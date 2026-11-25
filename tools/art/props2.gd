extends RefCounted
## Map-pack props and effects (realistic pixel style, props alpha-hardened, fx may be soft).

const Painter := preload("res://tools/art/painter.gd")
const PR := preload("res://tools/art/props_real.gd")

const STONE := Color(0.42, 0.41, 0.39)
const WOOD := Color(0.3, 0.2, 0.12)
const IRON := Color(0.26, 0.26, 0.27)
const BONE := Color(0.66, 0.6, 0.48)
const MOSS := Color(0.2, 0.24, 0.13)
const ICE := Color(0.55, 0.82, 1.0)
const FROST := Color(0.5, 0.95, 1.0)
const MAGMA := Color(1.0, 0.45, 0.1)
const MAGMA_HOT := Color(1.0, 0.82, 0.4)
const TOXIC := Color(0.55, 0.85, 0.2)


static func _new(w: int, h: int, seed_value: int) -> Painter:
	var p := Painter.new(w, h, seed_value)
	p.set_real(1.0)
	p.grain = 0.12
	return p


static func _done(p: Painter) -> Image:
	p.rim(0.35, 0.1)
	p.harden_alpha()
	return p.img


static func sarcophagus() -> Image:
	var p := _new(96, 64, 1)
	var st := Color(0.4, 0.39, 0.37)
	# base box (front face + top edge)
	p.flat_poly(PackedVector2Array([Vector2(6, 36), Vector2(90, 36), Vector2(88, 63), Vector2(8, 63)]), st.darkened(0.1), Vector3(0, 0.05, 1))
	p.flat_poly(PackedVector2Array([Vector2(4, 31), Vector2(92, 31), Vector2(92, 37), Vector2(4, 37)]), st, Vector3(0, -1, 0.5))
	for i in 4:
		var px := 14.0 + i * 22.0
		p.flat_poly(PackedVector2Array([Vector2(px, 41), Vector2(px + 14, 41), Vector2(px + 14, 58), Vector2(px, 58)]), st.darkened(0.2), Vector3(0, 0, 1))
		p.line(Vector2(px, 41), Vector2(px + 14, 41), st.darkened(0.5))
		p.line(Vector2(px, 41), Vector2(px, 58), st.darkened(0.5))
		p.line(Vector2(px + 7, 44), Vector2(px + 7, 55), st.darkened(0.45))
		p.line(Vector2(px + 3.5, 48), Vector2(px + 10.5, 48), st.darkened(0.45))
	# lid with a recumbent knight effigy in profile
	p.flat_poly(PackedVector2Array([Vector2(2, 26), Vector2(94, 26), Vector2(92, 32), Vector2(4, 32)]), st.lightened(0.05), Vector3(0, -0.6, 1))
	var ef := st.lightened(0.08)
	p.ball(16, 21, 6.0, 5.5, ef)
	p.rect(10, 20, 10, 1, st.darkened(0.6))
	p.capsule(Vector2(21, 22), Vector2(62, 21), 6.0, 5.5, ef)
	p.ball(40, 17, 5.0, 3.0, ef)
	p.capsule(Vector2(36, 15.5), Vector2(46, 15.5), 1.6, 1.4, ef.lightened(0.05))
	p.blade(Vector2(46, 18), Vector2(84, 21), 1.8, 0.5, ef)
	p.capsule(Vector2(44, 15), Vector2(44, 21), 1.0, 1.0, ef)
	p.capsule(Vector2(62, 22), Vector2(84, 23), 4.0, 3.2, ef)
	p.ball(87, 20, 3.0, 4.2, ef)
	p.grime(MOSS, 0.5, 0.08, 0.2, 0.5)
	p.grime(Color(0.05, 0.05, 0.05), 0.45, 0.06, 0.12, 0.8)
	return _done(p)


static func well() -> Image:
	var p := _new(64, 64, 2)
	# roof
	p.flat_poly(PackedVector2Array([Vector2(8, 16), Vector2(32, 2), Vector2(56, 16), Vector2(52, 18), Vector2(32, 6), Vector2(12, 18)]), Color(0.28, 0.18, 0.1), Vector3(0, -0.6, 1))
	for i in 6:
		p.line(Vector2(12 + i * 3.6, 16 - i * 2.0), Vector2(32 + i * 3.6, 4 + i * 2.0), Color(0.18, 0.11, 0.06))
	for sx in [14.0, 50.0]:
		p.capsule(Vector2(sx, 16), Vector2(sx, 44), 1.8, 1.8, WOOD)
	p.capsule(Vector2(14, 22), Vector2(50, 22), 1.6, 1.6, WOOD.lightened(0.05))
	p.line(Vector2(32, 22), Vector2(32, 34), Color(0.5, 0.42, 0.28))
	p.spec = 0.5
	p.flat_poly(PackedVector2Array([Vector2(28.5, 34), Vector2(35.5, 34), Vector2(34.5, 41), Vector2(29.5, 41)]), Color(0.32, 0.22, 0.13), Vector3(0, 0, 1))
	p.line(Vector2(28.5, 36), Vector2(35.5, 36), IRON)
	p.spec = 0.0
	# stone ring (front view cylinder of stones)
	p.cyl_poly(PackedVector2Array([Vector2(8, 42), Vector2(56, 42), Vector2(56, 63), Vector2(8, 63)]), STONE, 32, 24, -0.1)
	p.ellipse(32, 42, 24.5, 3.6, STONE.lightened(0.1))
	p.ellipse(32, 42.6, 20.5, 2.4, Color(0.03, 0.04, 0.05))
	for row in 3:
		var yy := 46.0 + row * 6.0
		p.line(Vector2(9, yy), Vector2(55, yy), STONE.darkened(0.55))
		for k in 6:
			var xx := 12.0 + k * 8.0 + (4.0 if row % 2 == 1 else 0.0)
			p.line(Vector2(xx, yy), Vector2(xx, yy + 6), STONE.darkened(0.55))
	p.grime(MOSS, 0.5, 0.1, 0.2, 0.6)
	return _done(p)


static func fence() -> Image:
	var p := _new(64, 48, 3)
	p.grain = 0.16
	for px in [6.0, 30.0, 56.0]:
		var lean := 0.0 if px != 56.0 else 5.0
		p.capsule(Vector2(px, 47), Vector2(px + lean, 12), 2.6, 2.2, WOOD)
		p.poly(PackedVector2Array([Vector2(px + lean - 2.4, 12), Vector2(px + lean + 2.4, 12), Vector2(px + lean, 7)]), WOOD)
	p.capsule(Vector2(3, 20), Vector2(33, 21), 1.8, 1.8, WOOD.lightened(0.06))
	p.capsule(Vector2(3, 34), Vector2(33, 35), 1.8, 1.8, WOOD.lightened(0.04))
	p.capsule(Vector2(31, 35), Vector2(60, 34), 1.8, 1.8, WOOD.lightened(0.04))
	# broken upper rail hanging down
	p.capsule(Vector2(31, 21), Vector2(44, 32), 1.8, 1.6, WOOD.lightened(0.06))
	p.poly(PackedVector2Array([Vector2(43, 30.5), Vector2(47, 33), Vector2(44.5, 34.5)]), WOOD.lightened(0.2))
	p.spec = 0.6
	for n in [Vector2(6, 20), Vector2(30, 21), Vector2(30, 35), Vector2(6, 34)]:
		var nv: Vector2 = n
		p.ball(nv.x, nv.y, 0.8, 0.8, IRON)
	p.spec = 0.0
	for k in 7:
		p.line(Vector2(2 + k * 9.0, 47), Vector2(3 + k * 9.0 + (k % 3 - 1), 43), Color(0.24, 0.28, 0.15))
	p.grime(MOSS, 0.4, 0.12, 0.25, 0.5)
	return _done(p)


static func crystal() -> Image:
	var p := _new(48, 96, 4)
	p.grain = 0.06
	var shards := [[Vector2(24, 95), Vector2(23, 10), 7.0], [Vector2(14, 95), Vector2(7, 40), 5.0], [Vector2(34, 95), Vector2(42, 34), 5.5], [Vector2(19, 95), Vector2(12, 62), 4.0], [Vector2(30, 95), Vector2(36, 64), 4.0]]
	for sh in shards:
		var a: Vector2 = sh[0]
		var b: Vector2 = sh[1]
		var wdt: float = sh[2]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var tip := b
		var shoulder := b - d * wdt * 1.6
		p.spec = 1.0
		p.shininess = 30.0
		p.flat_poly(PackedVector2Array([a + n * wdt, shoulder + n * wdt, tip, shoulder]), ICE.darkened(0.1), Vector3(-0.7, -0.3, 0.6))
		p.flat_poly(PackedVector2Array([a, shoulder, tip, shoulder - n * wdt, a - n * wdt]), ICE.darkened(0.35), Vector3(0.6, -0.2, 0.7))
		p.spec = 0.0
		p.line(a + n * wdt * 0.6, shoulder + n * wdt * 0.6, Color(0.92, 1.0, 1.0))
		p.line(shoulder, tip, Color(0.85, 0.98, 1.0))
	p.shininess = 18.0
	p.ball(24, 93, 18, 3.5, Color(0.32, 0.36, 0.4))
	p.rim(0.25, 0.0)
	p.light_only(24, 50, 30, FROST, 0.35)
	for g in [Vector2(23, 30), Vector2(10, 52), Vector2(39, 50)]:
		var gv: Vector2 = g
		p.glow(gv.x, gv.y, 7.0, FROST, 0.5)
	p.harden_alpha()
	return p.img


static func obsidian_spike() -> Image:
	var p := _new(48, 96, 5)
	p.grain = 0.1
	var black := Color(0.09, 0.085, 0.1)
	p.flat_poly(PackedVector2Array([Vector2(8, 95), Vector2(16, 60), Vector2(20, 40), Vector2(25, 6), Vector2(27, 30), Vector2(26, 95)]), black.lightened(0.04), Vector3(-0.6, -0.2, 0.7))
	p.flat_poly(PackedVector2Array([Vector2(25, 6), Vector2(30, 34), Vector2(34, 52), Vector2(40, 95), Vector2(26, 95), Vector2(27, 30)]), black, Vector3(0.6, -0.1, 0.7))
	p.flat_poly(PackedVector2Array([Vector2(28, 95), Vector2(38, 70), Vector2(44, 58), Vector2(43, 95)]), black.lightened(0.02), Vector3(0.4, -0.3, 0.8))
	p.line(Vector2(25, 6), Vector2(26, 95), Color(0.32, 0.33, 0.4))
	p.line(Vector2(16, 60), Vector2(25, 10), Color(0.3, 0.31, 0.38))
	# glowing fissures
	var cracks := [[Vector2(22, 90), Vector2(20, 72), Vector2(23, 58), Vector2(21, 44)], [Vector2(31, 88), Vector2(33, 74), Vector2(30, 62)], [Vector2(38, 92), Vector2(40, 78)]]
	for cr in cracks:
		var pts := PackedVector2Array(cr)
		for i in pts.size() - 1:
			p.line(pts[i], pts[i + 1], MAGMA, 1.4)
			p.line(pts[i], pts[i + 1], MAGMA_HOT, 0.6)
	p.ball(25, 93, 18, 3.0, Color(0.12, 0.1, 0.1))
	p.rim(0.3, 0.0)
	for cr in cracks:
		var c0: Vector2 = cr[0]
		var c1: Vector2 = cr[1]
		var m := c0.lerp(c1, 0.5)
		p.glow(m.x, m.y, 6.0, MAGMA, 0.45)
	p.harden_alpha()
	return p.img


static func candles_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _new(32, 32, 60 + f)
		# stone slab + skull
		p.flat_poly(PackedVector2Array([Vector2(3, 27), Vector2(29, 27), Vector2(30, 31.5), Vector2(2, 31.5)]), STONE.darkened(0.1), Vector3(0, -0.3, 1))
		p.ball(17, 23, 4.6, 4.2, BONE)
		p.ellipse(15.3, 23, 1.2, 1.3, Color(0.05, 0.04, 0.03))
		p.ellipse(18.7, 23, 1.2, 1.3, Color(0.05, 0.04, 0.03))
		p.ball(17, 26.5, 2.8, 1.2, BONE.darkened(0.1))
		var wax := Color(0.78, 0.74, 0.62)
		var cand := [[Vector2(7, 27), 9.0, 1.5], [Vector2(11, 27), 6.0, 1.3], [Vector2(24, 27), 11.0, 1.6], [Vector2(27.5, 27), 5.0, 1.2], [Vector2(17, 19), 4.0, 1.1]]
		for c in cand:
			var base: Vector2 = c[0]
			var ht: float = c[1]
			var r: float = c[2]
			p.capsule(base, base - Vector2(0, ht), r, r, wax)
			p.ball(base.x + r * 0.6, base.y - ht * 0.4, 0.7, 1.6, wax.lightened(0.1))
		for c in cand:
			var base2: Vector2 = c[0]
			p.ball(base2.x, base2.y - 0.5, float(c[2]) + 1.2, 1.0, wax.darkened(0.08))
		p.rim(0.3, 0.0)
		for i in cand.size():
			var c3: Array = cand[i]
			var b3: Vector2 = c3[0]
			var top := b3.y - float(c3[1]) - 0.5
			PR.flame(p, b3.x + ((f + i) % 2) * 0.3, top, 4.0 + ((f + i) % 3) * 0.8, 1.2, f * 1.9 + i * 2.3)
			p.glow(b3.x, top - 2, 4.0, Color(1.0, 0.55, 0.2), 0.3)
		p.harden_alpha(0.45)
		frames.append(p.img)
	return Painter.strip(frames)


static func cauldron_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _new(48, 48, 80 + f)
		p.spec = 0.6
		for lx in [12.0, 36.0]:
			p.capsule(Vector2(lx, 38), Vector2(lx + (lx - 24) * 0.15, 46.5), 1.6, 1.3, IRON)
		p.ball(24, 32, 17, 13, IRON)
		p.capsule(Vector2(6, 22.5), Vector2(42, 22.5), 2.0, 2.0, IRON.lightened(0.08))
		p.spec = 0.0
		p.ellipse(24, 22, 16.5, 3.2, Color(0.3, 0.45, 0.08))
		p.ellipse(24, 21.6, 15, 2.4, Color(0.48, 0.72, 0.14))
		var rng := RandomNumberGenerator.new()
		rng.seed = 400 + f
		for b in 5:
			var bx := rng.randf_range(12, 36)
			var br := rng.randf_range(1.0, 2.4) * (0.6 + 0.4 * float((f + b) % 3))
			p.ball(bx, 21 - br * 0.5, br, br * 0.8, Color(0.62, 0.9, 0.22))
			p.put(int(bx) - 1, int(21 - br), Color(0.9, 1.0, 0.7))
		p.rim(0.3, 0.0)
		for k in 3:
			var sx := 16.0 + k * 8.0 + (f % 2) * 2.0
			p.ball(sx, 14 - k * 2.0 - f * 1.5 + 2.0, 3.0, 2.4, Color(0.45, 0.6, 0.25))
		p.light_only(24, 22, 14, TOXIC, 0.4)
		p.glow(24, 20, 10, TOXIC, 0.35)
		p.harden_alpha(0.45)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== fx

static func acid_pool() -> Image:
	var p := Painter.new(128, 128, 90)
	var n := FastNoiseLite.new()
	n.seed = 4
	n.frequency = 0.035
	n.fractal_octaves = 3
	var fine := FastNoiseLite.new()
	fine.seed = 5
	fine.frequency = 0.25
	for y in 128:
		for x in 128:
			var d := Vector2(x + 0.5 - 64, y + 0.5 - 64).length() / 60.0
			var edge := d + n.get_noise_2d(x, y) * 0.35
			if edge > 1.0:
				continue
			var a := clampf((1.0 - edge) * 3.0, 0.0, 0.85)
			var c := Color(0.34, 0.48, 0.07).lerp(Color(0.62, 0.82, 0.18), clampf(1.0 - edge, 0.0, 1.0))
			if edge > 0.85:
				c = Color(0.22, 0.3, 0.05)
			if fine.get_noise_2d(x, y) > 0.55:
				c = c.lightened(0.3)
			p.put(x, y, Color(c.r, c.g, c.b, a))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in 14:
		var bp := Vector2(rng.randf_range(30, 98), rng.randf_range(30, 98))
		var r := rng.randf_range(1.5, 4.0)
		p.ellipse(bp.x, bp.y, r, r, Color(0.7, 0.92, 0.3, 0.85))
		p.put(int(bp.x - r * 0.4), int(bp.y - r * 0.4), Color(0.95, 1.0, 0.8, 0.95))
	return p.img


static func meteor_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(48, 48, 120 + f)
		p.set_real(1.0)
		p.grain = 0.1
		# flame trail streaming upward
		for k in 3:
			PR.flame(p, 24.0 + (k - 1) * 5.0 + (f % 2), 34.0, 26.0 - absf(k - 1.0) * 7.0, 6.0 - absf(k - 1.0) * 1.5, f * 1.7 + k * 2.2)
		# burning rock
		p.ball(24, 36, 9.5, 9.0, Color(0.16, 0.13, 0.12))
		p.ball(21, 33, 4.0, 3.4, Color(0.2, 0.16, 0.14))
		for cr in [[Vector2(18, 36), Vector2(24, 38), Vector2(30, 34)], [Vector2(22, 30), Vector2(25, 34)], [Vector2(20, 41), Vector2(27, 42)]]:
			var pts := PackedVector2Array(cr)
			for i in pts.size() - 1:
				p.line(pts[i], pts[i + 1], MAGMA, 1.2)
				p.line(pts[i], pts[i + 1], MAGMA_HOT, 0.5)
		p.glow(24, 36, 16, MAGMA, 0.45)
		frames.append(p.img)
	return Painter.strip(frames)
