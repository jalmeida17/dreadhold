extends RefCounted
## Realistic props, pickups, effects and HUD portraits (double resolution of the original set).
## Designs are written in the original design units and drawn with k = 2.

const Painter := preload("res://tools/art/painter.gd")
const Creatures := preload("res://tools/art/creatures.gd")

const IRON := Color(0.27, 0.26, 0.27)
const RUSTY := Color(0.3, 0.2, 0.14)
const WOOD := Color(0.3, 0.2, 0.13)
const STONE := Color(0.42, 0.41, 0.4)
const BONE := Color(0.68, 0.62, 0.5)
const GOLD := Color(0.66, 0.5, 0.2)
const MOSS := Color(0.2, 0.24, 0.13)

const FIRE6 := [Color(0.35, 0.05, 0.02), Color(0.62, 0.14, 0.03), Color(0.86, 0.33, 0.06), Color(0.98, 0.56, 0.14), Color(1.0, 0.8, 0.4), Color(1.0, 0.96, 0.82)]
const SHADOW6 := [Color(0.1, 0.02, 0.16), Color(0.25, 0.06, 0.4), Color(0.45, 0.15, 0.7), Color(0.65, 0.35, 0.95), Color(0.85, 0.65, 1.0), Color(1.0, 0.95, 1.0)]
const SOUL6 := [Color(0.02, 0.14, 0.06), Color(0.06, 0.32, 0.14), Color(0.15, 0.6, 0.27), Color(0.35, 0.88, 0.45), Color(0.65, 1.0, 0.7), Color(0.95, 1.0, 0.95)]
const FROST6 := [Color(0.04, 0.14, 0.3), Color(0.1, 0.3, 0.55), Color(0.25, 0.55, 0.85), Color(0.5, 0.8, 1.0), Color(0.78, 0.94, 1.0), Color(0.97, 1.0, 1.0)]


static func _new(w: int, h: int, seed_value: int, k: float = 2.0) -> Painter:
	var p := Painter.new(w, h, seed_value)
	p.set_real(k)
	return p


static func _pal(palette: Array, inten: float) -> Color:
	var i := clampi(int(inten * float(palette.size())), 0, palette.size() - 1)
	return palette[i]


# =============================================================================== fire & energy

static func flame(p: Painter, cx: float, base_y: float, height: float, half_w: float, phase: float, palette: Array = FIRE6) -> void:
	## Turbulent flame tongue, coordinates in design units.
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.12
	n.fractal_octaves = 3
	var c0 := p.tp(Vector2(cx, base_y))
	var H := height * p.k
	var HW := half_w * p.k
	for y in range(int(c0.y - H) - 1, int(c0.y + HW * 0.6) + 1):
		for x in range(int(c0.x - HW * 2.0), int(c0.x + HW * 2.0) + 1):
			var v := (c0.y - (y + 0.5)) / H
			if v < -0.15 or v > 1.0:
				continue
			var vv := clampf(v, 0.0, 1.0)
			var radius := HW * pow(1.0 - vv, 0.85) * (0.55 + 0.45 * sin(minf(vv * 4.0 + 0.6, PI * 0.5)))
			if v < 0.0:
				radius = HW * (1.0 + v * 5.0)
			var shift := sin(vv * 5.5 + phase) * vv * HW * 0.55 + n.get_noise_2d(x * 0.8, y * 0.6 + phase * 30.0) * vv * HW * 0.6
			var d := absf(x + 0.5 - c0.x - shift)
			if radius <= 0.2 or d > radius:
				continue
			var inten := (1.0 - d / radius) * (1.0 - vv * 0.6) + n.get_noise_2d(x * 1.7 + phase * 11.0, y * 1.7) * 0.22
			if inten < 0.06:
				continue
			p.put(x, y, _pal(palette, clampf(inten * 1.15, 0.0, 0.999)))


static func orb(p: Painter, cx: float, cy: float, r: float, phase: float, palette: Array) -> void:
	## Swirling energy ball (pixel coordinates).
	var n := FastNoiseLite.new()
	n.seed = 11
	n.frequency = 0.5
	n.fractal_octaves = 3
	for y in range(int(cy - r * 1.6), int(cy + r * 1.6) + 1):
		for x in range(int(cx - r * 1.6), int(cx + r * 1.6) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy)
			var ang := d.angle()
			var rr := r * (1.0 + 0.32 * n.get_noise_2d(cos(ang) * 2.5 + phase, sin(ang) * 2.5 + phase * 0.7))
			var t := d.length() / rr
			if t > 1.0:
				continue
			var swirl := n.get_noise_2d(d.x * 0.8 + cos(phase) * 5.0, d.y * 0.8 + sin(phase) * 5.0) * 0.25
			p.put(x, y, _pal(palette, clampf(1.0 - t + 0.05 + swirl, 0.0, 0.999)))


static func orb_sheet(size: int, frames_n: int, palette: Array, r: float, glow_col: Color) -> Image:
	var frames: Array = []
	for f in frames_n:
		var p := Painter.new(size, size, 300 + f)
		var c := size * 0.5
		p.glow_px(c, c, size * 0.5, glow_col, 0.6)
		orb(p, c, c, r, f * 1.6, palette)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== props

static func torch_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _new(32, 64, 40 + f)
		p.spec = 0.5
		# wall plate + bracket ring
		p.flat_poly(PackedVector2Array([Vector2(5.5, 24), Vector2(10.5, 24), Vector2(10.5, 31.5), Vector2(5.5, 31.5)]), IRON, Vector3(0, 0, 1))
		p.ball(8, 25.2, 0.6, 0.6, IRON.lightened(0.3))
		p.ball(8, 30.2, 0.6, 0.6, IRON.lightened(0.3))
		p.capsule(Vector2(8, 27.5), Vector2(8, 21.5), 0.8, 0.8, IRON)
		p.capsule(Vector2(4.5, 21.5), Vector2(11.5, 21.5), 0.8, 0.8, IRON)
		p.capsule(Vector2(4.5, 21.5), Vector2(5.2, 15.5), 0.7, 0.6, IRON)
		p.capsule(Vector2(11.5, 21.5), Vector2(10.8, 15.5), 0.7, 0.6, IRON)
		p.spec = 0.0
		# wooden handle with pitch-soaked rag
		p.capsule(Vector2(8, 26), Vector2(8, 15), 1.5, 1.8, WOOD)
		p.capsule(Vector2(8, 16.5), Vector2(8, 13.2), 2.4, 2.5, Color(0.12, 0.09, 0.07), 0.3)
		p.rim(0.3, 0.0)
		flame(p, 8.0 + (f % 2) * 0.4 - 0.2, 14.0, 12.5 + (f % 3), 3.4, f * 1.7)
		p.glow(8, 8, 9, Color(1.0, 0.5, 0.15), 0.28)
		p.harden_alpha(0.45)
		frames.append(p.img)
	return Painter.strip(frames)


static func brazier_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _new(64, 96, 60 + f)
		p.spec = 0.5
		for side in [-1.0, 1.0]:
			var s: float = side
			p.strand(PackedVector2Array([Vector2(16 + s * 4, 30), Vector2(16 + s * 8, 38), Vector2(16 + s * 10, 46.5)]), 1.1, 0.9, IRON)
			p.ball(16 + s * 10.2, 46.8, 1.4, 0.9, IRON)
		p.capsule(Vector2(16, 30), Vector2(16, 46.5), 1.0, 0.9, IRON.darkened(0.2))
		p.capsule(Vector2(10, 40), Vector2(22, 40), 0.6, 0.6, IRON)
		p.ball(16, 28, 12, 5, IRON)
		p.capsule(Vector2(4, 25.8), Vector2(28, 25.8), 1.1, 1.1, RUSTY)
		p.spec = 0.0
		# glowing coals
		for kk in 14:
			var cx := 6.0 + kk * 1.55
			p.ball(cx, 25.0 + sin(kk * 2.1) * 0.6, 1.2, 0.9, Color(0.75, 0.22, 0.05) if (kk + f) % 3 else Color(1.0, 0.55, 0.15))
		p.rim(0.3, 0.0)
		flame(p, 12.5 + (f % 2), 25.5, 18 + (f % 3) * 1.5, 5.0, f * 1.3)
		flame(p, 19.5 - (f % 2), 25.5, 14 + ((f + 1) % 3) * 1.5, 4.0, f * 1.9 + 2.0)
		for kk in 5:
			var sp := Vector2(10 + ((kk * 7 + f * 5) % 13), 10 - ((kk * 5 + f * 3) % 9))
			p.ball(sp.x, sp.y, 0.35, 0.35, Color(1.0, 0.75, 0.3))
		p.glow(16, 16, 16, Color(1.0, 0.45, 0.12), 0.25)
		p.harden_alpha(0.45)
		frames.append(p.img)
	return Painter.strip(frames)


static func tree() -> Image:
	var p := _new(128, 192, 77)
	p.grain = 0.16
	var bark := Color(0.2, 0.16, 0.13)
	p.strand(PackedVector2Array([Vector2(33, 95), Vector2(31.5, 80), Vector2(32.5, 70), Vector2(30, 60)]), 6.8, 4.2, bark, 0.2)
	p.strand(PackedVector2Array([Vector2(20, 96), Vector2(26, 91), Vector2(31, 86)]), 2.6, 1.4, bark)
	p.strand(PackedVector2Array([Vector2(45, 96), Vector2(38, 91), Vector2(34, 86)]), 2.6, 1.4, bark)
	var branches := [
		[[Vector2(30, 62), Vector2(22, 50), Vector2(16, 40)], 4.0, 2.2], [[Vector2(16, 40), Vector2(11, 30), Vector2(8, 22)], 2.2, 1.0],
		[[Vector2(16, 40), Vector2(9, 39), Vector2(3, 36)], 1.5, 0.6], [[Vector2(30, 62), Vector2(37, 48), Vector2(41, 36)], 3.6, 2.0],
		[[Vector2(41, 36), Vector2(47, 26), Vector2(53, 17)], 2.0, 0.8], [[Vector2(41, 36), Vector2(50, 35), Vector2(57, 31)], 1.5, 0.6],
		[[Vector2(41, 36), Vector2(38, 24), Vector2(36, 12)], 1.6, 0.6], [[Vector2(8, 22), Vector2(10, 15), Vector2(13, 9)], 1.0, 0.45],
		[[Vector2(53, 17), Vector2(57, 12), Vector2(61, 7)], 1.0, 0.4], [[Vector2(30, 62), Vector2(27, 45), Vector2(25, 30)], 2.0, 1.0],
		[[Vector2(25, 30), Vector2(23, 22), Vector2(22, 13)], 1.2, 0.5], [[Vector2(22, 50), Vector2(15, 52), Vector2(9, 55)], 1.2, 0.5],
	]
	for b in branches:
		var pts: Array = b[0]
		p.strand(PackedVector2Array(pts), b[1], b[2], bark, 0.15)
	# bark furrows
	for kk in 7:
		p.line(Vector2(29 + kk * 0.9, 93), Vector2(28.5 + kk * 1.0, 64), bark.darkened(0.45), 0.5)
	# hanging noose
	p.line(Vector2(16, 41), Vector2(16, 54), Color(0.42, 0.35, 0.22), 0.8)
	p.ball(16, 56, 2.2, 1.8, Color(0.42, 0.35, 0.22))
	p.erase_ellipse(16, 56, 1.2, 1.0)
	p.grime(MOSS, 0.4, 0.06, 0.25, 0.5)
	p.rim(0.35, 0.1)
	p.harden_alpha()
	return p.img


static func graves_sheet() -> Image:
	var frames: Array = []
	for v in 3:
		var p := _new(48, 64, 90 + v)
		p.grain = 0.14
		var stone := Color(0.42, 0.42, 0.43) * (1.0 - v * 0.05)
		if v == 0:
			# celtic cross
			p.flat_poly(PackedVector2Array([Vector2(10.3, 6), Vector2(13.7, 6), Vector2(14, 30), Vector2(10, 30)]), stone, Vector3(-0.15, -0.1, 1))
			p.flat_poly(PackedVector2Array([Vector2(4.5, 10.5), Vector2(19.5, 10.5), Vector2(19.5, 14), Vector2(4.5, 14)]), stone, Vector3(0, -0.35, 1))
			for a in 24:
				var ang := float(a) / 24.0 * TAU
				p.ball(12 + cos(ang) * 4.6, 12.3 + sin(ang) * 4.6, 0.75, 0.75, stone.darkened(0.05))
		elif v == 1:
			p.cyl_poly(PackedVector2Array([Vector2(4, 30), Vector2(4, 12), Vector2(6.5, 7.5), Vector2(12, 5.5), Vector2(17.5, 7.5), Vector2(20, 12), Vector2(20, 30)]), stone, 12, 9.5, -0.2)
			p.line(Vector2(7.5, 16), Vector2(16.5, 16), stone.darkened(0.45), 0.6)
			p.line(Vector2(8.5, 19), Vector2(15.5, 19), stone.darkened(0.45), 0.6)
			p.line(Vector2(9, 22), Vector2(15, 22), stone.darkened(0.45), 0.6)
			p.line(Vector2(12, 9.5), Vector2(12, 14), stone.darkened(0.45), 0.6)
			p.line(Vector2(10.5, 11), Vector2(13.5, 11), stone.darkened(0.45), 0.6)
			p.line(Vector2(15, 7), Vector2(13, 13), stone.darkened(0.55), 0.6)
		else:
			# broken leaning obelisk
			p.flat_poly(PackedVector2Array([Vector2(6, 30), Vector2(7, 10), Vector2(10, 4), Vector2(12.5, 7), Vector2(14, 5.5), Vector2(16, 12), Vector2(18, 30)]), stone, Vector3(-0.3, -0.2, 1))
			p.flat_poly(PackedVector2Array([Vector2(12.5, 7), Vector2(14, 5.5), Vector2(16, 12), Vector2(14, 12)]), stone.darkened(0.2), Vector3(0.6, 0, 1))
			p.line(Vector2(9, 12), Vector2(14.5, 22), stone.darkened(0.55), 0.6)
		# soil mound + grass at the base
		p.ball(12, 30.5, 10.5, 2.2, Color(0.2, 0.16, 0.11))
		for kk in 9:
			p.line(Vector2(3.5 + kk * 2.1, 30.5), Vector2(3 + kk * 2.2 + (kk % 3 - 1) * 0.8, 27.5 - (kk % 2)), Color(0.24, 0.28, 0.15), 0.6)
		p.grime(MOSS, 0.55, 0.08, 0.18, 0.4)
		p.grime(Color(0.06, 0.05, 0.05), 0.4, 0.05, 0.15, 0.8)
		p.rim(0.3, 0.08)
		p.harden_alpha()
		frames.append(p.img)
	return Painter.strip(frames)


static func bones_prop() -> Image:
	var p := _new(64, 32, 120)
	for b in [[Vector2(4, 13), Vector2(14, 11)], [Vector2(18, 13.5), Vector2(28, 14)], [Vector2(10, 14.5), Vector2(22, 12.5)]]:
		var a: Vector2 = b[0]
		var e: Vector2 = b[1]
		p.capsule(a, e, 0.9, 0.8, BONE)
		p.ball(a.x, a.y, 1.25, 1.1, BONE)
		p.ball(e.x, e.y, 1.25, 1.1, BONE)
	for kk in 3:
		p.strand(PackedVector2Array([Vector2(14 + kk * 2, 10.5), Vector2(13 + kk * 2.2, 12.5), Vector2(13.5 + kk * 2.2, 14.5)]), 0.6, 0.5, BONE)
	p.ball(24, 10, 3.3, 3.0, BONE)
	p.ball(24, 12.2, 2.2, 1.0, BONE)
	p.ellipse(22.8, 9.8, 0.9, 1.0, Color(0.05, 0.04, 0.04))
	p.ellipse(25.4, 9.8, 0.9, 1.0, Color(0.05, 0.04, 0.04))
	p.grime(Color(0.25, 0.18, 0.1), 0.5, 0.15, 0.05)
	p.rim(0.35, 0.0)
	p.harden_alpha()
	return p.img


static func barrel() -> Image:
	var p := _new(48, 64, 130)
	var wood := Color(0.33, 0.21, 0.12)
	p.cyl_poly(PackedVector2Array([Vector2(5, 3), Vector2(19, 3), Vector2(21, 10), Vector2(21.5, 17), Vector2(21, 23), Vector2(19, 30), Vector2(5, 30), Vector2(3, 23), Vector2(2.5, 17), Vector2(3, 10)]), wood, 12, 9.8)
	for kk in 6:
		var sx := 5.2 + kk * 2.75
		p.line(Vector2(sx, 3.5), Vector2(sx + (sx - 12) * 0.12, 29.5), wood.darkened(0.55), 0.5)
	p.spec = 0.6
	for by in [6.5, 12.0, 21.5, 26.5]:
		var byy: float = by
		var hw := 9.0 if (byy > 9 and byy < 24) else 8.0
		p.capsule(Vector2(12 - hw, byy), Vector2(12 + hw, byy), 0.7, 0.7, RUSTY)
	p.spec = 0.0
	p.ellipse(12, 3.2, 7.1, 1.5, wood.darkened(0.35))
	p.grime(Color(0.08, 0.06, 0.04), 0.45, 0.08, 0.1, 0.7)
	p.rim(0.35, 0.08)
	p.harden_alpha()
	return p.img


static func statue() -> Image:
	## Weathered stone knight on a plinth, sword point-down, moss streaks.
	var p := _new(96, 192, 140)
	p.grain = 0.15
	var stone := Color(0.46, 0.45, 0.44)
	p.flat_poly(PackedVector2Array([Vector2(6, 78), Vector2(42, 78), Vector2(44, 94), Vector2(4, 94)]), stone.darkened(0.12), Vector3(0, -0.1, 1))
	p.flat_poly(PackedVector2Array([Vector2(4, 74), Vector2(44, 74), Vector2(44, 79), Vector2(4, 79)]), stone, Vector3(0, -1, 0.6))
	p.line(Vector2(8, 85), Vector2(40, 85), stone.darkened(0.5), 0.5)
	for side in [-1.0, 1.0]:
		var s: float = side
		p.capsule(Vector2(24 + s * 4.5, 54), Vector2(24 + s * 5, 66), 3.4, 2.8, stone)
		p.capsule(Vector2(24 + s * 5, 66), Vector2(24 + s * 5.5, 73), 2.8, 2.4, stone)
		p.ball(24 + s * 5.5, 73.5, 3.2, 1.6, stone)
	# surcoat + mail
	p.cloth(PackedVector2Array([Vector2(12, 27), Vector2(36, 27), Vector2(39, 62), Vector2(33, 70), Vector2(15, 70), Vector2(9, 62)]), stone.darkened(0.08), 24, 15, 0.9, 0.35)
	p.cyl_poly(PackedVector2Array([Vector2(14, 29), Vector2(34, 29), Vector2(32, 52), Vector2(16, 52)]), stone, 24, 11, -0.3)
	p.capsule(Vector2(14, 49), Vector2(34, 49), 1.2, 1.2, stone.darkened(0.15))
	p.ball(12, 28.5, 6.2, 5, stone)
	p.ball(36, 28.5, 6.2, 5, stone)
	p.capsule(Vector2(12, 32), Vector2(19, 45), 2.6, 2.3, stone)
	p.capsule(Vector2(36, 32), Vector2(29, 45), 2.6, 2.3, stone)
	p.blade(Vector2(24, 46), Vector2(24, 74), 2.4, 0.5, stone.lightened(0.05))
	p.capsule(Vector2(17.5, 44.5), Vector2(30.5, 44.5), 1.2, 1.2, stone)
	p.capsule(Vector2(24, 37), Vector2(24, 44), 1.0, 1.0, stone)
	p.ball(24, 36.5, 2.0, 2.0, stone)
	p.ball(21, 45.5, 2.2, 2.0, stone)
	p.ball(27, 45.5, 2.2, 2.0, stone)
	# mail aventail + plate gorget seating the helm on the shoulders
	p.cyl_poly(PackedVector2Array([Vector2(17.5, 19), Vector2(30.5, 19), Vector2(35, 31.5), Vector2(13, 31.5)]), stone.darkened(0.12), 24, 11, -0.4)
	for my in range(21, 31, 2):
		for mx in range(15, 34, 2):
			if Geometry2D.is_point_in_polygon(Vector2(mx + (my % 4) * 0.5, my), PackedVector2Array([Vector2(17.5, 19), Vector2(30.5, 19), Vector2(35, 31.5), Vector2(13, 31.5)])):
				p.tput(mx + (my % 4) * 0.5, my, stone.darkened(0.42))
	p.cyl_poly(PackedVector2Array([Vector2(16, 25), Vector2(32, 25), Vector2(34.5, 29.5), Vector2(13.5, 29.5)]), stone, 24, 11, -0.6)
	p.line(Vector2(15, 27.2), Vector2(33, 27.2), stone.darkened(0.45), 0.6)
	p.line(Vector2(15.2, 27.9), Vector2(32.8, 27.9), stone.lightened(0.1), 0.5)
	# great helm (its lower rim overlaps the gorget)
	p.cyl_poly(PackedVector2Array([Vector2(18.5, 11), Vector2(29.5, 11), Vector2(30.2, 25.5), Vector2(17.8, 25.5)]), stone, 24, 6, -0.15)
	p.line(Vector2(17.8, 25), Vector2(30.2, 25), stone.darkened(0.35), 0.6)
	p.ball(24, 11, 5.6, 2.5, stone.lightened(0.05))
	p.rect(19.5, 16, 9, 0.9, Color(0.05, 0.05, 0.05))
	p.line(Vector2(24, 17), Vector2(24, 23.5), stone.darkened(0.4), 0.5)
	p.grime(MOSS, 0.6, 0.06, 0.15, 0.85)
	p.grime(Color(0.07, 0.07, 0.07), 0.5, 0.05, 0.1, 0.9)
	p.rim(0.35, 0.1)
	p.harden_alpha()
	return p.img


static func altar_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _new(96, 80, 150 + f)
		p.grain = 0.13
		var stone := Color(0.26, 0.27, 0.31)
		p.flat_poly(PackedVector2Array([Vector2(4, 18), Vector2(44, 18), Vector2(41, 38.5), Vector2(7, 38.5)]), stone, Vector3(0, 0, 1))
		p.flat_poly(PackedVector2Array([Vector2(2, 14), Vector2(46, 14), Vector2(46, 19), Vector2(2, 19)]), stone.lightened(0.12), Vector3(0, -1, 0.5))
		p.line(Vector2(2, 19), Vector2(46, 19), stone.darkened(0.5), 0.6)
		for kk in 3:
			var rx := 14.0 + kk * 10
			p.line(Vector2(rx, 23), Vector2(rx, 34), Color(0.03, 0.08, 0.05), 1.4)
			p.line(Vector2(rx - 3, 26.5), Vector2(rx + 3, 30.5), Color(0.03, 0.08, 0.05), 1.4)
		# candles & a skull offering
		for cx in [7.0, 10.0, 38.0, 41.0]:
			var cxx: float = cx
			var hgt := 5.0 if int(cxx) % 2 == 0 else 3.5
			p.capsule(Vector2(cxx, 13.5), Vector2(cxx, 13.5 - hgt), 0.9, 0.9, Color(0.75, 0.7, 0.58))
		p.ball(24, 11, 3.6, 3.3, BONE)
		p.ball(24, 13.4, 2.4, 1.1, BONE)
		p.ellipse(22.7, 10.8, 0.9, 1.0, Color(0.04, 0.03, 0.03))
		p.ellipse(25.3, 10.8, 0.9, 1.0, Color(0.04, 0.03, 0.03))
		p.grime(Color(0.05, 0.05, 0.06), 0.4, 0.06, 0.15, 0.8)
		p.rim(0.32, 0.08)
		# glowing runes (pulse)
		var pulse := 0.65 + 0.3 * sin(f * PI * 0.5)
		for kk in 3:
			var rx2 := 14.0 + kk * 10
			p.line(Vector2(rx2, 23.5), Vector2(rx2, 33.5), SOUL6[3].lerp(SOUL6[4], pulse - 0.5), 0.8)
			p.line(Vector2(rx2 - 2.5, 27), Vector2(rx2 + 2.5, 30.2), SOUL6[3], 0.8)
			p.glow(rx2, 28.5, 7, Color(0.3, 1.0, 0.45), pulse * 0.6)
		for cx in [7.0, 10.0, 38.0, 41.0]:
			var cxx2: float = cx
			var hgt2 := 5.0 if int(cxx2) % 2 == 0 else 3.5
			flame(p, cxx2, 13.2 - hgt2, 3.6 + ((f + int(cxx2)) % 2) * 0.8, 0.9, f * 2.1 + cxx2)
		p.harden_alpha(0.45)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== pickups

static func gold_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _new(32, 32, 200 + f)
		p.spec = 0.9
		p.shininess = 24.0
		var coins := [Vector2(5, 12.5), Vector2(11, 12.5), Vector2(8, 11), Vector2(6, 9), Vector2(10, 8.5), Vector2(8, 6.5), Vector2(3.5, 13.2), Vector2(12.5, 13.3)]
		for c in coins:
			var cv: Vector2 = c
			p.ball(cv.x, cv.y, 2.9, 1.7, GOLD)
			p.ellipse(cv.x, cv.y - 0.2, 1.6, 0.8, GOLD.darkened(0.25))
		p.spec = 0.0
		p.rim(0.3, 0.0)
		var sp: Vector2 = [Vector2(10, 7.5), Vector2(5, 8.5), Vector2(12, 12), Vector2(7, 11)][f]
		var q := p.tp(sp)
		for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0)]:
			var ov: Vector2i = o
			p.put(int(q.x) + ov.x, int(q.y) + ov.y, Color(1, 0.97, 0.85))
		p.harden_alpha()
		frames.append(p.img)
	return Painter.strip(frames)


static func potion(liquid: Color) -> Image:
	var p := _new(32, 40, 210)
	var glass := Color(0.45, 0.52, 0.55)
	p.ball(8, 13, 6, 6, glass)
	p.spec = 0.4
	p.ball(8, 14, 5.1, 4.6, liquid)
	p.spec = 0.0
	p.ellipse(8, 10.2, 4.4, 0.7, liquid.lightened(0.25))
	p.cyl_poly(PackedVector2Array([Vector2(6.2, 3), Vector2(9.8, 3), Vector2(9.8, 8), Vector2(6.2, 8)]), glass, 8, 2)
	p.cyl_poly(PackedVector2Array([Vector2(6, 0.5), Vector2(10, 0.5), Vector2(9.8, 3.5), Vector2(6.2, 3.5)]), Color(0.42, 0.3, 0.2), 8, 2.2)
	p.capsule(Vector2(5.6, 7), Vector2(10.4, 7), 0.6, 0.6, Color(0.35, 0.26, 0.15))
	p.rim(0.3, 0.0)
	var hl := p.tp(Vector2(5.6, 10.5))
	p.put(int(hl.x), int(hl.y), Color(1, 1, 1))
	p.put(int(hl.x), int(hl.y) + 1, Color(0.9, 0.95, 1.0))
	p.put(int(hl.x) - 1, int(hl.y) + 2, Color(0.8, 0.85, 0.9))
	p.glow(8, 14, 8, liquid, 0.3)
	p.harden_alpha()
	return p.img


# =============================================================================== effects

static func explosion_sheet() -> Image:
	var frames: Array = []
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.06
	n.fractal_octaves = 4
	for f in 6:
		var p := Painter.new(96, 96, 320 + f)
		var t := float(f) / 5.0
		var r := 12.0 + t * 34.0
		var fire_amt := clampf(1.15 - t * 1.25, 0.0, 1.0)
		for y in 96:
			for x in 96:
				var d := Vector2(x + 0.5 - 48, y + 0.5 - 48)
				var nv := n.get_noise_3d(x, y, f * 25.0) * 0.5 + 0.5
				var q := d.length() / (r * (0.7 + nv * 0.55))
				if q > 1.0:
					continue
				if t > 0.4 and nv < 0.3 + t * 0.25 and q > 0.4:
					continue
				var inten := ((1.0 - q) * 1.1 + nv * 0.35) * fire_amt
				var c: Color
				if inten > 0.16:
					c = _pal(FIRE6, clampf(inten, 0.0, 0.999))
				else:
					var sm := 0.17 + nv * 0.12
					c = Color(sm, sm * 0.92, sm * 0.88, clampf(1.0 - t * 0.7, 0.25, 0.95))
				p.put(x, y, c)
		frames.append(p.img)
	return Painter.strip(frames)


static func frost_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(64, 64, 340 + f)
		var t := float(f) / 3.0
		p.glow_px(32, 32, 20 + t * 12, FROST6[2], 0.8 - t * 0.45)
		var rng := RandomNumberGenerator.new()
		rng.seed = 40
		for kk in 14:
			var a := float(kk) / 14.0 * TAU + rng.randf() * 0.3
			var d := Vector2(cos(a), sin(a))
			var r0 := 5.0 + t * 12.0 + rng.randf() * 3.0
			var r1 := r0 + 10.0 - t * 4.0 + rng.randf() * 4.0
			var nn := Vector2(-d.y, d.x)
			var w := 2.4 + rng.randf()
			p.poly(PackedVector2Array([Vector2(32, 32) + d * r0 + nn * w, Vector2(32, 32) + d * r1, Vector2(32, 32) + d * r0 - nn * w]), FROST6[3] if kk % 2 == 0 else FROST6[4])
			p.line(Vector2(32, 32) + d * r0, Vector2(32, 32) + d * (r1 - 1.0), FROST6[5])
		frames.append(p.img)
	return Painter.strip(frames)


static func burst_sheet(size: int, base: Color, seed_value: int, gravity: bool) -> Image:
	var frames: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var parts: Array = []
	for i in 30:
		var a := rng.randf() * TAU
		parts.append([Vector2(cos(a), sin(a) - 0.45) * rng.randf_range(3.0, 9.0), rng.randf_range(0.8, 2.6), rng.randf_range(0.7, 1.15)])
	for f in 4:
		var p := Painter.new(size, size, seed_value + f)
		var t := float(f + 1)
		for pr in parts:
			var v: Vector2 = pr[0]
			var pos := Vector2(size * 0.5, size * 0.5) + v * t * 0.9
			if gravity:
				pos.y += t * t * 0.9
			var r: float = pr[1] * (1.2 - f * 0.2)
			if r <= 0.3:
				continue
			var c := base * float(pr[2])
			c.a = 1.0 if gravity else clampf(0.95 - f * 0.22, 0.2, 1.0)
			p.ellipse(pos.x, pos.y, r, r * (1.3 if gravity else 1.0), c)
			if gravity and f < 2:
				p.line(pos, pos - v * 0.8, Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, 1.0))
		frames.append(p.img)
	return Painter.strip(frames)


static func portal_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(96, 96, 360 + f)
		p.glow_px(48, 48, 44, SOUL6[2], 0.55)
		for arm in 5:
			for kk in 60:
				var t := float(kk) / 59.0
				var a := float(arm) / 5.0 * TAU + t * 3.4 + f * 0.42
				var r := 6.0 + t * 36.0
				var pos := Vector2(48 + cos(a) * r, 48 + sin(a) * r * 0.85)
				var col: Color = SOUL6[5] if t < 0.2 else (SOUL6[4] if t < 0.45 else (SOUL6[3] if t < 0.75 else SOUL6[2]))
				var rad := 2.6 - t * 1.7
				p.ellipse(pos.x, pos.y, rad, rad, col)
		p.glow_px(48, 48, 13, SOUL6[5], 0.9)
		frames.append(p.img)
	return Painter.strip(frames)


static func ring_decal() -> Image:
	var p := Painter.new(128, 128, 370)
	var n := FastNoiseLite.new()
	n.seed = 3
	n.frequency = 0.08
	for y in 128:
		for x in 128:
			var d := Vector2(x + 0.5 - 64, y + 0.5 - 64).length() / 62.0
			if d > 1.0:
				continue
			var a := pow(smoothstep(0.55, 0.95, d), 2.0) * (1.0 - smoothstep(0.95, 1.0, d))
			a *= 0.75 + n.get_noise_2d(x, y) * 0.35
			if a > 0.02:
				p.put(x, y, Color(0.75, 0.93, 1.0, clampf(a, 0.0, 1.0)))
	return p.img


# =============================================================================== class portraits (48x48, 8 frames)
## 0 idle, 1 blink, 2 glance left, 3 glance right, 4 hurt flinch, 5 critical, 6 battle cry, 7 dead.
## Fully opaque frames (painted background), head + shoulders, light from the upper left.

const PORTRAIT_POSES := [
	{},
	{"eyes": "closed"},
	{"gaze": -1.0, "dx": -0.6},
	{"gaze": 1.0, "dx": 0.6},
	{"dx": 2.0, "dy": 1.0, "eyes": "squint", "mouth": "grimace", "blood": 1, "brow": 1.4, "tilt": 0.06},
	{"eyes": "half", "mouth": "pain", "blood": 2, "pale": 0.3, "dy": 0.6},
	{"mouth": "roar", "glow": true, "brow": 1.3},
	{"dead": true, "eyes": "closed", "mouth": "slack", "blood": 2, "dy": 3.0, "dx": -1.0, "tilt": 0.16},
]

const CLASS_GLOW := {"warrior": Color(1.0, 0.55, 0.15), "mage": Color(0.45, 0.9, 1.0), "hunter": Color(0.6, 1.0, 0.3)}


## Head framing: design units are scaled so the head fills ~78% of the 48px frame.
const PORTRAIT_SCALE := 1.36
const PORTRAIT_EYE := Vector2(24, 21)


static func _bg_flat(p: Painter, col: Color) -> void:
	## Uniform dark backdrop (borders stay flat) with a soft light only behind the head.
	var head := Vector2(24, 15)
	for y in p.h:
		for x in p.w:
			var d := Vector2(x, y).distance_to(head) / 19.0
			var g := clampf(1.0 - d, 0.0, 1.0)
			var c := col.lerp(col.lightened(0.35), g * g)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))


static func _bg(p: Painter, col: Color, cx: float, cy: float) -> void:
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.09
	for y in p.h:
		for x in p.w:
			var d := Vector2(x - cx, y - cy).length() / (p.w * 0.75)
			var c := col.darkened(clampf(d, 0.0, 1.0) * 0.85)
			c = c.darkened(0.1 + n.get_noise_2d(x, y) * 0.1)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))


static func _eyes(p: Painter, cx: float, cy: float, pose: Dictionary, skin: Color, iris_col: Color, glow_col: Color, narrow: float) -> void:
	var state: String = pose.get("eyes", "open")
	var gaze: float = pose.get("gaze", 0.0)
	var glow: bool = pose.get("glow", false)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var ex := cx + s * 3.7
		var ey := cy + 0.4
		# socket shading
		p.ball(ex, ey - 0.2, 2.9, 1.9, skin.darkened(0.3))
		if state == "closed":
			p.line(Vector2(ex - 2.0, ey), Vector2(ex + 2.0, ey + 0.3), skin.darkened(0.6))
			p.line(Vector2(ex - 1.6, ey + 0.9), Vector2(ex + 1.6, ey + 1.0), skin.darkened(0.15))
			continue
		var ry := 0.95 * narrow
		var oy := 0.0
		if state == "half":
			ry = 0.5
			oy = 0.4
		elif state == "squint":
			ry = 0.42
			oy = 0.2
		p.ellipse(ex, ey + oy, 1.95, ry, Color(0.74, 0.7, 0.64))
		var ic := glow_col if glow else iris_col
		p.ellipse(ex + gaze * 0.9, ey + oy, 0.95, minf(0.95, ry + 0.05), ic)
		if not glow:
			p.tput(ex + gaze * 0.9, ey + oy - 0.4, Color(0.05, 0.04, 0.04))
		# upper lid
		p.line(Vector2(ex - 2.1, ey + oy - ry - 0.2), Vector2(ex + 2.0, ey + oy - ry - 0.3), skin.darkened(0.55))
		if glow:
			var e := p.tp(Vector2(ex, ey))
			p.glow_px(e.x, e.y, 4.5 * p.k, glow_col, 1.0)


static func _mouth(p: Painter, mx: float, my: float, pose: Dictionary, skin: Color) -> void:
	var lip := skin.darkened(0.25).lerp(Color(0.45, 0.2, 0.18), 0.4)
	var dark := Color(0.12, 0.04, 0.04)
	var teeth := Color(0.72, 0.68, 0.58)
	match String(pose.get("mouth", "closed")):
		"closed":
			p.line(Vector2(mx - 2.6, my), Vector2(mx + 2.6, my + 0.2), dark)
			p.line(Vector2(mx - 1.8, my + 1.0), Vector2(mx + 1.8, my + 1.0), lip)
		"grimace":
			p.ellipse(mx, my + 0.2, 3.0, 1.2, dark)
			p.rect(mx - 2.6, my - 0.5, 5.2, 1.3, teeth)
			p.line(Vector2(mx - 2.6, my + 0.2), Vector2(mx + 2.6, my + 0.2), dark)
		"pain":
			p.ellipse(mx, my + 0.4, 2.2, 1.1, dark)
			p.rect(mx - 1.6, my - 0.4, 3.2, 0.6, teeth)
		"roar":
			p.ellipse(mx, my + 1.4, 3.1, 2.8, dark)
			p.rect(mx - 2.4, my - 1.0, 4.8, 0.8, teeth)
			p.rect(mx - 2.0, my + 3.2, 4.0, 0.7, teeth.darkened(0.15))
			p.ellipse(mx, my + 2.4, 1.6, 0.8, Color(0.4, 0.1, 0.12))
		"slack":
			p.ellipse(mx, my + 0.5, 1.6, 0.8, dark)


static func _blood(p: Painter, cx: float, cy: float, level: int) -> void:
	var b := Color(0.42, 0.03, 0.04)
	if level >= 1:
		p.line(Vector2(cx + 3.0, cy - 6.0), Vector2(cx + 4.2, cy + 3.5), b, 1.0)
		p.ball(cx + 4.3, cy + 3.8, 0.6, 0.9, b.darkened(0.2))
		p.line(Vector2(cx + 1.8, cy - 6.5), Vector2(cx + 4.6, cy - 5.6), b.lightened(0.1), 1.0)
	if level >= 2:
		p.line(Vector2(cx - 5.5, cy - 7.0), Vector2(cx - 6.5, cy + 6.0), b, 1.4)
		p.line(Vector2(cx + 0.4, cy + 6.6), Vector2(cx + 0.8, cy + 10.5), b, 0.9)
		p.ball(cx - 4.0, cy + 4.5, 1.6, 1.0, Color(0.32, 0.14, 0.22))
		for i in 5:
			p.tput(cx - 8 + i * 3.7, cy + 12 + (i % 2) * 2, b)


static func portrait_sheet(kind: String) -> Image:
	var frames: Array = []
	for f in PORTRAIT_POSES.size():
		var pose: Dictionary = PORTRAIT_POSES[f]
		var p := Painter.new(48, 48, 500 + f + kind.length() * 7)
		p.set_real(PORTRAIT_SCALE)
		var base_xf := Transform2D(0.0, Vector2(PORTRAIT_SCALE, PORTRAIT_SCALE), 0.0, PORTRAIT_EYE - Vector2(24, 22) * PORTRAIT_SCALE)
		p.xf = base_xf
		p.grain = 0.08
		p.dither = 0.15
		var dx: float = pose.get("dx", 0.0)
		var dy: float = pose.get("dy", 0.0)
		var cx := 24.0 + dx
		var cy := 22.0 + dy
		var bgc: Color = {"warrior": Color(0.13, 0.05, 0.035), "mage": Color(0.04, 0.05, 0.13), "hunter": Color(0.045, 0.08, 0.04)}[kind]
		_bg_flat(p, bgc)
		var tilt: float = pose.get("tilt", 0.0)
		if tilt != 0.0:
			var piv := Vector2(24, 47)
			p.xf = base_xf * Transform2D(0.0, piv) * Transform2D(tilt, Vector2.ZERO) * Transform2D(0.0, -piv)
		var skin: Color = {"warrior": Color(0.6, 0.43, 0.33), "mage": Color(0.58, 0.46, 0.4), "hunter": Color(0.58, 0.42, 0.31)}[kind]
		var pale: float = pose.get("pale", 0.0)
		if pose.get("dead", false):
			pale = 0.5
		skin = skin.lerp(Color(0.55, 0.55, 0.53), pale)
		var brow_down: float = pose.get("brow", 0.0)
		var glow_col: Color = CLASS_GLOW[kind]
		# ---- shoulders & clothing
		match kind:
			"warrior":
				p.ball(24, 50, 26, 12, Color(0.3, 0.3, 0.32), 0.25)
				for i in 30:
					p.tput(2 + (i * 7) % 44, 41 + (i * 5) % 7, Color(0.2, 0.2, 0.22))
				p.ball(24, 41, 15, 4.5, Color(0.3, 0.24, 0.18), 0.4)
				p.spec = 0.8
				p.ball(4, 46, 9, 7, Color(0.44, 0.45, 0.48))
				p.ball(44, 46, 9, 7, Color(0.42, 0.43, 0.46))
				p.capsule(Vector2(-3, 41), Vector2(10, 41.5), 0.8, 0.8, GOLD)
				p.capsule(Vector2(38, 41.5), Vector2(51, 41), 0.8, 0.8, GOLD)
				p.spec = 0.0
			"mage":
				p.cloth(PackedVector2Array([Vector2(-2, 48), Vector2(4, 38), Vector2(14, 34), Vector2(34, 34), Vector2(44, 38), Vector2(50, 48)]), Color(0.14, 0.15, 0.32), 24, 24, 0.6, 0.35)
				p.strand(PackedVector2Array([Vector2(13, 35), Vector2(20, 48)]), 0.9, 0.9, GOLD)
				p.strand(PackedVector2Array([Vector2(35, 35), Vector2(28, 48)]), 0.9, 0.9, GOLD.darkened(0.2))
			"hunter":
				p.cloth(PackedVector2Array([Vector2(-2, 48), Vector2(3, 38), Vector2(13, 34), Vector2(35, 34), Vector2(45, 38), Vector2(50, 48)]), Color(0.27, 0.2, 0.13), 24, 24, 0.7, 0.3)
				p.capsule(Vector2(8, 36), Vector2(38, 48), 1.6, 1.6, Color(0.18, 0.12, 0.08))
				p.spec = 0.7
				p.rect(20, 40, 3, 3, Color(0.5, 0.45, 0.35))
				p.spec = 0.0
		# ---- hood back
		if kind == "mage":
			p.ball(cx, cy - 0.5, 14.5, 17.5, Color(0.13, 0.14, 0.33))
			p.ellipse(cx, cy + 1.5, 10.2, 12.6, Color(0.03, 0.03, 0.06))
		elif kind == "hunter":
			p.ball(cx, cy - 1.0, 13.5, 16.0, Color(0.23, 0.25, 0.14))
			p.ellipse(cx, cy + 1.0, 10.0, 12.0, Color(0.04, 0.04, 0.03))
		# ---- neck + head
		p.capsule(Vector2(cx, cy + 10), Vector2(cx, cy + 16), 4.8, 5.2, skin.darkened(0.15))
		p.ball(cx, cy + 1.5, 8.6, 11.0, skin)
		p.ball(cx, cy + 8.6, 6.4, 4.2, skin.darkened(0.04))
		p.ball(cx - 4.6, cy + 3.2, 3.0, 2.2, skin)
		p.ball(cx + 4.6, cy + 3.2, 3.0, 2.2, skin.darkened(0.06))
		p.ball(cx - 8.4, cy + 1.6, 1.4, 2.4, skin.darkened(0.1))
		p.ball(cx + 8.4, cy + 1.6, 1.4, 2.4, skin.darkened(0.2))
		# nose
		p.capsule(Vector2(cx + 0.3, cy - 0.5), Vector2(cx + 0.7, cy + 5.4), 1.0, 1.6, skin.lightened(0.04))
		p.tput(cx - 0.9, cy + 6.0, skin.darkened(0.6))
		p.tput(cx + 1.8, cy + 6.0, skin.darkened(0.6))
		p.line(Vector2(cx + 1.9, cy + 0.5), Vector2(cx + 2.2, cy + 5.0), skin.darkened(0.25))
		# eyes + brows
		var iris: Color = {"warrior": Color(0.3, 0.35, 0.42), "mage": Color(0.35, 0.42, 0.5), "hunter": Color(0.32, 0.3, 0.15)}[kind]
		_eyes(p, cx, cy, pose, skin, iris, glow_col, 0.8 if kind == "hunter" else 1.0)
		var brow_c: Color = {"warrior": Color(0.25, 0.13, 0.06), "mage": Color(0.82, 0.82, 0.8), "hunter": Color(0.18, 0.11, 0.06)}[kind]
		var bw := 1.1 if kind == "mage" else 0.8
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var inner_y := cy - 2.2 + brow_down * 0.9
			p.strand(PackedVector2Array([Vector2(cx + s * 6.3, cy - 2.3), Vector2(cx + s * 3.8, cy - 3.0 + brow_down * 0.4), Vector2(cx + s * 1.3, inner_y)]), bw, bw * 0.8, brow_c)
		var mx := cx + 0.3
		var my := cy + 9.4
		# ---- identity details
		match kind:
			"warrior":
				var beard := Color(0.38, 0.2, 0.09).lerp(Color(0.4, 0.38, 0.36), pale)
				p.cloth(PackedVector2Array([Vector2(cx - 8.8, cy + 3.5), Vector2(cx - 6.5, cy + 7.5), Vector2(cx - 3, cy + 7.4), Vector2(cx + 3, cy + 7.4), Vector2(cx + 6.5, cy + 7.5), Vector2(cx + 8.8, cy + 3.5), Vector2(cx + 8.2, cy + 13), Vector2(cx + 4, cy + 19), Vector2(cx, cy + 21), Vector2(cx - 4, cy + 19), Vector2(cx - 8.2, cy + 13)]), beard, cx, 9.0, 1.7, 0.45)
				for i in 7:
					var bx := cx - 6 + i * 2.0
					p.line(Vector2(bx, cy + 11), Vector2(bx + (i - 3) * 0.3, cy + 17 - absf(i - 3.0)), beard.darkened(0.4))
				p.strand(PackedVector2Array([Vector2(cx - 5.2, cy + 8.8), Vector2(cx, cy + 7.4), Vector2(cx + 5.2, cy + 8.8)]), 1.1, 1.1, beard.lightened(0.06))
				_mouth(p, mx, my, pose, skin)
				# old scar over the left eye
				p.line(Vector2(cx - 6.0, cy - 5.0), Vector2(cx - 2.6, cy + 5.4), skin.lightened(0.12))
				p.line(Vector2(cx - 5.4, cy - 5.0), Vector2(cx - 2.0, cy + 5.4), skin.darkened(0.25))
				# horned steel helm
				p.spec = 0.8
				p.shininess = 22.0
				p.cyl_poly(PackedVector2Array([Vector2(cx - 10.2, cy - 2.2), Vector2(cx - 10, cy - 8), Vector2(cx - 6.8, cy - 12.8), Vector2(cx, cy - 14.8), Vector2(cx + 6.8, cy - 12.8), Vector2(cx + 10, cy - 8), Vector2(cx + 10.2, cy - 2.2), Vector2(cx + 5, cy - 3.6), Vector2(cx - 5, cy - 3.6)]), Color(0.46, 0.47, 0.5), cx, 10.0, -0.45)
				p.line(Vector2(cx, cy - 14.5), Vector2(cx, cy - 4.0), Color(0.3, 0.3, 0.33))
				p.capsule(Vector2(cx - 10.4, cy - 2.8), Vector2(cx + 10.4, cy - 2.8), 1.1, 1.1, Color(0.38, 0.38, 0.41))
				for i in 5:
					p.ball(cx - 8 + i * 4, cy - 2.8, 0.55, 0.55, GOLD.lightened(0.2))
				p.capsule(Vector2(cx, cy - 3.6), Vector2(cx, cy + 3.8), 1.0, 0.8, Color(0.44, 0.45, 0.48))
				p.spec = 0.0
				p.shininess = 18.0
				for sv in [-1.0, 1.0]:
					var s: float = sv
					var h0 := Vector2(cx + s * 9.2, cy - 7.5)
					var pts := PackedVector2Array([h0, h0 + Vector2(s * 5.5, -2.5), h0 + Vector2(s * 9.5, -8.0), h0 + Vector2(s * 10.0, -15.0)])
					p.strand(pts, 2.6, 0.5, Color(0.62, 0.57, 0.46))
					for r in 4:
						var t := 0.15 + r * 0.18
						var q := pts[0].lerp(pts[1], minf(t * 2.0, 1.0)) if t < 0.5 else pts[1].lerp(pts[2], (t - 0.5) * 2.0)
						p.line(q + Vector2(-1.2, 0.6), q + Vector2(1.2, -0.6), Color(0.38, 0.33, 0.25))
			"mage":
				# wrinkles
				p.line(Vector2(cx - 4.5, cy - 4.6), Vector2(cx + 4.5, cy - 4.8), skin.darkened(0.3))
				p.line(Vector2(cx - 3.5, cy - 6.0), Vector2(cx + 3.5, cy - 6.1), skin.darkened(0.25))
				p.line(Vector2(cx - 6.6, cy + 0.6), Vector2(cx - 7.6, cy + 2.0), skin.darkened(0.35))
				p.line(Vector2(cx + 6.6, cy + 0.6), Vector2(cx + 7.6, cy + 2.0), skin.darkened(0.35))
				p.line(Vector2(cx - 2.2, cy + 5.5), Vector2(cx - 3.6, cy + 8.5), skin.darkened(0.3))
				var beard2 := Color(0.78, 0.78, 0.76)
				p.cloth(PackedVector2Array([Vector2(cx - 8.4, cy + 4), Vector2(cx - 6, cy + 7.6), Vector2(cx + 6, cy + 7.6), Vector2(cx + 8.4, cy + 4), Vector2(cx + 8, cy + 15), Vector2(cx + 5, cy + 26), Vector2(cx, cy + 28), Vector2(cx - 5, cy + 26), Vector2(cx - 8, cy + 15)]), beard2, cx, 8.5, 1.8, 0.45)
				for i in 6:
					var bx2 := cx - 5 + i * 2.0
					p.line(Vector2(bx2, cy + 12), Vector2(bx2 + (i - 2.5) * 0.4, cy + 24 - absf(i - 2.5)), beard2.darkened(0.3))
				p.strand(PackedVector2Array([Vector2(cx - 5.6, cy + 9.4), Vector2(cx - 2.0, cy + 7.6), Vector2(cx, cy + 8.0), Vector2(cx + 2.0, cy + 7.6), Vector2(cx + 5.6, cy + 9.4)]), 1.1, 1.0, beard2.lightened(0.05))
				_mouth(p, mx, my + 0.4, pose, skin)
				# hood rim with gold trim, shadow on the brow
				var rim_pts := PackedVector2Array([Vector2(cx - 9.8, cy + 11), Vector2(cx - 10.4, cy + 1), Vector2(cx - 7.5, cy - 8.5), Vector2(cx, cy - 11.8), Vector2(cx + 7.5, cy - 8.5), Vector2(cx + 10.4, cy + 1), Vector2(cx + 9.8, cy + 11)])
				p.poly(PackedVector2Array([Vector2(cx - 9, cy - 6), Vector2(cx, cy - 10.5), Vector2(cx + 9, cy - 6), Vector2(cx + 8, cy - 3.2), Vector2(cx - 8, cy - 3.2)]), Color(0.02, 0.02, 0.05, 0.55))
				p.strand(rim_pts, 1.8, 1.8, Color(0.17, 0.18, 0.4))
				var trim := PackedVector2Array()
				for v in rim_pts:
					trim.append(Vector2(cx, cy) + (v - Vector2(cx, cy)) * 1.13)
				p.strand(trim, 0.7, 0.7, GOLD)
			"hunter":
				# scar across the cheekbone
				p.line(Vector2(cx + 2.5, cy + 1.5), Vector2(cx + 7.5, cy - 1.5), skin.lightened(0.12))
				# scarf mask over the lower face
				var scarf := Color(0.32, 0.23, 0.15).lerp(Color(0.35, 0.33, 0.31), pale)
				var mouth_state: String = pose.get("mouth", "closed")
				var sag := 1.2 if mouth_state == "roar" else 0.0
				p.cloth(PackedVector2Array([Vector2(cx - 9.8, cy + 4.6), Vector2(cx - 3, cy + 4.0), Vector2(cx + 3, cy + 4.0), Vector2(cx + 9.8, cy + 4.6), Vector2(cx + 9.4, cy + 15), Vector2(cx, cy + 17.5 + sag), Vector2(cx - 9.4, cy + 15)]), scarf, cx, 10.0, 1.5, 0.4)
				p.line(Vector2(cx - 9.5, cy + 7.5), Vector2(cx + 9.5, cy + 7.6), scarf.darkened(0.45))
				p.line(Vector2(cx - 8.5, cy + 11.5), Vector2(cx + 8.5, cy + 11.4), scarf.darkened(0.35))
				if mouth_state == "roar" or mouth_state == "grimace":
					p.ellipse(mx, my + 0.5, 2.6, 1.0, scarf.darkened(0.4))
				# leather hood rim with stitching
				var rim2 := PackedVector2Array([Vector2(cx - 9.6, cy + 10), Vector2(cx - 10.2, cy), Vector2(cx - 7.2, cy - 9), Vector2(cx, cy - 12.0), Vector2(cx + 7.2, cy - 9), Vector2(cx + 10.2, cy), Vector2(cx + 9.6, cy + 10)])
				p.poly(PackedVector2Array([Vector2(cx - 9, cy - 6), Vector2(cx, cy - 10.5), Vector2(cx + 9, cy - 6), Vector2(cx + 8, cy - 3.0), Vector2(cx - 8, cy - 3.0)]), Color(0.02, 0.03, 0.02, 0.5))
				p.strand(rim2, 1.7, 1.7, Color(0.27, 0.29, 0.17))
				for i in 9:
					var q2 := rim2[i % rim2.size()]
					p.tput(q2.x, q2.y, Color(0.45, 0.42, 0.3))
		_blood(p, cx, cy, int(pose.get("blood", 0)))
		p.xf = Transform2D.IDENTITY
		if pose.get("dead", false):
			for y in 48:
				for x in 48:
					var c := p.img.get_pixel(x, y)
					var l := c.get_luminance()
					var g := l * 0.62
					p.img.set_pixel(x, y, Color(lerpf(c.r, g, 0.8), lerpf(c.g, g, 0.8), lerpf(c.b, g, 0.8), 1.0))
		elif pale > 0.0:
			p.tint(Color(0.45, 0.02, 0.02), 0.13)
		p.harden_alpha(0.0)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== boss portrait (64x64, 3 frames)

static func boss_portrait() -> Image:
	var soul := Color(0.45, 1.0, 0.55)
	var frames: Array = []
	for f in 3:
		var p := Painter.new(64, 64, 800 + f)
		p.set_real(1.0)
		p.grain = 0.09
		# dark background with a soul-fire glow behind the skull
		var n := FastNoiseLite.new()
		n.seed = 9
		n.frequency = 0.07
		for y in 64:
			for x in 64:
				var d := Vector2(x - 32, y - 26).length() / 40.0
				var g := clampf(1.0 - d, 0.0, 1.0)
				var mist := n.get_noise_2d(x, y + f * 9.0) * 0.5 + 0.5
				var c := Color(0.015, 0.025, 0.02).lerp(Color(0.05, 0.22, 0.1), g * g * (0.55 + mist * 0.5) * (1.3 if f == 2 else 1.0))
				p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		var glows: Array = []
		var hx := 32.0
		var hy := 28.0
		if f == 1:
			hx += 2.0
			hy -= 1.5
			var piv := Vector2(32, 60)
			p.xf = Transform2D(0.0, piv) * Transform2D(-0.09, Vector2.ZERO) * Transform2D(0.0, -piv)
		# iron gorget + fur collar
		var steel := Color(0.2, 0.2, 0.24)
		p.spec = 0.7
		p.cyl_poly(PackedVector2Array([Vector2(-4, 64), Vector2(4, 50), Vector2(20, 45), Vector2(44, 45), Vector2(60, 50), Vector2(68, 64)]), steel, 32, 32, -0.3)
		for i in 3:
			p.line(Vector2(6 + i * 2, 52 + i * 4), Vector2(58 - i * 2, 52 + i * 4), steel.darkened(0.6))
			p.line(Vector2(6 + i * 2, 53 + i * 4), Vector2(58 - i * 2, 53 + i * 4), steel.lightened(0.25))
		p.strand(PackedVector2Array([Vector2(4, 50), Vector2(20, 45.5), Vector2(44, 45.5), Vector2(60, 50)]), 0.8, 0.8, GOLD)
		for sx in [8.0, 56.0]:
			var sxx: float = sx
			p.poly(PackedVector2Array([Vector2(sxx - 3, 51), Vector2(sxx + 3, 51), Vector2(sxx + (sxx - 32) * 0.08, 40)]), BONE)
		p.spec = 0.0
		p.ball(32, 46, 16, 4.5, Color(0.3, 0.28, 0.26), 0.35)
		# skull (cracks / split depending on the frame)
		var jaw: float = [0.6, 1.4, 2.8][f]
		p.capsule(Vector2(hx, hy + 12), Vector2(hx, hy + 18), 3.0, 3.0, BONE.darkened(0.15))
		Creatures._skull(p, hx, hy, 2.15, jaw, soul, glows)
		glows.clear()
		# crown + antlers
		p.spec = 0.8
		p.capsule(Vector2(hx - 11.5, hy - 11), Vector2(hx + 11.5, hy - 11), 1.6, 1.6, GOLD.darkened(0.1))
		p.spec = 0.0
		for i in 3:
			p.ball(hx - 7 + i * 7, hy - 11.3, 1.3, 1.3, soul)
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var a0 := Vector2(hx + s * 10.0, hy - 12.0)
			var a1 := a0 + Vector2(s * 6.0, -7.0)
			var a2 := a1 + Vector2(s * 5.0, -7.0)
			p.strand(PackedVector2Array([a0, a1, a2, a2 + Vector2(s * 1.0, -6.0)]), 2.2, 0.6, BONE.darkened(0.05))
			p.strand(PackedVector2Array([a1, a1 + Vector2(-s * 1.5, -5.5), a1 + Vector2(-s * 0.5, -9.0)]), 1.3, 0.5, BONE.darkened(0.05))
			p.strand(PackedVector2Array([a0.lerp(a1, 0.5), a0.lerp(a1, 0.5) + Vector2(s * 6.0, -1.0), a0.lerp(a1, 0.5) + Vector2(s * 8.5, -4.0)]), 1.2, 0.45, BONE.darkened(0.05))
		if f == 1:
			for crack in [[Vector2(hx - 2, hy - 13), Vector2(hx - 4, hy - 8), Vector2(hx - 2.5, hy - 4)], [Vector2(hx + 6, hy - 10), Vector2(hx + 8, hy - 5), Vector2(hx + 7, hy - 2)]]:
				var cp: Array = crack
				p.line(cp[0], cp[1], Color(0.12, 0.1, 0.08))
				p.line(cp[1], cp[2], Color(0.12, 0.1, 0.08))
		# eye fire
		var eye_r: float = [3.0, 2.2, 4.5][f]
		var eye_s: float = [1.0, 0.7, 1.4][f]
		for ex in [-2.3, 2.3]:
			var e := p.tp(Vector2(hx + float(ex) * 2.15, hy + 0.8 * 2.15))
			p.ellipse(hx + float(ex) * 2.15, hy + 0.8 * 2.15, 1.6, 1.4, soul.lightened(0.5) if f == 2 else soul)
			glows.append([e, eye_r * 2.0, soul, eye_s])
			if f == 2:
				glows.append([e, 2.0, Color(0.95, 1, 0.95), 1.0])
		# enraged: glowing crack splitting the skull
		if f == 2:
			var zig := PackedVector2Array([Vector2(hx + 0.5, hy - 14), Vector2(hx - 1.5, hy - 9), Vector2(hx + 1.2, hy - 5), Vector2(hx - 0.6, hy - 1), Vector2(hx + 0.4, hy + 2)])
			for i in zig.size() - 1:
				p.line(zig[i], zig[i + 1], Color(0.05, 0.15, 0.07), 2.2)
			for i in zig.size() - 1:
				p.line(zig[i], zig[i + 1], soul.lightened(0.3), 1.0)
				var m := p.tp(zig[i].lerp(zig[i + 1], 0.5))
				glows.append([m, 4.0, soul, 0.8])
		p.xf = Transform2D.IDENTITY
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1], g[2], g[3])
		p.harden_alpha(0.0)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== relic pedestal (64x64)

static func pedestal() -> Image:
	var p := Painter.new(64, 64, 880)
	p.set_real(1.0)
	p.grain = 0.14
	var stone := Color(0.36, 0.36, 0.39)
	# base slab (feet on the bottom row)
	p.flat_poly(PackedVector2Array([Vector2(10, 57), Vector2(54, 57), Vector2(55, 64), Vector2(9, 64)]), stone.darkened(0.1), Vector3(0, 0.1, 1))
	p.flat_poly(PackedVector2Array([Vector2(11, 54.5), Vector2(53, 54.5), Vector2(54, 57.5), Vector2(10, 57.5)]), stone.lightened(0.08), Vector3(0, -1, 0.5))
	# plinth step
	p.flat_poly(PackedVector2Array([Vector2(15, 49), Vector2(49, 49), Vector2(49, 55), Vector2(15, 55)]), stone, Vector3(0, 0, 1))
	p.flat_poly(PackedVector2Array([Vector2(16, 47.5), Vector2(48, 47.5), Vector2(49, 49.5), Vector2(15, 49.5)]), stone.lightened(0.1), Vector3(0, -1, 0.5))
	# carved shaft
	p.cyl_poly(PackedVector2Array([Vector2(21, 22), Vector2(43, 22), Vector2(41.5, 48), Vector2(22.5, 48)]), stone, 32, 11, -0.1)
	for gx in [26.5, 37.5]:
		var gxx: float = gx
		p.line(Vector2(gxx, 25), Vector2(gxx, 45), stone.darkened(0.45))
		p.line(Vector2(gxx + 1, 25), Vector2(gxx + 1, 45), stone.lightened(0.12))
	# rune carvings (grooves with a faint soul glow)
	var rune_dark := Color(0.06, 0.1, 0.07)
	var strokes := [[Vector2(32, 26), Vector2(32, 43)], [Vector2(32, 29), Vector2(29, 33)], [Vector2(32, 29), Vector2(35, 33)], [Vector2(29, 33), Vector2(32, 36.5)], [Vector2(35, 33), Vector2(32, 36.5)], [Vector2(32, 39.5), Vector2(29.5, 43)], [Vector2(32, 39.5), Vector2(34.5, 43)]]
	for s in strokes:
		p.line(s[0], s[1], rune_dark, 1.4)
	for s in strokes:
		p.line(s[0], s[1], Color(0.3, 0.75, 0.38), 0.6)
	# capital with mouldings
	p.flat_poly(PackedVector2Array([Vector2(17, 17.5), Vector2(47, 17.5), Vector2(44, 22.5), Vector2(20, 22.5)]), stone.lightened(0.04), Vector3(0, 0.2, 1))
	p.line(Vector2(18, 19.5), Vector2(46, 19.5), stone.darkened(0.4))
	# shallow bowl on top
	p.cyl_poly(PackedVector2Array([Vector2(16, 13), Vector2(48, 13), Vector2(44, 17.8), Vector2(20, 17.8)]), Color(0.3, 0.28, 0.26), 32, 16, -0.3)
	p.ellipse(32, 13, 16.5, 2.6, Color(0.42, 0.4, 0.38))
	p.ellipse(32, 13.4, 14.2, 1.7, Color(0.1, 0.09, 0.09))
	p.spec = 0.7
	p.capsule(Vector2(16, 13), Vector2(48, 13), 0.6, 0.6, GOLD.darkened(0.2))
	p.spec = 0.0
	p.grime(MOSS, 0.5, 0.1, 0.2, 0.6)
	p.grime(Color(0.05, 0.05, 0.05), 0.45, 0.07, 0.12, 0.85)
	p.rim(0.35, 0.1)
	for s in strokes:
		var m := p.tp((s[0] as Vector2).lerp(s[1], 0.5))
		p.glow_px(m.x, m.y, 3.0, Color(0.3, 1.0, 0.45), 0.35)
	p.harden_alpha()
	return p.img
