extends RefCounted
## Monster forge HEAD layer, drawn in the rig head frame (r.hxf): origin = cranium centre,
## y down, neck top at Rig.H_NECK. The rig tilts heads in pain/dying and opens the jaw (r.jaw).

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const RP := preload("res://tools/art/monsters/rp.gd")

const NAMES := ["skull", "horned_skull", "hood", "helm", "crowned_skull", "wolf_skull"]

const BONE := RP.BONE
const VOID := RP.VOID
const HORN := Color(0.47, 0.4, 0.31)
const SOUL := Color(0.45, 1.0, 0.55)
const EMBER := Color(1.0, 0.45, 0.14)
const ARCANE := Color(0.85, 0.55, 1.0)
const FROST := Color(0.55, 0.85, 1.0)
const LICH := Color(0.5, 0.95, 0.85)
const AMBER := Color(1.0, 0.74, 0.26)


static func draw(name: String, p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	p.xf = Rig.sub(r, "hxf")
	var jaw: float = r["jaw"]
	match name:
		"skull":
			skull_shape(p, jaw, SOUL, glows)
		"horned_skull":
			for s in [-1.0, 1.0]:
				_horn(p, s)
			skull_shape(p, jaw, EMBER, glows, BONE.darkened(0.06))
		"hood":
			_hood(p, glows)
		"helm":
			_helm(p, glows)
		"crowned_skull":
			skull_shape(p, jaw, LICH, glows, BONE.lightened(0.03))
			_crown(p)
		"wolf_skull":
			_wolf(p, jaw, glows)
	p.xf = r["xf"]
	if name in ["skull", "horned_skull", "crowned_skull", "wolf_skull"]:
		p.grime(RP.BONE_DIRT, 0.5, 0.13, 0.08, 0.5, 511)
	elif name == "helm":
		p.grime(RP.RUST, 0.6, 0.11, 0.05, 0.5, 512)
	else:
		p.grime(Color(0.1, 0.08, 0.07), 0.4, 0.12, 0.1, 0.8, 513)
	return glows


# =============================================================================== skulls

static func skull_shape(p: Painter, jaw: float, eye: Color, glows: Array, c: Color = BONE, s: float = 1.0) -> void:
	## Human skull, front view, cranium centre at the local origin.
	RP.oval(p, Vector2(0, 0), 5.5 * s, 6.3 * s, c)
	RP.oval(p, Vector2(-4.0 * s, 0.5 * s), 1.5 * s, 2.6 * s, c.darkened(0.25))
	RP.oval(p, Vector2(4.0 * s, 0.5 * s), 1.5 * s, 2.6 * s, c.darkened(0.1))
	RP.oval(p, Vector2(-3.2 * s, 2.6 * s), 1.7 * s, 1.2 * s, c)
	RP.oval(p, Vector2(3.2 * s, 2.6 * s), 1.7 * s, 1.2 * s, c)
	RP.oval(p, Vector2(0, 4.0 * s), 3.1 * s, 1.7 * s, c)
	var jy := (6.6 + jaw) * s
	RP.oval(p, Vector2(0, jy), 3.3 * s, 1.6 * s, c)
	p.capsule(Vector2(-3.4 * s, 3.4 * s), Vector2(-2.6 * s, jy), 0.8 * s, 0.8 * s, c)
	p.capsule(Vector2(3.4 * s, 3.4 * s), Vector2(2.6 * s, jy), 0.8 * s, 0.8 * s, c)
	if jaw > 0.5:
		RP.blot(p, Vector2(0, 5.6 * s + jaw * 0.5 * s), 2.2 * s, jaw * 0.5 * s, VOID)
	for i in 6:
		var tx := -2.5 * s + i * s
		p.rect(tx, 4.7 * s, 0.7 * s, 0.9 * s, Color(0.78, 0.74, 0.6))
		p.rect(tx, jy - 1.4 * s, 0.7 * s, 0.8 * s, Color(0.7, 0.66, 0.54))
	RP.blot(p, Vector2(-2.3 * s, 0.7 * s), 1.75 * s, 1.85 * s, VOID)
	RP.blot(p, Vector2(2.3 * s, 0.7 * s), 1.75 * s, 1.85 * s, VOID)
	p.poly(PackedVector2Array([Vector2(-0.9 * s, 2.3 * s), Vector2(0.9 * s, 2.3 * s), Vector2(0, 3.7 * s)]), VOID)
	# brow ridge catching the light
	p.strand(PackedVector2Array([Vector2(-4.2 * s, -1.2 * s), Vector2(-2.3 * s, -1.7 * s), Vector2(-0.6 * s, -1.0 * s)]), 0.45 * s, 0.4 * s, c.lightened(0.12))
	p.strand(PackedVector2Array([Vector2(0.6 * s, -1.0 * s), Vector2(2.3 * s, -1.7 * s), Vector2(4.2 * s, -1.2 * s)]), 0.45 * s, 0.4 * s, c.lightened(0.05))
	# crack across the cranium
	p.line(Vector2(1.0 * s, -5.6 * s), Vector2(2.2 * s, -3.4 * s), c.darkened(0.55))
	p.line(Vector2(2.2 * s, -3.4 * s), Vector2(1.6 * s, -2.2 * s), c.darkened(0.55))
	_eyes(p, Vector2(-2.3 * s, 0.8 * s), Vector2(2.3 * s, 0.8 * s), eye, glows, 1.8 * s)


static func _eyes(p: Painter, a: Vector2, b: Vector2, eye: Color, glows: Array, rad: float = 1.8, strength: float = 0.9) -> void:
	for e in [a, b]:
		var q := p.tp(e)
		p.put(int(q.x), int(q.y), eye.lightened(0.5))
		glows.append([q, rad * p.k, eye, strength])


static func _horn(p: Painter, s: float) -> void:
	var pts := PackedVector2Array([Vector2(s * 4.2, -2.6), Vector2(s * 8.4, -4.4), Vector2(s * 12.0, -6.2), Vector2(s * 14.4, -8.8), Vector2(s * 15.2, -12.0)])
	p.strand(pts, 2.7, 0.5, HORN)
	# underside shadow and faint growth rings
	p.strand(PackedVector2Array([pts[0] + Vector2(0, 1.4), pts[1] + Vector2(0, 1.6), pts[2] + Vector2(0, 1.2)]), 0.7, 0.45, HORN.darkened(0.4))
	for i in 4:
		var t := 0.15 + i * 0.16
		var seg_i := int(t * 4.0)
		var f := t * 4.0 - seg_i
		var c := pts[seg_i].lerp(pts[seg_i + 1], f)
		var d := (pts[seg_i + 1] - pts[seg_i]).normalized()
		var n := Vector2(-d.y, d.x)
		var w := lerpf(2.4, 1.0, t)
		p.line(c + n * w * 0.8, c - n * w * 0.8, HORN.darkened(0.28))
	p.capsule(pts[3], pts[4], 0.8, 0.4, HORN.lightened(0.35))


# =============================================================================== crown

static func _crown(p: Painter) -> void:
	var gold := RP.GOLD.darkened(0.08)
	p.spec = 0.6
	# points first (behind the band's lower edge)
	var xs := [-5.2, -2.6, 0.0, 2.6, 5.2]
	var hs := [3.4, 4.4, 5.4, 4.4, 3.4]
	for i in 5:
		var x: float = xs[i]
		var hgt: float = hs[i]
		var w := 1.25
		RP.facet(p, PackedVector2Array([Vector2(x - w, -5.0), Vector2(x, -5.0), Vector2(x, -5.0 - hgt)]), gold, Vector3(-0.7, -0.3, 0.6))
		RP.facet(p, PackedVector2Array([Vector2(x, -5.0), Vector2(x + w, -5.0), Vector2(x, -5.0 - hgt)]), gold.darkened(0.3), Vector3(0.6, -0.2, 0.7))
		RP.oval(p, Vector2(x, -5.4 - hgt), 0.7, 0.7, gold.lightened(0.1))
	var band := PackedVector2Array([Vector2(-6.4, -6.2), Vector2(6.4, -6.2), Vector2(6.1, -2.8), Vector2(-6.1, -2.8)])
	RP.cyl(p, band, gold, Vector2(0, -6.2), Vector2(0, -2.8), 6.4, -0.2)
	p.spec = 0.0
	p.line(Vector2(-6.2, -6.0), Vector2(6.2, -6.0), gold.lightened(0.3))
	p.line(Vector2(-6.0, -3.0), Vector2(6.0, -3.0), gold.darkened(0.5))
	# dull gems
	p.spec = 0.8
	RP.oval(p, Vector2(0, -4.5), 1.0, 1.0, Color(0.45, 0.07, 0.08))
	RP.oval(p, Vector2(-3.6, -4.5), 0.7, 0.7, Color(0.12, 0.35, 0.2))
	RP.oval(p, Vector2(3.6, -4.5), 0.7, 0.7, Color(0.12, 0.35, 0.2))
	p.spec = 0.0


# =============================================================================== hood

const HOOD := Color(0.23, 0.2, 0.18)


static func _hood(p: Painter, glows: Array) -> void:
	# capelet draped over the neck and inner shoulders
	var drape := PackedVector2Array([Vector2(-6.8, 2), Vector2(6.8, 2), Vector2(9.2, 8), Vector2(10.4, 12.2), Vector2(6.4, 14.6), Vector2(0, 15.6), Vector2(-6.4, 14.6), Vector2(-10.4, 12.2), Vector2(-9.2, 8)])
	RP.cyl(p, drape, HOOD.darkened(0.05), Vector2(0, 2), Vector2(0, 15), 10.0, -0.35, 0.0, 1.2, 0.35)
	# hood mass + peak
	RP.oval(p, Vector2(0, -0.6), 7.4, 8.4, HOOD.darkened(0.1))
	RP.cyl(p, PackedVector2Array([Vector2(-6.6, -4.0), Vector2(6.6, -4.0), Vector2(3.4, -9.0), Vector2(1.2, -10.8), Vector2(-1.4, -10.2), Vector2(-4.8, -7.6)]), HOOD.darkened(0.1), Vector2(0, -11), Vector2(0, -4), 6.4, -0.4, 0.0, 1.0, 0.3)
	# deep opening
	RP.blot(p, Vector2(0, 1.4), 4.6, 5.8, VOID)
	RP.blot(p, Vector2(0, 5.6), 3.4, 2.4, VOID)
	# hint of a gaunt chin in the dark
	RP.oval(p, Vector2(0, 4.9), 2.2, 1.6, Color(0.2, 0.17, 0.17))
	p.rect(-1.1, 5.0, 2.2, 0.5, Color(0.06, 0.04, 0.04))
	# rim of the hood around the face
	p.strand(PackedVector2Array([Vector2(-4.9, 7.4), Vector2(-5.4, -0.8), Vector2(0, -5.0), Vector2(5.4, -0.8), Vector2(4.9, 7.4)]), 1.05, 1.05, HOOD)
	p.strand(PackedVector2Array([Vector2(-5.9, 9.0), Vector2(0, 10.6), Vector2(5.9, 9.0)]), 0.9, 0.9, HOOD.darkened(0.15))
	_eyes(p, Vector2(-1.8, 1.4), Vector2(1.8, 1.4), ARCANE, glows, 1.9, 1.0)


# =============================================================================== great helm

static func _helm(p: Painter, glows: Array) -> void:
	var iron := RP.IRON.lightened(0.04)
	var shell := PackedVector2Array([Vector2(-6.6, -7.4), Vector2(6.6, -7.4), Vector2(7.3, -4.2), Vector2(7.3, 6.4), Vector2(5.8, 9.8), Vector2(-5.8, 9.8), Vector2(-7.3, 6.4), Vector2(-7.3, -4.2)])
	p.spec = 0.55
	RP.cyl(p, shell, iron, Vector2(0, -8), Vector2(0, 10), 7.3, -0.15)
	RP.oval(p, Vector2(0, -7.4), 6.6, 1.9, iron.lightened(0.05))
	# brow band and the cross reinforcement
	RP.cyl(p, PackedVector2Array([Vector2(-7.4, -4.4), Vector2(7.4, -4.4), Vector2(7.4, -2.6), Vector2(-7.4, -2.6)]), iron.darkened(0.08), Vector2(0, -4.4), Vector2(0, -2.6), 7.4, -0.2)
	RP.cyl(p, PackedVector2Array([Vector2(-0.9, -7.6), Vector2(0.9, -7.6), Vector2(0.9, 9.8), Vector2(-0.9, 9.8)]), iron.lightened(0.08), Vector2(0, -8), Vector2(0, 10), 1.6, -0.2)
	p.spec = 0.0
	# eye slit with a cold glint
	p.rect(-6.4, -1.9, 5.5, 1.5, VOID)
	p.rect(0.9, -1.9, 5.5, 1.5, VOID)
	# breaths
	for i in 3:
		for j in 2:
			RP.dot(p, Vector2(2.4 + i * 1.3, 3.0 + j * 1.6), VOID)
	# rivets and the bottom flare
	for i in 6:
		RP.dot(p, Vector2(-5.8 + i * 2.32, -3.5), iron.lightened(0.5))
	p.strand(PackedVector2Array([Vector2(-5.8, 9.6), Vector2(0, 10.4), Vector2(5.8, 9.6)]), 0.6, 0.6, iron.darkened(0.3))
	# dent
	RP.blot(p, Vector2(-4.0, -6.0), 1.2, 0.8, iron.darkened(0.35))
	p.line(Vector2(-5.0, -6.6), Vector2(-3.4, -6.6), iron.lightened(0.3))
	_eyes(p, Vector2(-3.0, -1.2), Vector2(3.0, -1.2), FROST, glows, 1.5, 0.8)


# =============================================================================== wolf skull

static func _wolf(p: Painter, jaw: float, glows: Array) -> void:
	## Beast skull in three-quarter view: broad cranium facing us, long muzzle swung down-right
	## so its tooth row and fangs read in profile.
	var c := BONE.darkened(0.03)
	var tooth := Color(0.84, 0.8, 0.66)
	var j := jaw * 1.4
	var head_xf := p.xf
	var mz := head_xf * Transform2D(0.42, Vector2(0.6, -0.6))
	# ---- lower jaw (behind the muzzle), opens with r.jaw
	p.xf = mz * Transform2D(j * 0.09, Vector2(-1.2, 1.0))
	RP.cyl(p, PackedVector2Array([Vector2(-3.4, 0), Vector2(1.8, 0), Vector2(1.6, 9.0), Vector2(0.6, 11.4), Vector2(-1.4, 11.2), Vector2(-2.6, 6.0)]), c.darkened(0.2), Vector2(-0.8, 0), Vector2(-0.4, 11), 2.6, -0.3)
	for i in 4:
		p.rect(0.9, 3.0 + i * 2.0, 0.8, 1.0, tooth.darkened(0.15))
	p.strand(PackedVector2Array([Vector2(0.6, 10.4), Vector2(1.6, 8.8), Vector2(2.2, 7.6)]), 0.6, 0.15, tooth)
	# ---- cranium, crest, cheek arches, brow
	p.xf = head_xf
	RP.oval(p, Vector2(0, -3.4), 6.2, 4.2, c)
	p.strand(PackedVector2Array([Vector2(0, -8.2), Vector2(0.2, -5.2), Vector2(0.4, -2.0)]), 0.7, 0.5, c.lightened(0.14))
	RP.oval(p, Vector2(-6.4, 0.2), 2.6, 1.6, c.darkened(0.2), 0.45)
	RP.oval(p, Vector2(6.6, 0.6), 2.4, 1.5, c.darkened(0.1), -0.3)
	RP.oval(p, Vector2(-3.4, -1.8), 2.8, 1.3, c, -0.3)
	RP.oval(p, Vector2(3.2, -1.8), 2.8, 1.3, c, 0.3)
	# ---- muzzle: tapered, swung toward screen-right
	p.xf = mz
	var snout := PackedVector2Array([Vector2(-4.2, -0.6), Vector2(4.0, -0.6), Vector2(3.0, 4.0), Vector2(2.2, 9.6), Vector2(1.2, 11.8), Vector2(-1.4, 11.8), Vector2(-2.4, 9.0), Vector2(-3.4, 4.0)])
	RP.cyl(p, snout, c, Vector2(0, -0.5), Vector2(0, 11.5), 3.8, -0.4)
	p.line(Vector2(-0.4, 0.4), Vector2(-0.2, 9.4), c.lightened(0.22))
	p.line(Vector2(2.0, 1.8), Vector2(1.6, 9.6), c.darkened(0.35))
	# upper tooth row along the near side + big fang
	for i in 4:
		p.rect(2.0, 3.0 + i * 1.9, 0.8, 1.1, tooth)
	p.strand(PackedVector2Array([Vector2(1.6, 9.6), Vector2(2.6, 12.0), Vector2(2.2, 14.6)]), 1.05, 0.25, tooth)
	p.strand(PackedVector2Array([Vector2(-1.6, 10.0), Vector2(-1.8, 12.0), Vector2(-1.4, 13.6)]), 0.8, 0.2, tooth.darkened(0.15))
	# nose cavity at the tip
	p.poly(PackedVector2Array([Vector2(-1.4, 9.4), Vector2(1.2, 9.4), Vector2(0.8, 11.2), Vector2(-1.0, 11.2)]), VOID)
	# ---- deep slanted sockets
	p.xf = head_xf
	RP.blot(p, Vector2(-3.6, -0.8), 1.7, 2.0, VOID, 0.6)
	RP.blot(p, Vector2(3.4, -0.8), 1.6, 1.9, VOID, -0.6)
	_eyes(p, Vector2(-3.5, -0.7), Vector2(3.3, -0.7), AMBER, glows, 1.8, 0.95)
