extends RefCounted
## Monster forge drawing helpers: shaded primitives that honour ANY affine Painter.xf (the rig
## rotates bodies while dying and lays them down, rotated + squashed, for the corpse), plus the
## shared material palette. Normals are computed in local space and carried through xf, so the
## key light stays upper-left on screen whatever the pose.

const Painter := preload("res://tools/art/painter.gd")

# ---- natural material palette (the game may tint whole sprites for elites)
const BONE := Color(0.68, 0.62, 0.5)
const BONE_DIRT := Color(0.3, 0.23, 0.15)
const VOID := Color(0.035, 0.03, 0.04)
const IRON := Color(0.34, 0.34, 0.37)
const STEEL := Color(0.45, 0.45, 0.48)
const DARK_STEEL := Color(0.22, 0.22, 0.25)
const RUST := Color(0.38, 0.22, 0.13)
const LEATHER := Color(0.27, 0.18, 0.11)
const WOOD := Color(0.32, 0.21, 0.13)
const GOLD := Color(0.62, 0.48, 0.22)
const BLOOD := Color(0.32, 0.03, 0.04)
const LINEN := Color(0.4, 0.35, 0.27)
const MAIL := Color(0.33, 0.33, 0.35)


# =============================================================================== transforms

static func _n(p: Painter, nl: Vector2, nz: float) -> Vector3:
	## Local normal (xy part nl) -> screen normal.
	var l := nl.length()
	var v := p.xf.basis_xform(nl)
	if l > 1e-5 and v.length_squared() > 1e-10:
		v = v.normalized() * l
	return Vector3(v.x, v.y, nz)


static func _box(p: Painter, c: Vector2, rad: float) -> Rect2i:
	var pts := PackedVector2Array()
	for v in [Vector2(-rad, -rad), Vector2(rad, -rad), Vector2(rad, rad), Vector2(-rad, rad)]:
		pts.append(p.tp(c + v))
	return p._bounds(pts)


static func _screen(p: Painter, pts: PackedVector2Array) -> PackedVector2Array:
	var t := PackedVector2Array()
	for v in pts:
		t.append(p.tp(v))
	return t


# =============================================================================== shaded primitives

static func oval(p: Painter, c: Vector2, rx: float, ry: float, base: Color, rot: float = 0.0, rough: float = 0.0) -> void:
	## Shaded ellipsoid in local space (rotated by rot), correct under rotation/squash.
	var ix := p.xf.affine_inverse()
	var bb := _box(p, c, maxf(rx, ry) + 0.5)
	var cr := cos(rot)
	var sr := sin(rot)
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			var q := ix * Vector2(x + 0.5, y + 0.5) - c
			var dx := (q.x * cr + q.y * sr) / rx
			var dy := (-q.x * sr + q.y * cr) / ry
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				var nl := Vector2(dx * cr - dy * sr, dx * sr + dy * cr)
				var s := p.shade_value(_n(p, nl, sqrt(1.0 - d2)), x, y)
				if rough > 0.0:
					s += (p.rng.randf() - 0.5) * rough
				p.put(x, y, p.col(base, s))


static func blot(p: Painter, c: Vector2, rx: float, ry: float, color: Color, rot: float = 0.0) -> void:
	## Flat (unshaded) ellipse in local space: sockets, holes, stains.
	var ix := p.xf.affine_inverse()
	var bb := _box(p, c, maxf(rx, ry) + 0.5)
	var cr := cos(rot)
	var sr := sin(rot)
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			var q := ix * Vector2(x + 0.5, y + 0.5) - c
			var dx := (q.x * cr + q.y * sr) / rx
			var dy := (-q.x * sr + q.y * cr) / ry
			if dx * dx + dy * dy <= 1.0:
				p.put(x, y, color)


static func hole(p: Painter, c: Vector2, rx: float, ry: float, rot: float = 0.0) -> void:
	## Punch a transparent ellipse (local space).
	var ix := p.xf.affine_inverse()
	var bb := _box(p, c, maxf(rx, ry) + 0.5)
	var cr := cos(rot)
	var sr := sin(rot)
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			var q := ix * Vector2(x + 0.5, y + 0.5) - c
			var dx := (q.x * cr + q.y * sr) / rx
			var dy := (-q.x * sr + q.y * cr) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < p.w and y < p.h:
				p.img.set_pixel(x, y, Color(0, 0, 0, 0))


static func limb(p: Painter, a: Vector2, b: Vector2, ra: float, rb: float, base: Color, rough: float = 0.0) -> void:
	## Tapered shaded limb (screen-space capsule: keeps its thickness when the body is squashed).
	p.capsule(a, b, ra, rb, base, rough)


static func chain(p: Painter, pts: PackedVector2Array, r0: float, r1: float, base: Color) -> void:
	p.strand(pts, r0, r1, base)


static func cyl(p: Painter, pts: PackedVector2Array, base: Color, a: Vector2, b: Vector2, hw: float, tilt: float = -0.25, rough: float = 0.0, folds: float = 0.0, fold_amp: float = 0.0) -> void:
	## Local polygon shaded as a cylinder around the axis a->b (half width hw); folds > 0 adds
	## noise-modulated fabric creases. Works under any xf.
	var t := _screen(p, pts)
	var bb := p._bounds(t)
	var ix := p.xf.affine_inverse()
	var d := (b - a).normalized()
	var perp := Vector2(-d.y, d.x)
	if perp.x < 0.0 or (absf(perp.x) < 1e-4 and perp.y > 0.0):
		perp = -perp
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			var sp := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(sp, t):
				continue
			var rel := ix * sp - a
			var u := rel.dot(perp)
			var nx := clampf(u / hw, -0.97, 0.97)
			if fold_amp > 0.0:
				var wob := p.mid_noise(u * 0.6, rel.dot(d) * 0.1) * 2.5
				nx = clampf(nx + sin(u * folds + wob) * fold_amp, -0.97, 0.97)
			var nl := perp * nx + d * tilt
			var n := _n(p, nl, sqrt(maxf(1.0 - nx * nx, 0.0))).normalized()
			var s := p.shade_value(n, x, y)
			if rough > 0.0:
				s += (p.rng.randf() - 0.5) * rough
			p.put(x, y, p.col(base, s))


static func facet(p: Painter, pts: PackedVector2Array, base: Color, n: Vector3) -> void:
	## Flat-lit local polygon with local normal n.
	var t := _screen(p, pts)
	var bb := p._bounds(t)
	var sn := _n(p, Vector2(n.x, n.y), n.z).normalized()
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), t):
				p.put(x, y, p.col(base, p.shade_value(sn, x, y)))


static func band(p: Painter, a: Vector2, b: Vector2, wa: float, wb: float, base: Color, tilt: float = -0.2) -> void:
	## Flat strap / plank from a to b (half widths wa, wb), shaded across its width.
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([a + n * wa, b + n * wb, b - n * wb, a - n * wa])
	var hw := maxf(wa, wb)
	cyl(p, pts, base, a - n * 0.0, b, hw * 1.6, tilt)


static func flat(p: Painter, pts: PackedVector2Array, c: Color) -> void:
	p.poly(pts, c)


static func dot(p: Painter, at: Vector2, c: Color) -> void:
	var q := p.tp(at)
	p.put(int(floor(q.x)), int(floor(q.y)), c)


static func seg(p: Painter, a: Vector2, b: Vector2, c: Color, thick: float = 1.0) -> void:
	p.line(a, b, c, thick)


static func glow(glows: Array, p: Painter, at: Vector2, rad: float, c: Color, strength: float = 1.0) -> void:
	glows.append([p.tp(at), rad * p.k, c, strength])


static func mail(p: Painter, pts: PackedVector2Array, amount: float = 0.3) -> void:
	## Chainmail rings (screen-space stagger) over what is already painted inside pts.
	var t := _screen(p, pts)
	var bb := p._bounds(t)
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), t):
				continue
			var c := p.img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var row := y % 2
			var stagger := (y / 2) % 2
			if row == 0 and (x + stagger) % 2 == 0:
				p.img.set_pixel(x, y, Color(c.r * (1.0 - amount), c.g * (1.0 - amount), c.b * (1.0 - amount), c.a))
			elif row == 1 and (x + stagger) % 2 == 1:
				p.img.set_pixel(x, y, Color(minf(c.r * (1.0 + amount * 0.6), 1.0), minf(c.g * (1.0 + amount * 0.6), 1.0), minf(c.b * (1.0 + amount * 0.6), 1.0), c.a))


static func mail_capsule(p: Painter, a: Vector2, b: Vector2, rad: float, amount: float = 0.3) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * rad
	mail(p, PackedVector2Array([a + n - d * rad, b + n + d * rad, b - n + d * rad, a - n - d * rad]), amount)


# =============================================================================== shared anatomy

static func fist(p: Painter, at: Vector2, dir: Vector2, base: Color, rad: float = 2.3, knuckle: Color = Color(0, 0, 0, 0)) -> void:
	## Closed fist centred on the rig hand; dir = held-weapon axis. Knuckle row faces the viewer.
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	oval(p, at, rad * 1.02, rad * 0.95, base, d.angle())
	var kc := knuckle if knuckle.a > 0.0 else base.darkened(0.55)
	# finger creases across the grip
	for i in 3:
		var o := (float(i) - 1.0) * rad * 0.55
		seg(p, at + d * o + n * rad * 0.15, at + d * o - n * rad * 0.75, kc)
	# thumb wrapped over
	oval(p, at - n * rad * 0.55 - d * rad * 0.45, rad * 0.55, rad * 0.42, base.lightened(0.06), d.angle())


static func open_hand(p: Painter, at: Vector2, dir: Vector2, base: Color, spread: float = 0.9, length: float = 3.4, claw: Color = Color(0, 0, 0, 0)) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	oval(p, at, 1.9, 1.7, base, d.angle())
	for f in 4:
		var off := (float(f) - 1.5) * spread
		var b0 := at + d * 1.2 + n * off * 0.6
		var tip := b0 + d * length + n * off * 0.5
		p.strand(PackedVector2Array([b0, b0.lerp(tip, 0.55) + n * 0.2, tip]), 0.6, 0.42, base)
		if claw.a > 0.0:
			p.strand(PackedVector2Array([tip, tip + d * 1.6 + n * off * 0.2]), 0.42, 0.2, claw)
	p.capsule(at + n * 1.5, at + n * 2.5 + d * 1.5, 0.6, 0.5, base)


static func wrist_of(r: Dictionary, side: String, back: float = 2.0) -> Vector2:
	## Point on the forearm just behind the fist.
	var hd: Vector2 = r[side + "hd"]
	var el: Vector2 = r[side + "el"]
	return hd + (el - hd).normalized() * back


static func pool(p: Painter, cx: float, cy: float, rx: float, c: Color) -> void:
	## Screen-space puddle on the floor (call with p.xf = identity).
	p.ellipse(cx, cy, rx, 2.6, c.darkened(0.45))
	p.ellipse(cx - rx * 0.1, cy - 0.3, rx * 0.66, 1.7, c)
