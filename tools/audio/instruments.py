"""Instrument models for music (and some SFX). Mono functions return 1-D arrays,
section/ensemble functions return stereo (2, n)."""
import numpy as np
from dsp import (SR, n_of, tl, white, pink, brown, lp, hp, bp, biquad, eq, resonators, tvf, onepole_lp,
                 env_pts, env_exp, adsr, freq_pts, smooth_rand, phase_of, sine, saw, pulse, modal, sat, norm,
                 pad_to, place, pan, ks_string, church_bell, midi_hz, vibrato_curve)


def _ctrl_additive(f0, amp_of_k, kmax, hop=64):
    """Additive synthesis with harmonic amplitudes evaluated at control rate.
    amp_of_k(k, ci) -> array of amplitudes at control indices ci."""
    n = len(f0)
    ci = np.arange(0, n, hop)
    ph = phase_of(f0)
    y = np.zeros(n)
    idx = np.arange(n)
    for k in range(1, kmax + 1):
        fk = k * f0[ci]
        if np.min(fk) > 16000:
            break
        a = amp_of_k(k, ci) * np.clip((17000 - fk) / 2000, 0, 1)
        if np.max(a) < 1e-5:
            continue
        y += np.interp(idx, ci, a) * np.sin(2 * np.pi * k * ph)
    return y


# ------------------------------------------------------------------ brass
def brass(r, f, dur, vel=0.9, att=0.07, rel=0.18, tilt_soft=2.6, tilt_loud=0.85, scoop=0.03,
          vib=10.0, wobble=0.0, fall=0.0):
    """Brass note: brightness follows the dynamic envelope (the 'blare')."""
    n = n_of(dur + rel)
    env = env_pts(n, [(0, 0), (att * 0.6, 0.8 * vel), (att, vel), (max(att + 0.01, dur), vel * 0.92), (dur + rel, 0)], 1.2)
    t = tl(n)
    f0 = f * (1 - scoop * np.exp(-t / 0.035))
    f0 = vibrato_curve(n, f0, 5.2, vib, 0.25, 0.4, r)
    f0 *= 2 ** ((wobble * smooth_rand(r, n, 0.7) + 3 * smooth_rand(r, n, 3)) / 1200)
    if fall > 0:
        f0 *= 2 ** (-fall * np.clip((t - dur * 0.7) / (dur * 0.3 + rel), 0, 1) ** 2 / 12)
    tilt = tilt_soft - (tilt_soft - tilt_loud) * np.clip(env, 0, 1) ** 1.3
    kmax = int(min(40, 14000 / f))
    y = _ctrl_additive(f0, lambda k, ci: k ** (-tilt[ci]), kmax)
    y = eq(y, [("peak", 550, 1.0, 4.0), ("peak", 1400, 1.2, 3.0), ("highshelf", 5000, 0.7, -6.0)])
    br = bp(white(r, n), 700, 3000) * env * 0.04
    return (y + br) * env


def brass_section(r, midi_notes, dur, vel=0.9, players=3, spread=0.5, detune=7.0, **kw):
    n = n_of(dur + kw.get("rel", 0.18) + 0.05)
    out = np.zeros((2, n))
    for m in np.atleast_1d(midi_notes):
        for p in range(players):
            c = detune * (2 * p / max(players - 1, 1) - 1) + r.uniform(-2, 2)
            note = brass(r, midi_hz(m) * 2 ** (c / 1200), dur, vel, **kw)
            place(out, pan(note, r.uniform(-spread, spread)), r.uniform(0, 0.025))
    return out


# ------------------------------------------------------------------ choir
CHOIR = {  # (formant freqs, bandwidths, gains dB) - sung vowels
    ("m", "a"): ([650, 1080, 2650, 2900, 3250], [80, 90, 120, 130, 140], [0, -6, -7, -8, -22]),
    ("m", "o"): ([400, 750, 2400, 2600, 2900], [40, 80, 100, 120, 120], [0, -11, -21, -20, -40]),
    ("m", "u"): ([350, 600, 2400, 2675, 2950], [40, 80, 100, 120, 120], [0, -20, -32, -28, -36]),
    ("m", "e"): ([400, 1700, 2600, 3200, 3580], [50, 80, 100, 120, 120], [0, -14, -12, -14, -20]),
    ("f", "a"): ([800, 1150, 2900, 3900, 4950], [80, 90, 120, 130, 140], [0, -6, -32, -20, -50]),
    ("f", "o"): ([450, 800, 2830, 3800, 4950], [70, 80, 100, 130, 135], [0, -11, -22, -22, -50]),
    ("f", "u"): ([325, 700, 2700, 3800, 4950], [50, 60, 170, 180, 200], [0, -16, -35, -40, -60]),
}


def vowel_filter(x, voice="m", vowel="a", shift=1.0):
    F, B, G = CHOIR[(voice, vowel)]
    F = [f * shift for f in F]
    y = resonators(x, F, [f / b for f, b in zip(F, B)], [10 ** (g / 20) for g in G])
    return y + 0.08 * lp(x, 400)


def singer(r, f, dur, att=0.25, rel=0.5, vib=16.0, female=False):
    n = n_of(dur + rel)
    f0 = f * 2 ** (r.uniform(-9, 9) / 1200)
    f0 = vibrato_curve(n, np.full(n, f0), r.uniform(4.6, 5.8), vib * r.uniform(0.6, 1.3), r.uniform(0.15, 0.4), 0.5, r)
    f0 *= 2 ** ((5 * smooth_rand(r, n, 0.6) + 2 * smooth_rand(r, n, 9)) / 1200)
    src = saw(f0, ph0=r.uniform())
    src = onepole_lp(src, 3200 if female else 2200)
    src += 0.06 * white(r, n) * (0.6 + 0.4 * smooth_rand(r, n, 3))
    env = env_pts(n, [(0, 0), (att, 1), (max(att, dur), 0.9), (dur + rel, 0)], 1.4)
    env *= 1 + 0.08 * smooth_rand(r, n, 0.8)
    return src * env


def choir(r, midi_notes, dur, vowel="a", female=False, singers=5, att=0.3, rel=0.6, spread=0.7, vib=16.0):
    """Stereo choir section singing a chord on one vowel."""
    n = n_of(dur + rel + 0.1)
    raw = np.zeros((2, n))
    for m in np.atleast_1d(midi_notes):
        for s in range(singers):
            v = singer(r, midi_hz(m), dur, att * r.uniform(0.8, 1.3), rel, vib, female)
            place(raw, pan(v, r.uniform(-spread, spread)), r.uniform(0, 0.06))
    vx = "f" if female else "m"
    out = np.array([vowel_filter(c, vx, vowel) for c in raw])
    return lp(out, 6500 if female else 5000)


# ------------------------------------------------------------------ organ
def organ(r, f, dur, stops=(("16", 0.45), ("8", 1.0), ("4", 0.5), ("223", 0.22), ("2", 0.28), ("mix", 0.12)),
          rel=0.25, chiff=0.12, trem=0.0):
    n = n_of(dur + rel)
    mult = {"32": 0.25, "16": 0.5, "8": 1.0, "4": 2.0, "223": 3.0, "2": 4.0, "135": 5.0, "mix": 6.0}
    t = tl(n)
    y = np.zeros(n)
    for name, g in stops:
        fp = f * mult[name]
        if fp > 12000:
            continue
        a = min(0.06, 6.0 / fp + 0.02)
        e = env_pts(n, [(0, 0), (a, 1), (dur, 1), (dur + rel * r.uniform(0.7, 1.0), 0)])
        detune = 1 + r.uniform(-0.0008, 0.0008)
        settle = 1 + 0.004 * np.exp(-t / 0.03)
        fr = fp * detune * settle
        pipe = sine(fr, ph0=r.uniform()) + 0.35 * sine(fr * 2) + 0.12 * sine(fr * 3) if name != "mix" else \
            sine(fr) + 0.7 * sine(fr * 1.3333) + 0.5 * sine(fr * 2)
        y += g * pipe * e
        if chiff > 0 and fp < 4000:
            ch = bp(white(r, n_of(0.08)), fp * 1.5, min(fp * 4, 15000)) * env_exp(n_of(0.08), 0.004, 0.02)
            place(y, ch * chiff * g, 0)
    if trem > 0:
        y *= 1 + trem * np.sin(2 * np.pi * 5.8 * t)
    y += 0.01 * bp(white(r, n), 300, 3000) * env_pts(n, [(0, 0), (0.05, 1), (dur, 1), (dur + rel, 0)])
    return y


# ------------------------------------------------------------------ strings
def string_player(r, f, dur, style="sustain", rel=0.25, bright=1.0):
    n = n_of(dur + rel)
    t = tl(n)
    f0 = f * 2 ** (r.uniform(-7, 7) / 1200)
    if style == "spiccato":
        f0 = np.full(n, f0)
        env = env_exp(n, 0.004, max(0.05, min(dur, 0.35) * 0.45))
    else:
        f0 = vibrato_curve(n, np.full(n, f0), r.uniform(5.0, 6.2), r.uniform(8, 16), 0.2, 0.4, r)
        a = 0.03 if style == "tremolo" else 0.12
        env = env_pts(n, [(0, 0), (a, 1), (max(a, dur), 0.95), (dur + rel, 0)], 1.3)
    src = saw(f0, ph0=r.uniform())
    bow = bp(white(r, n), 1500, 6000) * (0.08 + 0.25 * np.exp(-t / 0.03))
    if style == "tremolo":
        env = env * (0.55 + 0.45 * np.abs(np.sin(2 * np.pi * phase_of(np.full(n, 6.5 + r.uniform(-0.5, 0.5))))))
    return (src + bow) * env


def strings(r, midi_notes, dur, style="sustain", players=4, spread=0.6, rel=0.25, low=True):
    n = n_of(dur + rel + 0.05)
    out = np.zeros((2, n))
    for m in np.atleast_1d(midi_notes):
        for p in range(players):
            s = string_player(r, midi_hz(m), dur, style, rel)
            place(out, pan(s, r.uniform(-spread, spread)), r.uniform(0, 0.012 if style == "spiccato" else 0.04))
    body = [("peak", 230, 1.2, 5.0), ("peak", 520, 1.5, 3.0), ("peak", 1250, 1.2, 2.0), ("highshelf", 3500, 0.7, -9.0)] if low else \
        [("peak", 450, 1.2, 3.0), ("peak", 1100, 1.4, 2.5), ("peak", 2800, 1.2, 2.0), ("highshelf", 6000, 0.7, -8.0)]
    return lp(eq(out, body), 7000)


# ------------------------------------------------------------------ percussion
def taiko(r, vel=1.0, size=1.0):
    d = 1.4 * size
    n = n_of(d)
    t = tl(n)
    f = 58 / size * r.uniform(0.97, 1.03)
    glide = 1 + 0.45 * vel * np.exp(-t / 0.025)
    ratios = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92, 3.16]
    amps = [1.0, 0.55, 0.38, 0.3, 0.22, 0.16, 0.12]
    dec = [0.42 * size, 0.22, 0.16, 0.13, 0.11, 0.09, 0.08]
    body = modal(n, [f * k for k in ratios], [a * (vel ** (i * 0.3)) for i, a in enumerate(amps)], dec, r, 0.0008, glide)
    beater = lp(white(r, n), 1800 + 2500 * vel) * env_exp(n, 0.0005, 0.01)
    shell = bp(white(r, n), 200, 900) * env_exp(n, 0.001, 0.05)
    y = norm(body, 1.0) + 0.35 * vel * norm(beater, 1.0) + 0.25 * norm(shell, 1.0)
    return sat(y, 1.3) * vel


def tom(r, f=110.0, vel=1.0):
    n = n_of(0.8)
    t = tl(n)
    glide = 1 + 0.3 * vel * np.exp(-t / 0.02)
    body = modal(n, [f, f * 1.59, f * 2.14, f * 2.65], [1, 0.45, 0.3, 0.18], [0.22, 0.12, 0.08, 0.06], r, 0.0006, glide)
    stick = lp(white(r, n), 4000) * env_exp(n, 0.0003, 0.006)
    return (norm(body, 1.0) + 0.4 * norm(stick, 1.0)) * vel


def frame_drum(r, vel=1.0):
    n = n_of(0.5)
    t = tl(n)
    body = modal(n, [190, 305, 410, 520], [1, 0.5, 0.35, 0.2], [0.12, 0.07, 0.05, 0.04], r, 0.0005, 1 + 0.15 * np.exp(-t / 0.015))
    slap = bp(white(r, n), 700, 5000) * env_exp(n, 0.0003, 0.018)
    return (norm(body, 0.8) + norm(slap, 0.7 * vel)) * vel


def snare(r, vel=1.0):
    n = n_of(0.5)
    t = tl(n)
    shell = modal(n, [185, 330, 470], [1, 0.5, 0.3], [0.08, 0.05, 0.04], r, 0.0005, 1 + 0.1 * np.exp(-t / 0.01))
    wires = bp(white(r, n), 2500, 9000) * env_exp(n, 0.001, 0.12)
    crack = bp(white(r, n), 800, 4000) * env_exp(n, 0.0003, 0.01)
    return (0.6 * norm(shell, 1) + 0.7 * norm(wires, 1) + 0.5 * norm(crack, 1)) * vel


def sticks(r, vel=1.0):
    n = n_of(0.12)
    return (modal(n, [2100, 3400, 5200], [1, 0.6, 0.3], [0.012, 0.008, 0.005], r) + 0.5 * hp(white(r, n), 3000) * env_exp(n, 0.0002, 0.003)) * vel


def shaker(r, vel=1.0):
    n = n_of(0.15)
    return hp(white(r, n), 5000) * env_pts(n, [(0, 0), (0.025, 1), (0.15, 0)]) * vel


def timpani(r, f, vel=1.0, dur=2.5):
    n = n_of(dur)
    t = tl(n)
    body = modal(n, [f, f * 1.5, f * 1.98, f * 2.44, f * 2.95], [1, 0.6, 0.4, 0.25, 0.15],
                 [1.2, 0.6, 0.45, 0.3, 0.2], r, 0.001, 1 + 0.02 * np.exp(-t / 0.05))
    mallet = lp(white(r, n), 1500) * env_exp(n, 0.0005, 0.012)
    return (norm(body, 1.0) + 0.3 * norm(mallet, 1.0)) * vel


def anvil(r, f=900.0, vel=1.0, dur=1.6):
    n = n_of(dur)
    ratios = [1.0, 2.76, 5.40, 8.93, 1.47, 3.9]
    y = modal(n, [f * k * r.uniform(0.998, 1.002) for k in ratios], [1, 0.7, 0.45, 0.25, 0.3, 0.3],
              [0.9, 0.5, 0.3, 0.18, 0.4, 0.25], r)
    hit = hp(white(r, n), 2000) * env_exp(n, 0.0002, 0.004)
    return (norm(y, 1.0) + 0.5 * norm(hit, 1.0)) * vel


def crash(r, dur=3.0, vel=1.0):
    n = n_of(dur)
    nz = white(r, n)
    y = 0.8 * hp(nz, 4000) + 0.4 * bp(nz, 7000, 14000)
    met = modal(n, [f * r.uniform(0.98, 1.02) for f in (1310, 1980, 2620, 3490, 4810, 5840, 7270, 8900)],
                [0.3] * 8, [dur * 0.25] * 8, r)
    return (norm(y, 1.0) + 0.35 * norm(met, 1.0)) * env_exp(n, 0.002, dur * 0.28) * vel


def swell(r, dur=2.0, vel=1.0):
    """Reverse-cymbal riser peaking exactly at dur."""
    n = n_of(dur)
    y = 0.8 * hp(white(r, n), 3500) + 0.4 * bp(white(r, n), 6000, 12000)
    e = (tl(n) / dur) ** 3
    e[-n_of(0.01):] *= np.linspace(1, 0, n_of(0.01))
    return norm(y, 1.0) * e * vel


def gong(r, f=70.0, dur=6.0, vel=1.0):
    n = n_of(dur)
    t = tl(n)
    fr = [f * k * r.uniform(0.99, 1.01) for k in (1.0, 1.52, 2.0, 2.43, 2.98, 3.6, 4.3, 5.1, 6.4, 7.9, 9.3, 11.0)]
    y = modal(n, fr, [1, 0.8, 0.7, 0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2], [dur * 0.35] * 3 + [dur * 0.25] * 9, r, 0.01)
    bloom = np.clip(t / 0.4, 0, 1) ** 0.5
    return norm(y * (0.6 + 0.4 * bloom), 1.0) * vel


def sub_boom(f=45.0, dur=1.5, vel=1.0):
    n = n_of(dur)
    t = tl(n)
    y = sine(f * (1 + 0.8 * np.exp(-t / 0.04))) * env_exp(n, 0.002, dur * 0.3) * vel
    nf = n_of(0.05)
    y[n - nf:] *= np.cos(np.linspace(0, np.pi / 2, nf)) ** 2
    return y


def wet_thud(r, vel=1.0):
    """Sludgy percussion: low thud with a resonant squelch sweep and bubbles."""
    n = n_of(0.7)
    th = sine(60 * (1 + 0.6 * np.exp(-tl(n) / 0.03))) * env_exp(n, 0.001, 0.12)
    sq = tvf(white(r, n), freq_pts(n, [(0, 1400), (0.25, 180)]), 7.0, "bp") * env_exp(n, 0.003, 0.09)
    bub = np.zeros(n)
    for _ in range(4):
        d = r.uniform(0.03, 0.07)
        m = n_of(d)
        tt = tl(m)
        b = sine(r.uniform(180, 450) * (1 + 2 * tt / d)) * np.exp(-tt / (d / 3))
        place(bub, b * r.uniform(0.2, 0.6), r.uniform(0.04, 0.3))
    return (norm(th, 1.0) + 0.5 * norm(sq, 1.0) + 0.3 * norm(bub, 1.0)) * vel


# ------------------------------------------------------------------ melodic others
def lute(r, f, dur=1.2, vel=1.0, bright=0.3):
    y = ks_string(f, dur, r, decay=1.6, bright=bright, pick=r.uniform(0.12, 0.25))
    y = eq(y, [("peak", 110, 1.0, 3.0), ("peak", 250, 1.2, 4.0), ("peak", 520, 1.5, 2.0), ("highshelf", 4000, 0.7, -4)])
    y += 0.4 * ks_string(f * 2.003, dur, r, decay=1.0, bright=bright, pick=0.2)    # paired course (octave)
    return norm(y, 1.0) * vel


def pizz(r, f, vel=1.0):
    y = ks_string(f, 0.6, r, decay=0.45, bright=0.15, pick=0.35)
    return eq(y, [("peak", 220, 1.0, 4.0)]) * vel


def hurdy(r, f, dur, rel=0.15, buzz=0.3):
    n = n_of(dur + rel)
    t = tl(n)
    f0 = vibrato_curve(n, np.full(n, f), 5.5, 6, 0.3, 0.3, r) * (1 + 0.002 * smooth_rand(r, n, 8))
    src = saw(f0) + 0.5 * pulse(f0 * 1.001, 0.2)
    wheel = bp(white(r, n), 1500, 5000) * (0.6 + 0.4 * smooth_rand(r, n, 30))
    y = eq(src, [("peak", 950, 2.0, 9.0), ("peak", 2400, 2.5, 6.0), ("peak", 300, 1.0, 3.0), ("highshelf", 5000, 0.7, -8)])
    y = norm(y, 1.0) + 0.12 * norm(wheel, 1.0)
    if buzz > 0:
        g = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * phase_of(np.full(n, 11.0))))
        y += buzz * norm(bp(saw(np.full(n, f * 0.5)) * g, 400, 3000), 1.0)
    env = env_pts(n, [(0, 0), (0.05, 1), (dur, 1), (dur + rel, 0)])
    return y * env


def drone(r, f, dur, bright=500.0, beat=0.25):
    n = n_of(dur)
    y = saw(np.full(n, f)) + saw(np.full(n, f * (1 + beat / f))) + 0.5 * saw(np.full(n, f * 2.0015))
    return lp(y, bright, 2)


def bell(r, f, dur=6.0, vel=1.0, decay=1.0, bright=0.8):
    return norm(church_bell(f, dur, r, decay, bright), 1.0) * vel


def glass_harmonica(r, f, dur, rel=0.8, vel=1.0):
    n = n_of(dur + rel)
    t = tl(n)
    f0 = f * (1 + 0.0015 * smooth_rand(r, n, 2))
    y = sine(f0) + 0.06 * sine(f0 * 2) + 0.025 * sine(f0 * 3)
    y *= 1 + 0.12 * np.sin(2 * np.pi * 4.2 * t + r.uniform(0, 6))
    air = bp(white(r, n), f * 0.9, f * 1.15) * 0.03
    env = env_pts(n, [(0, 0), (0.35, 1), (dur, 0.85), (dur + rel, 0)], 1.5)
    return (y + air) * env * vel


def celesta(r, f, dur=1.5, vel=1.0):
    n = n_of(dur)
    y = modal(n, [f, f * 3.99, f * 9.1, f * 2.0], [1, 0.25, 0.06, 0.1], [0.9, 0.3, 0.1, 0.5], r, 0.0008)
    return (y + 0.08 * hp(white(r, n), 5000) * env_exp(n, 0.0002, 0.002)) * vel
