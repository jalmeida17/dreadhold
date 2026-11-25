extends RefCounted
## Map-pack textures (village, cathedral, ossuary, ice, volcano, swamp, crypt).
## Walls 128x256, floors/ceilings 128x128, all seamless horizontally (floors both ways).

const Painter := preload("res://tools/art/painter.gd")
const Tex := preload("res://tools/art/textures.gd")

const W := 128
const H := 256
const F := 128


static func _n(seed_value: int, freq: float, oct: int = 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = oct
	return n


static func _sl(seed_value: int, w: int, h: int, freq: float, oct: int = 3) -> Image:
	return _n(seed_value, freq, oct).get_seamless_image(w, h, false, false, 0.15, true)


static func _v(im: Image, x: int, y: int) -> float:
	return im.get_pixel(posmod(x, im.get_width()), posmod(y, im.get_height())).r


static func _q(c: Color) -> Color:
	return Color(floorf(c.r * 40.0 + 0.5) / 40.0, floorf(c.g * 40.0 + 0.5) / 40.0, floorf(c.b * 40.0 + 0.5) / 40.0, 1.0)


static func _finish(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, _q(img.get_pixel(x, y)))


static func _voronoi(seed_value: int, size: int, cells: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts: Array = []
	for gy in cells:
		for gx in cells:
			pts.append(Vector2((gx + 0.15 + rng.randf() * 0.7) * size / float(cells), (gy + 0.15 + rng.randf() * 0.7) * size / float(cells)))
	return pts


static func _vor_at(pts: Array, size: int, x: float, y: float) -> Array:
	## -> [nearest index, d1, d2, offset to nearest]
	var d1 := 1e9
	var d2 := 1e9
	var i1 := 0
	var off := Vector2.ZERO
	for i in pts.size():
		var q: Vector2 = pts[i]
		var dx := x - q.x
		var dy := y - q.y
		if dx > size * 0.5: dx -= size
		if dx < -size * 0.5: dx += size
		if dy > size * 0.5: dy -= size
		if dy < -size * 0.5: dy += size
		var d := dx * dx + dy * dy
		if d < d1:
			d2 = d1
			d1 = d
			i1 = i
			off = Vector2(dx, dy)
		elif d < d2:
			d2 = d
	return [i1, sqrt(d1), sqrt(d2), off]


# =============================================================================== wood frame house

static func _wood_px(grain: FastNoiseLite, u: float, v: float, base: Color, edge: float) -> Color:
	var g := grain.get_noise_2d(u * 0.12, v * 1.5) * 0.5 + 0.5
	var knot := grain.get_noise_2d(u * 0.9 + 50.0, v * 0.9)
	var s := 0.55 + g * 0.42 - edge
	if knot > 0.55:
		s -= 0.25
	return Painter.ramp_real(base, s)


static func wall_wood(seed_value: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var oak := Color(0.22, 0.15, 0.1)
	var plaster := Color(0.56, 0.51, 0.41)
	var pn := _sl(seed_value, W, H, 0.05, 4)
	var pf := _sl(seed_value + 1, W, H, 0.4, 2)
	var hole := _sl(seed_value + 2, W, H, 0.035, 3)
	var grain := _n(seed_value + 3, 0.1, 3)
	# plaster / exposed wattle
	for y in H:
		for x in W:
			var c: Color
			if _v(hole, x, y) > 0.68:
				var weave := sin((x + y) * 0.55) * sin((x - y) * 0.55)
				c = Painter.ramp_real(Color(0.32, 0.23, 0.14), 0.55 + weave * 0.3 + _v(pf, x, y) * 0.2)
				if _v(hole, x, y) < 0.7:
					c = c.darkened(0.4)
			else:
				var s := 0.78 + _v(pn, x, y) * 0.26 + (_v(pf, x, y) - 0.5) * 0.12
				c = Painter.ramp_real(plaster, s)
				if _v(hole, x, y) > 0.64:
					c = c.darkened(0.25)
			# soot rising from the top
			var soot := clampf(1.0 - float(y) / 90.0, 0.0, 1.0) * (0.5 + _v(pn, x + 30, y) * 0.5)
			c = c.lerp(Color(0.06, 0.05, 0.04), soot * 0.6)
			img.set_pixel(x, y, c)
	# cracks in the plaster
	var p := Painter.new(W, H, seed_value)
	p.img = img
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 9:
		var cp := Vector2(rng.randf_range(14, 120), rng.randf_range(20, 236))
		for k in rng.randi_range(6, 14):
			var np := cp + Vector2(rng.randf_range(-3, 3), rng.randf_range(1, 4))
			p.line(cp, np, Color(0.2, 0.17, 0.13))
			cp = np
	# beams: posts, plates, rail, sill, brace
	var rects := [Rect2i(0, 0, 12, H), Rect2i(0, 0, W, 14), Rect2i(0, 118, W, 12), Rect2i(0, 238, W, 18), Rect2i(28, 24, 74, 6), Rect2i(28, 96, 74, 6), Rect2i(28, 24, 6, 78), Rect2i(96, 24, 6, 78)]
	for ri in rects.size():
		var r: Rect2i = rects[ri]
		var vertical := r.size.y > r.size.x
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var u := float(y) if vertical else float(x)
				var v := float(x) if vertical else float(y)
				var e := 0.0
				var lx := (x - r.position.x) if vertical else (y - r.position.y)
				var span := r.size.x if vertical else r.size.y
				if lx == 0:
					e = -0.12
				elif lx >= span - 2:
					e = 0.22
				img.set_pixel(x, y, _wood_px(grain, u, v + ri * 31.0, oak, e))
	# diagonal brace in the lower panel
	var brace := PackedVector2Array([Vector2(12, 226), Vector2(20, 238), Vector2(70, 130), Vector2(62, 130)])
	for y in range(128, 240):
		for x in range(10, 74):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), brace):
				var along := (Vector2(x, y) - Vector2(16, 232)).dot(Vector2(0.43, -0.9))
				img.set_pixel(x, y, _wood_px(grain, along, float(x) * 0.9 + 400.0, oak, 0.0))
	p.line(Vector2(20, 238), Vector2(70, 130), Color(0.06, 0.04, 0.03))
	# closed shutters in the window frame (one ajar)
	for side in 2:
		var x0 := 34 + side * 31
		for y in range(30, 96):
			for x in range(x0, x0 + 31):
				var plank := (x - x0) / 8
				var c := _wood_px(grain, float(y), float(x) + plank * 13.0 + side * 70.0, Color(0.27, 0.18, 0.11), 0.0)
				if (x - x0) % 8 == 0:
					c = c.darkened(0.55)
				img.set_pixel(x, y, c)
	for y in range(30, 96):
		for x in range(64, 68):
			img.set_pixel(x, y, Color(0.02, 0.02, 0.02))
	p.set_real(1.0)
	p.spec = 0.6
	for hy in [40.0, 84.0]:
		p.capsule(Vector2(36, hy), Vector2(58, hy), 1.4, 1.4, Color(0.22, 0.21, 0.2))
		p.capsule(Vector2(70, hy), Vector2(92, hy), 1.4, 1.4, Color(0.22, 0.21, 0.2))
	p.spec = 0.0
	# wooden pegs on the beams
	for pg in [Vector2(6, 7), Vector2(6, 124), Vector2(6, 246), Vector2(64, 7), Vector2(64, 124)]:
		var pv: Vector2 = pg
		p.ball(pv.x, pv.y, 1.6, 1.6, Color(0.3, 0.2, 0.12))
	_finish(img)
	return img


# =============================================================================== cathedral

static func wall_cathedral(seed_value: int) -> Image:
	var img := Tex.stone_blocks(seed_value, W, H, Tex.wall_rows(seed_value), Color(0.6, 0.58, 0.52), Color(0.3, 0.28, 0.25), {"cracks": 0.3, "grime": 0.55})
	var p := Painter.new(W, H, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.06
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		var a := PI + t * PI
		# pointed (two-centred) arch
		var ox := 64.0 + cos(a) * 30.0
		var oy := 80.0 - absf(sin(a)) * 50.0 * (1.0 - absf(t - 0.5) * 0.35)
		outer.append(Vector2(ox, oy))
		inner.append(Vector2(64.0 + cos(a) * 22.0, 88.0 - absf(sin(a)) * 44.0 * (1.0 - absf(t - 0.5) * 0.35)))
	outer.append(Vector2(94, 222))
	outer.append(Vector2(34, 222))
	inner.append(Vector2(86, 214))
	inner.append(Vector2(42, 214))
	# recess (darker, sloped jambs)
	for y in range(20, 224):
		for x in range(32, 96):
			var pp := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(pp, outer) and not Geometry2D.is_point_in_polygon(pp, inner):
				var side := (x - 64.0) / 30.0
				img.set_pixel(x, y, Painter.ramp_real(Color(0.5, 0.48, 0.43), 0.55 - side * 0.25 + (0.1 if y < 60 else 0.0)))
	# stained glass: dark panes in a lead grid, quatrefoil at the top
	var panes := [Color(0.32, 0.05, 0.06), Color(0.07, 0.1, 0.32), Color(0.07, 0.22, 0.1), Color(0.36, 0.25, 0.05), Color(0.2, 0.06, 0.25)]
	var gn := _sl(seed_value + 5, W, H, 0.08, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in range(40, 216):
		for x in range(42, 86):
			var pp := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(pp, inner):
				continue
			var cell := Vector2i((x - 42) / 7, (y - 40) / 9)
			var lead := (x - 42) % 7 == 0 or (y - 40) % 9 == 0
			var c: Color
			if lead:
				c = Color(0.07, 0.07, 0.08)
			else:
				var pc: Color = panes[posmod(cell.x * 3 + cell.y * 7 + (cell.x * cell.y) % 5, panes.size())]
				c = pc * (0.45 + _v(gn, x, y) * 0.4)
				c.a = 1.0
				if rng.randf() < 0.006:
					c = pc.lightened(0.45)
			img.set_pixel(x, y, c)
	# mullion + tracery
	p.spec = 0.4
	p.capsule(Vector2(64, 60), Vector2(64, 214), 1.6, 1.6, Color(0.5, 0.48, 0.43))
	for i in 4:
		var a2 := float(i) / 4.0 * TAU + PI * 0.25
		p.ellipse(64 + cos(a2) * 5.0, 60 + sin(a2) * 5.0, 4.0, 4.0, Color(0.48, 0.46, 0.41))
		p.ellipse(64 + cos(a2) * 5.0, 60 + sin(a2) * 5.0, 2.6, 2.6, panes[i])
	p.spec = 0.0
	p.line(Vector2(34, 222), Vector2(94, 222), Color(0.65, 0.62, 0.56), 2.0)
	p.grime(Color(0.06, 0.06, 0.05), 0.35, 0.05, 0.15, 0.9)
	_finish(p.img)
	return p.img


# =============================================================================== ossuary

static func wall_bone(seed_value: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var mn := _sl(seed_value, W, H, 0.1, 3)
	for y in H:
		for x in W:
			img.set_pixel(x, y, Painter.ramp_real(Color(0.12, 0.1, 0.085), 0.6 + _v(mn, x, y) * 0.5))
	var p := Painter.new(W, H, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.12
	var bone := Color(0.62, 0.57, 0.46)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := 4.0
	var row := 0
	while y < H - 4:
		var kind := row % 3
		if kind == 0:
			# skull row
			var n := 6
			for i in n:
				var sx := (i + 0.5) * W / float(n) + (rng.randf() - 0.5) * 3.0
				var sy := y + 11.0
				for wrap in [-W, 0, W]:
					var cx := sx + float(wrap)
					if cx < -14 or cx > W + 14:
						continue
					var b := bone.darkened(rng.randf() * 0.2)
					p.ball(cx, sy, 9.0, 9.5, b)
					p.ball(cx, sy + 7.5, 5.5, 3.0, b.darkened(0.05))
					p.ellipse(cx - 3.4, sy + 1.0, 2.4, 2.6, Color(0.04, 0.03, 0.03))
					p.ellipse(cx + 3.4, sy + 1.0, 2.4, 2.6, Color(0.04, 0.03, 0.03))
					p.poly(PackedVector2Array([Vector2(cx - 1.2, sy + 4.0), Vector2(cx + 1.2, sy + 4.0), Vector2(cx, sy + 6.2)]), Color(0.05, 0.04, 0.03))
					for t in 5:
						p.rect(cx - 3.0 + t * 1.3, sy + 7.0, 0.8, 1.4, Color(0.7, 0.66, 0.54))
			y += 23.0
		elif kind == 1:
			# femur heads facing out
			var n2 := 12
			for i in n2:
				var bx := (i + 0.5) * W / float(n2)
				for wrap in [-W, 0, W]:
					var cx2 := bx + float(wrap)
					if cx2 < -8 or cx2 > W + 8:
						continue
					for r2 in 2:
						var by := y + 5.0 + r2 * 9.0
						var ox := 5.0 if r2 == 1 else 0.0
						p.ball(cx2 + ox, by, 4.6, 4.2, bone.darkened(rng.randf() * 0.25))
						p.ball(cx2 + ox + 0.6, by + 0.6, 1.4, 1.2, bone.darkened(0.45))
			y += 19.0
		else:
			# long bones laid flat
			var n3 := 3
			for i in n3:
				var lx := i * W / float(n3) + rng.randf() * 6.0
				for wrap in [-W, 0, W]:
					var a := Vector2(lx + float(wrap), y + 5.0)
					var b2 := a + Vector2(36.0, rng.randf_range(-1.5, 1.5))
					if b2.x < -6 or a.x > W + 6:
						continue
					p.capsule(a, b2, 2.6, 2.2, bone)
					p.ball(a.x, a.y, 3.6, 3.2, bone)
					p.ball(b2.x, b2.y, 3.4, 3.0, bone)
			y += 11.0
		row += 1
	p.grime(Color(0.2, 0.15, 0.08), 0.5, 0.06, 0.05, 0.6)
	_finish(p.img)
	return p.img


# =============================================================================== ice

static func wall_ice(seed_value: int) -> Image:
	var img := Tex.stone_blocks(seed_value, W, H, Tex.wall_rows(seed_value), Color(0.22, 0.24, 0.28), Color(0.08, 0.09, 0.1), {"cracks": 0.4, "grime": 0.2})
	var thick := _sl(seed_value + 4, W, H, 0.03, 4)
	var fine := _sl(seed_value + 5, W, H, 0.3, 2)
	var ice := Color(0.55, 0.74, 0.88)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in H:
		for x in W:
			var c := img.get_pixel(x, y)
			var t := _v(thick, x, y)
			var a := 0.45 + t * 0.35
			var streak := 0.08 * sin((x + y * 0.6) * 0.18) + 0.06 * sin((x - y * 0.3) * 0.07)
			c = c.lerp(Painter.ramp_real(ice, 0.7 + t * 0.45 + streak), a)
			if _v(fine, x, y) > 0.8:
				c = c.lightened(0.25)
			if rng.randf() < 0.004:
				c = Color(0.92, 0.97, 1.0)
			img.set_pixel(x, y, c)
	var p := Painter.new(W, H, seed_value)
	p.img = img
	for i in 7:
		var cp := Vector2(rng.randf_range(4, 124), rng.randf_range(30, 240))
		for k in rng.randi_range(5, 12):
			var np := cp + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 4))
			p.line(cp, np, Color(0.85, 0.94, 1.0, 0.85))
			cp = np
	# icicles hanging from the top edge (frost line + spikes)
	for x in W:
		for y in 6:
			img.set_pixel(x, y, Color(0.8, 0.9, 0.97).darkened(float(y) * 0.04))
	var xs := 2.0
	while xs < W - 2:
		var wdt := rng.randf_range(3.0, 7.0)
		var ln := rng.randf_range(12.0, 44.0)
		var poly := PackedVector2Array([Vector2(xs, 4), Vector2(xs + wdt, 4), Vector2(xs + wdt * 0.55, 4 + ln)])
		for y2 in range(4, int(4 + ln) + 1):
			for x2 in range(int(xs), int(xs + wdt) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(x2 + 0.5, y2 + 0.5), poly):
					var lt := 1.05 if x2 < xs + wdt * 0.45 else 0.8
					img.set_pixel(x2 % W, y2, Painter.ramp_real(Color(0.68, 0.84, 0.95), lt - float(y2) / 200.0))
		xs += wdt + rng.randf_range(1.0, 6.0)
	_finish(img)
	return img


# =============================================================================== obsidian & lava

static func _cracks_mask(seed_value: int, w: int, h: int, freq: float) -> Image:
	## Seamless crack field: value near 0 on the crack lines.
	var a := _n(seed_value, freq, 2).get_seamless_image(w, h, false, false, 0.1, false)
	var b := _n(seed_value + 9, freq * 1.8, 1).get_seamless_image(w, h, false, false, 0.1, false)
	var out := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			var v := minf(absf(a.get_pixel(x, y).r - 0.5), absf(b.get_pixel(x, y).r - 0.5) * 1.6)
			out.set_pixel(x, y, Color(v, 0, 0))
	return out


static func wall_obsidian(seed_value: int) -> Array:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var emi := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var pts := _voronoi(seed_value, W, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var facets: Array = []
	for i in pts.size():
		facets.append(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), 1.0).normalized())
	var cracks := _cracks_mask(seed_value + 3, W, H, 0.02)
	var L := Vector3(-0.45, -0.6, 0.66).normalized()
	for y in H:
		for x in W:
			var vr := _vor_at(pts, W, x + 0.5, fposmod(y * 0.5, float(W)) + 0.5)
			var nrm: Vector3 = facets[vr[0]]
			var s := 0.25 + maxf(nrm.dot(L), 0.0) * 0.7
			var c := Painter.ramp_real(Color(0.1, 0.095, 0.12), s)
			var edge: float = vr[2] - vr[1]
			if edge < 1.0:
				c = c.lightened(0.12)
			elif edge < 2.2:
				c = c.darkened(0.3)
			var cv := cracks.get_pixel(x, y).r
			var e := Color(0, 0, 0, 1)
			if cv < 0.008:
				c = Color(1.0, 0.82, 0.4)
				e = Color(1.0, 0.7, 0.3, 1)
			elif cv < 0.02:
				c = Color(1.0, 0.42, 0.08)
				e = Color(0.9, 0.35, 0.05, 1)
			elif cv < 0.04:
				c = c.lerp(Color(0.4, 0.08, 0.02), 0.6)
				e = Color(0.25, 0.06, 0.0, 1)
			img.set_pixel(x, y, _q(c))
			emi.set_pixel(x, y, e)
	return [img, emi]


static func floor_lava(seed_value: int) -> Array:
	var img := Image.create(F, F, false, Image.FORMAT_RGBA8)
	var emi := Image.create(F, F, false, Image.FORMAT_RGBA8)
	var pts := _voronoi(seed_value, F, 6)
	var fine := _sl(seed_value + 1, F, F, 0.35, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints: Array = []
	for i in pts.size():
		tints.append(rng.randf_range(0.85, 1.12))
	var L := Vector3(-0.45, -0.6, 0.66).normalized()
	for y in F:
		for x in F:
			var vr := _vor_at(pts, F, x + 0.5, y + 0.5)
			var edge: float = vr[2] - vr[1]
			var off: Vector2 = vr[3]
			var c: Color
			var e := Color(0, 0, 0, 1)
			if edge < 1.2:
				c = Color(1.0, 0.85, 0.45)
				e = Color(1.0, 0.75, 0.35, 1)
			elif edge < 2.6:
				c = Color(1.0, 0.45, 0.08)
				e = Color(0.95, 0.38, 0.05, 1)
			elif edge < 4.0:
				c = Color(0.45, 0.1, 0.03)
				e = Color(0.3, 0.06, 0.0, 1)
			else:
				var nn := Vector3(off.x / 14.0, off.y / 14.0, 0.0)
				nn.z = sqrt(maxf(1.0 - minf(nn.x * nn.x + nn.y * nn.y, 0.9), 0.1))
				var s := 0.3 + maxf(nn.normalized().dot(L), 0.0) * 0.55 + (_v(fine, x, y) - 0.5) * 0.25
				c = Painter.ramp_real(Color(0.17, 0.155, 0.15) * float(tints[vr[0]]), s)
				if edge < 5.5:
					c = c.lerp(Color(0.3, 0.08, 0.03), 0.3)
			img.set_pixel(x, y, _q(c))
			emi.set_pixel(x, y, e)
	return [img, emi]


# =============================================================================== floors

static func floor_marble(seed_value: int) -> Image:
	var img := Image.create(F, F, false, Image.FORMAT_RGBA8)
	var vein := _n(seed_value, 0.04, 3).get_seamless_image(F, F, false, false, 0.15, false)
	var vein2 := _n(seed_value + 1, 0.09, 2).get_seamless_image(F, F, false, false, 0.15, false)
	var dirt := _sl(seed_value + 2, F, F, 0.05, 4)
	var fine := _sl(seed_value + 3, F, F, 0.4, 2)
	for y in F:
		for x in F:
			var tx := x / 32
			var ty := y / 32
			var dark := (tx + ty) % 2 == 0
			var base := Color(0.14, 0.13, 0.15) if dark else Color(0.6, 0.58, 0.53)
			var lx := x % 32
			var ly := y % 32
			var s := 0.82 + (_v(fine, x, y) - 0.5) * 0.12
			if ly <= 1:
				s += 0.08
			if lx >= 30 or ly >= 30:
				s -= 0.15
			var c := Painter.ramp_real(base, s)
			var vv := absf(vein.get_pixel(x, y).r - 0.5)
			var vv2 := absf(vein2.get_pixel(x, y).r - 0.5)
			if vv < 0.012 or vv2 < 0.006:
				c = c.lightened(0.35) if dark else c.darkened(0.3)
			elif vv < 0.03:
				c = c.lightened(0.12) if dark else c.darkened(0.1)
			if lx == 0 or ly == 0:
				c = Color(0.06, 0.055, 0.05)
			c = c.lerp(Color(0.15, 0.12, 0.08), clampf((_v(dirt, x, y) - 0.55) * 1.6, 0.0, 0.55))
			img.set_pixel(x, y, _q(c))
	var p := Painter.new(F, F, seed_value)
	p.img = img
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 5:
		var cp := Vector2(rng.randf_range(2, 126), rng.randf_range(2, 126))
		for k in rng.randi_range(5, 12):
			var np := cp + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			p.line(cp, np, Color(0.05, 0.05, 0.05))
			cp = np
	return img


static func floor_snow(seed_value: int) -> Image:
	var rows := [[32, 36, 72, 1.0], [32, 36, 72, 0.96], [32, 36, 72, 1.03], [32, 36, 72, 0.98]]
	var img := Tex.stone_blocks(seed_value, F, F, rows, Color(0.3, 0.31, 0.34), Color(0.1, 0.1, 0.11), {"cracks": 0.3, "vertical": false})
	var cover := _sl(seed_value + 1, F, F, 0.04, 4)
	var fine := _sl(seed_value + 2, F, F, 0.3, 2)
	var icy := _sl(seed_value + 3, F, F, 0.06, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in F:
		for x in F:
			var c := img.get_pixel(x, y)
			var cv := _v(cover, x, y)
			if _v(icy, x, y) > 0.68:
				var streak := 0.1 * sin((x + y) * 0.3)
				c = Painter.ramp_real(Color(0.5, 0.66, 0.78), 0.85 + streak + _v(fine, x, y) * 0.15)
			elif cv > 0.3:
				var s := 0.82 + (cv - 0.3) * 0.35 + (_v(fine, x, y) - 0.5) * 0.12
				c = Painter.ramp_real(Color(0.8, 0.84, 0.9), s)
				if cv < 0.38:
					c = c.lerp(img.get_pixel(x, y), (0.38 - cv) * 8.0)
				if rng.randf() < 0.006:
					c = Color(1, 1, 1)
			img.set_pixel(x, y, _q(c))
	return img


static func floor_sludge(seed_value: int) -> Image:
	var img := Image.create(F, F, false, Image.FORMAT_RGBA8)
	var big := _sl(seed_value, F, F, 0.04, 4)
	var fine := _sl(seed_value + 1, F, F, 0.35, 2)
	var pud := _sl(seed_value + 2, F, F, 0.05, 3)
	for y in F:
		for x in F:
			var s := 0.6 + _v(big, x, y) * 0.4 + (_v(fine, x, y) - 0.5) * 0.3
			var c := Painter.ramp_real(Color(0.17, 0.13, 0.08), s)
			var pv := _v(pud, x, y)
			if pv > 0.64:
				var depth := clampf((pv - 0.64) * 6.0, 0.0, 1.0)
				c = Color(0.36, 0.42, 0.08).lerp(Color(0.62, 0.7, 0.16), depth)
				if (_v(fine, x + 9, y) > 0.78):
					c = c.lightened(0.25)
			elif pv > 0.6:
				c = c.lerp(Color(0.2, 0.24, 0.05), 0.6)
			img.set_pixel(x, y, c)
	var p := Painter.new(F, F, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 4:
		var a := Vector2(rng.randf_range(10, 110), rng.randf_range(10, 118))
		var b := a + Vector2(rng.randf_range(-16, 16), rng.randf_range(-10, 10))
		p.capsule(a, b, 1.6, 1.4, Color(0.55, 0.5, 0.38))
		p.ball(a.x, a.y, 2.4, 2.2, Color(0.55, 0.5, 0.38))
		p.ball(b.x, b.y, 2.2, 2.0, Color(0.55, 0.5, 0.38))
	p.ball(88, 30, 5.5, 5.0, Color(0.52, 0.47, 0.36))
	p.ellipse(86, 30, 1.4, 1.5, Color(0.05, 0.04, 0.03))
	p.ellipse(90.5, 30, 1.4, 1.5, Color(0.05, 0.04, 0.03))
	for i in 10:
		var bp := Vector2(rng.randf_range(4, 124), rng.randf_range(4, 124))
		if _v(pud, int(bp.x), int(bp.y)) > 0.66:
			p.ellipse(bp.x, bp.y, 1.6, 1.3, Color(0.75, 0.82, 0.3))
			p.put(int(bp.x) - 1, int(bp.y) - 1, Color(0.95, 1.0, 0.7))
	_finish(p.img)
	return p.img


static func ceiling_stone(seed_value: int) -> Image:
	var rows := [[32, 30, 64, 1.0], [32, 30, 64, 0.95], [32, 30, 64, 1.02], [32, 30, 64, 0.97]]
	var img := Tex.stone_blocks(seed_value, F, F, rows, Color(0.27, 0.26, 0.25), Color(0.08, 0.075, 0.07), {"cracks": 0.4, "vertical": false})
	var p := Painter.new(F, F, seed_value)
	p.img = img
	p.set_real(1.0)
	p.grain = 0.08
	# vault rib across the tile
	for y in range(54, 74):
		for x in F:
			var t := float(y - 54) / 19.0
			var s := 0.55 + sin(t * PI) * 0.5 + (0.12 if y == 56 else 0.0) - (0.2 if y == 70 else 0.0)
			img.set_pixel(x, y, Painter.ramp_real(Color(0.33, 0.32, 0.3), s))
	for x in range(0, F, 32):
		p.line(Vector2(x, 54), Vector2(x, 73), Color(0.08, 0.07, 0.07))
	# creeping roots
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 3:
		var cp := Vector2(rng.randf_range(0, F), rng.randf_range(0, F))
		var dir := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var r := 2.2
		for k in 26:
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			var np := cp + dir * 3.0
			p.capsule(Vector2(fposmod(cp.x, F), fposmod(cp.y, F)), Vector2(fposmod(cp.x, F), fposmod(cp.y, F)) + (np - cp), r, r * 0.95, Color(0.2, 0.14, 0.09))
			if rng.randf() < 0.15:
				var tw := np + dir.rotated(1.2) * 6.0
				p.line(np, tw, Color(0.17, 0.12, 0.08))
			cp = np
			r = maxf(r * 0.96, 0.7)
	# cobwebs in two corners
	for corner in [Vector2(0, 0), Vector2(F - 1, F - 1)]:
		var cv: Vector2 = corner
		var sx := 1.0 if cv.x == 0 else -1.0
		var sy := 1.0 if cv.y == 0 else -1.0
		for k in 6:
			var a := float(k) / 5.0 * PI * 0.5
			p.line(cv, cv + Vector2(cos(a) * sx, sin(a) * sy) * 30.0, Color(0.6, 0.6, 0.58, 0.55))
		for ring in [8.0, 15.0, 22.0]:
			var rr: float = ring
			for k in 5:
				var a0 := float(k) / 5.0 * PI * 0.5
				var a1 := float(k + 1) / 5.0 * PI * 0.5
				p.line(cv + Vector2(cos(a0) * sx, sin(a0) * sy) * rr, cv + Vector2(cos(a1) * sx, sin(a1) * sy) * (rr - 1.5), Color(0.55, 0.55, 0.52, 0.45))
	_finish(p.img)
	return p.img
