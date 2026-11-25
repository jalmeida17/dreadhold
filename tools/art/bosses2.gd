extends RefCounted
## Three map bosses (9 frames of 192x192, same frame meaning as boss.png) and their 64x64 portraits.
## Designed in 128 design units (ground at y=126), drawn at k = 1.5, realistic gritty pixel style.

const Painter := preload("res://tools/art/painter.gd")
const PR := preload("res://tools/art/props_real.gd")

const POSES := [
	{"step": 1.0},
	{"step": -1.0, "bob": 1.0},
	{"atk": 1},
	{"atk": 2},
	{"pain": true},
	{"die": 1},
	{"die": 2},
	{"corpse": true},
	{"cast": true},
]

const VOID := Color(0.04, 0.03, 0.035)
const BONE := Color(0.68, 0.62, 0.5)
const IRON := Color(0.3, 0.3, 0.33)

# Mother of Rot
const ROT_FLESH := Color(0.42, 0.45, 0.35)
const ROT_DARK := Color(0.28, 0.3, 0.23)
const HABIT := Color(0.15, 0.14, 0.13)
const VEIL := Color(0.17, 0.16, 0.15)
const WIMPLE := Color(0.55, 0.52, 0.44)
const GAS := Color(0.62, 0.74, 0.28)
const ROT_GLOW := Color(0.75, 1.0, 0.3)
# Cinder Tyrant
const CHAR := Color(0.14, 0.12, 0.11)
const HORN := Color(0.24, 0.2, 0.16)
const MAGMA := Color(1.0, 0.45, 0.1)
const MAGMA_HOT := Color(1.0, 0.82, 0.4)
# Lady Rime
const RIME_SKIN := Color(0.72, 0.81, 0.9)
const ROBE := Color(0.42, 0.56, 0.72)
const ROBE_PALE := Color(0.72, 0.84, 0.94)
const ROBE_DEEP := Color(0.2, 0.3, 0.45)
const ICE := Color(0.62, 0.86, 1.0)
const FROST_GLOW := Color(0.5, 0.95, 1.0)


# =============================================================================== builders

static func build_sheet(kind: String) -> Image:
	var size := 192
	var design := 128.0
	var scale := 1.5
	var frames: Array = []
	for i in POSES.size():
		var pose: Dictionary = POSES[i]
		var p := Painter.new(size, size, 2000 + i * 17 + kind.length() * 101)
		p.set_real(scale)
		var base_xf := p.xf
		var glows: Array = []
		if pose.get("corpse", false):
			glows = _dispatch("corpse", kind, p)
		else:
			var die: int = pose.get("die", 0)
			if die > 0:
				var pivot := Vector2(design * 0.5, design - 2)
				var ang := 0.3 if die == 1 else 1.1
				var off := Vector2(-design * 0.04, design * 0.05) if die == 1 else Vector2(-design * 0.26, design * 0.08)
				p.xf = base_xf * Transform2D(0.0, pivot + off) * Transform2D(ang, Vector2.ZERO) * Transform2D(0.0, -pivot)
			glows = _dispatch("body", kind, p, pose)
		p.xf = base_xf
		p.rim(0.42, 0.12)
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1] * scale, g[2], g[3])
		p.harden_alpha(0.5)
		frames.append(p.img)
	return Painter.strip(frames)


static func _dispatch(what: String, kind: String, p: Painter, pose: Dictionary = {}) -> Array:
	match kind + ":" + what:
		"rot:body":
			return rot_body(p, pose)
		"rot:corpse":
			return rot_corpse(p)
		"cinder:body":
			return cinder_body(p, pose)
		"cinder:corpse":
			return cinder_corpse(p)
		"rime:body":
			return rime_body(p, pose)
		"rime:corpse":
			return rime_corpse(p)
	return []


static func _gas(p: Painter, cx: float, cy: float, r: float, seed_value: int) -> void:
	## Opaque, noisy puffs of toxic gas (sprites are alpha-cut).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 11:
		var o := Vector2(rng.randf_range(-r, r), rng.randf_range(-r * 1.6, r * 0.3))
		var rr := r * rng.randf_range(0.22, 0.42)
		p.ball(cx + o.x, cy + o.y, rr, rr * 0.8, Color(0.4, 0.46, 0.22).lerp(Color(0.52, 0.58, 0.28), rng.randf()), 0.3)


static func _claws(p: Painter, wrist: Vector2, dir: Vector2, spread: float, length: float, skin: Color, claw: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	p.ball(wrist.x + d.x * 1.5, wrist.y + d.y * 1.5, 3.0, 2.6, skin)
	for f in 4:
		var off := (float(f) - 1.5) * spread
		var b0 := wrist + d * 3.0 + n * off
		var mid := b0 + d * length * 0.55 + n * off * 0.25
		var tip := b0 + d * length + n * off * 0.4
		p.strand(PackedVector2Array([b0, mid]), 1.0, 0.8, skin)
		p.strand(PackedVector2Array([mid, tip]), 0.75, 0.2, claw)


# =============================================================================== Mother of Rot

static func rot_head(p: Painter, cx: float, cy: float, s: float, expr: String, glows: Array) -> void:
	p.ball(cx, cy - 1.0 * s, 12.0 * s, 13.5 * s, VEIL)
	p.ball(cx, cy + 1.0 * s, 9.6 * s, 11.2 * s, WIMPLE)
	p.ball(cx, cy + 1.8 * s, 7.6 * s, 9.6 * s, ROT_FLESH)
	p.ball(cx - 4.2 * s, cy + 4.0 * s, 2.0 * s, 2.6 * s, ROT_DARK)
	p.ball(cx + 4.2 * s, cy + 4.0 * s, 2.0 * s, 2.6 * s, ROT_DARK.darkened(0.1))
	# forehead band of the wimple
	p.cyl_poly(PackedVector2Array([Vector2(cx - 9.0 * s, cy - 6.5 * s), Vector2(cx + 9.0 * s, cy - 6.5 * s), Vector2(cx + 8.5 * s, cy - 3.6 * s), Vector2(cx - 8.5 * s, cy - 3.6 * s)]), WIMPLE.lightened(0.05), cx, 9.0 * s, -0.2)
	# sunken sockets with sickly lights
	var blaze := expr == "enraged"
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		var ex := cx + sd * 3.1 * s
		var ey := cy - 0.2 * s
		p.ellipse(ex, ey, 2.1 * s, 1.7 * s, VOID)
		var e := p.tp(Vector2(ex, ey + 0.2 * s))
		p.ellipse(ex, ey + 0.2 * s, 0.7 * s, 0.6 * s, ROT_GLOW.lightened(0.3))
		glows.append([e, (2.6 if blaze else 1.6) * s, ROT_GLOW, 1.0 if blaze else 0.75])
	# rotted nose and mouth
	p.poly(PackedVector2Array([Vector2(cx - 1.0 * s, cy + 2.8 * s), Vector2(cx + 1.0 * s, cy + 2.8 * s), Vector2(cx, cy + 4.6 * s)]), VOID)
	var my := cy + 7.2 * s
	if expr == "calm":
		p.line(Vector2(cx - 3.2 * s, my), Vector2(cx + 3.2 * s, my), Color(0.12, 0.06, 0.05), maxf(0.6 * s, 1.0))
		for i in 5:
			var sx := cx - 2.6 * s + i * 1.3 * s
			p.line(Vector2(sx, my - 0.9 * s), Vector2(sx + 0.3 * s, my + 0.9 * s), Color(0.45, 0.38, 0.3), maxf(0.35 * s, 1.0))
	else:
		var open := 1.6 if expr == "hurt" else 3.2
		p.ellipse(cx, my + open * 0.4 * s, 3.2 * s, open * s, Color(0.12, 0.05, 0.04))
		for i in 5:
			p.rect(cx - 2.6 * s + i * 1.25 * s, my - 0.6 * s, maxf(0.6 * s, 1.0), 0.9 * s, Color(0.6, 0.55, 0.38))
	# rot sores
	for w in [Vector2(-5.0, 6.0), Vector2(5.4, 1.0), Vector2(2.6, 8.4)]:
		var wv: Vector2 = w
		p.ball(cx + wv.x * s, cy + wv.y * s, 0.9 * s, 0.8 * s, Color(0.35, 0.22, 0.2))


static func rot_body(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cast: bool = pose.get("cast", false)
	var cx := 64.0 + (2.0 if pain else 0.0) + step * 1.0
	var by := bob * 1.2 + (1.5 if pain else 0.0)
	# ---- veil hanging down the back
	var vb := PackedVector2Array([Vector2(cx - 10, 14 + by), Vector2(cx + 10, 14 + by), Vector2(cx + 32, 46 + by), Vector2(cx + 36, 86)])
	for i in 13:
		vb.append(Vector2(cx + 36 - i * 6.0, 92 - (i % 2) * 7 - (4 if i % 3 == 0 else 0)))
	vb.append(Vector2(cx - 32, 46 + by))
	p.cloth(vb, VEIL.darkened(0.15), cx, 34.0, 0.45, 0.4)
	# ---- skirt of the habit, ragged hem, rotting toes
	var hem := PackedVector2Array([Vector2(cx - 24, 74 + by), Vector2(cx + 24, 74 + by), Vector2(cx + 34 + step * 2, 118)])
	for i in 15:
		hem.append(Vector2(cx + 34 + step * 2 - i * (68.0 / 14.0), 124 - (i % 2) * 5 - (3 if i % 4 == 1 else 0)))
	hem.append(Vector2(cx - 34 + step * 2, 118))
	p.cloth(hem, HABIT, cx, 34.0, 0.5, 0.42)
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		var lift := maxf(step * sd, 0.0)
		var fx := cx + sd * 12.0
		p.ball(fx, 124.0 - lift * 2.0, 6.5, 2.6, ROT_FLESH)
		for t in 4:
			p.capsule(Vector2(fx - 4.5 + t * 3.0, 125 - lift * 2.0), Vector2(fx - 4.8 + t * 3.2, 126.5 - lift * 2.0), 0.9, 0.7, ROT_DARK)
	# ---- bloated belly bursting through the parted habit
	p.ball(cx, 64 + by, 22.0, 18.0, ROT_FLESH.darkened(0.08), 0.18)
	p.ball(cx + 1, 74 + by, 20.0, 11.0, ROT_FLESH.darkened(0.14), 0.18)
	p.ball(cx - 6, 58 + by, 10.0, 7.5, ROT_FLESH.darkened(0.02), 0.15)
	for v in [[Vector2(cx - 18, 58), Vector2(cx - 8, 74)], [Vector2(cx + 14, 52), Vector2(cx + 20, 72)], [Vector2(cx - 4, 50), Vector2(cx + 6, 62)]]:
		var a: Vector2 = v[0]
		var b: Vector2 = v[1]
		p.line(a + Vector2(0, by), b + Vector2(0, by), Color(0.25, 0.22, 0.28), 0.8)
	# stitched wound
	p.line(Vector2(cx - 14, 64 + by), Vector2(cx + 12, 70 + by), Color(0.18, 0.06, 0.06), 0.9)
	for i in 8:
		var sp := Vector2(cx - 14, 64 + by).lerp(Vector2(cx + 12, 70 + by), float(i) / 7.0)
		p.line(sp + Vector2(-0.5, -1.4), sp + Vector2(0.5, 1.4), Color(0.36, 0.31, 0.24), 0.5)
	# open sore with maggots
	p.ball(cx + 10, 77 + by, 6.0, 4.5, Color(0.28, 0.06, 0.06))
	p.ball(cx + 10, 76.5 + by, 4.2, 2.8, Color(0.42, 0.12, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + int(step * 3) + atk
	for i in 9:
		var mp := Vector2(cx + 10 + rng.randf_range(-4.5, 4.5), 76.5 + by + rng.randf_range(-2.5, 2.5))
		p.capsule(mp, mp + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1, 1)), 0.7, 0.6, Color(0.85, 0.82, 0.68))
	p.ball(cx - 2, 72 + by, 1.6, 1.2, ROT_DARK.darkened(0.3))
	# parted habit over the chest and flanks
	for sv in [-1.0, 1.0]:
		var sd2: float = sv
		var panel := PackedVector2Array([Vector2(cx + sd2 * 6, 36 + by), Vector2(cx + sd2 * 24, 36 + by), Vector2(cx + sd2 * 29, 60 + by), Vector2(cx + sd2 * 26, 82 + by), Vector2(cx + sd2 * 15, 86 + by), Vector2(cx + sd2 * 17, 64 + by), Vector2(cx + sd2 * 11, 46 + by)])
		p.cloth(panel, HABIT.lightened(0.03), cx + sd2 * 20, 12.0, 0.8, 0.35)
	p.cyl_poly(PackedVector2Array([Vector2(cx - 10, 34 + by), Vector2(cx + 10, 34 + by), Vector2(cx + 7, 46 + by), Vector2(cx - 7, 46 + by)]), WIMPLE.darkened(0.15), cx, 10, -0.3)
	# ---- arms: long, thin, clawed, tattered sleeves
	var lsh := Vector2(cx - 23, 39 + by)
	var rsh := Vector2(cx + 23, 39 + by)
	var lel := Vector2(cx - 33, 62 + by)
	var lwr := Vector2(cx - 31, 86 + by)
	var rel := Vector2(cx + 33, 62 + by)
	var rwr := Vector2(cx + 32, 88 + by)
	var rdir := Vector2(0.05, 1)
	var ldir := Vector2(-0.05, 1)
	if cast:
		lel = Vector2(cx - 32, 30 + by); lwr = Vector2(cx - 18, 14 + by)
		rel = Vector2(cx + 32, 30 + by); rwr = Vector2(cx + 18, 14 + by)
		ldir = Vector2(0.5, -1); rdir = Vector2(-0.5, -1)
	elif atk == 1:
		rel = Vector2(cx + 34, 32 + by); rwr = Vector2(cx + 28, 12 + by); rdir = Vector2(-0.2, -1)
	elif atk == 2:
		rel = Vector2(cx + 22, 56 + by); rwr = Vector2(cx + 2, 70 + by); rdir = Vector2(-1, 0.6)
	elif pain:
		lel = Vector2(cx - 36, 52 + by); lwr = Vector2(cx - 44, 68 + by)
		rel = Vector2(cx + 36, 52 + by); rwr = Vector2(cx + 44, 66 + by)
	for arm in [[lsh, lel, lwr, ldir], [rsh, rel, rwr, rdir]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var wr: Vector2 = arm[2]
		var hd: Vector2 = arm[3]
		p.capsule(sh, el, 5.5, 4.2, HABIT.lightened(0.05))
		for k in 3:
			var rag := el + Vector2(-3.0 + k * 3.0, 2)
			p.capsule(rag, rag + Vector2((k - 1) * 0.8, 5.0 + k), 1.2, 0.6, HABIT)
		p.capsule(el, wr, 2.6, 2.0, ROT_FLESH)
		p.capsule(el.lerp(wr, 0.1), wr, 1.1, 0.8, ROT_DARK)
		_claws(p, wr, hd, 1.7, 9.0, ROT_FLESH, Color(0.3, 0.27, 0.2))
	# ---- censer on a chain from the left hand, leaking gas
	if not cast:
		var swing := step * 5.0 + (6.0 if atk == 1 else (-8.0 if atk == 2 else 0.0))
		var top := lwr + Vector2(0, 4)
		var cen := top + Vector2(swing - 3, 18)
		for k in 7:
			var cp := top.lerp(cen, float(k) / 6.0)
			p.spec = 0.6
			p.ball(cp.x, cp.y, 0.9, 0.7, IRON)
			p.spec = 0.0
		p.spec = 0.7
		p.ball(cen.x, cen.y + 3, 4.5, 4.2, IRON.darkened(0.1))
		p.ball(cen.x, cen.y - 0.5, 2.6, 1.6, IRON)
		p.spec = 0.0
		for k in 4:
			p.ellipse(cen.x - 2.5 + k * 1.7, cen.y + 3, 0.5, 0.7, GAS.lightened(0.2))
		_gas(p, cen.x + 1, cen.y - 4, 6.0, 5 + int(step * 2) + atk)
	# ---- head on a craning neck
	var hx := cx + (3.0 if pain else 0.0)
	var hy := 20.0 + by + (1.5 if pain else 0.0)
	p.capsule(Vector2(hx, hy + 9), Vector2(cx, 36 + by), 4.0, 5.0, ROT_FLESH.darkened(0.05))
	rot_head(p, hx, hy, 1.15, "enraged" if (atk > 0 or cast) else ("hurt" if pain else "calm"), glows)
	if cast:
		var oc := Vector2(cx, 6 + by)
		var opx := p.tp(oc)
		PR.orb(p, opx.x, opx.y, 7.5 * p.k, 1.3, PR.SOUL6)
		p.light_only(cx, 20 + by, 30, ROT_GLOW, 0.55)
		glows.append([opx, 12.0, ROT_GLOW, 1.1])
		_gas(p, cx - 22, 12 + by, 6.0, 91)
		_gas(p, cx + 22, 14 + by, 6.0, 92)
	if atk == 2:
		for k in 3:
			for t in 8:
				var pt := Vector2(cx + 30 - t * 5.5, 30 + t * 5.0 + k * 3.0)
				glows.append([p.tp(pt), 2.0, Color(0.7, 0.75, 0.6), 0.3])
	p.grime(Color(0.25, 0.2, 0.12), 0.45, 0.06, 0.12, 0.6)
	p.grime(Color(0.3, 0.22, 0.3), 0.35, 0.1, 0.3)
	return glows


static func rot_corpse(p: Painter) -> Array:
	p.ellipse(64, 122, 54, 5.0, Color(0.16, 0.2, 0.05))
	p.cloth(PackedVector2Array([Vector2(10, 126), Vector2(22, 108), Vector2(70, 100), Vector2(110, 108), Vector2(120, 126)]), HABIT, 64, 56, 0.5, 0.4, -0.6)
	p.ball(60, 108, 28, 13, ROT_FLESH, 0.1)
	p.line(Vector2(42, 106), Vector2(76, 110), Color(0.22, 0.05, 0.06), 1.2)
	p.ball(100, 112, 11, 9, VEIL)
	p.ball(101, 113, 7, 6, ROT_FLESH.darkened(0.15))
	p.ellipse(100, 112, 1.6, 1.2, VOID)
	p.ellipse(104, 112, 1.6, 1.2, VOID)
	p.capsule(Vector2(20, 120), Vector2(36, 112), 2.2, 1.8, ROT_FLESH)
	p.spec = 0.7
	p.ball(14, 121, 4.5, 4.0, IRON)
	p.spec = 0.0
	_gas(p, 60, 96, 9.0, 3)
	_gas(p, 16, 112, 5.0, 4)
	p.grime(Color(0.25, 0.2, 0.12), 0.45, 0.06, 0.12)
	return []


# =============================================================================== Cinder Tyrant

static func _magma_cracks(p: Painter, seed_value: int, freq: float = 0.05, single: bool = false) -> void:
	## Glowing fissures on charcoal skin (only touches dark, unsaturated pixels).
	var n1 := FastNoiseLite.new()
	n1.seed = seed_value
	n1.frequency = freq
	var n2 := FastNoiseLite.new()
	n2.seed = seed_value + 7
	n2.frequency = freq * 1.7
	var ur := p.img.get_used_rect()
	for y in range(ur.position.y, ur.end.y):
		for x in range(ur.position.x, ur.end.x):
			var c := p.img.get_pixel(x, y)
			if c.a < 0.5 or c.get_luminance() > 0.24 or c.s > 0.45:
				continue
			var v := minf(absf(n1.get_noise_2d(x, y)), absf(n2.get_noise_2d(x, y)) * 2.2)
			if single:
				v = absf(n1.get_noise_2d(x, y)) * 0.55
			if v < 0.012:
				p.img.set_pixel(x, y, MAGMA_HOT)
			elif v < 0.03:
				p.img.set_pixel(x, y, MAGMA)
			elif v < 0.06:
				p.img.set_pixel(x, y, c.lerp(Color(0.42, 0.12, 0.03), 0.45))


static func cinder_head(p: Painter, cx: float, cy: float, s: float, expr: String) -> void:
	## Base head (charcoal) — horns/flames/eyes are added after the crack pass.
	p.ball(cx, cy, 9.5 * s, 10.5 * s, CHAR)
	p.ball(cx, cy + 6.0 * s, 8.0 * s, 6.0 * s, CHAR)
	p.capsule(Vector2(cx - 7.0 * s, cy - 2.5 * s), Vector2(cx + 7.0 * s, cy - 2.5 * s), 2.2 * s, 2.2 * s, CHAR.lightened(0.05))
	p.ball(cx, cy + 2.0 * s, 2.2 * s, 2.6 * s, CHAR.lightened(0.04))


static func cinder_face(p: Painter, cx: float, cy: float, s: float, expr: String, glows: Array, phase: float) -> void:
	# horns: out from the temples, sweeping up and forward
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		var a0 := Vector2(cx + sd * 7.5 * s, cy - 5.0 * s)
		var pts := PackedVector2Array([a0, a0 + Vector2(sd * 8.0 * s, -3.0 * s), a0 + Vector2(sd * 12.5 * s, -11.0 * s), a0 + Vector2(sd * 10.0 * s, -20.0 * s)])
		p.strand(pts, 3.2 * s, 0.6 * s, HORN)
		for r in 4:
			var q := pts[1].lerp(pts[2], float(r) / 4.0)
			p.line(q + Vector2(-1.6 * s, 0.6 * s), q + Vector2(1.6 * s, -0.6 * s), HORN.darkened(0.45), maxf(0.4 * s, 1.0))
	# glowing eye slits and a molten maw
	var blaze := expr == "enraged"
	for sv in [-1.0, 1.0]:
		var sd2: float = sv
		var ex := cx + sd2 * 3.4 * s
		var ey := cy - 0.6 * s
		p.line(Vector2(ex - 2.0 * s, ey - 0.4 * s * sd2 * 0.0), Vector2(ex + 2.0 * s, ey), MAGMA_HOT, maxf(0.9 * s, 1.0))
		glows.append([p.tp(Vector2(ex, ey)), (3.0 if blaze else 1.8) * s, MAGMA, 1.0 if blaze else 0.7])
	var open := 1.2
	if expr == "hurt":
		open = 2.0
	elif blaze:
		open = 3.4
	p.ellipse(cx, cy + 7.0 * s, 4.0 * s, open * s, MAGMA)
	p.ellipse(cx, cy + 7.0 * s, 2.6 * s, open * 0.55 * s, MAGMA_HOT)
	for i in 5:
		p.rect(cx - 3.2 * s + i * 1.5 * s, cy + 7.0 * s - open * s, maxf(0.7 * s, 1.0), 1.0 * s, HORN.lightened(0.2))
	# burning beard and mane (flames stay modest on close-ups so the face reads)
	var fs := s if s < 1.5 else s * 0.5
	for i in 5:
		var bx := cx + (-6.0 + i * 3.0) * s
		PR.flame(p, bx, cy + 13.5 * s + absf(i - 2.0) * -1.0 * s, (7.0 + (i % 2) * 3.0) * fs, 2.2 * fs, phase + i * 1.3)
	for i in 4:
		var mx := cx + (-10.0 + i * 6.6) * s
		PR.flame(p, mx, cy - 7.5 * s, (6.0 + (i % 2) * 2.5) * fs, 2.0 * fs, phase * 1.3 + i * 2.1)


static func cinder_body(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cast: bool = pose.get("cast", false)
	var cx := 64.0 + (2.0 if pain else 0.0)
	var by := bob * 1.4 + (1.5 if pain else 0.0)
	# ---- charcoal body (cracks are burned in afterwards)
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		var lift := maxf(step * sd, 0.0)
		var hip := Vector2(cx + sd * 12.0, 84 + by * 0.5)
		var knee := Vector2(cx + sd * 16.0, 104.0 - lift * 4.0)
		var ankle := Vector2(cx + sd * 16.0, 121.0 - lift * 5.0)
		p.capsule(hip, knee, 9.5, 7.5, CHAR)
		p.capsule(knee, ankle, 7.5, 6.0, CHAR)
		p.ball(knee.x, knee.y, 6.5, 5.5, CHAR.lightened(0.03))
		p.ball(ankle.x + sd * 2.0, ankle.y + 3.0, 9.0, 3.8, CHAR)
	p.ball(cx, 70 + by, 21.0, 13.0, CHAR)
	p.ball(cx, 50 + by, 27.0, 18.0, CHAR)
	p.ball(cx - 10, 47 + by, 12.0, 8.0, CHAR.lightened(0.03))
	p.ball(cx + 10, 47 + by, 12.0, 8.0, CHAR.lightened(0.02))
	for i in 3:
		p.line(Vector2(cx - 8, 60 + i * 5 + by), Vector2(cx + 8, 60 + i * 5 + by), CHAR.darkened(0.4))
	var lsh := Vector2(cx - 30, 41 + by)
	var rsh := Vector2(cx + 30, 41 + by)
	p.ball(lsh.x, lsh.y, 11.0, 9.0, CHAR)
	p.ball(rsh.x, rsh.y, 11.0, 9.0, CHAR)
	var lel := Vector2(cx - 40, 63 + by)
	var lwr := Vector2(cx - 38, 83 + by)
	var rel := Vector2(cx + 40, 63 + by)
	var rwr := Vector2(cx + 39, 82 + by)
	if cast:
		lel = Vector2(cx - 38, 32 + by); lwr = Vector2(cx - 18, 14 + by)
		rel = Vector2(cx + 38, 32 + by); rwr = Vector2(cx + 18, 14 + by)
	elif atk == 1:
		lel = Vector2(cx - 30, 24 + by); lwr = Vector2(cx - 7, 12 + by)
		rel = Vector2(cx + 30, 24 + by); rwr = Vector2(cx + 7, 12 + by)
	elif atk == 2:
		lel = Vector2(cx - 30, 58 + by); lwr = Vector2(cx - 7, 70 + by)
		rel = Vector2(cx + 30, 58 + by); rwr = Vector2(cx + 7, 70 + by)
	elif pain:
		lel = Vector2(cx - 44, 54 + by); lwr = Vector2(cx - 50, 70 + by)
		rel = Vector2(cx + 44, 54 + by); rwr = Vector2(cx + 50, 68 + by)
	for arm in [[lsh, lel, lwr], [rsh, rel, rwr]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var wr: Vector2 = arm[2]
		p.capsule(sh + Vector2(0, 4), el, 9.0, 7.0, CHAR)
		p.ball(sh.lerp(el, 0.5).x, sh.lerp(el, 0.5).y, 8.0, 7.0, CHAR)
		p.capsule(el, wr, 7.0, 6.0, CHAR)
		p.ball(wr.x, wr.y + 2, 6.5, 6.0, CHAR.lightened(0.02))
	var hx := cx + (3.0 if pain else 0.0)
	var hy := 22.0 + by + (1.5 if pain else 0.0)
	p.capsule(Vector2(hx, hy + 8), Vector2(cx, 36 + by), 7.0, 9.0, CHAR)
	cinder_head(p, hx, hy, 1.0, "")
	_magma_cracks(p, 13, 0.028)
	# ---- iron loin plates on chains
	p.spec = 0.6
	for k in 5:
		var px := cx - 18 + k * 7.4
		p.flat_poly(PackedVector2Array([Vector2(px, 77 + by), Vector2(px + 6.6, 77 + by), Vector2(px + 7.2, 96 + by), Vector2(px - 0.6, 96 + by)]), IRON.darkened(0.3) if k % 2 == 0 else IRON.darkened(0.45), Vector3((k - 2) * 0.35, -0.2, 1))
	for k in 12:
		var chp := Vector2(cx - 20, 76 + by).lerp(Vector2(cx + 20, 76 + by), float(k) / 11.0)
		p.ball(chp.x, chp.y + sin(k * 0.9) * 0.6, 1.3, 1.0, IRON.lightened(0.1))
	for sv in [-1.0, 1.0]:
		var sd3: float = sv
		var wr2: Vector2 = rwr if sd3 > 0 else lwr
		p.capsule(wr2 + Vector2(-6, -3), wr2 + Vector2(6, -3), 1.8, 1.8, IRON)
	p.spec = 0.0
	# ---- smouldering great hammer
	var bot: Vector2
	var top: Vector2
	if atk == 1:
		bot = Vector2(cx, 18 + by); top = Vector2(cx - 1, -14 + by)
	elif atk == 2:
		bot = Vector2(cx, 62 + by); top = Vector2(cx - 1, 108)
	elif cast:
		bot = Vector2(cx + 46, 126); top = Vector2(cx + 50, 92)
	else:
		bot = rwr + Vector2(0, 14); top = rwr + Vector2(10, -40)
	p.capsule(bot, top, 2.4, 2.4, Color(0.2, 0.14, 0.1))
	var hd := (top - bot).normalized()
	var hn := Vector2(-hd.y, hd.x)
	var c0 := top - hd * 8.0
	var stone := Color(0.2, 0.19, 0.19)
	var depth := Vector2(-4.0, -4.0)
	var front := PackedVector2Array([c0 + hn * 13 - hd * 11, c0 + hn * 13 + hd * 11, c0 - hn * 13 + hd * 11, c0 - hn * 13 - hd * 11])
	p.flat_poly(PackedVector2Array([front[0], front[0] + depth, front[1] + depth, front[1]]), stone.lightened(0.12), Vector3(-0.4, -0.8, 0.5))
	p.flat_poly(PackedVector2Array([front[1], front[1] + depth, front[2] + depth, front[2]]), stone, Vector3(-0.8, -0.2, 0.5))
	p.flat_poly(front, stone, Vector3(0.1, 0.1, 1))
	p.line(c0 - hd * 9 + hn * 2, c0 - hd * 2 - hn * 1, MAGMA, 1.2)
	p.line(c0 - hd * 2 - hn * 1, c0 + hd * 4 + hn * 2, MAGMA, 1.2)
	p.line(c0 + hd * 4 + hn * 2, c0 + hd * 9 - hn * 1, MAGMA, 1.0)
	p.line(c0 - hd * 2 - hn * 1, c0 + hd * 4 + hn * 2, MAGMA_HOT, 0.6)
	for chip in [hn * 13 - hd * 11, -hn * 13 + hd * 11]:
		var cv: Vector2 = chip
		p.erase_ellipse((c0 + cv).x, (c0 + cv).y, 2.0, 2.0)
	p.spec = 0.6
	for band in [-6.0, 6.0]:
		var bf: float = band
		p.capsule(c0 + hn * 13.8 + hd * bf * 1.4, c0 - hn * 13.8 + hd * bf * 1.4, 1.3, 1.3, IRON)
	p.spec = 0.0
	glows.append([p.tp(c0), 7.0, MAGMA, 0.5])
	# fists over the haft
	for wr3 in [lwr, rwr]:
		var wv: Vector2 = wr3
		if (atk > 0) or wv == rwr:
			p.ball(wv.x, wv.y + 2, 6.5, 6.0, CHAR.lightened(0.04))
			for f in 4:
				p.ball(wv.x - 4.5 + f * 3.0, wv.y - 0.5, 1.8, 1.6, CHAR.lightened(0.08))
	# ---- horns, burning beard & mane, eyes
	var expr := "enraged" if (atk > 0 or cast) else ("hurt" if pain else "calm")
	cinder_face(p, hx, hy, 1.0, expr, glows, float(int(step * 2) + atk * 3 + (5 if cast else 0)))
	if cast:
		var oc := Vector2(cx, 6 + by)
		var opx := p.tp(oc)
		PR.orb(p, opx.x, opx.y, 9.0 * p.k, 0.7, PR.FIRE6)
		p.light_only(cx, 24 + by, 32, MAGMA, 0.5)
		glows.append([opx, 14.0, MAGMA, 1.1])
	if atk == 2:
		for k in 9:
			var fx := cx - 20 + k * 5.0
			PR.flame(p, fx, 124, 10.0 + (k % 3) * 4.0, 3.0, k * 1.7)
	return glows


static func cinder_corpse(p: Painter) -> Array:
	var glows: Array = []
	p.ball(60, 112, 32, 13, CHAR, 0.1)
	p.ball(28, 118, 14, 8, CHAR)
	p.ball(92, 116, 15, 9, CHAR)
	p.ball(100, 106, 9, 9, CHAR)
	_magma_cracks(p, 29, 0.06)
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		p.strand(PackedVector2Array([Vector2(100 + sd * 6, 100), Vector2(100 + sd * 13, 96), Vector2(100 + sd * 15, 86)]), 2.8, 0.6, HORN)
	p.flat_poly(PackedVector2Array([Vector2(4, 112), Vector2(24, 110), Vector2(26, 126), Vector2(6, 126)]), Color(0.18, 0.16, 0.15), Vector3(0, -0.6, 1))
	p.line(Vector2(8, 116), Vector2(22, 122), MAGMA, 1.0)
	for k in 5:
		PR.flame(p, 40 + k * 10.0, 104 - (k % 2) * 3.0, 6.0 + (k % 3) * 2.0, 2.0, k * 1.9)
	glows.append([p.tp(Vector2(60, 108)), 12.0, MAGMA, 0.45])
	return glows


# =============================================================================== Lady Rime

static func rime_head(p: Painter, cx: float, cy: float, s: float, expr: String, glows: Array) -> void:
	# long white hair falling behind
	for sv in [-1.0, 1.0]:
		var sh: float = sv
		for k in 4:
			var x0 := cx + sh * (4.0 + k * 1.4) * s
			p.strand(PackedVector2Array([Vector2(x0, cy - 6 * s), Vector2(x0 + sh * 2.4 * s, cy + 6 * s), Vector2(x0 + sh * (2.0 + k * 0.6) * s, cy + (16 + k * 2.5) * s)]), 1.2 * s, 0.6 * s, Color(0.84, 0.9, 0.94).darkened(0.06 * k))
	# gaunt face
	p.ball(cx, cy, 6.4 * s, 8.8 * s, RIME_SKIN)
	p.ball(cx - 3.4 * s, cy + 1.6 * s, 1.8 * s, 1.5 * s, RIME_SKIN.lightened(0.08))
	p.ball(cx + 3.4 * s, cy + 1.6 * s, 1.8 * s, 1.5 * s, RIME_SKIN.lightened(0.04))
	p.ball(cx - 3.6 * s, cy + 4.0 * s, 1.5 * s, 2.0 * s, RIME_SKIN.darkened(0.3))
	p.ball(cx + 3.6 * s, cy + 4.0 * s, 1.5 * s, 2.0 * s, RIME_SKIN.darkened(0.35))
	p.capsule(Vector2(cx, cy - 0.8 * s), Vector2(cx + 0.3 * s, cy + 3.4 * s), 0.7 * s, 0.9 * s, RIME_SKIN.lightened(0.06))
	var blaze := expr == "enraged"
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		var ex := cx + sd * 2.6 * s
		var ey := cy - 1.2 * s
		p.ball(ex, ey, 2.2 * s, 1.4 * s, RIME_SKIN.darkened(0.45))
		p.ellipse(ex, ey, 1.7 * s, 0.8 * s, Color(0.06, 0.1, 0.16))
		p.ellipse(ex, ey, 1.0 * s, 0.6 * s, FROST_GLOW.lightened(0.35))
		glows.append([p.tp(Vector2(ex, ey)), (2.8 if blaze else 1.7) * s, FROST_GLOW, 1.0 if blaze else 0.75])
		p.line(Vector2(cx + sd * 0.8 * s, ey - 1.6 * s), Vector2(cx + sd * 4.2 * s, ey - 1.0 * s), Color(0.75, 0.82, 0.88), maxf(0.5 * s, 1.0))
	var my := cy + 5.4 * s
	if expr == "calm":
		p.ellipse(cx, my, 1.8 * s, 0.6 * s, Color(0.2, 0.26, 0.42))
		p.line(Vector2(cx - 1.6 * s, my), Vector2(cx + 1.6 * s, my), Color(0.08, 0.1, 0.2), maxf(0.5 * s, 1.0))
	else:
		var open := 1.0 if expr == "hurt" else 2.0
		p.ellipse(cx, my + 0.3 * s, 1.8 * s, open * s, Color(0.08, 0.1, 0.18))
	if expr != "calm":
		p.line(Vector2(cx - 5.5 * s, cy - 4 * s), Vector2(cx - 3.0 * s, cy + 2 * s), Color(0.9, 0.97, 1.0), maxf(0.4 * s, 1.0))
		p.line(Vector2(cx + 4.5 * s, cy - 5 * s), Vector2(cx + 2.5 * s, cy - 1 * s), Color(0.9, 0.97, 1.0), maxf(0.4 * s, 1.0))
	# crown of icicles
	p.spec = 1.0
	p.capsule(Vector2(cx - 7.0 * s, cy - 6.4 * s), Vector2(cx + 7.0 * s, cy - 6.4 * s), 1.0 * s, 1.0 * s, Color(0.7, 0.78, 0.85))
	var heights := [5.0, 9.0, 7.0, 14.0, 7.0, 9.0, 5.0]
	for i in heights.size():
		var ix := cx + (-6.0 + i * 2.0) * s
		var ht: float = heights[i]
		p.flat_poly(PackedVector2Array([Vector2(ix - 1.0 * s, cy - 6.6 * s), Vector2(ix + 1.0 * s, cy - 6.6 * s), Vector2(ix, cy - (6.6 + ht) * s)]), ICE, Vector3(-0.4, -0.3, 1))
		p.line(Vector2(ix - 0.3 * s, cy - 7.0 * s), Vector2(ix - 0.1 * s, cy - (6.6 + ht * 0.7) * s), Color(0.95, 1, 1), maxf(0.3 * s, 1.0))
	p.spec = 0.0


static func _shard(p: Painter, at: Vector2, size: float, ang: float) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	p.spec = 1.0
	p.flat_poly(PackedVector2Array([at - d * size, at + n * size * 0.35, at + d * size, at - n * size * 0.35]), ICE, Vector3(-0.5, -0.4, 1))
	p.spec = 0.0
	p.line(at - d * size * 0.8, at + d * size * 0.6, Color(0.95, 1, 1))


static func rime_body(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cast: bool = pose.get("cast", false)
	var cx := 64.0 + (2.0 if pain else 0.0)
	var by := bob * 1.5 - 1.0 + (1.5 if pain else 0.0)
	var sway := step * 3.0
	# ---- flowing train behind (pale, streaked: reads as translucent)
	var train := PackedVector2Array([Vector2(cx - 14, 34 + by), Vector2(cx + 14, 34 + by), Vector2(cx + 40 + sway, 98), Vector2(cx + 46 + sway, 126)])
	for i in 11:
		train.append(Vector2(cx + 46 + sway - i * 9.2, 126 - (i % 2) * 8))
	train.append(Vector2(cx - 42 + sway, 98))
	p.cloth(train, ROBE_PALE.darkened(0.25), cx, 44.0, 0.4, 0.5)
	# ---- gown: deep blue bodice fading to pale, misty hem (she glides, no feet)
	var gown := PackedVector2Array([Vector2(cx - 11, 54 + by), Vector2(cx + 11, 54 + by), Vector2(cx + 18, 80 + by), Vector2(cx + 34 + sway, 118)])
	for i in 14:
		var t := float(i) / 13.0
		gown.append(Vector2(cx + 34 + sway - t * 68.0, 126 - absf(sin(t * 9.0 + step)) * 6.0))
	gown.append(Vector2(cx - 34 + sway, 118))
	gown.append(Vector2(cx - 18, 80 + by))
	p.cloth(gown, ROBE, cx + sway * 0.3, 30.0, 0.55, 0.45)
	var ur := Rect2i(Vector2i(p.tp(Vector2(cx - 40, 80))), Vector2i(int(80 * p.k), int(48 * p.k)))
	for y in range(maxi(ur.position.y, 0), mini(ur.end.y, p.h)):
		var t2 := clampf((float(y) - ur.position.y) / float(ur.size.y), 0.0, 1.0)
		for x in range(maxi(ur.position.x, 0), mini(ur.end.x, p.w)):
			var c := p.img.get_pixel(x, y)
			if c.a > 0.5 and c.b > c.r + 0.08:
				var streak := 0.12 * sin(x * 0.7) + 0.1 * sin(x * 0.23 + 1.0)
				p.img.set_pixel(x, y, c.lerp(ROBE_PALE, clampf(t2 * 0.75 + streak, 0.0, 0.9)))
	# bodice + ice brooch
	var bod := Color(0.3, 0.42, 0.58)
	p.cyl_poly(PackedVector2Array([Vector2(cx - 13, 34 + by), Vector2(cx - 4, 34 + by), Vector2(cx, 44 + by), Vector2(cx + 4, 34 + by), Vector2(cx + 13, 34 + by), Vector2(cx + 9, 50 + by), Vector2(cx + 7, 58 + by), Vector2(cx, 62 + by), Vector2(cx - 7, 58 + by), Vector2(cx - 9, 50 + by)]), bod, cx, 12, -0.25)
	p.poly(PackedVector2Array([Vector2(cx - 4, 34 + by), Vector2(cx + 4, 34 + by), Vector2(cx, 43 + by)]), RIME_SKIN.darkened(0.1))
	for i in 5:
		p.line(Vector2(cx - 2.5, 46 + i * 3 + by), Vector2(cx + 2.5, 47.5 + i * 3 + by), ROBE_PALE.darkened(0.1))
		p.line(Vector2(cx + 2.5, 46 + i * 3 + by), Vector2(cx - 2.5, 47.5 + i * 3 + by), ROBE_PALE.darkened(0.1))
	p.line(Vector2(cx - 13, 34 + by), Vector2(cx - 7, 58 + by), Color(0.75, 0.82, 0.9))
	p.line(Vector2(cx + 13, 34 + by), Vector2(cx + 7, 58 + by), Color(0.6, 0.68, 0.78))
	p.spec = 1.0
	p.flat_poly(PackedVector2Array([Vector2(cx, 41 + by), Vector2(cx + 2.5, 44 + by), Vector2(cx, 48 + by), Vector2(cx - 2.5, 44 + by)]), ICE, Vector3(-0.4, -0.5, 1))
	p.spec = 0.0
	glows.append([p.tp(Vector2(cx, 44 + by)), 3.5, FROST_GLOW, 0.7])
	# high frost collar
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		p.flat_poly(PackedVector2Array([Vector2(cx + sd * 6, 36 + by), Vector2(cx + sd * 16, 34 + by), Vector2(cx + sd * 18, 22 + by), Vector2(cx + sd * 9, 28 + by)]), ROBE_PALE, Vector3(-sd * 0.3, -0.5, 1))
	# ---- arms in flared translucent sleeves, ice staff in the left hand
	var lsh := Vector2(cx - 13, 37 + by)
	var rsh := Vector2(cx + 13, 37 + by)
	var lel := Vector2(cx - 19, 54 + by)
	var lwr := Vector2(cx - 21, 70 + by)
	var rel := Vector2(cx + 19, 54 + by)
	var rwr := Vector2(cx + 16, 70 + by)
	if cast:
		lel = Vector2(cx - 24, 28 + by); lwr = Vector2(cx - 14, 12 + by)
		rel = Vector2(cx + 24, 28 + by); rwr = Vector2(cx + 14, 12 + by)
	elif atk == 1:
		lel = Vector2(cx - 22, 30 + by); lwr = Vector2(cx - 18, 14 + by)
	elif atk == 2:
		lel = Vector2(cx - 14, 48 + by); lwr = Vector2(cx - 2, 56 + by)
	elif pain:
		lel = Vector2(cx - 24, 48 + by); lwr = Vector2(cx - 32, 60 + by)
		rel = Vector2(cx + 24, 48 + by); rwr = Vector2(cx + 32, 58 + by)
	for arm in [[lsh, lel, lwr], [rsh, rel, rwr]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var wr: Vector2 = arm[2]
		p.capsule(sh, el, 3.6, 3.2, ROBE_PALE.darkened(0.22))
		var cuff := wr + (el - wr).normalized() * 2.5
		p.capsule(el, cuff, 3.4, 6.5, ROBE_PALE.darkened(0.08))
		for kk in 3:
			p.line(el.lerp(cuff, 0.2) + Vector2(-2.5 + kk * 2.5, 0), cuff + Vector2(-4 + kk * 4, 0), ROBE_PALE.lightened(0.15))
		p.ellipse(cuff.x, cuff.y, 3.0, 2.0, ROBE_DEEP.darkened(0.2))
		var hd := (wr - el).normalized()
		var hn := Vector2(-hd.y, hd.x)
		p.ball(wr.x, wr.y, 1.8, 1.8, RIME_SKIN)
		for f in 4:
			var f0 := wr + hn * ((float(f) - 1.5) * 0.9)
			p.capsule(f0, f0 + hd * 4.2 + hn * ((float(f) - 1.5) * 0.4), 0.55, 0.35, RIME_SKIN)
	# staff of ice
	var s_bot: Vector2
	var s_top: Vector2
	if cast:
		s_bot = Vector2(cx - 40, 124); s_top = Vector2(cx - 44, 30)
	elif atk == 1:
		s_bot = lwr + Vector2(4, 40); s_top = lwr + Vector2(-6, -30)
	elif atk == 2:
		s_bot = lwr + Vector2(-26, -28); s_top = lwr + Vector2(30, 40)
	else:
		s_bot = lwr + Vector2(-2, 54); s_top = lwr + Vector2(-6, -48)
	p.spec = 0.9
	p.capsule(s_bot, s_top, 1.5, 1.2, ICE.darkened(0.15))
	var sd2 := (s_top - s_bot).normalized()
	var sn := Vector2(-sd2.y, sd2.x)
	for k in 5:
		var a2 := float(k - 2) * 0.35
		var tipd := sd2.rotated(a2)
		p.flat_poly(PackedVector2Array([s_top + sn * 1.6, s_top + tipd * (10.0 - absf(k - 2.0) * 2.0), s_top - sn * 1.6]), ICE, Vector3(-0.5, -0.4, 1))
	p.spec = 0.0
	var orb := p.tp(s_top + sd2 * 2.0)
	PR.orb(p, orb.x, orb.y, 3.5 * p.k, float(int(step * 2) + atk), PR.FROST6)
	glows.append([orb, 7.0, FROST_GLOW, 0.8])
	# ---- head
	var hx := cx + (2.5 if pain else 0.0)
	var hy := 18.0 + by + (1.5 if pain else 0.0)
	p.capsule(Vector2(hx, hy + 8), Vector2(cx, 32 + by), 2.4, 2.8, RIME_SKIN.darkened(0.1))
	rime_head(p, hx, hy, 1.0, "enraged" if (atk > 0 or cast) else ("hurt" if pain else "calm"), glows)
	# ---- orbiting shards
	var phase := float(int(step * 2) + atk * 2 + (3 if cast else 0) + (5 if pain else 0)) * 0.7
	for k in 6:
		var a := phase + float(k) / 6.0 * TAU
		var at := Vector2(cx + cos(a) * 34.0, 58 + by + sin(a) * 10.0)
		_shard(p, at, 3.2, a + 0.6)
		glows.append([p.tp(at), 2.5, FROST_GLOW, 0.35])
	if cast:
		var oc := Vector2(cx, 4 + by)
		var opx := p.tp(oc)
		PR.orb(p, opx.x, opx.y, 7.0 * p.k, 2.0, PR.FROST6)
		p.light_only(cx, 22 + by, 30, FROST_GLOW, 0.5)
		glows.append([opx, 13.0, FROST_GLOW, 1.1])
	if atk == 2:
		for k in 8:
			var a3 := -0.6 + k * 0.17
			_shard(p, s_top + Vector2(cos(a3), sin(a3)) * (8.0 + (k % 3) * 4.0), 2.6, a3)
	return glows


static func rime_corpse(p: Painter) -> Array:
	var glows: Array = []
	p.cloth(PackedVector2Array([Vector2(14, 126), Vector2(26, 112), Vector2(64, 106), Vector2(104, 112), Vector2(116, 126)]), ROBE, 64, 52, 0.5, 0.45, -0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for k in 14:
		_shard(p, Vector2(rng.randf_range(24, 104), rng.randf_range(108, 124)), rng.randf_range(2.5, 6.0), rng.randf_range(0, PI))
	p.spec = 1.0
	p.capsule(Vector2(80, 108), Vector2(94, 108), 1.0, 1.0, Color(0.7, 0.78, 0.85))
	for i in 5:
		var ix := 81.0 + i * 3.0
		p.flat_poly(PackedVector2Array([Vector2(ix - 1, 108), Vector2(ix + 1, 108), Vector2(ix, 108 - 4.0 - (i % 2) * 4.0)]), ICE, Vector3(-0.4, -0.3, 1))
	p.spec = 0.0
	p.capsule(Vector2(6, 124), Vector2(70, 120), 1.5, 1.3, ICE.darkened(0.15))
	glows.append([p.tp(Vector2(64, 114)), 10.0, FROST_GLOW, 0.4])
	return glows


# =============================================================================== portraits (3 x 64x64)

static func portrait(kind: String) -> Image:
	var bgc: Color = {"rot": Color(0.05, 0.07, 0.025), "cinder": Color(0.07, 0.03, 0.015), "rime": Color(0.025, 0.045, 0.08)}[kind]
	var glow: Color = {"rot": ROT_GLOW, "cinder": MAGMA, "rime": FROST_GLOW}[kind]
	var frames: Array = []
	for f in 3:
		var p := Painter.new(64, 64, 3100 + f + kind.length())
		p.set_real(1.0)
		p.grain = 0.09
		for y in 64:
			for x in 64:
				var d := Vector2(x - 32, y - 26).length() / 38.0
				var g := clampf(1.0 - d, 0.0, 1.0)
				var c := bgc.lerp(glow * 0.3, g * g * (0.5 + 0.35 * f))
				p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		var glows: Array = []
		var cx := 32.0
		var cy := 29.0
		if f == 1:
			cx += 2.0
			cy -= 1.0
			var piv := Vector2(32, 62)
			p.xf = Transform2D(0.0, piv) * Transform2D(-0.08, Vector2.ZERO) * Transform2D(0.0, -piv)
		var expr: String = ["calm", "hurt", "enraged"][f]
		match kind:
			"rot":
				p.cloth(PackedVector2Array([Vector2(-4, 64), Vector2(2, 46), Vector2(18, 40), Vector2(46, 40), Vector2(62, 46), Vector2(68, 64)]), HABIT, 32, 34, 0.4, 0.35)
				p.ball(cx, cy - 2, 26, 28, VEIL)
				rot_head(p, cx, cy, 2.2, expr, glows)
				if f == 1:
					p.line(Vector2(cx - 8, cy - 10), Vector2(cx - 3, cy + 4), Color(0.3, 0.06, 0.06), 1.4)
				_gas(p, 10, 54, 6.0, 1 + f)
			"cinder":
				p.ball(cx, 62, 34, 14, CHAR)
				cinder_head(p, cx, cy + 2, 2.05, expr)
				_magma_cracks(p, 41 + f, 0.045, true)
				cinder_face(p, cx, cy + 2, 2.05, expr, glows, float(f) * 2.0)
				p.light_only(cx, cy + 20, 34, MAGMA, 0.3)
			"rime":
				p.cloth(PackedVector2Array([Vector2(-4, 64), Vector2(4, 48), Vector2(20, 44), Vector2(44, 44), Vector2(60, 48), Vector2(68, 64)]), ROBE_DEEP, 32, 34, 0.4, 0.35)
				for sv in [-1.0, 1.0]:
					var sd: float = sv
					p.flat_poly(PackedVector2Array([Vector2(cx + sd * 10, 50), Vector2(cx + sd * 30, 46), Vector2(cx + sd * 32, 26), Vector2(cx + sd * 16, 36)]), ROBE_PALE, Vector3(-sd * 0.3, -0.5, 1))
				rime_head(p, cx, cy + 3, 2.2, expr, glows)
		p.xf = Transform2D.IDENTITY
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1], g[2], g[3])
		p.harden_alpha(0.0)
		frames.append(p.img)
	return Painter.strip(frames)
