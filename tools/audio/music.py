"""Music: sequencing framework + menu and night tracks. Stereo, seamless loops.

Loops are an exact number of bars (tempos chosen so a beat is a whole number of
samples). Everything is rendered onto [0, L + tail]; note releases and reverb past L
are wrapped back onto the start, so the end flows into the beginning."""
import numpy as np
from scipy import signal
from dsp import (SR, n_of, tl, lp, hp, bp, eq, env_pts, smooth_rand, norm, pad_to, place, pan, midi_hz,
                 make_ir, convolve, rms, peak, softclip, rng_for, saw, sine, white)
import instruments as I

TRACKS = {}
LOOP_INFO = {}

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
        "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "dim": [0, 3, 6], "aug": [0, 4, 8], "sus4": [0, 5, 7], "sus2": [0, 2, 7],
        "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "5": [0, 7], "m6": [0, 3, 7, 9],
        "madd9": [0, 3, 7, 14], "add9": [0, 4, 7, 14], "7b9": [0, 4, 7, 10, 13]}


def parse(ch):
    root = ch[:2] if len(ch) > 1 and ch[1] in "#b" else ch[:1]
    return NOTE[root], QUAL[ch[len(root):]]


def chord(ch, low, high=None, count=None):
    """Chord tones of `ch` between midi low..high (close voicing, ascending)."""
    rt, iv = parse(ch)
    high = high if high is not None else low + 12
    pcs = sorted({(rt + i) % 12 for i in iv})
    out = [m for m in range(low, high + 1) if m % 12 in pcs]
    return out[:count] if count else out


def root(ch, octave=2):
    return 12 * (octave + 1) + parse(ch)[0]


def steps(pattern):
    """'X.x.o...' -> [(step, vel)]"""
    vel = {"X": 1.0, "x": 0.72, "o": 0.42, "g": 0.25}
    return [(i, vel[c]) for i, c in enumerate(pattern.replace(" ", "")) if c in vel]


class Song:
    def __init__(self, name, bpm, bars, beats=4, tail=9.0, seed=0):
        self.name = name
        self.r = rng_for("song", name, seed)
        self.spb = 60.0 / bpm
        self.beats = beats
        self.bars = bars
        self.L = int(round(bars * beats * self.spb * SR))
        self.N = self.L + n_of(tail)
        self.buses = {}
        self.cache = {}
        LOOP_INFO[name] = f"{bpm} BPM x {bars} bars of {beats} = {self.L / SR:.2f}s"

    def t(self, bar, beat=0.0):
        return (bar * self.beats + beat) * self.spb

    def bus(self, name, send=0.3, level=0.1):
        if name not in self.buses:
            self.buses[name] = [np.zeros((2, self.N)), send, level]
        return self.buses[name][0]

    def add(self, busname, sig, t, gain=1.0, p=0.0):
        b = self.buses[busname][0]
        if sig.ndim == 1:
            sig = pan(sig, p)
        place(b, sig, t % (self.L / SR), gain)

    def cached(self, key, fn):
        if key not in self.cache:
            self.cache[key] = fn()
        return self.cache[key]

    def render(self, rt60=2.6, damp=0.5, rev=0.35, glue_db=-16.0, ratio=2.2, bright=0.0, clip=1.3):
        dry = np.zeros((2, self.N))
        send = np.zeros((2, self.N))
        for name, (b, s, level) in self.buses.items():
            r_ = rms(b[:, :self.L])
            if r_ < 1e-9:
                continue
            b = b * (level / r_)
            dry += b
            send += s * b
        ir = make_ir(rt60, None, True, 17, 0.02, damp, 0.4, 1.4)
        wet = convolve(send, ir)[:, :self.N]
        mix = dry + rev * wet * (rms(dry) / max(rms(wet), 1e-9)) * 0.5
        if bright:
            mix = eq(mix, [("highshelf", 6000, 0.7, bright)])
        # fade the far end of the over-length render, then wrap the tail onto the start
        nf = n_of(1.5)
        mix[:, -nf:] *= np.cos(np.linspace(0, np.pi / 2, nf)) ** 2
        loop = mix[:, :self.L].copy()
        k = self.L
        while k < self.N:
            e = min(self.N, k + self.L)
            loop[:, :e - k] += mix[:, k:e]
            k += self.L
        loop -= loop.mean(axis=1, keepdims=True)
        loop = glue(loop, glue_db, ratio)
        loop = norm(loop, 1.0)
        loop = softclip(loop, clip)
        return norm(loop, 10 ** (-3 / 20))


def glue(x, thr_db, ratio, win=0.12):
    """Gentle bus compression with a periodic (loop-safe) zero-phase envelope."""
    env = np.max(np.abs(x), axis=0)
    p = n_of(1.0)
    e = np.concatenate([env[-p:], env, env[:p]])
    a = np.exp(-1.0 / (win * SR))
    e = signal.filtfilt([1 - a], [1, -a], e)[p:-p]
    edb = 20 * np.log10(np.maximum(e, 1e-9) / max(np.max(e), 1e-9))
    g = np.where(edb > thr_db, (thr_db - edb) * (1 - 1 / ratio), 0.0)
    return x * 10 ** (g / 20)


# ------------------------------------------------------------------ shared parts
def drums(song, bus, bar, pats, taiko_size=1.0, gain=1.0):
    """pats: dict instrument -> 16-step pattern string (per bar)."""
    r = song.r
    for inst, pat in pats.items():
        for st, v in steps(pat):
            t = song.t(bar, st * song.beats / 16.0) + r.uniform(0, 0.006)
            vv = round(v * r.uniform(0.9, 1.0) * 4) / 4
            if inst == "taiko":
                s = song.cached(("taiko", vv, int(r.integers(3)), taiko_size), lambda: I.taiko(rng_for(song.name, "tk", vv, r.integers(9)), vv, taiko_size))
                song.add(bus, s, t, gain, r.uniform(-0.25, 0.25))
            elif inst in ("tom_hi", "tom_lo", "tom_mid"):
                f = {"tom_hi": 165, "tom_mid": 120, "tom_lo": 88}[inst]
                s = song.cached((inst, vv), lambda: I.tom(rng_for(song.name, inst, vv), f, vv))
                song.add(bus, s, t, gain * 0.8, {"tom_hi": 0.4, "tom_mid": 0.0, "tom_lo": -0.4}[inst])
            elif inst == "frame":
                s = song.cached(("frame", vv, int(r.integers(2))), lambda: I.frame_drum(rng_for(song.name, "fr", vv, r.integers(9)), vv))
                song.add(bus, s, t, gain * 0.55, 0.3)
            elif inst == "snare":
                s = song.cached(("snare", vv), lambda: I.snare(rng_for(song.name, "sn", vv), vv))
                song.add(bus, s, t, gain * 0.5, -0.2)
            elif inst == "sticks":
                s = song.cached(("sticks", vv), lambda: I.sticks(rng_for(song.name, "st", vv), vv))
                song.add(bus, s, t, gain * 0.35, 0.45)
            elif inst == "shaker":
                s = song.cached(("shaker", vv), lambda: I.shaker(rng_for(song.name, "sh", vv), vv))
                song.add(bus, s, t, gain * 0.3, -0.45)
            elif inst == "anvil":
                s = song.cached(("anvil", vv), lambda: I.anvil(rng_for(song.name, "an", vv), 920, vv, 1.4))
                song.add(bus, s, t, gain * 0.5, 0.35)
            elif inst == "wet":
                s = song.cached(("wet", vv, int(r.integers(3))), lambda: I.wet_thud(rng_for(song.name, "wet", vv, r.integers(9)), vv))
                song.add(bus, s, t, gain, r.uniform(-0.3, 0.3))
            elif inst == "timp":
                s = song.cached(("timp", vv), lambda: I.timpani(rng_for(song.name, "tp", vv), 73.4, vv))
                song.add(bus, s, t, gain, 0.0)


def ostinato(song, bus, bar, ch, pattern, degrees, octave=2, dur_steps=1, players=3, gain=1.0, style="spiccato"):
    """Low strings figure: pattern steps take successive semitone offsets from `degrees`."""
    st = steps(pattern)
    for j, (s, v) in enumerate(st):
        m = root(ch, octave) + degrees[j % len(degrees)]
        d = dur_steps * song.spb * song.beats / 16.0
        key = ("ost", m, round(d, 3), style, players)
        sig = song.cached(key, lambda: I.strings(rng_for(song.name, *key), [m], d, style, players, 0.6, 0.08))
        song.add(bus, sig, song.t(bar, s * song.beats / 16.0), gain * v)


def pad_choir(song, bus, bar, ch, nbars, low, high, vowel="a", female=False, singers=4, gain=1.0, att=0.6):
    notes = chord(ch, low, high)
    d = nbars * song.beats * song.spb
    key = ("choir", ch, low, high, vowel, female, round(d, 3), singers)
    sig = song.cached(key, lambda: I.choir(rng_for(song.name, *key), notes, d, vowel, female, singers, att, 1.0))
    song.add(bus, sig, song.t(bar), gain)


def pad_strings(song, bus, bar, ch, nbars, low, high, gain=1.0, style="sustain", players=4, lowbody=True):
    notes = chord(ch, low, high)
    d = nbars * song.beats * song.spb
    key = ("str", ch, low, high, round(d, 3), style)
    sig = song.cached(key, lambda: I.strings(rng_for(song.name, *key), notes, d, style, players, 0.7, 0.5, lowbody))
    song.add(bus, sig, song.t(bar), gain)


def melody(song, bus, notes, inst="horn", gain=1.0, p=0.0):
    """notes: [(bar, beat, beats, midi), ...]"""
    for bar, beat, beats, m in notes:
        d = beats * song.spb
        key = (inst, m, round(d, 3))
        if inst == "horn":
            fn = lambda: I.brass_section(rng_for(song.name, *key), [m], d, 0.75, 3, 0.35, 6.0, att=0.12, rel=0.35, vib=14)
        elif inst == "trumpet":
            fn = lambda: I.brass_section(rng_for(song.name, *key), [m], d, 0.95, 2, 0.3, 5.0, att=0.05, rel=0.2, vib=12, tilt_loud=0.7)
        elif inst == "cello":
            fn = lambda: I.strings(rng_for(song.name, *key), [m], d, "sustain", 2, 0.25, 0.4, True)
        elif inst == "violin":
            fn = lambda: I.strings(rng_for(song.name, *key), [m], d, "sustain", 3, 0.3, 0.4, False)
        elif inst == "hurdy":
            fn = lambda: pan(I.hurdy(rng_for(song.name, *key), midi_hz(m), d, 0.12, 0.25), 0.15)
        elif inst == "glass":
            fn = lambda: pan(I.glass_harmonica(rng_for(song.name, *key), midi_hz(m), d, 1.2), 0.2)
        elif inst == "choir_f":
            fn = lambda: I.choir(rng_for(song.name, *key), [m], d, "u", True, 4, 0.4, 1.0)
        else:
            raise ValueError(inst)
        song.add(bus, song.cached(key, fn), song.t(bar, beat), gain, p)


def hit_once(song, bus, sig, bar, beat=0.0, gain=1.0, p=0.0):
    song.add(bus, sig, song.t(bar, beat), gain, p)


# ------------------------------------------------------------------ MENU
def t_music_menu(r):
    s = Song("music_menu", 60, 20, tail=10.0)
    prog = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A", "Dm", "Dm", "F", "F", "C", "C", "Gm", "Gm", "Bb", "Bb", "A", "A"]
    s.bus("strings", 0.35, 0.10)
    s.bus("choir", 0.6, 0.075)
    s.bus("organ", 0.4, 0.035)
    s.bus("horn", 0.45, 0.06)
    s.bus("perc", 0.5, 0.035)
    s.bus("drone", 0.2, 0.03)
    for b in range(0, 20, 2):
        ch = prog[b]
        pad_strings(s, "strings", b, ch, 2, 38, 57, 1.0)
        if b >= 4:
            pad_choir(s, "choir", b, ch, 2, 50, 62, "o" if b < 12 else "a", False, 4, 1.0, 1.2)
        s.add("organ", s.cached(("org", ch), lambda: I.organ(rng_for("menu", "org", ch), midi_hz(root(ch, 1)), 7.6,
                                                              (("16", 0.6), ("8", 1.0), ("4", 0.25)), 0.6, 0.05)), s.t(b))
    hmel = [(8, 0, 2, 57), (8, 2, 2, 62), (9, 0, 3, 65), (9, 3, 1, 64), (10, 0, 2, 65), (10, 2, 2, 69),
            (11, 0, 3, 67), (11, 3, 1, 65), (12, 0, 2, 64), (12, 2, 2, 67), (13, 0, 3, 67), (13, 3, 1, 64),
            (14, 0, 2, 62), (14, 2, 2, 67), (15, 0, 3, 70), (15, 3, 1, 69), (16, 0, 4, 62), (17, 0, 2, 65),
            (17, 2, 2, 62), (18, 0, 2, 64), (18, 2, 2, 61), (19, 0, 4, 57)]
    melody(s, "horn", hmel, "horn", 1.0, -0.15)
    bell = I.bell(rng_for("menu", "bell"), midi_hz(50), 8.0, 1.0, 1.4, 0.7)
    for b in (0, 8, 16):
        hit_once(s, "perc", bell, b, 0, 1.0, 0.2)
    timp_roll = np.zeros(n_of(4.2))
    rr = rng_for("menu", "roll")
    for k in range(24):
        place(timp_roll, I.timpani(rr, 73.4, 0.25 + 0.75 * k / 24, 1.5), k * 0.16)
    for b in (7, 15):
        hit_once(s, "perc", pan(timp_roll, 0), b, 0, 0.5)
    hit_once(s, "perc", pan(I.timpani(rr, 73.4, 1.0, 3.0), 0), 8, 0, 0.9)
    hit_once(s, "perc", pan(I.timpani(rr, 73.4, 1.0, 3.0), 0), 16, 0, 0.9)
    dr = I.drone(rng_for("menu", "drone"), midi_hz(26), s.L / SR + 0.5, 180)
    s.add("drone", pan(dr, 0), 0)
    return s.render(4.2, 0.55, 0.5)


# ------------------------------------------------------------------ NIGHT 1: grim and steady
def t_music_night_1(r):
    s = Song("music_night_1", 90, 32, tail=7.0)
    prog = (["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"] * 2 + ["Dm", "Bb", "F", "C", "Gm", "Gm", "A", "A"] * 2)
    s.bus("drums", 0.2, 0.15)
    s.bus("ost", 0.25, 0.085)
    s.bus("pad", 0.45, 0.05)
    s.bus("brass", 0.4, 0.05)
    s.bus("choir", 0.55, 0.04)
    for b in range(32):
        ch = prog[b]
        fill = b % 8 == 7
        drums(s, "drums", b, {"taiko": "X.......x.....x." if not fill else "X.......X.x.x.xx",
                              "tom_mid": "....x.......x..." if not fill else "....x...........",
                              "frame": "x.o.x.o.x.o.x.o." if b >= 8 else "x...x...x...x..."})
        ostinato(s, "ost", b, ch, "x.x.x.x.x.x.x.x.", [0, 0, 12, 0, 0, 0, 7, 5], 2, 2, 3)
        if b % 2 == 0:
            pad_strings(s, "pad", b, ch, 2, 50, 62, 1.0)
        if b >= 16 and b % 2 == 0:
            pad_choir(s, "choir", b, ch, 2, 45, 57, "o", False, 4)
    for b in list(range(8, 16, 2)) + list(range(24, 32, 2)):
        notes = chord(prog[b], 45, 57, 3)
        key = ("bsw", prog[b])
        sig = s.cached(key, lambda: I.brass_section(rng_for("n1", *key), notes, s.spb * 8, 0.55, 2, 0.5, 6, att=0.6, rel=0.6))
        s.add("brass", sig, s.t(b))
    s.bus("fx", 0.5, 0.02)
    cr = I.crash(rng_for("n1", "crash"), 3.0)
    for b in (0, 8, 16, 24):
        hit_once(s, "fx", pan(cr, 0.3), b)
    return s.render(2.4, 0.55, 0.32)


# ------------------------------------------------------------------ NIGHT 2: darker, choir, faster
def t_music_night_2(r):
    s = Song("music_night_2", 105, 32, tail=7.0)
    prog = (["Dm", "Eb", "Dm", "C", "Bb", "Gm", "A", "A"] * 2 + ["Dm", "Eb", "Gm", "A", "Bb", "Eb", "A", "A"] * 2)
    s.bus("drums", 0.2, 0.15)
    s.bus("ost", 0.25, 0.08)
    s.bus("choir", 0.6, 0.07)
    s.bus("brass", 0.4, 0.045)
    s.bus("hi", 0.5, 0.03)
    for b in range(32):
        ch = prog[b]
        fill = b % 4 == 3
        drums(s, "drums", b, {"taiko": "X..x..X.x..x.X.." if not fill else "X..x..X.X.xxX.xx",
                              "snare": "....x.......x..." if b >= 8 else "",
                              "tom_lo": "" if not fill else "........x.x.x.x.",
                              "frame": "x.ooxo.ox.ooxo.o"})
        ostinato(s, "ost", b, ch, "xoxoxoxoxoxoxoxo", [0, 0, 12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 1, 0, 12, 0], 2, 1, 3)
        if b % 2 == 0:
            pad_choir(s, "choir", b, ch, 2, 45, 60, "a", False, 5, 1.0, 0.4)
            if b >= 16:
                pad_choir(s, "hi", b, ch, 2, 69, 79, "o", True, 4, 1.0, 0.5)
        if b % 4 == 0:
            notes = [root(ch, 2), root(ch, 2) + 7, root(ch, 3)]
            key = ("hit", ch)
            sig = s.cached(key, lambda: I.brass_section(rng_for("n2", *key), notes, 0.5, 1.0, 2, 0.4, 8, att=0.03, rel=0.3, fall=1.0))
            s.add("brass", sig, s.t(b))
    s.bus("fx", 0.5, 0.025)
    cr = I.crash(rng_for("n2", "crash"), 3.0)
    sw = I.swell(rng_for("n2", "sw"), s.spb * 4)
    for b in range(0, 32, 8):
        hit_once(s, "fx", pan(cr, -0.3), b)
        hit_once(s, "fx", pan(sw, 0.2), (b - 1) % 32)
    return s.render(2.6, 0.55, 0.35)


# ------------------------------------------------------------------ NIGHT 3: heavy, brass stabs
def t_music_night_3(r):
    s = Song("music_night_3", 120, 40, tail=7.0)
    two = ["Cm", "Ab", "Bb", "G", "Cm", "Ab", "Fm", "G", "Ab", "Bb", "Cm", "Cm", "Fm", "G", "Cm", "G", "Ab", "Fm", "G", "G"]
    prog = [c for c in two for _ in (0, 1)]
    s.bus("drums", 0.2, 0.16)
    s.bus("ost", 0.25, 0.075)
    s.bus("stabs", 0.35, 0.07)
    s.bus("choir", 0.6, 0.055)
    s.bus("horn", 0.45, 0.06)
    for b in range(40):
        ch = prog[b]
        fill = b % 8 == 7
        drums(s, "drums", b, {"taiko": "X.x.X.x.X.x.X.x." if not fill else "X.x.X.x.XxxxXxxx",
                              "snare": "....X.......X..o" if not fill else "....X...xxxxXXXX",
                              "tom_hi": "" if not fill else "........x.x.....",
                              "tom_lo": "" if not fill else "..........x.x.x.",
                              "frame": "oxoxoxoxoxoxoxox"})
        ostinato(s, "ost", b, ch, "xxxxxxxxxxxxxxxx", [0, 0, 12, 0, 0, 12, 0, 0, 0, 0, 12, 0, 7, 0, 12, 0], 2, 1, 3)
        stab_pat = "X.....X.....X.x." if b % 2 == 0 else "..X...X...X.X..."
        for st, v in steps(stab_pat):
            notes = chord(ch, 48, 60, 4)
            key = ("stab", ch)
            sig = s.cached(key, lambda: I.brass_section(rng_for("n3", *key), notes, 0.16, 1.0, 2, 0.6, 9, att=0.012, rel=0.12))
            s.add("stabs", sig, s.t(b, st / 4.0), v)
        if b % 2 == 0:
            pad_choir(s, "choir", b, ch, 2, 48, 63, "a", False, 4, 1.0, 0.3)
    hm = [(20, 0, 3, 67), (20, 3, 1, 68), (21, 0, 4, 67), (22, 0, 2, 63), (22, 2, 2, 65), (23, 0, 4, 67),
          (24, 0, 3, 68), (24, 3, 1, 70), (25, 0, 4, 72), (26, 0, 2, 70), (26, 2, 2, 68), (27, 0, 4, 67),
          (28, 0, 3, 65), (28, 3, 1, 67), (29, 0, 2, 68), (29, 2, 2, 65), (30, 0, 4, 67), (31, 0, 4, 62),
          (32, 0, 3, 63), (32, 3, 1, 65), (33, 0, 4, 67), (34, 0, 2, 68), (34, 2, 2, 72), (35, 0, 4, 71),
          (36, 0, 3, 72), (36, 3, 1, 70), (37, 0, 4, 68), (38, 0, 4, 67), (39, 0, 4, 67)]
    melody(s, "horn", hm, "horn", 1.0, 0.1)
    s.bus("fx", 0.5, 0.025)
    cr = I.crash(rng_for("n3", "crash"), 3.0)
    for b in range(0, 40, 4):
        hit_once(s, "fx", pan(cr, 0.3 if b % 8 else -0.3), b, 0, 1.0 if b % 8 == 0 else 0.6)
    return s.render(2.4, 0.5, 0.3)


# ------------------------------------------------------------------ NIGHT 4: frantic, dissonant
def t_music_night_4(r):
    s = Song("music_night_4", 140, 48, tail=7.0)
    two = ["Dm", "Eb", "Dm", "Ab", "Bb", "Gm", "A7b9", "A7b9", "Dm", "Eb", "Gm", "Ab", "Bb", "Eb", "A", "A",
           "Dm", "Ab", "Dm", "Ab", "Gm", "Eb", "A7b9", "A7b9"]
    prog = [c for c in two for _ in (0, 1)]
    s.bus("drums", 0.2, 0.17)
    s.bus("ost", 0.25, 0.07)
    s.bus("trem", 0.4, 0.035)
    s.bus("stabs", 0.35, 0.065)
    s.bus("choir", 0.6, 0.06)
    s.bus("hi", 0.5, 0.03)
    for b in range(48):
        ch = prog[b]
        fill = b % 4 == 3
        drums(s, "drums", b, {"taiko": "X.xxX.x.X.xxX.x." if not fill else "XxxxX.xxXxxxXXXX",
                              "snare": "o.o.X.o.o.ooX.o." if not fill else "ooooXoooxxxxXXXX",
                              "tom_lo": "x.....x.........",
                              "frame": "xoxoxoxoxoxoxoxo"}, 1.0)
        ostinato(s, "ost", b, ch, "xxxxxxxxxxxxxxxx", [0, 0, 12, 0, 1, 0, 12, 0, 0, 0, 12, 0, 6, 0, 12, 1], 2, 1, 3)
        if b % 2 == 0:
            notes = chord(ch, 62, 74) + [chord(ch, 62, 74)[0] + 1]           # added b9 grind
            key = ("trem", ch)
            sig = s.cached(key, lambda: I.strings(rng_for("n4", *key), notes, s.spb * 8, "tremolo", 3, 0.7, 0.4, False))
            s.add("trem", sig, s.t(b))
            pad_choir(s, "choir", b, ch, 2, 45, 62, "a", False, 5, 1.0, 0.25)
            if b >= 16:
                pad_choir(s, "hi", b, ch, 2, 69, 81, "a", True, 4, 1.0, 0.3)
        for st, v in steps("X..X..X...X..X.." if b % 2 == 0 else "X..X..X.X.X.X.X."):
            notes = chord(ch, 46, 58, 4)
            key = ("stab", ch)
            sig = s.cached(key, lambda: I.brass_section(rng_for("n4", *key), notes, 0.13, 1.0, 2, 0.6, 14, att=0.01, rel=0.1))
            s.add("stabs", sig, s.t(b, st / 4.0), v)
    s.bus("fx", 0.5, 0.03)
    cr = I.crash(rng_for("n4", "crash"), 2.5)
    for b in range(0, 48, 4):
        hit_once(s, "fx", pan(cr, 0.3 if b % 8 else -0.3), b)
    return s.render(2.2, 0.5, 0.28, -14, 2.5)


for _n in ("music_menu", "music_night_1", "music_night_2", "music_night_3", "music_night_4"):
    TRACKS[_n] = "music"

from music2 import *  # noqa: E402,F401,F403  (dawn, bosses, defeat)
from ambience import *  # noqa: E402,F401,F403
