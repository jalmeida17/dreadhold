"""Core DSP helpers for the Dreadhold audio generator (numpy/scipy, 44.1 kHz).

Everything is deterministic: callers pass an explicit numpy Generator.
Mono signals are 1-D float64 arrays, stereo signals are shape (2, n).
"""
import zlib
import numpy as np
from scipy import signal

SR = 44100
NYQ = SR / 2


# ---------------------------------------------------------------- basics
def n_of(sec):
    return max(1, int(round(sec * SR)))


def tl(n):
    return np.arange(n) / SR


def seed_of(*parts):
    return zlib.crc32("|".join(str(p) for p in parts).encode()) & 0x7FFFFFFF


def rng_for(*parts):
    return np.random.default_rng(seed_of(*parts))


def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def db(x):
    return 20 * np.log10(np.maximum(np.abs(x), 1e-12))


def undb(d):
    return 10.0 ** (d / 20.0)


def peak(x):
    return float(np.max(np.abs(x))) if x.size else 0.0


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)))) if x.size else 0.0


def norm(x, p=1.0):
    pk = peak(x)
    return x * (p / pk) if pk > 1e-12 else x


def pad_to(x, n):
    if x.shape[-1] >= n:
        return x[..., :n]
    w = [(0, 0)] * (x.ndim - 1) + [(0, n - x.shape[-1])]
    return np.pad(x, w)


def place(dst, src, t, gain=1.0):
    """Add src into dst (same ndim) starting at time t (seconds)."""
    i0 = int(round(t * SR))
    if i0 >= dst.shape[-1]:
        return dst
    s0 = max(0, -i0)
    i0 = max(0, i0)
    m = min(src.shape[-1] - s0, dst.shape[-1] - i0)
    if m > 0:
        dst[..., i0:i0 + m] += gain * src[..., s0:s0 + m]
    return dst


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = n_of(fin), n_of(fout)
    n = x.shape[-1]
    a, b = min(a, n), min(b, n)
    if a > 0:
        x[..., :a] *= np.linspace(0, 1, a) ** 2
    if b > 0:
        x[..., n - b:] *= np.linspace(1, 0, b) ** 2
    return x


# ---------------------------------------------------------------- envelopes
def env_pts(n, pts, curve=1.0):
    """Breakpoint envelope. pts = [(t, v), ...]; curve>1 = convex segments."""
    t = tl(n)
    ts = np.array([p[0] for p in pts], dtype=float)
    vs = np.array([p[1] for p in pts], dtype=float)
    e = np.interp(t, ts, vs)
    if curve != 1.0:
        e = np.sign(e) * np.abs(e) ** curve
    return e


def env_exp(n, att, tau, hold=0.0):
    t = tl(n)
    e = np.exp(-np.maximum(t - att - hold, 0) / max(tau, 1e-5))
    if att > 0:
        e = np.where(t < att, (t / att) ** 1.5, e)
    return e


def adsr(n, a, d, s, r, dur=None):
    dur = n / SR if dur is None else dur
    ts = max(a + d, dur - r)
    return env_pts(n, [(0, 0), (a, 1), (a + d, s), (ts, s), (dur, 0)])


def freq_pts(n, pts):
    """Breakpoint frequency curve interpolated in log domain."""
    t = tl(n)
    ts = np.array([p[0] for p in pts], dtype=float)
    vs = np.log(np.array([p[1] for p in pts], dtype=float))
    return np.exp(np.interp(t, ts, vs))


def smooth_rand(rng, n, rate, lo=-1.0, hi=1.0):
    """Smooth random curve: random points `rate` per second, cubic-ish interp."""
    k = max(2, int(n / SR * rate) + 3)
    pts = rng.uniform(lo, hi, k)
    # evaluate the smoothstep curve at control rate, then linear-interpolate to audio rate
    m = max(2, min(n, int(n / SR * max(rate, 1.0) * 24) + 2))
    x = np.linspace(0, k - 1, m)
    i = np.minimum(np.floor(x).astype(int), k - 2)
    f = x - i
    f = f * f * (3 - 2 * f)
    c = pts[i] * (1 - f) + pts[i + 1] * f
    if m == n:
        return c
    return np.interp(np.linspace(0, m - 1, n), np.arange(m), c)


# ---------------------------------------------------------------- oscillators
def phase_of(f, ph0=0.0):
    """Cycle phase (in cycles) for a frequency array, starting at ph0."""
    f = np.broadcast_to(np.asarray(f, dtype=float), np.shape(f))
    return ph0 + np.concatenate(([0.0], np.cumsum(f[:-1]))) / SR


def sine(f, n=None, ph0=0.0):
    if np.isscalar(f):
        return np.sin(2 * np.pi * (ph0 + f * tl(n)))
    return np.sin(2 * np.pi * phase_of(f, ph0))


def _blep(ph, dt):
    y = np.zeros_like(ph)
    m = ph < dt
    t = ph[m] / dt[m]
    y[m] = t + t - t * t - 1.0
    m = ph > 1.0 - dt
    t = (ph[m] - 1.0) / dt[m]
    y[m] = t * t + t + t + 1.0
    return y


def saw(f, n=None, ph0=0.0):
    if np.isscalar(f):
        f = np.full(n, float(f))
    dt = np.minimum(f / SR, 0.49)
    ph = phase_of(f, ph0) % 1.0
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def pulse(f, pw=0.5, n=None, ph0=0.0):
    if np.isscalar(f):
        f = np.full(n, float(f))
    return 0.5 * (saw(f, ph0=ph0) - saw(f, ph0=ph0 + pw))


def tri(f, n=None, ph0=0.0):
    if np.isscalar(f):
        f = np.full(n, float(f))
    ph = phase_of(f, ph0 + 0.25) % 1.0
    return 4.0 * np.abs(ph - 0.5) - 1.0


def additive(f0, amps, n=None, ph0=None, rng=None):
    """Sum of harmonics k*f0 with amplitudes amps[k-1]; harmonics above ~18 kHz fade out."""
    if np.isscalar(f0):
        f0 = np.full(n, float(f0))
    ph = phase_of(f0)
    y = np.zeros_like(f0)
    for k, a in enumerate(amps, start=1):
        if a == 0:
            continue
        fk = k * f0
        if np.min(fk) > 18000:
            break
        g = np.clip((19000 - fk) / 2000, 0, 1)
        p0 = 0.0 if ph0 is None else ph0[k - 1]
        y += a * g * np.sin(2 * np.pi * (k * ph + p0))
    return y


def vibrato_curve(n, f, rate=5.5, depth_cents=15, delay=0.0, ramp=0.3, rng=None, wobble=0.15):
    t = tl(n)
    r = np.clip((t - delay) / max(ramp, 1e-3), 0, 1)
    rr = rate
    if rng is not None:
        rr = rate * (1 + wobble * smooth_rand(rng, n, 1.5))
    ph = np.cumsum(rr) / SR
    cents = depth_cents * r * np.sin(2 * np.pi * ph + (rng.uniform(0, 6.28) if rng is not None else 0))
    return f * 2.0 ** (cents / 1200.0)


# ---------------------------------------------------------------- noise
def white(rng, n):
    return rng.standard_normal(n) * 0.5


def pink(rng, n):
    X = np.fft.rfft(rng.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    fr[0] = fr[1] if n > 1 else 1.0
    X /= np.sqrt(fr)
    y = np.fft.irfft(X, n)
    return norm(y, 1.0) * 0.5


def brown(rng, n):
    X = np.fft.rfft(rng.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    fr[0] = fr[1] if n > 1 else 1.0
    X /= fr
    y = np.fft.irfft(X, n)
    y -= np.mean(y)
    return norm(y, 1.0) * 0.5


# ---------------------------------------------------------------- filters
def _sos(kind, fc, order=2):
    if np.ndim(fc):
        fc = [min(max(float(fc[0]), 5.0), NYQ * 0.95), min(max(float(fc[1]), 6.0), NYQ * 0.96)]
    else:
        fc = min(max(float(fc), 5.0), NYQ * 0.95)
    return signal.butter(order, fc, btype=kind, fs=SR, output="sos")


def lp(x, fc, order=2):
    return signal.sosfilt(_sos("lowpass", fc, order), x, axis=-1)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos("highpass", fc, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bandpass", (lo, hi), order), x, axis=-1)


def rbj(kind, fc, q=0.707, gain_db=0.0):
    """RBJ biquad as an sos row (b0,b1,b2,1,a1,a2)."""
    fc = min(max(fc, 5.0), NYQ * 0.95)
    w = 2 * np.pi * fc / SR
    cw, sw = np.cos(w), np.sin(w)
    al = sw / (2 * q)
    A = 10 ** (gain_db / 40)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == "bp":  # constant 0 dB peak
        b = [al, 0, -al]
        a = [1 + al, -2 * cw, 1 - al]
    elif kind == "peak":
        b = [1 + al * A, -2 * cw, 1 - al * A]
        a = [1 + al / A, -2 * cw, 1 - al / A]
    elif kind == "lowshelf":
        sa = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) - (A - 1) * cw + sa), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sa)]
        a = [(A + 1) + (A - 1) * cw + sa, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sa]
    elif kind == "highshelf":
        sa = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa)]
        a = [(A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    return np.concatenate([b, a])


def biquad(x, kind, fc, q=0.707, gain_db=0.0):
    return signal.sosfilt(rbj(kind, fc, q, gain_db)[None, :], x, axis=-1)


def eq(x, bands):
    """bands: list of (kind, fc, q, gain_db)."""
    sos = np.array([rbj(k, f, q, g) for (k, f, q, g) in bands])
    return signal.sosfilt(sos, x, axis=-1)


def resonators(x, freqs, qs, gains):
    """Parallel constant-peak band-pass bank (formants, body modes)."""
    y = np.zeros_like(x)
    for f, q, g in zip(freqs, qs, gains):
        if f < NYQ * 0.9:
            y += g * biquad(x, "bp", f, q)
    return y


def tvf(x, fc, q=0.707, kind="lp", block=64):
    """Time-varying biquad (cutoff array), coefficients updated per block."""
    n = x.shape[-1]
    fc = np.broadcast_to(np.asarray(fc, dtype=float), (n,))
    y = np.empty_like(x)
    zi = np.zeros(2)
    for s in range(0, n, block):
        e = min(n, s + block)
        c = rbj(kind, float(fc[(s + e) // 2]), q)
        yb, zi = signal.lfilter(c[:3], c[3:], x[s:e], zi=zi)
        y[s:e] = yb
    return y


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    return signal.lfilter([1 - a], [1, -a], x, axis=-1)


def comb(x, delay_s, fb):
    d = max(1, int(delay_s * SR))
    a = np.zeros(d + 1)
    a[0] = 1
    a[d] = -fb
    return signal.lfilter([1.0], a, x, axis=-1)


# ---------------------------------------------------------------- nonlinear
def sat(x, drive=2.0):
    pk = peak(x)
    if pk < 1e-12:
        return x
    return np.tanh(x / pk * drive) / np.tanh(drive) * pk


def softclip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


# ---------------------------------------------------------------- physical / modal models
def ks_string(f, dur, rng, decay=3.0, bright=0.35, pick=0.18, excite=None):
    """Karplus-Strong plucked string (tuned with fractional delay).
    decay: T60-ish seconds at the fundamental; bright: 0 (dark) .. 0.5 (bright)."""
    n = n_of(dur)
    L = SR / f
    b = float(np.clip(0.5 - bright, 0.02, 0.5))   # loop low-pass tap
    N = int(np.floor(L - b))
    fr = L - b - N
    g = 10 ** (-3 * (1.0 / f) / max(decay, 0.01))  # per-period loss for T60=decay
    taps = g * np.convolve([1 - b, b], [1 - fr, fr])
    a = np.zeros(N + 3)
    a[0] = 1.0
    a[N:N + 3] -= taps
    if excite is None:
        ex = rng.uniform(-1, 1, N)
        ex = onepole_lp(ex, 1500 + 9000 * bright)
        k = max(1, int(pick * N))
        ex = ex - np.concatenate((np.zeros(k), ex[:-k]))   # pick-position comb
    else:
        ex = excite
    x = np.zeros(n)
    m = min(len(ex), n)
    x[:m] = ex[:m]
    k = min(m, 22)                       # 0.5 ms ramp: no digital edge at the pluck onset
    x[:k] *= np.linspace(0, 1, k)
    y = hp(signal.lfilter([1.0], a, x), 30, 1)
    nf = min(n // 4, n_of(0.03))
    if nf > 1:
        y[n - nf:] *= np.cos(np.linspace(0, np.pi / 2, nf)) ** 2
    return y


def modal(n, freqs, amps, decays, rng=None, att=0.0005, glide=None):
    """Sum of exponentially decaying sinusoids. glide: optional per-sample frequency multiplier."""
    t = tl(n)
    y = np.zeros(n)
    for f, a, d in zip(freqs, amps, decays):
        if f >= NYQ * 0.92 or a == 0:
            continue
        ph0 = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        if glide is None:
            arg = 2 * np.pi * f * t + ph0
        else:
            arg = 2 * np.pi * phase_of(f * glide) + ph0
        y += a * np.exp(-t / d) * np.sin(arg)
    if att > 0:
        na = min(n, n_of(att))
        y[:na] *= np.linspace(0, 1, na)
    # modes may still ring when the buffer ends: fade the last stretch so it never clicks
    nf = min(n // 4, n_of(0.03))
    if nf > 1:
        y[n - nf:] *= np.cos(np.linspace(0, np.pi / 2, nf)) ** 2
    return y


BELL_RATIOS = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166, 5.433, 6.796, 8.215]
BELL_AMPS = [0.6, 0.5, 0.55, 0.3, 0.5, 0.25, 0.2, 0.17, 0.12, 0.08, 0.05, 0.03]
BELL_T60 = [9.0, 5.5, 4.0, 3.0, 2.8, 1.8, 1.5, 1.1, 0.8, 0.55, 0.4, 0.3]


def church_bell(f, dur, rng, decay=1.0, bright=1.0):
    n = n_of(dur)
    fr, am, dc = [], [], []
    for r, a, d in zip(BELL_RATIOS, BELL_AMPS, BELL_T60):
        for dt in (0.0, rng.uniform(0.6, 1.6)):           # doublets -> beating
            fr.append(f * r + dt * (r > 0.6))
            am.append(a * (0.6 if dt else 1.0) * (bright if r > 2.2 else 1.0))
            dc.append(d * decay / 6.9)
    y = modal(n, fr, am, dc, rng, att=0.001)
    clang = bp(white(rng, n), 1500, 6000) * env_exp(n, 0.0005, 0.012)
    return y + 0.25 * bright * clang


# ---------------------------------------------------------------- reverb
_IR_CACHE = {}


def make_ir(rt60=1.6, dur=None, stereo=True, seed=1, pre=0.012, damp=0.5, early=0.35, size=1.0):
    """Synthetic room impulse response: multiband exponentially decaying noise
    (highs decay faster, controlled by damp) + sparse early reflections."""
    key = (rt60, dur, stereo, seed, pre, damp, early, size)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    rng = np.random.default_rng(seed)
    dur = dur or min(rt60 * 1.3, 8.0)
    n = n_of(dur)
    t = tl(n)
    bands = [(20, 250, 1.15), (250, 1000, 1.0), (1000, 3000, 0.8 - 0.3 * damp),
             (3000, 7000, 0.6 - 0.35 * damp), (7000, 20000, 0.4 - 0.3 * damp)]
    chans = []
    for c in range(2 if stereo else 1):
        acc = np.zeros(n)
        for lo, hi, k in bands:
            r = rt60 * max(k, 0.08)
            nb = bp(rng.standard_normal(n), lo, min(hi, NYQ * 0.95), 2)
            acc += nb * np.exp(-6.9 * t / r)
        # soft onset of the diffuse tail
        acc *= np.clip((t - pre) / (0.03 * size), 0, 1) ** 1.5
        er = np.zeros(n)
        for _ in range(int(14 * size)):
            d = pre + rng.uniform(0.002, 0.07 * size)
            i = int(d * SR)
            if i < n:
                er[i] += rng.uniform(-1, 1) * np.exp(-d * 18)
        er = lp(er, 6000 - 3000 * damp)
        acc = acc / (np.sqrt(np.sum(acc ** 2)) + 1e-12)
        er = er / (np.sqrt(np.sum(er ** 2)) + 1e-12)
        chans.append(acc + early * er)
    ir = np.array(chans) if stereo else chans[0]
    _IR_CACHE[key] = ir
    return ir


def convolve(x, ir):
    """FFT convolution; mono x with mono IR -> mono, mono/stereo x with stereo IR -> stereo."""
    if ir.ndim == 1:
        return signal.fftconvolve(x, ir, axes=-1) if x.ndim == 1 else np.array([signal.fftconvolve(c, ir) for c in x])
    if x.ndim == 1:
        return np.array([signal.fftconvolve(x, c) for c in ir])
    return np.array([signal.fftconvolve(x[i], ir[i]) for i in range(2)])


def reverb(x, wet=0.2, rt60=1.4, damp=0.5, pre=0.012, seed=7, dry=1.0, tail=None, early=0.35):
    """Dry + convolution reverb. Mono in -> mono out (mono IR); stereo in -> stereo out."""
    st = x.ndim == 2
    ir = make_ir(rt60, None, st, seed, pre, damp, early)
    w = convolve(x, ir)
    n = x.shape[-1] + (n_of(tail) if tail is not None else w.shape[-1] - x.shape[-1])
    out = pad_to(x * dry, n) + wet * pad_to(w, n)
    return out


# ---------------------------------------------------------------- stereo
def pan(x, p):
    """Constant-power pan of a mono signal, p in [-1, 1]."""
    a = (p + 1) * np.pi / 4
    return np.array([x * np.cos(a), x * np.sin(a)])


def widen(st, amount=0.3, delay_ms=11.0):
    """Mid/side style widening using a short delayed side component."""
    mid = 0.5 * (st[0] + st[1])
    d = int(delay_ms * SR / 1000)
    side = 0.5 * (st[0] - st[1]) + amount * np.concatenate((np.zeros(d), mid[:-d])) * 0.5
    return np.array([mid + side, mid - side])


def to_stereo(x):
    return x if x.ndim == 2 else np.array([x, x])


def addl(*xs):
    """Sum arrays of different lengths (zero-padded to the longest)."""
    n = max(x.shape[-1] for x in xs)
    out = np.zeros(xs[0].shape[:-1] + (n,))
    for x in xs:
        out[..., :x.shape[-1]] += x
    return out
