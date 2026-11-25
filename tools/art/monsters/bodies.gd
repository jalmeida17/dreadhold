extends RefCounted
## Monster forge BODY layer: headless, weaponless torsos/limbs drawn on the shared rig.
## Each body ends in a neck stump reaching the rig neck top and closed fists on both rig hands
## (weapons and off-hand items are separate layers that grip those fists).

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const RP := preload("res://tools/art/monsters/rp.gd")

const NAMES := ["skeleton", "ghoul", "cultist", "knight", "wraith"]

const BONE := RP.BONE
const VOID := RP.VOID


static func draw(name: String, p: Painter, r: Dictionary) -> Array:
	match name:
		"skeleton":
			return skeleton(p, r)
		"ghoul":
			return ghoul(p, r)
		"cultist":
			return cultist(p, r)
		"knight":
			return knight(p, r)
		"wraith":
			return wraith(p, r)
	return []


static func post(name: String, p: Painter, r: Dictionary) -> void:
	## Runs after the silhouette rim, before glows.
	if name == "wraith":
		_wraith_fade(p, r)


static func rim_amount(name: String) -> Vector2:
	return Vector2(0.3, 0.08) if name == "wraith" else Vector2(0.42, 0.12)


static func _sides() -> Array:
	return [["l", -1.0], ["r", 1.0]]


# =============================================================================== skeleton

static func _bone(p: Painter, a: Vector2, b: Vector2, rad: float, c: Color = BONE) -> void:
	p.capsule(a, b, rad, rad * 0.82, c)
	p.ball(a.x, a.y, rad * 1.3, rad * 1.1, c)
	p.ball(b.x, b.y, rad * 1.25, rad * 1.05, c)


static func _bone_foot(p: Painter, an: Vector2, s: float, c: Color) -> void:
	p.ball(an.x, an.y, 1.8, 1.4, c)
	RP.oval(p, an + Vector2(s * 0.6, 2.5), 2.6, 1.5, c)
	for t in 4:
		var b0 := an + Vector2(s * 0.6 - 1.8 + t * 1.2, 2.9)
		p.capsule(b0, b0 + Vector2(-0.4 + t * 0.25, 1.3), 0.5, 0.45, c)


static func _bone_arm(p: Painter, r: Dictionary, sd: String, c: Color) -> void:
	var sh: Vector2 = r[sd + "sh"]
	var el: Vector2 = r[sd + "el"]
	var hd: Vector2 = r[sd + "hd"]
	var dir: Vector2 = r[sd + "dir"]
	p.ball(sh.x, sh.y, 2.3, 2.0, c)
	_bone(p, sh, el, 1.7, c)
	var wr := RP.wrist_of(r, sd, 2.0)
	var fd := (wr - el).normalized()
	var fn := Vector2(-fd.y, fd.x)
	p.capsule(el + fn * 0.7, wr + fn * 0.7, 1.0, 0.85, c)
	p.capsule(el - fn * 0.8, wr - fn * 0.6, 0.85, 0.7, c.darkened(0.08))
	RP.fist(p, hd, dir, c, 2.1)


static func skeleton(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var c := BONE
	# ---- legs
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var hip: Vector2 = r[sd + "hip"]
		var kn: Vector2 = r[sd + "kn"]
		var ft: Vector2 = r[sd + "ft"]
		_bone(p, hip, kn, 2.0)
		p.ball(kn.x, kn.y - 0.6, 1.5, 1.3, c.lightened(0.05))
		var dk := (ft - kn).normalized()
		var outv := Vector2(dk.y, -dk.x) * -s
		p.capsule(kn - outv * 0.6 + dk, ft - outv * 0.4, 1.55, 1.2, c)
		p.capsule(kn + outv * 1.6 + dk * 1.5, ft + outv * 1.5 - dk * 0.5, 0.8, 0.7, c.darkened(0.1))
		_bone_foot(p, ft, s, c)
	# ---- torso (torso frame: origin pelvis centre)
	p.xf = Rig.sub(r, "txf")
	for i in 13:
		var vy := -25.0 + i * 1.85
		var lumbar := vy > -10.0
		RP.oval(p, Vector2(0, vy), 2.5 if lumbar else 1.8, 1.0 if lumbar else 0.85, c.darkened(0.15))
	# pelvis
	RP.oval(p, Vector2(-5.0, -3.2), 4.4, 3.1, c.darkened(0.12))
	RP.oval(p, Vector2(5.0, -3.2), 4.4, 3.1, c.darkened(0.05))
	RP.hole(p, Vector2(-5.4, -2.4), 1.6, 1.2)
	RP.hole(p, Vector2(5.4, -2.4), 1.6, 1.2)
	RP.oval(p, Vector2(0, -2.0), 2.4, 3.2, c.darkened(0.2))
	p.capsule(Vector2(-4.2, 2.5), Vector2(4.2, 2.5), 1.3, 1.3, c)
	RP.hole(p, Vector2(-3.1, 1.0), 1.3, 1.1)
	RP.hole(p, Vector2(3.1, 1.0), 1.3, 1.1)
	# ribcage
	var widths := [6.8, 8.8, 10.2, 11.0, 11.4, 11.0, 10.0, 8.6]
	for i in 8:
		var y0 := -23.4 + i * 2.15
		var wi: float = widths[i]
		var drop := 2.6 + i * 0.2
		var start := 1.3 if i < 6 else 3.6
		for e in _sides():
			var s: float = e[1]
			p.strand(PackedVector2Array([
				Vector2(s * start, y0 + (0.6 if i >= 6 else 0.0)),
				Vector2(s * wi * 0.55, y0 - 0.5),
				Vector2(s * wi * 0.88, y0 + drop * 0.4),
				Vector2(s * wi, y0 + drop)]), 1.05, 0.8, c)
	p.capsule(Vector2(0, -24.0), Vector2(0, -12.5), 1.5, 1.0, c.lightened(0.05))
	p.ball(0, -24.2, 2.0, 1.4, c)
	for e in _sides():
		var s: float = e[1]
		p.strand(PackedVector2Array([Vector2(s * 1.5, -25.4), Vector2(s * 6.0, -26.4), Vector2(s * 10.8, -25.2)]), 1.05, 0.9, c)
	# neck vertebrae up to the rig neck top
	for i in 4:
		RP.oval(p, Vector2(0, -26.6 - i * 1.35), 1.6, 0.75, c.darkened(0.1))
	# ---- arms
	p.xf = bxf
	for e in _sides():
		_bone_arm(p, r, e[0], c)
	p.grime(RP.BONE_DIRT, 0.55, 0.11, 0.05, 0.6, 311)
	return []


# =============================================================================== ghoul

const G_FLESH := Color(0.43, 0.46, 0.39)
const G_DARK := Color(0.3, 0.31, 0.27)
const G_CLAW := Color(0.55, 0.5, 0.38)
const G_ROT := Color(0.24, 0.05, 0.06)


static func ghoul(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var flesh := G_FLESH
	var dark := G_DARK
	var step: float = r["step"]
	# ---- legs: thin, knees bowed out, clawed feet
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var hip: Vector2 = r[sd + "hip"]
		var kn: Vector2 = r[sd + "kn"]
		var ft: Vector2 = r[sd + "ft"]
		var knee := kn + Vector2(s * 2.2, 0.5)
		p.capsule(hip, knee, 3.3, 2.4, flesh)
		RP.oval(p, hip.lerp(knee, 0.35) + Vector2(s * 1.0, 0), 2.6, 4.2, flesh, (knee - hip).angle() - PI * 0.5)
		p.ball(knee.x, knee.y, 2.5, 2.3, dark.lightened(0.12))
		p.capsule(knee, ft, 2.2, 1.5, flesh)
		p.capsule(knee + Vector2(-s * 1.1, 2.0), ft + Vector2(-s * 0.5, -3.0), 1.0, 0.7, dark)
		RP.oval(p, ft + Vector2(s * 0.8, 2.4), 3.3, 1.7, dark)
		for t in 4:
			var tb := ft + Vector2(s * 0.8 - 2.6 + t * 1.75, 3.3)
			p.capsule(tb, tb + Vector2((t - 1.5) * 0.4, 1.6), 0.6, 0.35, G_CLAW)
	# ---- torso
	p.xf = Rig.sub(r, "txf")
	# loin rag
	var sw := step * 1.2
	var rag := PackedVector2Array([Vector2(-8, -4), Vector2(8, -4), Vector2(7.5, 8), Vector2(5 + sw, 15), Vector2(3 + sw, 11), Vector2(0.5 + sw, 17), Vector2(-2 + sw, 11), Vector2(-4.5 + sw, 15.5), Vector2(-7.5, 9)])
	RP.cyl(p, rag, Color(0.25, 0.2, 0.14), Vector2(0, -4), Vector2(sw, 15), 9.0, -0.2, 0.0, 1.4, 0.35)
	# hunched back rising behind the neck (shows either side of any head)
	RP.oval(p, Vector2(0, -30.0), 9.0, 5.4, flesh.darkened(0.16))
	RP.oval(p, Vector2(0, -32.0), 6.0, 3.2, flesh.darkened(0.1))
	for i in 3:
		RP.oval(p, Vector2(0, -34.0 + i * 1.6), 1.3, 0.8, dark.lightened(0.05))
	# neck (short, thick, thrust forward between the humps)
	p.capsule(Vector2(0, -24.0), Vector2(0, -31.0), 3.6, 3.0, flesh.darkened(0.06))
	p.line(Vector2(-1.2, -30), Vector2(-1.4, -26), dark.darkened(0.2))
	p.line(Vector2(1.4, -30), Vector2(1.6, -26), dark.darkened(0.25))
	var torso := PackedVector2Array([Vector2(-11, -25.5), Vector2(11, -25.5), Vector2(13, -21), Vector2(12, -14), Vector2(9, -7), Vector2(8.5, -2), Vector2(7.5, 1.5), Vector2(-7.5, 1.5), Vector2(-8.5, -2), Vector2(-9, -7), Vector2(-12, -14), Vector2(-13, -21)])
	RP.cyl(p, torso, flesh, Vector2(0, -25), Vector2(0, 2), 12.5, -0.3)
	# pectorals, ribs under the skin, sunken belly
	RP.oval(p, Vector2(-5.2, -19.5), 5.2, 3.3, flesh)
	RP.oval(p, Vector2(5.2, -19.5), 5.2, 3.3, flesh)
	for i in 3:
		var ry := -15.0 + i * 3.0
		for e in _sides():
			var s: float = e[1]
			p.line(Vector2(s * 4.5, ry + 0.4), Vector2(s * 10.0, ry + 1.8), dark.darkened(0.2))
			p.line(Vector2(s * 4.5, ry - 0.6), Vector2(s * 9.5, ry + 0.8), flesh.lightened(0.08))
	p.line(Vector2(0, -18), Vector2(0, -1), dark.darkened(0.3))
	RP.blot(p, Vector2(0, -4.5), 4.0, 2.6, flesh.darkened(0.22))
	# rotting wound with exposed ribs
	RP.oval(p, Vector2(6.0, -8.5), 3.0, 3.6, G_ROT)
	for i in 3:
		p.capsule(Vector2(3.8, -10.3 + i * 1.6), Vector2(8.0, -9.5 + i * 1.6), 0.5, 0.45, BONE)
	# hunched trapezius humps swallowing the neck, collarbones
	for e in _sides():
		var s: float = e[1]
		RP.oval(p, Vector2(s * 6.6, -27.4), 6.2, 4.2, flesh, s * 0.4)
		p.strand(PackedVector2Array([Vector2(s * 1.8, -24.8), Vector2(s * 6.0, -25.6), Vector2(s * 11.0, -24.6)]), 0.8, 0.7, flesh.lightened(0.15))
	# ---- arms: long and sinewy, gnarled fists
	p.xf = bxf
	for e in _sides():
		var sd: String = e[0]
		var sh: Vector2 = r[sd + "sh"]
		var el: Vector2 = r[sd + "el"]
		var hd: Vector2 = r[sd + "hd"]
		var dir: Vector2 = r[sd + "dir"]
		var wr := RP.wrist_of(r, sd, 2.2)
		RP.oval(p, sh, 4.4, 3.8, flesh)
		p.capsule(sh, el, 2.9, 2.0, flesh)
		p.ball(el.x, el.y, 2.1, 2.0, dark.lightened(0.1))
		p.capsule(el, wr, 2.1, 1.6, flesh)
		p.capsule(el.lerp(wr, 0.15), wr, 0.9, 0.7, dark)
		RP.fist(p, hd, dir, flesh.darkened(0.04), 2.45)
		# cracked yellow nails curling out of the fist
		var d := dir.normalized()
		var n := Vector2(-d.y, d.x)
		for f in 3:
			var o := (float(f) - 1.0) * 1.2
			var nb := hd + d * o - n * 1.9
			p.strand(PackedVector2Array([nb, nb - n * 1.4 + d * 0.5]), 0.5, 0.25, G_CLAW)
	p.grime(Color(0.26, 0.17, 0.24), 0.5, 0.09, 0.15, 0.0, 321)
	p.grime(Color(0.18, 0.2, 0.1), 0.45, 0.14, 0.2, 0.3, 322)
	p.grime(Color(0.25, 0.05, 0.05), 0.35, 0.2, 0.42, 0.7, 323)
	if r["kind"] == "corpse":
		p.xf = Transform2D.IDENTITY
		var pc: Vector2 = bxf * Vector2(48, 50)
		var src := p.img.duplicate() as Image
		RP.pool(p, pc.x + 4, 92.5, 26.0, Color(0.28, 0.03, 0.04))
		p.img.blend_rect(src, Rect2i(0, 0, p.w, p.h), Vector2i.ZERO)
	return []


# =============================================================================== cultist

const C_ROBE := Color(0.17, 0.12, 0.16)
const C_SKIN := Color(0.56, 0.5, 0.5)
const C_ROPE := Color(0.4, 0.33, 0.22)


static func cultist(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var txf: Transform2D = r["txf"]
	var robe := C_ROBE
	var lft: Vector2 = r["lft"]
	var rft: Vector2 = r["rft"]
	var down: Vector2 = r["down"]
	var sway := (lft.x + rft.x) * 0.5 - 48.0 + float(r["step"]) * 1.5
	# ---- boots peeking under the hem
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var ft: Vector2 = r[sd + "ft"]
		RP.oval(p, ft + Vector2(s * 0.8, 2.6), 3.0, 1.7, Color(0.13, 0.1, 0.08))
	# ---- robe: shoulders -> flared hem following the feet
	var hem_l := lft.y + 2.4
	var hem_r := rft.y + 2.4
	var body := PackedVector2Array([
		txf * Vector2(-10.5, -25.5), txf * Vector2(10.5, -25.5), txf * Vector2(12.5, -20),
		txf * Vector2(12.8, -6), txf * Vector2(13.5, 4), Vector2(rft.x + 9.0 + sway * 0.4, (txf * Vector2(0, 10)).y + 14.0),
		Vector2(rft.x + 10.0 + sway * 0.3, hem_r)])
	var x0 := rft.x + 10.0 + sway * 0.3
	var x1 := lft.x - 10.0 + sway * 0.3
	for i in 13:
		var t := float(i + 1) / 14.0
		var hy := lerpf(hem_r, hem_l, t) - (i % 2) * 2.2 - (1.4 if i % 4 == 1 else 0.0)
		body.append(Vector2(lerpf(x0, x1, t), hy))
	body.append(Vector2(x1, hem_l))
	body.append(Vector2(lft.x - 9.0 + sway * 0.4, (txf * Vector2(0, 10)).y + 14.0))
	body.append(txf * Vector2(-13.5, 4))
	body.append(txf * Vector2(-12.8, -6))
	body.append(txf * Vector2(-12.5, -20))
	var top: Vector2 = r["neck_base"]
	RP.cyl(p, body, robe, top, Vector2(48.0 + sway, 92.0), 16.0, -0.15, 0.0, 0.75, 0.42)
	# worn embroidered hem band
	for i in 34:
		var t := float(i) / 33.0
		var bx := lerpf(x1 + 1.0, x0 - 1.0, t)
		var byy := lerpf(hem_l, hem_r, t) - 5.0 + sin(t * 18.0) * 0.7
		p.tput(bx, byy, RP.GOLD.darkened(0.3 if i % 3 == 0 else 0.5))
	# ---- torso details (torso frame)
	p.xf = Rig.sub(r, "txf")
	# rope belt, hanging cords, bone charm
	p.capsule(Vector2(-12.5, -6.5), Vector2(12.5, -6.5), 1.2, 1.2, C_ROPE)
	var cs := float(r["step"]) * 0.8
	p.strand(PackedVector2Array([Vector2(3, -6), Vector2(3.5, 2), Vector2(3 + cs, 9)]), 0.8, 0.6, C_ROPE)
	p.strand(PackedVector2Array([Vector2(-2, -6), Vector2(-2.5, 1), Vector2(-2 + cs, 6)]), 0.8, 0.6, C_ROPE)
	RP.oval(p, Vector2(-2 + cs, 7.5), 1.6, 1.8, BONE)
	RP.blot(p, Vector2(-2.6 + cs, 7.2), 0.5, 0.5, VOID)
	RP.blot(p, Vector2(-1.4 + cs, 7.2), 0.5, 0.5, VOID)
	# shoulder mantle and the folded cowl around the neck
	var mt := PackedVector2Array([Vector2(-12.8, -26), Vector2(12.8, -26), Vector2(13, -18), Vector2(7.5, -11), Vector2(0, -8.5), Vector2(-7.5, -11), Vector2(-13, -18)])
	RP.cyl(p, mt, robe.lightened(0.06), Vector2(0, -26), Vector2(0, -8), 13.0, -0.35, 0.0, 1.1, 0.3)
	p.strand(PackedVector2Array([Vector2(-7.5, -11), Vector2(0, -8.5), Vector2(7.5, -11)]), 0.6, 0.6, RP.GOLD.darkened(0.45))
	p.capsule(Vector2(0, -25), Vector2(0, -31), 2.6, 2.3, C_SKIN.darkened(0.55))
	p.capsule(Vector2(-5.5, -25.8), Vector2(5.5, -25.8), 2.3, 2.3, robe.lightened(0.1))
	# ---- arms in wide sleeves, pale hands
	p.xf = bxf
	for e in _sides():
		var sd: String = e[0]
		var sh: Vector2 = r[sd + "sh"]
		var el: Vector2 = r[sd + "el"]
		var hd: Vector2 = r[sd + "hd"]
		var dir: Vector2 = r[sd + "dir"]
		var cuff := RP.wrist_of(r, sd, 2.8)
		var sl := robe.lightened(0.05)
		p.capsule(sh, el, 3.6, 3.8, sl)
		p.capsule(el, cuff, 3.8, 4.6, sl)
		# bell sleeve sagging with gravity
		var sag := PackedVector2Array([el + down * 2.0, cuff + down * 2.0, cuff + down * 5.5, el.lerp(cuff, 0.4) + down * 4.5])
		RP.cyl(p, sag, sl.darkened(0.08), el, cuff, 4.0, -0.2)
		RP.blot(p, cuff, 2.6, 2.1, VOID, (cuff - el).angle())
		RP.fist(p, hd, dir, C_SKIN, 2.2)
	p.grime(Color(0.12, 0.1, 0.08), 0.45, 0.1, 0.1, 0.8, 331)
	return []


# =============================================================================== knight

const K_PLATE := Color(0.33, 0.33, 0.36)
const K_DARK := Color(0.2, 0.2, 0.23)


static func knight(p: Painter, r: Dictionary) -> Array:
	var bxf: Transform2D = r["xf"]
	var txf: Transform2D = r["txf"]
	var plate := K_PLATE
	# ---- legs: cuisses, poleyns, greaves, sabatons
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var hip: Vector2 = r[sd + "hip"]
		var kn: Vector2 = r[sd + "kn"]
		var ft: Vector2 = r[sd + "ft"]
		p.spec = 0.4
		p.capsule(hip, kn, 3.7, 3.1, plate)
		p.capsule(kn, ft, 3.0, 2.3, plate.darkened(0.04))
		var dk := (ft - kn).normalized()
		for kk in 2:
			var q := kn.lerp(ft, 0.35 + kk * 0.3)
			p.line(q + Vector2(-dk.y, dk.x) * 2.6, q - Vector2(-dk.y, dk.x) * 2.6, K_DARK)
		RP.oval(p, kn + Vector2(0, -0.3), 3.2, 2.7, plate.lightened(0.06))
		RP.oval(p, kn + Vector2(s * 2.4, 0.2), 1.6, 2.2, plate.darkened(0.1))
		RP.oval(p, ft + Vector2(s * 0.7, 2.4), 3.5, 1.9, plate.darkened(0.08))
		p.line(ft + Vector2(s * 0.7 - 3.0, 2.2), ft + Vector2(s * 0.7 + 3.0, 2.2), K_DARK)
		p.spec = 0.0
	# tassets hanging over the thighs
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var hip: Vector2 = r[sd + "hip"]
		var kn: Vector2 = r[sd + "kn"]
		var a := txf * Vector2(s * 1.5, 2.5)
		var b := txf * Vector2(s * 11.0, 2.0)
		var lo := hip.lerp(kn, 0.42)
		var tas := PackedVector2Array([a, b, lo + Vector2(s * 4.8, 0), lo + Vector2(-s * 3.2, 0.6)])
		p.spec = 0.4
		RP.cyl(p, tas, plate.darkened(0.06), (a + b) * 0.5, lo, 6.0, -0.3)
		p.spec = 0.0
		p.line(a.lerp(lo + Vector2(-s * 3.2, 0.6), 0.5), b.lerp(lo + Vector2(s * 4.8, 0), 0.5), K_DARK)
	# ---- torso
	p.xf = Rig.sub(r, "txf")
	# faulds (hoops below the breastplate)
	p.spec = 0.4
	for i in 3:
		var fy := -5.0 + i * 2.6
		var fw := 10.4 + i * 0.6
		RP.cyl(p, PackedVector2Array([Vector2(-fw, fy - 1.4), Vector2(fw, fy - 1.4), Vector2(fw + 0.3, fy + 1.4), Vector2(-fw - 0.3, fy + 1.4)]), plate.darkened(0.05 * i), Vector2(0, fy - 2), Vector2(0, fy + 2), fw, -0.5)
		p.line(Vector2(-fw, fy + 1.4), Vector2(fw, fy + 1.4), K_DARK)
	# breastplate
	var bp := PackedVector2Array([Vector2(-9, -25.5), Vector2(9, -25.5), Vector2(12.6, -23), Vector2(13.2, -17.5), Vector2(11.6, -11), Vector2(9.8, -5.5), Vector2(-9.8, -5.5), Vector2(-11.6, -11), Vector2(-13.2, -17.5), Vector2(-12.6, -23)])
	p.spec = 0.3
	p.shininess = 30.0
	RP.cyl(p, bp, plate, Vector2(0, -26), Vector2(0, -5), 10.5, -0.3)
	p.shininess = 18.0
	# raised medial ridge catching the light
	RP.facet(p, PackedVector2Array([Vector2(-1.6, -25), Vector2(0, -25), Vector2(0, -7), Vector2(-1.2, -8)]), plate.lightened(0.12), Vector3(-0.5, -0.2, 0.85))
	RP.facet(p, PackedVector2Array([Vector2(0, -25), Vector2(1.6, -25), Vector2(1.2, -8), Vector2(0, -7)]), plate.darkened(0.18), Vector3(0.5, -0.2, 0.85))
	p.spec = 0.0
	p.strand(PackedVector2Array([Vector2(-11, -11), Vector2(-5, -13.5), Vector2(0, -14.2), Vector2(5, -13.5), Vector2(11, -11)]), 0.45, 0.45, K_DARK)
	for e in _sides():
		var s: float = e[1]
		p.strand(PackedVector2Array([Vector2(s * 9, -25), Vector2(s * 11.5, -22.5), Vector2(s * 12.4, -18)]), 0.5, 0.4, plate.lightened(0.2))
		for rv in 3:
			RP.dot(p, Vector2(s * (10.8 - rv * 0.4), -21.5 + rv * 4.5), plate.lightened(0.45))
	# undead rent in the plate: ribs and darkness behind
	var gash := PackedVector2Array([Vector2(2.5, -21), Vector2(7.5, -19.5), Vector2(8.5, -13), Vector2(5.5, -10.5), Vector2(3.0, -14)])
	RP.flat(p, gash, VOID)
	for i in 3:
		p.capsule(Vector2(3.6, -18.5 + i * 2.6), Vector2(7.6, -17.5 + i * 2.6), 0.55, 0.45, BONE.darkened(0.1))
	p.strand(PackedVector2Array([Vector2(2.5, -21), Vector2(3.0, -14), Vector2(5.5, -10.5)]), 0.5, 0.5, plate.lightened(0.15))
	# gorget up to the neck top
	p.spec = 0.5
	p.capsule(Vector2(-6.4, -25.8), Vector2(6.4, -25.8), 2.3, 2.3, plate.darkened(0.05))
	p.capsule(Vector2(-5.0, -28.0), Vector2(5.0, -28.0), 2.0, 2.0, plate)
	p.capsule(Vector2(-3.8, -30.0), Vector2(3.8, -30.0), 1.7, 1.7, plate.darkened(0.08))
	p.spec = 0.0
	# ---- arms: spaulders, rerebraces, couters, vambraces, gauntlets
	p.xf = bxf
	for e in _sides():
		var sd: String = e[0]
		var s: float = e[1]
		var sh: Vector2 = r[sd + "sh"]
		var el: Vector2 = r[sd + "el"]
		var hd: Vector2 = r[sd + "hd"]
		var dir: Vector2 = r[sd + "dir"]
		var wr := RP.wrist_of(r, sd, 2.4)
		p.spec = 0.45
		p.capsule(sh, el, 3.1, 2.7, plate.darkened(0.04))
		p.capsule(el, wr, 2.7, 2.2, plate)
		RP.oval(p, el, 2.8, 2.5, plate.lightened(0.05))
		RP.oval(p, el + (el - sh).normalized().rotated(s * 1.2) * 1.6, 1.4, 2.0, plate.darkened(0.08), (el - sh).angle())
		RP.oval(p, wr + (hd - wr).normalized() * 0.2, 2.8, 2.0, plate.darkened(0.06), (hd - wr).angle() + PI * 0.5)
		RP.oval(p, sh + Vector2(s * 1.0, -0.6), 4.6, 3.9, plate)
		RP.oval(p, sh + Vector2(s * 1.6, 2.6), 4.1, 2.5, plate.darkened(0.08))
		RP.fist(p, hd, dir, plate.darkened(0.12), 2.5, K_DARK)
		p.spec = 0.0
	p.grime(RP.RUST, 0.62, 0.09, 0.08, 0.55, 341)
	p.grime(Color(0.12, 0.1, 0.08), 0.4, 0.15, 0.3, 0.2, 342)
	return []


# =============================================================================== wraith

const W_SHROUD := Color(0.34, 0.38, 0.4)
const W_DEEP := Color(0.16, 0.18, 0.21)
const W_GHOST := Color(0.6, 0.73, 0.76)
const W_HAND := Color(0.58, 0.66, 0.67)


static func wraith(p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	var bxf: Transform2D = r["xf"]
	var txf: Transform2D = r["txf"]
	var down: Vector2 = r["down"]
	var lft: Vector2 = r["lft"]
	var rft: Vector2 = r["rft"]
	var step: float = r["step"]
	var sway := (lft.x + rft.x) * 0.5 - 48.0 - step * 2.0
	# ---- faint spectral legs inside the shroud (only show through the tatters)
	for e in _sides():
		var sd: String = e[0]
		var hip: Vector2 = r[sd + "hip"]
		var kn: Vector2 = r[sd + "kn"]
		var ft: Vector2 = r[sd + "ft"]
		p.capsule(hip, kn, 2.4, 1.8, W_DEEP.lightened(0.15))
		p.capsule(kn, ft, 1.8, 0.9, W_DEEP.lightened(0.1))
	# ---- the shroud: shoulders -> long tattered tails
	var body := PackedVector2Array([txf * Vector2(-10.5, -26), txf * Vector2(10.5, -26), txf * Vector2(13, -21), txf * Vector2(12.5, -8), txf * Vector2(12.0, 4)])
	var tails := 9
	var xr := rft.x + 7.5 + sway
	var xl := lft.x - 7.5 + sway
	body.append(Vector2(xr, 74))
	for i in tails:
		var t := (float(i) + 0.5) / float(tails)
		var tx := lerpf(xr, xl, t)
		var long := 88.0 - absf(t - 0.5) * 12.0 + (3.0 if i % 2 == 0 else -4.0) + sin(float(i) * 2.3 + step * 1.7) * 1.5
		body.append(Vector2(tx + 1.2, long))
		body.append(Vector2(tx + (xl - xr) / float(tails) * 0.5, long - 9.0 - (i % 3) * 2.0))
	body.append(Vector2(xl, 74))
	body.append(txf * Vector2(-12.0, 4))
	body.append(txf * Vector2(-12.5, -8))
	body.append(txf * Vector2(-13, -21))
	RP.cyl(p, body, W_SHROUD, r["neck_base"], Vector2(48.0 + sway, 88.0), 15.0, -0.2, 0.0, 0.9, 0.45)
	# torn gaps showing darkness
	RP.hole(p, Vector2(41 + sway * 0.6, 66), 1.4, 3.0, 0.2)
	RP.hole(p, Vector2(55 + sway * 0.6, 62), 1.2, 2.6, -0.3)
	RP.hole(p, Vector2(47 + sway * 0.8, 77), 1.6, 3.5)
	# ---- chest: shroud parted on a dark void with ghostly ribs
	p.xf = Rig.sub(r, "txf")
	RP.flat(p, PackedVector2Array([Vector2(-5.5, -26), Vector2(5.5, -26), Vector2(4.0, -15), Vector2(0, -5), Vector2(-4.0, -15)]), VOID)
	for i in 5:
		var ry := -22.5 + i * 2.6
		var wi := 4.6 - absf(i - 1.5) * 0.5
		for e in _sides():
			var s: float = e[1]
			p.strand(PackedVector2Array([Vector2(s * 0.6, ry), Vector2(s * wi * 0.6, ry - 0.4), Vector2(s * wi, ry + 1.2)]), 0.45, 0.35, W_GHOST.darkened(0.25))
	p.line(Vector2(0, -24), Vector2(0, -8), W_GHOST.darkened(0.35))
	# shroud lapels over the opening edges
	for e in _sides():
		var s: float = e[1]
		p.strand(PackedVector2Array([Vector2(s * 5.8, -26), Vector2(s * 4.6, -16), Vector2(s * 0.8, -5)]), 1.2, 0.7, W_SHROUD.lightened(0.08))
	# ragged collar + spectral neck
	p.capsule(Vector2(0, -25), Vector2(0, -31), 2.0, 1.8, W_GHOST.darkened(0.3))
	for i in 5:
		var cx := -6.0 + i * 3.0
		RP.oval(p, Vector2(cx, -25.8 + (i % 2) * 0.6), 2.2, 1.6, W_SHROUD.darkened(0.05 * (i % 2)))
	# ---- arms: tattered sleeves, bony spectral hands
	p.xf = bxf
	for e in _sides():
		var sd: String = e[0]
		var sh: Vector2 = r[sd + "sh"]
		var el: Vector2 = r[sd + "el"]
		var hd: Vector2 = r[sd + "hd"]
		var dir: Vector2 = r[sd + "dir"]
		var cuff := RP.wrist_of(r, sd, 3.0)
		p.capsule(sh, el, 3.4, 3.2, W_SHROUD.lightened(0.03))
		p.capsule(el, cuff, 3.2, 3.6, W_SHROUD.lightened(0.03))
		# rag strips hanging from the sleeve
		for j in 3:
			var a := el.lerp(cuff, 0.2 + j * 0.35)
			var ln := 5.0 + j * 1.5 + float((int(r["frame"]) + j) % 3)
			var tip := a + down * ln + (cuff - el).normalized() * 1.2
			var nrm := Vector2(-down.y, down.x)
			p.poly(PackedVector2Array([a + nrm * 1.3, a - nrm * 1.3, tip]), W_SHROUD.darkened(0.12 + j * 0.05))
		RP.blot(p, cuff, 2.2, 1.8, VOID, (cuff - el).angle())
		var wr := RP.wrist_of(r, sd, 1.6)
		p.capsule(cuff, wr, 0.9, 0.8, W_HAND)
		RP.fist(p, hd, dir, W_HAND, 2.0)
	p.grime(W_DEEP, 0.4, 0.07, 0.1, 0.7, 351)
	# cold motes drifting off the tails
	for i in 4:
		var q := Vector2(lerpf(xl, xr, (float(i) + 0.5 + float(int(r["frame"]) % 2) * 0.3) / 4.0), 84.0 + (i % 2) * 4.0)
		RP.glow(glows, p, q, 1.6, W_GHOST, 0.7)
	return glows


static func _wraith_fade(p: Painter, r: Dictionary) -> void:
	## Dither the lower shroud away (legs fading into mist), colder and paler toward the end.
	var ix: Transform2D = (r["xf"] as Transform2D).affine_inverse()
	var n := FastNoiseLite.new()
	n.seed = 77 + int(r["frame"]) * 3
	n.frequency = 0.18
	var ur := p.img.get_used_rect()
	for y in range(ur.position.y, ur.end.y):
		for x in range(ur.position.x, ur.end.x):
			var c := p.img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var q := ix * Vector2(x + 0.5, y + 0.5)
			# holes only below the usual cape hem, so under-body layers don't speckle through
			var cut := clampf((q.y - 76.0) / 17.0, 0.0, 1.0)
			cut = cut * cut * 1.2
			var fade := clampf((q.y - 52.0) / 40.0, 0.0, 1.0)
			var b: float = (float(Painter.BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0
			var nv := n.get_noise_2d(q.x, q.y) * 0.35
			if b < cut + nv * cut:
				p.img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif fade > 0.05:
				# colder, paler toward the fading end
				var g := W_GHOST
				p.img.set_pixel(x, y, Color(lerpf(c.r, g.r, fade * 0.5), lerpf(c.g, g.g, fade * 0.5), lerpf(c.b, g.b, fade * 0.5), 1.0))
