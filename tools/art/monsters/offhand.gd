extends RefCounted
## Monster forge OFF-HAND layer (left hand = screen-left), anchored on the rig's left fist.
## Hanging/held items use the rig's gravity vector (r.down) so they keep hanging while dying.

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const RP := preload("res://tools/art/monsters/rp.gd")
const Heads := preload("res://tools/art/monsters/heads.gd")

const NAMES := ["shield", "lantern", "skull_orb"]

const FIRE := Color(1.0, 0.62, 0.22)
const SOUL := Color(0.45, 1.0, 0.55)


static func draw(name: String, p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	match name:
		"shield":
			_shield(p, r)
		"lantern":
			_lantern(p, r, glows)
		"skull_orb":
			_skull_orb(p, r, glows)
	p.xf = r["xf"]
	p.spec = 0.0
	return glows


# =============================================================================== round shield

static func _shield(p: Painter, r: Dictionary) -> void:
	var lhd: Vector2 = r["lhd"]
	var lel: Vector2 = r["lel"]
	var fd := (lel - lhd).normalized()
	var c := lhd + fd * 3.4 + Vector2(1.2, -0.6)
	var wood := Color(0.29, 0.2, 0.13)
	var rx := 8.4
	var ry := 9.0
	RP.oval(p, c, rx, ry, wood)
	# planks
	for k in 4:
		var x := -6.3 + k * 4.2
		var hh := ry * sqrt(maxf(1.0 - (x / rx) * (x / rx), 0.0)) - 0.4
		p.line(c + Vector2(x, -hh), c + Vector2(x, hh), wood.darkened(0.6))
	# faded painted band
	for yy in range(-8, 9):
		var y := float(yy)
		var hw := rx * sqrt(maxf(1.0 - (y / ry) * (y / ry), 0.0)) - 1.0
		var x0 := -2.2 + y * 0.35
		for xi in range(int(floor(x0)), int(floor(x0 + 3.0))):
			if absf(float(xi)) < hw and (xi + yy) % 3 != 0:
				RP.dot(p, c + Vector2(float(xi), y), Color(0.34, 0.09, 0.07).lerp(wood, 0.35))
	# crack and gouges
	p.line(c + Vector2(2.6, -6.8), c + Vector2(4.4, -1.6), RP.VOID)
	p.line(c + Vector2(4.4, -1.6), c + Vector2(3.6, 2.6), RP.VOID)
	p.line(c + Vector2(-5.0, 3.0), c + Vector2(-2.6, 5.8), wood.lightened(0.2))
	# iron rim + studs
	p.spec = 0.5
	for a in 26:
		var t := float(a) / 26.0 * TAU
		var q := c + Vector2(cos(t) * (rx - 0.6), sin(t) * (ry - 0.6))
		p.ball(q.x, q.y, 1.05, 1.05, RP.RUST if a % 2 == 0 else RP.IRON)
	# boss
	RP.oval(p, c, 2.8, 2.9, RP.IRON.lightened(0.05))
	RP.oval(p, c + Vector2(-0.5, -0.6), 1.1, 1.1, RP.IRON.lightened(0.3))
	p.spec = 0.0
	p.grime(Color(0.12, 0.09, 0.06), 0.4, 0.13, 0.1, 0.3, 711)


# =============================================================================== lantern

static func _lantern(p: Painter, r: Dictionary, glows: Array) -> void:
	var lhd: Vector2 = r["lhd"]
	var down: Vector2 = r["down"]
	var iron := RP.IRON.darkened(0.15)
	p.xf = (r["xf"] as Transform2D) * Transform2D(down.angle() - PI * 0.5, lhd)
	# bail through the fist
	p.strand(PackedVector2Array([Vector2(-2.3, 2.0), Vector2(-2.0, 3.4), Vector2(-1.4, 4.6)]), 0.5, 0.5, iron)
	p.strand(PackedVector2Array([Vector2(2.3, 2.0), Vector2(2.0, 3.4), Vector2(1.4, 4.6)]), 0.5, 0.5, iron)
	# cap with a ring
	p.spec = 0.4
	RP.facet(p, PackedVector2Array([Vector2(-1.8, 4.4), Vector2(1.8, 4.4), Vector2(3.4, 6.6), Vector2(-3.4, 6.6)]), iron, Vector3(-0.2, -0.6, 0.8))
	RP.oval(p, Vector2(0, 4.0), 1.0, 0.7, iron.lightened(0.1))
	# glowing panes
	var pane := Color(1.0, 0.78, 0.36)
	for yy in range(7, 13):
		for xx in range(-3, 3):
			var t := absf(float(yy) - 9.8) / 3.0 + absf(float(xx) + 0.5) / 3.0
			RP.dot(p, Vector2(float(xx) + 0.5, float(yy) + 0.5), pane.lerp(Color(0.75, 0.33, 0.08), clampf(t * 0.7, 0.0, 1.0)))
	# frame bars
	for bx in [-3.2, 0.0, 3.2]:
		p.line(Vector2(bx, 6.6), Vector2(bx, 13.2), iron.darkened(0.2) if bx != 0.0 else iron)
	p.line(Vector2(-3.4, 6.8), Vector2(3.4, 6.8), iron.lightened(0.15))
	p.line(Vector2(-3.4, 13.0), Vector2(3.4, 13.0), iron)
	# flame
	RP.blot(p, Vector2(0, 9.9), 0.9, 1.6, Color(1.0, 0.95, 0.7))
	# base
	RP.facet(p, PackedVector2Array([Vector2(-3.4, 13.2), Vector2(3.4, 13.2), Vector2(2.4, 15.0), Vector2(-2.4, 15.0)]), iron, Vector3(0.1, 0.5, 0.8))
	p.spec = 0.0
	var fq := p.tp(Vector2(0, 9.9))
	glows.append([fq, 7.5 * p.k, FIRE, 1.1])
	glows.append([fq, 3.0 * p.k, Color(1.0, 0.92, 0.6), 0.9])


# =============================================================================== skull held up, glowing

static func _skull_orb(p: Painter, r: Dictionary, glows: Array) -> void:
	var lhd: Vector2 = r["lhd"]
	var down: Vector2 = r["down"]
	var bxf: Transform2D = r["xf"]
	var c := lhd - down * 5.6
	var sc := 0.8
	var k0 := p.k
	p.xf = bxf * Transform2D(down.angle() - PI * 0.5, Vector2(sc, sc), 0.0, c)
	p.k = k0 * sc
	var eye_glows: Array = []
	Heads.skull_shape(p, 0.6, SOUL, eye_glows, RP.BONE.lightened(0.05), 1.0)
	p.k = k0
	for g in eye_glows:
		glows.append([g[0], 1.3 * k0, SOUL, 0.8])
	var cq := p.tp(Vector2(0, 1.0))
	# ghost-fire licking up from the cranium
	p.xf = Transform2D.IDENTITY
	var up := -((bxf.basis_xform(down)).normalized())
	var f: int = r["frame"]
	for i in 3:
		var base := cq + up * 4.6 + Vector2(-2.2 + i * 2.2, 0)
		var ln := 2.2 + float((f + i * 2) % 3) * 1.0
		var side := Vector2(-up.y, up.x)
		var tip := base + up * ln + side * (float((f + i) % 3) - 1.0) * 0.8
		p.poly(PackedVector2Array([base - side * 0.9, base + side * 0.9, tip]), SOUL.darkened(0.25))
		p.put(int(tip.x), int(tip.y), SOUL.lightened(0.4))
	glows.append([cq + up * 4.0, 5.0 * k0, SOUL, 0.35])
	p.xf = bxf
	p.grime(RP.BONE_DIRT, 0.4, 0.15, 0.15, 0.3, 721)
