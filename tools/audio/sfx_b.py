"""SFX recipes part B: enemies, bosses, goblin merchant, game flow."""
import numpy as np
from dsp import (addl, SR, n_of, tl, lp, hp, bp, eq, tvf, env_pts, env_exp, freq_pts, smooth_rand, sine, saw,
                 modal, sat, norm, place, comb, midi_hz, church_bell, phase_of)
from sfx_common import (room, mixdown, nz, thump, burst, whoosh, crackle, fire, debris, bubble, sizzle,
                        metal, wood_knock, glass_pings, voice, creature, big_roar, gibberish, poisson_times,
                        vowel_tracks)
from instruments import brass, choir, organ, gong, sub_boom, bell, glass_harmonica


def bone_clack(r, g=1.0):
    return wood_knock(r, r.uniform(1100, 3000), 0.06, r.uniform(0.004, 0.012)) * g


def body_fall(r, weight=1.0):
    d = 0.5
    n = n_of(d)
    th = thump(d, 110 / weight, 40, 0.03, 0.09 * weight)
    cloth = burst(r, d, 0, 900, 0.002, 0.05, "pink")
    grit = crackle(r, 0.2, [(0, 900), (0.2, 0)], 0.1, 0.6, 1800)
    return mixdown(n, (norm(th, 1.0), 0, 1), (norm(cloth, 0.6), 0, 1), (norm(grit, 0.25), 0.005, 1))


# ------------------------------------------------------------------ ghoul
def s_ghoul_alert(r):
    d = 0.75
    v = creature(r, d, [(0, 115), (0.18, 190), (0.45, 160), (d, 105)], [(0, "uh"), (0.15, "a"), (0.5, "ae"), (d, "o")],
                 [(0, 0), (0.07, 1), (0.45, 0.85), (d, 0)], 0.88, 0.7, 0.6, 0.05, 0.75, 0.45, 2.6, 36)
    hiss = bp(nz(r, n_of(d)), 2500, 9000) * env_pts(n_of(d), [(0, 0), (0.05, 1), (0.3, 0.4), (d, 0)])
    return room(addl(norm(v, 1.0), norm(hiss, 0.15)), 0.15, 1.2, 0.55)


def s_ghoul_attack(r):
    d = 0.42
    hiss = whoosh(r, d, [(0, 5200), (0.12, 3600), (d, 3000)], [(0, 0), (0.015, 1), (0.1, 0.5), (0.2, 0)], 1.3)
    sn = creature(r, 0.32, [(0, 200), (0.08, 230), (0.32, 140)], [(0, "e"), (0.1, "ae"), (0.32, "a")],
                  [(0, 0), (0.015, 1), (0.18, 0.7), (0.32, 0)], 0.92, 0.65, 0.65, 0.06, 0.8, 0.5, 2.8, 42)
    swipe = whoosh(r, 0.2, [(0, 600), (0.08, 1800), (0.2, 500)], [(0, 0), (0.06, 1), (0.2, 0)], 1.2, "pink")
    y = mixdown(n_of(d), (norm(hiss, 0.5), 0, 1), (norm(sn, 0.95), 0.06, 1), (norm(swipe, 0.35), 0.12, 1))
    return room(y, 0.12, 1.1, 0.55)


def s_ghoul_death(r):
    d = 1.15
    n = n_of(d)
    v = creature(r, 0.9, [(0, 160), (0.2, 125), (0.6, 70), (0.9, 52)],
                 [(0, "a"), (0.1, "o"), (0.18, "u"), (0.26, "o"), (0.34, "u"), (0.42, "o"), (0.55, "u"), (0.9, "u")],
                 [(0, 0), (0.04, 1), (0.5, 0.7), (0.85, 0)], 0.85, 0.75, 0.5, 0.08, 0.9, 0.5, 2.2, 28)
    gm = n_of(0.9)
    v *= 0.6 + 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * tl(gm) + 2 * smooth_rand(r, gm, 20)))
    bubbles = np.zeros(n)
    for t in poisson_times(r, 0.7, [(0, 10), (0.7, 25)], 0.1):
        place(bubbles, bubble(r, r.uniform(250, 700), r.uniform(0.03, 0.07)) * r.uniform(0.2, 0.7), t)
    y = mixdown(n, (norm(v, 0.9), 0, 1), (norm(bubbles, 0.3), 0, 1), (norm(body_fall(r), 0.75), 0.62, 1))
    return room(y, 0.16, 1.3, 0.55)


# ------------------------------------------------------------------ skeleton
def s_skeleton_alert(r):
    d = 0.85
    n = n_of(d)
    rattle = np.zeros(n)
    t = 0.0
    while t < 0.45:
        place(rattle, bone_clack(r, r.uniform(0.35, 0.8) * (1 - t)), t)
        t += r.uniform(0.018, 0.034)
    f0 = freq_pts(n, [(0, 140), (0.25, 172), (d, 128)])
    breath = voice(r, f0, [(0, "u"), (0.4, "o"), (d, "u")], 0.95, 1.6, 0.9, 0.02, 0.1, 20, 0.0)
    hollow = comb(breath, 0.0042, 0.62) + 0.6 * comb(breath, 0.0067, 0.5)
    hollow *= env_pts(n, [(0, 0), (0.18, 1), (0.55, 0.8), (d, 0)])
    return room(addl(norm(rattle, 0.7), norm(hollow, 0.75)), 0.25, 1.8, 0.45)


def s_skeleton_death(r):
    d = 1.7
    n = n_of(d)
    y = np.zeros(n)
    for _ in range(16):
        place(y, norm(bone_clack(r), r.uniform(0.35, 0.9)), r.uniform(0, 0.2) ** 1.3 / 0.2 ** 0.3)
    skull = addl(wood_knock(r, 520, 0.2, 0.035), 0.6 * wood_knock(r, 1260, 0.15, 0.02))
    place(y, norm(skull, 0.95), 0.24)
    place(y, norm(skull, 0.5), 0.42)
    t = 0.3
    for j in range(10):
        place(y, norm(bone_clack(r), 0.6 * 0.83 ** j), t)
        t += r.uniform(0.03, 0.07) * (1 + 0.08 * j)
    place(y, norm(thump(0.2, 200, 90, 0.01, 0.03), 0.3), 0.22)
    return room(y, 0.16, 1.2, 0.5)


# ------------------------------------------------------------------ cultist
def s_cultist_cast(r):
    d = 0.95
    n = n_of(d)
    wh = np.zeros(n)
    for k in range(3):                         # three whispering voices
        seq = [(0, "o"), (0.2, "a"), (0.4, "e"), (0.6, "u"), (d, "o")]
        whis = bp(nz(r, n), 500, 7000)
        F = vowel_tracks(n, seq, 1.0 + 0.06 * k)
        acc = sum(g * tvf(whis, Fi, float(np.mean(Fi)) / 120, "bp", 256) for Fi, g in zip(F[:3], (1, 0.7, 0.4)))
        acc *= 0.5 + 0.5 * np.clip(smooth_rand(r, n, 7) + 0.4, 0, 1)
        place(wh, norm(acc, 1.0) * 0.6, r.uniform(0, 0.05))
    swell = env_pts(n, [(0, 0), (0.7, 1), (0.82, 0.8), (d, 0)], 1.5)
    chant = sum(voice(r, np.full(n, midi_hz(m)) * (1 + 0.004 * smooth_rand(r, n, 5)), [(0, "o"), (d, "o")], 0.95, 1.0, 0.2, 0.01)
                for m in (43, 50, 43.1))
    sub = sine(np.full(n, 49.0))
    y = (norm(wh, 0.8) + norm(chant, 0.45) + norm(sub, 0.25)) * swell
    return room(y, 0.3, 2.0, 0.45)


def s_cultist_death(r):
    d = 1.1
    n = n_of(d)
    t = tl(n)
    f0 = freq_pts(n, [(0, 330), (0.1, 420), (0.35, 310), (d, 160)]) * (1 + 0.03 * np.sin(2 * np.pi * 6 * t))
    v = voice(r, f0, [(0, "a"), (0.3, "a"), (0.6, "o"), (d, "u")], 1.05, 0.7, 0.4, 0.04, 0.35, 40, 0.15)
    choke = np.clip((t - 0.25) / 0.4, 0, 0.85) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(12 + 10 * t) / SR))
    v *= (1 - choke) * env_pts(n, [(0, 0), (0.03, 1), (0.3, 0.8), (d, 0)])
    y = mixdown(n_of(d + 0.2), (norm(sat(v, 1.6), 0.9), 0, 1), (norm(body_fall(r, 0.8), 0.5), 0.85, 1))
    return room(y, 0.2, 1.4, 0.5)


# ------------------------------------------------------------------ brute
def s_brute_roar(r):
    d = 1.4
    y = big_roar(r, d, [(0, 62), (0.25, 80), (0.85, 72), (d, 54)], [(0, "o"), (0.3, "a"), (1.0, "a"), (d, "o")],
                 [(0, 0), (0.15, 1), (0.95, 0.85), (d, 0)], 0.7, 2.8, 0.0, 0.45)
    return room(y, 0.2, 1.6, 0.5)


def s_brute_smash(r):
    d = 1.1
    n = n_of(d)
    sub = thump(d, 95, 30, 0.05, 0.2)
    crack = burst(r, 0.05, 500, 10000, 0.0002, 0.006)
    body = tvf(nz(r, n, "pink"), freq_pts(n, [(0, 3000), (0.06, 700), (d, 120)]), 0.7, "lp") * env_exp(n, 0.002, 0.15)
    rocks = debris(r, d, [(0, 0), (0.03, 220), (0.3, 80), (0.8, 5), (d, 0)], 300, 2200)
    dust = bp(nz(r, n, "pink"), 300, 3000) * env_pts(n, [(0, 0), (0.05, 1), (d, 0)])
    core = sat(addl(norm(sub, 1.0), norm(body, 0.9), norm(crack, 0.6)), 2.4)
    return room(addl(core, norm(rocks, 0.35), norm(dust, 0.12)), 0.2, 1.6, 0.55)


def s_brute_death(r):
    d = 2.0
    g = big_roar(r, 1.3, [(0, 82), (0.3, 88), (1.0, 50), (1.3, 42)], [(0, "a"), (0.5, "o"), (1.3, "u")],
                 [(0, 0), (0.1, 1), (0.6, 0.8), (1.1, 0.3), (1.3, 0)], 0.7, 2.2, 0.0, 0.3)
    y = mixdown(n_of(d), (norm(g, 0.85), 0, 1), (norm(body_fall(r, 1.6), 1.0), 1.05, 1),
                (norm(debris(r, 0.6, [(0, 120), (0.6, 0)], 300, 1500), 0.25), 1.07, 1))
    return room(y, 0.2, 1.7, 0.55)


# ------------------------------------------------------------------ Hollow King (generic boss_*)
def s_boss_roar(r):
    d = 2.4
    n = n_of(d)
    roar = big_roar(r, d, [(0, 46), (0.35, 60), (1.5, 56), (d, 38)], [(0, "o"), (0.45, "a"), (1.6, "a"), (d, "o")],
                    [(0, 0), (0.3, 1), (1.7, 0.85), (d, 0)], 0.6, 3.2, 0.22, 0.6, 0.6)
    ghost = sum(voice(r, freq_pts(n, [(0, 220 * k), (d, 180 * k)]), [(0, "u"), (d, "o")], 1.0, 1.4, 0.8, 0.02, 0.2, 20)
                for k in (1.0, 1.5))
    ghost = comb(ghost, 0.005, 0.55) * env_pts(n, [(0, 0), (0.5, 1), (d, 0)])
    rattle = np.zeros(n)
    for t in poisson_times(r, d, [(0, 0), (0.3, 30), (1.8, 20), (d, 0)]):
        place(rattle, bone_clack(r, r.uniform(0.2, 0.6)), t)
    return room(addl(norm(roar, 1.0), norm(ghost, 0.2), norm(rattle, 0.2)), 0.28, 2.6, 0.45)


def s_boss_cast(r):
    d = 1.3
    n = n_of(d)
    bend = freq_pts(n, [(0, 1.0), (d, 1.07)])
    drone = sum(saw(f * bend, ph0=r.uniform()) for f in (55.0, 82.4, 110.3, 164.8))
    drone = tvf(drone, freq_pts(n, [(0, 150), (1.1, 2600), (d, 700)]), 2.4, "lp", 128)
    drone *= env_pts(n, [(0, 0), (0.9, 1), (1.15, 1), (d, 0)])
    t = tl(n)
    rate = 4 + 12 * t / d
    fc = 800 * 2 ** (t / d) * 2 ** (0.9 * np.sin(2 * np.pi * np.cumsum(rate) / SR))
    swirl = tvf(nz(r, n), fc, 4.0, "bp") * env_pts(n, [(0, 0), (1.0, 1), (1.2, 0.5), (d, 0)])
    whispers = np.zeros(n)
    for k in range(4):
        wv = bp(nz(r, n), 800, 6000)
        F = vowel_tracks(n, [(0, "o"), (0.3, "i"), (0.6, "a"), (0.9, "e"), (d, "u")], 1.0 + 0.05 * k)
        whispers += sum(g * tvf(wv, Fi, float(np.mean(Fi)) / 110, "bp", 256) for Fi, g in zip(F[:3], (1, 0.7, 0.4))) * \
            np.clip(smooth_rand(r, n, 6) + 0.3, 0, 1)
    whispers *= env_pts(n, [(0, 0), (0.6, 1), (d, 0)])
    riser = hp(nz(r, n), 3000) * (t / d) ** 3
    boom = thump(0.4, 110, 40, 0.03, 0.1)
    y = mixdown(n_of(d + 0.2), (norm(drone, 0.7), 0, 1), (norm(swirl, 0.45), 0, 1), (norm(whispers, 0.3), 0, 1),
                (norm(riser, 0.25), 0, 1), (norm(boom, 0.6), 1.12, 1))
    return room(sat(y, 1.5), 0.28, 2.2, 0.4)


def s_boss_death(r):
    d = 3.6
    n = n_of(d)
    roar = big_roar(r, 1.8, [(0, 62), (0.4, 54), (1.8, 28)], [(0, "a"), (0.9, "o"), (1.8, "u")],
                    [(0, 0), (0.1, 1), (0.9, 0.8), (1.8, 0)], 0.6, 2.8, 0.15, 0.6)
    rumble = lp(nz(r, n, "brown"), 110) * env_pts(n, [(0, 0), (0.3, 0.6), (1.4, 1), (d, 0)])
    rocks = debris(r, d, [(0, 0), (1.3, 30), (1.45, 160), (2.5, 20), (d, 0)], 250, 2000)
    impact = sat(addl(norm(thump(1.4, 78, 26, 0.08, 0.38), 1.0), norm(burst(r, 0.8, 0, 2000, 0.002, 0.15, "pink"), 0.8)), 2.2)
    toll = bell(r, 98.0, 2.4, 1.0, 1.3, 0.8)
    y = mixdown(n, (norm(roar, 0.9), 0, 1), (norm(rumble, 0.45), 0, 1), (norm(rocks, 0.3), 0, 1),
                (impact, 1.35, 1.0), (norm(toll, 0.5), 1.4, 1))
    return room(y, 0.3, 3.0, 0.45)


# ------------------------------------------------------------------ Mother of Rot
def s_rot_roar(r):
    d = 2.2
    n = n_of(d)
    f0 = freq_pts(n, [(0, 120), (0.4, 165), (1.4, 150), (d, 95)])
    wet = voice(r, f0, [(0, "o"), (0.5, "ae"), (1.5, "a"), (d, "u")], 0.82, 0.8, 0.6, 0.05, 0.9, 22, 0.6)
    gurg = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(9 + 6 * smooth_rand(r, n, 2)) / SR)
    low = voice(r, f0 * 0.5, [(0, "o"), (d, "u")], 0.7, 0.9, 0.5, 0.04, 0.8, 18, 0.5)
    bubbles = np.zeros(n)
    for t in poisson_times(r, d, [(0, 20), (1.0, 45), (d, 15)]):
        place(bubbles, bubble(r, r.uniform(150, 600), r.uniform(0.04, 0.1)) * r.uniform(0.2, 1), t)
    slosh = tvf(nz(r, n, "pink"), 300 + 250 * smooth_rand(r, n, 3, 0, 1), 3.0, "bp")
    env = env_pts(n, [(0, 0), (0.25, 1), (1.6, 0.85), (d, 0)])
    y = sat((norm(wet * gurg, 1.0) + norm(low, 0.6)) * env, 2.6) + norm(bubbles, 0.35) + norm(slosh * env, 0.25)
    return room(y, 0.25, 2.0, 0.6)


def s_rot_death(r):
    d = 3.0
    n = n_of(d)
    rn = n_of(1.8)
    f0 = freq_pts(rn, [(0, 150), (0.3, 170), (1.8, 60)])
    wail = voice(r, f0, [(0, "a"), (0.8, "o"), (1.8, "u")], 0.82, 0.8, 0.6, 0.05, 0.9, 20, 0.5)
    wail *= (0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(np.linspace(7, 15, rn)) / SR)) * env_pts(rn, [(0, 0), (0.1, 1), (1.2, 0.6), (1.8, 0)])
    burst_ = tvf(nz(r, n_of(1.2), "pink"), freq_pts(n_of(1.2), [(0, 2500), (0.1, 600), (1.2, 150)]), 0.8, "lp") * env_exp(n_of(1.2), 0.004, 0.2)
    splash = np.zeros(n)
    for t in poisson_times(r, 1.6, [(0, 0), (0.05, 120), (1.6, 0)]):
        place(splash, bubble(r, r.uniform(300, 1400)) * r.uniform(0.2, 1), 1.4 + t)
    hiss = sizzle(r, 1.6, [(0, 1), (1.6, 0)], 2500, 10000, 120)
    y = mixdown(n, (norm(sat(wail, 2.4), 0.85), 0, 1), (norm(body_fall(r, 2.0), 0.9), 1.35, 1),
                (norm(burst_, 0.7), 1.4, 1), (norm(splash, 0.4), 0, 1), (norm(hiss, 0.3), 1.45, 1))
    return room(y, 0.25, 2.2, 0.6)


# ------------------------------------------------------------------ Cinder Tyrant
def s_cinder_roar(r):
    d = 2.4
    n = n_of(d)
    roar = big_roar(r, d, [(0, 44), (0.35, 58), (1.6, 54), (d, 36)], [(0, "o"), (0.4, "a"), (1.7, "a"), (d, "o")],
                    [(0, 0), (0.25, 1), (1.8, 0.85), (d, 0)], 0.58, 3.4, 0.12, 0.7, 0.6)
    flames = fire(r, d, [(0, 0), (0.3, 1), (1.8, 0.8), (d, 0)], 900, 1.0)
    flames = tvf(flames, freq_pts(n, [(0, 600), (0.4, 2500), (d, 800)]), 0.8, "lp")
    embers = crackle(r, d, [(0, 0), (0.3, 300), (d, 80)], 0.1, 1.0, 2000)
    return room(addl(norm(roar, 1.0), norm(flames, 0.4), norm(embers, 0.2)), 0.25, 2.4, 0.5)


def s_cinder_death(r):
    d = 3.6
    n = n_of(d)
    roar = big_roar(r, 1.8, [(0, 58), (0.4, 50), (1.8, 26)], [(0, "a"), (0.9, "o"), (1.8, "u")],
                    [(0, 0), (0.1, 1), (0.9, 0.8), (1.8, 0)], 0.58, 3.0, 0.1, 0.6)
    impact = sat(addl(norm(thump(1.6, 75, 24, 0.09, 0.42), 1.0), norm(burst(r, 1.0, 0, 2200, 0.002, 0.2, "pink"), 0.8)), 2.4)
    rocks = debris(r, d, [(0, 0), (1.3, 40), (1.45, 220), (2.6, 25), (d, 0)], 250, 2200)
    flames = fire(r, d, [(0, 0.3), (1.4, 1), (2.6, 0.4), (d, 0)], 800, 0.9)
    hiss = sizzle(r, 2.0, [(0, 0), (0.2, 1), (2.0, 0)], 2000, 9000, 70)       # fire dying out
    y = mixdown(n, (norm(roar, 0.85), 0, 1), (impact, 1.35, 1.0), (norm(rocks, 0.35), 0, 1),
                (norm(flames, 0.3), 0, 1), (norm(hiss, 0.25), 1.6, 1))
    return room(y, 0.28, 2.8, 0.5)


# ------------------------------------------------------------------ Lady Rime
def s_rime_cast(r):
    d = 1.6
    n = n_of(d)
    y = np.zeros(n)
    for j, m in enumerate([81, 88, 84, 91, 87]):     # A5 E6 C6 G6 Eb6: eerie, unresolved
        place(y, glass_harmonica(r, midi_hz(m), d - 0.4 - j * 0.08, 0.4, 0.6) * (1 - 0.1 * j), j * 0.08)
    chimes = glass_pings(r, d, 14, 2500, 7000, 0.6, (0.3, 1.0))
    ghost = voice(r, freq_pts(n, [(0, 520), (d, 560)]) * (1 + 0.01 * np.sin(2 * np.pi * 5 * tl(n))),
                  [(0, "u"), (0.8, "o"), (d, "u")], 1.25, 1.3, 0.5, 0.01, 0.0)
    ghost *= env_pts(n, [(0, 0), (0.6, 1), (d, 0)])
    rev_swell = hp(nz(r, n), 4000) * (tl(n) / d) ** 2 * env_pts(n, [(0, 1), (d - 0.05, 1), (d, 0)])
    return room(addl(norm(y, 0.7), norm(chimes, 0.35), norm(ghost, 0.3), norm(rev_swell, 0.15)), 0.35, 2.8, 0.15)


def s_rime_death(r):
    d = 3.2
    n = n_of(d)
    wn = n_of(1.8)
    t = tl(wn)
    f0 = freq_pts(wn, [(0, 520), (0.2, 640), (1.8, 260)]) * (1 + 0.025 * np.sin(2 * np.pi * 6 * t))
    wail = voice(r, f0, [(0, "a"), (0.6, "o"), (1.8, "u")], 1.3, 0.9, 0.5, 0.02, 0.2, 30, 0.1)
    wail *= env_pts(wn, [(0, 0), (0.06, 1), (1.0, 0.6), (1.8, 0)])
    wail = comb(wail, 0.0031, 0.4)
    shatter = glass_pings(r, 2.2, 60, 1800, 10000, 0.15, (0.05, 0.9))
    crack = burst(r, 0.05, 1500, 15000, 0.0002, 0.006)
    chime = sum(glass_harmonica(r, midi_hz(m), 1.2, 1.0, 0.5) for m in (69, 76, 80))
    y = mixdown(n, (norm(wail, 0.75), 0, 1), (norm(crack, 0.8), 0.9, 1), (norm(shatter, 0.7), 0.9, 1),
                (norm(chime, 0.3), 1.3, 1), (norm(thump(0.4, 150, 60, 0.02, 0.08), 0.4), 0.9, 1))
    return room(y, 0.32, 3.0, 0.15)


# ------------------------------------------------------------------ misc enemy magic
def s_enemy_spawn(r):
    d = 1.1
    n = n_of(d)
    ghosts = np.zeros(n)
    for a, b in ((420, 640), (600, 470), (890, 1010)):
        f = freq_pts(n, [(0, a), (d, b)]) * (1 + 0.015 * np.sin(2 * np.pi * r.uniform(5.5, 7) * tl(n) + r.uniform(0, 6)))
        ghosts += voice(r, f, [(0, "u"), (d * 0.5, "o"), (d, "u")], 1.2, 1.4, 0.3, 0.01, 0.1)
    ghosts *= env_pts(n, [(0, 0), (0.4, 1), (0.75, 0.7), (d, 0)])
    t = tl(n)
    fc = 900 * 2 ** (0.8 * np.sin(2 * np.pi * np.cumsum(3 + 6 * t / d) / SR))
    swirl = tvf(nz(r, n), fc, 5.0, "bp") * env_pts(n, [(0, 0), (0.3, 1), (d, 0)])
    low = whoosh(r, d, [(0, 90), (0.5, 260), (d, 80)], [(0, 0), (0.45, 1), (d, 0)], 0.8, "brown")
    return room(addl(norm(ghosts, 0.45), norm(swirl, 0.5), norm(low, 0.45)), 0.35, 2.4, 0.3)


def s_shadow_bolt(r):
    d = 0.55
    n = n_of(d)
    fr = freq_pts(n, [(0, 260), (d, 80)])
    buzz = saw(fr) + 0.8 * saw(fr * 1.012, ph0=0.3) + 0.5 * saw(fr * 0.5)
    buzz = tvf(buzz, freq_pts(n, [(0, 3500), (d, 350)]), 3.0, "lp") * env_pts(n, [(0, 0), (0.01, 1), (0.18, 0.6), (d, 0)])
    wh = whoosh(r, d, [(0, 1800), (0.12, 800), (d, 280)], [(0, 0), (0.03, 1), (d, 0)], 1.2, "pink", 0.4, 40)
    thd = thump(0.18, 190, 70, 0.02, 0.05)
    hissy = comb(bp(nz(r, n), 1500, 8000), 0.0023, 0.7) * env_exp(n, 0.005, 0.12)
    return room(sat(addl(norm(buzz, 0.6), norm(wh, 0.6), norm(thd, 0.55), norm(hissy, 0.2)), 1.6), 0.18, 1.4, 0.45)


def s_bolt_impact(r):
    d = 0.6
    n = n_of(d)
    pop = thump(0.25, 260, 55, 0.012, 0.04)
    crack = burst(r, 0.05, 900, 6000, 0.0003, 0.008)
    fizz = hp(nz(r, n), 2800) * (0.5 + 0.5 * smooth_rand(r, n, 60)) * env_exp(n, 0.004, 0.12)
    sparks = crackle(r, d, [(0, 600), (0.4, 50), (d, 0)], 0.1, 0.6, 2500)
    ring = lp(saw(np.full(n, 110.0)) + saw(np.full(n, 116.5)), 700) * env_exp(n, 0.002, 0.1)
    y = addl(norm(pop, 0.9), norm(crack, 0.6), norm(fizz, 0.4), norm(sparks, 0.35), norm(ring, 0.3))
    return room(sat(y, 1.5), 0.18, 1.3, 0.45)


# ------------------------------------------------------------------ goblin merchant
def s_goblin_greet(r):
    # "heh-heh ... wel-COME!" - nasal, quick, sly
    sy = [("h", "e", 0.09, 320, 270, 0.8), ("", "-", 0.03, 0, 0, 0), ("h", "e", 0.09, 300, 255, 0.75),
          ("", "-", 0.12, 0, 0, 0), ("w", "e", 0.13, 250, 275, 0.9),
          ("k", "a", 0.2, 340, 230, 1.0), ("m", "uh", 0.1, 230, 200, 0.6)]
    y = gibberish(r, sy, 1.3, 0.55, 0.85, 0.2)
    return room(y, 0.1, 0.9, 0.55)


def s_goblin_laugh(r):
    sy = []
    f = 420
    for j in range(7):
        sy.append(("h", "i" if j < 3 else "e", 0.075, f, f * 0.9, 1.0 - 0.07 * j))
        sy.append(("", "-", 0.03, 0, 0, 0))
        f *= 0.95
    sy.append(("h", "e", 0.18, f, f * 0.8, 0.6))
    return room(gibberish(r, sy, 1.35, 0.5, 0.8, 0.35), 0.1, 0.9, 0.55)


# ------------------------------------------------------------------ game flow
def horn_call(r, notes, f_scale=1.0):
    """notes: [(t, dur, midi)] -> war horn: 3 detuned horns + an octave-below horn."""
    total = max(t + d for t, d, m in notes) + 0.5
    y = np.zeros(n_of(total))
    for t, d, m in notes:
        f = midi_hz(m) * f_scale
        for k, c in enumerate((-9, 0, 8)):
            h = brass(r, f * 2 ** (c / 1200), d, 0.95, 0.14, 0.3, 2.8, 0.75, 0.06, 9, 4)
            place(y, h, t + 0.012 * k)
        place(y, brass(r, f * 0.5, d, 0.8, 0.18, 0.3, 2.8, 1.1, 0.04, 6, 3) * 0.7, t)
    y = eq(y, [("peak", 480, 1.0, 4.0), ("peak", 1200, 1.5, 2.0)])
    return y


def s_wave_start(r):
    y = horn_call(r, [(0.0, 0.75, 45), (0.72, 1.35, 50)])
    return room(sat(norm(y, 1.0), 1.3), 0.35, 2.8, 0.45)


def s_wave_clear(r):
    d = 2.0
    c1 = choir(r, [57, 61, 64, 69], 0.3, "a", False, 4, 0.05, 0.25)
    c2 = choir(r, [62, 66, 69, 74], 1.2, "a", False, 4, 0.08, 0.6)
    sop = choir(r, [78, 81], 1.2, "a", True, 3, 0.1, 0.6)
    y = np.zeros(n_of(d + 0.5))
    mono = lambda s: 0.5 * (s[0] + s[1])
    place(y, norm(mono(c1), 0.6), 0)
    place(y, norm(mono(c2), 0.85), 0.28)
    place(y, norm(mono(sop), 0.35), 0.3)
    place(y, norm(bell(r, midi_hz(74), 2.0, 1.0, 0.5, 0.7), 0.35), 0.28)
    place(y, norm(bell(r, midi_hz(81), 2.0, 1.0, 0.4, 0.6), 0.22), 0.29)
    place(y, norm(brass(r, midi_hz(50), 1.0, 0.9, 0.06, 0.4), 0.3), 0.28)
    return room(y, 0.3, 2.4, 0.4)


def s_boon_select(r):
    d = 1.6
    n = n_of(d)
    y = np.zeros(n)
    for j, m in enumerate([74, 78, 81, 86, 90, 93, 98]):
        f = midi_hz(m)
        nn = n_of(d - j * 0.05)
        place(y, modal(nn, [f, 2 * f, 3.01 * f], [1, 0.2, 0.06], [0.35, 0.2, 0.1], r, 0.004) * 0.3, j * 0.05)
    sh = bp(nz(r, n), 6000, 12000) * (0.6 + 0.4 * smooth_rand(r, n, 20)) * env_pts(n, [(0, 0), (0.3, 1), (d, 0)])
    g = gong(r, 98.0, d, 1.0)
    g *= env_pts(n, [(0, 0), (0.03, 1), (d, 1)])
    return room(addl(norm(y, 0.6), norm(sh, 0.1), norm(g, 0.5)), 0.3, 2.2, 0.3)


def s_game_over(r):
    d = 4.5
    n = n_of(d)
    y = np.zeros(n)
    place(y, norm(bell(r, 73.42, d, 1.0, 1.4, 0.8), 0.9), 0)
    place(y, norm(bell(r, 73.42, d - 1.7, 1.0, 1.2, 0.7), 0.6), 1.7)
    dr = sum(saw(np.full(n, f) * (1 + 0.002 * smooth_rand(r, n, 0.5)), ph0=r.uniform()) for f in (36.71, 55.0, 73.42))
    dr = lp(dr, 260) * env_pts(n, [(0, 0), (1.0, 1), (3.2, 0.9), (d, 0)])
    ch = choir(r, [38, 45, 50], 3.0, "o", False, 4, 0.8, 1.0)
    place(y, norm(dr, 0.45), 0)
    place(y, norm(0.5 * (ch[0] + ch[1]), 0.35), 0.4)
    return room(y, 0.3, 3.2, 0.45)


def s_boss_warning(r):
    d = 3.2
    n = n_of(d)
    y = np.zeros(n)
    for t, g in ((0.0, 0.9), (1.15, 0.9)):
        place(y, norm(bell(r, 98.0, d - t, 1.0, 1.0, 0.9), g), t)
        place(y, norm(modal(n_of(d - t), [277.18, 554.4], [1, 0.3], [0.9, 0.5], r, 0.002), 0.13), t)   # tritone colour
    rum = lp(nz(r, n, "brown"), 90) * env_pts(n, [(0, 0), (1.2, 1), (d, 0)])
    drum = sub_boom(40, 1.2, 1.0)
    place(y, norm(rum, 0.35), 0)
    place(y, norm(drum, 0.5), 0)
    place(y, norm(drum, 0.5), 1.15)
    return room(y, 0.3, 2.8, 0.45)
