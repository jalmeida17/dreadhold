"""Dreadhold procedural audio generator (all SFX, music and ambiences).

Everything is synthesised from code - no samples. Deterministic (fixed seeds per sound).
Output: OGG Vorbis 44.1 kHz. SFX mono -> assets/sfx/, music + ambiences stereo -> assets/music/.

Usage (from the project root):
  .venv\\Scripts\\python tools/audio/gen_audio.py                       # everything
  .venv\\Scripts\\python tools/audio/gen_audio.py --only fireball_cast,music_menu
  .venv\\Scripts\\python tools/audio/gen_audio.py -- only=bow_shoot,volley   # Godot-style also works
  .venv\\Scripts\\python tools/audio/gen_audio.py --list
Options: --jobs N (parallel workers), --keep-wav (don't delete replaced .wav/.wav.import files).
Setup:   py -3 -m venv .venv && .venv\\Scripts\\python -m pip install -r tools/audio/requirements.txt
"""
import argparse
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "music")

from dsp import SR, hp, norm, peak, rms, rng_for, fade, n_of, seed_of  # noqa: E402

SFX_PEAK_DB = -1.0
MUSIC_PEAK_DB = -3.0
AMB_PEAK_DB = -12.0
QUALITY = 0.5            # Vorbis quality 0..1 (~ -q5)


def registry():
    """name -> (kind, module, function name). kind: 'sfx' | 'music' | 'amb'."""
    import sfx_a
    import sfx_b
    reg = {}
    for mod in (sfx_a, sfx_b):
        for k in dir(mod):
            if k.startswith("s_"):
                reg[k[2:]] = ("sfx", mod.__name__, k)
    try:
        import music
        for name, kind in music.TRACKS.items():
            reg[name] = (kind, "music", "t_" + name)
    except ImportError:
        pass
    return reg


def finish_sfx(y):
    y = hp(np.asarray(y, dtype=float), 22, 2)
    y = norm(y, 10 ** (SFX_PEAK_DB / 20))
    thr = 10 ** (-50 / 20)
    idx = np.nonzero(np.abs(y) > thr)[0]
    end = min(len(y), (idx[-1] if idx.size else len(y) - 1) + n_of(0.02))
    y = y[:end]
    return fade(y, 0.001, min(0.02, len(y) / SR * 0.2))


def _ogg_crc_table():
    t = []
    for i in range(256):
        c = i << 24
        for _ in range(8):
            c = ((c << 1) ^ 0x04C11DB7) if c & 0x80000000 else (c << 1)
        t.append(c & 0xFFFFFFFF)
    return t


_OGG_CRC = _ogg_crc_table()


def fix_ogg_serial(path, serial):
    """libsndfile picks a random Ogg stream serial number, so identical audio would give
    different bytes on every run. Rewrite it with a fixed value and recompute page CRCs."""
    b = bytearray(open(path, "rb").read())
    i = 0
    while i + 27 <= len(b) and b[i:i + 4] == b"OggS":
        nseg = b[i + 26]
        size = 27 + nseg + sum(b[i + 27:i + 27 + nseg])
        b[i + 14:i + 18] = serial.to_bytes(4, "little")
        b[i + 22:i + 26] = b"\0\0\0\0"
        crc = 0
        for byte in b[i:i + size]:
            crc = ((crc << 8) & 0xFFFFFFFF) ^ _OGG_CRC[((crc >> 24) ^ byte) & 0xFF]
        b[i + 22:i + 26] = crc.to_bytes(4, "little")
        i += size
    open(path, "wb").write(bytes(b))


def write_ogg(path, y, target_db):
    """Encode, then re-measure the decoded file and correct the gain so the decoded
    peak lands on target (Vorbis can overshoot the PCM peak a little)."""
    data = np.ascontiguousarray(y.T if y.ndim == 2 else y)
    ch = 1 if data.ndim == 1 else data.shape[1]
    g = 1.0
    for _ in range(3):
        # stream in blocks: one huge write() overflows the stack inside libvorbis on Windows
        with sf.SoundFile(path, "w", SR, ch, format="OGG", subtype="VORBIS", compression_level=1.0 - QUALITY) as f:
            for i in range(0, data.shape[0], 8192):
                f.write(data[i:i + 8192] * g)
        fix_ogg_serial(path, seed_of(os.path.basename(path)))
        dec, _sr = sf.read(path, dtype="float64")
        pk = peak(dec)
        err = target_db - 20 * np.log10(max(pk, 1e-9))
        if abs(err) < 0.15:
            break
        g *= 10 ** (err / 20)
    return dec


def render(name, kind, modname, fname):
    t0 = time.time()
    mod = __import__(modname)
    fn = getattr(mod, fname)
    r = rng_for("dreadhold", name)
    y = fn(r)
    if kind == "sfx":
        y = finish_sfx(y)
        path = os.path.join(SFX_DIR, name + ".ogg")
        dec = write_ogg(path, y, SFX_PEAK_DB)
    else:
        path = os.path.join(MUS_DIR, name + ".ogg")
        dec = write_ogg(path, y, MUSIC_PEAK_DB if kind == "music" else AMB_PEAK_DB)
    info = {
        "name": name, "kind": kind, "path": path,
        "dur": dec.shape[0] / SR, "ch": 1 if dec.ndim == 1 else dec.shape[1],
        "peak": 20 * np.log10(max(peak(dec), 1e-9)), "rms": 20 * np.log10(max(rms(dec), 1e-9)),
        "kbps": os.path.getsize(path) * 8 / 1000 / max(dec.shape[0] / SR, 1e-3),
        "sec": time.time() - t0,
    }
    if kind != "sfx" and hasattr(mod, "LOOP_INFO") and name in mod.LOOP_INFO:
        info["loop"] = mod.LOOP_INFO[name]
    return info


def cleanup_old(name, kind):
    d = SFX_DIR if kind == "sfx" else MUS_DIR
    removed = []
    for ext in (".wav", ".wav.import"):
        p = os.path.join(d, name + ext)
        if os.path.exists(p):
            os.remove(p)
            removed.append(os.path.basename(p))
    return removed


def main():
    argv = sys.argv[1:]
    only = []
    rest = []
    for a in argv:
        if a.startswith("only="):
            only += [s for s in a[5:].split(",") if s]
        elif a != "--":
            rest.append(a)
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--jobs", type=int, default=max(1, min(6, (os.cpu_count() or 2) - 1)))
    ap.add_argument("--keep-wav", action="store_true")
    args = ap.parse_args(rest)
    only += [s for s in args.only.split(",") if s]

    reg = registry()
    if args.list:
        for k, v in sorted(reg.items(), key=lambda kv: (kv[1][0], kv[0])):
            print(f"{v[0]:5s} {k}")
        return
    names = list(reg) if not only else only
    unknown = [n for n in names if n not in reg]
    if unknown:
        print("unknown names:", ", ".join(unknown))
        names = [n for n in names if n in reg]
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUS_DIR, exist_ok=True)

    # long jobs first so the pool stays busy
    order = sorted(names, key=lambda n: 0 if reg[n][0] != "sfx" else 1)
    t_all = time.time()
    results, failures = [], []
    with ProcessPoolExecutor(max_workers=args.jobs) as ex:
        futs = {ex.submit(render, n, *reg[n]): n for n in order}
        for f in as_completed(futs):
            n = futs[f]
            try:
                info = f.result()
                results.append(info)
                extra = f"  loop {info['loop']}" if "loop" in info else ""
                print(f"  {info['kind']:5s} {n:22s} {info['dur']:6.2f}s {info['ch']}ch  peak {info['peak']:6.2f}  "
                      f"rms {info['rms']:6.2f} dBFS  {info['kbps']:5.0f} kbps  ({info['sec']:.1f}s){extra}", flush=True)
            except Exception as e:  # noqa: BLE001
                failures.append(n)
                print(f"  FAILED {n}: {e!r}", flush=True)
    removed = []
    if not args.keep_wav:
        for info in results:
            removed += cleanup_old(info["name"], info["kind"])
    silent = [i["name"] for i in results if i["rms"] < -50]
    print(f"\n[gen_audio] {len(results)} files in {time.time() - t_all:.1f}s  failures={failures}  "
          f"near-silent={silent}  removed old: {len(removed)} files")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
