extends RefCounted
## Monster forge WEAPON layer (right hand). Weapons are drawn in a grip frame: origin = the rig's
## right fist centre, +x toward the business end (default axis r.rdir; long weapons pick their
## own angle per frame but always pass through the fist). The handle is cut where the fist is so
## the body's fingers read as gripping it.

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const RP := preload("res://tools/art/monsters/rp.gd")

const NAMES := ["sword", "axe", "spear", "mace", "greatsword", "bow", "staff", "claws"]

const STEEL := Color(0.56, 0.56, 0.6)
const IRON := Color(0.4, 0.4, 0.43)
const WOOD := RP.WOOD
const LEATHER := RP.LEATHER
const RUST := RP.RUST
const STRING := Color(0.72, 0.7, 0.62)
const SMEAR := Color(0.74, 0.75, 0.78)
const STAFF_GEM := Color(0.42, 1.0, 0.72)


static func draw(name: String, p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	match name:
		"sword":
			_sword(p, r)
		"axe":
			_axe(p, r)
		"spear":
			_spear(p, r)
		"mace":
			_mace(p, r)
		"greatsword":
			_greatsword(p, r)
		"bow":
			_bow(p, r, glows)
		"staff":
			_staff(p, r, glows)
		"claws":
			_claws(p, r)
	p.xf = r["xf"]
	p.spec = 0.0
	return glows


static func _ang(r: Dictionary) -> float:
	return (r["rdir"] as Vector2).angle()


static func _edge_side(r: Dictionary) -> float:
	## Which local side (+y / -y) faces away from the body (strike: the leading edge).
	if int(r["atk"]) == 2:
		return 1.0
	var d: Vector2 = r["rdir"]
	return 1.0 if -d.y > 0.0 else -1.0


static func _gap(p: Painter) -> void:
	RP.hole(p, Vector2.ZERO, 1.9, 2.6)


static func _smear(p: Painter, r: Dictionary, reach: float, width: float = 5.0) -> void:
	## Strike frame motion arc behind the swing (screen space, dithered pale pixels).
	if int(r["atk"]) != 2:
		return
	var tip := p.tp(Vector2(reach, 0))
	var sh: Vector2 = (r["xf"] as Transform2D) * (r["rsh"] as Vector2)
	var rad := sh.distance_to(tip)
	var a1 := (tip - sh).angle()
	p.xf = Transform2D.IDENTITY
	# two thin trailing streaks behind the tip, the outer one longer, fading to sparse pixels
	for band in 2:
		var rr := rad - 1.0 - band * width * 0.45
		var span := 1.15 - band * 0.45
		var steps := int(rr * span * 1.6) + 2
		for i in steps:
			var t := float(i) / float(steps - 1)
			var a := a1 - 0.12 - t * span
			var q := sh + Vector2(cos(a), sin(a)) * rr
			var x := int(q.x)
			var y := int(q.y)
			if t > 0.55 and i % 2 == 1:
				continue
			if p.get_px(x, y).a < 0.5:
				p.put(x, y, SMEAR.darkened(0.08 + t * 0.4 + band * 0.12))


# =============================================================================== one-handed

static func _sword(p: Painter, r: Dictionary) -> void:
	p.xf = Rig.grip(r, _ang(r))
	p.spec = 0.55
	p.blade(Vector2(3.4, 0), Vector2(23.0, 0), 1.8, 0.5, STEEL)
	p.spec = 0.0
	p.line(Vector2(5.0, 0.0), Vector2(17.5, 0.0), STEEL.darkened(0.4))
	p.spec = 0.4
	p.capsule(Vector2(2.8, -3.5), Vector2(2.8, 3.5), 0.8, 0.8, RUST.lightened(0.05))
	RP.oval(p, Vector2(2.8, -3.6), 0.9, 0.9, IRON)
	RP.oval(p, Vector2(2.8, 3.6), 0.9, 0.9, IRON)
	p.capsule(Vector2(-2.4, 0), Vector2(2.2, 0), 0.85, 0.85, LEATHER)
	RP.oval(p, Vector2(-3.3, 0), 1.25, 1.15, IRON)
	p.spec = 0.0
	_gap(p)
	p.grime(RUST, 0.35, 0.14, 0.25, 0.0, 611)
	_smear(p, r, 23.0, 4.5)


static func _axe(p: Painter, r: Dictionary) -> void:
	p.xf = Rig.grip(r, _ang(r))
	var sd := _edge_side(r)
	p.capsule(Vector2(-3.6, 0), Vector2(21.0, 0), 1.0, 0.85, WOOD)
	p.line(Vector2(-2.5, 0.3), Vector2(19, 0.2), WOOD.darkened(0.4))
	p.capsule(Vector2(-2.6, 0), Vector2(1.8, 0), 1.1, 1.1, LEATHER)
	RP.oval(p, Vector2(-4.0, 0), 1.2, 1.1, IRON)
	# bearded head: dark forged cheek, bright curved bit
	var h := func(x: float, y: float) -> Vector2: return Vector2(x, y * sd)
	var head := PackedVector2Array([h.call(15.4, 0.5), h.call(20.4, 0.5), h.call(21.0, 2.6), h.call(23.4, 4.2), h.call(24.4, 6.6), h.call(23.8, 9.4), h.call(21.4, 10.6), h.call(17.6, 11.2), h.call(14.2, 11.6), h.call(14.6, 8.4), h.call(15.8, 4.0)])
	p.spec = 0.4
	RP.facet(p, head, IRON.darkened(0.22), Vector3(-0.3, -0.5 * sd, 0.8))
	var edge := PackedVector2Array([h.call(23.4, 4.2), h.call(24.4, 6.6), h.call(23.8, 9.4), h.call(21.4, 10.6), h.call(17.6, 11.2), h.call(14.2, 11.6), h.call(15.0, 10.0), h.call(18.0, 9.4), h.call(21.0, 8.8), h.call(22.4, 7.4), h.call(22.4, 5.4)])
	p.spec = 0.7
	RP.facet(p, edge, STEEL.lightened(0.12), Vector3(-0.4, -0.6 * sd, 0.7))
	p.spec = 0.0
	p.line(h.call(15.0, 10.4), h.call(22.6, 8.0), STEEL.darkened(0.35))
	# back spike
	RP.facet(p, PackedVector2Array([h.call(16.0, -0.5), h.call(19.6, -0.5), h.call(18.2, -4.4)]), IRON.darkened(0.25), Vector3(0.3, 0.4 * sd, 0.8))
	RP.oval(p, Vector2(17.9, 0), 1.2, 1.5, IRON)
	RP.dot(p, Vector2(17.9, 0), IRON.lightened(0.4))
	_gap(p)
	p.grime(RUST, 0.45, 0.14, 0.15, 0.0, 621)
	_smear(p, r, 22.0, 6.0)


static func _mace(p: Painter, r: Dictionary) -> void:
	p.xf = Rig.grip(r, _ang(r))
	p.spec = 0.35
	p.capsule(Vector2(-3.4, 0), Vector2(14.0, 0), 0.95, 0.9, IRON.darkened(0.15))
	p.capsule(Vector2(-2.6, 0), Vector2(2.0, 0), 1.1, 1.1, LEATHER)
	RP.oval(p, Vector2(-3.9, 0), 1.3, 1.2, IRON)
	for i in 2:
		p.capsule(Vector2(5.0 + i * 4.0, -1.1), Vector2(5.0 + i * 4.0, 1.1), 0.5, 0.5, IRON.lightened(0.1))
	# flanged head
	var c := Vector2(16.8, 0)
	p.spec = 0.5
	for k in 6:
		var a := float(k) / 6.0 * TAU + 0.3
		var o := Vector2(cos(a) * 1.0, sin(a) * 3.2)
		var tipv := c + Vector2(cos(a) * 2.2, sin(a) * 5.4)
		var nn := Vector2(1.3, 0)
		RP.facet(p, PackedVector2Array([c + o - nn, c + o + nn, tipv + nn * 0.6, tipv - nn * 0.6]), IRON.darkened(0.12 if sin(a) > 0 else 0.0), Vector3(0, sin(a), 0.8))
	RP.oval(p, c, 3.0, 3.1, IRON)
	RP.facet(p, PackedVector2Array([c + Vector2(2.4, -1.0), c + Vector2(2.4, 1.0), c + Vector2(6.0, 0)]), IRON.lightened(0.1), Vector3(0.3, -0.4, 0.8))
	p.spec = 0.0
	_gap(p)
	p.grime(RUST, 0.5, 0.15, 0.1, 0.0, 631)
	p.grime(RP.BLOOD, 0.5, 0.2, 0.35, 0.0, 632)
	_smear(p, r, 19.0, 6.0)


# =============================================================================== polearms & two-handers

static func _spear(p: Painter, r: Dictionary) -> void:
	var f: int = r["frame"]
	var ang := _ang(r)
	var fore := 28.0
	var aft := 26.0
	if f <= 1:
		ang = -PI * 0.5 + 0.08
		fore = 30.0
		aft = 36.0
	elif f == 2:
		fore = 23.0
		aft = 30.0
	elif f == 3:
		fore = 28.0
		aft = 22.0
	elif f == 4:
		ang = Vector2(0.35, -1.0).angle()
		fore = 24.0
		aft = 22.0
	elif f == 5:
		ang = Vector2(0.5, -0.87).angle()
		fore = 24.0
		aft = 20.0
	elif f == 6:
		fore = 32.0
		aft = 12.0
	p.xf = Rig.grip(r, ang)
	p.capsule(Vector2(-aft, 0), Vector2(fore, 0), 0.85, 0.75, WOOD)
	p.line(Vector2(-aft + 1.0, 0.3), Vector2(fore - 1.0, 0.25), WOOD.darkened(0.35))
	p.capsule(Vector2(-2.4, 0), Vector2(2.2, 0), 1.05, 1.05, LEATHER)
	RP.oval(p, Vector2(-aft, 0), 1.1, 1.0, IRON)
	# socket, binding and leaf blade
	p.spec = 0.5
	p.capsule(Vector2(fore - 2.6, 0), Vector2(fore + 0.6, 0), 1.1, 0.95, IRON)
	p.line(Vector2(fore - 2.0, -1.2), Vector2(fore - 2.0, 1.2), RUST)
	p.blade(Vector2(fore + 0.4, 0), Vector2(fore + 5.0, 0), 1.9, 1.9, STEEL)
	p.blade(Vector2(fore + 5.0, 0), Vector2(fore + 9.5, 0), 1.9, 0.2, STEEL)
	p.spec = 0.0
	# tattered pennant under the head
	var pn := PackedVector2Array([Vector2(fore - 3.5, 0.9), Vector2(fore - 9.5, 0.9), Vector2(fore - 8.0, 3.6), Vector2(fore - 6.6, 2.6), Vector2(fore - 5.2, 4.2)])
	p.poly(pn, Color(0.32, 0.08, 0.07))
	_gap(p)
	p.grime(RUST, 0.35, 0.14, 0.2, 0.0, 641)


static func _greatsword(p: Painter, r: Dictionary) -> void:
	var f: int = r["frame"]
	var ang := _ang(r)
	if f <= 1:
		ang = Vector2(0.36, 1.0).angle() if f == 0 else Vector2(0.3, 1.0).angle()
	elif f == 2:
		ang = Vector2(0.82, -0.57).angle()
	p.xf = Rig.grip(r, ang)
	p.spec = 0.55
	p.blade(Vector2(4.6, 0), Vector2(33.0, 0), 2.5, 0.8, STEEL)
	p.spec = 0.0
	p.line(Vector2(7.0, 0.0), Vector2(26.0, 0.0), STEEL.darkened(0.45))
	p.line(Vector2(5.0, -0.9), Vector2(8.0, -0.9), STEEL.lightened(0.2))
	# notches in the edge
	RP.hole(p, Vector2(15.0, 2.2), 0.8, 0.9)
	RP.hole(p, Vector2(22.5, -1.7), 0.7, 0.8)
	p.spec = 0.45
	p.capsule(Vector2(3.8, -5.8), Vector2(3.8, 5.8), 1.05, 1.05, IRON)
	RP.oval(p, Vector2(4.8, -6.4), 1.2, 1.2, IRON.darkened(0.1))
	RP.oval(p, Vector2(4.8, 6.4), 1.2, 1.2, IRON.darkened(0.1))
	RP.oval(p, Vector2(4.0, 0), 1.6, 1.9, IRON.lightened(0.08))
	p.capsule(Vector2(-6.8, 0), Vector2(2.8, 0), 0.95, 0.95, LEATHER)
	for i in 4:
		p.line(Vector2(-5.8 + i * 2.2, -1.0), Vector2(-5.0 + i * 2.2, 1.0), LEATHER.darkened(0.5))
	RP.oval(p, Vector2(-8.0, 0), 1.7, 1.5, IRON)
	p.spec = 0.0
	_gap(p)
	p.grime(RUST, 0.4, 0.12, 0.2, 0.0, 651)
	_smear(p, r, 33.0, 6.5)


# =============================================================================== bow

static func _bow_limbs(p: Painter, half: float, bend: float, wood: Color) -> PackedVector2Array:
	## Bow along local x (grip at origin), back bulging toward +y; tips pulled back by bend.
	## Returns the two nock points.
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0 * 2.0 - 1.0
		var x := t * half
		var y := 1.3 * (1.0 - t * t) - bend * t * t
		pts.append(Vector2(x, y))
	p.strand(pts, 1.15, 1.15, wood)
	p.capsule(Vector2(-2.2, 0.9), Vector2(2.2, 0.9), 1.45, 1.45, LEATHER)
	for s in [-1.0, 1.0]:
		var tip := Vector2(s * half, -bend)
		p.capsule(tip, tip + Vector2(s * 1.2, -0.6), 0.75, 0.5, RP.BONE.darkened(0.15))
	return PackedVector2Array([Vector2(-half, -bend - 0.3), Vector2(half, -bend - 0.3)])


static func _arrow(p: Painter, tail: Vector2, head: Vector2) -> void:
	var d := (head - tail).normalized()
	var n := Vector2(-d.y, d.x)
	p.line(tail, head - d * 1.5, Color(0.62, 0.5, 0.34))
	p.spec = 0.6
	p.poly(PackedVector2Array([head, head - d * 3.0 + n * 1.2, head - d * 2.2, head - d * 3.0 - n * 1.2]), IRON.lightened(0.2))
	p.spec = 0.0
	p.line(tail + n * 1.0, tail + d * 3.0 + n * 0.3, Color(0.6, 0.58, 0.5))
	p.line(tail - n * 1.0, tail + d * 3.0 - n * 0.3, Color(0.5, 0.2, 0.15))


static func _bow(p: Painter, r: Dictionary, glows: Array) -> void:
	var f: int = r["frame"]
	var rhd: Vector2 = r["rhd"]
	var bxf: Transform2D = r["xf"]
	var wood := Color(0.36, 0.24, 0.15)
	if f == 2:
		# drawn: string pulled back to the cheek, arrow nocked, bow canted perpendicular to it
		var anchor := Vector2(55.0, 22.5)
		var ad := (rhd - anchor).normalized()
		var bow_ang := ad.angle() - PI * 0.5
		p.xf = bxf * Transform2D(bow_ang, rhd)
		var nocks := _bow_limbs(p, 16.0, 3.4, wood)
		var n0 := p.tp(nocks[0])
		var n1 := p.tp(nocks[1])
		p.xf = bxf
		var ai := bxf.affine_inverse()
		p.line(ai * n0, anchor, STRING)
		p.line(anchor, ai * n1, STRING)
		_arrow(p, anchor + ad * -1.5, rhd + ad * 8.5)
	elif f == 3:
		# released: string straight and humming, arrow gone
		p.xf = bxf * Transform2D(-PI * 0.5 + 0.12, rhd)
		var nocks2 := _bow_limbs(p, 16.0, 0.5, wood)
		p.line(nocks2[0] + Vector2(0, -1.0), nocks2[1] + Vector2(0, -1.0), STRING)
		p.line(nocks2[0] + Vector2(0, -0.2), Vector2(0, -2.4), STRING.darkened(0.25))
		p.line(Vector2(0, -2.4), nocks2[1] + Vector2(0, -0.2), STRING.darkened(0.25))
		p.xf = bxf
		for i in 5:
			var q := rhd + Vector2(5.0 + i * 3.0, -1.0 - i * 0.6)
			RP.dot(p, q, SMEAR.darkened(i * 0.08))
	else:
		var ang := -PI * 0.5 + 0.06
		if f >= 4:
			ang = _ang(r) - PI * 0.5
		p.xf = bxf * Transform2D(ang, rhd)
		var nocks3 := _bow_limbs(p, 16.0, 0.5, wood)
		p.line(nocks3[0] + Vector2(0, -0.4), nocks3[1] + Vector2(0, -0.4), STRING)
	p.xf = bxf * Transform2D(_ang(r), rhd)
	RP.hole(p, Vector2.ZERO, 1.6, 1.6)
	p.xf = bxf
	p.grime(Color(0.15, 0.1, 0.06), 0.3, 0.15, 0.2, 0.0, 661)


# =============================================================================== staff

static func _staff(p: Painter, r: Dictionary, glows: Array) -> void:
	var f: int = r["frame"]
	var ang := _ang(r)
	var fore := 30.0
	var aft := 30.0
	var flare := 1.0
	match f:
		0, 1:
			ang = -PI * 0.5 + 0.05
			fore = 41.0
			aft = 37.0
		2:
			ang = Vector2(0.25, -0.97).angle()
			fore = 15.0
			aft = 43.0
			flare = 1.6
		3:
			ang = Vector2(0.6, -0.8).angle()
			fore = 25.0
			aft = 22.0
			flare = 2.2
		4:
			ang = Vector2(0.45, -0.89).angle()
			fore = 27.0
			aft = 30.0
		5:
			ang = Vector2(0.6, -0.8).angle()
			fore = 24.0
			aft = 24.0
			flare = 0.6
		6:
			fore = 34.0
			aft = 14.0
			flare = 0.25
		7:
			flare = 0.25
	p.xf = Rig.grip(r, ang)
	var wood := Color(0.28, 0.2, 0.14)
	# gnarled shaft
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-aft, fore, t)
		pts.append(Vector2(x, sin(t * 11.0) * 0.45))
	p.strand(pts, 1.0, 1.05, wood)
	for i in 4:
		var kx := lerpf(-aft, fore, 0.15 + i * 0.22)
		RP.oval(p, Vector2(kx, 0.3), 1.2, 1.4, wood.darkened(0.1))
	p.capsule(Vector2(-2.6, 0), Vector2(2.4, 0), 1.25, 1.25, LEATHER.darkened(0.1))
	RP.oval(p, Vector2(-aft, 0), 1.2, 1.1, IRON)
	# claw cradle holding the crystal
	var tip := Vector2(fore + 3.6, 0)
	for s in [-1.0, 0.0, 1.0]:
		p.strand(PackedVector2Array([Vector2(fore - 0.5, s * 0.8), Vector2(fore + 2.2, s * 3.0), Vector2(fore + 5.4, s * 2.4), Vector2(fore + 6.6, s * 0.8)]), 0.7, 0.35, wood.darkened(0.15 if s == 0.0 else 0.0))
	p.spec = 0.9
	RP.oval(p, tip, 2.3, 2.0, STAFF_GEM.darkened(0.2))
	p.spec = 0.0
	var tq := p.tp(tip)
	p.put(int(tq.x), int(tq.y), Color(0.95, 1.0, 0.95))
	glows.append([tq, 4.5 * flare * p.k, STAFF_GEM, 1.25])
	glows.append([tq, 2.0 * p.k, Color(0.9, 1.0, 0.92), 1.0])
	if flare > 1.5:
		# casting rays
		p.xf = Transform2D.IDENTITY
		for k in 8:
			var a := float(k) / 8.0 * TAU + float(f) * 0.4
			var ln := (4.0 + float(k % 2) * 3.0) * flare * 0.8
			p.line(tq + Vector2(cos(a), sin(a)) * 3.0, tq + Vector2(cos(a), sin(a)) * ln, STAFF_GEM.lightened(0.3))
		p.xf = Rig.grip(r, ang)
	_gap(p)
	p.grime(Color(0.12, 0.09, 0.06), 0.35, 0.15, 0.15, 0.4, 671)


# =============================================================================== claws

static func _claws(p: Painter, r: Dictionary) -> void:
	p.xf = Rig.grip(r, _ang(r))
	var horn := Color(0.5, 0.44, 0.34)
	var spread := 1.0 if int(r["atk"]) == 1 else 0.5
	# knuckle-spur bracket strapped over the fist
	p.capsule(Vector2(0.6, -2.6), Vector2(0.6, 2.6), 1.0, 1.0, Color(0.22, 0.17, 0.13))
	for i in 4:
		var o := (float(i) - 1.5)
		var b := Vector2(1.6, o * 1.4)
		var m := Vector2(7.5, o * (1.5 + spread) - 0.6)
		var t := Vector2(13.5 + (1.5 - absf(o)) * 1.2, o * (1.8 + spread * 1.4) + 2.4)
		p.strand(PackedVector2Array([b, m, t]), 1.15, 0.2, horn.darkened(0.15 * absf(o)))
		p.line(b + Vector2(0.6, -0.6), m + Vector2(0, -0.7), horn.lightened(0.3))
		RP.dot(p, t, horn.darkened(0.5))
	p.grime(RP.BLOOD, 0.55, 0.22, 0.2, 0.0, 681)
	_smear(p, r, 15.0, 4.0)
