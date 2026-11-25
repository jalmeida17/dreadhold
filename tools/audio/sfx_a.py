"""SFX recipes part A: UI, warrior, mage, hunter, player, items/economy, elements.
Each s_<name>(r) returns a mono float array (normalised later)."""
import numpy as np
from dsp import (addl, SR, n_of, tl, lp, hp, bp, biquad, eq, tvf, env_pts, env_exp, freq_pts, smooth_rand,
                 sine, saw, modal, sat, norm, place, ks_string, church_bell, midi_hz, comb, phase_of)
from sfx_common import (room, mixdown, nz, thump, burst, whoosh, crackle, fire, stone_ping, debris,
                        bubble, sizzle, metal, wood_knock, glass_pings, voice, poisson_times, grains)


# ------------------------------------------------------------------ UI
def s_ui_hover(r):
    n = n_of(0.09)
    tick = wood_knock(r, 1450, 0.09, 0.007)
    air = burst(r, 0.09, 3000, 9000, 0.0005, 0.004)
    return room(lp(norm(tick, 0.8) + 0.12 * norm(air, 1), 5000), 0.08, 0.5, 0.6)


def s_ui_click(r):
    st = stone_ping(r, 950, 0.012)
    knock = thump(0.08, 420, 210, 0.006, 0.014)
    grit = crackle(r, 0.03, [(0, 4000), (0.03, 0)], 0.05, 0.3, 2500)
    y = mixdown(n_of(0.12), (norm(st, 0.8), 0, 1), (norm(knock, 0.7), 0, 1), (norm(grit, 0.25), 0, 1))
    return room(y, 0.12, 0.6, 0.55)


def s_ui_confirm(r):
    n = n_of(0.5)
    bar = [1.0, 2.756, 5.404, 8.933]
    def strike(f):
        return modal(n, [f * k for k in bar] + [f * 1.003], [1, 0.4, 0.2, 0.08, 0.5], [0.28, 0.12, 0.06, 0.03, 0.3], r)
    y = mixdown(n, (norm(strike(midi_hz(79)), 0.7), 0, 1), (norm(strike(midi_hz(86)), 0.9), 0.075, 1),
                (norm(burst(r, 0.03, 4000, 12000, 0.0003, 0.004), 0.25), 0.075, 1))
    return room(y, 0.2, 1.0, 0.35)


# ------------------------------------------------------------------ warrior
def s_swing(r):
    d = 0.36
    a = [(0, 0), (0.07, 0.4), (0.13, 1), (0.22, 0.45), (d, 0)]
    body = whoosh(r, d, [(0, 300), (0.13, 1100), (d, 380)], a, 1.4, "pink", 0.5, 55)
    low = whoosh(r, d, [(0, 90), (0.13, 220), (d, 100)], a, 0.8, "brown", 0.4, 30)
    edge = whoosh(r, d, [(0, 2500), (0.13, 5200), (d, 2200)], [(0, 0), (0.1, 0.0), (0.13, 1), (0.2, 0)], 2.5)
    y = norm(body, 0.8) + norm(low, 0.65) + norm(edge, 0.18)
    return room(y, 0.12, 1.0, 0.6)


def s_spin(r):
    d = 0.8
    n = n_of(d)
    rate = env_pts(n, [(0, 3.0), (0.4, 4.8), (d, 4.0)])
    ph = np.cumsum(rate) / SR
    s = np.sin(2 * np.pi * ph - np.pi / 2)
    fc = 600 * 2 ** (1.2 * s)
    am = (0.25 + 0.75 * ((s + 1) / 2) ** 2)
    x = tvf(nz(r, n, "pink"), fc, 1.5, "bp") * am * (1 + 0.4 * smooth_rand(r, n, 50))
    lo = tvf(nz(r, n, "brown"), fc * 0.25, 0.8, "bp") * am
    y = (norm(x, 0.85) + norm(lo, 0.55)) * env_pts(n, [(0, 0), (0.08, 1), (0.6, 0.85), (d, 0)])
    return room(y, 0.15, 1.0, 0.6)


def s_charge(r):
    d = 0.62
    rush = whoosh(r, d, [(0, 250), (0.32, 1200), (d, 600)], [(0, 0), (0.3, 1), (0.4, 0.5), (d, 0)], 1.0, "pink", 0.5, 45)
    lo = whoosh(r, d, [(0, 80), (0.32, 200), (d, 120)], [(0, 0), (0.3, 1), (d, 0)], 0.7, "brown")
    ts = 0.32
    stomp = thump(0.3, 150, 42, 0.025, 0.09)
    dirt = burst(r, 0.2, 0, 900, 0.001, 0.035, "pink")
    mail = np.zeros(n_of(0.25))
    for j in range(7):
        place(mail, metal(r, r.uniform(2400, 4200), 0.12, 0.03, 0.8) * r.uniform(0.3, 1), j * 0.014 + r.uniform(0, 0.008))
    y = mixdown(n_of(d), (norm(rush, 0.6), 0, 1), (norm(lo, 0.4), 0, 1), (norm(stomp, 1.0), ts, 1),
                (norm(dirt, 0.5), ts, 1), (norm(mail, 0.3), ts, 1), (norm(debris(r, 0.25, [(0, 300), (0.25, 0)], 300, 1500), 0.25), ts, 1))
    return room(sat(y, 1.3), 0.15, 1.1, 0.55)


def s_hit_flesh(r):
    d = 0.32
    n = n_of(d)
    thud = thump(d, 160, 52, 0.02, 0.07)
    body = burst(r, d, 0, 700, 0.001, 0.035, "pink")
    smack = burst(r, 0.05, 800, 4000, 0.0003, 0.006)
    squelch = whoosh(r, 0.2, [(0, 1600), (0.2, 300)], [(0, 0), (0.008, 1), (0.2, 0)], 4.0)
    wet = sizzle(r, 0.18, [(0, 1), (0.18, 0)], 900, 4500, 160)
    crunch = crackle(r, 0.07, [(0, 1500), (0.07, 0)], 0.2, 1.2, 1200, 5000)
    y = mixdown(n, (norm(thud, 1.0), 0, 1), (norm(body, 0.7), 0, 1), (norm(smack, 0.45), 0, 1),
                (norm(squelch, 0.35), 0.01, 1), (norm(wet, 0.18), 0.015, 1), (norm(crunch, 0.25), 0.004, 1))
    return room(sat(y, 1.6), 0.08, 0.8, 0.6)


def s_hit_bone(r):
    d = 0.3
    crack = burst(r, 0.05, 1800, 12000, 0.0002, 0.0035)
    snap = wood_knock(r, 1250, 0.08, 0.009)
    knock = thump(0.1, 520, 300, 0.008, 0.02)
    y = mixdown(n_of(d), (norm(crack, 1.0), 0, 1), (norm(snap, 0.6), 0, 1), (norm(knock, 0.4), 0, 1))
    t = 0.012
    for j in range(6):
        t += r.uniform(0.012, 0.03)
        place(y, norm(wood_knock(r, r.uniform(1100, 2600), 0.06, r.uniform(0.004, 0.01)), 0.45 * 0.78 ** j), t)
    return room(y, 0.1, 0.9, 0.55)


def s_hit_metal(r):
    d = 0.6
    clang = metal(r, r.uniform(410, 450), d, 0.22, 1.0)
    clang2 = metal(r, 655, d, 0.1, 0.7, (1.0, 2.7, 4.2, 5.9))
    tr = burst(r, 0.03, 2500, 14000, 0.0002, 0.003)
    scrape = whoosh(r, 0.15, [(0, 6000), (0.15, 3500)], [(0, 0), (0.005, 1), (0.15, 0)], 6.0)
    thud = thump(0.12, 220, 120, 0.015, 0.03)
    y = mixdown(n_of(d), (norm(clang, 0.85), 0, 1), (norm(clang2, 0.4), 0.002, 1), (norm(tr, 0.7), 0, 1),
                (norm(scrape, 0.15), 0.005, 1), (norm(thud, 0.35), 0, 1))
    return room(y, 0.16, 1.2, 0.45)


# ------------------------------------------------------------------ mage
def s_fireball_cast(r):
    d = 0.62
    n = n_of(d)
    # ignition: a quick strike + a burst of sparks
    strike = burst(r, 0.05, 1500, 9000, 0.0005, 0.008)
    sparks = crackle(r, 0.25, [(0, 2500), (0.25, 0)], 0.1, 0.9, 2500)
    pop = thump(0.12, 300, 90, 0.01, 0.03)
    # roaring whoosh: fire texture swept upward
    roar = fire(r, d, [(0, 0), (0.12, 0.6), (0.3, 1), (d, 0)], 900, 0.8)
    roar = tvf(roar, freq_pts(n, [(0, 500), (0.3, 2200), (d, 900)]), 0.9, "bp") + 0.5 * lp(roar, 500)
    whsh = whoosh(r, d, [(0, 400), (0.32, 2400), (d, 1100)], [(0, 0), (0.28, 1), (d, 0)], 1.1, "pink", 0.5, 60)
    y = mixdown(n, (norm(strike, 0.5), 0, 1), (norm(sparks, 0.45), 0.01, 1), (norm(pop, 0.5), 0.0, 1),
                (norm(roar, 0.9), 0.02, 1), (norm(whsh, 0.5), 0.02, 1))
    return room(y, 0.15, 1.1, 0.55)


def s_fireball_explode(r):
    d = 1.6
    n = n_of(d)
    sub = thump(d, 95, 30, 0.06, 0.32)
    crack = burst(r, 0.04, 600, 9000, 0.0002, 0.006)
    body = tvf(nz(r, n, "pink"), freq_pts(n, [(0, 5000), (0.06, 1800), (0.5, 350), (d, 150)]), 0.7, "lp") * env_exp(n, 0.002, 0.25)
    rumble = lp(nz(r, n, "brown"), 160) * env_exp(n, 0.02, 0.55)
    flames = fire(r, d, [(0, 0), (0.05, 1), (0.6, 0.5), (d, 0)], 800, 0.9)
    sparks = crackle(r, d, [(0, 900), (0.3, 400), (1.0, 60), (d, 0)], 0.1, 1.5, 2000)
    rocks = debris(r, d, [(0, 0), (0.05, 120), (0.6, 30), (1.2, 0)], 300, 2200)
    core = sat(addl(norm(sub, 1.0), norm(body, 0.9), norm(crack, 0.6)), 2.2)
    y = mixdown(n, (core, 0, 1), (norm(rumble, 0.5), 0, 1), (norm(flames, 0.35), 0.03, 1),
                (norm(sparks, 0.3), 0.01, 1), (norm(rocks, 0.3), 0.04, 1))
    return room(y, 0.22, 1.8, 0.55)


def s_frost_nova(r):
    d = 1.3
    n = n_of(d)
    hit = thump(0.3, 170, 70, 0.02, 0.07)
    burst_hi = burst(r, d, 3000, 16000, 0.001, 0.07)
    crystals = glass_pings(r, d, 28, 2000, 9500, 0.2, (0.15, 0.7))
    crystals *= 1 + 0.25 * smooth_rand(r, n, 14)
    cracks = crackle(r, d, [(0, 600), (0.3, 150), (0.8, 20), (d, 0)], 0.08, 0.6, 2500)
    wind = whoosh(r, 0.9, [(0, 5000), (0.9, 900)], [(0, 0), (0.02, 1), (0.9, 0)], 1.0, "pink", 0.3, 25)
    y = mixdown(n, (norm(hit, 0.45), 0, 1), (norm(burst_hi, 0.4), 0, 1), (norm(crystals, 0.65), 0, 1),
                (norm(cracks, 0.45), 0, 1), (norm(wind, 0.4), 0, 1))
    return room(y, 0.28, 1.8, 0.15)


def s_blink(r):
    d = 0.45
    n = n_of(d)
    f1 = freq_pts(n, [(0, 220), (0.16, 2400), (d, 2400)])
    up = (sine(f1 * (1 + 0.05 * np.sin(2 * np.pi * 30 * tl(n)))) + 0.3 * sine(f1 * 2.01)) * env_pts(n, [(0, 0), (0.01, 1), (0.15, 0.7), (0.2, 0)])
    f2 = freq_pts(n, [(0, 3000), (0.12, 3000), (0.32, 260), (d, 260)])
    down = sine(f2) * env_pts(n, [(0, 0), (0.12, 0), (0.14, 0.6), (0.32, 0)])
    noise = nz(r, n, "pink")
    ph = comb(noise, 0.004, 0.6)
    swirl = tvf(ph, freq_pts(n, [(0, 700), (0.15, 6000), (d, 1200)]), 3.0, "bp") * env_pts(n, [(0, 0), (0.13, 1), (d, 0)])
    pop = thump(0.06, 900, 300, 0.005, 0.01)
    y = mixdown(n, (norm(up, 0.6), 0, 1), (norm(down, 0.45), 0, 1), (norm(swirl, 0.5), 0, 1), (norm(pop, 0.4), 0.135, 1))
    return room(y, 0.22, 1.2, 0.3)


def s_frost_cast(r):
    d = 0.85
    n = n_of(d)
    rise = freq_pts(n, [(0, 700), (0.75, 2600)])
    glass = sum(sine(rise * k * (1 + 0.003 * j)) * a for j, (k, a) in enumerate([(1, 1), (2.01, 0.3), (2.99, 0.15)]))
    glass *= env_pts(n, [(0, 0), (0.7, 1), (0.76, 0)]) * (1 + 0.3 * np.sin(2 * np.pi * freq_pts(n, [(0, 6), (0.75, 18)]).cumsum() / SR))
    swell = tvf(nz(r, n), freq_pts(n, [(0, 2000), (0.75, 9000)]), 1.5, "bp") * env_pts(n, [(0, 0), (0.74, 1), (0.77, 0)])
    sparkle = glass_pings(r, d, 18, 3000, 9000, 0.7, (0.04, 0.15)) * env_pts(n, [(0, 0.2), (0.75, 1), (d, 1)])
    tick = glass_pings(r, 0.2, 4, 2500, 6000, 0.01, (0.05, 0.2))
    y = mixdown(n, (norm(glass, 0.45), 0, 1), (norm(swell, 0.4), 0, 1), (norm(sparkle, 0.3), 0, 1), (norm(tick, 0.6), 0.75, 1))
    return room(y, 0.25, 1.5, 0.2)


def s_ice_shatter(r):
    d = 0.9
    n = n_of(d)
    crack = burst(r, 0.04, 1500, 15000, 0.0002, 0.005)
    thud = thump(0.15, 300, 140, 0.01, 0.03)
    shards = glass_pings(r, d, 45, 1800, 10000, 0.12, (0.03, 0.35))
    tinkle = np.zeros(n)
    for t in poisson_times(r, d, [(0, 0), (0.08, 60), (0.5, 20), (d, 0)]):
        place(tinkle, glass_pings(r, 0.2, 1, 3000, 9000, 0.0, (0.02, 0.08)) * r.uniform(0.1, 0.6), t)
    hiss = burst(r, 0.4, 5000, 15000, 0.001, 0.06)
    y = mixdown(n, (norm(crack, 1.0), 0, 1), (norm(thud, 0.4), 0, 1), (norm(shards, 0.7), 0, 1),
                (norm(tinkle, 0.35), 0, 1), (norm(hiss, 0.2), 0, 1))
    return room(y, 0.2, 1.4, 0.15)


# ------------------------------------------------------------------ hunter
def bow_release(r, thrum_f=110.0, zip_hi=3800.0, zip_lo=1500.0, zip_len=0.25, weight=1.0):
    n = n_of(zip_len + 0.06)
    st = ks_string(thrum_f, 0.18, r, decay=0.6, bright=0.12, pick=0.3) * env_exp(n_of(0.18), 0.0005, 0.03)
    body = thump(0.12, thrum_f * 1.5, thrum_f * 0.9, 0.012, 0.03)
    puff = burst(r, 0.08, 0, 500, 0.0008, 0.016, "pink")
    knock = addl(wood_knock(r, r.uniform(640, 760), 0.08, 0.01), 0.6 * wood_knock(r, r.uniform(1500, 1750), 0.06, 0.006))
    zn = n_of(zip_len)
    ze = env_exp(zn, 0.02, zip_len * 0.28) * env_pts(zn, [(0, 1), (zip_len * 0.7, 1), (zip_len, 0)])
    zp = tvf(nz(r, zn), freq_pts(zn, [(0, zip_hi), (zip_len, zip_lo)]), 2.0, "bp") * ze
    fl = 1 + 0.25 * np.sin(2 * np.pi * 55 * tl(zn))          # fletching flutter
    crisp = hp(nz(r, zn), 6000) * ze
    return mixdown(n, (norm(st, 0.8 * weight), 0, 1), (norm(body, 0.6 * weight), 0, 1), (norm(puff, 0.45 * weight), 0, 1),
                   (norm(knock, 0.4), 0, 1), (norm(zp * fl, 0.55), 0.008, 1), (norm(crisp, 0.12), 0.008, 1))


def s_bow_shoot(r):
    return room(bow_release(r), 0.1, 0.9, 0.55)


def s_volley(r):
    y = np.zeros(n_of(0.6))
    for j, (t, f) in enumerate([(0, 112), (0.05, 126), (0.1, 106), (0.16, 134), (0.23, 120)]):
        b = bow_release(r, f, r.uniform(3300, 4100), r.uniform(1300, 1700), r.uniform(0.22, 0.27))
        place(y, norm(b, [1, 0.85, 0.9, 0.75, 0.8][j]), t + r.uniform(0, 0.01))
    return room(y, 0.1, 0.9, 0.55)


def s_enemy_arrow(r):
    return room(bow_release(r, 170, 4400, 1900, 0.2, 0.7), 0.1, 0.9, 0.55)


def s_arrow_hit(r):
    d = 0.35
    n = n_of(d)
    tip = burst(r, 0.02, 2000, 10000, 0.0002, 0.002)
    thunk = addl(wood_knock(r, 380, 0.15, 0.03), 0.5 * thump(0.12, 300, 160, 0.012, 0.03))
    t = tl(n)
    quiver = sine(np.full(n, 70.0)) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) * np.exp(-t / 0.07)
    shaft = ks_string(310, d, r, 0.3, 0.2, 0.5) * np.exp(-t / 0.06)
    y = mixdown(n, (norm(tip, 0.6), 0, 1), (norm(thunk, 0.95), 0.001, 1), (norm(quiver, 0.3), 0.004, 1), (norm(shaft, 0.25), 0.002, 1))
    return room(y, 0.1, 0.9, 0.55)


def s_dash(r):
    d = 0.34
    a = [(0, 0), (0.06, 1), (d, 0)]
    y = norm(whoosh(r, d, [(0, 500), (0.09, 1900), (d, 550)], a, 1.2, "pink", 0.4, 60), 0.8)
    y += norm(whoosh(r, d, [(0, 140), (0.09, 330), (d, 140)], a, 0.8, "brown"), 0.5)
    for t in (0.0, 0.045):
        place(y, norm(burst(r, 0.05, 500, 1600, 0.002, 0.01), 0.3), t)    # leather flaps
    return room(y, 0.1, 0.9, 0.6)


# ------------------------------------------------------------------ player
def s_player_hurt(r):
    d = 0.34
    n = n_of(d)
    v = voice(r, freq_pts(n, [(0, 135), (0.04, 165), (d, 100)]), [(0, "uh"), (0.08, "a"), (d, "uh")], 1.0, 0.75, 0.3, 0.02, 0.2, 40, 0.1)
    v *= env_pts(n, [(0, 0), (0.012, 1), (0.1, 0.8), (d, 0)])
    return room(sat(v, 1.6), 0.1, 0.9, 0.55)


def s_player_death(r):
    d = 1.5
    n = n_of(d)
    t = tl(n)
    f0 = freq_pts(n, [(0, 165), (0.12, 185), (0.6, 140), (d, 78)]) * (1 + 0.025 * (t / d) * np.sin(2 * np.pi * 6.5 * t))
    v = voice(r, f0, [(0, "a"), (0.5, "a"), (0.95, "o"), (d, "u")], 1.0, 0.85, 0.35, 0.025, 0.25, 35, 0.15)
    v *= env_pts(n, [(0, 0), (0.05, 1), (0.55, 0.9), (1.0, 0.45), (d, 0)])
    exhale = bp(nz(r, n, "pink"), 400, 2500)
    exhale *= env_pts(n, [(0, 0), (1.0, 0), (1.2, 1), (d, 0)])
    thud = thump(0.3, 110, 50, 0.02, 0.08) + 0.4 * burst(r, 0.3, 0, 600, 0.002, 0.05, "pink")
    y = mixdown(n_of(d + 0.1), (norm(sat(v, 1.5), 0.9), 0, 1), (norm(exhale, 0.2), 0, 1), (norm(thud, 0.5), 1.15, 1))
    return room(y, 0.18, 1.3, 0.55)


def s_potion_drink(r):
    d = 0.78
    y = np.zeros(n_of(d))
    for j, t0 in enumerate([0.0, 0.2, 0.4]):
        t0 += r.uniform(0, 0.02)
        gn = n_of(0.14)
        gulp = thump(0.14, 120 + 10 * j, 70, 0.03, 0.05)
        sw = freq_pts(gn, [(0, 260 + 20 * j), (0.1, 620 + 30 * j)])
        liquid = tvf(nz(r, gn), sw * 1.5, 6.0, "bp") * env_exp(gn, 0.004, 0.04)
        tone = sine(sw) * env_pts(gn, [(0, 0), (0.008, 1), (0.06, 0.5), (0.14, 0)])
        place(y, norm(gulp, 0.6) + norm(liquid, 0.4) + norm(tone, 0.5), t0, 1 - 0.08 * j)
        for k in range(4):
            place(y, norm(bubble(r, r.uniform(500, 1300)), 0.22), t0 + r.uniform(0.02, 0.16))
    place(y, norm(thump(0.1, 140, 80, 0.015, 0.03), 0.4), 0.62)       # final swallow
    place(y, norm(bp(nz(r, n_of(0.12), "pink"), 500, 2500) * env_pts(n_of(0.12), [(0, 0), (0.03, 1), (0.12, 0)]), 0.15), 0.66)
    return room(y, 0.08, 0.8, 0.6)


def coin(r, f, dur=0.35):
    n = n_of(dur)
    ratios = [1.0, 1.6, 2.13, 2.65, 3.36, 4.1]
    y = modal(n, [f * k * r.uniform(0.995, 1.005) for k in ratios] + [f * 1.004],
              [1, 0.7, 0.5, 0.35, 0.25, 0.15, 0.6], [0.16, 0.12, 0.09, 0.07, 0.05, 0.04, 0.17], r)
    return addl(y, 0.3 * burst(r, dur, 4000, 15000, 0.0002, 0.002))


def s_coin_pickup(r):
    y = mixdown(n_of(0.4), (norm(coin(r, 2350), 0.75), 0, 1), (norm(coin(r, 3150), 0.9), 0.07, 1))
    return room(y, 0.12, 0.9, 0.4)


def s_purchase(r):
    y = np.zeros(n_of(0.8))
    for j in range(7):
        place(y, norm(coin(r, r.uniform(2000, 3400), 0.3), r.uniform(0.3, 0.8)), 0.02 + j * 0.035 + r.uniform(0, 0.015))
    clunk = addl(wood_knock(r, 210, 0.3, 0.05), 0.7 * thump(0.25, 160, 80, 0.015, 0.05))
    latch = metal(r, 1200, 0.25, 0.04, 0.6)
    place(y, norm(clunk, 0.9), 0.32)
    place(y, norm(latch, 0.35), 0.33)
    return room(y, 0.12, 1.0, 0.55)


def s_item_pickup(r):
    d = 0.6
    y = np.zeros(n_of(d))
    for j, m in enumerate([76, 83, 88]):
        nn = n_of(d - j * 0.06)
        f = midi_hz(m)
        s = modal(nn, [f, f * 2.0, f * 3.0, f * 4.01], [1, 0.25, 0.08, 0.04], [0.3, 0.18, 0.1, 0.06], r, att=0.004)
        place(y, norm(s, 0.6), j * 0.06)
    sh = hp(nz(r, n_of(d)), 7000) * env_pts(n_of(d), [(0, 0), (0.1, 1), (d, 0)])
    return room(addl(y, norm(sh, 0.06)), 0.28, 1.6, 0.25)


def _step(r, weight=1.0, grit=0.3):
    d = 0.16
    heel = thump(d, 105 * r.uniform(0.9, 1.1), 55, 0.012, 0.025)
    sole = burst(r, d, 0, 900 * r.uniform(0.8, 1.2), 0.002, 0.022, "pink")
    scuff = burst(r, 0.07, 1500, 6000, 0.004, 0.014)
    gr = crackle(r, 0.07, [(0, 600), (0.07, 0)], 0.08, 0.4, 2500)
    return mixdown(n_of(d), (norm(heel, 0.7 * weight), 0, 1), (norm(sole, 0.8), 0.002, 1),
                   (norm(scuff, 0.18), 0.012, 1), (norm(gr, grit * 0.5), 0.01, 1))


def s_footstep(r):
    return room(_step(r), 0.07, 0.7, 0.6)


def s_footstep_1(r):
    return room(_step(r, 1.0, 0.3), 0.07, 0.7, 0.6)


def s_footstep_2(r):
    return room(_step(r, 0.85, 0.45), 0.07, 0.7, 0.6)


def s_footstep_3(r):
    return room(_step(r, 1.1, 0.2), 0.07, 0.7, 0.6)


def s_jump(r):
    d = 0.3
    cloth = whoosh(r, d, [(0, 600), (0.1, 1600), (d, 700)], [(0, 0), (0.05, 1), (d, 0)], 1.2, "pink", 0.5, 70)
    push = _step(r, 0.6, 0.2)
    effort = voice(r, freq_pts(n_of(0.12), [(0, 150), (0.12, 135)]), [(0, "uh"), (0.12, "uh")], 1.0, 1.0, 0.6, 0.02)
    effort *= env_pts(n_of(0.12), [(0, 0), (0.015, 1), (0.12, 0)])
    gear = np.zeros(n_of(0.15))
    for j in range(3):
        place(gear, metal(r, r.uniform(2500, 4000), 0.08, 0.02, 0.6) * r.uniform(0.3, 1), j * 0.02 + r.uniform(0, 0.01))
    y = mixdown(n_of(d), (norm(push, 0.7), 0, 1), (norm(cloth, 0.5), 0.01, 1), (norm(effort, 0.2), 0.01, 1), (norm(gear, 0.15), 0.03, 1))
    return room(y, 0.08, 0.8, 0.6)


def s_land(r):
    d = 0.4
    impact = thump(d, 120, 45, 0.015, 0.06)
    sole = burst(r, d, 0, 800, 0.001, 0.04, "pink")
    grit = crackle(r, 0.15, [(0, 1200), (0.15, 0)], 0.1, 0.6, 2000)
    gear = np.zeros(n_of(0.25))
    for j in range(5):
        place(gear, metal(r, r.uniform(2200, 4200), 0.1, 0.025, 0.6) * r.uniform(0.3, 1), j * 0.018 + r.uniform(0, 0.01))
    y = mixdown(n_of(d), (norm(impact, 1.0), 0, 1), (norm(sole, 0.7), 0, 1), (norm(grit, 0.3), 0.005, 1), (norm(gear, 0.2), 0.01, 1))
    return room(sat(y, 1.4), 0.1, 0.9, 0.55)


def s_heartbeat(r):
    d = 0.9
    def beat(g):
        b = addl(thump(0.25, 62, 38, 0.03, 0.06), 0.25 * thump(0.2, 120, 60, 0.01, 0.02))
        return lp(addl(b, 0.15 * lp(burst(r, 0.25, 0, 300, 0.004, 0.03, "brown"), 250)), 300) * g
    y = mixdown(n_of(d), (norm(beat(1), 1.0), 0.02, 1), (norm(beat(1), 0.75), 0.27, 1))
    return sat(y, 1.3)


def s_torch_ignite(r):
    d = 1.0
    n = n_of(d)
    whoomp = whoosh(r, 0.5, [(0, 120), (0.15, 700), (0.5, 300)], [(0, 0), (0.08, 1), (0.5, 0)], 0.8, "brown")
    low = thump(0.4, 90, 45, 0.04, 0.12)
    flame = fire(r, d, [(0, 0), (0.12, 1), (0.6, 0.6), (d, 0.25)], 800, 0.7)
    strike = burst(r, 0.04, 1200, 8000, 0.0005, 0.006)
    y = mixdown(n, (norm(strike, 0.4), 0, 1), (norm(whoomp, 0.85), 0.02, 1), (norm(low, 0.6), 0.02, 1), (norm(flame, 0.5), 0.05, 1))
    return room(y, 0.12, 1.0, 0.55)


# ------------------------------------------------------------------ elements (boss mechanics)
def s_acid_splash(r):
    d = 0.9
    n = n_of(d)
    splat = tvf(nz(r, n, "pink"), freq_pts(n, [(0, 3000), (0.05, 900), (0.3, 300)]), 0.8, "lp") * env_exp(n, 0.002, 0.06)
    slap = burst(r, 0.04, 600, 5000, 0.0003, 0.006)
    drops = np.zeros(n)
    for t in poisson_times(r, 0.5, [(0, 0), (0.02, 90), (0.5, 0)]):
        place(drops, bubble(r, r.uniform(400, 1500)) * r.uniform(0.2, 1), t)
    hiss = sizzle(r, d, [(0, 0), (0.05, 1), (0.5, 0.5), (d, 0)], 2500, 11000, 120)
    y = mixdown(n, (norm(splat, 0.9), 0, 1), (norm(slap, 0.5), 0, 1), (norm(drops, 0.5), 0.01, 1), (norm(hiss, 0.45), 0.02, 1))
    return room(y, 0.1, 1.0, 0.55)


def s_acid_pool(r):
    d = 0.6
    n = n_of(d)
    hiss = sizzle(r, d, [(0, 0), (0.06, 1), (0.35, 0.7), (d, 0)], 2500, 10000, 150)
    pops = np.zeros(n)
    for t in poisson_times(r, d, [(0, 20), (d, 10)]):
        place(pops, bubble(r, r.uniform(250, 700), r.uniform(0.03, 0.07)) * r.uniform(0.3, 1), t)
    return room(addl(norm(hiss, 0.8), norm(pops, 0.5)), 0.08, 0.8, 0.6)


def s_meteor_fall(r):
    d = 1.2
    n = n_of(d)
    whistle = tvf(nz(r, n), freq_pts(n, [(0, 2600), (d, 420)]), 9.0, "bp")
    whistle *= env_pts(n, [(0, 0), (0.6, 0.7), (1.0, 1), (d, 0.6)])
    roar = fire(r, d, [(0, 0), (0.7, 0.6), (d, 1)], 600, 0.9)
    roar = tvf(roar, freq_pts(n, [(0, 400), (d, 1600)]), 0.8, "lp")
    rumble = lp(nz(r, n, "brown"), 120) * env_pts(n, [(0, 0), (d, 1)])
    y = addl(norm(whistle, 0.6), norm(roar, 0.7), norm(rumble, 0.4))
    # doppler-ish: louder and brighter as it approaches
    return room(y * env_pts(n, [(0, 0.2), (d - 0.08, 1), (d, 0)], 1.5), 0.15, 1.5, 0.5)


def s_meteor_impact(r):
    d = 2.2
    n = n_of(d)
    sub = thump(d, 80, 26, 0.08, 0.45)
    crack = burst(r, 0.06, 400, 12000, 0.0002, 0.01)
    body = tvf(nz(r, n, "pink"), freq_pts(n, [(0, 4000), (0.08, 1200), (0.8, 250), (d, 120)]), 0.7, "lp") * env_exp(n, 0.002, 0.4)
    rocks = debris(r, d, [(0, 0), (0.04, 260), (0.6, 80), (1.6, 10), (d, 0)], 250, 2400)
    flames = fire(r, d, [(0, 0), (0.06, 1), (1.0, 0.5), (d, 0)], 700, 0.9)
    rumble = lp(nz(r, n, "brown"), 110) * env_exp(n, 0.05, 0.8)
    core = sat(addl(norm(sub, 1.0), norm(body, 0.9), norm(crack, 0.7)), 2.6)
    y = mixdown(n, (core, 0, 1), (norm(rocks, 0.4), 0.03, 1), (norm(flames, 0.35), 0.05, 1), (norm(rumble, 0.5), 0, 1))
    return room(y, 0.25, 2.2, 0.5)


def s_shockwave(r):
    d = 1.5
    n = n_of(d)
    sub = sine(freq_pts(n, [(0, 85), (0.4, 32), (d, 24)])) * env_pts(n, [(0, 0), (0.02, 1), (0.5, 0.6), (d, 0)])
    air = whoosh(r, d, [(0, 900), (0.3, 250), (d, 80)], [(0, 0), (0.03, 1), (0.7, 0.3), (d, 0)], 0.7, "brown")
    rumble = lp(nz(r, n, "brown"), 90) * env_pts(n, [(0, 0), (0.1, 1), (d, 0)])
    rattle = debris(r, d, [(0, 0), (0.1, 60), (0.8, 20), (d, 0)], 300, 1500)
    y = addl(sat(addl(norm(sub, 1.0), norm(air, 0.6)), 1.8), norm(rumble, 0.5), norm(rattle, 0.2))
    return room(y, 0.2, 1.8, 0.6)


def s_weapon_upgrade(r):
    d = 2.2
    n = n_of(d)
    y = np.zeros(n)
    anvil = metal(r, 520, 1.6, 0.6, 1.0, (1.0, 2.76, 5.40, 8.93, 3.3, 4.6))
    place(y, norm(anvil, 0.9), 0)
    place(y, norm(anvil, 0.55), 0.32)
    rise = np.zeros(n)
    for j, m in enumerate([62, 66, 69, 74, 78, 81, 86]):
        f = midi_hz(m)
        nn = n_of(d - 0.55 - j * 0.07)
        s = modal(nn, [f, 2 * f, 3 * f], [1, 0.3, 0.1], [0.7, 0.4, 0.2], r, att=0.01)
        place(rise, s, 0.55 + j * 0.07)
    shimmer = hp(nz(r, n), 6000) * env_pts(n, [(0, 0), (0.5, 0), (1.1, 1), (d, 0)])
    chord = np.zeros(n)
    for m in (50, 57, 62, 66):
        chord += saw(np.full(n, midi_hz(m)) * (1 + 0.003 * smooth_rand(r, n, 4)))
    chord = lp(chord, 1800) * env_pts(n, [(0, 0), (0.9, 0), (1.2, 1), (d, 0)])
    return room(addl(y, norm(rise, 0.5), norm(shimmer, 0.12), norm(chord, 0.3)), 0.25, 2.0, 0.4)
