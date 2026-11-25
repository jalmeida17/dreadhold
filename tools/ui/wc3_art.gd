extends RefCounted
## RTS-console style UI art (inspired by classic RTS consoles, all original):
## class-themed bottom console, top resource bar with night dial, boss plate,
## ornate frames, buttons, tabs, slots, bars, gems, relic beam, boss-arena art.
## Everything is drawn at "art" resolution and saved at 2x for the 1280x720 UI.

const Painter := preload("res://tools/art/painter.gd")

const THEMES := {
	"warrior": {"stone": Color(0.22, 0.215, 0.21), "trim": Color(0.78, 0.6, 0.26), "accent": Color(0.6, 0.07, 0.07), "metal": Color(0.36, 0.36, 0.37), "glow": Color(1.0, 0.45, 0.15)},
	"mage": {"stone": Color(0.215, 0.215, 0.22), "trim": Color(0.74, 0.64, 0.4), "accent": Color(0.2, 0.35, 0.85), "metal": Color(0.36, 0.36, 0.38), "glow": Color(0.4, 0.85, 1.0)},
	"hunter": {"stone": Color(0.22, 0.21, 0.2), "trim": Color(0.7, 0.55, 0.3), "accent": Color(0.18, 0.42, 0.14), "metal": Color(0.36, 0.35, 0.34), "glow": Color(0.6, 1.0, 0.35)},
}


static func _p(w: int, h: int, seed_value: int) -> Painter:
	var p := Painter.new(w, h, seed_value)
	p.set_real(1.0)
	p.spec = 0.3
	return p


static func x2(img: Image) -> Image:
	var c := img.duplicate() as Image
	c.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return c


static func _stone_rect(p: Painter, x0: int, y0: int, x1: int, y1: int, base: Color, seed_value: int, bevel: int = 2) -> void:
	## Carved stone block with noise and a light top/left, dark bottom/right bevel.
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.09
	n.fractal_octaves = 3
	var f := FastNoiseLite.new()
	f.seed = seed_value + 1
	f.frequency = 0.5
	for y in range(y0, y1):
		for x in range(x0, x1):
			var s := 0.85 + n.get_noise_2d(x, y) * 0.18 + f.get_noise_2d(x, y) * 0.07
			if y - y0 < bevel or x - x0 < bevel:
				s += 0.18
			elif y1 - 1 - y < bevel or x1 - 1 - x < bevel:
				s -= 0.28
			var c := Painter.ramp_real(base, s)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))


static func _rail(p: Painter, a: Vector2, b: Vector2, c: Color, r: float = 1.3) -> void:
	p.capsule(a, b, r, r, c)


static func _gem(p: Painter, x: float, y: float, r: float, c: Color, trim: Color) -> void:
	p.ball(x, y, r + 1.2, r + 1.2, trim)
	p.ball(x, y, r, r, c)
	p.put(int(x - r * 0.4), int(y - r * 0.4), Color(1, 1, 1, 0.9))


static func _recess(p: Painter, x0: int, y0: int, x1: int, y1: int, dark: Color = Color(0.03, 0.03, 0.04)) -> void:
	## Sunken dark panel with an inner shadow line and light lower lip.
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := dark
			if y == y0 or x == x0:
				c = Color(0.0, 0.0, 0.0)
			elif y == y1 - 1 or x == x1 - 1:
				c = dark.lightened(0.12)
			p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.94))


static func _slot(p: Painter, x: int, y: int, s: int, th: Dictionary) -> void:
	## Icon socket: metal bevel ring around an s x s hole (hole left transparent-dark).
	for yy in range(y - 2, y + s + 2):
		for xx in range(x - 2, x + s + 2):
			var inside := xx >= x and yy >= y and xx < x + s and yy < y + s
			if inside:
				p.img.set_pixel(xx, yy, Color(0.02, 0.02, 0.03, 1.0))
			else:
				var lit := xx < x or yy < y
				p.img.set_pixel(xx, yy, Painter.ramp_real(th.metal, 1.2 if lit else 0.55))
	for c in [Vector2(x - 2, y - 2), Vector2(x + s + 1, y - 2), Vector2(x - 2, y + s + 1), Vector2(x + s + 1, y + s + 1)]:
		p.img.set_pixel(int(c.x), int(c.y), Painter.ramp_real(th.trim, 1.2))


static func _filigree(p: Painter, cx: float, cy: float, s: float, c: Color) -> void:
	## Symmetric gold scroll ornament.
	for side in [-1.0, 1.0]:
		var prev := Vector2(cx, cy)
		for i in 12:
			var t := float(i + 1) / 12.0
			var a: float = PI * 0.5 + side * t * PI * 1.3
			var r := s * (1.0 - t * 0.6)
			var pt := Vector2(cx + side * s * 0.9 * t, cy) + Vector2(cos(a), sin(a)) * r * 0.5
			p.capsule(prev, pt, 1.1, 0.8, c)
			prev = pt


# ============================================================================ bottom console

const CONSOLE_W := 640
const CONSOLE_H := 80


static func console(kind: String) -> Image:
	## Layout (art px): minimap window (8,12) 64x64; portrait window (86,8) 48x48 with two
	## text lines below (84..136, 59..78); info recess (146,28)-(430,77); inventory 3x2
	## slots of 24 at (440 + c*26, 26 + r*26); command card 4x2 slots of 24 at (526 + c*28, 20 + r*28).
	var th: Dictionary = THEMES[kind]
	var p := _p(CONSOLE_W, CONSOLE_H, 960 + kind.length())
	_stone_rect(p, 0, 22, CONSOLE_W, CONSOLE_H, th.stone, 961, 2)
	_stone_rect(p, 0, 4, 80, 30, th.stone, 962, 2)
	_stone_rect(p, 436, 14, 520, 30, th.stone, 963, 2)
	_stone_rect(p, 520, 8, 640, 30, th.stone, 964, 2)
	var arch := PackedVector2Array([Vector2(80, 80), Vector2(80, 10)])
	for i in 11:
		var t := float(i) / 10.0
		arch.append(Vector2(lerpf(80, 140, t), 10 - sin(t * PI) * 10))
	arch.append(Vector2(140, 10))
	arch.append(Vector2(140, 80))
	var hp := _p(CONSOLE_W, CONSOLE_H, 965)
	_stone_rect(hp, 80, 0, 140, 80, th.stone.lightened(0.05), 965, 2)
	for y in CONSOLE_H:
		for x in range(80, 140):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), arch):
				p.img.set_pixel(x, y, hp.img.get_pixel(x, y))
	# seams between housings, starting just under the border of the lower neighbour
	for seam in [[80, 12], [140, 25], [436, 18], [520, 18]]:
		_rail(p, Vector2(seam[0], seam[1]), Vector2(seam[0], 79), th.metal, 1.4)
		p.ball(seam[0], 79, 2.2, 2.2, th.trim)
	# windows and sockets
	_recess(p, 6, 10, 74, 78)
	_recess(p, 84, 6, 136, 58)
	_recess(p, 84, 59, 136, 78, Color(0.05, 0.04, 0.04))
	_recess(p, 146, 28, 430, 77)
	for r in 2:
		for c in 3:
			_slot(p, 440 + c * 26, 26 + r * 26, 24, th)
	for r in 2:
		for c in 4:
			_slot(p, 526 + c * 28, 20 + r * 28, 24, th)
	p.rim(0.25, 0.0)
	# one continuous gold border following the whole top silhouette (steps and arch included)
	var top := PackedInt32Array()
	top.resize(CONSOLE_W)
	for x in CONSOLE_W:
		var ty := CONSOLE_H - 1
		for y in CONSOLE_H:
			if p.img.get_pixel(x, y).a > 0.5:
				ty = y
				break
		top[x] = ty
	var lit: Color = Painter.ramp_real(th.trim, 1.25)
	var mid: Color = Painter.ramp_real(th.trim, 0.95)
	var dark: Color = Painter.ramp_real(th.trim, 0.55)
	for x in CONSOLE_W:
		var y: int = top[x]
		p.img.set_pixel(x, y, lit)
		p.img.set_pixel(x, y + 1, mid)
		p.img.set_pixel(x, y + 2, dark)
		if x > 0 and top[x] != top[x - 1]:
			var a: int = top[x - 1]
			var b: int = top[x]
			if b < a:
				for yy in range(b, a + 2):
					p.img.set_pixel(x, yy, lit)
					p.img.set_pixel(x + 1, yy, dark)
			else:
				for yy in range(a, b + 2):
					p.img.set_pixel(x - 1, yy, mid)
					p.img.set_pixel(x - 2, yy, dark)
	# accent gems on the border
	_gem(p, 110, 2.5, 2.4, th.accent, th.trim)
	_gem(p, 288, 23.5, 2.0, th.accent, th.trim)
	_gem(p, 580, 9.5, 2.0, th.accent, th.trim)
	_gem(p, 40, 5.5, 2.0, th.accent, th.trim)
	# transparent windows for minimap and portrait (drawn underneath)
	for y in range(12, 76):
		for x in range(8, 72):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in range(8, 56):
		for x in range(86, 134):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	var rr := 7.0
	for cc in [Vector2(86 + rr, 8 + rr), Vector2(134 - rr, 8 + rr)]:
		for y in range(8, int(8 + rr) + 1):
			for x in range(86, 134):
				var inside_corner: bool = (x < 86 + rr and cc.x < 110) or (x >= 134 - rr and cc.x > 110)
				if not inside_corner:
					continue
				var d := Vector2(x + 0.5, y + 0.5).distance_to(cc)
				if d > rr + 0.5:
					p.img.set_pixel(x, y, Painter.ramp_real(th.stone, 0.75))
				elif d > rr - 0.6:
					p.img.set_pixel(x, y, Painter.ramp_real(th.trim, 1.0))
	return p.img


static func _emblem(p: Painter, kind: String, cx: float, cy: float, th: Dictionary) -> void:
	p.ball(cx, cy, 11, 13, th.stone.darkened(0.3))
	p.ball(cx, cy, 9, 11, th.accent.darkened(0.3))
	match kind:
		"warrior":
			for side in [-1.0, 1.0]:
				p.capsule(Vector2(cx - side * 6, cy + 8), Vector2(cx + side * 5, cy - 7), 0.9, 0.9, Color(0.45, 0.3, 0.16))
				p.flat_poly(PackedVector2Array([Vector2(cx + side * 5, cy - 9), Vector2(cx + side * 9, cy - 6), Vector2(cx + side * 4, cy - 3)]), th.trim, Vector3(0, -0.4, 1))
		"mage":
			p.flat_poly(PackedVector2Array([Vector2(cx - 4, cy + 7), Vector2(cx, cy - 9), Vector2(cx + 4, cy + 7)]), Color(1.0, 0.6, 0.2), Vector3(-0.3, -0.3, 1))
			p.ball(cx, cy + 4, 2.4, 2.0, Color(1.0, 0.9, 0.6))
		_:
			p.capsule(Vector2(cx - 6, cy + 8), Vector2(cx + 6, cy - 8), 0.8, 0.8, Color(0.5, 0.36, 0.22))
			p.flat_poly(PackedVector2Array([Vector2(cx + 3, cy - 9), Vector2(cx + 8, cy - 10), Vector2(cx + 7, cy - 5)]), th.trim, Vector3(0, -0.4, 1))
			p.capsule(Vector2(cx - 6, cy + 8), Vector2(cx - 9, cy + 6), 0.8, 0.6, th.accent.lightened(0.3))


static func topbar(kind: String) -> Image:
	## 640x40 art: bar 0..15; a half-ring housing hangs from the very top at the centre
	## around a half-disc window centred (320, 0) radius 27 (the dial is drawn by the game).
	var th: Dictionary = THEMES[kind]
	var p := _p(640, 40, 970)
	_stone_rect(p, 0, 0, 640, 15, th.stone, 971, 1)
	_rail(p, Vector2(0, 15), Vector2(639, 15), th.trim, 1.2)
	_recess(p, 4, 2, 92, 13)
	for x0 in [424, 498, 568]:
		_recess(p, x0, 2, x0 + 68, 13)
	var hp := _p(640, 40, 972)
	_stone_rect(hp, 280, 0, 360, 40, th.stone.lightened(0.05), 972, 1)
	for y in 40:
		for x in range(280, 360):
			if Vector2(x + 0.5 - 320, y + 0.5).length() < 36.0:
				p.img.set_pixel(x, y, hp.img.get_pixel(x, y))
	for i in 24:
		var a0 := float(i) / 24.0 * PI
		var a1 := float(i + 1) / 24.0 * PI
		_rail(p, Vector2(320 + cos(a0) * 35, sin(a0) * 35), Vector2(320 + cos(a1) * 35, sin(a1) * 35), th.trim, 1.2)
		_rail(p, Vector2(320 + cos(a0) * 28, sin(a0) * 28), Vector2(320 + cos(a1) * 28, sin(a1) * 28), th.trim.darkened(0.35), 0.9)
	for k in 5:
		var a := PI * (0.1 + 0.2 * k)
		p.ball(320 + cos(a) * 31.5, sin(a) * 31.5, 1.3, 1.3, th.trim)
	_gem(p, 320, 33, 2.2, th.accent, th.trim)
	p.rim(0.25, 0.0)
	for y in range(0, 40):
		for x in range(280, 360):
			if Vector2(x + 0.5 - 320, y + 0.5).length() < 27.0:
				p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	return p.img


# ============================================================================ boss plate

static func boss_plate() -> Image:
	## 200x40 art. Portrait window (3,3) 34x34; name area x 42..196; bar window (42, 27) 152x7.
	var p := _p(200, 40, 980)
	var base := Color(0.16, 0.17, 0.16)
	var bone := Color(0.78, 0.74, 0.6)
	_stone_rect(p, 0, 0, 200, 40, base, 981, 1)
	_rail(p, Vector2(1, 1.5), Vector2(198, 1.5), bone, 1.1)
	_rail(p, Vector2(1, 38.5), Vector2(198, 38.5), bone, 1.1)
	for x in range(46, 198, 10):
		p.ball(x, 1.5, 1.6, 1.9, bone)
		p.ball(x, 38.5, 1.6, 1.9, bone)
	_recess(p, 1, 1, 39, 39, Color(0.02, 0.04, 0.02))
	_recess(p, 40, 25, 196, 36, Color(0.02, 0.03, 0.02))
	for side in [-1.0, 1.0]:
		p.capsule(Vector2(20 + side * 14, 2), Vector2(20 + side * 19, -2), 1.1, 0.8, bone)
	p.rim(0.3, 0.0)
	for y in range(3, 37):
		for x in range(3, 37):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in range(27, 34):
		for x in range(42, 194):
			p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	return p.img


static func gem_frames() -> Image:
	## 3 frames 8x10: intact, cracked, shattered phylactery.
	var frames: Array = []
	for f in 3:
		var p := _p(8, 10, 990 + f)
		p.ball(4, 5, 3.6, 4.6, Color(0.55, 0.5, 0.38))
		if f < 2:
			p.flat_poly(PackedVector2Array([Vector2(4, 1), Vector2(7, 5), Vector2(4, 9), Vector2(1, 5)]), Color(0.3, 0.95, 0.45), Vector3(-0.4, -0.5, 1))
			p.put(3, 3, Color(1, 1, 1, 0.9))
			if f == 1:
				p.line(Vector2(3, 2), Vector2(5, 5), Color(0.05, 0.1, 0.05))
				p.line(Vector2(5, 5), Vector2(3, 8), Color(0.05, 0.1, 0.05))
		else:
			p.flat_poly(PackedVector2Array([Vector2(4, 6), Vector2(6, 8), Vector2(2, 8)]), Color(0.15, 0.35, 0.2), Vector3(0, -0.5, 1))
			p.put(2, 4, Color(0.3, 0.9, 0.4))
			p.put(6, 3, Color(0.3, 0.9, 0.4))
		p.rim(0.35, 0.0)
		frames.append(p.img)
	return Painter.strip(frames)


# ============================================================================ generic UI

static func frame() -> Image:
	## 48x48 nine-patch (14px border): carved stone border with gold rail and corner ornaments.
	var th: Dictionary = THEMES["warrior"]
	var p := _p(48, 48, 1000)
	_stone_rect(p, 0, 0, 48, 48, Color(0.27, 0.25, 0.26), 1000, 2)
	for y in range(12, 36):
		for x in range(12, 36):
			p.img.set_pixel(x, y, Color(0.035, 0.035, 0.045, 0.93))
	_rail(p, Vector2(10, 10), Vector2(37, 10), th.trim, 1.0)
	_rail(p, Vector2(10, 37), Vector2(37, 37), th.trim.darkened(0.3), 1.0)
	_rail(p, Vector2(10, 10), Vector2(10, 37), th.trim.darkened(0.1), 1.0)
	_rail(p, Vector2(37, 10), Vector2(37, 37), th.trim.darkened(0.35), 1.0)
	for c in [Vector2(5, 5), Vector2(42, 5), Vector2(5, 42), Vector2(42, 42)]:
		p.ball(c.x, c.y, 4.2, 4.2, th.trim)
		p.ball(c.x, c.y, 2.0, 2.0, th.accent)
	p.rim(0.3, 0.0)
	return p.img


static func tooltip() -> Image:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var edge := x == 0 or y == 0 or x == 11 or y == 11
			var inner := x == 1 or y == 1 or x == 10 or y == 10
			if edge:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.95))
			elif inner:
				img.set_pixel(x, y, Color(0.75, 0.68, 0.5, 0.95))
			else:
				img.set_pixel(x, y, Color(0.02, 0.02, 0.04, 0.9))
	return img


static func button(state: int) -> Image:
	## 48x16 nine-patch (5px border). 0 normal, 1 hover, 2 pressed, 3 disabled.
	var p := _p(48, 16, 1010 + state)
	var base: Color = [Color(0.3, 0.28, 0.3), Color(0.4, 0.33, 0.27), Color(0.2, 0.18, 0.19), Color(0.22, 0.22, 0.23)][state]
	var trim: Color = [Color(0.72, 0.55, 0.22), Color(1.0, 0.82, 0.35), Color(0.55, 0.42, 0.18), Color(0.4, 0.4, 0.4)][state]
	_stone_rect(p, 0, 0, 48, 16, base, 1012, 2 if state != 2 else 1)
	for x in 48:
		p.img.set_pixel(x, 0, Color(0, 0, 0))
		p.img.set_pixel(x, 15, Color(0, 0, 0))
		p.img.set_pixel(x, 1, trim.lightened(0.2))
		p.img.set_pixel(x, 14, trim.darkened(0.4))
	for y in 16:
		p.img.set_pixel(0, y, Color(0, 0, 0))
		p.img.set_pixel(47, y, Color(0, 0, 0))
		if y > 0 and y < 15:
			p.img.set_pixel(1, y, trim)
			p.img.set_pixel(46, y, trim.darkened(0.35))
	if state == 1:
		for x in range(3, 45):
			p.img.set_pixel(x, 2, p.img.get_pixel(x, 2).lightened(0.25))
	return p.img


static func tab(on: bool) -> Image:
	var p := _p(40, 14, 1020 + int(on))
	var base := Color(0.32, 0.28, 0.26) if on else Color(0.17, 0.16, 0.17)
	var trim := Color(0.95, 0.78, 0.32) if on else Color(0.5, 0.42, 0.25)
	_stone_rect(p, 0, 0, 40, 14, base, 1022, 1)
	for x in 40:
		p.img.set_pixel(x, 0, trim)
	for y in 14:
		p.img.set_pixel(0, y, trim.darkened(0.1))
		p.img.set_pixel(39, y, trim.darkened(0.4))
	return p.img


static func slot(kind: String) -> Image:
	var p := _p(28, 28, 1030)
	_slot(p, 2, 2, 24, THEMES[kind])
	return p.img


static func bar_frame() -> Image:
	var img := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 12:
			var edge := x == 0 or y == 0 or x == 11 or y == 7
			img.set_pixel(x, y, Color(0, 0, 0, 1) if edge else Color(0.05, 0.05, 0.06, 1))
	return img


static func bar_fill(col: Color) -> Image:
	## Simple flat fill: one light line on top, one shade line at the bottom.
	var img := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		var c := col
		if y == 0:
			c = col.lightened(0.3)
		elif y >= 6:
			c = col.darkened(0.3)
		for x in 12:
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1))
	return img


static func grabber() -> Image:
	var p := _p(8, 12, 1040)
	p.flat_poly(PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(4, 12), Vector2(0, 8)]), Color(0.8, 0.62, 0.26), Vector3(-0.3, -0.4, 1))
	p.rim(0.4, 0.0)
	return p.img


static func check(on: bool) -> Image:
	var p := _p(10, 10, 1041)
	_slot(p, 2, 2, 6, THEMES["warrior"])
	if on:
		p.ball(5, 5, 2.4, 2.4, Color(1.0, 0.8, 0.3))
	return p.img


static func moon() -> Image:
	var p := _p(12, 12, 1050)
	p.ball(6, 6, 5, 5, Color(0.85, 0.9, 0.8))
	p.ball(8, 5, 4, 4.2, Color(0, 0, 0, 0))
	p.erase_ellipse(8.5, 5, 3.8, 4.2)
	return p.img


static func sun() -> Image:
	var p := Painter.new(14, 14, 1051)
	p.glow(7, 7, 7, Color(1.0, 0.7, 0.3), 1.0)
	p.ball(7, 7, 3.5, 3.5, Color(1.0, 0.9, 0.5))
	return p.img


static func beam() -> Image:
	var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var a := pow(float(y) / 63.0, 1.6)
		for x in 16:
			var u := 1.0 - absf(x - 7.5) / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, a * u * u))
	return img


# ============================================================================ boss arena

static func magic_circle() -> Image:
	## 256x256 emissive ritual circle for the boss arena floor (black = no glow).
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := Painter.new(256, 256, 1060)
	p.img = img
	var c := Vector2(128, 128)
	var g := Color(0.35, 1.0, 0.5)
	for r in [124.0, 116.0, 84.0, 40.0]:
		for i in 720:
			var a := float(i) / 720.0 * TAU
			p.put(int(c.x + cos(a) * r), int(c.y + sin(a) * r), g)
	for k in 7:
		var a0 := float(k) / 7.0 * TAU - PI * 0.5
		var a1 := float(k + 3) / 7.0 * TAU - PI * 0.5
		p.line(c + Vector2(cos(a0), sin(a0)) * 84, c + Vector2(cos(a1), sin(a1)) * 84, g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1061
	for k in 36:
		var a := float(k) / 36.0 * TAU
		var pc := c + Vector2(cos(a), sin(a)) * 100
		for s in 3:
			var o := Vector2(rng.randf_range(-3, 3), rng.randf_range(-4, 4))
			p.line(pc + o, pc + o + Vector2(rng.randf_range(-3, 3), rng.randf_range(-4, 4)), g)
	return img


static func sky_void() -> Image:
	## 2048x1024 equirectangular void sky with green/violet aurora for the boss arena.
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 1070
	n.frequency = 1.4
	n.fractal_octaves = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 1071
	for y in h:
		var v := float(y) / float(h)
		for x in w:
			var ang := float(x) / float(w) * TAU
			var c := Color(0.01, 0.015, 0.02)
			if v < 0.55:
				var aur := n.get_noise_3d(cos(ang) * 1.5, sin(ang) * 1.5, v * 4.0) * 0.5 + 0.5
				var band := smoothstep(0.1, 0.3, v) * (1.0 - smoothstep(0.35, 0.52, v))
				var a := clampf((aur - 0.45) * 2.5, 0.0, 1.0) * band
				c = c.lerp(Color(0.1, 0.55, 0.3), a * 0.7).lerp(Color(0.35, 0.12, 0.5), a * a * 0.5)
				if rng.randf() < 0.0015 * (1.0 - v):
					c = Color(0.8, 1.0, 0.85) * rng.randf_range(0.4, 1.0)
			else:
				c = Color(0.02, 0.05, 0.03).lerp(Color(0.0, 0.0, 0.0), (v - 0.55) * 2.0)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


# ============================================================================ cursor

static func cursor(hover: bool) -> Image:
	## 20x20 art armoured gauntlet pointing up-left; hotspot at the fingertip (2, 2).
	var p := _p(20, 20, 1080 + int(hover))
	var steel := Color(0.62, 0.63, 0.68)
	var gold := Color(0.9, 0.7, 0.28) if not hover else Color(1.0, 0.85, 0.4)
	# cuff
	p.flat_poly(PackedVector2Array([Vector2(12, 15.5), Vector2(15.5, 12), Vector2(20, 16.5), Vector2(16.5, 20)]), gold.darkened(0.15), Vector3(-0.3, -0.5, 1))
	p.line(Vector2(12.5, 16), Vector2(16, 12.5), gold.lightened(0.25))
	# back of the hand + curled fingers + thumb
	p.ball(11.0, 11.0, 4.6, 4.0, steel)
	for c in [Vector2(9.5, 14.5), Vector2(11.8, 15.2), Vector2(14.0, 14.2)]:
		p.ball(c.x, c.y, 1.7, 1.5, steel.darkened(0.1))
	p.capsule(Vector2(8.5, 11.5), Vector2(5.5, 13.0), 1.4, 1.2, steel)
	# extended index finger with gold knuckle plates
	p.capsule(Vector2(9.5, 9.5), Vector2(2.6, 2.6), 2.0, 1.4, steel)
	for k in [0.35, 0.65]:
		var c := Vector2(9.5, 9.5).lerp(Vector2(2.6, 2.6), k)
		p.capsule(c + Vector2(-1.2, 1.2), c + Vector2(1.2, -1.2), 0.6, 0.6, gold)
	p.ball(10.5, 10.5, 1.2, 1.2, gold)
	p.outline(Color(0.04, 0.03, 0.03))
	if hover:
		p.glow(3.0, 3.0, 4.0, Color(1.0, 0.85, 0.4), 0.9)
	return p.img


static func sky_variant(seed_value: int, base: Color, aur_a: Color, aur_b: Color, ground: Color, stars: float) -> Image:
	## Equirectangular boss-arena sky: tinted aurora/haze bands over a dark base (2048x1024).
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 1.3
	n.fractal_octaves = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in h:
		var v := float(y) / float(h)
		for x in w:
			var ang := float(x) / float(w) * TAU
			var c := base
			if v < 0.55:
				var aur := n.get_noise_3d(cos(ang) * 1.5, sin(ang) * 1.5, v * 4.0) * 0.5 + 0.5
				var band := smoothstep(0.08, 0.3, v) * (1.0 - smoothstep(0.38, 0.54, v))
				var a := clampf((aur - 0.42) * 2.4, 0.0, 1.0) * band
				c = base.lerp(aur_a, a * 0.75).lerp(aur_b, a * a * 0.5)
				c = c.lerp(ground, smoothstep(0.4, 0.55, v) * 0.6)
				if rng.randf() < stars * (1.0 - v):
					c = Color(0.9, 0.9, 0.95) * rng.randf_range(0.4, 1.0)
			else:
				c = ground.lerp(Color(0, 0, 0), clampf((v - 0.55) * 2.2, 0.0, 1.0))
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img
