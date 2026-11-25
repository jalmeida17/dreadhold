"""Ambience beds (stereo, seamless): continuous textures are rendered past the loop
length and equal-power crossfaded into the start; one-shot events are wrapped."""
import numpy as np
from dsp import (SR, n_of, tl, lp, hp, bp, tvf, resonators, env_pts, env_exp, freq_pts, smooth_rand, phase_of,
                 sine, saw, pink, brown, white, norm, place, pan, make_ir, convolve, rng_for, rms, church_bell, midi_hz)
from sfx_common import voice, vowel_tracks, fire, metal
import instruments as I
from music import TRACKS, LOOP_INFO


class Amb:
    def __init__(self, name, seconds, xfade=4.0, tail=6.0):
        self.name = name
        self.r = rng_for("amb", name)
        self.L = n_of(seconds)
        self.X = n_of(xfade)
        self.N = self.L + self.X + n_of(tail)
        self.bed = np.zeros((2, self.L + self.X))
        self.ev = np.zeros((2, self.N))
        LOOP_INFO[name] = f"{seconds:.1f}s ambience loop"

    def add_bed(self, st, g=1.0):
        self.bed += g * st[:, :self.L + self.X]

    def event(self, sig, t, g=1.0, p=0.0):
        if sig.ndim == 1:
            sig = pan(sig, p)
        place(self.ev, sig, t % (self.L / SR), g)

    def render(self, rt60=2.5, damp=0.5, wet=0.5, bed_wet=0.15, ev_level=1.0):
        ir = make_ir(rt60, None, True, 23, 0.02, damp, 0.3, 1.4)
        bed = self.bed + bed_wet * convolve(self.bed, ir)[:, :self.L + self.X]
        L, X = self.L, self.X
        a = np.sin(np.linspace(0, np.pi / 2, X)) ** 2
        loop = bed[:, :L].copy()
        loop[:, :X] = bed[:, :X] * np.sqrt(a) + bed[:, L:L + X] * np.sqrt(1 - a)
        ev = self.ev + wet * convolve(self.ev, ir)[:, :self.N]
        nf = n_of(1.0)
        ev[:, -nf:] *= np.cos(np.linspace(0, np.pi / 2, nf)) ** 2
        evl = ev[:, :L].copy()
        k = L
        while k < self.N:
            e = min(self.N, k + L)
            evl[:, :e - k] += ev[:, k:e]
            k += L
        out = loop + ev_level * evl
        out -= out.mean(axis=1, keepdims=True)
        return norm(out, 10 ** (-12 / 20))


def wind(r, n, center=450.0, spread=0.7, gust=0.12, q=0.8):
    common = smooth_rand(r, n, gust)
    chans = []
    for c in range(2):
        fc = center * 2 ** (spread * smooth_rand(r, n, gust * 1.7))
        y = tvf(pink(r, n), fc, q, "bp", 512)
        g = 0.3 + 0.7 * np.clip((0.7 * common + 0.3 * smooth_rand(r, n, gust * 2) + 1) / 2, 0, 1) ** 1.6
        chans.append(y * g)
    return np.array(chans)


def crow(r):
    y = np.zeros(n_of(1.6))
    t = 0.0
    for k in range(int(r.integers(2, 5))):
        d = r.uniform(0.17, 0.28)
        n = n_of(d)
        f0 = freq_pts(n, [(0, 360), (d * 0.3, 440), (d, 320)]) * r.uniform(0.9, 1.1)
        v = voice(r, f0, [(0, "a"), (d, "ae")], 1.35, 0.5, 0.7, 0.08, 0.9, 50, 0.4)
        place(y, v * env_pts(n, [(0, 0), (0.02, 1), (d * 0.7, 0.8), (d, 0)]), t)
        t += d + r.uniform(0.1, 0.2)
    return lp(hp(y, 350), 2800)


def drip(r):
    d = r.uniform(0.03, 0.06)
    n = n_of(d)
    t = tl(n)
    f0 = r.uniform(900, 2300)
    y = sine(f0 * (1 + 1.8 * t / d)) * np.exp(-t / (d / 3)) + 0.3 * sine(f0 * 2.7 * (1 + t / d)) * np.exp(-t / (d / 5))
    return y * np.clip(t / 0.0008, 0, 1)


def chains(r, dur):
    n = n_of(dur + 0.3)
    y = np.zeros(n)
    times = np.sort(r.uniform(0, dur, int(dur * r.uniform(18, 30))))
    for t in times:
        place(y, metal(r, r.uniform(1800, 4200), 0.15, r.uniform(0.02, 0.06), 0.7) * r.uniform(0.15, 1.0), t)
    return lp(y, 3500)


def creak(r, dur):
    n = n_of(dur)
    rate = freq_pts(n, [(0, r.uniform(12, 25)), (dur * 0.5, r.uniform(35, 70)), (dur, r.uniform(12, 30))])
    ph = phase_of(rate)
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float) * (0.5 + 0.5 * r.random(n))
    y = resonators(pulses, [r.uniform(250, 350), r.uniform(650, 850), r.uniform(1300, 1700), 2600], [8, 10, 12, 10], [1, 0.8, 0.5, 0.25])
    return y * env_pts(n, [(0, 0), (0.12, 1), (dur - 0.12, 1), (dur, 0)])


def whisper(r, dur):
    n = n_of(dur)
    vs = ["o", "a", "e", "i", "u", "a", "o"]
    seq = [(dur * k / 6, vs[int(r.integers(len(vs)))]) for k in range(7)]
    F = vowel_tracks(n, seq, r.uniform(0.95, 1.15))
    x = bp(white(r, n), 600, 7000)
    y = sum(g * tvf(x, Fi, float(np.mean(Fi)) / 110, "bp", 256) for Fi, g in zip(F[:3], (1, 0.7, 0.45)))
    syl = np.clip(0.5 + 0.8 * np.sin(2 * np.pi * phase_of(np.full(n, r.uniform(4.5, 7.0)))) + 0.3 * smooth_rand(r, n, 6), 0, 1)
    return y * syl * env_pts(n, [(0, 0), (0.3, 1), (dur - 0.4, 1), (dur, 0)])


# ------------------------------------------------------------------ the beds
def t_amb_keep(r):
    a = Amb("amb_keep", 48.0)
    n = a.L + a.X
    a.add_bed(norm(wind(a.r, n, 420, 0.8, 0.1, 0.7), 1.0), 1.0)
    a.add_bed(norm(wind(a.r, n, 1500, 0.5, 0.15, 2.5), 1.0), 0.25)            # high whistle in battlements
    fr = fire(a.r, n / SR, [(0, 0.6), (n / SR, 0.6)], 500, 0.6)
    a.add_bed(pan(lp(norm(fr, 1.0), 2500), -0.55), 0.12)
    for t in (3.0, 14.5, 22.0, 33.5, 41.0):
        a.event(norm(crow(a.r), 1.0), t + a.r.uniform(0, 2), 0.35, a.r.uniform(-0.8, 0.8))
    return a.render(2.8, 0.55, 0.9, 0.1)


def t_amb_crypt(r):
    a = Amb("amb_crypt", 44.0)
    n = a.L + a.X
    rum = np.array([lp(brown(a.r, n), 70) for _ in range(2)]) * (0.6 + 0.4 * smooth_rand(a.r, n, 0.08))
    a.add_bed(norm(rum, 1.0), 0.8)
    a.add_bed(norm(wind(a.r, n, 250, 0.4, 0.06, 1.2), 1.0), 0.18)
    t = 0.0
    while t < 44.0:                                                  # irregular drips + a steady leak
        a.event(norm(drip(a.r), 1.0), t, a.r.uniform(0.15, 0.45), a.r.uniform(-0.9, 0.9))
        t += a.r.uniform(0.6, 3.5)
    for k in range(int(44 / 1.9)):
        a.event(norm(drip(rng_for("leak", k % 3)), 1.0), 0.7 + k * 1.9, 0.12, 0.5)
    for t in (9.0, 27.0, 38.5):
        a.event(norm(chains(a.r, a.r.uniform(0.8, 1.6)), 1.0), t, 0.25, a.r.uniform(-0.7, 0.7))
    return a.render(3.6, 0.6, 1.2, 0.2)


def t_amb_village(r):
    a = Amb("amb_village", 50.0)
    n = a.L + a.X
    a.add_bed(norm(wind(a.r, n, 380, 0.8, 0.09, 0.7), 1.0), 1.0)
    whistle = np.array([tvf(white(a.r, n), 850 * 2 ** (0.35 * smooth_rand(a.r, n, 0.12)), 14, "bp", 512) for _ in range(2)])
    whistle *= np.clip(smooth_rand(a.r, n, 0.1) + 0.2, 0, 1) ** 2
    a.add_bed(norm(whistle, 1.0), 0.22)
    for t in (5.0, 17.0, 29.5, 43.0):
        a.event(norm(creak(a.r, a.r.uniform(0.8, 1.8)), 1.0), t, 0.3, a.r.uniform(-0.8, 0.8))
    bell = lp(church_bell(midi_hz(55), 7.0, a.r, 1.2, 0.6), 2200)
    for t in (11.0, 36.0):
        a.event(norm(bell, 1.0), t, 0.25, -0.4)
    return a.render(2.4, 0.6, 1.3, 0.1)


def t_amb_cathedral(r):
    a = Amb("amb_cathedral", 56.0, 5.0)
    n = a.L + a.X
    dur = n / SR
    org = sum(I.organ(rng_for("cath", m), midi_hz(m), dur, (("16", 0.8), ("8", 0.6)), 0.1, 0.0)[:n] for m in (26, 33))
    org *= 0.75 + 0.25 * smooth_rand(a.r, n, 0.05)
    a.add_bed(np.array([org, org * 0.98]), 1.0)
    a.add_bed(norm(wind(a.r, n, 300, 0.4, 0.05, 1.0), 1.0) * 0.08 / 1.0, 1.0)
    for t in (4.0, 12.0, 21.0, 30.0, 41.0, 49.0):
        a.event(norm(whisper(a.r, a.r.uniform(1.5, 3.0)), 1.0), t + a.r.uniform(0, 2), 0.09, a.r.uniform(-0.9, 0.9))
    return a.render(5.0, 0.5, 1.0, 0.35)


def t_amb_boss(r):
    a = Amb("amb_boss", 40.0, 4.0)
    n = a.L + a.X
    dur = n / SR
    hum = I.choir(rng_for("ambboss", "hum"), [38, 45], dur, "u", False, 4, 2.0, 1.0)[:, :n]
    throat = I.choir(rng_for("ambboss", "throat"), [38], dur, "o", False, 3, 2.0, 1.0)[:, :n]
    throat = np.array([tvf(c, 1150 * 2 ** (0.3 * smooth_rand(a.r, n, 0.07)), 9.0, "bp", 512) for c in throat])
    a.add_bed(np.pad(norm(hum, 1.0), ((0, 0), (0, max(0, n - hum.shape[1])))), 1.0)
    a.add_bed(np.pad(norm(throat, 1.0), ((0, 0), (0, max(0, n - throat.shape[1])))), 0.3)
    drum = lp(I.taiko(rng_for("ambboss", "dr"), 0.6, 1.2), 600)
    t = 0.0
    while t < 40.0:
        a.event(drum, t, 0.25)
        t += 2.5
    return a.render(4.0, 0.55, 0.8, 0.3)


for _n in ("amb_keep", "amb_crypt", "amb_village", "amb_cathedral", "amb_boss"):
    TRACKS[_n] = "amb"
