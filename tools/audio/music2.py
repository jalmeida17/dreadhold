"""Music part 2: goblin dawn market, the four boss themes, defeat."""
import numpy as np
from dsp import SR, n_of, lp, hp, bp, eq, pan, place, midi_hz, rng_for, norm, smooth_rand, saw, sine
import instruments as I
from music import (TRACKS, Song, chord, root, steps, drums, ostinato, pad_choir, pad_strings, melody, hit_once)


# ------------------------------------------------------------------ DAWN: sly goblin market
def t_music_dawn(r):
    s = Song("music_dawn", 112, 24, tail=5.0)
    prog = ["Am", "Am", "G", "G", "F", "F", "E", "E"] * 3
    s.bus("lute", 0.3, 0.07)
    s.bus("bass", 0.15, 0.05)
    s.bus("perc", 0.25, 0.035)
    s.bus("hurdy", 0.35, 0.055)
    s.bus("drone", 0.3, 0.02)
    arp = [0, 2, 1, 2, 0, 2, 1, 2]                       # index into chord tones, 8ths
    for b in range(24):
        ch = prog[b]
        tones = chord(ch, 57, 72)
        for k, idx in enumerate(arp):
            m = tones[idx % len(tones)] + (12 if (k == 5 and b % 2) else 0)
            key = ("lute", m)
            sig = s.cached(key, lambda: I.lute(rng_for("dawn", *key), midi_hz(m), 1.0, 1.0, 0.3))
            s.add("lute", sig, s.t(b, k * 0.5) + r.uniform(0, 0.012), 0.55 + 0.45 * (k % 2 == 0), -0.25)
        for beat, deg in ((0, 0), (1.5, 7), (2.5, 12), (3, 7)):
            m = root(ch, 2) + deg
            key = ("pz", m)
            sig = s.cached(key, lambda: I.pizz(rng_for("dawn", *key), midi_hz(m)))
            s.add("bass", sig, s.t(b, beat), 1.0 if beat == 0 else 0.7, 0.1)
        drums(s, "perc", b, {"frame": "x..x..x.x..x..x." if b % 4 != 3 else "x..x..x.x.xxx.x.",
                             "shaker": "oxoxoxoxoxoxoxox" if b >= 8 else "",
                             "sticks": "....x.......x.x."})
    # sly hurdy-gurdy tune (bars 8-23), chromatic grace leaning on the E chord
    tune = [(8, 0, 1.5, 69), (8, 1.5, 0.5, 71), (8, 2, 1, 72), (8, 3, 1, 71), (9, 0, 2, 69), (9, 2, 1, 68), (9, 3, 1, 69),
            (10, 0, 1.5, 71), (10, 1.5, 0.5, 72), (10, 2, 1, 74), (10, 3, 1, 72), (11, 0, 3, 71), (11, 3, 1, 67),
            (12, 0, 1, 69), (12, 1, 1, 72), (12, 2, 1, 77), (12, 3, 1, 76), (13, 0, 2, 74), (13, 2, 2, 72),
            (14, 0, 1, 71), (14, 1, 0.5, 72), (14, 1.5, 0.5, 71), (14, 2, 1, 68), (14, 3, 1, 71), (15, 0, 4, 64),
            (16, 0, 0.5, 76), (16, 0.5, 0.5, 75), (16, 1, 1, 76), (16, 2, 2, 72), (17, 0, 1, 69), (17, 1, 1, 72), (17, 2, 2, 76),
            (18, 0, 0.5, 74), (18, 0.5, 0.5, 73), (18, 1, 1, 74), (18, 2, 2, 71), (19, 0, 1, 67), (19, 1, 1, 71), (19, 2, 2, 74),
            (20, 0, 1, 72), (20, 1, 1, 69), (20, 2, 1, 65), (20, 3, 1, 69), (21, 0, 2, 72), (21, 2, 2, 74),
            (22, 0, 1, 71), (22, 1, 1, 68), (22, 2, 1, 64), (22, 3, 1, 68), (23, 0, 3, 71), (23, 3, 1, 68)]
    melody(s, "hurdy", tune, "hurdy", 1.0)
    dr = norm(I.hurdy(rng_for("dawn", "drone"), midi_hz(45), s.L / SR + 0.3, 0.2, 0.4), 1.0) * 0.7
    dr += norm(I.hurdy(rng_for("dawn", "drone2"), midi_hz(52), s.L / SR + 0.3, 0.2, 0.0), 1.0) * 0.5
    s.add("drone", pan(lp(dr, 1800), -0.1), 0)
    return s.render(1.3, 0.6, 0.25, -20, 2.0, 0.0, 2.2)


# ------------------------------------------------------------------ BOSS: Hollow King
def t_music_boss_hollow(r):
    s = Song("music_boss_hollow", 70, 24, tail=10.0)
    two = ["Em", "C", "Am", "B", "Em", "Am", "C", "B", "Em", "D", "C", "B7"]
    prog = [c for c in two for _ in (0, 1)]
    s.bus("organ", 0.55, 0.075)
    s.bus("choir", 0.7, 0.08)
    s.bus("drums", 0.35, 0.12)
    s.bus("bells", 0.6, 0.035)
    s.bus("brass", 0.5, 0.045)
    stops = (("16", 0.7), ("8", 1.0), ("4", 0.6), ("223", 0.3), ("2", 0.35), ("mix", 0.18))
    for b in range(0, 24, 2):
        ch = prog[b]
        notes = chord(ch, 52, 67) + [root(ch, 1)]
        d = 2 * 4 * s.spb
        key = ("org", ch)
        sig = s.cached(key, lambda: sum(pan(I.organ(rng_for("hk", *key, m), midi_hz(m), d, stops, 0.5, 0.08), (m % 7) / 7 - 0.4)
                                        for m in notes))
        s.add("organ", sig, s.t(b))
        pad_choir(s, "choir", b, ch, 2, 40, 59, "o" if b < 12 else "a", False, 5, 1.0, 0.9)
        if b >= 12:
            n3 = [root(ch, 2), root(ch, 2) + 7]
            key = ("lb", ch)
            sig = s.cached(key, lambda: I.brass_section(rng_for("hk", *key), n3, d * 0.9, 0.7, 2, 0.4, 6, att=0.5, rel=0.8))
            s.add("brass", sig, s.t(b))
    for b in range(24):
        drums(s, "drums", b, {"taiko": "X.......x......." if b % 4 != 3 else "X.......X...x.x.", "timp": "x.......o......."}, 1.0)
    gong = I.gong(rng_for("hk", "gong"), 62, 7.0)
    bell = I.bell(rng_for("hk", "bell"), midi_hz(52), 7.0, 1.0, 1.3, 0.7)
    for b in range(0, 24, 4):
        hit_once(s, "bells", pan(bell, 0.3), b, 0, 1.0)
        if b % 8 == 0:
            hit_once(s, "drums", pan(gong, -0.2), b, 0, 0.6)
    return s.render(4.5, 0.5, 0.55, -16, 2.0)


# ------------------------------------------------------------------ BOSS: Mother of Rot
def t_music_boss_rot(r):
    s = Song("music_boss_rot", 84, 28, tail=7.0)
    two = ["Fm", "Gb", "Fm", "Db", "Fm", "E", "Fm", "C", "Bbm", "Gb", "Fm", "Db", "E", "C"]
    prog = [c for c in two for _ in (0, 1)]
    s.bus("drone", 0.3, 0.05)
    s.bus("brass", 0.4, 0.08)
    s.bus("wet", 0.25, 0.12)
    s.bus("choir", 0.6, 0.045)
    s.bus("strings", 0.4, 0.035)
    L = s.L / SR
    for f, g in ((midi_hz(29), 1.0), (midi_hz(36), 0.6), (midi_hz(41) * 1.01, 0.3)):
        rr = rng_for("rot", "dr", f)
        n = n_of(L + 0.3)
        fr = f * 2 ** (25 * smooth_rand(rr, n, 0.25) / 1200)
        d = saw(fr) + saw(fr * 1.006, ph0=0.3)
        s.add("drone", pan(lp(d, 420) * g, rr.uniform(-0.4, 0.4)), 0)
    for b in range(0, 28, 2):
        ch = prog[b]
        notes = [root(ch, 1) + 12, root(ch, 1) + 19, chord(ch, 48, 60)[1]]
        key = ("rb", ch)
        sig = s.cached(key, lambda: I.brass_section(rng_for("rot", *key), notes, s.spb * 7, 0.85, 3, 0.6, 28,
                                                     att=0.25, rel=0.6, wobble=30, fall=1.5, vib=22))
        s.add("brass", sig, s.t(b))
        if b % 4 == 2:
            pad_choir(s, "choir", b, ch, 2, 41, 53, "u", False, 4, 1.0, 1.0)
    for b in range(28):
        drums(s, "wet", b, {"wet": "X.....x...x.X..." if b % 4 != 3 else "X.....x.x.xxX.x.", "taiko": "x.......o......."})
        if b % 2 == 0:
            ch = prog[b]
            notes = chord(ch, 65, 77)
            key = ("sul", ch)
            sig = s.cached(key, lambda: I.strings(rng_for("rot", *key), notes, s.spb * 8, "tremolo", 2, 0.7, 0.5, False))
            s.add("strings", sig, s.t(b), 0.8)
    return s.render(2.2, 0.65, 0.35, -16, 2.0)


# ------------------------------------------------------------------ BOSS: Cinder Tyrant
def t_music_boss_cinder(r):
    s = Song("music_boss_cinder", 126, 40, tail=6.0)
    two = ["Am", "Bb", "Am", "G", "F", "Bb", "Am", "E", "Am", "Bb", "Dm", "E", "F", "G", "Bb", "E", "Am", "Bb", "Am", "E"]
    prog = [c for c in two for _ in (0, 1)]
    s.bus("drums", 0.2, 0.17)
    s.bus("anvil", 0.35, 0.04)
    s.bus("ost", 0.25, 0.07)
    s.bus("brass", 0.4, 0.075)
    s.bus("choir", 0.55, 0.045)
    for b in range(40):
        ch = prog[b]
        fill = b % 4 == 3
        drums(s, "drums", b, {"taiko": "X..x..X...x.X.x." if not fill else "X..x..X.XxxxXXXX",
                              "tom_lo": "..x.....x.....x.", "tom_hi": "" if not fill else "........x.x.x...",
                              "frame": "xoxoxoxoxoxoxoxo"})
        drums(s, "anvil", b, {"anvil": "....X.......X..." if b % 2 == 0 else "....X.......X.x."})
        ostinato(s, "ost", b, ch, "xxxxxxxxxxxxxxxx", [0, 0, 12, 0, 1, 0, 12, 0, 0, 0, 12, 0, 1, 0, 7, 0], 2, 1, 3)
        for st, v in steps("X.....X...X....." if b % 2 == 0 else "X.....X...X.X.X."):
            notes = chord(ch, 45, 57, 4)
            key = ("stab", ch)
            sig = s.cached(key, lambda: I.brass_section(rng_for("cin", *key), notes, 0.2, 1.0, 2, 0.6, 10, att=0.01, rel=0.14, fall=0.8))
            s.add("brass", sig, s.t(b, st / 4.0), v)
        if b % 2 == 0 and b >= 8:
            pad_choir(s, "choir", b, ch, 2, 45, 60, "a", False, 4, 1.0, 0.2)
    fan = [(16, 0, 1.5, 69), (16, 1.5, 0.5, 70), (16, 2, 2, 69), (17, 0, 3, 64), (17, 3, 1, 65),
           (18, 0, 1.5, 69), (18, 1.5, 0.5, 72), (18, 2, 2, 74), (19, 0, 4, 76), (20, 0, 2, 77), (20, 2, 2, 76),
           (21, 0, 3, 74), (21, 3, 1, 72), (22, 0, 2, 74), (22, 2, 2, 70), (23, 0, 4, 68),
           (24, 0, 1.5, 69), (24, 1.5, 0.5, 70), (24, 2, 2, 69), (25, 0, 3, 64), (25, 3, 1, 62),
           (26, 0, 2, 65), (26, 2, 2, 69), (27, 0, 4, 68), (28, 0, 2, 69), (28, 2, 2, 72), (29, 0, 4, 71),
           (30, 0, 2, 70), (30, 2, 2, 68), (31, 0, 4, 64)]
    melody(s, "brass", fan, "trumpet", 0.9, 0.2)
    s.bus("fx", 0.5, 0.025)
    cr = I.crash(rng_for("cin", "crash"), 3.0)
    for b in range(0, 40, 8):
        hit_once(s, "fx", pan(cr, -0.3), b)
    return s.render(2.0, 0.5, 0.28, -14, 2.4)


# ------------------------------------------------------------------ BOSS: Lady Rime
def t_music_boss_rime(r):
    s = Song("music_boss_rime", 75, 24, tail=9.0)
    two = ["Bm", "Gmaj7", "Em", "F#", "Bm", "G", "C", "F#", "Bm", "Gmaj7", "Em", "F#"]
    prog = [c for c in two for _ in (0, 1)]
    s.bus("glass", 0.6, 0.06)
    s.bus("celesta", 0.6, 0.04)
    s.bus("choir", 0.75, 0.06)
    s.bus("pulse", 0.3, 0.09)
    s.bus("low", 0.4, 0.04)
    for b in range(0, 24, 2):
        ch = prog[b]
        notes = chord(ch, 71, 84)
        d = s.spb * 8
        for m in notes:
            key = ("gl", m)
            sig = s.cached(key, lambda: pan(I.glass_harmonica(rng_for("rime", *key), midi_hz(m), d, 1.5), ((m * 7) % 11) / 11 - 0.5))
            s.add("glass", sig, s.t(b), 0.6)
        pad_choir(s, "choir", b, ch, 2, 67, 79, "u", True, 4, 1.0, 1.2)
        key = ("low", ch)
        sig = s.cached(key, lambda: I.strings(rng_for("rime", *key), [root(ch, 1) + 12], d, "sustain", 3, 0.4, 1.0, True))
        s.add("low", sig, s.t(b))
    cel = [0, 2, 1, 3, 2, 1, 0, 2]
    for b in range(24):
        tones = chord(prog[b], 79, 96)
        for k, idx in enumerate(cel):
            if (k + b) % 3 == 2:
                continue
            m = tones[idx % len(tones)]
            key = ("cel", m)
            sig = s.cached(key, lambda: I.celesta(rng_for("rime", *key), midi_hz(m), 1.6))
            s.add("celesta", sig, s.t(b, k * 0.5), 0.5 + 0.3 * (k % 2 == 0), ((k * 3) % 7) / 7 - 0.4)
        drums(s, "pulse", b, {"taiko": "X.....x........." if b % 4 != 3 else "X.....x.....x.x.", "timp": "x...............",
                              "frame": "........o......."})
    return s.render(4.0, 0.25, 0.55, -18, 1.8, 2.0)


# ------------------------------------------------------------------ DEFEAT
def t_music_defeat(r):
    s = Song("music_defeat", 60, 8, tail=9.0)
    prog = ["Dm", "Bb", "Gm", "A", "Dm", "Gm", "A", "Dm"]
    s.bus("cello", 0.5, 0.085)
    s.bus("choir", 0.7, 0.05)
    s.bus("low", 0.4, 0.045)
    s.bus("bell", 0.6, 0.03)
    for b in range(8):
        ch = prog[b]
        pad_choir(s, "choir", b, ch, 1, 50, 62, "o", False, 4, 1.0, 1.0)
        pad_strings(s, "low", b, ch, 1, 38, 50, 1.0, "sustain", 3)
    mel = [(0, 0, 2, 62), (0, 2, 1, 60), (0, 3, 1, 57), (1, 0, 3, 58), (1, 3, 1, 57), (2, 0, 2, 55), (2, 2, 2, 58),
           (3, 0, 4, 57), (4, 0, 2, 65), (4, 2, 1, 64), (4, 3, 1, 62), (5, 0, 2, 62), (5, 2, 2, 58), (6, 0, 2, 61),
           (6, 2, 2, 64), (7, 0, 4, 62)]
    melody(s, "cello", mel, "cello", 1.0, 0.1)
    bell = I.bell(rng_for("defeat", "bell"), midi_hz(50), 7.0, 1.0, 1.2, 0.6)
    hit_once(s, "bell", pan(bell, 0.25), 0)
    hit_once(s, "bell", pan(bell, 0.25), 4, 0, 0.6)
    return s.render(3.5, 0.6, 0.55, -18, 1.8)


for _n in ("music_dawn", "music_boss_hollow", "music_boss_rot", "music_boss_cinder", "music_boss_rime", "music_defeat"):
    TRACKS[_n] = "music"
