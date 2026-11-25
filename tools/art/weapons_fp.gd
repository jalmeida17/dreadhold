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


static func _rot(v: Vector2, a: float) -> Vector2:
	return v.rotated(a)


static func _finger(p: Painter, pts: PackedVector2Array, r: float, col: Color) -> void:
	## Gloved finger: phalanges as tapered capsules with knuckle joints and creases.
	for i in pts.size() - 1:
		var t := float(i) / float(maxi(pts.size() - 1, 1))
		p.capsule(pts[i], pts[i + 1], r * (1.0 - t * 0.12), r * (0.9 - t * 0.12), col)
	for i in range(1, pts.size() - 1):
		var j := pts[i]
		p.ball(j.x, j.y, r * 0.95, r * 0.9, col.lightened(0.05))
		var d := (pts[i + 1] - pts[i - 1]).normalized()
		var n := Vector2(-d.y, d.x)
		p.line(j + n * r * 0.6, j - n * r * 0.6, col.darkened(0.5), 1.0)


static func _forearm(p: Painter, wrist: Vector2, f: Vector2) -> void:
	## Cloth sleeve + laced leather bracer running from the wrist off-screen along f.
	var n := Vector2(-f.y, f.x)
	var far := wrist + f * 260.0
	p.capsule(far, wrist + f * 74.0, 38.0, 25.0, SLEEVE)
	for i in 4:
		var a := wrist + f * (88.0 + i * 22.0) + n * (-16.0 + i * 10.0)
		p.line(a, a + f * 40.0 + n * 4.0, SLEEVE.darkened(0.45), 1.2)
	p.capsule(wrist + f * 92.0, wrist + f * 6.0, 20.0, 15.5, BRACER)
	for i in 3:
		var c := wrist + f * (24.0 + i * 23.0)
		var hw := 16.0 + i * 1.4
		p.capsule(c - n * hw, c + n * hw, 2.2, 2.2, BRACER.darkened(0.45))
		p.spec = 0.8
		p.flat_poly(PackedVector2Array([c + n * (hw - 6.5) - f * 3.0, c + n * (hw - 2.0) - f * 3.0, c + n * (hw - 2.0) + f * 3.0, c + n * (hw - 6.5) + f * 3.0]), Color(0.42, 0.38, 0.3), Vector3(-0.3, -0.5, 1))
		p.spec = 0.0
	for i in 12:
		var s := wrist + f * (10.0 + i * 7.0) + n * 12.5
		p.line(s, s + f * 3.0, STITCH, 1.0)
	# flared glove cuff
	p.capsule(wrist + f * 3.0 - n * 12.5, wrist + f * 3.0 + n * 12.5, 4.5, 4.5, GLOVE.lightened(0.04))
	p.line(wrist + f * 6.0 - n * 14.5, wrist + f * 6.0 + n * 14.5, GLOVE.darkened(0.5), 1.0)


static func _bow_fist(p: Painter, grip: Vector2, axis: Vector2, left: Vector2) -> void:
	## Left fist closed around the leather grip; knuckles and thumb over the grip.
	var f := Vector2(-0.48, 1.0).normalized()
	var wrist := grip + left * 20.0 + f * 48.0
	_forearm(p, wrist, f)
	# back of the hand (wider than the wrist), seam stitching
	var hand_c := grip + left * 17.0 + f * 14.0
	p.capsule(wrist, hand_c, 17.5, 21.0, GLOVE)
	p.ball(hand_c.x, hand_c.y, 21.0, 19.0, GLOVE)
	for i in 7:
		var s := wrist.lerp(hand_c, float(i) / 6.0) + left * 11.0
		p.tput(s.x, s.y, STITCH)
	# four fingers wrapped across the front of the grip (pinky lowest)
	var sizes := [5.0, 5.8, 6.2, 6.0]
	for j in 4:
		var k := grip + left * 12.0 + axis * (-16.0 + j * 10.5)
		var r: float = sizes[j]
		var col := GLOVE.lightened(0.025 * j)
		var pts := PackedVector2Array([k + left * 2.0, k - left * 9.0 + f * 0.5, k - left * 15.0 + f * 5.0, k - left * 13.5 + f * 11.0])
		_finger(p, pts, r, col)
		p.ball(k.x + left.x * 1.5, k.y + left.y * 1.5, r * 1.12, r * 1.02, GLOVE.lightened(0.1))
		p.line(k + axis * (r + 0.5) + left * 3.0, k + axis * (r + 0.5) - left * 14.0, GLOVE.darkened(0.6), 1.0)
	# thumb resting over the index finger, pointing forward
	var tb := grip + left * 21.0 + axis * 25.0
	var tm := grip + left * 7.0 + axis * 28.5
	var tt := grip - left * 8.0 + axis * 25.5
	_finger(p, PackedVector2Array([tb, tm, tt]), 6.6, GLOVE.lightened(0.07))
	p.ball(tt.x, tt.y, 5.2, 4.8, GLOVE.lightened(0.12))


static func _draw_hand(p: Painter, nock: Vector2, u: Vector2, s_up: Vector2, s_dn: Vector2) -> void:
	## Right hand in a Mediterranean draw: index above the nock, middle + ring below, hooked on the string.
	var h := -u
	var f := (h + Vector2(0.25, 0.35)).normalized()
	var wrist := nock + h * 50.0 + Vector2(4, 8)
	_forearm(p, wrist, f)
	var hand_c := nock + h * 25.0
	p.capsule(wrist, hand_c, 17.5, 20.0, GLOVE)
	p.ball(hand_c.x, hand_c.y, 20.0, 18.5, GLOVE)
	var side := Vector2(-h.y, h.x)
	for i in 7:
		var s := wrist.lerp(hand_c, float(i) / 6.0) - side * 10.0
		p.tput(s.x, s.y, STITCH)
	# thumb tucked down along the jaw, pinky curled into the palm
	var tb := hand_c + s_dn * 13.0 + h * 8.0
	_finger(p, PackedVector2Array([tb, tb + s_dn * 11.0 - h * 2.0, tb + s_dn * 18.0 - h * 7.0]), 6.3, GLOVE.lightened(0.05))
	var pk := nock + s_dn * 29.0 + h * 11.0
	_finger(p, PackedVector2Array([pk + h * 9.0, pk, pk - h * 3.5 + s_up * 3.5]), 4.6, GLOVE.darkened(0.03))
	# three drawing fingers hooked on the string
	var spots := [[s_up, 10.0, 5.8], [s_dn, 9.0, 6.1], [s_dn, 20.0, 5.6]]
	for sp in spots:
		var sd: Vector2 = sp[0]
		var fp := nock + sd * float(sp[1])
		var r: float = sp[2]
		var k := fp + h * 18.0
		_finger(p, PackedVector2Array([k, fp + h * 4.0, fp - h * 3.0, fp + h * 2.0 + sd * 4.0]), r, GLOVE.lightened(0.03))
		p.ball(k.x, k.y, r * 1.12, r * 1.02, GLOVE.lightened(0.1))
	# leather finger tab edge peeking under the fingers
	p.line(nock + s_up * 4.0 - h * 2.0, nock + s_dn * 26.0 - h * 2.0, BRACER.darkened(0.3), 1.6)


static func _released_hand(p: Painter, at: Vector2, u: Vector2) -> void:
	## Open hand flicked back after the release.
	var h := -u
	var f := (h + Vector2(0.35, 0.5)).normalized()
	var wrist := at + h * 42.0
	_forearm(p, wrist, f)
	p.capsule(wrist, at, 17.5, 20.0, GLOVE)
	p.ball(at.x, at.y, 20.0, 18.0, GLOVE)
	var dirs := [-0.6, -0.24, 0.1, 0.42]
	var rs := [5.8, 6.1, 5.7, 4.8]
	var lens := [26.0, 30.0, 27.0, 20.0]
	for j in 4:
		var d := u.rotated(float(dirs[j]))
		var k := at + d * 13.0
		var r: float = rs[j]
		var L: float = lens[j]
		var n := Vector2(-d.y, d.x)
		_finger(p, PackedVector2Array([k, k + d * L * 0.45, k + d * L * 0.8 + n * 2.0, k + d * L + n * 4.5]), r, GLOVE.lightened(0.03))
		p.ball(k.x, k.y, r * 1.12, r * 1.02, GLOVE.lightened(0.1))
	var tb := at + u.rotated(1.2) * 13.0
	var td := u.rotated(1.5)
	_finger(p, PackedVector2Array([tb, tb + td * 12.0, tb + td * 21.0 + td.rotated(-0.5) * 2.5]), 6.3, GLOVE.lightened(0.05))


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
