"""Reusable SFX building blocks (mono, 44.1 kHz)."""
import numpy as np
from dsp import (SR, n_of, tl, white, pink, brown, lp, hp, bp, biquad, tvf, eq, resonators,
                 env_pts, env_exp, freq_pts, smooth_rand, phase_of, sine, saw, modal, sat,
                 norm, pad_to, place, reverb, ks_string, onepole_lp, peak)


def room(x, wet=0.18, rt=1.3, damp=0.55, pre=0.010, seed=11, tail=None):
    """Torch-lit stone hall: mono convolution reverb."""
    return reverb(x, wet, rt, damp, pre, seed, tail=tail if tail is not None else min(rt * 0.8, 2.5))


def mixdown(n, *layers):
    """layers: (signal, t, gain)."""
    n = max([n] + [int(round(t * SR)) + s.shape[-1] for s, t, g in layers])   # never truncate a layer
    y = np.zeros(n)
    for s, t, g in layers:
        place(y, s, t, g)
    return y


def nz(r, n, color="white"):
    return {"white": white, "pink": pink, "brown": brown}[color](r, n)


def thump(dur, f_hi, f_lo, ptau, atau, att=0.001):
    n = n_of(dur)
    t = tl(n)
    f = f_lo + (f_hi - f_lo) * np.exp(-t / ptau)
    return endfade(sine(f) * env_exp(n, att, atau))


def endfade(y, sec=0.03):
    nf = min(len(y) // 4, n_of(sec))
    if nf > 1:
        y[len(y) - nf:] *= np.cos(np.linspace(0, np.pi / 2, nf)) ** 2
    return y


def burst(r, dur, lo, hi, att, tau, color="white"):
    n = n_of(dur)
    x = nz(r, n, color)
    if lo and hi:
        x = bp(x, lo, hi)
    elif hi:
        x = lp(x, hi)
    elif lo:
        x = hp(x, lo)
    return endfade(x * env_exp(n, att, tau))


def whoosh(r, dur, f_pts, a_pts, q=1.2, color="white", turb=0.0, turb_rate=40):
    """Band-passed noise with a swept centre; turb adds air-tearing turbulence."""
    n = n_of(dur)
    x = nz(r, n, color)
    y = tvf(x, freq_pts(n, f_pts), q, "bp")
    if turb > 0:
        y *= 1 + turb * smooth_rand(r, n, turb_rate)
    return y * env_pts(n, a_pts)


def grains(r, n, times, maker):
    """Place maker(r, i) grains at given sample times (seconds)."""
    y = np.zeros(n)
    for i, t in enumerate(times):
        place(y, maker(r, i), t)
    return y


def poisson_times(r, dur, rate_pts, t0=0.0):
    """Event times from a time-varying density (events/s)."""
    n = n_of(dur)
    dens = env_pts(n, rate_pts)
    cum = np.cumsum(dens) / SR
    total = cum[-1]
    k = r.poisson(max(total, 0))
    u = np.sort(r.uniform(0, total, k))
    idx = np.searchsorted(cum, u)
    return t0 + idx / SR


def crackle(r, dur, rate_pts, gmin=0.15, gmax=1.5, lo=1500, hi=None, amp_pow=2.0):
    """Sparks / fire crackle: decaying noise grains (ms lengths)."""
    n = n_of(dur)
    times = poisson_times(r, dur, rate_pts)

    def g(rr, i):
        L = max(3, int(rr.uniform(gmin, gmax) * SR / 1000))
        e = np.exp(-np.arange(L) / (L / 4)) * rr.uniform(0, 1) ** amp_pow * rr.choice([-1, 1])
        return rr.standard_normal(L) * e
    y = grains(r, n, times, g)
    y = hp(y, lo) if lo else y
    return lp(y, hi) if hi else y


def fire(r, dur, intensity_pts, body=700, flick=0.6):
    """Roaring fire texture: brown/pink noise body + flicker + crackle."""
    n = n_of(dur)
    roar = lp(nz(r, n, "pink"), body) + 0.5 * bp(nz(r, n, "white"), body, body * 3.5)
    roar *= 1 + flick * smooth_rand(r, n, 22) + 0.3 * flick * smooth_rand(r, n, 70)
    roar *= env_pts(n, intensity_pts)
    cr = crackle(r, dur, [(p[0], 160 * p[1]) for p in intensity_pts], 0.1, 1.2, 1800)
    return norm(roar, 1.0) + 0.45 * norm(cr, 1.0)


def stone_ping(r, f=None, tau=None):
    f = f or r.uniform(500, 2600)
    n = n_of(0.08)
    ratios = [1.0, 1.73, 2.41, 3.2]
    return modal(n, [f * k * r.uniform(0.97, 1.03) for k in ratios], [1, 0.6, 0.4, 0.25],
                 [tau or r.uniform(0.006, 0.02)] * 4, r) + 0.4 * burst(r, 0.08, 1500, 9000, 0.0002, 0.002)


def debris(r, dur, rate_pts, f_lo=400, f_hi=2600, gain_pow=1.5):
    n = n_of(dur)
    times = poisson_times(r, dur, rate_pts)
    return grains(r, n, times, lambda rr, i: stone_ping(rr, rr.uniform(f_lo, f_hi)) * rr.uniform(0.15, 1) ** gain_pow)


def bubble(r, f0=None, dur=None):
    """Minnaert bubble: sine with rising pitch and fast decay."""
    f0 = f0 or r.uniform(350, 1400)
    d = dur or r.uniform(0.02, 0.06)
    n = n_of(d)
    t = tl(n)
    f = f0 * (1 + 2.5 * t / d)
    return sine(f) * np.exp(-t / (d / 3.5)) * np.clip(t / 0.001, 0, 1)


def sizzle(r, dur, a_pts, lo=3000, hi=12000, rate=90):
    n = n_of(dur)
    x = bp(nz(r, n), lo, hi)
    am = np.clip(0.4 + smooth_rand(r, n, rate) + 0.6 * smooth_rand(r, n, 400), 0, None)
    y = x * am * env_pts(n, a_pts)
    cr = crackle(r, dur, [(p[0], 400 * p[1]) for p in a_pts], 0.05, 0.4, lo)
    return norm(y, 1.0) + 0.5 * norm(cr, 1.0)


def metal(r, f, dur, decay=0.25, bright=1.0, ratios=(1.0, 2.32, 3.86, 5.1, 6.93, 8.6, 11.2, 13.4)):
    n = n_of(dur)
    amps = [1.0, 0.75, 0.6, 0.5, 0.38 * bright, 0.28 * bright, 0.2 * bright, 0.14 * bright]
    dec = [decay * (1.0 / (1 + 0.35 * i)) for i in range(len(ratios))]
    fr = []
    am = []
    dc = []
    for k, a, d in zip(ratios, amps, dec):
        for j in range(2):
            fr.append(f * k * r.uniform(0.996, 1.004) + j * r.uniform(1, 4))
            am.append(a * (0.7 if j else 1.0))
            dc.append(d)
    y = modal(n, fr, am, dc, r)
    return y + 0.35 * burst(r, dur, 2500, 14000, 0.0002, 0.004)


def wood_knock(r, f=420.0, dur=0.15, tau=0.025):
    n = n_of(dur)
    y = modal(n, [f, f * 2.2, f * 3.7, f * 5.1], [1, 0.5, 0.25, 0.12], [tau, tau * 0.5, tau * 0.35, tau * 0.25], r)
    return y + 0.3 * burst(r, dur, 1500, 7000, 0.0002, 0.003)


def glass_pings(r, dur, count, f_lo=2200, f_hi=9000, t_max=0.15, tau=(0.08, 0.5)):
    n = n_of(dur)
    y = np.zeros(n)
    for _ in range(count):
        f = r.uniform(f_lo, f_hi)
        t0 = r.uniform(0, t_max) ** 1.5 / max(t_max, 1e-3) ** 0.5
        d = r.uniform(*tau)
        g = modal(n_of(dur - t0), [f, f * 2.76, f * 1.51], [1, 0.3, 0.25], [d, d * 0.4, d * 0.6], r)
        place(y, g * r.uniform(0.3, 1.0), t0)
    return y


# ------------------------------------------------------------------ voices
VOWELS = {
    "a": [730, 1090, 2440, 3400, 4500],
    "e": [530, 1840, 2480, 3500, 4500],
    "i": [270, 2290, 3010, 3500, 4500],
    "o": [570, 840, 2410, 3400, 4500],
    "u": [300, 870, 2240, 3400, 4500],
    "uh": [640, 1190, 2390, 3400, 4500],
    "ae": [660, 1720, 2410, 3400, 4500],
    "ng": [250, 1000, 2400, 3400, 4500],
}
BW = [90, 110, 160, 250, 300]
FG = [1.0, 0.7, 0.45, 0.28, 0.18]


def vowel_tracks(n, seq, shift=1.0):
    """seq = [(t, vowel), ...] -> list of 5 formant-frequency arrays."""
    ts = [s[0] for s in seq]
    out = []
    for k in range(5):
        vs = [VOWELS[s[1]][k] * shift for s in seq]
        out.append(np.interp(tl(n), ts, vs))
    return out


def voice(r, f0, seq, shift=1.0, tilt=1.1, breath=0.15, jitter=0.01, growl=0.0, growl_rate=32,
          sub=0.0, nasal=0.0, bw_scale=1.0, fmax=9000):
    """Formant-additive voice: harmonics of f0 shaped by moving formant resonances
    (computed at control rate), plus aspiration noise through the same formants.
    growl = random AM roughness, sub = subharmonic (period doubling) amount."""
    n = len(f0)
    f0 = f0 * (1 + jitter * smooth_rand(r, n, 45) + 0.5 * jitter * smooth_rand(r, n, 7))
    F = vowel_tracks(n, seq, shift)
    hop = 64
    ci = np.arange(0, n, hop)
    f0c = f0[ci]
    Fc = [f[ci] for f in F]
    ph = phase_of(f0)
    y = np.zeros(n)
    K = int(fmax / max(np.min(f0), 30))
    for k in range(1, K + 1):
        fk = k * f0c
        if np.min(fk) > fmax:
            break
        a = np.zeros_like(fk)
        for Fi, Bi, Gi in zip(Fc, BW, FG):
            a += Gi / np.sqrt(1 + ((fk - Fi) / (0.5 * Bi * bw_scale)) ** 2)
        if nasal > 0:
            a *= 1 - nasal * 0.8 / np.sqrt(1 + ((fk - 1000 * shift) / 150) ** 2)
            a += nasal * 0.6 / np.sqrt(1 + ((fk - 260 * shift) / 60) ** 2)
        a *= k ** (-tilt) * np.clip((fmax - fk) / 1500, 0, 1)
        y += np.interp(np.arange(n), ci, a) * np.sin(2 * np.pi * k * ph)
    if sub > 0:
        y *= 1 + sub * np.sin(np.pi * ph)            # period doubling -> subharmonics
    if growl > 0:
        y *= 1 + growl * smooth_rand(r, n, growl_rate) + 0.5 * growl * smooth_rand(r, n, growl_rate * 2.7)
    y = norm(y, 1.0)
    if breath > 0:
        b = nz(r, n)
        asp = np.zeros(n)
        for Fi, Bi, Gi in zip(F[:4], BW, FG):
            asp += Gi * tvf(b, Fi, float(np.mean(Fi)) / (Bi * 1.5), "bp", block=256)
        # aspiration is pitch-synchronous (pulsed with the glottis)
        asp *= 0.55 + 0.45 * np.cos(2 * np.pi * ph) ** 2
        y = y + breath * norm(asp, 1.0)
    return y


def creature(r, dur, f0_pts, seq, a_pts, shift=0.85, tilt=0.9, breath=0.4, jitter=0.03, growl=0.6,
             sub=0.3, drive=2.5, growl_rate=32):
    n = n_of(dur)
    v = voice(r, freq_pts(n, f0_pts), seq, shift, tilt, breath, jitter, growl, growl_rate, sub)
    v *= env_pts(n, a_pts)
    return sat(v, drive)


def big_roar(r, dur, f0_pts, seq, a_pts, size=0.65, drive=3.0, scream=0.0, sub_bass=0.5, breath=0.5):
    """Layered monster roar: base voice + octave-down voice + throat noise + optional scream."""
    n = n_of(dur)
    f0 = freq_pts(n, f0_pts)
    env = env_pts(n, a_pts)
    v1 = voice(r, f0, seq, size, 0.8, breath, 0.03, 0.8, 30, 0.5)
    v2 = voice(r, f0 * 0.5, seq, size * 0.9, 0.9, breath * 0.6, 0.03, 0.6, 24, 0.3)
    ph = phase_of(f0)
    rattle = bp(nz(r, n), 150, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * ph)) * (1 + 0.6 * smooth_rand(r, n, 35))
    y = norm(v1, 1.0) + 0.7 * norm(v2, 1.0) + 0.35 * norm(rattle, 1.0)
    if scream > 0:
        sc = voice(r, f0 * 5.1, [(0, "e"), (dur * 0.5, "a"), (dur, "a")], 1.05, 0.7, 0.5, 0.05, 0.5, 40, 0.2)
        y += scream * norm(sc, 1.0) * env_pts(n, [(0, 0), (dur * 0.2, 0), (dur * 0.45, 1), (dur, 0.6)])
    y = sat(y * env, drive)
    if sub_bass > 0:
        y = y + sub_bass * norm(sine(np.clip(f0 * 0.5, 28, 80)) * env, 1.0)
    return y


def gibberish(r, sylls, shift=1.25, nasal=0.5, tilt=0.9, breath=0.18, jitter=0.02):
    """Voice-like gibberish. sylls = [(consonant, vowel, dur, f0_start, f0_end, amp), ...];
    consonant in '', 'h', 'k', 't', 's', 'w', 'm', or a pause vowel '-'."""
    total = sum(s[2] for s in sylls)
    n = n_of(total + 0.05)
    f0 = np.full(n, 200.0)
    amp = np.zeros(n)
    seq = []
    cons = np.zeros(n)
    t = 0.0
    last_v = "a"
    for c, v, d, fa, fb, a in sylls:
        i0, i1 = n_of(t), n_of(t + d)
        if v == "-":
            f0[i0:i1] = f0[max(i0 - 1, 0)]
            seq.append((t, last_v))
            t += d
            continue
        m = i1 - i0
        f0[i0:i1] = np.geomspace(fa, fb, m)
        e = np.ones(m)
        at = min(m, n_of(0.02 if c in ("", "w", "m") else 0.012))
        rl = min(m, n_of(0.04))
        e[:at] = np.linspace(0, 1, at)
        e[m - rl:] *= np.linspace(1, 0.15, rl)
        amp[i0:i1] = a * e
        seq.append((t, "u" if c in ("w",) else ("ng" if c == "m" else v)))
        seq.append((t + min(0.04, d * 0.4), v))
        seq.append((t + d * 0.85, v))
        last_v = v
        if c in ("h", "k", "t", "s"):
            cl = {"h": 0.05, "k": 0.025, "t": 0.02, "s": 0.08}[c]
            band = {"h": (800, 4000), "k": (1200, 4500), "t": (2500, 8000), "s": (4000, 11000)}[c]
            b = bp(nz(r, n_of(cl)), *band) * env_exp(n_of(cl), 0.002, cl / 3)
            place(cons, b * (0.9 if c != "h" else 0.6), max(0, t - cl * 0.3))
        t += d
    seq.append((total + 0.05, last_v))
    # smooth f0 jumps between syllables a little
    f0 = onepole_lp(f0, 30) if n > 10 else f0
    f0[:n_of(0.02)] = f0[n_of(0.02)]
    amp = onepole_lp(amp, 60)
    v = voice(r, f0, seq, shift, tilt, breath, jitter, 0.1, 30, 0.0, nasal)
    return norm(v * amp, 1.0) + 0.5 * norm(cons, 1.0)
