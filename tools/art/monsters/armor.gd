extends RefCounted
## Monster forge ARMOUR layer: overlays sized to the widest body on the shared rig, so they fit
## every body in every frame. "cape" is an UNDER-BODY layer (stack it before the body).

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const RP := preload("res://tools/art/monsters/rp.gd")

const NAMES := ["rags", "chain", "pauldrons", "cape"]
const UNDER_BODY := ["cape"]


static func draw(name: String, p: Painter, r: Dictionary) -> Array:
	match name:
		"rags":
			return rags(p, r)
		"chain":
			return chain(p, r)
		"pauldrons":
			return pauldrons(p, r)
		"cape":
			return cape(p, r)
	return []


static func _sides() -> Array:
	return [["l", -1.0], ["r", 1.0]]


# =============================================================================== chain

static func chain(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var txf: Transform2D = r["txf"]
	var mail := Color(0.27, 0.27, 0.29)
	# ---- skirt panels following each thigh
	var panels: Array = []
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var hip: Vector2 = r[sd + "hip"]
		var kn: Vector2 = r[sd + "kn"]
		var lo := hip.lerp(kn, 0.6)
		var top_out := txf * Vector2(s * 12.2, 2.0)
		var top_in := txf * Vector2(s * 0.3, 3.0)
		var bot_in := lo + Vector2(-s * 1.6, 0.4)
		var bot_out := lo + Vector2(s * 6.8, -0.6)
		var pts := PackedVector2Array([top_in, top_out, bot_out])
		for j in 4:
			var t := float(j + 1) / 5.0
			pts.append(bot_out.lerp(bot_in, t) + Vector2(0, 1.0 if j % 2 == 0 else -0.6))
		pts.append(bot_in)
		RP.cyl(p, pts, mail.darkened(0.04), (top_in + top_out) * 0.5, lo, 7.0, -0.25)
		panels.append(pts)
	for pts in panels:
		RP.mail(p, pts, 0.42)
	# ---- hauberk body (torso frame)
	p.xf = Rig.sub(r, "txf")
	var shirt := PackedVector2Array([Vector2(-6.5, -27.2), Vector2(6.5, -27.2), Vector2(11.8, -26.0), Vector2(13.8, -22.5), Vector2(13.6, -17), Vector2(12.2, -11), Vector2(11.0, -6), Vector2(11.4, -1), Vector2(12.8, 4.4), Vector2(1.2, 5.0), Vector2(0, 3.2), Vector2(-1.2, 5.0), Vector2(-12.8, 4.4), Vector2(-11.4, -1), Vector2(-11.0, -6), Vector2(-12.2, -11), Vector2(-13.6, -17), Vector2(-13.8, -22.5), Vector2(-11.8, -26.0)])
	p.spec = 0.15
	RP.cyl(p, shirt, mail, Vector2(0, -27), Vector2(0, 4), 12.5, -0.25)
	p.spec = 0.0
	RP.mail(p, shirt, 0.42)
	# hem ring and split
	p.strand(PackedVector2Array([Vector2(-12.6, 4.2), Vector2(-1.2, 4.8)]), 0.55, 0.55, mail.darkened(0.3))
	p.strand(PackedVector2Array([Vector2(1.2, 4.8), Vector2(12.6, 4.2)]), 0.55, 0.55, mail.darkened(0.3))
	# coif collar ring
	p.capsule(Vector2(-6.2, -26.6), Vector2(6.2, -26.6), 1.5, 1.5, mail.lightened(0.08))
	RP.mail(p, PackedVector2Array([Vector2(-7.8, -28.2), Vector2(7.8, -28.2), Vector2(7.8, -25), Vector2(-7.8, -25)]), 0.3)
	# leather belt with an iron buckle
	p.capsule(Vector2(-11.8, -6.0), Vector2(11.8, -6.0), 1.15, 1.15, RP.LEATHER)
	p.spec = 0.6
	RP.oval(p, Vector2(0.5, -6.0), 1.6, 1.4, RP.IRON.lightened(0.15))
	p.spec = 0.0
	RP.dot(p, Vector2(0.5, -6.0), RP.VOID)
	# ---- short sleeves over the upper arms
	p.xf = bxf
	for e in _sides():
		var sd: String = e[0]
		var sh: Vector2 = r[sd + "sh"]
		var el: Vector2 = r[sd + "el"]
		var b := sh.lerp(el, 0.62)
		p.spec = 0.25
		p.capsule(sh, b, 3.6, 3.1, mail)
		p.spec = 0.0
		RP.mail_capsule(p, sh, b, 3.6, 0.42)
		var d := (b - sh).normalized()
		var n := Vector2(-d.y, d.x)
		p.line(b + n * 3.1, b - n * 3.1, mail.darkened(0.35))
	p.grime(RP.RUST, 0.55, 0.1, 0.05, 0.6, 411)
	p.grime(Color(0.08, 0.07, 0.06), 0.35, 0.16, 0.2, 0.3, 412)
	return []


# =============================================================================== pauldrons + belt

static func pauldrons(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var iron := RP.IRON
	# ---- heavy belt (torso frame)
	p.xf = Rig.sub(r, "txf")
	var belt := PackedVector2Array([Vector2(-13.0, -9.2), Vector2(13.0, -9.2), Vector2(13.4, -3.0), Vector2(-13.4, -3.0)])
	RP.cyl(p, belt, RP.LEATHER, Vector2(0, -9), Vector2(0, -3), 13.0, -0.1)
	p.line(Vector2(-13, -8.6), Vector2(13, -8.6), RP.LEATHER.lightened(0.25))
	p.line(Vector2(-13.4, -3.4), Vector2(13.4, -3.4), RP.LEATHER.darkened(0.5))
	p.spec = 0.6
	for i in 6:
		var sx := -11.0 + i * 4.4
		if absf(sx) < 3.5:
			continue
		RP.oval(p, Vector2(sx, -6.1), 0.9, 0.9, iron.lightened(0.2))
	# iron skull buckle
	RP.facet(p, PackedVector2Array([Vector2(-3.6, -10.0), Vector2(3.6, -10.0), Vector2(3.8, -2.2), Vector2(-3.8, -2.2)]), iron, Vector3(-0.2, -0.3, 1))
	RP.oval(p, Vector2(0, -7.0), 2.3, 2.0, RP.BONE.darkened(0.1))
	RP.oval(p, Vector2(0, -4.9), 1.4, 0.9, RP.BONE.darkened(0.2))
	p.spec = 0.0
	RP.blot(p, Vector2(-0.9, -7.0), 0.6, 0.7, RP.VOID)
	RP.blot(p, Vector2(0.9, -7.0), 0.6, 0.7, RP.VOID)
	p.line(Vector2(-3.6, -10), Vector2(3.6, -10), iron.lightened(0.3))
	# ---- shoulder plates following the upper arms
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var sh: Vector2 = r[sd + "sh"]
		var el: Vector2 = r[sd + "el"]
		var ang := (el - sh).angle() - PI * 0.5
		ang = wrapf(ang, -PI, PI) * 0.5
		p.xf = bxf * Transform2D(ang, sh)
		_pauldron(p, s, iron)
	p.xf = bxf
	p.grime(RP.RUST, 0.45, 0.11, 0.2, 0.4, 421)
	return []


static func _pauldron(p: Painter, s: float, iron: Color) -> void:
	## One layered shoulder plate in a local frame (origin = shoulder joint, x outward = s).
	var m := Color(0.47, 0.47, 0.5)
	p.spec = 0.6
	# lower lames first
	RP.oval(p, Vector2(s * 4.0, 5.6), 5.2, 2.2, m.darkened(0.22), s * 0.3)
	RP.oval(p, Vector2(s * 3.2, 3.2), 6.2, 2.5, m.darkened(0.12), s * 0.25)
	# wide flattened dome
	RP.oval(p, Vector2(s * 1.8, -0.4), 7.2, 4.6, m, s * 0.14)
	p.spec = 0.0
	p.strand(PackedVector2Array([Vector2(-s * 4.4, 2.4), Vector2(s * 1.8, 4.0), Vector2(s * 8.6, 2.0)]), 0.45, 0.45, RP.VOID)
	p.strand(PackedVector2Array([Vector2(-s * 2.4, 4.8), Vector2(s * 3.2, 6.6), Vector2(s * 8.8, 4.8)]), 0.4, 0.4, RP.VOID)
	# rolled bright rim along the top edge
	p.strand(PackedVector2Array([Vector2(-s * 5.0, 0.8), Vector2(-s * 3.4, -3.6), Vector2(s * 1.8, -5.0), Vector2(s * 6.8, -3.2), Vector2(s * 9.0, 0.4)]), 0.8, 0.65, m.lightened(0.3))
	for i in 3:
		var a := -2.4 + i * 1.1
		RP.dot(p, Vector2(s * (1.8 + cos(a) * 5.4) * 1.0, -0.4 + sin(a) * 3.3), m.lightened(0.55))
	# hooked spike
	var b0 := Vector2(s * 0.0, -3.8)
	var b1 := Vector2(s * 4.6, -3.4)
	var mid := Vector2(s * 2.6, -4.6)
	var tip := Vector2(s * 5.6, -12.0)
	RP.facet(p, PackedVector2Array([b0, mid, tip]), m.lightened(0.08), Vector3(-0.6, -0.4, 0.7))
	RP.facet(p, PackedVector2Array([mid, b1, tip]), m.darkened(0.3), Vector3(0.6, -0.1, 0.7))
	RP.dot(p, tip + Vector2(0, 0.8), m.lightened(0.6))


# =============================================================================== rags

const R_CLOTH := Color(0.38, 0.33, 0.25)
const R_CLOTH2 := Color(0.3, 0.24, 0.18)


static func rags(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var step: float = r["step"]
	var down: Vector2 = r["down"]
	# ---- torso frame: loin cloth, belt cord, diagonal sash
	p.xf = Rig.sub(r, "txf")
	var sw := step * 1.6
	var loin := PackedVector2Array([Vector2(-7.5, -5), Vector2(7.5, -5), Vector2(6.5, 6), Vector2(5.2 + sw, 17), Vector2(3.0 + sw, 12.5), Vector2(1.2 + sw, 19.5), Vector2(-1.2 + sw, 13), Vector2(-3.4 + sw, 18), Vector2(-5.6 + sw, 12), Vector2(-6.8, 6)])
	RP.cyl(p, loin, R_CLOTH2, Vector2(0, -5), Vector2(sw, 18), 8.0, -0.2, 0.0, 1.3, 0.38)
	RP.hole(p, Vector2(2.0 + sw * 0.5, 8.0), 0.9, 1.3)
	# side strips
	for e in _sides():
		var s: float = e[1]
		var st := PackedVector2Array([Vector2(s * 9.5, -5), Vector2(s * 12.5, -5), Vector2(s * 13.0 + sw * 0.5, 7), Vector2(s * 11.6 + sw * 0.6, 3.5), Vector2(s * 10.4 + sw * 0.7, 9)])
		RP.cyl(p, st, R_CLOTH.darkened(0.12), Vector2(s * 11, -5), Vector2(s * 11, 9), 2.0, -0.2, 0.0, 1.5, 0.3)
	# knotted cord belt
	p.capsule(Vector2(-12.4, -5.6), Vector2(12.4, -5.6), 1.0, 1.0, R_CLOTH.darkened(0.3))
	RP.oval(p, Vector2(-4.0, -5.4), 1.6, 1.3, R_CLOTH.darkened(0.2))
	p.strand(PackedVector2Array([Vector2(-4.2, -4.4), Vector2(-4.8, 0), Vector2(-4.4 + sw * 0.4, 3.8)]), 0.6, 0.45, R_CLOTH.darkened(0.25))
	# sash from the left shoulder to the right hip, frayed end
	var sash := PackedVector2Array([Vector2(-11.5, -26.2), Vector2(-6.0, -27.0), Vector2(12.0, -7.2), Vector2(12.6, -2.0), Vector2(8.0, -2.4), Vector2(-12.6, -21.0)])
	RP.cyl(p, sash, R_CLOTH, Vector2(-9, -26), Vector2(11, -4), 4.0, -0.2, 0.0, 1.6, 0.3)
	for i in 5:
		var t := float(i) / 4.0
		var a := Vector2(-12.6, -21.0).lerp(Vector2(8.0, -2.4), t)
		RP.dot(p, a + Vector2(-0.3, 0.8), R_CLOTH.darkened(0.45))
	RP.hole(p, Vector2(-2.0, -15.8), 1.0, 0.8, 0.8)
	RP.hole(p, Vector2(5.0, -9.0), 0.8, 0.6, 0.8)
	var fray := PackedVector2Array([Vector2(9.0, -2.6), Vector2(12.4, -2.2), Vector2(12.0 + sw * 0.4, 6.0), Vector2(10.8 + sw * 0.4, 3.0), Vector2(9.6 + sw * 0.5, 7.4)])
	RP.cyl(p, fray, R_CLOTH.darkened(0.08), Vector2(10.6, -2), Vector2(10.6, 7), 2.4, -0.2)
	# ---- forearm wraps and a hanging strip
	p.xf = bxf
	for e in _sides():
		var sd: String = e[0]
		var el: Vector2 = r[sd + "el"]
		var wr := RP.wrist_of(r, sd, 3.0)
		var d := (wr - el).normalized()
		var n := Vector2(-d.y, d.x)
		var w0 := el.lerp(wr, 0.3)
		var w1 := el.lerp(wr, 0.92)
		p.capsule(w0, w1, 2.3, 2.0, R_CLOTH.darkened(0.05))
		for j in 4:
			var c := w0.lerp(w1, 0.12 + j * 0.25)
			p.line(c + n * 2.0 - d * 0.7, c - n * 2.0 + d * 0.7, R_CLOTH.darkened(0.45))
		var a := el.lerp(wr, 0.5) + n * 1.5
		var tail := a + down * (5.5 + float(int(r["frame"]) % 2)) + d * 0.8
		p.strand(PackedVector2Array([a, a.lerp(tail, 0.5) + n * 0.4, tail]), 0.8, 0.4, R_CLOTH.darkened(0.15))
	p.grime(Color(0.14, 0.11, 0.08), 0.5, 0.12, 0.05, 0.6, 431)
	p.grime(RP.BLOOD, 0.4, 0.17, 0.45, 0.8, 432)
	return []


# =============================================================================== cape (under body)

const CAPE := Color(0.3, 0.07, 0.07)


static func cape(p: Painter, r: Dictionary) -> Array:
	var txf: Transform2D = r["txf"]
	var lft: Vector2 = r["lft"]
	var rft: Vector2 = r["rft"]
	var step: float = r["step"]
	var atk: int = r["atk"]
	var flare := 0.0
	if atk == 1:
		flare = -4.0
	elif atk == 2:
		flare = 4.0
	elif r["pain"]:
		flare = -3.0
	var sway := (lft.x + rft.x) * 0.5 - 48.0 - step * 2.0 + flare
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	var hem := 83.0
	var xr := rsh.x + 12.0 + sway * 0.6 + maxf(flare, 0.0)
	var xl := lsh.x - 12.0 + sway * 0.6 + minf(flare, 0.0)
	var pts := PackedVector2Array([txf * Vector2(-11.0, -27.2), txf * Vector2(11.0, -27.2), rsh + Vector2(3.6, 0.5), Vector2(rsh.x + 8.0 + sway * 0.3, 52.0), Vector2(xr, hem - 2.0)])
	var n := 12
	for i in n:
		var t := float(i + 1) / float(n + 1)
		var hy := hem + (2.5 if i % 2 == 0 else -1.5) - (3.5 if i % 5 == 2 else 0.0) + sin(t * 9.0 + step) * 1.2
		pts.append(Vector2(lerpf(xr, xl, t), hy))
	pts.append(Vector2(xl, hem - 1.0))
	pts.append(Vector2(lsh.x - 8.0 + sway * 0.3, 52.0))
	pts.append(lsh + Vector2(-3.6, 0.5))
	RP.cyl(p, pts, CAPE, r["neck_base"], Vector2(48.0 + sway, hem), 20.0, -0.2, 0.0, 0.8, 0.45)
	# dark lining showing at the inner edges
	for e in [[xl, -1.0], [xr, 1.0]]:
		var ex: float = e[0]
		var s: float = e[1]
		var lin := PackedVector2Array([Vector2(ex, hem - 1.5), Vector2(ex - s * 2.5, hem - 14.0), Vector2(ex - s * 1.0, hem + 1.0)])
		p.poly(lin, CAPE.darkened(0.6))
	RP.hole(p, Vector2(36.0 + sway * 0.5, 74.0), 1.2, 2.4)
	RP.hole(p, Vector2(61.0 + sway * 0.5, 70.0), 1.0, 2.0)
	# collar band behind the neck
	p.xf = Rig.sub(r, "txf")
	p.capsule(Vector2(-10.5, -26.8), Vector2(10.5, -26.8), 1.6, 1.6, CAPE.lightened(0.08))
	p.grime(Color(0.1, 0.06, 0.05), 0.5, 0.1, 0.05, 0.7, 441)
	return []
