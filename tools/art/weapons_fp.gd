extends RefCounted
## First-person weapon sprites, realistic pixel style. Each frame is the full 640x360 internal
## screen, drawn 1:1 at (0,0); the weapon sits where it appears on screen and only leaves the
## frame through real screen edges. Designed in 128x96 units, scaled by K and offset by an origin.

const Painter := preload("res://tools/art/painter.gd")
const Items := preload("res://tools/art/items.gd")
const GOLD := Color(0.6, 0.47, 0.22)
const STEEL := Color(0.5, 0.52, 0.56)
const DARK_STEEL := Color(0.3, 0.31, 0.34)
const LEATHER := Color(0.28, 0.18, 0.11)
const WOOD := Color(0.33, 0.21, 0.12)
const SKIN := Color(0.66, 0.5, 0.4)

const FW := 640
const FH := 360
const K := 2.85
## screen position of design-unit (0,0) for right-handed weapons and for the bow
const ORIGIN_R := Vector2(172, 86)
const ORIGIN_BOW := Vector2(125, 86)


static func _new(seed_value: int, origin: Vector2 = ORIGIN_R) -> Painter:
	var p := Painter.new(FW, FH, seed_value)
	p.set_real(K)
	p.xf = Transform2D(0.0, Vector2(K, K), 0.0, origin)
	p.grain = 0.08
	return p


static func _finish(p: Painter) -> void:
	p.rim(0.38, 0.1)


static func _wood_haft(p: Painter, a: Vector2, b: Vector2, r: float) -> void:
	p.capsule(a, b, r, r * 0.9, WOOD)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var L := a.distance_to(b)
	for i in 5:
		var off := (float(i) - 2.0) * r * 0.38
		var t0 := 0.05 + float(i % 3) * 0.1
		p.line(a + d * L * t0 + n * off, a + d * L * (0.85 - float(i % 2) * 0.15) + n * (off * 0.9), WOOD.darkened(0.45), 0.5)


static func _leather_wrap(p: Painter, a: Vector2, b: Vector2, r: float, bands: int) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var L := a.distance_to(b)
	p.capsule(a, b, r, r, LEATHER)
	for i in bands:
		var t := (float(i) + 0.5) / float(bands)
		var c := a + d * L * t
		p.line(c - n * r + d * 1.2, c + n * r - d * 1.2, LEATHER.darkened(0.55), 0.6)


static func _gauntlet(p: Painter, grip: Vector2, d: Vector2, arm_dir: Vector2) -> void:
	## Articulated plate gauntlet closed around a haft running along d; the forearm runs
	## along arm_dir far past the screen edge.
	var n := Vector2(-d.y, d.x)
	if n.x < 0.0:
		n = -n
	var cuff := grip - d * 4.0 + n * 9.0
	var forearm_from := cuff + arm_dir.normalized() * 140.0
	# leather sleeve + vambrace
	p.capsule(forearm_from + Vector2(6, 10), cuff, 19, 13, LEATHER.darkened(0.2))
	p.spec = 0.8
	p.shininess = 22.0
	p.capsule(forearm_from, cuff + (forearm_from - cuff).normalized() * 6.0, 16, 11.5, STEEL)
	var fa := (cuff - forearm_from).normalized()
	var fn := Vector2(-fa.y, fa.x)
	for k in 2:
		var bp := cuff - fa * (14.0 + k * 16.0)
		p.capsule(bp - fn * (12.5 + k * 1.2), bp + fn * (12.5 + k * 1.2), 1.2, 1.2, GOLD)
	# flared cuff
	p.ball(cuff.x, cuff.y, 11.5, 10.5, STEEL.darkened(0.05))
	p.capsule(cuff - fn * 11.0, cuff + fn * 11.0, 1.0, 1.0, GOLD.darkened(0.1))
	# back-of-hand plate
	var hand := grip + n * 6.0
	p.ball(hand.x, hand.y, 9.5, 9.0, STEEL)
	# finger lames wrapping the haft
	for f in 4:
		var fp := grip + d * (-6.5 + f * 4.4)
		var k0 := fp + n * 9.0
		var k1 := fp + n * 3.0
		var k2 := fp - n * 2.5
		p.capsule(k0, k1, 2.6, 2.4, STEEL.lightened(0.03))
		p.capsule(k1, k2, 2.4, 2.1, STEEL)
		p.ball(k1.x, k1.y, 2.6, 2.4, STEEL.lightened(0.08))
		p.line(k1 - d * 2.0, k1 + d * 2.0, DARK_STEEL.darkened(0.4), 0.5)
	# thumb over the top
	p.capsule(grip + n * 9.0 - d * 7.0, grip - d * 9.0 - n * 1.5, 2.8, 2.4, STEEL.lightened(0.03))
	for rv in [hand + d * 3.0, hand - d * 3.5, cuff + fn * 7.0, cuff - fn * 7.0]:
		var r: Vector2 = rv
		p.ball(r.x, r.y, 0.9, 0.9, STEEL.lightened(0.3))
	p.spec = 0.0
	p.shininess = 18.0


# =============================================================================== axe

static func axe_frames() -> Image:
	# [grip, head, smear]
	var poses := [
		[Vector2(98, 82), Vector2(68, 22), false],
		[Vector2(116, 42), Vector2(138, -34), false],
		[Vector2(70, 90), Vector2(20, 40), true],
		[Vector2(12, 118), Vector2(-40, 90), false],
	]
	var frames: Array = []
	for i in poses.size():
		var p := _new(400 + i)
		var grip: Vector2 = poses[i][0]
		var head: Vector2 = poses[i][1]
		var d := (head - grip).normalized()
		var n := Vector2(-d.y, d.x)
		if n.x > 0.0:
			n = -n
		if poses[i][2]:
			# motion smear (semi-transparent, the HUD layer blends it)
			for kk in 60:
				var t := float(kk) / 59.0
				var a := lerpf(-0.35, 1.9, t)
				var pc := Vector2(76, 118) + Vector2(cos(a + PI), sin(a + PI)) * Vector2(84, 94)
				p.glow(pc.x, pc.y, 6.0 + t * 5.0, Color(0.55, 0.57, 0.62), 0.1 + t * 0.12)
		# haft: wood with grain, leather grip, iron langets near the head
		_wood_haft(p, grip - d * 40.0, head + d * 10.0, 3.6)
		_leather_wrap(p, grip - d * 12.0, grip + d * 16.0, 4.0, 9)
		p.spec = 0.5
		p.capsule(head - d * 16.0 + n * 3.2, head + d * 4.0 + n * 3.2, 0.9, 0.9, DARK_STEEL)
		p.capsule(head - d * 16.0 - n * 3.2, head + d * 4.0 - n * 3.2, 0.9, 0.9, DARK_STEEL)
		p.spec = 0.0
		# bearded blade
		var s := 1.3
		var loc := func(u: float, v: float) -> Vector2: return head + (d * u + n * v) * s
		var blade := PackedVector2Array([loc.call(5, 2.5), loc.call(5, 7), loc.call(10.5, 13), loc.call(12.5, 23), loc.call(6.5, 27.5), loc.call(-4, 28.8), loc.call(-14, 27), loc.call(-24, 21), loc.call(-17, 14), loc.call(-9, 8.5), loc.call(-5, 2.5)])
		p.spec = 0.9
		p.shininess = 26.0
		p.spec = 0.45
		p.grad_poly(blade, STEEL, head, n, 29.0 * s, 0.32, 0.82, 7.0)
		var edge := PackedVector2Array([loc.call(12.5, 23), loc.call(6.5, 27.5), loc.call(-4, 28.8), loc.call(-14, 27), loc.call(-24, 21), loc.call(-21, 19.5), loc.call(-13, 23.8), loc.call(-4, 25.4), loc.call(5.5, 24.2), loc.call(10.5, 20.5)])
		p.grad_poly(edge, STEEL, loc.call(0, 23), n, 6.0 * s, 0.9, 1.15, 3.0)
		p.spec = 0.0
		p.shininess = 18.0
		# scratches & etched rune line
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for kk in 9:
			var u := rng.randf_range(-16, 8)
			var v := rng.randf_range(6, 24)
			var a2: Vector2 = loc.call(u, v)
			var b2: Vector2 = loc.call(u + rng.randf_range(2, 6), v + rng.randf_range(-1.5, 1.5))
			p.line(a2, b2, STEEL.darkened(0.35) if kk % 2 == 0 else STEEL.lightened(0.2), 0.5)
		p.line(loc.call(8, 20.5), loc.call(-15, 22.5), DARK_STEEL.darkened(0.2), 0.6)
		for kk in 0:
			var u2 := 2.0 - kk * 4.5
			p.line(loc.call(u2, 6.5), loc.call(u2 - 1.5, 10), DARK_STEEL.darkened(0.4), 0.6)
		# socket + hammer poll
		p.spec = 0.6
		p.flat_poly(PackedVector2Array([loc.call(6, 3), loc.call(6, -3), loc.call(-7, -3), loc.call(-7, 3)]), DARK_STEEL, Vector3(0.3, 0.2, 1))
		p.flat_poly(PackedVector2Array([loc.call(3.5, -3), loc.call(3.5, -7.5), loc.call(-4.5, -7.5), loc.call(-4.5, -3)]), DARK_STEEL.lightened(0.1), Vector3(0.4, 0.1, 1))
		p.capsule(loc.call(7.5, 3.5), loc.call(7.5, -3.5), 1.1, 1.1, GOLD)
		p.spec = 0.0
		_gauntlet(p, grip, d, Vector2(30, 32))
		_finish(p)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== staff

static func staff_frames() -> Image:
	var poses := [
		[Vector2(96, 78), Vector2(76, 12), Items.FIRE, 0.7],
		[Vector2(86, 74), Vector2(62, 8), Items.FIRE, 1.5],
		[Vector2(93, 77), Vector2(72, 11), Items.FIRE, 0.45],
		[Vector2(86, 74), Vector2(62, 8), Items.FROST, 1.5],
	]
	var frames: Array = []
	for i in poses.size():
		var p := _new(420 + i)
		var grip: Vector2 = poses[i][0]
		var top: Vector2 = poses[i][1]
		var pal: Array = poses[i][2]
		var power: float = poses[i][3]
		var d := (top - grip).normalized()
		var n := Vector2(-d.y, d.x)
		var wood := Color(0.27, 0.19, 0.13)
		# gnarled shaft
		var pts := PackedVector2Array()
		for kk in 14:
			var t := float(kk) / 13.0
			pts.append((grip - d * 44.0).lerp(top - d * 9.0, t) + n * (sin(t * 13.0) * 1.4 + sin(t * 5.0) * 0.8))
		p.strand(pts, 5.0, 3.4, wood, 0.25)
		for kk in 4:
			var t := 0.25 + kk * 0.18
			var bp := (grip - d * 44.0).lerp(top - d * 9.0, t)
			p.ball(bp.x + n.x * 2.2, bp.y + n.y * 2.2, 2.4, 1.8, wood.darkened(0.1))
			p.line(bp - n * 2.5 - d * 4.0, bp + n * 1.5 + d * 6.0, wood.darkened(0.5), 0.5)
		# root claws holding the crystal
		for side in [-1.0, -0.35, 0.35, 1.0]:
			var sd: float = side
			var c0: Vector2 = top - d * 11.0 + n * sd * 2.0
			var c1: Vector2 = top + n * sd * 9.5 - d * 2.5
			var c2: Vector2 = top + n * sd * 5.0 + d * 8.5
			p.strand(PackedVector2Array([c0, c1, c2]), 2.2, 0.7, wood.lightened(0.04))
		p.spec = 0.6
		p.capsule(top - d * 15.0 - n * 4.8, top - d * 15.0 + n * 4.8, 1.8, 1.8, GOLD)
		p.capsule(top - d * 19.0 - n * 4.2, top - d * 19.0 + n * 4.2, 1.3, 1.3, GOLD.darkened(0.2))
		p.spec = 0.0
		# heavy robe sleeve with worn trim
		var sleeve := Color(0.17, 0.17, 0.32)
		p.capsule(grip + Vector2(2, 6), grip + Vector2(64, 66), 12.5, 19.0, sleeve)
		for fl in 4:
			var f0 := grip + Vector2(-4 + fl * 5.0, 12 + fl * 1.5)
			p.line(f0, f0 + Vector2(22, 24), sleeve.darkened(0.45), 0.7)
		p.strand(PackedVector2Array([grip + Vector2(-10, 10), grip + Vector2(0, 2), grip + Vector2(12, -4)]), 1.6, 1.6, GOLD.darkened(0.25))
		# hand with knuckles gripping the shaft
		p.ball(grip.x + 4, grip.y + 3, 9.0, 8.5, SKIN)
		for f in 4:
			var fp := grip + d * (-6.0 + f * 4.0) - n * 0.5
			p.capsule(fp + n * 8.5, fp - n * 3.0, 2.7, 2.3, SKIN)
			p.ball(fp.x + n.x * 2.5, fp.y + n.y * 2.5, 2.4, 2.2, SKIN.lightened(0.05))
			p.line(fp + n * 5.0 - d * 1.6, fp + n * 5.0 + d * 1.6, SKIN.darkened(0.45), 0.5)
		p.capsule(grip + n * 8.0 - d * 8.0, grip - d * 9.5 - n * 2.0, 2.8, 2.4, SKIN)
		_finish(p)
		# crystal (faceted) with magic inside
		var cr := top + d * 1.0
		p.glow(cr.x, cr.y, 20.0 * power, pal[1], 0.5 * power)
		var crp := p.tp(cr)
		Items.orb(p, crp.x, crp.y, (5.0 + power * 2.0) * p.k, float(i) * 1.3, pal)
		p.spec = 1.0
		var facets := [[0.0, -7.0], [5.0, -2.0], [4.0, 5.5], [-4.0, 5.5], [-5.0, -2.0]]
		for fi in facets.size():
			var f0: Array = facets[fi]
			var f1: Array = facets[(fi + 1) % facets.size()]
			p.line(cr + Vector2(f0[0], f0[1]), cr + Vector2(f1[0], f1[1]), Color(1, 1, 1, 0.35), 0.6)
		p.spec = 0.0
		if power > 1.0:
			for kk in 10:
				var a := float(kk) / 10.0 * TAU + i
				p.glow(cr.x + cos(a) * 17, cr.y + sin(a) * 17, 2.6, pal[2], 0.9)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== bow
## Drawn directly in screen pixels (k = 1). The arrow lies on the aim line that runs from
## the nocking hand through the arrow rest on the bow to the crosshair at the screen centre.

const AIM := Vector2(320, 180)
const REST := Vector2(352, 218)
const GLOVE := Color(0.27, 0.2, 0.13)
const BRACER := Color(0.21, 0.19, 0.12)
const SLEEVE := Color(0.18, 0.22, 0.13)
const STITCH := Color(0.55, 0.5, 0.38)


## Hands are built from a few clean shapes with strict 5-tone ramps (outline, shadow, base,
## light, highlight), one light direction (top-left), no grain, 1px dark separations.
const GLOVE_T := [Color(0.07, 0.045, 0.03), Color(0.18, 0.12, 0.075), Color(0.28, 0.195, 0.125), Color(0.39, 0.28, 0.18), Color(0.53, 0.4, 0.26)]
const BRACER_T := [Color(0.06, 0.05, 0.03), Color(0.14, 0.13, 0.08), Color(0.22, 0.2, 0.125), Color(0.31, 0.29, 0.18), Color(0.42, 0.39, 0.26)]
const STRAP_T := [Color(0.04, 0.03, 0.02), Color(0.09, 0.07, 0.045), Color(0.14, 0.1, 0.065), Color(0.2, 0.15, 0.1), Color(0.28, 0.21, 0.14)]
const SLEEVE_T := [Color(0.04, 0.05, 0.03), Color(0.1, 0.13, 0.07), Color(0.16, 0.2, 0.11), Color(0.23, 0.28, 0.16), Color(0.3, 0.36, 0.21)]
const METAL_T := [Color(0.08, 0.08, 0.08), Color(0.3, 0.29, 0.26), Color(0.48, 0.46, 0.4), Color(0.66, 0.63, 0.55), Color(0.85, 0.82, 0.72)]
const HAND_LIGHT := Vector3(-0.55, -0.65, 0.52)


static func _tone(tones: Array, i: float) -> Color:
	if i < 0.12:
		return tones[1]
	if i < 0.5:
		return tones[2]
	if i < 0.83:
		return tones[3]
	return tones[4]


static func _tcapsule(p: Painter, a: Vector2, b: Vector2, r: float, tones: Array) -> void:
	## Clean banded capsule with a 1px outline (later shapes overwrite earlier ones,
	## so their outline becomes the dark separation line).
	var L := HAND_LIGHT.normalized()
	var R := r + 1.0
	var x0 := maxi(int(floor(minf(a.x, b.x) - R)), 0)
	var x1 := mini(int(ceil(maxf(a.x, b.x) + R)), p.w - 1)
	var y0 := maxi(int(floor(minf(a.y, b.y) - R)), 0)
	var y1 := mini(int(ceil(maxf(a.y, b.y) + R)), p.h - 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var pp := Vector2(x + 0.5, y + 0.5)
			var t := clampf((pp - a).dot(ab) / len2, 0.0, 1.0)
			var d := pp - (a + ab * t)
			var dl := d.length()
			if dl > R:
				continue
			if dl > r:
				p.img.set_pixel(x, y, tones[0])
				continue
			var nxy := d / r
			var nz := sqrt(maxf(1.0 - nxy.length_squared(), 0.0))
			p.img.set_pixel(x, y, _tone(tones, Vector3(nxy.x, nxy.y, nz).dot(L)))


static func _tpoly(p: Painter, pts: PackedVector2Array, tones: Array, base_idx: int = 2) -> void:
	## Flat plate: base tone, a light inner edge facing the light, a shadow inner edge opposite, outline.
	var r := Rect2i(Vector2i(int(floor(pts[0].x)), int(floor(pts[0].y))), Vector2i.ZERO)
	for v in pts:
		r = r.expand(Vector2i(int(floor(v.x)), int(floor(v.y))))
	r = r.grow(2)
	var centroid := Vector2.ZERO
	for v in pts:
		centroid += v
	centroid /= float(pts.size())
	for y in range(maxi(r.position.y, 0), mini(r.end.y, p.h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, p.w)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				p.img.set_pixel(x, y, tones[base_idx])
	var light2 := Vector2(-0.6, -0.8)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var e := (b - a).normalized()
		var n := Vector2(-e.y, e.x)
		if n.dot((a + b) * 0.5 - centroid) < 0.0:
			n = -n
		var facing := n.dot(light2)
		if facing > 0.3:
			p.line(a - n * 1.5 + e * 1.5, b - n * 1.5 - e * 1.5, tones[3], 1.0)
		elif facing < -0.3:
			p.line(a - n * 1.5 + e * 1.5, b - n * 1.5 - e * 1.5, tones[1], 1.0)
	for i in pts.size():
		p.line(pts[i], pts[(i + 1) % pts.size()], tones[0], 1.0)


static func _knuckle_glint(p: Painter, at: Vector2, along: Vector2) -> void:
	p.line(at - along * 1.5, at + along * 1.5, GLOVE_T[4], 1.0)


static func _forearm(p: Painter, wrist: Vector2, f: Vector2, r0: float) -> void:
	## Sleeve + leather bracer with two strapped buckles, running off-screen along f.
	var n := Vector2(-f.y, f.x)
	_tcapsule(p, wrist + f * 260.0, wrist + f * 66.0, r0 + 10.0, SLEEVE_T)
	_tcapsule(p, wrist + f * 74.0, wrist + f * 3.0, r0 + 3.0, BRACER_T)
	for s in [22.0, 48.0]:
		var c: Vector2 = wrist + f * float(s)
		var hw := r0 + 2.5 + float(s) * 0.03
		_tcapsule(p, c - n * hw, c + n * hw, 2.4, STRAP_T)
		_tcapsule(p, c + n * (hw * 0.45) - f * 0.5, c + n * (hw * 0.45) + f * 0.5, 2.6, METAL_T)


static func _bow_fist(p: Painter, grip: Vector2, axis: Vector2, left: Vector2) -> void:
	## Left fist on the grip: back of the hand as a tapered plate, four parallel finger bands
	## wrapped around the grip toward the viewer, the thumb laid over the top band.
	var rdir := -left
	var f := Vector2(-0.48, 1.0).normalized()
	var lens := [27.0, 25.5, 24.0, 21.0]
	var centres: Array = []
	for i in 4:
		centres.append(grip + axis * (11.0 - i * 8.6))
	var c0: Vector2 = centres[0]
	var c3: Vector2 = centres[3]
	var k_top := c0 - rdir * 12.0 + axis * 4.5
	var k_bot := c3 - rdir * 12.0 - axis * 4.5
	var w_top := k_top + f * 30.0 - rdir * 6.0
	var w_bot := k_bot + f * 20.0 - rdir * 1.0
	var wrist := (w_top + w_bot) * 0.5
	_forearm(p, wrist, f, 13.0)
	_tpoly(p, PackedVector2Array([k_top, k_bot, w_bot, w_top]), GLOVE_T)
	# seam on the back of the hand
	for i in 5:
		var s := k_top.lerp(w_top, 0.2 + i * 0.15) + (k_bot - k_top).normalized() * 6.0
		p.img.set_pixel(int(s.x), int(s.y), GLOVE_T[3])
	# fingers: pinky first so each upper band's outline separates it from the one below
	for i in range(3, -1, -1):
		var c: Vector2 = centres[i]
		var a := c - rdir * 12.0
		var b := c + rdir * (float(lens[i]) - 12.0)
		_tcapsule(p, a, b, 4.0, GLOVE_T)
		_knuckle_glint(p, a + rdir * 3.0 + axis * 2.6, rdir)
	# thumb: one band laid diagonally over the index band
	var t0 := k_top + f * 13.0 - rdir * 2.0
	var t1 := c0 + rdir * 5.0 + axis * 2.0
	_tcapsule(p, t0, t1, 4.4, GLOVE_T)
	_knuckle_glint(p, t1 - (t1 - t0).normalized() * 3.0 + axis * 2.8, (t1 - t0).normalized())


static func _draw_hand(p: Painter, nock: Vector2, u: Vector2, s_up: Vector2, s_dn: Vector2) -> void:
	## Drawing hand, kept simple: three hooked finger tips crossing the string under the nock
	## (parallel bands perpendicular to the string), back of the hand and wrist as clean planes,
	## forearm leaving through the bottom-right edge.
	var h := -u
	var fd := Vector2(-s_dn.y, s_dn.x)
	if fd.dot(h) < 0.0:
		fd = -fd
	var tips: Array = []
	for j in 3:
		tips.append(nock + s_dn * (5.5 + j * 8.6))
	var t0: Vector2 = tips[0]
	var t2: Vector2 = tips[2]
	var f2 := (h + Vector2(0.15, 0.5)).normalized()
	var k_top := t0 + fd * 15.0 - s_dn * 4.5
	var k_bot := t2 + fd * 15.0 + s_dn * 4.5
	var w_top := k_top + fd * 10.0 + f2 * 16.0
	var w_bot := k_bot + fd * 2.0 + f2 * 12.0
	var wrist := (w_top + w_bot) * 0.5
	_forearm(p, wrist, f2, 12.0)
	_tpoly(p, PackedVector2Array([k_top, w_top, w_bot, k_bot]), GLOVE_T)
	for j in range(2, -1, -1):
		var tp: Vector2 = tips[j]
		_tcapsule(p, tp - fd * 3.0, tp + fd * 15.0, 4.0, GLOVE_T)
		_knuckle_glint(p, tp + fd * 11.0 - s_dn * 2.6, fd)


static func _released_hand(p: Painter, at: Vector2, u: Vector2) -> void:
	## Open hand pulled back: four slightly fanned parallel finger bands, thumb aside.
	var pu := Vector2(-u.y, u.x)
	if pu.x < 0.0:
		pu = -pu
	var lens := [19.0, 23.0, 24.0, 21.0]
	var knuckles: Array = []
	for j in 4:
		knuckles.append(at + pu * (-12.6 + j * 8.4) + u * 6.0)
	var k0: Vector2 = knuckles[0]
	var k3: Vector2 = knuckles[3]
	var w0 := k0 - pu * 2.0 - u * 30.0
	var w3 := k3 + pu * 3.0 - u * 26.0
	var wrist := (w0 + w3) * 0.5
	_forearm(p, wrist, (-u + Vector2(0.25, 0.35)).normalized(), 12.0)
	_tpoly(p, PackedVector2Array([k0 - pu * 4.5, k3 + pu * 4.5, w3, w0]), GLOVE_T)
	for j in 4:
		var k: Vector2 = knuckles[j]
		var d := u.rotated(-0.16 + j * 0.11)
		_tcapsule(p, k, k + d * float(lens[j]), 4.0, GLOVE_T)
		_knuckle_glint(p, k + d * 3.0 - pu * 2.6, d)
	var tb := k0 - pu * 5.0 - u * 14.0
	_tcapsule(p, tb, tb - pu * 15.0 + u * 7.0, 4.4, GLOVE_T)


static func bow_frames() -> Image:
	var wood := Color(0.31, 0.2, 0.12)
	var u := (AIM - REST).normalized()
	var axis := Vector2(-0.3, -1.0).normalized()   # bow axis, upper limb leaning left
	var left := Vector2(axis.y, -axis.x)            # perpendicular pointing to the left
	if left.x > 0.0:
		left = -left
	var frames: Array = []
	for i in 3:
		var p := Painter.new(FW, FH, 440 + i)
		p.set_real(1.0)
		p.grain = 0.08
		var draw: float = [80.0, 150.0, 0.0][i]
		var bend := 34.0 + draw * 0.08
		var grip := REST + Vector2(4, 14)
		var mid := grip - left * 4.0
		var half := 225.0
		var top_tip := mid + axis * half - left * bend + (-u) * draw * 0.06
		var bot_tip := mid - axis * half - left * bend + (-u) * draw * 0.06
		var nock := REST - u * draw
		# string (behind the limbs and hands)
		var sc := Color(0.8, 0.78, 0.7)
		if i == 2:
			p.line(top_tip, bot_tip, sc, 1.3)
			p.line(top_tip + left * 3.0, bot_tip + left * 3.0, Color(0.8, 0.78, 0.7, 0.35), 1.0)
		else:
			p.line(top_tip, nock, sc, 1.3)
			p.line(nock, bot_tip, sc, 1.3)
		# laminated limbs with horn tips
		var lim := PackedVector2Array()
		for kk in 25:
			var t := float(kk) / 24.0
			lim.append(top_tip.lerp(bot_tip, t) + left * sin(t * PI) * bend)
		for kk in 24:
			var t0 := float(kk) / 24.0
			var thick := 5.5 + sin(t0 * PI) * 7.0
			p.capsule(lim[kk], lim[kk + 1], thick, thick, wood)
		for kk in 22:
			p.line(lim[kk] - left * 3.0, lim[kk + 1] - left * 3.0, wood.lightened(0.16), 1.0)
		for tip in [top_tip, bot_tip]:
			var tv: Vector2 = tip
			p.capsule(tv, tv - left * 8.0 + (Vector2(0, 5) if tv.y < 180 else Vector2(0, -5)), 4.0, 2.4, Color(0.55, 0.5, 0.42))
		# leather grip wrap, then the bow hand around it
		p.capsule(mid + axis * 20.0, mid - axis * 20.0, 10.0, 10.0, LEATHER.darkened(0.15))
		_bow_fist(p, mid, axis, left)
		# arrow on the aim line: nock -> rest -> broadhead just short of the crosshair
		if i < 2:
			var tip_p := REST + u * 30.0
			var tail := nock
			p.capsule(tail, tip_p, 3.0, 2.6, Color(0.56, 0.43, 0.27))
			var an := Vector2(-u.y, u.x)
			p.spec = 0.9
			p.grad_poly(PackedVector2Array([tip_p - u * 4.0 + an * 7.0, tip_p + u * 20.0, tip_p - u * 4.0 - an * 7.0]), Color(0.5, 0.52, 0.56), tip_p, an, 7.0, 0.6, 1.2, 3.0)
			p.spec = 0.0
			for kk in 7:
				var fp := tail + u * (26.0 + kk * 4.0)
				p.line(fp, fp - u * 7.0 + an * 11.0, Color(0.55, 0.12, 0.1) if kk % 2 == 0 else Color(0.42, 0.08, 0.08), 1.6)
				p.line(fp, fp - u * 7.0 - an * 11.0, Color(0.85, 0.82, 0.75) if kk % 2 == 0 else Color(0.7, 0.68, 0.62), 1.6)
			_draw_hand(p, nock, u, (top_tip - nock).normalized(), (bot_tip - nock).normalized())
		else:
			_released_hand(p, Vector2(500, 300), u)
		_finish(p)
		frames.append(p.img)
	return Painter.strip(frames)
