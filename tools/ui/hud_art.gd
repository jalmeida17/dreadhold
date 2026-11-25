extends RefCounted
## "Reliquary" UI art: gothic ironwork HUD, vials, rune stones, tapestries, stone tablets,
## tombstone, parchment, vignettes, class crosshairs and the chiselled title font.

const Painter := preload("res://tools/art/painter.gd")
const FontData := preload("res://tools/art/font_data.gd")

const IRON := Color(0.34, 0.34, 0.38)
const DARK_IRON := Color(0.19, 0.19, 0.22)
const GOLD := Color(0.78, 0.6, 0.26)
const BONE := Color(0.8, 0.76, 0.62)
const STONE := Color(0.46, 0.45, 0.47)
const LEATHER := Color(0.27, 0.17, 0.11)
const PARCHMENT := Color(0.76, 0.66, 0.48)


static func _p(w: int, h: int, seed_value: int, real: bool = true) -> Painter:
	var p := Painter.new(w, h, seed_value)
	if real:
		p.set_real(1.0)
		p.spec = 0.35
	return p


static func _rivet(p: Painter, x: float, y: float, r: float = 1.6, c: Color = GOLD) -> void:
	p.ball(x, y, r, r, c)


static func _thorn(p: Painter, base: Vector2, dir: Vector2, length: float, width: float, c: Color = IRON) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	p.flat_poly(PackedVector2Array([base + n * width, base + d * length, base - n * width]), c, Vector3(n.x * 0.5, -0.6, 0.8))


static func _curl(p: Painter, center: Vector2, r: float, a0: float, sweep: float, thick: float, c: Color = IRON) -> void:
	## Wrought-iron scroll: a spiral drawn with capsule segments.
	var prev := center + Vector2(cos(a0), sin(a0)) * r
	var steps := 14
	for i in steps:
		var t := float(i + 1) / float(steps)
		var a := a0 + sweep * t
		var rr := r * (1.0 - t * 0.55)
		var pt := center + Vector2(cos(a), sin(a)) * rr
		p.capsule(prev, pt, thick * (1.0 - t * 0.4), thick * (1.0 - t * 0.45), c)
		prev = pt
	p.ball(prev.x, prev.y, thick * 0.9, thick * 0.9, c)


static func _skull(p: Painter, cx: float, cy: float, s: float) -> void:
	p.ball(cx, cy, 5.0 * s, 5.2 * s, BONE)
	p.ball(cx, cy + 4.2 * s, 3.2 * s, 2.0 * s, BONE)
	p.ball(cx - 2.0 * s, cy + 0.4 * s, 1.4 * s, 1.6 * s, Color(0.06, 0.04, 0.05))
	p.ball(cx + 2.0 * s, cy + 0.4 * s, 1.4 * s, 1.6 * s, Color(0.06, 0.04, 0.05))
	p.rect(cx - 0.5, cy + 2.2 * s, 1, 1, Color(0.1, 0.06, 0.06))


static func _cloth(p: Painter, x0: int, y0: int, x1: int, y1: int, base: Color, seed_value: int, tatter: float = 8.0) -> void:
	## Hanging cloth with vertical folds, weave grain and a tattered bottom edge.
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.07
	var weave := FastNoiseLite.new()
	weave.seed = seed_value + 1
	weave.frequency = 0.8
	for x in range(x0, x1):
		var bottom := y1 - int(absf(n.get_noise_1d(x * 3.0)) * tatter * 2.0) - (int(tatter) if (x * 7 + seed_value) % 11 == 0 else 0)
		for y in range(y0, bottom):
			var u := float(x - x0) / float(x1 - x0)
			var fold := sin(u * TAU * 3.0 + n.get_noise_2d(x, y) * 1.5) * 0.16 + sin(u * TAU * 7.3) * 0.05
			var s := 0.92 + fold - float(y - y0) / float(y1 - y0) * 0.18 + weave.get_noise_2d(x, y) * 0.06
			if (x + y) % 2 == 0:
				s -= 0.02
			var c := Painter.ramp_real(base, s)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	# a few moth holes
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 3:
		var hx := rng.randf_range(x0 + 10, x1 - 10)
		var hy := rng.randf_range(y1 - 50, y1 - 18)
		p.erase_ellipse(hx, hy, rng.randf_range(1.5, 3.0), rng.randf_range(1.0, 2.5))


static func _embroider(p: Painter, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	## Double gold border line with corner knots.
	for x in range(x0, x1):
		for yy in [y0, y0 + 2]:
			if p.get_px(x, yy).a > 0.5:
				p.img.set_pixel(x, yy, Painter.ramp_real(c, 1.1 if yy == y0 else 0.8))
	for y in range(y0, y1):
		for xx in [x0, x0 + 2, x1 - 1, x1 - 3]:
			if p.get_px(xx, y).a > 0.5:
				p.img.set_pixel(xx, y, Painter.ramp_real(c, 1.0 if xx < x1 - 2 else 0.75))
	for cpos in [Vector2(x0 + 1, y0 + 1), Vector2(x1 - 2, y0 + 1)]:
		p.ball(cpos.x, cpos.y, 2.2, 2.2, c)


# ============================================================================ in-game HUD

static func reliquary() -> Image:
	## Bottom-left HUD piece: portrait window (40x40 at 62,30), vial sockets at x 22 and x 126.
	var p := _p(164, 96, 801)
	# base plate
	p.flat_poly(PackedVector2Array([Vector2(6, 80), Vector2(158, 80), Vector2(152, 94), Vector2(12, 94)]), DARK_IRON, Vector3(0, -0.3, 1))
	p.capsule(Vector2(8, 80), Vector2(156, 80), 1.6, 1.6, IRON)
	for x in [10, 154]:
		_curl(p, Vector2(x, 86), 6.0, PI * 0.5 if x < 80 else PI * 0.5, PI * 1.6 if x < 80 else -PI * 1.6, 1.4)
	# number plaques (recessed)
	for px in [12, 112]:
		p.flat_poly(PackedVector2Array([Vector2(px, 82), Vector2(px + 40, 82), Vector2(px + 40, 92), Vector2(px, 92)]), Color(0.06, 0.05, 0.06), Vector3(0, 0, 1))
	# vial brackets
	for vx in [30, 134]:
		p.capsule(Vector2(vx - 11, 20), Vector2(vx + 11, 20), 1.7, 1.7, IRON)
		p.capsule(Vector2(vx - 11, 74), Vector2(vx + 11, 74), 1.7, 1.7, IRON)
		p.capsule(Vector2(vx - 11, 20), Vector2(vx - 11, 79), 1.3, 1.5, DARK_IRON)
		p.capsule(Vector2(vx + 11, 20), Vector2(vx + 11, 79), 1.3, 1.5, DARK_IRON)
		_thorn(p, Vector2(vx, 18), Vector2(0, -1), 9.0, 2.2)
		_rivet(p, vx - 11, 20)
		_rivet(p, vx + 11, 20)
		_rivet(p, vx - 11, 74)
		_rivet(p, vx + 11, 74)
	# gothic arch frame around the portrait
	var outer := PackedVector2Array([Vector2(54, 78), Vector2(54, 30)])
	for i in 9:
		var t := float(i) / 8.0
		outer.append(Vector2(54, 30).lerp(Vector2(82, 4), t) + Vector2(sin(t * PI) * -4.0, 0))
	for i in 9:
		var t := float(i) / 8.0
		outer.append(Vector2(82, 4).lerp(Vector2(110, 30), t) + Vector2(sin(t * PI) * 4.0, 0))
	outer.append(Vector2(110, 78))
	p.flat_poly(outer, IRON, Vector3(-0.2, -0.4, 1))
	# stained glass in the arch head
	var glass := PackedVector2Array([Vector2(62, 29), Vector2(82, 11), Vector2(102, 29)])
	p.poly(glass, Color(0.3, 0.03, 0.05))
	for k in 3:
		p.line(Vector2(72 + k * 10, 29), Vector2(82, 12), Color(0.08, 0.06, 0.06))
	p.glow(82, 22, 7, Color(1.0, 0.3, 0.2), 0.7)
	p.ball(82, 22, 2.2, 2.2, Color(0.95, 0.25, 0.2))
	# inner bevel lip
	p.capsule(Vector2(60, 29), Vector2(104, 29), 1.4, 1.4, GOLD)
	p.capsule(Vector2(60, 29), Vector2(60, 72), 1.2, 1.2, DARK_IRON)
	p.capsule(Vector2(104, 29), Vector2(104, 72), 1.2, 1.2, IRON.lightened(0.1))
	p.capsule(Vector2(60, 72), Vector2(104, 72), 1.4, 1.4, GOLD.darkened(0.2))
	# thorns on the arch
	for t in [0.2, 0.45, 0.7]:
		var lp := Vector2(54, 30).lerp(Vector2(82, 4), t) + Vector2(sin(t * PI) * -4.0, 0)
		var rp := Vector2(110, 30).lerp(Vector2(82, 4), t) + Vector2(sin(t * PI) * 4.0, 0)
		_thorn(p, lp, Vector2(-1, -0.6), 6.0, 1.6)
		_thorn(p, rp, Vector2(1, -0.6), 6.0, 1.6)
	_thorn(p, Vector2(82, 5), Vector2(0, -1), 6.0, 1.8, GOLD)
	# skull keystone
	_skull(p, 82, 84, 1.0)
	_rivet(p, 58, 34)
	_rivet(p, 106, 34)
	_rivet(p, 58, 74)
	_rivet(p, 106, 74)
	p.rim(0.45, 0.12)
	# punch the portrait window
	for y in range(30, 70):
		for x in range(62, 102):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	return p.img


static func _flask_shape(x: float, y: float) -> bool:
	## 16x60 phial: 6px neck (y < 10), 14px body with a rounded bottom.
	if y < 2:
		return false
	if y < 10:
		return absf(x - 7.5) <= 3.0
	if y < 13:
		return absf(x - 7.5) <= 3.0 + (y - 10) * 1.4
	if y > 52:
		var dy := (y - 52) / 7.0
		return absf(x - 7.5) <= 7.0 * sqrt(maxf(1.0 - dy * dy, 0.0))
	return absf(x - 7.5) <= 7.0


static func vial_back() -> Image:
	var img := Image.create(16, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 60:
		for x in 16:
			if _flask_shape(x, y):
				img.set_pixel(x, y, Color(0.04, 0.035, 0.05, 0.92))
	return img


static func vial_liquid(base: Color, seed_value: int, glow: bool) -> Image:
	var img := Image.create(16, 60, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in 60:
		for x in 16:
			if not _flask_shape(x, y) or absf(x - 7.5) > 6.0 or y < 12:
				continue
			var u := (x - 7.5) / 6.5
			var s := 0.75 + (1.0 - u * u) * 0.35 - u * 0.12 + n.get_noise_2d(x, y * 0.6) * 0.18
			if glow:
				s += 0.15
			var c := Painter.ramp_real(base, s)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	for i in 7:
		var bx := rng.randi_range(4, 11)
		var by := rng.randi_range(16, 56)
		img.set_pixel(bx, by, base.lightened(0.55))
		if rng.randf() < 0.5:
			img.set_pixel(bx + 1, by - 1, base.lightened(0.35))
	return img


static func vial_over() -> Image:
	var p := _p(16, 60, 803)
	for y in 60:
		for x in 16:
			if not _flask_shape(x, y):
				continue
			var edge := not _flask_shape(x - 1, y) or not _flask_shape(x + 1, y) or not _flask_shape(x, y + 1)
			if edge:
				p.img.set_pixel(x, y, Color(0.62, 0.66, 0.7, 0.85))
	for y in range(14, 50):
		p.img.set_pixel(3, y, Color(1, 1, 1, 0.42))
		if y % 3 != 0:
			p.img.set_pixel(4, y, Color(1, 1, 1, 0.18))
	p.img.set_pixel(11, 20, Color(1, 1, 1, 0.5))
	p.img.set_pixel(11, 21, Color(1, 1, 1, 0.3))
	# iron cap
	p.flat_poly(PackedVector2Array([Vector2(3, 0), Vector2(13, 0), Vector2(12, 5), Vector2(4, 5)]), IRON, Vector3(-0.3, -0.5, 1))
	p.capsule(Vector2(4, 5), Vector2(12, 5), 1.2, 1.2, GOLD)
	return p.img


static func runestone() -> Image:
	var p := _p(34, 40, 811)
	p.capsule(Vector2(17, 1), Vector2(17, 5), 1.8, 1.8, IRON)
	p.flat_poly(PackedVector2Array([Vector2(3, 6), Vector2(31, 5), Vector2(32, 36), Vector2(29, 39), Vector2(4, 39), Vector2(2, 35)]), STONE, Vector3(-0.15, -0.25, 1))
	p.grime(Color(0.2, 0.22, 0.16), 0.5, 0.12, 0.25, 0.4, 7)
	# carved recess for the icon (24x24 at 5,6)
	p.flat_poly(PackedVector2Array([Vector2(4, 5), Vector2(30, 5), Vector2(30, 31), Vector2(4, 31)]), STONE.darkened(0.45), Vector3(0.3, 0.4, 1))
	p.rim(0.5, 0.15)
	for x in range(5, 29):
		for y in range(6, 30):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	return p.img


static func runestone_glow() -> Image:
	var p := Painter.new(40, 46, 812)
	for y in 46:
		for x in 40:
			var dx := maxf(absf(x - 19.5) - 14.0, 0.0)
			var dy := maxf(absf(y - 24.5) - 17.0, 0.0)
			var d := sqrt(dx * dx + dy * dy)
			if d > 0.0 and d < 4.0:
				p.img.set_pixel(x, y, Color(1, 1, 1, (1.0 - d / 4.0) * 0.8))
	return p.img


static func rune_rack() -> Image:
	## Iron rod with three chains, stones hang at x = 5, 49, 93 (34 wide), y = 14.
	var p := _p(132, 16, 813)
	p.capsule(Vector2(4, 4), Vector2(128, 4), 1.8, 1.8, IRON)
	for x in [3.0, 129.0]:
		p.ball(x, 4, 3.0, 3.0, GOLD)
	_thorn(p, Vector2(1, 4), Vector2(-1, 0), 4.0, 1.4)
	for cx in [22.0, 66.0, 110.0]:
		for k in 3:
			p.ball(cx, 7 + k * 3, 1.3, 1.6, DARK_IRON.lightened(0.15))
	p.rim(0.4, 0.0)
	return p.img


static func flask(full: bool) -> Image:
	var p := _p(12, 16, 820 + int(full))
	p.ball(6, 11, 4.6, 4.4, Color(0.5, 0.55, 0.6, 1))
	if full:
		p.ball(6, 11.5, 3.8, 3.4, Color(0.7, 0.06, 0.08))
	else:
		p.ball(6, 11.5, 3.8, 3.4, Color(0.08, 0.07, 0.08))
	p.rect(4, 2, 4, 5, Color(0.5, 0.55, 0.6))
	p.rect(4, 0, 4, 3, LEATHER)
	p.rim(0.45, 0.0)
	p.put(4, 9, Color(1, 1, 1, 0.8))
	return p.img


static func pouch() -> Image:
	var p := _p(18, 18, 830)
	p.ball(9, 11, 7, 6, LEATHER)
	p.flat_poly(PackedVector2Array([Vector2(5, 6), Vector2(13, 6), Vector2(11, 2), Vector2(7, 2)]), LEATHER.lightened(0.1), Vector3(0, -0.4, 1))
	p.capsule(Vector2(5, 6), Vector2(13, 6), 1.0, 1.0, GOLD)
	p.ball(12, 13, 2.2, 1.8, GOLD)
	p.ball(14, 15, 2.0, 1.6, GOLD)
	p.rim(0.45, 0.0)
	return p.img


static func night_plate() -> Image:
	var p := _p(180, 30, 840)
	p.flat_poly(PackedVector2Array([Vector2(14, 4), Vector2(166, 4), Vector2(176, 15), Vector2(166, 26), Vector2(14, 26), Vector2(4, 15)]), DARK_IRON, Vector3(0, -0.2, 1))
	p.capsule(Vector2(16, 5), Vector2(164, 5), 1.0, 1.0, GOLD.darkened(0.1))
	p.capsule(Vector2(16, 25), Vector2(164, 25), 1.0, 1.0, GOLD.darkened(0.35))
	for x in [4.0, 176.0]:
		p.ball(x, 15, 3.0, 3.0, GOLD)
	for x in [20.0, 160.0]:
		_rivet(p, x, 15, 1.6, IRON.lightened(0.2))
	p.rim(0.45, 0.1)
	return p.img


static func boss_frame() -> Image:
	## 340x30: skull on the left, bar window 292x8 at (38, 11).
	var p := _p(340, 30, 850)
	p.flat_poly(PackedVector2Array([Vector2(30, 7), Vector2(334, 7), Vector2(338, 15), Vector2(334, 23), Vector2(30, 23)]), DARK_IRON, Vector3(0, -0.2, 1))
	p.capsule(Vector2(32, 8), Vector2(332, 8), 1.2, 1.2, IRON)
	p.capsule(Vector2(32, 22), Vector2(332, 22), 1.2, 1.2, IRON.darkened(0.2))
	for x in range(60, 330, 40):
		_thorn(p, Vector2(x, 7), Vector2(0, -1), 4.0, 1.2)
		_thorn(p, Vector2(x, 23), Vector2(0, 1), 4.0, 1.2)
	# antlered skull
	p.ball(17, 15, 9, 9.5, BONE)
	p.ball(17, 22, 6, 3.5, BONE)
	p.ball(13.5, 15, 2.6, 2.8, Color(0.04, 0.05, 0.04))
	p.ball(20.5, 15, 2.6, 2.8, Color(0.04, 0.05, 0.04))
	for side in [-1.0, 1.0]:
		p.capsule(Vector2(17 + side * 6, 8), Vector2(17 + side * 11, 1), 1.4, 0.8, BONE)
		p.capsule(Vector2(17 + side * 9, 4), Vector2(17 + side * 14, 4), 1.0, 0.6, BONE)
	p.rim(0.45, 0.1)
	p.glow(13.5, 15, 3.5, Color(0.4, 1.0, 0.5), 1.0)
	p.glow(20.5, 15, 3.5, Color(0.4, 1.0, 0.5), 1.0)
	for y in range(11, 19):
		for x in range(38, 330):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	return p.img


static func boss_fill(under: bool) -> Image:
	var img := Image.create(292, 8, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 851
	n.frequency = 0.15
	for y in 8:
		for x in 292:
			if under:
				img.set_pixel(x, y, Color(0.03, 0.04, 0.03, 1))
			else:
				var v := n.get_noise_2d(x, y * 2.0) * 0.5 + 0.5
				var c := Color(0.12, 0.45, 0.18).lerp(Color(0.55, 1.0, 0.55), v * (1.0 - absf(y - 3.5) / 5.0))
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1))
	return img


static func vignette(blood: bool) -> Image:
	## 320x180, drawn at 2x over the whole screen.
	var img := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	var veins := FastNoiseLite.new()
	veins.seed = 860
	veins.frequency = 0.05
	veins.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	veins.fractal_octaves = 4
	for y in 180:
		for x in 320:
			var dx := (x - 159.5) / 160.0
			var dy := (y - 89.5) / 90.0
			var d := sqrt(dx * dx * 0.8 + dy * dy * 1.1)
			var a := smoothstep(0.55, 1.15, d)
			if blood:
				var v := veins.get_noise_2d(x, y) * 0.5 + 0.5
				var vein := smoothstep(0.82, 0.95, v) * smoothstep(0.35, 0.95, d)
				a = clampf(a * 0.9 + vein * 0.8, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.35 + vein * 0.2, 0.0, 0.02, a))
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.01, a))
	return img


static func crosshair(kind: String) -> Image:
	var img := Image.create(15, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.95, 0.9, 0.78, 0.95)
	var sh := Color(0, 0, 0, 0.6)
	var pts: Array = []
	match kind:
		"warrior":
			pts = [Vector2i(3, 5), Vector2i(2, 6), Vector2i(2, 7), Vector2i(2, 8), Vector2i(3, 9),
				Vector2i(11, 5), Vector2i(12, 6), Vector2i(12, 7), Vector2i(12, 8), Vector2i(11, 9), Vector2i(7, 7)]
		"mage":
			for i in 16:
				var a := float(i) / 16.0 * TAU
				pts.append(Vector2i(int(round(7 + cos(a) * 4.5)), int(round(7 + sin(a) * 4.5))))
			pts += [Vector2i(7, 0), Vector2i(7, 1), Vector2i(7, 13), Vector2i(7, 14), Vector2i(0, 7), Vector2i(1, 7), Vector2i(13, 7), Vector2i(14, 7), Vector2i(7, 7)]
		_:
			pts = [Vector2i(7, 7), Vector2i(7, 9), Vector2i(6, 10), Vector2i(8, 10), Vector2i(5, 11), Vector2i(9, 11),
				Vector2i(2, 7), Vector2i(3, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(7, 3), Vector2i(7, 2)]
	for q: Vector2i in pts:
		if q.x + 1 < 15 and q.y + 1 < 15:
			img.set_pixel(q.x + 1, q.y + 1, sh)
	for q: Vector2i in pts:
		img.set_pixel(q.x, q.y, c)
	return img


static func boon_frame() -> Image:
	var p := _p(28, 28, 870)
	for y in 28:
		for x in 28:
			if x < 2 or y < 2 or x > 25 or y > 25:
				p.img.set_pixel(x, y, Painter.ramp_real(IRON, 1.15 if (x < 2 or y < 2) else 0.6))
	for c in [Vector2(1.5, 1.5), Vector2(26.5, 1.5), Vector2(1.5, 26.5), Vector2(26.5, 26.5)]:
		_rivet(p, c.x, c.y, 1.8)
	return p.img


# ============================================================================ menus

static func candle_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := _p(10, 20, 880 + f)
		p.capsule(Vector2(5, 11), Vector2(5, 18), 2.8, 3.0, Color(0.82, 0.76, 0.62))
		p.ball(6.5, 12.5, 1.0, 2.0, Color(0.86, 0.8, 0.66))
		p.line(Vector2(5, 7), Vector2(5, 9), Color(0.1, 0.08, 0.06))
		var fx: float = 5.0 + [0.0, 0.5, -0.4, 0.2][f]
		var fh: float = [6.0, 7.0, 5.5, 6.5][f]
		for y in int(fh):
			var t := float(y) / fh
			var wv := (1.0 - t) * 1.8 + 0.3
			for x in range(int(fx - wv), int(fx + wv) + 1):
				var c := Color(1.0, 0.95, 0.7) if absf(x - fx) < wv * 0.5 and t < 0.6 else Color(1.0, 0.55, 0.15)
				p.put(x, int(8 - y), c)
		p.glow(fx, 4, 5, Color(1.0, 0.6, 0.2), 0.35)
		frames.append(p.img)
	return Painter.strip(frames)


static func menu_banner() -> Image:
	## 180x260 crimson tapestry on an iron rod with the keep sigil (tower under a crescent).
	var p := _p(180, 260, 890)
	_cloth(p, 14, 10, 166, 256, Color(0.34, 0.05, 0.07), 890, 9.0)
	_embroider(p, 20, 16, 160, 236, GOLD)
	# sigil
	var cx := 90.0
	p.ball(cx, 44, 20, 20, Color(0.22, 0.03, 0.05))
	for i in 24:
		var a := float(i) / 24.0 * TAU
		p.ball(cx + cos(a) * 20, 44 + sin(a) * 20, 1.2, 1.2, GOLD)
	p.ball(cx + 7, 34, 7, 7, Color(0.86, 0.84, 0.7))
	p.ball(cx + 10, 32, 6, 6, Color(0.22, 0.03, 0.05))
	p.flat_poly(PackedVector2Array([Vector2(cx - 9, 60), Vector2(cx - 9, 42), Vector2(cx - 11, 42), Vector2(cx - 11, 37), Vector2(cx - 7, 37), Vector2(cx - 7, 40), Vector2(cx - 3, 40), Vector2(cx - 3, 32), Vector2(cx, 27), Vector2(cx + 3, 32), Vector2(cx + 3, 60)]), GOLD, Vector3(-0.3, -0.3, 1))
	p.rect(cx - 1, 45, 2, 3, Color(0.22, 0.03, 0.05))
	# rod
	p.capsule(Vector2(4, 8), Vector2(176, 8), 2.4, 2.4, IRON)
	for x in [3.0, 177.0]:
		p.ball(x, 8, 4, 4, GOLD)
	p.rim(0.35, 0.08)
	return p.img


static func tapestry(base: Color, trim: Color, sigil: String, seed_value: int) -> Image:
	## 150x232 class banner; portrait roundel centred at (75, 120) radius 24.
	var p := _p(150, 232, seed_value)
	_cloth(p, 10, 8, 140, 230, base, seed_value, 7.0)
	_embroider(p, 16, 14, 134, 212, trim)
	var cx := 75.0
	var sc := trim.lerp(Color(0.95, 0.92, 0.85), 0.3)
	match sigil:
		"axes":
			for side in [-1.0, 1.0]:
				p.capsule(Vector2(cx - side * 14, 58), Vector2(cx + side * 12, 24), 1.4, 1.4, Color(0.4, 0.25, 0.14))
				var hd := Vector2(cx + side * 12, 24)
				p.flat_poly(PackedVector2Array([hd + Vector2(-side * 1, 2), hd + Vector2(side * 10, -2), hd + Vector2(side * 9, 9), hd + Vector2(side * 1, 6)]), sc, Vector3(-side * 0.3, -0.4, 1))
			p.ball(cx, 44, 8, 9, trim.darkened(0.2))
			p.ball(cx, 44, 5, 6, base.darkened(0.2))
		"flame":
			for i in 28:
				var a := float(i) / 28.0 * TAU
				p.ball(cx + cos(a) * 17, 40 + sin(a) * 17, 1.0, 1.0, sc)
			for k in 3:
				p.flat_poly(PackedVector2Array([Vector2(cx - 8 + k * 3, 52), Vector2(cx - 2 + k * 2, 24 + k * 4), Vector2(cx + 2 + k * 2, 52)]), Color(0.95, 0.55 + k * 0.12, 0.15), Vector3(-0.2, -0.3, 1))
			p.ball(cx, 46, 4, 3, Color(1.0, 0.9, 0.6))
		"arrows":
			for side in [-1.0, 1.0]:
				p.capsule(Vector2(cx - side * 15, 60), Vector2(cx + side * 13, 24), 1.0, 1.0, Color(0.5, 0.36, 0.22))
				var tip := Vector2(cx + side * 13, 24)
				p.flat_poly(PackedVector2Array([tip + Vector2(-side * 4, -1), tip + Vector2(side * 3, -5), tip + Vector2(side * 1, 3)]), sc, Vector3(0, -0.4, 1))
			for side in [-1.0, 1.0]:
				p.capsule(Vector2(cx + side * 3, 30), Vector2(cx + side * 10, 14), 1.2, 0.7, Color(0.75, 0.7, 0.58))
				p.capsule(Vector2(cx + side * 7, 22), Vector2(cx + side * 13, 20), 1.0, 0.6, Color(0.75, 0.7, 0.58))
	# portrait roundel
	p.ball(cx, 120, 25, 25, trim.darkened(0.15))
	p.ball(cx, 120, 22, 22, base.darkened(0.45))
	p.capsule(Vector2(4, 6), Vector2(146, 6), 2.2, 2.2, IRON)
	for x in [3.0, 147.0]:
		p.ball(x, 6, 3.6, 3.6, trim)
	p.rim(0.35, 0.08)
	return p.img


static func vellum() -> Image:
	## 48x48 nine-patch (12px border): dark tooled leather with gold corners and stitching.
	var p := _p(48, 48, 900)
	var n := FastNoiseLite.new()
	n.seed = 900
	n.frequency = 0.2
	for y in 48:
		for x in 48:
			var s := 0.85 + n.get_noise_2d(x, y) * 0.15
			var c := Painter.ramp_real(Color(0.17, 0.12, 0.1), s)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.96))
	for i in 48:
		for e in [0, 47]:
			p.img.set_pixel(i, e, Color(0.04, 0.03, 0.03))
			p.img.set_pixel(e, i, Color(0.04, 0.03, 0.03))
		for e in [3, 44]:
			if i % 3 != 0 and i > 3 and i < 44:
				p.img.set_pixel(i, e, Color(0.5, 0.42, 0.3))
				p.img.set_pixel(e, i, Color(0.5, 0.42, 0.3))
	for c in [Vector2(6, 6), Vector2(41, 6), Vector2(6, 41), Vector2(41, 41)]:
		p.ball(c.x, c.y, 4.0, 4.0, GOLD)
		p.ball(c.x, c.y, 1.6, 1.6, Color(0.5, 0.06, 0.06))
	return p.img


static func tablet(gem: Color, seed_value: int) -> Image:
	## 140x180 boon tablet: arched stone, icon niche at (70, 46) r 27, gem on top.
	var p := _p(140, 180, seed_value)
	var shape := PackedVector2Array([Vector2(6, 178), Vector2(6, 40)])
	for i in 17:
		var a := PI + float(i) / 16.0 * PI
		shape.append(Vector2(70 + cos(a) * 64, 40 + sin(a) * 36))
	shape.append(Vector2(134, 178))
	p.flat_poly(shape, STONE, Vector3(-0.15, -0.2, 1))
	p.grime(Color(0.22, 0.24, 0.18), 0.55, 0.06, 0.15, 0.6, seed_value)
	# carved inner border
	var inner := PackedVector2Array([Vector2(14, 170), Vector2(14, 42)])
	for i in 17:
		var a := PI + float(i) / 16.0 * PI
		inner.append(Vector2(70 + cos(a) * 56, 42 + sin(a) * 29))
	inner.append(Vector2(126, 170))
	for i in inner.size():
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[(i + 1) % inner.size()]
		p.line(a, b, STONE.darkened(0.55), 1.0)
		p.line(a + Vector2(1, 1), b + Vector2(1, 1), STONE.lightened(0.2), 1.0)
	# icon niche
	p.ball(70, 50, 28, 28, STONE.darkened(0.15))
	p.ball(70, 50, 26, 26, Color(0.1, 0.09, 0.1))
	# text field
	p.flat_poly(PackedVector2Array([Vector2(18, 84), Vector2(122, 84), Vector2(122, 166), Vector2(18, 166)]), STONE.darkened(0.42), Vector3(0.2, 0.3, 1))
	# gem
	p.ball(70, 7, 6.5, 6.5, GOLD)
	p.ball(70, 7, 4.5, 4.5, gem)
	p.put(68, 5, Color(1, 1, 1, 0.9))
	p.rim(0.45, 0.12)
	p.glow(70, 7, 9, gem, 0.5)
	return p.img


static func altar_slab() -> Image:
	var p := _p(600, 52, 910)
	p.flat_poly(PackedVector2Array([Vector2(10, 8), Vector2(590, 8), Vector2(600, 16), Vector2(0, 16)]), STONE.lightened(0.05), Vector3(0, -1, 0.4))
	p.flat_poly(PackedVector2Array([Vector2(0, 16), Vector2(600, 16), Vector2(592, 52), Vector2(8, 52)]), STONE.darkened(0.15), Vector3(0, 0, 1))
	p.grime(Color(0.2, 0.22, 0.16), 0.6, 0.05, 0.1, 0.7, 911)
	for k in 12:
		var x := 40 + k * 48
		p.line(Vector2(x, 26), Vector2(x, 42), Color(0.25, 0.7, 0.35))
		p.line(Vector2(x - 4, 30), Vector2(x + 4, 38), Color(0.25, 0.7, 0.35))
	p.rim(0.4, 0.1)
	for k in 12:
		p.glow(40 + k * 48, 34, 7, Color(0.3, 1.0, 0.45), 0.35)
	return p.img


static func tombstone() -> Image:
	var p := _p(240, 214, 920)
	var shape := PackedVector2Array([Vector2(14, 200), Vector2(14, 70)])
	for i in 21:
		var a := PI + float(i) / 20.0 * PI
		shape.append(Vector2(120 + cos(a) * 106, 70 + sin(a) * 62))
	shape.append(Vector2(226, 200))
	p.flat_poly(shape, STONE.darkened(0.05), Vector3(-0.1, -0.15, 1))
	p.grime(Color(0.2, 0.24, 0.16), 0.7, 0.04, 0.05, 0.8, 921)
	p.grime(Color(0.1, 0.1, 0.1), 0.4, 0.12, 0.35, 0.0, 922)
	# crack
	var cp := Vector2(176, 22)
	for k in 12:
		var np := cp + Vector2(-3 + (k % 3) * 2, 6)
		p.line(cp, np, Color(0.08, 0.07, 0.08))
		cp = np
	# carved sword
	p.line(Vector2(120, 18), Vector2(120, 46), STONE.darkened(0.6), 2.0)
	p.line(Vector2(112, 24), Vector2(128, 24), STONE.darkened(0.6), 2.0)
	p.line(Vector2(121, 19), Vector2(121, 46), STONE.lightened(0.25), 1.0)
	# ground + moss
	p.flat_poly(PackedVector2Array([Vector2(0, 198), Vector2(240, 198), Vector2(240, 214), Vector2(0, 214)]), Color(0.18, 0.14, 0.1), Vector3(0, -1, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 923
	for i in 90:
		var x := rng.randf_range(4, 236)
		p.line(Vector2(x, 200), Vector2(x + rng.randf_range(-2, 2), 200 - rng.randf_range(2, 9)), Color(0.22, 0.34, 0.14))
	p.rim(0.45, 0.1)
	return p.img


static func scroll() -> Image:
	## 260x230 unrolled parchment with rolled ends (text area x 20..240, y 26..204).
	var p := _p(260, 230, 930)
	var n := FastNoiseLite.new()
	n.seed = 930
	n.frequency = 0.04
	var fine := FastNoiseLite.new()
	fine.seed = 931
	fine.frequency = 0.4
	for y in range(14, 216):
		for x in range(14, 246):
			var edge := minf(minf(x - 14, 245 - x), 60.0)
			var burn := n.get_noise_2d(x, y) * 6.0
			if edge + burn < 1.0:
				continue
			var s := 0.9 + fine.get_noise_2d(x, y) * 0.08 + n.get_noise_2d(x * 2.0, y * 2.0) * 0.1
			var c := Painter.ramp_real(PARCHMENT, s)
			if edge + burn < 5.0:
				c = c.lerp(Color(0.25, 0.14, 0.06), 0.6)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1))
	for ry in [12.0, 218.0]:
		p.capsule(Vector2(8, ry), Vector2(252, ry), 9.0, 9.0, PARCHMENT.darkened(0.1))
		for x in [5.0, 255.0]:
			p.ball(x, ry, 5.0, 5.0, Color(0.4, 0.26, 0.14))
	p.rim(0.35, 0.05)
	return p.img


# ============================================================================ title font

static func title_font() -> Array:
	## Chiselled serif display font built from the 5x7 glyphs: 2x strokes with thin
	## horizontals, serifs, silver bevel, dark outline and drop shadow (tint with font_color).
	var cw := 16
	var ch := 21
	var cols := 16
	var img := Image.create(cols * cw, 6 * ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for code in range(32, 127):
		var c := char(code)
		var key := c.to_upper() if c >= "a" and c <= "z" else c
		var rows: Array = FontData.GLYPHS.get(key, FontData.GLYPHS["?"])
		var gw := FontData.glyph_width(key)
		var gh := rows.size()
		var on := func(x: int, y: int) -> bool:
			if x < 0 or y < 0 or y >= gh:
				return false
			var r: String = rows[y]
			return x < r.length() and r[x] == "#"
		var mask := {}
		for y in gh:
			for x in gw:
				if not on.call(x, y):
					continue
				var up: bool = on.call(x, y - 1)
				var dn: bool = on.call(x, y + 1)
				var lf: bool = on.call(x - 1, y)
				var rt: bool = on.call(x + 1, y)
				var bx := x * 2 + 1
				var by := y * 2
				var horiz_only := not up and not dn and (lf or rt)
				for oy in 2:
					for ox in 2:
						if horiz_only and oy == (1 if y < 3 else 0):
							continue
						mask[Vector2i(bx + ox, by + oy)] = true
				if not up and dn:
					mask[Vector2i(bx - 1, by)] = true
					mask[Vector2i(bx + 2, by)] = true
				if not dn and up and y >= 5:
					mask[Vector2i(bx - 1, by + 1)] = true
					mask[Vector2i(bx + 2, by + 1)] = true
		var ox0 := (code - 32) % cols * cw + 1
		var oy0 := (code - 32) / cols * ch + 1
		var hpx := gh * 2
		# shadow, outline, fill
		for q: Vector2i in mask:
			var sp := Vector2i(ox0 + q.x + 2, oy0 + q.y + 2)
			img.set_pixel(sp.x, sp.y, Color(0, 0, 0, 0.75))
		for q: Vector2i in mask:
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var nq: Vector2i = q + o
				if not mask.has(nq):
					img.set_pixel(ox0 + nq.x + 1, oy0 + nq.y + 1, Color(0.05, 0.04, 0.05, 1))
		for q: Vector2i in mask:
			var t := float(q.y) / 14.0
			var v := lerpf(1.0, 0.55, t)
			if not mask.has(q + Vector2i(0, -1)):
				v = minf(v + 0.18, 1.0)
			elif not mask.has(q + Vector2i(0, 1)):
				v -= 0.18
			if t > 0.48 and t < 0.56:
				v -= 0.12
			img.set_pixel(ox0 + q.x + 1, oy0 + q.y + 1, Color(v, v, v * 0.97, 1))
	return [img, {"cell_w": cw, "cell_h": ch, "baseline": 16, "cols": cols}]
