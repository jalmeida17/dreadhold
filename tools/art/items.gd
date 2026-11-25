extends RefCounted
## Props, pickups, effects, first-person weapons and HUD portraits.

const Painter := preload("res://tools/art/painter.gd")
const GOLD := Color(0.88, 0.67, 0.2)
const IRON := Color(0.42, 0.42, 0.48)
const BONE := Color(0.86, 0.81, 0.64)
const STEEL := Color(0.7, 0.72, 0.78)


# =============================================================================== fire helpers

static func flame(p: Painter, cx: float, base_y: float, height: float, half_w: float, phase: float, palette: Array = []) -> void:
	if palette.is_empty():
		palette = [Color(0.78, 0.18, 0.04), Color(1.0, 0.5, 0.08), Color(1.0, 0.85, 0.35), Color(1.0, 0.98, 0.85)]
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.25
	for y in range(int(base_y - height) - 1, int(base_y) + 2):
		for x in range(int(cx - half_w * 2.0), int(cx + half_w * 2.0) + 1):
			var v := (base_y - (y + 0.5)) / height
			if v < -0.12 or v > 1.0:
				continue
			var vv := clampf(v, 0.0, 1.0)
			var radius := half_w * pow(1.0 - vv, 0.8) * (0.6 + 0.4 * sin(minf(vv * 4.0 + 0.6, PI * 0.5)))
			if v < 0.0:
				radius = half_w * (1.0 + v * 6.0)
			var shift := sin(vv * 5.0 + phase) * vv * half_w * 0.5 + n.get_noise_2d(x * 1.0, y + phase * 9.0) * vv * 1.5
			var d := absf(x + 0.5 - cx - shift)
			if radius <= 0.1 or d > radius:
				continue
			var inten := (1.0 - d / radius) * (1.0 - vv * 0.55) + n.get_noise_2d(x * 2.0 + phase * 5.0, y * 2.0) * 0.15
			var c: Color
			if inten > 0.72:
				c = palette[3]
			elif inten > 0.48:
				c = palette[2]
			elif inten > 0.22:
				c = palette[1]
			else:
				c = palette[0]
			p.put(x, y, c)


static func orb(p: Painter, cx: float, cy: float, r: float, phase: float, palette: Array) -> void:
	## Flickering ball of energy (fire / shadow / soul).
	var n := FastNoiseLite.new()
	n.seed = 11
	n.frequency = 0.9
	for y in range(int(cy - r * 1.5), int(cy + r * 1.5) + 1):
		for x in range(int(cx - r * 1.5), int(cx + r * 1.5) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy)
			var ang := d.angle()
			var rr := r * (1.0 + 0.3 * n.get_noise_2d(cos(ang) * 2.0 + phase, sin(ang) * 2.0 + phase * 0.7))
			var t := d.length() / rr
			if t > 1.0:
				continue
			var c: Color
			if t < 0.35:
				c = palette[3]
			elif t < 0.6:
				c = palette[2]
			elif t < 0.82:
				c = palette[1]
			else:
				c = palette[0]
			p.put(x, y, c)


const FIRE := [Color(0.78, 0.18, 0.04), Color(1.0, 0.5, 0.08), Color(1.0, 0.85, 0.35), Color(1.0, 0.98, 0.85)]
const SHADOW := [Color(0.18, 0.04, 0.3), Color(0.45, 0.12, 0.7), Color(0.75, 0.45, 1.0), Color(1.0, 0.9, 1.0)]
const SOUL := [Color(0.05, 0.3, 0.12), Color(0.2, 0.75, 0.3), Color(0.55, 1.0, 0.55), Color(0.92, 1.0, 0.9)]
const FROST := [Color(0.1, 0.35, 0.7), Color(0.35, 0.7, 1.0), Color(0.7, 0.92, 1.0), Color(0.97, 1.0, 1.0)]


# =============================================================================== props

static func torch_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(16, 32, 40 + f)
		p.capsule(Vector2(8, 30), Vector2(8, 22), 1.2, 1.2, IRON)
		p.capsule(Vector2(4, 22), Vector2(12, 22), 1.0, 1.0, IRON)
		p.capsule(Vector2(4, 22), Vector2(5, 16), 0.9, 0.9, IRON)
		p.capsule(Vector2(12, 22), Vector2(11, 16), 0.9, 0.9, IRON)
		p.capsule(Vector2(8, 24), Vector2(8, 15), 1.8, 2.0, Color(0.38, 0.22, 0.12))
		p.capsule(Vector2(6, 16), Vector2(10, 16), 1.2, 1.2, Color(0.25, 0.15, 0.1))
		p.outline()
		flame(p, 8.0 + (f % 2) * 0.5 - 0.25, 15.5, 13.0 + (f % 3), 3.6, f * 1.7)
		p.glow(8, 10, 8, Color(1.0, 0.55, 0.15), 0.35)
		frames.append(p.img)
	return Painter.strip(frames)


static func brazier_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(32, 48, 60 + f)
		for side in [-1.0, 1.0]:
			p.capsule(Vector2(16 + side * 3, 30), Vector2(16 + side * 9, 46), 1.3, 1.3, IRON)
		p.capsule(Vector2(16, 30), Vector2(16, 46), 1.3, 1.3, IRON.darkened(0.2))
		p.ball(16, 28, 12, 5, IRON)
		p.capsule(Vector2(4, 26), Vector2(28, 26), 1.3, 1.3, GOLD.darkened(0.3))
		p.ellipse(16, 25, 10, 2.2, Color(0.95, 0.45, 0.1))
		p.outline()
		flame(p, 13 + (f % 2), 26, 17 + (f % 3) * 1.5, 5.0, f * 1.3)
		flame(p, 19 - (f % 2), 26, 14 + ((f + 1) % 3) * 1.5, 4.0, f * 1.9 + 2.0)
		p.glow(16, 18, 16, Color(1.0, 0.5, 0.12), 0.3)
		frames.append(p.img)
	return Painter.strip(frames)


static func tree() -> Image:
	var p := Painter.new(64, 96, 77)
	var bark := Color(0.24, 0.18, 0.16)
	p.capsule(Vector2(32, 94), Vector2(30, 60), 6.5, 4.5, bark, 0.15)
	p.capsule(Vector2(22, 95), Vector2(30, 86), 2.5, 2.0, bark)
	p.capsule(Vector2(42, 95), Vector2(33, 86), 2.5, 2.0, bark)
	var branches := [
		[Vector2(30, 62), Vector2(16, 40), 4.0], [Vector2(16, 40), Vector2(8, 22), 2.2], [Vector2(16, 40), Vector2(4, 38), 1.5],
		[Vector2(30, 62), Vector2(40, 36), 3.6], [Vector2(40, 36), Vector2(52, 18), 2.0], [Vector2(40, 36), Vector2(56, 34), 1.5],
		[Vector2(40, 36), Vector2(36, 12), 1.6], [Vector2(8, 22), Vector2(12, 10), 1.0], [Vector2(52, 18), Vector2(60, 8), 1.0],
		[Vector2(30, 62), Vector2(26, 30), 2.0], [Vector2(26, 30), Vector2(22, 14), 1.2],
	]
	for b in branches:
		p.capsule(b[0], b[1], b[2], maxf(float(b[2]) * 0.55, 0.8), bark)
	# hanging rope + crow-like dark rags
	p.line(Vector2(16, 41), Vector2(16, 54), Color(0.5, 0.42, 0.28))
	p.ball(16, 56, 2.5, 2.0, Color(0.5, 0.42, 0.28))
	p.outline()
	return p.img


static func graves_sheet() -> Image:
	var frames: Array = []
	var stone := Color(0.5, 0.5, 0.53)
	var moss := Color(0.3, 0.42, 0.16)
	for v in 3:
		var p := Painter.new(24, 32, 90 + v)
		p.ellipse(12, 30, 10, 2, Color(0.12, 0.1, 0.08))
		if v == 0:
			p.flat_poly(PackedVector2Array([Vector2(10, 4), Vector2(14, 4), Vector2(14, 30), Vector2(10, 30)]), stone, Vector3(-0.2, -0.2, 1))
			p.flat_poly(PackedVector2Array([Vector2(4, 10), Vector2(20, 10), Vector2(20, 14), Vector2(4, 14)]), stone, Vector3(0, -0.5, 1))
		elif v == 1:
			p.cyl_poly(PackedVector2Array([Vector2(4, 30), Vector2(4, 12), Vector2(7, 7), Vector2(12, 5), Vector2(17, 7), Vector2(20, 12), Vector2(20, 30)]), stone, 12, 9)
			p.line(Vector2(8, 14), Vector2(16, 14), stone.darkened(0.5))
			p.line(Vector2(9, 17), Vector2(15, 17), stone.darkened(0.5))
			p.line(Vector2(12, 11), Vector2(12, 22), stone.darkened(0.5))
		else:
			p.flat_poly(PackedVector2Array([Vector2(6, 30), Vector2(7, 9), Vector2(12, 3), Vector2(15, 9), Vector2(17, 16), Vector2(18, 30)]), stone, Vector3(-0.3, -0.3, 1))
			p.line(Vector2(9, 12), Vector2(15, 22), stone.darkened(0.55))
		for k in 6:
			p.put(5 + k * 3, 28 - (k % 2), moss)
			p.put(6 + k * 3, 27, moss.lightened(0.2))
		p.outline()
		frames.append(p.img)
	return Painter.strip(frames)


static func bones_prop() -> Image:
	var p := Painter.new(32, 16, 120)
	p.ellipse(16, 13, 14, 2.5, Color(0.1, 0.07, 0.08))
	for b in [[Vector2(4, 13), Vector2(14, 11)], [Vector2(18, 13), Vector2(28, 14)], [Vector2(10, 14), Vector2(22, 12)]]:
		p.capsule(b[0], b[1], 1.1, 1.0, BONE)
		p.ball(b[0].x, b[0].y, 1.5, 1.5, BONE)
		p.ball(b[1].x, b[1].y, 1.5, 1.5, BONE)
	p.ball(24, 10, 3.5, 3.2, BONE)
	p.ball(23, 10, 1.0, 1.2, Color(0.1, 0.06, 0.08))
	p.ball(26, 10, 1.0, 1.2, Color(0.1, 0.06, 0.08))
	p.outline()
	return p.img


static func barrel() -> Image:
	var p := Painter.new(24, 32, 130)
	var wood := Color(0.45, 0.28, 0.15)
	p.cyl_poly(PackedVector2Array([Vector2(5, 3), Vector2(19, 3), Vector2(21, 10), Vector2(21, 22), Vector2(19, 30), Vector2(5, 30), Vector2(3, 22), Vector2(3, 10)]), wood, 12, 9.5)
	for k in 4:
		p.line(Vector2(7 + k * 3.5, 4), Vector2(7 + k * 3.5, 29), wood.darkened(0.45))
	for by in [7, 25]:
		p.capsule(Vector2(4, by), Vector2(20, by), 1.2, 1.2, IRON)
	p.ellipse(12, 3, 7, 1.6, wood.darkened(0.3))
	p.outline()
	return p.img


static func statue() -> Image:
	## Heroic knight statue on a plinth, sword point-down.
	var p := Painter.new(48, 96, 140)
	var stone := Color(0.56, 0.55, 0.58)
	p.flat_poly(PackedVector2Array([Vector2(6, 78), Vector2(42, 78), Vector2(44, 94), Vector2(4, 94)]), stone.darkened(0.1), Vector3(0, -0.2, 1))
	p.flat_poly(PackedVector2Array([Vector2(4, 74), Vector2(44, 74), Vector2(44, 79), Vector2(4, 79)]), stone, Vector3(0, -1, 0.6))
	for side in [-1.0, 1.0]:
		p.capsule(Vector2(24 + side * 5, 54), Vector2(24 + side * 6, 73), 3.6, 3.0, stone)
	p.cyl_poly(PackedVector2Array([Vector2(13, 30), Vector2(35, 30), Vector2(33, 58), Vector2(15, 58)]), stone, 24, 12)
	p.cyl_poly(PackedVector2Array([Vector2(12, 26), Vector2(36, 26), Vector2(40, 62), Vector2(34, 72), Vector2(14, 72), Vector2(8, 62)]), stone.darkened(0.15), 24, 16)
	p.cyl_poly(PackedVector2Array([Vector2(14, 30), Vector2(34, 30), Vector2(32, 56), Vector2(16, 56)]), stone, 24, 11)
	p.ball(12, 29, 7, 5.5, stone)
	p.ball(36, 29, 7, 5.5, stone)
	p.capsule(Vector2(12, 32), Vector2(20, 46), 2.8, 2.5, stone)
	p.capsule(Vector2(36, 32), Vector2(28, 46), 2.8, 2.5, stone)
	p.blade(Vector2(24, 44), Vector2(24, 74), 2.6, 0.6, stone.lightened(0.1))
	p.capsule(Vector2(17, 44), Vector2(31, 44), 1.4, 1.4, stone)
	p.capsule(Vector2(24, 36), Vector2(24, 44), 1.2, 1.2, stone)
	p.ball(24, 46, 3.5, 2.5, stone)
	p.ball(24, 18, 6, 7, stone)
	p.ball(24, 15, 6.6, 5, stone.lightened(0.05))
	p.rect(19, 17, 10, 1, stone.darkened(0.6))
	p.poly(PackedVector2Array([Vector2(22, 9), Vector2(26, 9), Vector2(24, 2)]), stone)
	var moss := Color(0.3, 0.42, 0.16)
	for k in 14:
		p.put(6 + (k * 7) % 36, 92 - (k * 3) % 8, moss)
	p.outline()
	return p.img


static func altar_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(48, 40, 150 + f)
		var stone := Color(0.3, 0.3, 0.38)
		p.flat_poly(PackedVector2Array([Vector2(4, 18), Vector2(44, 18), Vector2(40, 38), Vector2(8, 38)]), stone, Vector3(0, -0.1, 1))
		p.flat_poly(PackedVector2Array([Vector2(2, 14), Vector2(46, 14), Vector2(46, 19), Vector2(2, 19)]), stone.lightened(0.15), Vector3(0, -1, 0.5))
		for k in 3:
			var rx := 14 + k * 10
			p.line(Vector2(rx, 24), Vector2(rx, 34), Color(0.45, 1.0, 0.5))
			p.line(Vector2(rx - 3, 27), Vector2(rx + 3, 31), Color(0.45, 1.0, 0.5))
		for cx in [8, 40]:
			p.capsule(Vector2(cx, 13), Vector2(cx, 8), 1.4, 1.4, BONE)
		p.ball(24, 11, 4.0, 3.5, BONE)
		p.outline()
		for cx in [8, 40]:
			flame(p, cx, 7.5, 5 + (f + cx) % 2, 1.4, f * 2.1 + cx)
		var pulse := 0.6 + 0.25 * sin(f * PI * 0.5)
		for k in 3:
			p.glow(14 + k * 10, 29, 6, Color(0.4, 1.0, 0.45), pulse)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== pickups

static func gold_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(16, 16, 200 + f)
		for c in [Vector2(5, 12), Vector2(11, 12), Vector2(8, 10), Vector2(6, 8), Vector2(10, 7)]:
			p.ball(c.x, c.y, 3.2, 2.2, GOLD)
			p.put(int(c.x), int(c.y), GOLD.lightened(0.5))
		p.outline()
		var sp: Vector2 = [Vector2(10, 6), Vector2(5, 9), Vector2(12, 11), Vector2(7, 12)][f]
		p.put(int(sp.x), int(sp.y), Color(1, 1, 0.9))
		p.put(int(sp.x) - 1, int(sp.y), Color(1, 0.95, 0.7, 0.7))
		p.put(int(sp.x) + 1, int(sp.y), Color(1, 0.95, 0.7, 0.7))
		p.put(int(sp.x), int(sp.y) - 1, Color(1, 0.95, 0.7, 0.7))
		p.put(int(sp.x), int(sp.y) + 1, Color(1, 0.95, 0.7, 0.7))
		frames.append(p.img)
	return Painter.strip(frames)


static func potion(liquid: Color) -> Image:
	var p := Painter.new(16, 20, 210)
	p.ball(8, 13, 6, 6, Color(0.55, 0.65, 0.7, 1.0))
	p.ball(8, 14, 5, 4.5, liquid)
	p.rect(6, 3, 4, 5, Color(0.55, 0.65, 0.7))
	p.rect(6, 1, 4, 3, Color(0.45, 0.3, 0.18))
	p.capsule(Vector2(5, 7), Vector2(11, 7), 0.8, 0.8, GOLD)
	p.outline()
	p.put(6, 11, Color(1, 1, 1, 0.9))
	p.put(5, 12, Color(1, 1, 1, 0.6))
	p.glow(8, 14, 7, liquid, 0.35)
	return p.img


# =============================================================================== effects

static func orb_sheet(size: int, frames_n: int, palette: Array, r: float, glow_col: Color) -> Image:
	var frames: Array = []
	for f in frames_n:
		var p := Painter.new(size, size, 300 + f)
		var c := size * 0.5
		p.glow(c, c, size * 0.5, glow_col, 0.7)
		orb(p, c, c, r, f * 1.6, palette)
		frames.append(p.img)
	return Painter.strip(frames)


static func explosion_sheet() -> Image:
	var frames: Array = []
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.12
	for f in 6:
		var p := Painter.new(48, 48, 320 + f)
		var t := float(f) / 5.0
		var r := 6.0 + t * 17.0
		var fire_amt := 1.0 - t * 1.1
		for y in 48:
			for x in 48:
				var d := Vector2(x + 0.5 - 24, y + 0.5 - 24)
				var nv := n.get_noise_3d(x, y, f * 9.0) * 0.5 + 0.5
				var rr := r * (0.75 + nv * 0.5)
				var q := d.length() / rr
				if q > 1.0:
					continue
				var c: Color
				var inten := ((1.0 - q) * 1.15 + nv * 0.3) * fire_amt
				if t > 0.5 and nv < 0.38 + t * 0.2 and q > 0.45:
					continue
				if inten > 0.75:
					c = FIRE[3]
				elif inten > 0.5:
					c = FIRE[2]
				elif inten > 0.28:
					c = FIRE[1]
				elif inten > 0.12:
					c = FIRE[0]
				else:
					var smoke := Color(0.16, 0.13, 0.13, clampf(1.0 - t * 0.8, 0.2, 0.9))
					if nv > 0.6:
						smoke = smoke.lightened(0.1)
					c = smoke
				p.put(x, y, c)
		frames.append(p.img)
	return Painter.strip(frames)


static func frost_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(32, 32, 340 + f)
		var t := float(f) / 3.0
		p.glow(16, 16, 10 + t * 6, FROST[1], 0.9 - t * 0.5)
		for k in 8:
			var a := float(k) / 8.0 * TAU + f * 0.2
			var d := Vector2(cos(a), sin(a))
			var r0 := 3.0 + t * 6.0
			var r1 := r0 + 6.0 - t * 2.0
			var nn := Vector2(-d.y, d.x)
			p.poly(PackedVector2Array([Vector2(16, 16) + d * r0 + nn * 1.6, Vector2(16, 16) + d * r1, Vector2(16, 16) + d * r0 - nn * 1.6]), FROST[2] if k % 2 == 0 else FROST[3])
		frames.append(p.img)
	return Painter.strip(frames)


static func burst_sheet(size: int, base: Color, seed_value: int, gravity: bool) -> Image:
	## Particle spray (blood, dust): droplets flying out then falling.
	var frames: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var parts: Array = []
	for i in 16:
		var a := rng.randf() * TAU
		parts.append([Vector2(cos(a), sin(a) - 0.4) * rng.randf_range(2.0, 4.5), rng.randf_range(0.6, 1.4)])
	for f in 4:
		var p := Painter.new(size, size, seed_value + f)
		var t := float(f + 1)
		for pr in parts:
			var v: Vector2 = pr[0]
			var pos := Vector2(size * 0.5, size * 0.5) + v * t * 0.9
			if gravity:
				pos.y += t * t * 0.45
			var r: float = pr[1] * (1.2 - f * 0.18)
			if r <= 0.2:
				continue
			var c := base.darkened(rng.randf() * 0.3)
			if not gravity:
				c.a = 1.0 - f * 0.22
			p.ellipse(pos.x, pos.y, r, r, c)
		frames.append(p.img)
	return Painter.strip(frames)


static func portal_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(48, 48, 360 + f)
		p.glow(24, 24, 22, SOUL[1], 0.6)
		for arm in 4:
			for k in 30:
				var t := float(k) / 29.0
				var a := float(arm) / 4.0 * TAU + t * 3.2 + f * 0.45
				var r := 4.0 + t * 17.0
				var pos := Vector2(24 + cos(a) * r, 24 + sin(a) * r * 0.9)
				var col: Color = SOUL[3] if t < 0.3 else (SOUL[2] if t < 0.65 else SOUL[1])
				p.ellipse(pos.x, pos.y, 1.6 - t * 0.8, 1.6 - t * 0.8, col)
		p.glow(24, 24, 7, SOUL[3], 0.9)
		frames.append(p.img)
	return Painter.strip(frames)


static func ring_decal() -> Image:
	var p := Painter.new(64, 64, 370)
	for y in 64:
		for x in 64:
			var d := Vector2(x + 0.5 - 32, y + 0.5 - 32).length() / 31.0
			if d > 1.0:
				continue
			var a := pow(smoothstep(0.55, 0.95, d), 2.0) * (1.0 - smoothstep(0.95, 1.0, d))
			if a > 0.02:
				p.put(x, y, Color(0.75, 0.95, 1.0, a))
	return p.img


# =============================================================================== first-person weapons (128x96)

static func _gauntlet(p: Painter, grip: Vector2, d: Vector2, steel: Color, trim: Color) -> void:
	var n := Vector2(-d.y, d.x)
	p.capsule(grip + d * -4 + Vector2(10, 22), grip + d * -2, 11, 8, steel.darkened(0.15))
	p.ball(grip.x, grip.y, 9, 8, steel)
	for k in 4:
		var fp := grip + d * (-5.0 + k * 3.4) + n * 6.0
		p.capsule(fp - n * 8.0, fp, 2.4, 2.2, steel.lightened(0.05))
	p.capsule(grip + d * -7 + n * 9, grip + d * 6 + n * 9, 1.5, 1.5, trim)
	p.ball(grip.x - n.x * 4, grip.y - n.y * 4, 3.0, 3.0, trim)


static func axe_frames() -> Image:
	var poses := [
		[Vector2(100, 92), Vector2(76, 28)],
		[Vector2(108, 86), Vector2(118, 14)],
		[Vector2(62, 98), Vector2(18, 44)],
		[Vector2(34, 104), Vector2(-4, 84)],
	]
	var frames: Array = []
	for i in poses.size():
		var p := Painter.new(128, 96, 400 + i)
		var grip: Vector2 = poses[i][0]
		var head: Vector2 = poses[i][1]
		var d := (head - grip).normalized()
		var n := Vector2(-d.y, d.x)
		if n.x > 0.0:
			n = -n
		if i == 2:
			for k in 14:
				var t := float(k) / 13.0
				var a := lerpf(-0.6, 2.5, t)
				var pc := Vector2(70, 110) + Vector2(cos(a + PI), sin(a + PI)) * 82.0
				p.glow(pc.x, pc.y, 10.0, Color(0.85, 0.85, 1.0), 0.22)
		var haft_end := head + d * 10.0
		var wood := Color(0.42, 0.25, 0.13)
		p.capsule(grip - d * 30.0, haft_end, 3.6, 3.0, wood)
		for k in 5:
			var wp := grip + d * (10.0 + k * 5.0)
			p.capsule(wp - n * 3.6, wp + n * 3.6 + d * 2.0, 1.0, 1.0, Color(0.25, 0.14, 0.08))
		# blade (crescent) on the n side
		var blade := PackedVector2Array([
			head + d * 7 + n * 2.5, head + d * 17 + n * 16, head + d * 10 + n * 25, head + n * 28,
			head - d * 12 + n * 25, head - d * 20 + n * 15, head - d * 8 + n * 2.5])
		p.flat_poly(blade, STEEL, Vector3(-0.4, -0.6, 1.0))
		var edge := PackedVector2Array([head + d * 17 + n * 16, head + d * 10 + n * 25, head + n * 28, head - d * 12 + n * 25, head - d * 20 + n * 15,
			head - d * 16 + n * 15, head - d * 9 + n * 21, head + n * 24, head + d * 8 + n * 21, head + d * 14 + n * 16])
		p.flat_poly(edge, STEEL.lightened(0.25), Vector3(-0.6, -0.8, 0.6))
		# gold inlay
		p.line(head + d * 6 + n * 8, head - d * 8 + n * 8, GOLD, 2.0)
		p.line(head + n * 6, head + n * 16, GOLD, 2.0)
		# back spike
		p.flat_poly(PackedVector2Array([head + d * 5 - n * 2, head - n * 16, head - d * 5 - n * 2]), STEEL.darkened(0.1), Vector3(0.2, -0.8, 0.8))
		p.ball(head.x, head.y, 4.5, 4.5, IRON)
		p.ball(head.x, head.y, 2.0, 2.0, GOLD)
		_gauntlet(p, grip, d, Color(0.55, 0.56, 0.62), GOLD)
		p.outline()
		frames.append(p.img)
	return Painter.strip(frames)


static func staff_frames() -> Image:
	var poses := [
		[Vector2(98, 96), Vector2(84, 24), FIRE, 0.6],
		[Vector2(86, 94), Vector2(66, 14), FIRE, 1.4],
		[Vector2(94, 96), Vector2(80, 20), FIRE, 0.4],
		[Vector2(86, 94), Vector2(66, 14), FROST, 1.4],
	]
	var frames: Array = []
	for i in poses.size():
		var p := Painter.new(128, 96, 420 + i)
		var grip: Vector2 = poses[i][0]
		var top: Vector2 = poses[i][1]
		var pal: Array = poses[i][2]
		var power: float = poses[i][3]
		var d := (top - grip).normalized()
		var n := Vector2(-d.y, d.x)
		var wood := Color(0.36, 0.22, 0.14)
		# gnarled shaft
		var prev := grip + d * -30.0
		for k in 10:
			var t := float(k + 1) / 10.0
			var pt := (grip + d * -30.0).lerp(top + d * -6.0, t) + n * sin(t * 9.0) * 1.6
			p.capsule(prev, pt, 3.4 - t * 0.6, 3.2 - t * 0.6, wood)
			prev = pt
		# claw head holding the gem
		for side in [-1.0, 1.0]:
			var c0: Vector2 = top - d * 8.0
			var c1: Vector2 = top + n * side * 8.0 - d * 2.0
			var c2: Vector2 = top + n * side * 4.0 + d * 7.0
			p.capsule(c0, c1, 2.2, 1.8, wood)
			p.capsule(c1, c2, 1.8, 1.0, wood)
		p.capsule(top - d * 12.0 - n * 4.0, top - d * 12.0 + n * 4.0, 1.6, 1.6, GOLD)
		# sleeve + hand
		var sleeve := Color(0.2, 0.18, 0.45)
		p.capsule(grip + Vector2(14, 30), grip + d * -4.0, 13, 9, sleeve)
		p.capsule(grip + Vector2(4, 12), grip + Vector2(20, 18), 1.6, 1.6, GOLD)
		p.ball(grip.x, grip.y, 6.5, 6, Color(0.78, 0.62, 0.5))
		for k in 4:
			var fp := grip + d * (-4.0 + k * 2.8) + n * 4.0
			p.capsule(fp - n * 6.0, fp, 1.9, 1.7, Color(0.78, 0.62, 0.5))
		p.outline()
		p.glow(top.x, top.y, 14.0 * power, pal[1], 0.6 * power)
		orb(p, top.x, top.y, 5.0 + power * 1.5, float(i) * 1.3, pal)
		if power > 1.0:
			for k in 6:
				var a := float(k) / 6.0 * TAU + i
				p.glow(top.x + cos(a) * 12, top.y + sin(a) * 12, 3.0, pal[2], 0.9)
		frames.append(p.img)
	return Painter.strip(frames)


static func bow_frames() -> Image:
	var wood := Color(0.32, 0.19, 0.12)
	var glove := Color(0.36, 0.24, 0.16)
	var frames: Array = []
	for i in 3:
		var p := Painter.new(128, 96, 440 + i)
		var grip := Vector2(46, 62)
		var top_tip := Vector2(60, 2)
		var bot_tip := Vector2(62, 118)
		var pull := Vector2(56, 60)
		if i == 1:
			pull = Vector2(104, 70)
			top_tip = Vector2(64, 6)
			bot_tip = Vector2(66, 114)
		# limbs (curved), drawn as segments of an arc bulging left
		var prev := top_tip
		for k in 16:
			var t := float(k + 1) / 16.0
			var pt := top_tip.lerp(bot_tip, t) + Vector2(-sin(t * PI) * (22.0 if i == 1 else 18.0), 0)
			var thick := 2.0 + sin(t * PI) * 2.6
			p.capsule(prev, pt, thick, thick, wood)
			prev = pt
		p.ball(top_tip.x, top_tip.y, 2.4, 2.4, GOLD)
		# string
		var sc := Color(0.9, 0.88, 0.78)
		if i == 2:
			p.line(top_tip, bot_tip, sc)
			p.line(top_tip + Vector2(1, 0), bot_tip + Vector2(1, 0), Color(0.9, 0.88, 0.78, 0.4))
		else:
			p.line(top_tip, pull, sc)
			p.line(pull, bot_tip, sc)
		# arrow
		if i < 2:
			var tip := Vector2(22, 60) if i == 1 else Vector2(28, 58)
			p.capsule(pull, tip, 1.1, 1.0, Color(0.6, 0.45, 0.28))
			p.flat_poly(PackedVector2Array([tip + Vector2(2, -3), tip + Vector2(-6, 0), tip + Vector2(2, 3)]), STEEL, Vector3(-0.3, -0.6, 1))
			for k in 2:
				var fp := pull + (tip - pull).normalized() * (4.0 + k * 3.0)
				p.line(fp, fp + Vector2(3, -4), Color(0.75, 0.15, 0.12))
				p.line(fp, fp + Vector2(3, 4), Color(0.6, 0.1, 0.1))
		# left hand on grip
		var gp := grip + Vector2(-16, 0) + Vector2(0 if i != 1 else -2, 0)
		p.capsule(gp + Vector2(-30, 40), gp, 9, 6.5, Color(0.25, 0.3, 0.18))
		p.ball(gp.x, gp.y, 6.5, 7.5, glove)
		for k in 4:
			p.capsule(gp + Vector2(2, -6 + k * 4), gp + Vector2(7, -5 + k * 4), 1.8, 1.8, glove.lightened(0.08))
		p.capsule(gp + Vector2(-4, 6), gp + Vector2(4, 6), 1.2, 1.2, GOLD)
		# right hand pulling
		var rh := pull + Vector2(6, 4)
		if i == 2:
			rh = Vector2(116, 84)
		p.capsule(rh + Vector2(26, 34), rh, 9, 6.5, Color(0.25, 0.3, 0.18))
		p.ball(rh.x, rh.y, 6.0, 6.5, glove)
		p.outline()
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== portraits (40x40, 4 frames: ok / hurt / critical / power)

static func _portrait_bg(p: Painter, col: Color) -> void:
	for y in 40:
		for x in 40:
			var d := Vector2(x - 20, y - 16).length() / 30.0
			p.img.set_pixel(x, y, col.darkened(clampf(d, 0.0, 1.0) * 0.8))


static func _blood_marks(p: Painter, level: int) -> void:
	if level >= 1:
		p.line(Vector2(13, 13), Vector2(15, 22), Color(0.6, 0.05, 0.05), 1.5)
		p.put(15, 23, Color(0.5, 0.03, 0.04))
	if level >= 2:
		p.line(Vector2(25, 10), Vector2(27, 26), Color(0.55, 0.04, 0.05), 2.0)
		p.ellipse(22, 30, 3, 1.5, Color(0.5, 0.04, 0.04))
		p.line(Vector2(10, 18), Vector2(17, 16), Color(0.55, 0.04, 0.05))


static func portrait_sheet(kind: String) -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(40, 40, 500 + f)
		p.dither = 0.4
		var skin := Color(0.82, 0.6, 0.46)
		var tilt := 1.0 if f == 1 else 0.0
		match kind:
			"warrior":
				_portrait_bg(p, Color(0.35, 0.1, 0.08))
				p.ball(20 + tilt, 21, 10, 12, skin)
				# beard
				p.cyl_poly(PackedVector2Array([Vector2(10 + tilt, 22), Vector2(30 + tilt, 22), Vector2(28 + tilt, 34), Vector2(20 + tilt, 40), Vector2(12 + tilt, 34)]), Color(0.55, 0.28, 0.12), 20 + tilt, 11)
				var mouth_open := f == 3 or f == 2
				p.ellipse(20 + tilt, 29, 4 if mouth_open else 3.5, 2.2 if mouth_open else 0.8, Color(0.22, 0.05, 0.05))
				if mouth_open:
					p.rect(17 + tilt, 28, 6, 1, Color(0.9, 0.88, 0.8))
				# helm
				p.ball(20 + tilt, 12, 12, 9, Color(0.5, 0.52, 0.58))
				p.rect(7 + tilt, 14, 26, 4, Color(0.42, 0.44, 0.5))
				p.capsule(Vector2(8 + tilt, 16), Vector2(32 + tilt, 16), 1.4, 1.4, GOLD)
				p.capsule(Vector2(20 + tilt, 4), Vector2(20 + tilt, 22), 1.6, 1.4, Color(0.48, 0.5, 0.56))
				for side in [-1.0, 1.0]:
					var h0 := Vector2(20 + tilt + side * 10, 10)
					p.capsule(h0, h0 + Vector2(side * 6, -4), 2.6, 2.0, BONE)
					p.capsule(h0 + Vector2(side * 6, -4), h0 + Vector2(side * 7, -10), 2.0, 0.8, BONE)
			"mage":
				_portrait_bg(p, Color(0.1, 0.12, 0.35))
				p.ball(20 + tilt, 20, 12, 15, Color(0.2, 0.2, 0.5))
				p.ellipse(20 + tilt, 21, 9.5, 11.5, GOLD.darkened(0.1))
				p.ball(20 + tilt, 21, 8, 10, skin.darkened(0.05))
				p.cyl_poly(PackedVector2Array([Vector2(12 + tilt, 23), Vector2(28 + tilt, 23), Vector2(26 + tilt, 36), Vector2(20 + tilt, 40), Vector2(14 + tilt, 36)]), Color(0.88, 0.88, 0.9), 20 + tilt, 9)
				p.ellipse(20 + tilt, 28, 3, 1.0 if f != 2 else 1.8, Color(0.25, 0.08, 0.08))
				p.capsule(Vector2(14 + tilt, 16), Vector2(18 + tilt, 17), 1.0, 0.8, Color(0.9, 0.9, 0.92))
				p.capsule(Vector2(22 + tilt, 17), Vector2(26 + tilt, 16), 0.8, 1.0, Color(0.9, 0.9, 0.92))
			"hunter":
				_portrait_bg(p, Color(0.12, 0.25, 0.1))
				p.ball(20 + tilt, 19, 12, 14, Color(0.3, 0.38, 0.18))
				p.ball(20 + tilt, 20, 8, 10, skin)
				# scarf mask
				p.cyl_poly(PackedVector2Array([Vector2(11 + tilt, 23), Vector2(29 + tilt, 23), Vector2(28 + tilt, 33), Vector2(12 + tilt, 33)]), Color(0.42, 0.28, 0.18), 20 + tilt, 9)
				p.line(Vector2(12 + tilt, 26), Vector2(28 + tilt, 26), Color(0.3, 0.2, 0.12))
				p.capsule(Vector2(13 + tilt, 15), Vector2(18 + tilt, 16), 0.9, 0.7, Color(0.3, 0.18, 0.1))
				p.capsule(Vector2(22 + tilt, 16), Vector2(27 + tilt, 15), 0.7, 0.9, Color(0.3, 0.18, 0.1))
				p.line(Vector2(23 + tilt, 9), Vector2(26 + tilt, 21), Color(0.65, 0.4, 0.32))
		# eyes
		var eye_col := Color(0.15, 0.1, 0.1)
		var ey := 18 if kind != "warrior" else 19
		if f == 3:
			eye_col = {"warrior": Color(1, 0.5, 0.1), "mage": Color(0.5, 0.9, 1.0), "hunter": Color(0.7, 1.0, 0.3)}[kind]
		if f == 1:
			p.line(Vector2(14 + tilt, ey), Vector2(17 + tilt, ey), eye_col)
			p.line(Vector2(23 + tilt, ey), Vector2(26 + tilt, ey), eye_col)
		else:
			p.rect(15 + tilt, ey, 2, 2, Color(0.95, 0.92, 0.85))
			p.rect(23 + tilt, ey, 2, 2, Color(0.95, 0.92, 0.85))
			p.rect(16 + tilt, ey, 1, 2, eye_col)
			p.rect(23 + tilt, ey, 1, 2, eye_col)
		_blood_marks(p, f if f < 3 else 0)
		if f == 3:
			p.glow(16 + tilt, ey + 1, 4, eye_col, 0.8)
			p.glow(24 + tilt, ey + 1, 4, eye_col, 0.8)
		if f == 2:
			p.tint(Color(0.5, 0.0, 0.0), 0.15)
		frames.append(p.img)
	return Painter.strip(frames)
