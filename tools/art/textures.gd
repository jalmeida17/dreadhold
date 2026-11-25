extends RefCounted
## World textures, realistic weathered style.
## Walls 128x256 (one tile = 2 m wide x 4 m tall), floors/ceiling 128x128 (2 m), sky 2048x1024.

const Painter := preload("res://tools/art/painter.gd")

const WALL_W := 128
const WALL_H := 256
const FLOOR := 128


static func _noise(seed_value: int, freq: float, octaves: int = 3, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = kind
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


static func _seamless(seed_value: int, w: int, h: int, freq: float, octaves: int = 3) -> Image:
	return _noise(seed_value, freq, octaves).get_seamless_image(w, h, false, false, 0.15, true)


static func _nv(im: Image, x: int, y: int) -> float:
	return im.get_pixel(posmod(x, im.get_width()), posmod(y, im.get_height())).r


static func _q(c: Color, levels: float = 40.0) -> Color:
	return Color(floorf(c.r * levels + 0.5) / levels, floorf(c.g * levels + 0.5) / levels, floorf(c.b * levels + 0.5) / levels, 1.0)


static func _vary(base: Color, rng: RandomNumberGenerator, amount: float) -> Color:
	var v := 1.0 + (rng.randf() - 0.5) * amount
	var c := Color(base.r * v, base.g * v, base.b * v)
	c.h = fposmod(c.h + (rng.randf() - 0.5) * 0.04, 1.0)
	c.s = clampf(c.s * (0.8 + rng.randf() * 0.4), 0.0, 1.0)
	return c


# ----------------------------------------------------------------------------- block layouts

static func _row_layout(rng: RandomNumberGenerator, tex_w: int, min_w: int, max_w: int) -> Array:
	var widths: Array = []
	var total := 0
	while total < tex_w:
		var bw := rng.randi_range(min_w, max_w)
		if tex_w - (total + bw) < min_w and tex_w - (total + bw) > 0:
			bw = tex_w - total
		bw = mini(bw, tex_w - total)
		widths.append(bw)
		total += bw
	return [rng.randi_range(0, tex_w - 1), widths]


static func _block_at(layout: Array, x: int, tex_w: int) -> Vector3i:
	var lx := posmod(x - int(layout[0]), tex_w)
	var acc := 0
	var widths: Array = layout[1]
	for i in widths.size():
		var bw: int = widths[i]
		if lx < acc + bw:
			return Vector3i(i, lx - acc, bw)
		acc += bw
	return Vector3i(widths.size() - 1, 0, 1)


static func stone_blocks(seed_value: int, w: int, h: int, rows: Array, base: Color, mortar: Color, opts: Dictionary = {}) -> Image:
	## Weathered masonry. rows = [[height, min_w, max_w, brightness], ...] top to bottom.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var big := _seamless(seed_value + 1, w, h, 0.03, 4)
	var mid := _seamless(seed_value + 2, w, h, 0.09, 3)
	var fine := _seamless(seed_value + 3, w, h, 0.45, 2)
	var chip := _seamless(seed_value + 4, w, h, 0.22, 2)
	var streak := _noise(seed_value + 5, 0.05, 3)
	var moss_n := _seamless(seed_value + 6, w, h, 0.05, 4)
	var moss: float = opts.get("moss", 0.0)
	var moss_col: Color = opts.get("moss_color", Color(0.23, 0.27, 0.15))
	var grime_amt: float = opts.get("grime", 0.45)
	var vertical: bool = opts.get("vertical", true)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var layouts: Array = []
	var row_y: Array = []
	var y_acc := 0
	for r in rows:
		row_y.append(y_acc)
		y_acc += int(r[0])
		var lay := _row_layout(rng, w, int(r[1]), int(r[2]))
		var cols: Array = []
		for i in (lay[1] as Array).size():
			cols.append(_vary(base * float(r[3]), rng, 0.22))
		layouts.append([lay, cols])
	# cracks as random walks
	var cracks := {}
	for i in int(w * h / 1800.0 * float(opts.get("cracks", 0.4)) * 1.6):
		var cx := rng.randi_range(0, w - 1)
		var cy := rng.randi_range(0, h - 1)
		var dx := 1 if rng.randf() < 0.5 else -1
		for s in rng.randi_range(6, 20):
			cracks[Vector2i(posmod(cx, w), clampi(cy, 0, h - 1))] = true
			if rng.randf() < 0.6:
				cy += 1
			else:
				cx += dx
			if rng.randf() < 0.15:
				dx = -dx
	for y in h:
		var ri := 0
		for kk in row_y.size():
			if y >= int(row_y[kk]):
				ri = kk
		var rh: int = int(rows[ri][0])
		var ly := y - int(row_y[ri])
		var lay: Array = layouts[ri][0]
		var cols: Array = layouts[ri][1]
		var depth := float(y) / float(h)
		for x in w:
			var b := _block_at(lay, x, w)
			var lx := b.y
			var bw := b.z
			var edge_d := mini(mini(lx, bw - 1 - lx), mini(ly, rh - 1 - ly))
			var chipped := edge_d < 3 and _nv(chip, x, y) > 0.62 + float(edge_d) * 0.08
			var is_mortar := lx <= 2 or ly <= 2 or chipped
			var c: Color
			if is_mortar:
				var m := 0.8 + _nv(fine, x, y) * 0.3 + _nv(mid, x, y) * 0.2
				# the stone above casts a shadow into the joint
				if ly <= 1:
					m *= 0.55
				elif lx <= 1:
					m *= 0.75
				c = mortar * m
			else:
				var bc: Color = cols[b.x]
				var s := 0.74 + _nv(big, x, y) * 0.3 + (_nv(mid, x, y) - 0.5) * 0.2 + (_nv(fine, x, y) - 0.5) * 0.16
				# subtle relief: lit top-left rims, shaded bottom-right, worn rounded faces
				if ly <= 3:
					s += 0.06 * (4 - ly) / 4.0
				if lx <= 3:
					s += 0.03
				if ly >= rh - 4:
					s -= 0.07 * float(ly - (rh - 5))
				if lx >= bw - 3:
					s -= 0.05
				# pits
				if _nv(fine, x + 37, y + 11) < 0.16:
					s -= 0.18
				c = Painter.ramp_real(bc, s)
				if cracks.has(Vector2i(x, y)):
					c = c.darkened(0.42)
				elif cracks.has(Vector2i(x - 1, y - 1)):
					c = c.lightened(0.04)
			# grime streaks running down, darker toward the base
			if vertical:
				var sv := streak.get_noise_2d(x * 1.6, y * 0.12) * 0.5 + 0.5
				var g := clampf((sv - 0.45) * 2.2, 0.0, 1.0) * (0.35 + depth * 0.65) * grime_amt
				c = c.lerp(Color(0.07, 0.06, 0.05), g * 0.6)
				# water stains
				var ws := _nv(big, x + 50, y + 90)
				if ws > 0.62:
					c = c.darkened((ws - 0.62) * 0.9)
			if moss > 0.0:
				var mv := _nv(moss_n, x, y)
				var near_joint := 0.26 if (ly <= 4 or lx <= 3 or ly >= rh - 2) else 0.0
				var score := mv * 0.85 + near_joint + depth * 0.3 * moss
				var thr := 1.02 - moss * 0.3
				if score > thr:
					var mc := moss_col * (0.6 + _nv(fine, x + 5, y) * 0.7)
					c = c.lerp(mc, clampf((score - thr) * 5.0, 0.25, 0.85))
			img.set_pixel(x, y, _q(c))
	return img


# ----------------------------------------------------------------------------- walls

static func wall_rows(rng_seed: int, plinth: bool = true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var rows: Array = [[12, 128, 128, 1.08]]
	var y := 12
	var bottom := 32 if plinth else 0
	while y < WALL_H - bottom:
		var rh: int = [24, 26, 28, 30, 32][rng.randi_range(0, 4)]
		if WALL_H - bottom - (y + rh) < 18:
			rh = WALL_H - bottom - y
		rows.append([rh, 30, 62, 1.0 + (rng.randf() - 0.5) * 0.08])
		y += rh
	if plinth:
		rows.append([32, 46, 80, 0.82])
	return rows


static func wall_stone(seed_value: int, moss: float = 0.0) -> Image:
	return stone_blocks(seed_value, WALL_W, WALL_H, wall_rows(seed_value), Color(0.4, 0.385, 0.37), Color(0.2, 0.18, 0.16), {"moss": moss, "cracks": 0.45})


static func wall_dark(seed_value: int) -> Image:
	return stone_blocks(seed_value, WALL_W, WALL_H, wall_rows(seed_value), Color(0.24, 0.25, 0.29), Color(0.1, 0.1, 0.11), {"cracks": 0.6, "grime": 0.35})


static func wall_banner(seed_value: int) -> Image:
	var img := wall_stone(seed_value, 0.12)
	var p := Painter.new(WALL_W, WALL_H, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.07
	# iron rod on brackets
	p.spec = 0.6
	p.capsule(Vector2(20, 28), Vector2(108, 28), 2.4, 2.4, Color(0.25, 0.25, 0.27))
	for bx in [22.0, 106.0]:
		var bxx: float = bx
		p.capsule(Vector2(bxx, 28), Vector2(bxx, 20), 1.6, 1.6, Color(0.22, 0.22, 0.24))
		p.ball(bxx, 20, 2.4, 2.4, Color(0.22, 0.22, 0.24))
	p.spec = 0.0
	# faded crimson cloth with folds, torn hem and moth holes
	var crimson := Color(0.36, 0.07, 0.08)
	var cloth := PackedVector2Array([Vector2(28, 30), Vector2(100, 30), Vector2(101, 150), Vector2(98, 188)])
	for i in 15:
		var t := float(i) / 14.0
		cloth.append(Vector2(98 - t * 68, 196 - absf(t - 0.5) * 34 + sin(t * 37.0) * 3.0 + (4 if i % 3 == 0 else 0)))
	cloth.append(Vector2(27, 150))
	p.cloth(cloth, crimson, 64, 38, 0.18, 0.55, -0.05)
	for hole in [Vector2(44, 120), Vector2(86, 160), Vector2(60, 176), Vector2(78, 70)]:
		var hv: Vector2 = hole
		p.ellipse(hv.x, hv.y, 2.2, 3.0, img.get_pixel(int(hv.x), int(hv.y)).darkened(0.3))
	# embroidered border (dull gold)
	var gold := Color(0.52, 0.41, 0.2)
	for y in range(34, 150, 2):
		p.put(33, y, Painter.ramp_real(gold, 0.95))
		p.put(95, y, Painter.ramp_real(gold, 0.6))
	for x in range(33, 96, 2):
		p.put(x, 35, Painter.ramp_real(gold, 1.0))
	# emblem: crowned sword over a sun disc, worn
	p.ball(64, 92, 20, 20, gold)
	p.ball(64, 92, 15.5, 15.5, crimson.darkened(0.15))
	for i in 12:
		var a := PI + float(i) / 11.0 * PI
		var d := Vector2(cos(a), sin(a))
		p.line(Vector2(64, 92) + d * 22.0, Vector2(64, 92) + d * 29.0, Painter.ramp_real(gold, 0.9), 1.5)
	p.spec = 0.6
	p.blade(Vector2(64, 64), Vector2(64, 134), 3.6, 0.8, Color(0.62, 0.63, 0.66))
	p.capsule(Vector2(51, 72), Vector2(77, 72), 2.0, 2.0, gold)
	p.ball(64, 60, 3.4, 3.4, gold)
	p.spec = 0.0
	p.grime(Color(0.08, 0.06, 0.05), 0.4, 0.05, 0.15, 0.85)
	return p.img


static func wall_gate(seed_value: int) -> Image:
	## Rusted portcullis in a stone arch; a dark passage with a faint green glow.
	var img := wall_stone(seed_value, 0.08)
	var p := Painter.new(WALL_W, WALL_H, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.06
	var opening := PackedVector2Array()
	for i in 25:
		var a := PI + float(i) / 24.0 * PI
		opening.append(Vector2(64 + cos(a) * 48, 80 + sin(a) * 44))
	opening.append(Vector2(112, 256))
	opening.append(Vector2(16, 256))
	var mist := _seamless(seed_value + 9, WALL_W, WALL_H, 0.035, 3)
	for y in WALL_H:
		for x in WALL_W:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), opening):
				var g := clampf(float(y - 100) / 160.0, 0.0, 1.0) * (0.45 + _nv(mist, x, y) * 0.7)
				img.set_pixel(x, y, _q(Color(0.015, 0.015, 0.02).lerp(Color(0.09, 0.24, 0.12), g * 0.75)))
	# arch voussoirs
	for i in 11:
		var a0 := PI + float(i) / 11.0 * PI
		var a1 := PI + float(i + 1) / 11.0 * PI
		var pts := PackedVector2Array([
			Vector2(64 + cos(a0) * 48, 80 + sin(a0) * 44), Vector2(64 + cos(a0) * 62, 80 + sin(a0) * 58),
			Vector2(64 + cos(a1) * 62, 80 + sin(a1) * 58), Vector2(64 + cos(a1) * 48, 80 + sin(a1) * 44)])
		var am := (a0 + a1) * 0.5
		p.flat_poly(pts, Color(0.47, 0.45, 0.43) * (0.92 + 0.08 * float(i % 2)), Vector3(cos(am) * 0.35, sin(am) * 0.35, 1.0))
		p.line(pts[1], pts[0], Color(0.1, 0.09, 0.08), 1.0)
	p.flat_poly(PackedVector2Array([Vector2(56, 20), Vector2(72, 20), Vector2(70, 38), Vector2(58, 38)]), Color(0.5, 0.47, 0.42), Vector3(0, -0.2, 1))
	# portcullis
	var iron := Color(0.25, 0.19, 0.15)
	p.spec = 0.4
	for bx in [24, 38, 52, 66, 80, 94, 108]:
		var bxx: float = bx
		var top_y := 40.0 if absf(bxx - 64) < 32 else 62.0
		p.capsule(Vector2(bxx, top_y), Vector2(bxx, 250), 2.6, 2.6, iron)
		p.poly(PackedVector2Array([Vector2(bxx - 3, 250), Vector2(bxx + 3, 250), Vector2(bxx, 256)]), iron)
	for by in [92, 148, 204]:
		var byy: float = by
		p.capsule(Vector2(19, byy), Vector2(113, byy), 2.2, 2.2, iron)
		for bx in [24, 38, 52, 66, 80, 94, 108]:
			p.ball(float(bx), byy, 2.8, 2.6, iron.lightened(0.1))
	p.spec = 0.0
	return p.img


static func wall_rune(seed_value: int) -> Array:
	## [albedo, emission]: dark basalt with a carved, glowing ward rune.
	var img := wall_dark(seed_value)
	var emi := Image.create(WALL_W, WALL_H, false, Image.FORMAT_RGBA8)
	emi.fill(Color(0, 0, 0, 1))
	var col := Color(0.45, 1.0, 0.5)
	var strokes := [
		[Vector2(64, 66), Vector2(64, 194)],
		[Vector2(64, 86), Vector2(40, 110)], [Vector2(64, 86), Vector2(88, 110)],
		[Vector2(40, 110), Vector2(64, 134)], [Vector2(88, 110), Vector2(64, 134)],
		[Vector2(64, 160), Vector2(44, 184)], [Vector2(64, 160), Vector2(84, 184)],
		[Vector2(52, 70), Vector2(76, 70)],
	]
	var pe := Painter.new(WALL_W, WALL_H)
	pe.img = emi
	for s in strokes:
		pe.line(s[0], s[1], col, 3.0)
	var src := emi.duplicate() as Image
	for y in WALL_H:
		for x in WALL_W:
			var e := src.get_pixel(x, y)
			if e.g > 0.5:
				var hot := 0.75 + float((x * 7 + y * 13) % 5) * 0.06
				img.set_pixel(x, y, Color(0.5 * hot, 1.0 * hot, 0.55 * hot))
			else:
				var near := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
					var q: Vector2i = Vector2i(x, y) + o
					if q.x >= 0 and q.y >= 0 and q.x < WALL_W and q.y < WALL_H and src.get_pixel(q.x, q.y).g > 0.5:
						near = true
				if near:
					img.set_pixel(x, y, Color(0.03, 0.08, 0.05))
					emi.set_pixel(x, y, Color(0.04, 0.2, 0.07))
	return [img, emi]


# ----------------------------------------------------------------------------- floors

static func floor_flagstone(seed_value: int) -> Image:
	var rows := [[32, 36, 72, 1.0], [32, 36, 72, 0.96], [32, 36, 72, 1.03], [32, 36, 72, 0.98]]
	return stone_blocks(seed_value, FLOOR, FLOOR, rows, Color(0.35, 0.32, 0.29), Color(0.13, 0.11, 0.09), {"moss": 0.45, "moss_color": Color(0.2, 0.23, 0.13), "cracks": 0.5, "vertical": false})


static func floor_cobble(seed_value: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := FLOOR
	var pts: Array = []
	var cols: Array = []
	var cells := 11
	for gy in cells:
		for gx in cells:
			pts.append(Vector2((gx + 0.2 + rng.randf() * 0.6) * w / float(cells), (gy + 0.2 + rng.randf() * 0.6) * w / float(cells)))
			cols.append(_vary(Color(0.4, 0.39, 0.38), rng, 0.3))
	var fine := _seamless(seed_value + 4, w, w, 0.4, 2)
	var dirt := _seamless(seed_value + 5, w, w, 0.05, 3)
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	var L := Vector3(-0.45, -0.55, 0.7).normalized()
	var r_cell := float(w) / float(cells)
	for y in w:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var i1 := 0
			var off := Vector2.ZERO
			for i in pts.size():
				var q: Vector2 = pts[i]
				var dx := p.x - q.x
				var dy := p.y - q.y
				if dx > w * 0.5: dx -= w
				if dx < -w * 0.5: dx += w
				if dy > w * 0.5: dy -= w
				if dy < -w * 0.5: dy += w
				var d := dx * dx + dy * dy
				if d < d1:
					d2 = d1
					d1 = d
					i1 = i
					off = Vector2(dx, dy)
				elif d < d2:
					d2 = d
			var edge := sqrt(d2) - sqrt(d1)
			var c: Color
			if edge < 2.2:
				c = Color(0.1, 0.08, 0.06).lerp(Color(0.16, 0.15, 0.08), _nv(dirt, x, y))
			else:
				var nn := Vector3(off.x / (r_cell * 0.65), off.y / (r_cell * 0.65), 0.0)
				nn.z = sqrt(maxf(1.0 - minf(nn.x * nn.x + nn.y * nn.y, 0.9), 0.1))
				var s := 0.28 + maxf(nn.normalized().dot(L), 0.0) * 0.82
				s += (_nv(fine, x, y) - 0.5) * 0.2
				if edge < 3.6:
					s -= 0.15
				c = Painter.ramp_real(cols[i1], s)
				c = c.lerp(Color(0.2, 0.17, 0.12), clampf((_nv(dirt, x, y) - 0.6) * 1.5, 0.0, 0.5))
			img.set_pixel(x, y, _q(c))
	return img


static func floor_dirt(seed_value: int) -> Image:
	var w := FLOOR
	var big := _seamless(seed_value, w, w, 0.03, 4)
	var fine := _seamless(seed_value + 1, w, w, 0.5, 2)
	var grass := _seamless(seed_value + 2, w, w, 0.05, 4)
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	var dirt := Color(0.3, 0.23, 0.17)
	var grass_c := Color(0.2, 0.24, 0.13)
	for y in w:
		for x in w:
			var s := 0.72 + _nv(big, x, y) * 0.32 + (_nv(fine, x, y) - 0.5) * 0.3
			var c := Painter.ramp_real(dirt, s)
			var g := _nv(grass, x, y)
			if g > 0.6:
				c = Painter.ramp_real(grass_c, 0.55 + (g - 0.6) * 1.4 + (_nv(fine, x + 3, y) - 0.5) * 0.5)
			img.set_pixel(x, y, _q(c))
	var p := Painter.new(w, w, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.08
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 40:
		var px := rng.randf_range(3, w - 3)
		var py := rng.randf_range(3, w - 3)
		p.ball(px, py, rng.randf_range(1.0, 2.6), rng.randf_range(0.8, 1.8), Color(0.42, 0.4, 0.38) * rng.randf_range(0.8, 1.1))
	for i in 60:
		var px := rng.randf_range(2, w - 2)
		var py := rng.randf_range(5, w - 2)
		if _nv(grass, int(px), int(py)) > 0.52:
			for kk in 4:
				p.line(Vector2(px + kk - 1.5, py), Vector2(px + (kk - 1.5) * 2.2, py - rng.randf_range(3, 6)), Color(0.27, 0.33, 0.16) * rng.randf_range(0.8, 1.15))
	return p.img


static func ceiling_wood(seed_value: int) -> Image:
	var w := FLOOR
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grain := FastNoiseLite.new()
	grain.seed = seed_value
	grain.frequency = 0.06
	grain.fractal_octaves = 4
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	var wood := Color(0.27, 0.17, 0.1)
	var plank_h := 16
	for y in w:
		var pi := y / plank_h
		var ly := y % plank_h
		var shift := float((pi * 53) % 128)
		var pc := wood * (0.88 + 0.12 * float(pi % 3))
		for x in w:
			var gx := fposmod(x + shift, 128.0)
			var gv := grain.get_noise_2d(gx * 0.12, y * 1.6 + pi * 17.0) * 0.5 + 0.5
			var s := 0.62 + gv * 0.42
			if ly <= 1:
				s = 0.12
			elif ly == 2:
				s += 0.08
			elif ly >= plank_h - 2:
				s -= 0.18
			img.set_pixel(x, y, _q(Painter.ramp_real(pc, s)))
	var p := Painter.new(w, w)
	p.img = img
	p.set_real(1.0)
	for y in range(52, 76):
		for x in w:
			var s := 0.75 + (0.15 if y < 56 else (-0.3 if y > 71 else 0.0)) + grain.get_noise_2d(x * 0.08, y * 2.0) * 0.18
			img.set_pixel(x, y, _q(Painter.ramp_real(Color(0.2, 0.12, 0.07), s)))
	p.spec = 0.6
	for nx in [12, 76]:
		p.ball(float(nx), 64, 3.0, 3.0, Color(0.25, 0.25, 0.27))
	p.spec = 0.0
	return p.img


# ----------------------------------------------------------------------------- sky

static func sky(seed_value: int) -> Image:
	var w := 2048
	var h := 1024
	var half := h / 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var clouds := _noise(seed_value, 0.004, 5).get_seamless_image(w, half, false, false, 0.2, true)
	var wisps := _noise(seed_value + 1, 0.012, 3).get_seamless_image(w, half, false, false, 0.2, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var zenith := Color(0.02, 0.022, 0.035)
	var mid := Color(0.06, 0.06, 0.08)
	var horizon := Color(0.15, 0.13, 0.14)
	var moon := Vector2(600, 300)
	for y in half:
		var v := float(y) / float(half)
		var base := zenith.lerp(mid, smoothstep(0.0, 0.7, v)).lerp(horizon, smoothstep(0.7, 1.0, v))
		for x in w:
			var c := base
			var cn := clouds.get_pixel(x, y).r * 0.75 + wisps.get_pixel(x, y).r * 0.25
			var band := smoothstep(0.03, 0.4, v)
			var cl := clampf((cn - 0.4) * 2.8, 0.0, 1.0) * band
			var md := Vector2(x, y).distance_to(moon)
			var moonlit := clampf(1.0 - md / 520.0, 0.0, 1.0)
			var cloud_col := Color(0.11, 0.1, 0.115).lerp(Color(0.4, 0.44, 0.4), moonlit * moonlit * 0.9).lerp(Color(0.2, 0.15, 0.14), smoothstep(0.6, 1.0, v) * 0.6)
			c = c.lerp(cloud_col, cl * 0.9)
			c += Color(0.16, 0.2, 0.16) * pow(clampf(1.0 - md / 240.0, 0.0, 1.0), 2.2) * (1.0 - cl * 0.7)
			if md < 40.0:
				var crater := clouds.get_pixel((x * 5) % w, (y * 5) % half).r
				var mc := Color(0.78, 0.84, 0.72) * (0.82 + crater * 0.25)
				if md > 36.0:
					mc = mc.lerp(Color(0.5, 0.58, 0.5), 0.5)
				c = c.lerp(mc, 1.0 - cl * 0.55)
			elif cl < 0.1 and rng.randf() < 0.0012 * (1.0 - v * 1.4):
				c = Color(0.75, 0.75, 0.8) * rng.randf_range(0.4, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	img.fill_rect(Rect2i(0, half, w, half), Color(0.02, 0.018, 0.022))
	# mountain ranges (seamless), farther = lighter/hazier
	var ridge := _noise(seed_value + 3, 1.0, 5)
	for layer in 2:
		var base_y := 0.44 if layer == 0 else 0.468
		var amp := 0.075 if layer == 0 else 0.035
		var col := Color(0.06, 0.055, 0.07) if layer == 0 else Color(0.035, 0.03, 0.04)
		for x in w:
			var ang := float(x) / float(w) * TAU
			var rv := ridge.get_noise_2d(cos(ang) * (1.5 + layer), sin(ang) * (1.5 + layer)) * 0.5 + 0.5
			rv = absf(rv - 0.5) * 2.0
			var top := int((base_y - rv * amp) * h)
			for y in range(top, half + 4):
				var cc := col
				if layer == 0 and y < top + 2:
					cc = col.lightened(0.05)
				img.set_pixel(x, y, cc)
	# ruined spires & a broken keep on the horizon (up to ~12% above it)
	var p := Painter.new(w, h)
	p.img = img
	p.dither = 0.0
	var dark := Color(0.025, 0.022, 0.03)
	for sp in [[1450, 1.0], [300, 0.7], [1900, 0.55]]:
		var sx: float = sp[0]
		var sc: float = sp[1]
		var base_y := float(half) + 4
		p.poly(PackedVector2Array([Vector2(sx - 60 * sc, base_y), Vector2(sx - 52 * sc, base_y - 62 * sc), Vector2(sx - 16 * sc, base_y - 62 * sc), Vector2(sx - 12 * sc, base_y - 120 * sc), Vector2(sx - 4 * sc, base_y - 118 * sc), Vector2(sx, base_y - 122 * sc), Vector2(sx + 6 * sc, base_y - 96 * sc), Vector2(sx + 14 * sc, base_y - 62 * sc), Vector2(sx + 30 * sc, base_y - 62 * sc), Vector2(sx + 34 * sc, base_y - 80 * sc), Vector2(sx + 42 * sc, base_y - 74 * sc), Vector2(sx + 48 * sc, base_y - 62 * sc), Vector2(sx + 56 * sc, base_y)]), dark)
		for k in 3:
			var wx := sx - 40 * sc + k * 20 * sc
			p.rect(wx, base_y - 70 * sc, 6 * sc, 8 * sc, dark)
		if sc > 0.9:
			for wp in [Vector2(sx - 6, base_y - 100), Vector2(sx - 34, base_y - 44), Vector2(sx + 22, base_y - 40)]:
				var wv: Vector2 = wp
				p.rect(wv.x, wv.y, 3, 5, Color(0.9, 0.5, 0.18))
				p.glow(wv.x + 1.5, wv.y + 2.5, 9, Color(0.9, 0.42, 0.12), 0.3)
	return img
