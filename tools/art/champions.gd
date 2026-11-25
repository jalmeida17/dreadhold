extends RefCounted
## Co-op champions: the partner's billboard sprite, one sheet per playable class, drawn in the same
## realistic pixel style as the enemies (Painter "real" mode, grain, rim-darkened silhouettes) plus a
## thin key-light rim on the upper-left edges so a partner reads on dark floors.
## Each sheet is a horizontal strip of 8 frames of 96x96, figure facing the viewer, feet on the
## bottom rows:
##   0 idle, 1 walk A, 2 walk B, 3 attack wind-up, 4 attack strike,
##   5 cast (mage: arcane cast / warrior: battle cry / hunter: aiming high), 6 pain,
##   7 downed (wounded on the ground, inside the bottom 45 px).
## Bodies use a small rig: a torso frame (pelvis position + lean, rotation-safe shading) carries the
## trunk, back gear and head; limbs and weapons are placed with free joint positions.

const Painter := preload("res://tools/art/painter.gd")

const POSES := [
	{},
	{"step": 1.0},
	{"step": -1.0, "bob": 1.0},
	{"atk": 1},
	{"atk": 2},
	{"cast": true},
	{"pain": true},
	{"down": true},
]

const FRAME := 96
const HIP_REST := Vector2(48, 53)
const NECK_REST := Vector2(48, 23)
const FEET_SHIFT := 2

# shared materials
const GOLD := Color(0.68, 0.52, 0.23)
const LEATHER := Color(0.29, 0.19, 0.11)
const WOOD := Color(0.34, 0.22, 0.13)
const IRON := Color(0.33, 0.33, 0.36)
const VOID := Color(0.035, 0.03, 0.04)
const BLOOD := Color(0.4, 0.03, 0.04)
# warrior
const STEEL := Color(0.44, 0.45, 0.49)
const STEEL_D := Color(0.28, 0.29, 0.32)
const MAIL := Color(0.31, 0.31, 0.33)
const FUR := Color(0.38, 0.3, 0.21)
const CRIMSON := Color(0.44, 0.08, 0.07)
const BEARD_RED := Color(0.47, 0.24, 0.1)
const SKIN_W := Color(0.62, 0.44, 0.34)
const HORN := Color(0.66, 0.6, 0.47)
const RAGE := Color(1.0, 0.55, 0.15)
# mage
const ROBE := Color(0.18, 0.21, 0.47)
const ROBE_IN := Color(0.27, 0.3, 0.53)
const BEARD_WHITE := Color(0.84, 0.84, 0.82)
const SKIN_M := Color(0.6, 0.47, 0.41)
const FIRE := Color(1.0, 0.5, 0.14)
const ARCANE := Color(0.45, 0.9, 1.0)
const BOOK := Color(0.38, 0.12, 0.1)
# hunter
const HOOD_G := Color(0.32, 0.38, 0.18)
const CLOAK_G := Color(0.27, 0.32, 0.16)
const SLEEVE_G := Color(0.28, 0.34, 0.17)
const MASK := Color(0.42, 0.3, 0.18)
const JERKIN := Color(0.43, 0.3, 0.17)
const BRACER := Color(0.27, 0.24, 0.15)
const PANTS := Color(0.34, 0.3, 0.23)
const BOOT := Color(0.29, 0.19, 0.11)
const SKIN_H := Color(0.64, 0.46, 0.34)
const STRING := Color(0.68, 0.66, 0.58)
const FOCUS := Color(0.6, 1.0, 0.3)


static func build_sheet(kind: String) -> Image:
	var frames: Array = []
	for i in POSES.size():
		var pose: Dictionary = POSES[i]
		var p := Painter.new(FRAME, FRAME, 7100 + i * 37 + kind.length() * 211)
		p.set_real(1.0)
		var r := _rig(pose)
		var glows: Array = []
		match kind:
			"warrior":
				glows = _warrior(p, r)
			"mage":
				glows = _mage(p, r)
			"hunter":
				glows = _hunter(p, r)
		p.xf = Transform2D.IDENTITY
		_edges(p, 0.42, 0.12, 0.3)
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1], g[2], g[3])
		p.harden_alpha(0.5)
		var img := p.img
		if not pose.get("down", false):
			# the standing rig is designed with soles on row 93: seat them on the bottom row
			img = Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			img.blit_rect(p.img, Rect2i(0, 0, FRAME, FRAME - FEET_SHIFT), Vector2i(0, FEET_SHIFT))
		frames.append(img)
	return Painter.strip(frames)


static func bounds_report(sheet: Image) -> String:
	## "top-bottom" opaque rows per frame (checks figure height, feet contact, downed <= 45 px).
	var parts: Array = []
	for i in sheet.get_width() / FRAME:
		var ur := sheet.get_region(Rect2i(i * FRAME, 0, FRAME, FRAME)).get_used_rect()
		parts.append("%d:%d-%d" % [i, ur.position.y, ur.end.y - 1])
	return " ".join(parts)


# =============================================================================== rig

static func _rig(pose: Dictionary) -> Dictionary:
	var cx := 48.0
	var r := {
		"step": float(pose.get("step", 0.0)), "bob": float(pose.get("bob", 0.0)),
		"atk": int(pose.get("atk", 0)), "cast": bool(pose.get("cast", false)),
		"pain": bool(pose.get("pain", false)), "down": bool(pose.get("down", false)),
	}
	var step: float = r["step"]
	var lean := step * 0.02
	var hip := Vector2(cx, 53.0 + float(r["bob"]))
	var tilt := 0.0
	var spread := 0.0
	var crouch := 0.0
	var sq := 1.0
	var drop := 0.0
	if r["down"]:
		# slumped on the ground, hunched toward the viewer (vertical squash), propped on the
		# screen-right arm, head hanging
		lean = 0.28
		hip = Vector2(cx - 1.0, 88.5)
		tilt = 0.3
		sq = 0.72
		drop = 4.5
	elif r["pain"]:
		lean = 0.08
		hip += Vector2(2.0, 1.0)
		tilt = 0.16
		spread = 0.8
	elif r["atk"] == 1:
		crouch = 1.5
		spread = 1.2
		lean = 0.03
	elif r["atk"] == 2:
		crouch = 2.0
		spread = 2.0
		lean = -0.05
	elif r["cast"]:
		spread = 1.4
		tilt = -0.05
	hip.y += crouch
	var txf := Transform2D(lean, Vector2(1.0, sq), 0.0, hip) * Transform2D(0.0, -HIP_REST)
	var hxf := txf * Transform2D(0.0, NECK_REST) * Transform2D(tilt, Vector2.ZERO) * Transform2D(0.0, -NECK_REST + Vector2(0.0, drop))
	r["txf"] = txf
	r["hxf"] = hxf
	r["lsh"] = txf * Vector2(cx - 12.5, 28.0)
	r["rsh"] = txf * Vector2(cx + 12.5, 28.0)
	r["lhip"] = txf * Vector2(cx - 5.6, 55.5)
	r["rhip"] = txf * Vector2(cx + 5.6, 55.5)
	if r["down"]:
		# sitting: screen-left knee drawn up, screen-right leg stretched toward the viewer
		r["lknee"] = Vector2(cx - 9.5, 80.0)
		r["lank"] = Vector2(cx - 12.5, 90.0)
		r["rknee"] = Vector2(cx + 8.0, 87.5)
		r["rank"] = Vector2(cx + 15.5, 90.5)
	else:
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var lift := maxf(step * s, 0.0)
			var key := "l" if s < 0.0 else "r"
			r[key + "knee"] = Vector2(cx + s * (6.3 + spread * 1.1 - lift * 0.9), 72.5 + crouch * 0.6 - lift * 4.8)
			r[key + "ank"] = Vector2(cx + s * (6.0 + spread * 1.6 - lift * 0.6), 88.5 - lift * 6.0)
	# relaxed arms; each class overrides them for its actions
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	r["lel"] = lsh + Vector2(-1.8, 12.5)
	r["lwr"] = lsh + Vector2(-1.0 + step * 0.8, 24.0 + step * 1.5)
	r["rel"] = rsh + Vector2(1.8, 12.5)
	r["rwr"] = rsh + Vector2(1.0 + step * 0.8, 24.0 - step * 1.5)
	if r["down"]:
		# screen-right hand braced on the ground, the other one reaching out for help
		r["lel"] = lsh + Vector2(-7.0, -3.0)
		r["lwr"] = lsh + Vector2(-12.0, -9.5)
		r["rel"] = rsh + Vector2(6.0, 8.0)
		r["rwr"] = rsh + Vector2(9.0, 16.5)
	return r


static func _down_cape(p: Painter, r: Dictionary, c: Color, extra: float) -> void:
	## Cape / cloak pooled on the ground behind a downed champion.
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	var pts := PackedVector2Array([lsh + Vector2(1, -1), rsh + Vector2(-1, -1), Vector2(rsh.x + 8 + extra, 84), Vector2(rsh.x + 12 + extra, 93.5)])
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector2(lerpf(rsh.x + 12 + extra, lsh.x - 14 - extra, t), 93.5 - (i % 2) * 1.5))
	pts.append(Vector2(lsh.x - 9 - extra, 82))
	var top := (lsh + rsh) * 0.5
	_cyl(p, pts, c, top, Vector2(top.x, 93.5), 22.0, -0.45, 0.0, 0.85, 0.4)


static func _down_boot(p: Painter, an: Vector2, c: Color) -> Vector2:
	## Boot seen from the sole (leg pointing at the viewer); returns the sole centre.
	var sole := an + Vector2(0, 1.0)
	p.ball(sole.x, sole.y, 2.6, 3.0, c)
	p.ball(sole.x, sole.y + 0.8, 1.7, 1.9, c.darkened(0.35))
	return sole


# =============================================================================== shading helpers

static func _cyl(p: Painter, pts: PackedVector2Array, base: Color, a: Vector2, b: Vector2, hw: float, tilt: float = -0.25, rough: float = 0.0, folds: float = 0.0, fold_amp: float = 0.0) -> void:
	## Polygon shaded as a cylinder around the axis a->b (honours rotated transforms, unlike
	## Painter.cyl_poly / cloth); folds > 0 adds noise-modulated creases for fabric.
	var t := PackedVector2Array()
	for v in pts:
		t.append(p.tp(v))
	var ta := p.tp(a)
	var tb := p.tp(b)
	var d := (tb - ta).normalized()
	var perp := Vector2(d.y, -d.x)
	var hwp := hw * p.k
	var bb: Rect2i = p._bounds(t)
	for y in range(bb.position.y, bb.end.y + 1):
		for x in range(bb.position.x, bb.end.x + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(q, t):
				continue
			var rel := q - ta
			var u := rel.dot(perp)
			var nx := clampf(u / hwp, -0.97, 0.97)
			if fold_amp > 0.0:
				var wob := p.mid_noise(u * 0.6, rel.dot(d) * 0.08) * 2.5
				nx = clampf(nx + sin(u * folds + wob) * fold_amp, -0.97, 0.97)
			var n2 := perp * nx + d * tilt
			var n := Vector3(n2.x, n2.y, sqrt(maxf(1.0 - nx * nx, 0.0))).normalized()
			var s := p.shade_value(n, x, y)
			if rough > 0.0:
				s += (p.rng.randf() - 0.5) * rough
			p.put(x, y, p.col(base, s))


static func _mail(p: Painter, pts: PackedVector2Array, amount: float = 0.3) -> void:
	## Chainmail: staggered dark ring gaps and lit ring tops over what is painted inside pts.
	var t := PackedVector2Array()
	for v in pts:
		t.append(p.tp(v))
	var bb: Rect2i = p._bounds(t)
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
				p.img.set_pixel(x, y, Color(minf(c.r * (1.0 + amount * 0.5), 1.0), minf(c.g * (1.0 + amount * 0.5), 1.0), minf(c.b * (1.0 + amount * 0.5), 1.0), c.a))


static func _edges(p: Painter, dark: float, inner: float, lit: float) -> void:
	## Enemy-style silhouette treatment (outer pixel darkened, next ring slightly) except where the
	## edge faces the key light (upper left): there the edge pixel catches a thin warm rim light.
	var src := p.img.duplicate() as Image
	var ur := p.img.get_used_rect()
	var ldir := Vector2(-0.5, -0.87)
	for y in range(ur.position.y, ur.end.y):
		for x in range(ur.position.x, ur.end.x):
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var e := _edge_kind(src, x, y, p.w, p.h)
			if e == 0:
				continue
			if e == 2:
				p.img.set_pixel(x, y, Color(c.r * (1.0 - inner), c.g * (1.0 - inner), c.b * (1.0 - inner), c.a))
				continue
			var outv := Vector2.ZERO
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var qx := x + ox
					var qy := y + oy
					if qx < 0 or qy < 0 or qx >= p.w or qy >= p.h or src.get_pixel(qx, qy).a < 0.5:
						outv += Vector2(ox, oy)
			var facing := outv.normalized().dot(ldir) if outv.length() > 0.01 else 0.0
			if facing > 0.3:
				var a := lit * clampf((facing - 0.3) / 0.6, 0.0, 1.0)
				var tgt := Color(1.0, 0.94, 0.82)
				p.img.set_pixel(x, y, Color(lerpf(c.r, tgt.r, a), lerpf(c.g, tgt.g, a), lerpf(c.b, tgt.b, a), c.a))
			else:
				p.img.set_pixel(x, y, Color(c.r * (1.0 - dark), c.g * (1.0 - dark), c.b * (1.0 - dark) * 1.02, c.a))


static func _edge_kind(src: Image, x: int, y: int, w: int, h: int) -> int:
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + o
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or src.get_pixel(q.x, q.y).a < 0.5:
			return 1
	for o in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var q: Vector2i = Vector2i(x, y) + o
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or src.get_pixel(q.x, q.y).a < 0.5:
			return 2
	return 0


static func _blood_pool(p: Painter, cx: float, cy: float, rx: float) -> void:
	p.ellipse(cx, cy, rx, 2.9, Color(0.17, 0.015, 0.02))
	p.ellipse(cx - rx * 0.12, cy - 0.3, rx * 0.68, 1.9, Color(0.3, 0.025, 0.035))
	p.tput(cx - rx * 0.35, cy - 1.0, Color(0.55, 0.14, 0.14))
	p.tput(cx + rx * 0.2, cy - 0.6, Color(0.5, 0.12, 0.12))


static func _wound(p: Painter, at: Vector2, size: float) -> void:
	## Fresh blood on armour or cloth: a dark core and a few runs.
	p.ball(at.x, at.y, size, size * 0.85, BLOOD.darkened(0.2))
	p.tput(at.x - size * 0.3, at.y - size * 0.3, Color(0.62, 0.1, 0.1))
	p.line(at + Vector2(0.3, size * 0.6), at + Vector2(0.6, size * 0.6 + 3.0), BLOOD)
	p.line(at + Vector2(-size * 0.6, size * 0.4), at + Vector2(-size * 0.7, size * 0.4 + 2.0), BLOOD.darkened(0.15))


# =============================================================================== hands & weapons

static func _fist(p: Painter, at: Vector2, dir: Vector2, c: Color, rad: float = 2.2) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	p.ball(at.x + d.x * 0.6, at.y + d.y * 0.6, rad, rad * 0.95, c)
	var kn := at + d * (rad * 0.9)
	p.line(kn + n * (rad * 0.7), kn - n * (rad * 0.7), c.darkened(0.5))


static func _open_hand(p: Painter, at: Vector2, dir: Vector2, c: Color, spread: float = 0.95, length: float = 3.0) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	p.ball(at.x, at.y, 1.9, 1.7, c)
	for f in 4:
		var off := (float(f) - 1.5) * spread
		var b0 := at + d * 1.2 + n * off * 0.6
		var tip := b0 + d * length + n * off * 0.5
		p.strand(PackedVector2Array([b0, b0.lerp(tip, 0.55) + n * 0.2, tip]), 0.6, 0.45, c)
	p.capsule(at + n * 1.5, at + n * 2.6 + d * 1.6, 0.6, 0.5, c)


static func _axe(p: Painter, butt: Vector2, dir: Vector2, side: float, fs: float = 1.0, vs: float = 1.0) -> void:
	## Long bearded war axe, same make as the first-person axe: ash haft with gold bands and a
	## leather grip, broad steel head with a hooked beard and a back spike.
	## butt = haft end, dir = toward the head, side = which side the blade is on, fs = foreshortening
	## along the haft, vs = foreshortening across it (an axe lying on the ground).
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x) * side * vs
	var L := 37.0 * fs
	var hs := maxf(fs, 0.72)
	var top := butt + d * L
	p.capsule(butt, top + d * 1.0, 1.15, 1.0, WOOD)
	p.line(butt + d * 3.0 + n * 0.4, top - d * 6.0 + n * 0.4, WOOD.lightened(0.18))
	# leather grip
	p.capsule(butt + d * 2.0 * fs, butt + d * 11.0 * fs, 1.35, 1.35, LEATHER)
	for k in 4:
		var wp := butt + d * (3.2 + k * 2.2) * fs
		p.line(wp + n * 1.3 + d * 0.5, wp - n * 1.3 - d * 0.5, LEATHER.darkened(0.5))
	p.spec = 0.8
	p.ball(butt.x, butt.y, 1.6, 1.6, GOLD)
	for band in [0.48, 0.66]:
		var bp: Vector2 = butt + d * L * float(band)
		p.capsule(bp + n * 1.45, bp - n * 1.45, 0.6, 0.6, GOLD)
	# head
	var hc := butt + d * (L - 4.5 * hs)
	var blade := PackedVector2Array()
	for q in [Vector2(1.2, 4.4), Vector2(5.0, 5.0), Vector2(8.8, 6.4), Vector2(11.6, 7.8), Vector2(12.8, 4.2), Vector2(13.2, 0.0), Vector2(12.6, -4.4), Vector2(11.2, -8.8), Vector2(9.0, -7.6), Vector2(6.0, -4.6), Vector2(3.0, -2.8), Vector2(1.2, -2.6)]:
		var qv: Vector2 = q
		blade.append(hc + n * qv.x + d * qv.y * hs)
	p.spec = 0.7
	p.grad_poly(blade, STEEL, hc, n.normalized(), 13.0 * vs, 0.72, 1.12, 4.0)
	# honed edge bevel and a dark fuller
	var edge := [Vector2(11.0, 7.4), Vector2(12.2, 4.0), Vector2(12.6, 0.0), Vector2(12.0, -4.2), Vector2(10.6, -8.2)]
	for i in edge.size() - 1:
		var e0: Vector2 = edge[i]
		var e1: Vector2 = edge[i + 1]
		p.line(hc + n * e0.x + d * e0.y * hs, hc + n * e1.x + d * e1.y * hs, STEEL.lightened(0.5))
	p.line(hc + n * 4.0 + d * 3.0 * hs, hc + n * 4.6 + d * -2.0 * hs, STEEL_D.darkened(0.2))
	p.line(hc + n * 8.0 + d * 4.6 * hs, hc + n * 6.4 + d * -1.0 * hs, STEEL.lightened(0.2))
	# socket + back spike
	p.flat_poly(PackedVector2Array([hc + n * 1.9 + d * 5.2 * hs, hc - n * 1.9 + d * 5.2 * hs, hc - n * 1.9 - d * 3.4 * hs, hc + n * 1.9 - d * 3.4 * hs]), STEEL_D, Vector3(-0.3, -0.3, 1))
	p.poly(PackedVector2Array([hc - n * 1.8 + d * 2.4 * hs, hc - n * 5.6 + d * 0.8 * hs, hc - n * 1.8 - d * 1.0 * hs]), STEEL_D.darkened(0.15))
	p.capsule(top + n * 1.5, top - n * 1.5, 0.6, 0.6, GOLD)
	p.spec = 0.0


static func _staff(p: Painter, bot: Vector2, top: Vector2, gem: Color, glows: Array, flare: float = 1.0) -> void:
	## Gnarled wizard staff (first-person staff look): twisted dark wood, knots, gold rings and a
	## wooden claw cradling a glowing gem.
	var d := (top - bot).normalized()
	var n := Vector2(-d.y, d.x)
	var L := bot.distance_to(top)
	var pts := PackedVector2Array()
	for i in 10:
		var t := float(i) / 9.0
		pts.append(bot.lerp(top, t) + n * sin(t * 15.0) * 0.5)
	p.strand(pts, 1.0, 1.25, Color(0.3, 0.2, 0.12))
	for kk in 5:
		var kp := bot.lerp(top, 0.22 + kk * 0.13) + n * (1.0 if kk % 2 == 0 else -1.0)
		p.ball(kp.x, kp.y, 0.9, 0.8, Color(0.25, 0.16, 0.1))
	p.spec = 0.8
	for band in [L - 7.5, L - 9.5]:
		var bp: Vector2 = bot + d * float(band)
		p.capsule(bp + n * 1.7, bp - n * 1.7, 0.55, 0.55, GOLD)
	p.spec = 0.0
	var head := top - d * 1.5
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.strand(PackedVector2Array([head - d * 4.5 + n * s * 0.8, head - d * 1.2 + n * s * 2.7, head + d * 2.0 + n * s * 2.6, head + d * 3.6 + n * s * 0.8]), 0.85, 0.45, Color(0.31, 0.21, 0.13))
	var gc := head + d * 0.4
	p.ball(gc.x, gc.y, 2.0, 2.2, gem.darkened(0.15))
	p.ball(gc.x - 0.4, gc.y - 0.5, 1.1, 1.1, gem.lightened(0.55))
	p.light_only(gc.x, gc.y, 9.0 * flare, gem, 0.55)
	glows.append([p.tp(gc), 4.5 * flare, gem, 0.9])
	glows.append([p.tp(gc), 1.8 * flare, Color(1, 0.96, 0.85), 0.9])


static func _bow(p: Painter, grip: Vector2, axis: Vector2, out: Vector2, half: float, bend: float, nock: Variant = null) -> void:
	## Yew longbow: limbs bow away from the string (toward `out`), horn-capped recurved tips,
	## leather grip. nock = where the string is pulled to, or null for a resting string.
	var a := axis.normalized()
	var o := out.normalized()
	var pts := PackedVector2Array()
	for i in 13:
		var t := lerpf(-1.0, 1.0, float(i) / 12.0)
		pts.append(grip - o * bend + a * (t * half) + o * (bend * (1.0 - t * t)))
	var bot_tip: Vector2 = pts[0]
	var top_tip: Vector2 = pts[12]
	if nock == null:
		p.line(top_tip, bot_tip, STRING)
	else:
		var nk: Vector2 = nock
		p.line(top_tip, nk, STRING)
		p.line(nk, bot_tip, STRING)
	for i in 12:
		var t0 := absf(lerpf(-1.0, 1.0, float(i) / 12.0))
		var t1 := absf(lerpf(-1.0, 1.0, float(i + 1) / 12.0))
		p.capsule(pts[i], pts[i + 1], lerpf(1.8, 0.75, t0), lerpf(1.8, 0.75, t1), WOOD)
	for i in range(2, 10):
		p.line(pts[i] - o * 0.6 - a * 0.2, pts[i + 1] - o * 0.6, WOOD.lightened(0.2))
	p.capsule(top_tip, top_tip + o * 1.7 + a * 1.3, 0.65, 0.45, Color(0.6, 0.55, 0.44))
	p.capsule(bot_tip, bot_tip + o * 1.7 - a * 1.3, 0.65, 0.45, Color(0.6, 0.55, 0.44))
	p.capsule(grip - a * 2.6, grip + a * 2.6, 1.75, 1.75, LEATHER.darkened(0.15))
	p.line(grip - a * 1.2 - o * 1.5, grip - a * 1.2 + o * 1.5, LEATHER.darkened(0.55))
	p.line(grip + a * 1.2 - o * 1.5, grip + a * 1.2 + o * 1.5, LEATHER.darkened(0.55))


static func _arrow(p: Painter, tail: Vector2, head: Vector2) -> void:
	var d := (head - tail).normalized()
	var n := Vector2(-d.y, d.x)
	p.line(tail, head - d * 1.0, Color(0.6, 0.46, 0.28))
	p.flat_poly(PackedVector2Array([head + d * 2.6, head - d * 0.8 + n * 1.4, head - d * 0.8 - n * 1.4]), Color(0.6, 0.62, 0.66), Vector3(-0.4, -0.6, 0.7))
	for k in 2:
		var fp := tail + d * (2.6 + k * 1.3)
		p.line(fp, fp - d * 2.0 + n * 1.4, Color(0.62, 0.13, 0.1) if k == 0 else Color(0.86, 0.83, 0.76))
		p.line(fp, fp - d * 2.0 - n * 1.4, Color(0.86, 0.83, 0.76) if k == 0 else Color(0.62, 0.13, 0.1))


static func _swing_arc(glows: Array, from: Vector2, to: Vector2, bulge: float, c: Color) -> void:
	for kk in 14:
		var t := float(kk) / 13.0
		var pt := from.lerp(to, t) + Vector2(-sin(t * PI) * bulge, -sin(t * PI) * bulge * 0.3)
		glows.append([pt, 2.2, c, 0.28])


# =============================================================================== warrior

static func _warrior(p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	var cx := 48.0
	var atk: int = r["atk"]
	var cast: bool = r["cast"]
	var pain: bool = r["pain"]
	var down: bool = r["down"]
	var step: float = r["step"]
	var txf: Transform2D = r["txf"]
	var hxf: Transform2D = r["hxf"]
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	var lel: Vector2 = r["lel"]
	var lwr: Vector2 = r["lwr"]
	var rel: Vector2 = r["rel"]
	var rwr: Vector2 = r["rwr"]
	var sway := step * 2.0
	# ---- arms & axe for this pose
	var axe_dir := Vector2(0.1 + step * 0.04, -1.0)
	var axe_side := 1.0
	var axe_fs := 1.0
	var axe_butt := Vector2.ZERO
	var l_dir := lwr - lel
	var r_dir := rwr - rel
	var l_open := false
	var mouth := "closed"
	var eye_glow := false
	if down:
		mouth = "pain"
		l_open = true
		l_dir = Vector2(-0.55, -0.85)
		r_dir = Vector2(0.3, 1.0)
		axe_butt = Vector2(cx - 4.0, 94.0)
		axe_dir = Vector2(-1.0, -0.1)
	elif atk == 1:
		# axe heaved back over the right shoulder, both hands on the haft
		axe_dir = Vector2(0.42, -0.9)
		axe_fs = 0.64
		axe_butt = rsh + Vector2(-1.5, 0.5)
		var dn := axe_dir.normalized()
		rwr = axe_butt + dn * 8.0
		lwr = axe_butt + dn * 3.0
		rel = rsh + Vector2(8.5, 4.0)
		lel = lsh + Vector2(9.0, 9.0)
		r_dir = dn
		l_dir = dn
		mouth = "grimace"
	elif atk == 2:
		# follow-through: the chop ends low on the left
		axe_dir = Vector2(-0.62, 0.79)
		var dn2 := axe_dir.normalized()
		axe_butt = Vector2(cx + 4.0, 44.5)
		rwr = axe_butt + dn2 * 8.0
		lwr = axe_butt + dn2 * 3.0
		rel = rsh + Vector2(1.5, 11.0)
		lel = lsh + Vector2(1.0, 10.0)
		r_dir = dn2
		l_dir = dn2
		mouth = "roar"
		_swing_arc(glows, Vector2(80, 6), Vector2(18, 76), 10.0, Color(0.62, 0.62, 0.68))
	elif cast:
		# battle cry: axe brandished high, other fist raised, head thrown back
		rel = rsh + Vector2(9.0, -4.0)
		rwr = rsh + Vector2(7.0, -10.5)
		axe_dir = Vector2(0.1, -1.0)
		axe_butt = rwr - axe_dir.normalized() * 24.0
		r_dir = Vector2(0, -1)
		lel = lsh + Vector2(-7.5, -4.0)
		lwr = lsh + Vector2(-4.5, -13.5)
		l_dir = Vector2(0.1, -1)
		mouth = "roar"
		eye_glow = true
	elif pain:
		rel = rsh + Vector2(5.5, 8.5)
		rwr = rsh + Vector2(10.0, 14.0)
		axe_dir = Vector2(0.3, -0.95)
		axe_butt = rwr - axe_dir.normalized() * 8.0
		r_dir = axe_dir
		lel = lsh + Vector2(-5.5, 8.0)
		lwr = lsh + Vector2(-10.5, 15.5)
		l_dir = lwr - lel
		l_open = true
		mouth = "grimace"
	else:
		rel = rsh + Vector2(3.0, 12.0)
		rwr = rsh + Vector2(2.5, 23.0 - step * 1.0)
		axe_butt = rwr - axe_dir.normalized() * 8.0
		r_dir = Vector2(0.15, -1)
	if down:
		_blood_pool(p, cx + 2.0, 92.5, 24.0)
	# ---- cape (behind)
	if down:
		_down_cape(p, r, CRIMSON.darkened(0.3), 2.0)
	else:
		p.xf = txf
		var cape := PackedVector2Array([Vector2(cx - 12, 26), Vector2(cx + 12, 26), Vector2(cx + 16.5, 52), Vector2(cx + 18 + sway, 84)])
		for i in 11:
			var t := float(i) / 10.0
			cape.append(Vector2(lerpf(cx + 18 + sway, cx - 18 + sway, t), 87.0 - (i % 2) * 3.0 - (1.5 if i % 3 == 1 else 0.0)))
		cape.append(Vector2(cx - 16.5, 52))
		_cyl(p, cape, CRIMSON.darkened(0.3), Vector2(cx, 26), Vector2(cx, 86), 18.0, -0.1, 0.0, 0.85, 0.4)
		p.xf = Transform2D.IDENTITY
		_warrior_legs(p, r)
	# ---- mail skirt & tabard
	p.xf = txf
	var skirt := PackedVector2Array([Vector2(cx - 10.5, 48), Vector2(cx + 10.5, 48), Vector2(cx + 12.0, 62.5), Vector2(cx + 7, 64), Vector2(cx - 7, 64), Vector2(cx - 12.0, 62.5)])
	_cyl(p, skirt, MAIL, Vector2(cx, 48), Vector2(cx, 64), 12.0, -0.1)
	_mail(p, skirt, 0.32)
	p.strand(PackedVector2Array([Vector2(cx - 11.8, 62.6), Vector2(cx - 7, 64), Vector2(cx + 7, 64), Vector2(cx + 11.8, 62.6)]), 0.6, 0.6, MAIL.darkened(0.35))
	var tab := PackedVector2Array([Vector2(cx - 5, 49.5), Vector2(cx + 5, 49.5), Vector2(cx + 5.8 + sway * 0.3, 67), Vector2(cx + 3.2, 69.5), Vector2(cx + 1.2, 67.5), Vector2(cx - 0.8, 70.5), Vector2(cx - 2.8, 67.5), Vector2(cx - 5.8 + sway * 0.3, 68.5)])
	_cyl(p, tab, CRIMSON, Vector2(cx, 49), Vector2(cx, 70), 6.0, -0.1, 0.0, 1.3, 0.3)
	p.line(Vector2(cx - 4.4, 51), Vector2(cx - 5.0, 66), GOLD.darkened(0.25))
	p.line(Vector2(cx + 4.4, 51), Vector2(cx + 5.0, 66), GOLD.darkened(0.4))
	p.poly(PackedVector2Array([Vector2(cx, 53.5), Vector2(cx + 1.8, 56), Vector2(cx, 58.5), Vector2(cx - 1.8, 56)]), GOLD.darkened(0.2))
	p.tput(cx, 56, CRIMSON.darkened(0.3))
	# ---- torso: mail hauberk under a plate breastplate
	var core := PackedVector2Array([Vector2(cx - 12, 25.5), Vector2(cx + 12, 25.5), Vector2(cx + 12.5, 33), Vector2(cx + 10.5, 49), Vector2(cx - 10.5, 49), Vector2(cx - 12.5, 33)])
	_cyl(p, core, MAIL, Vector2(cx, 25), Vector2(cx, 49), 12.5, -0.3)
	_mail(p, core, 0.3)
	p.spec = 0.6
	p.shininess = 26.0
	var bp := PackedVector2Array([Vector2(cx - 9.6, 27.5), Vector2(cx - 3, 26.2), Vector2(cx + 3, 26.2), Vector2(cx + 9.6, 27.5), Vector2(cx + 10.6, 34), Vector2(cx + 9.4, 41.5), Vector2(cx + 6.4, 46.5), Vector2(cx, 47.8), Vector2(cx - 6.4, 46.5), Vector2(cx - 9.4, 41.5), Vector2(cx - 10.6, 34)])
	_cyl(p, bp, STEEL, Vector2(cx, 26), Vector2(cx, 48), 10.8, -0.2)
	p.spec = 0.0
	p.shininess = 18.0
	# medial ridge, pectoral fold, lower lame, gold edging
	p.line(Vector2(cx - 0.5, 29), Vector2(cx - 0.5, 46.8), STEEL.lightened(0.3))
	p.line(Vector2(cx + 0.6, 29), Vector2(cx + 0.6, 46.8), STEEL_D.darkened(0.25))
	p.line(Vector2(cx - 9.2, 36.5), Vector2(cx - 2.0, 38.0), STEEL_D)
	p.line(Vector2(cx + 2.0, 38.0), Vector2(cx + 9.2, 36.5), STEEL_D.darkened(0.25))
	p.line(Vector2(cx - 9.0, 41.0), Vector2(cx - 1.2, 42.4), STEEL_D.darkened(0.15))
	p.line(Vector2(cx + 1.4, 42.4), Vector2(cx + 9.0, 41.0), STEEL_D.darkened(0.3))
	p.strand(PackedVector2Array([Vector2(cx - 9.4, 41.6), Vector2(cx - 6.4, 46.5), Vector2(cx, 47.8), Vector2(cx + 6.4, 46.5), Vector2(cx + 9.4, 41.6)]), 0.55, 0.55, GOLD)
	p.strand(PackedVector2Array([Vector2(cx - 9.6, 27.6), Vector2(cx - 3, 26.4), Vector2(cx + 3, 26.4), Vector2(cx + 9.6, 27.6)]), 0.5, 0.5, GOLD.darkened(0.15))
	p.capsule(Vector2(cx - 11, 49.4), Vector2(cx + 11, 49.4), 1.4, 1.4, LEATHER)
	p.spec = 0.8
	p.rect(cx - 1.8, 47.8, 3.6, 3.2, GOLD)
	p.spec = 0.0
	p.rect(cx - 0.7, 48.7, 1.4, 1.4, LEATHER.darkened(0.45))
	p.xf = Transform2D.IDENTITY
	if down:
		_warrior_legs(p, r)
	# ---- upper arms (mail sleeves)
	for arm in [[lsh, lel], [rsh, rel]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		p.capsule(sh, el, 3.2, 2.7, MAIL)
		var ua := (el - sh).normalized()
		var un := Vector2(-ua.y, ua.x)
		for k in 3:
			var mp := sh.lerp(el, 0.35 + k * 0.22)
			p.line(mp + un * 2.6, mp - un * 2.6, MAIL.darkened(0.35))
	# ---- fur mantle & pauldrons (dome + lame, gold-rimmed)
	p.xf = txf
	p.ball(cx, 25.5, 12.5, 4.6, FUR, 0.45)
	for i in 11:
		var fx := cx - 11.5 + i * 2.3
		p.strand(PackedVector2Array([Vector2(fx, 27.0), Vector2(fx + 0.4 * float((i % 3) - 1), 29.6 + (i % 2) * 1.2)]), 0.85, 0.4, FUR.darkened(0.2) if i % 2 == 0 else FUR.lightened(0.06))
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var pc := Vector2(cx + s * 13.6, 26.4)
		p.spec = 0.7
		p.shininess = 24.0
		p.ball(pc.x + s * 1.2, pc.y + 4.6, 5.4, 2.7, GOLD.darkened(0.2))
		p.ball(pc.x + s * 1.2, pc.y + 3.9, 5.3, 2.6, STEEL.darkened(0.15))
		p.ball(pc.x, pc.y + 0.9, 6.7, 4.5, GOLD.darkened(0.1))
		p.ball(pc.x, pc.y, 6.5, 4.4, STEEL)
		p.spec = 0.0
		p.shininess = 18.0
		p.line(Vector2(pc.x - s * 4.5, pc.y - 1.2), Vector2(pc.x + s * 4.5, pc.y - 2.6), STEEL.lightened(0.25))
		p.tput(pc.x - s * 3.4, pc.y + 1.6, GOLD.lightened(0.3))
		p.tput(pc.x + s * 3.0, pc.y + 1.2, GOLD.lightened(0.1))
	# ---- head
	p.xf = hxf
	_warrior_head(p, 48.0, 16.0, mouth, eye_glow, glows)
	# ---- forearms (plate vambraces with gold bands), the axe, gauntlets
	p.xf = Transform2D.IDENTITY
	for arm in [[lel, lwr], [rel, rwr]]:
		var el2: Vector2 = arm[0]
		var wr: Vector2 = arm[1]
		var dn3 := (wr - el2).normalized()
		var nn := Vector2(-dn3.y, dn3.x)
		p.spec = 0.6
		p.capsule(el2, wr, 2.7, 2.3, STEEL)
		for band in [0.35, 0.78]:
			var bb: Vector2 = el2.lerp(wr, float(band))
			p.capsule(bb + nn * 2.4, bb - nn * 2.4, 0.5, 0.5, GOLD)
		p.ball(el2.x, el2.y, 2.7, 2.5, STEEL.lightened(0.04))
		p.spec = 0.0
	_axe(p, axe_butt, axe_dir, axe_side, axe_fs, 0.6 if down else 1.0)
	p.spec = 0.6
	_fist(p, rwr, r_dir, STEEL, 2.4)
	if l_open:
		_open_hand(p, lwr, l_dir, STEEL.darkened(0.05), 1.0, 3.0)
	else:
		_fist(p, lwr, l_dir, STEEL, 2.4)
	p.spec = 0.0
	if pain:
		_wound(p, Vector2(cx + 7.0, 34.0), 1.3)
	if down:
		p.xf = txf
		_wound(p, Vector2(cx + 3.5, 39.0), 1.7)
		p.xf = Transform2D.IDENTITY
	if cast:
		p.light_only(cx, 18, 22, RAGE, 0.14)
		for kk in 10:
			var ang := -PI * 0.5 + (float(kk) - 4.5) * 0.32
			var rr := 21.0 + (kk % 3) * 3.0
			glows.append([Vector2(cx, 22) + Vector2(cos(ang), sin(ang)) * rr, 1.6, RAGE, 0.55])
	p.grime(Color(0.13, 0.1, 0.08), 0.36, 0.1, 0.16, 0.5)
	return glows


static func _warrior_legs(p: Painter, r: Dictionary) -> void:
	## Mail chausses, plate greaves and knee cops, leather boots with steel toes.
	var down: bool = r["down"]
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var key := "l" if s < 0.0 else "r"
		var hp: Vector2 = r[key + "hip"]
		var kn: Vector2 = r[key + "knee"]
		var an: Vector2 = r[key + "ank"]
		var shin := (an - kn).normalized()
		var sn := Vector2(-shin.y, shin.x)
		p.capsule(hp, kn, 3.8, 3.1, MAIL)
		p.spec = 0.6
		p.capsule(kn + shin * 1.0, an - shin * 0.5, 2.9, 2.4, STEEL)
		p.line(kn + shin * 2.5 - sn * 0.4, an - shin * 2.0 - sn * 0.4, STEEL.lightened(0.28))
		p.ball(kn.x, kn.y, 3.1, 2.7, STEEL.lightened(0.04))
		p.spec = 0.0
		p.tput(kn.x, kn.y, GOLD.lightened(0.2))
		if down:
			var sole := _down_boot(p, an, LEATHER)
			p.spec = 0.6
			p.ball(sole.x, sole.y - 1.6, 2.0, 1.1, STEEL_D)
			p.spec = 0.0
			continue
		var foot := an + Vector2(s * 0.6, 2.9)
		p.ball(foot.x, foot.y, 3.8, 2.4, LEATHER)
		p.capsule(an - sn * 2.6 - shin * 0.6, an + sn * 2.6 - shin * 0.6, 1.0, 1.0, LEATHER.darkened(0.25))
		p.spec = 0.6
		p.ball(foot.x, foot.y + 0.6, 2.2, 1.5, STEEL_D)
		p.spec = 0.0


static func _warrior_head(p: Painter, hx: float, hy: float, mouth: String, eye_glow: bool, glows: Array) -> void:
	# face
	p.ball(hx, hy + 0.8, 4.7, 5.6, SKIN_W)
	p.ball(hx - 2.8, hy + 2.6, 1.6, 1.3, SKIN_W.lightened(0.05))
	p.ball(hx + 2.8, hy + 2.6, 1.6, 1.3, SKIN_W.darkened(0.06))
	p.ellipse(hx, hy + 0.3, 4.3, 1.3, SKIN_W.darkened(0.62))
	for exv in [-1.8, 1.8]:
		var ex: float = exv
		if eye_glow:
			p.tput(hx + ex, hy + 0.3, Color(1.0, 0.9, 0.6))
			glows.append([p.tp(Vector2(hx + ex + 0.5, hy + 0.8)), 2.2, RAGE, 0.9])
		else:
			p.tput(hx + ex, hy + 0.3, Color(0.72, 0.74, 0.76))
	p.capsule(Vector2(hx + 0.2, hy + 0.8), Vector2(hx + 0.4, hy + 3.6), 0.8, 1.1, SKIN_W.lightened(0.07))
	# great red-brown beard with two gold-ringed braids
	var beard := PackedVector2Array([Vector2(hx - 5.0, hy + 1.6), Vector2(hx - 3.6, hy + 4.4), Vector2(hx - 1.8, hy + 4.2), Vector2(hx + 1.8, hy + 4.2), Vector2(hx + 3.6, hy + 4.4), Vector2(hx + 5.0, hy + 1.6), Vector2(hx + 5.8, hy + 7.0), Vector2(hx + 5.0, hy + 11.5), Vector2(hx + 2.6, hy + 15.0), Vector2(hx, hy + 16.2), Vector2(hx - 2.6, hy + 15.0), Vector2(hx - 5.0, hy + 11.5), Vector2(hx - 5.8, hy + 7.0)])
	_cyl(p, beard, BEARD_RED, Vector2(hx, hy + 2), Vector2(hx, hy + 16), 6.0, -0.2, 0.0, 1.6, 0.45)
	for i in 6:
		var bx := hx - 3.8 + i * 1.5
		p.line(Vector2(bx, hy + 8.5), Vector2(bx + (float(i) - 2.5) * 0.3, hy + 13.5 - absf(float(i) - 2.5)), BEARD_RED.darkened(0.42))
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.strand(PackedVector2Array([Vector2(hx + s * 1.7, hy + 13.8), Vector2(hx + s * 2.0, hy + 16.5), Vector2(hx + s * 1.8, hy + 18.6)]), 0.9, 0.6, BEARD_RED.darkened(0.08))
		p.tput(hx + s * 2.0, hy + 16.6, GOLD.lightened(0.25))
	match mouth:
		"roar":
			p.ellipse(hx, hy + 6.8, 1.9, 1.7, Color(0.12, 0.03, 0.03))
			p.rect(hx - 1.3, hy + 5.4, 2.6, 0.6, Color(0.75, 0.7, 0.6))
		"grimace":
			p.ellipse(hx, hy + 6.2, 1.9, 0.8, Color(0.12, 0.03, 0.03))
			p.rect(hx - 1.4, hy + 5.8, 2.8, 0.6, Color(0.72, 0.68, 0.58))
		"pain":
			p.ellipse(hx, hy + 6.3, 1.3, 0.8, Color(0.12, 0.03, 0.03))
		_:
			p.line(Vector2(hx - 1.4, hy + 6.0), Vector2(hx + 1.4, hy + 6.1), Color(0.18, 0.07, 0.04))
	p.strand(PackedVector2Array([Vector2(hx - 3.6, hy + 5.6), Vector2(hx - 1.2, hy + 4.6), Vector2(hx + 1.2, hy + 4.6), Vector2(hx + 3.6, hy + 5.6)]), 0.85, 0.75, BEARD_RED.lightened(0.08))
	# horned steel helm with brow band, gold rivets and nasal guard
	p.spec = 0.85
	p.shininess = 22.0
	var dome := PackedVector2Array([Vector2(hx - 6.0, hy - 0.8), Vector2(hx - 5.9, hy - 4.8), Vector2(hx - 4.1, hy - 8.0), Vector2(hx, hy - 9.4), Vector2(hx + 4.1, hy - 8.0), Vector2(hx + 5.9, hy - 4.8), Vector2(hx + 6.0, hy - 0.8), Vector2(hx + 3.0, hy - 1.8), Vector2(hx - 3.0, hy - 1.8)])
	_cyl(p, dome, STEEL, Vector2(hx, hy - 9), Vector2(hx, hy), 6.0, -0.5)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.flat_poly(PackedVector2Array([Vector2(hx + s * 6.1, hy - 1.4), Vector2(hx + s * 4.4, hy - 1.4), Vector2(hx + s * 4.3, hy + 3.2), Vector2(hx + s * 5.7, hy + 2.4)]), STEEL_D, Vector3(s * 0.7, 0.0, 1.0))
	p.line(Vector2(hx - 0.4, hy - 9.0), Vector2(hx - 0.4, hy - 2.4), STEEL.lightened(0.3))
	p.line(Vector2(hx + 0.6, hy - 9.0), Vector2(hx + 0.6, hy - 2.4), STEEL_D)
	p.capsule(Vector2(hx - 6.2, hy - 1.4), Vector2(hx + 6.2, hy - 1.4), 0.95, 0.95, STEEL_D.lightened(0.12))
	for i in 5:
		p.tput(hx - 5.0 + i * 2.5, hy - 1.6, GOLD.lightened(0.25))
	p.capsule(Vector2(hx, hy - 1.6), Vector2(hx, hy + 2.6), 0.8, 0.6, STEEL)
	p.spec = 0.0
	p.shininess = 18.0
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var h0 := Vector2(hx + s * 5.2, hy - 5.0)
		var pts := PackedVector2Array([h0, h0 + Vector2(s * 3.6, -1.0), h0 + Vector2(s * 6.6, -4.4), h0 + Vector2(s * 7.0, -9.0)])
		p.strand(pts, 1.95, 0.45, HORN)
		for k in 3:
			var q := pts[1].lerp(pts[2], 0.2 + k * 0.35) if k < 2 else pts[2].lerp(pts[3], 0.35)
			p.line(q + Vector2(-0.9, -0.6 * s), q + Vector2(0.9, 0.6 * s), HORN.darkened(0.4))
		p.line(h0 + Vector2(s * 0.5, -1.0), h0 + Vector2(s * 3.8, -1.9), HORN.lightened(0.18))


# =============================================================================== mage

static func _mage(p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	var cx := 48.0
	var atk: int = r["atk"]
	var cast: bool = r["cast"]
	var pain: bool = r["pain"]
	var down: bool = r["down"]
	var step: float = r["step"]
	var txf: Transform2D = r["txf"]
	var hxf: Transform2D = r["hxf"]
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	var lel: Vector2 = r["lel"]
	var lwr: Vector2 = r["lwr"]
	var rel: Vector2 = r["rel"]
	var rwr: Vector2 = r["rwr"]
	var sway := step * 2.0
	var gem := FIRE
	var flare := 1.0
	var s_bot := Vector2.ZERO
	var s_top := Vector2.ZERO
	var l_dir := lwr - lel
	var r_dir := Vector2(0, -1)
	var l_open := true
	var r_open := false
	var mouth := "closed"
	var eye_glow := false
	if down:
		mouth = "pain"
		l_dir = Vector2(-0.55, -0.85)
		r_dir = Vector2(0.3, 1.0)
		r_open = true
		s_bot = Vector2(3, 93.5)
		s_top = Vector2(cx - 16.0, 91.0)
		flare = 0.5
	elif atk == 1:
		# staff raised high, fire gathering in the other palm
		rel = rsh + Vector2(7.0, -3.0)
		rwr = rsh + Vector2(4.0, -14.0)
		var sd := Vector2(-0.2, -1.0).normalized()
		s_top = rwr + sd * 12.0
		s_bot = rwr - sd * 48.0
		lel = lsh + Vector2(1.0, 10.5)
		lwr = Vector2(cx - 5.0, 39.0)
		l_dir = Vector2(0.4, -1.0)
		flare = 1.3
		var orb := lwr + Vector2(1.0, -4.0)
		p.light_only(orb.x, orb.y, 9.0, FIRE, 0.3)
		glows.append([orb, 3.5, FIRE, 1.0])
		glows.append([orb, 1.5, Color(1, 0.95, 0.8), 0.9])
	elif atk == 2:
		# spell thrust: both hands drive the staff out to the left, the gem flares
		var sd2 := Vector2(-0.84, -0.54).normalized()
		rwr = Vector2(cx + 1.0, 38.5)
		lwr = rwr + sd2 * 7.0
		s_top = rwr + sd2 * 21.0
		s_bot = rwr - sd2 * 28.0
		rel = rsh + Vector2(0.5, 10.0)
		lel = lsh + Vector2(-1.0, 9.5)
		l_dir = sd2
		r_dir = sd2
		l_open = false
		flare = 2.0
		mouth = "roar"
	elif cast:
		# both arms raised, arcane power between the hands
		rel = rsh + Vector2(7.5, -6.0)
		rwr = rsh + Vector2(5.0, -16.5)
		s_top = rwr + Vector2(-0.4, -9.5)
		s_bot = rwr + Vector2(1.2, 50.0)
		lel = lsh + Vector2(-7.5, -6.0)
		lwr = lsh + Vector2(-5.0, -16.5)
		l_dir = Vector2(0.15, -1.0)
		gem = ARCANE
		flare = 1.4
		mouth = "roar"
		eye_glow = true
	elif pain:
		rel = rsh + Vector2(6.0, 9.0)
		rwr = rsh + Vector2(11.0, 16.0)
		var sd3 := Vector2(0.35, -1.0).normalized()
		s_top = rwr + sd3 * 30.0
		s_bot = rwr - sd3 * 22.0
		lel = lsh + Vector2(-5.5, 8.0)
		lwr = lsh + Vector2(-11.0, 14.5)
		l_dir = lwr - lel
		mouth = "grimace"
	else:
		rel = rsh + Vector2(3.5, 11.0)
		rwr = rsh + Vector2(4.6, 20.5 - step * 0.8)
		s_top = Vector2(rwr.x - 1.6, 8.0 + float(r["bob"]))
		s_bot = Vector2(rwr.x + 1.3, 93.5 - maxf(step, 0.0) * 1.5)
		lel = lsh + Vector2(-2.5, 11.0)
		lwr = Vector2(cx - 8.5, 47.0 + step * 1.0 + float(r["bob"]))
		l_dir = Vector2(0.55, 0.8)
		l_open = false
	if down:
		_blood_pool(p, cx + 2.0, 92.5, 23.0)
		# robe pooled on the ground around the seated mage
		var pool := PackedVector2Array([Vector2(cx - 17, 84), Vector2(cx - 21, 93.6), Vector2(cx + 24, 93.6), Vector2(cx + 19, 83), Vector2(cx + 9, 78), Vector2(cx - 8, 79)])
		_cyl(p, pool, ROBE.darkened(0.12), Vector2(cx, 78), Vector2(cx, 93), 22.0, -0.55, 0.0, 0.8, 0.4)
		p.strand(PackedVector2Array([Vector2(cx - 20.5, 92.2), Vector2(cx, 92.8), Vector2(cx + 23.5, 92.2)]), 0.6, 0.6, GOLD.darkened(0.2))
	else:
		# feet peeking under the hem
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var key := "l" if s < 0.0 else "r"
			var an: Vector2 = r[key + "ank"]
			p.ball(an.x + s * 0.5, an.y + 3.2, 3.0, 2.0, Color(0.2, 0.14, 0.1))
	# ---- robe
	p.xf = txf
	var robe := PackedVector2Array([Vector2(cx - 11, 25), Vector2(cx + 11, 25), Vector2(cx + 12, 36), Vector2(cx + 10.5, 48), Vector2(cx + 13.5 + sway * 0.5, 70), Vector2(cx + 16.5 + sway, 91)])
	for i in 13:
		var t := float(i) / 12.0
		robe.append(Vector2(lerpf(cx + 16.5 + sway, cx - 16.5 + sway, t), 93.4 - absf(sin(t * PI * 6.0)) * 1.3))
	robe.append(Vector2(cx - 16.5 + sway, 91))
	robe.append(Vector2(cx - 13.5 + sway * 0.5, 70))
	robe.append(Vector2(cx - 10.5, 48))
	robe.append(Vector2(cx - 12, 36))
	if down:
		robe = PackedVector2Array([Vector2(cx - 11, 25), Vector2(cx + 11, 25), Vector2(cx + 12, 36), Vector2(cx + 10.5, 48), Vector2(cx + 13, 58), Vector2(cx - 13, 58), Vector2(cx - 10.5, 48), Vector2(cx - 12, 36)])
	_cyl(p, robe, ROBE, Vector2(cx, 25), Vector2(cx, 93), 16.0, -0.12, 0.0, 0.75, 0.42)
	if step != 0.0 and not down:
		# the striding knee pushes the cloth forward
		var ks := signf(step)
		p.ball(cx + ks * 7.0 + sway * 0.4, 72.0, 3.2, 5.0, ROBE.lightened(0.07))
	if not down:
		var panel := PackedVector2Array([Vector2(cx - 3.2, 50), Vector2(cx + 3.2, 50), Vector2(cx + 6.5 + sway, 92.6), Vector2(cx - 6.5 + sway, 92.6)])
		_cyl(p, panel, ROBE_IN, Vector2(cx, 50), Vector2(cx + sway, 92), 7.0, -0.1, 0.0, 1.1, 0.25)
		p.line(Vector2(cx - 3.4, 50.5), Vector2(cx - 6.7 + sway, 92.4), GOLD.darkened(0.1))
		p.line(Vector2(cx + 3.4, 50.5), Vector2(cx + 6.7 + sway, 92.4), GOLD.darkened(0.3))
		for k in 4:
			var ey := 58.0 + k * 8.5
			var ex := cx + sway * (ey - 50.0) / 42.0
			p.poly(PackedVector2Array([Vector2(ex, ey - 1.6), Vector2(ex + 1.2, ey), Vector2(ex, ey + 1.6), Vector2(ex - 1.2, ey)]), GOLD.darkened(0.3))
		for i in 34:
			var t2 := float(i) / 33.0
			var hx2 := lerpf(cx - 16.0 + sway, cx + 16.0 + sway, t2)
			p.tput(hx2, 90.2 + sin(t2 * 30.0) * 0.4, GOLD.darkened(0.15 if i % 3 == 0 else 0.4))
			p.tput(hx2, 91.2, GOLD.darkened(0.5))
	# belt, sash and a tome on the hip
	p.capsule(Vector2(cx - 10.6, 49), Vector2(cx + 10.6, 49), 1.3, 1.3, Color(0.27, 0.16, 0.1))
	p.spec = 0.8
	p.ball(cx, 49, 1.5, 1.5, GOLD)
	p.spec = 0.0
	p.strand(PackedVector2Array([Vector2(cx + 2.5, 50), Vector2(cx + 3.2, 55), Vector2(cx + 2.8 + sway * 0.3, 60)]), 0.8, 0.6, GOLD.darkened(0.35))
	p.strand(PackedVector2Array([Vector2(cx + 4.0, 50), Vector2(cx + 5.2, 54), Vector2(cx + 5.0 + sway * 0.3, 58)]), 0.8, 0.6, GOLD.darkened(0.45))
	p.line(Vector2(cx - 8.5, 49.5), Vector2(cx - 9.5, 52.5), IRON.lightened(0.2))
	p.flat_poly(PackedVector2Array([Vector2(cx - 13.2, 52), Vector2(cx - 7.4, 52.6), Vector2(cx - 7.8, 59.4), Vector2(cx - 13.6, 58.8)]), BOOK, Vector3(-0.3, -0.2, 1))
	p.line(Vector2(cx - 13.0, 52.4), Vector2(cx - 13.3, 58.6), Color(0.75, 0.7, 0.58))
	for c in [Vector2(cx - 13.0, 52.3), Vector2(cx - 7.8, 52.9), Vector2(cx - 8.1, 59.0), Vector2(cx - 13.3, 58.6)]:
		var cv: Vector2 = c
		p.tput(cv.x, cv.y, GOLD.lightened(0.2))
	p.ball(cx - 10.5, 55.7, 1.0, 1.0, GOLD.darkened(0.1))
	p.xf = Transform2D.IDENTITY
	if down:
		# legs under the robe, soles toward the viewer
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var key := "l" if s < 0.0 else "r"
			var hp: Vector2 = r[key + "hip"]
			var kn: Vector2 = r[key + "knee"]
			var an2: Vector2 = r[key + "ank"]
			p.capsule(hp, kn, 4.6, 4.0, ROBE)
			p.capsule(kn, an2 + (an2 - kn).normalized() * -1.5, 4.0, 3.8, ROBE.lightened(0.03))
			_down_boot(p, an2, Color(0.22, 0.15, 0.1))
			var cuff := an2 - (an2 - kn).normalized() * 2.0
			p.capsule(cuff + Vector2(-3.6, 0.4), cuff + Vector2(3.6, -0.4), 0.6, 0.6, GOLD.darkened(0.2))
	# ---- upper arms in wide sleeves
	for arm in [[lsh, lel], [rsh, rel]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		p.capsule(sh, el, 3.4, 3.6, ROBE.lightened(0.03))
	# ---- mantle with gold trim
	p.xf = txf
	var mantle := PackedVector2Array([Vector2(cx - 12.5, 24), Vector2(cx + 12.5, 24), Vector2(cx + 13.4, 32), Vector2(cx + 9, 37.5), Vector2(cx, 39.5), Vector2(cx - 9, 37.5), Vector2(cx - 13.4, 32)])
	_cyl(p, mantle, ROBE.lightened(0.02), Vector2(cx, 24), Vector2(cx, 39), 13.5, -0.35, 0.0, 1.0, 0.3)
	p.strand(PackedVector2Array([Vector2(cx - 13.4, 32), Vector2(cx - 9, 37.5), Vector2(cx, 39.5), Vector2(cx + 9, 37.5), Vector2(cx + 13.4, 32)]), 0.6, 0.6, GOLD)
	# ---- head (hood, long white beard)
	p.xf = hxf
	_mage_head(p, 48.0, 16.0, mouth, eye_glow, glows)
	# ---- forearms in flared sleeves, staff, hands
	p.xf = Transform2D.IDENTITY
	for arm in [[lel, lwr], [rel, rwr]]:
		var el2: Vector2 = arm[0]
		var wr: Vector2 = arm[1]
		var cuff2 := wr + (el2 - wr).normalized() * 2.4
		p.capsule(el2, cuff2, 3.6, 4.6, ROBE.lightened(0.03))
		var dn := (cuff2 - el2).normalized()
		var nn := Vector2(-dn.y, dn.x)
		p.capsule(cuff2 - dn * 1.2 + nn * 4.2, cuff2 - dn * 1.2 - nn * 4.2, 0.7, 0.7, GOLD)
	_staff(p, s_bot, s_top, gem, glows, flare)
	if l_open:
		_open_hand(p, lwr, l_dir, SKIN_M, 0.9, 2.8)
	else:
		_fist(p, lwr, l_dir, SKIN_M, 1.9)
	if r_open:
		_open_hand(p, rwr, r_dir, SKIN_M, 0.9, 2.8)
	else:
		_fist(p, rwr, r_dir, SKIN_M, 1.9)
	if cast:
		var mid := (lwr + rwr) * 0.5 + Vector2(0, -3.0)
		p.light_only(cx, 8, 24, ARCANE, 0.22)
		for hv in [lwr, rwr]:
			var hp2: Vector2 = hv
			p.light_only(hp2.x, hp2.y - 2.0, 7.0, ARCANE, 0.45)
			glows.append([hp2 + Vector2(0, -2.5), 4.0, ARCANE, 1.0])
			glows.append([hp2 + Vector2(0, -2.5), 1.6, Color(0.9, 1, 1), 1.0])
		for kk in 12:
			var ang := float(kk) / 12.0 * TAU
			var rr := 9.0 + (kk % 3) * 2.5
			glows.append([mid + Vector2(cos(ang) * rr * 1.5, sin(ang) * rr * 0.7 + 4.0), 1.5, ARCANE, 0.75])
	elif atk == 2:
		var gp := s_top + (s_top - s_bot).normalized() * 1.0
		p.light_only(gp.x, gp.y, 15, FIRE, 0.35)
		for kk in 8:
			var ang2 := float(kk) / 8.0 * TAU + 0.3
			glows.append([gp + Vector2(cos(ang2), sin(ang2)) * (6.0 + (kk % 2) * 3.0), 1.6, Color(1.0, 0.75, 0.3), 0.8])
	if pain:
		_wound(p, Vector2(cx + 7.0, 33.0), 1.2)
	if down:
		p.xf = txf
		_wound(p, Vector2(cx + 4.5, 42.0), 1.7)
		p.xf = Transform2D.IDENTITY
	p.grime(Color(0.1, 0.09, 0.12), 0.26, 0.1, 0.2, 0.7)
	return glows


static func _mage_head(p: Painter, hx: float, hy: float, mouth: String, eye_glow: bool, glows: Array) -> void:
	var hood := ROBE.darkened(0.04)
	p.ball(hx, hy - 0.4, 7.4, 8.4, hood)
	_cyl(p, PackedVector2Array([Vector2(hx - 5.6, hy - 4.0), Vector2(hx + 5.6, hy - 4.0), Vector2(hx + 1.8, hy - 10.6), Vector2(hx - 0.2, hy - 11.2)]), hood, Vector2(hx, hy - 11), Vector2(hx, hy - 4), 5.6, -0.5)
	p.ellipse(hx, hy + 1.8, 4.9, 6.3, Color(0.03, 0.03, 0.06))
	# old weathered face, lit from the upper left
	p.ball(hx, hy + 1.3, 3.9, 5.0, SKIN_M)
	p.ball(hx - 1.4, hy - 1.2, 1.6, 1.1, SKIN_M.lightened(0.08))
	p.ellipse(hx, hy - 3.2, 3.4, 1.1, Color(0.03, 0.03, 0.07, 0.45))
	p.line(Vector2(hx - 2.2, hy - 1.8), Vector2(hx + 1.6, hy - 1.9), SKIN_M.darkened(0.22))
	for sv in [-1.0, 1.0]:
		var s: float = sv
		if eye_glow:
			p.tput(hx + s * 1.6, hy + 1.4, Color(0.85, 1.0, 1.0))
			glows.append([p.tp(Vector2(hx + s * 1.6 + 0.5, hy + 1.9)), 2.0, ARCANE, 0.9])
		else:
			p.tput(hx + s * 1.6, hy + 1.5, Color(0.12, 0.1, 0.12))
		# bushy white brows
		p.strand(PackedVector2Array([Vector2(hx + s * 1.1, hy + 0.3), Vector2(hx + s * 2.2, hy - 0.1), Vector2(hx + s * 3.5, hy + 0.8)]), 0.6, 0.45, BEARD_WHITE)
	p.capsule(Vector2(hx + 0.2, hy + 1.4), Vector2(hx + 0.4, hy + 4.0), 0.7, 1.0, SKIN_M.lightened(0.08))
	p.tput(hx + 1.2, hy + 2.6, SKIN_M.darkened(0.3))
	var beard := PackedVector2Array([Vector2(hx - 4.2, hy + 3.0), Vector2(hx - 2.6, hy + 4.7), Vector2(hx, hy + 4.4), Vector2(hx + 2.6, hy + 4.7), Vector2(hx + 4.2, hy + 3.0), Vector2(hx + 5.0, hy + 9), Vector2(hx + 4.6, hy + 16), Vector2(hx + 3.2, hy + 24), Vector2(hx + 1.4, hy + 30), Vector2(hx, hy + 32), Vector2(hx - 1.4, hy + 30), Vector2(hx - 3.2, hy + 24), Vector2(hx - 4.6, hy + 16), Vector2(hx - 5.0, hy + 9)])
	_cyl(p, beard, BEARD_WHITE, Vector2(hx, hy + 3), Vector2(hx, hy + 32), 5.2, -0.2, 0.0, 1.7, 0.45)
	for i in 5:
		var bx := hx - 3.0 + i * 1.5
		p.line(Vector2(bx, hy + 10), Vector2(bx + (float(i) - 2.0) * 0.4, hy + 24 - absf(float(i) - 2.0) * 2.0), BEARD_WHITE.darkened(0.32))
	match mouth:
		"roar":
			p.ellipse(hx, hy + 6.9, 1.6, 1.5, Color(0.12, 0.03, 0.03))
		"grimace":
			p.ellipse(hx, hy + 6.5, 1.6, 0.7, Color(0.12, 0.03, 0.03))
			p.rect(hx - 1.1, hy + 6.1, 2.2, 0.5, Color(0.72, 0.68, 0.58))
		"pain":
			p.ellipse(hx, hy + 6.6, 1.1, 0.7, Color(0.12, 0.03, 0.03))
	p.strand(PackedVector2Array([Vector2(hx - 3.8, hy + 7.0), Vector2(hx - 1.6, hy + 5.0), Vector2(hx, hy + 5.2), Vector2(hx + 1.6, hy + 5.0), Vector2(hx + 3.8, hy + 7.0)]), 0.8, 0.7, BEARD_WHITE.lightened(0.06))
	var rim := PackedVector2Array([Vector2(hx - 5.6, hy + 8.5), Vector2(hx - 6.0, hy + 1.5), Vector2(hx - 4.4, hy - 4.0), Vector2(hx, hy - 5.8), Vector2(hx + 4.4, hy - 4.0), Vector2(hx + 6.0, hy + 1.5), Vector2(hx + 5.6, hy + 8.5)])
	p.strand(rim, 1.15, 1.15, ROBE.lightened(0.08))
	var trim := PackedVector2Array()
	for v in rim:
		trim.append(Vector2(hx, hy + 1.5) + (v - Vector2(hx, hy + 1.5)) * 1.2)
	p.strand(trim, 0.5, 0.5, GOLD)


# =============================================================================== hunter

static func _hunter(p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	var cx := 48.0
	var atk: int = r["atk"]
	var cast: bool = r["cast"]
	var pain: bool = r["pain"]
	var down: bool = r["down"]
	var step: float = r["step"]
	var txf: Transform2D = r["txf"]
	var hxf: Transform2D = r["hxf"]
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	var lel: Vector2 = r["lel"]
	var lwr: Vector2 = r["lwr"]
	var rel: Vector2 = r["rel"]
	var rwr: Vector2 = r["rwr"]
	var sway := step * 2.0
	# bow in the screen-right hand, arrows drawn with the screen-left one
	var b_axis := Vector2(0.06, -1.0)
	var b_out := Vector2(1.0, 0.06)
	var b_half := 29.0
	var b_bend := 3.4
	var nock: Variant = null
	var arrow_tail := Vector2.ZERO
	var arrow_head := Vector2.ZERO
	var has_arrow := false
	var l_dir := lwr - lel
	var r_dir := rwr - rel
	var l_open := false
	var mouth_open := false
	var eye_glow := false
	if down:
		l_dir = Vector2(-0.55, -0.85)
		l_open = true
		r_dir = Vector2(0.3, 1.0)
		mouth_open = true
	elif atk == 1:
		# full draw, aiming level to the right: string at the jaw
		rel = rsh + Vector2(8.0, 1.5)
		rwr = rsh + Vector2(16.5, 2.5)
		b_axis = Vector2(0.0, -1.0)
		b_out = Vector2(1.0, 0.0)
		b_half = 26.0
		b_bend = 5.0
		lel = lsh + Vector2(-1.0, -0.5)
		lwr = Vector2(cx + 3.0, 26.5)
		nock = lwr + Vector2(-0.5, 0)
		has_arrow = true
		arrow_tail = lwr + Vector2(-2.5, 0.0)
		arrow_head = rwr + Vector2(8.5, 0.0)
		l_dir = Vector2(1, 0)
		r_dir = Vector2(1, 0)
	elif atk == 2:
		# release: the string snaps straight, the drawing hand flies open past the ear
		rel = rsh + Vector2(8.0, 1.5)
		rwr = rsh + Vector2(16.5, 2.5)
		b_axis = Vector2(0.0, -1.0)
		b_out = Vector2(1.0, 0.0)
		b_half = 27.5
		b_bend = 3.6
		lel = lsh + Vector2(-3.0, 2.5)
		lwr = lsh + Vector2(-6.5, -7.0)
		l_dir = Vector2(-0.6, -0.8)
		l_open = true
		r_dir = Vector2(1, 0)
		for kk in 7:
			glows.append([rwr + Vector2(9.0 + kk * 2.6, 0.0), 1.3, Color(0.85, 0.85, 0.78), 0.55 - kk * 0.05])
	elif cast:
		# drawn and aimed high (volley): bow arm raised to the upper right
		var grip := Vector2(cx + 23.0, 17.5)
		var nk := Vector2(cx + 3.0, 28.5)
		var aim := (grip - nk).normalized()
		rwr = grip
		rel = rsh + Vector2(6.5, -3.5)
		b_out = aim
		b_axis = Vector2(aim.y, -aim.x)
		b_half = 20.0
		b_bend = 4.8
		lwr = nk
		lel = lsh + Vector2(-1.0, -0.5)
		nock = nk
		has_arrow = true
		arrow_tail = nk - aim * 2.5
		arrow_head = grip + aim * 8.5
		l_dir = aim
		r_dir = aim
		eye_glow = true
	elif pain:
		rel = rsh + Vector2(6.0, 8.5)
		rwr = rsh + Vector2(12.0, 15.5)
		b_axis = Vector2(0.38, -1.0)
		b_out = Vector2(1.0, 0.38)
		lel = lsh + Vector2(-5.5, 8.0)
		lwr = lsh + Vector2(-11.0, 14.5)
		l_dir = lwr - lel
		l_open = true
		mouth_open = true
	else:
		rel = rsh + Vector2(3.0, 12.0)
		rwr = rsh + Vector2(4.0, 22.5 - step * 1.2)
		r_dir = Vector2(0, 1)
	if down:
		_blood_pool(p, cx + 2.0, 92.5, 23.0)
		_down_cape(p, r, CLOAK_G.darkened(0.25), 0.0)
	# ---- quiver (behind)
	p.xf = txf
	var qtop := Vector2(cx - 12.0, 15.5)
	var qbot := Vector2(cx + 9.0, 50.0)
	var qd := (qtop - qbot).normalized()
	var qn := Vector2(-qd.y, qd.x)
	for i in 6:
		var base := qtop + qn * (float(i) - 2.5) * 1.1 + qd * 0.5
		var tip := base + qd * (7.5 + (i % 3) * 1.2) + qn * (float(i) - 2.5) * 0.5
		p.line(base, tip, Color(0.6, 0.46, 0.28))
		var fc := Color(0.62, 0.13, 0.1) if i % 2 == 0 else Color(0.86, 0.83, 0.76)
		p.capsule(tip - qd * 2.6, tip, 0.9, 0.6, fc)
		p.tput(tip.x - qd.x * 1.2 + qn.x * 0.8, tip.y - qd.y * 1.2 + qn.y * 0.8, fc.darkened(0.3))
	p.capsule(qbot, qtop, 2.9, 3.2, Color(0.3, 0.19, 0.11))
	p.capsule(qtop + qn * 3.0 - qd * 0.6, qtop - qn * 3.0 - qd * 0.6, 0.9, 0.9, LEATHER.darkened(0.35))
	p.line(qtop - qd * 4.0 + qn * 2.4, qtop - qd * 4.0 - qn * 2.4, GOLD.darkened(0.45))
	if not down:
		var cloak := PackedVector2Array([Vector2(cx - 12, 25), Vector2(cx + 12, 25), Vector2(cx + 15.5, 48), Vector2(cx + 16.5 + sway, 70)])
		for i in 9:
			var t := float(i) / 8.0
			cloak.append(Vector2(lerpf(cx + 16.5 + sway, cx - 16.5 + sway, t), 74.0 - (i % 2) * 3.5 - (2.0 if i % 3 == 0 else 0.0)))
		cloak.append(Vector2(cx - 15.5, 48))
		_cyl(p, cloak, CLOAK_G.darkened(0.2), Vector2(cx, 25), Vector2(cx, 74), 16.0, -0.1, 0.0, 0.9, 0.38)
		p.xf = Transform2D.IDENTITY
		_hunter_legs(p, r)
	# ---- torso: leather jerkin with skirt flaps, baldric, belt and pouches
	p.xf = txf
	for k in 4:
		var x0 := cx - 10.2 + k * 5.1
		p.flat_poly(PackedVector2Array([Vector2(x0, 48), Vector2(x0 + 5.0, 48), Vector2(x0 + 5.3 + (k - 1.5) * 0.4, 59.0 + (k % 2)), Vector2(x0 - 0.3 + (k - 1.5) * 0.4, 59.0 + (k % 2))]), JERKIN.darkened(0.1 + (k % 2) * 0.08), Vector3((k - 1.5) * 0.3, -0.1, 1.0))
	var jerk := PackedVector2Array([Vector2(cx - 11.5, 25.5), Vector2(cx + 11.5, 25.5), Vector2(cx + 12, 34), Vector2(cx + 10, 49), Vector2(cx - 10, 49), Vector2(cx - 12, 34)])
	_cyl(p, jerk, JERKIN, Vector2(cx, 25), Vector2(cx, 49), 12.0, -0.3)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.line(Vector2(cx + s * 5.0, 30), Vector2(cx + s * 4.4, 48), JERKIN.darkened(0.45))
		for k in 5:
			p.tput(cx + s * 5.9 - s * k * 0.12, 31.5 + k * 3.5, JERKIN.lightened(0.3))
	for k in 4:
		var ly := 33.5 + k * 3.2
		p.line(Vector2(cx - 1.2, ly), Vector2(cx + 1.2, ly + 1.6), Color(0.62, 0.55, 0.4))
		p.line(Vector2(cx + 1.2, ly), Vector2(cx - 1.2, ly + 1.6), Color(0.5, 0.44, 0.32))
	p.strand(PackedVector2Array([Vector2(cx - 11.0, 26.5), Vector2(cx - 1.0, 37.0), Vector2(cx + 9.5, 47.5)]), 1.25, 1.25, LEATHER.darkened(0.2))
	p.spec = 0.7
	p.rect(cx - 2.6, 35.2, 2.6, 2.6, IRON.lightened(0.15))
	p.spec = 0.0
	p.capsule(Vector2(cx - 10.3, 49.2), Vector2(cx + 10.3, 49.2), 1.3, 1.3, LEATHER.darkened(0.3))
	p.spec = 0.7
	p.rect(cx - 1.4, 47.9, 2.8, 2.7, IRON.lightened(0.2))
	p.spec = 0.0
	p.ball(cx + 6.8, 52.6, 2.4, 2.6, LEATHER)
	p.line(Vector2(cx + 4.6, 51.6), Vector2(cx + 9.0, 51.6), LEATHER.darkened(0.45))
	p.ball(cx - 7.2, 52.2, 2.0, 2.4, LEATHER.darkened(0.08))
	p.capsule(Vector2(cx - 3.2, 50.2), Vector2(cx - 3.8, 58.5), 1.0, 0.8, Color(0.16, 0.11, 0.08))
	p.capsule(Vector2(cx - 4.6, 50.6), Vector2(cx - 1.8, 50.6), 0.6, 0.6, IRON.lightened(0.2))
	p.xf = Transform2D.IDENTITY
	if down:
		_hunter_legs(p, r)
	# ---- upper arms (green sleeves)
	for arm in [[lsh, lel], [rsh, rel]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		p.capsule(sh, el, 2.9, 2.5, SLEEVE_G)
	# ---- hood capelet
	p.xf = txf
	var cap := PackedVector2Array([Vector2(cx - 13, 23.5), Vector2(cx + 13, 23.5), Vector2(cx + 13.8, 30.5), Vector2(cx + 10.5, 35.5), Vector2(cx + 7, 33.5), Vector2(cx + 3.5, 38), Vector2(cx, 35), Vector2(cx - 3.5, 38), Vector2(cx - 7, 33.5), Vector2(cx - 10.5, 35.5), Vector2(cx - 13.8, 30.5)])
	_cyl(p, cap, HOOD_G, Vector2(cx, 23), Vector2(cx, 37), 14.0, -0.35, 0.0, 0.9, 0.3)
	# ---- head (hood + cloth mask)
	p.xf = hxf
	_hunter_head(p, 48.0, 16.0, mouth_open, eye_glow, glows)
	# ---- forearms: leather bracers
	p.xf = Transform2D.IDENTITY
	for arm in [[lel, lwr], [rel, rwr]]:
		var el2: Vector2 = arm[0]
		var wr: Vector2 = arm[1]
		var dn := (wr - el2).normalized()
		var nn := Vector2(-dn.y, dn.x)
		p.capsule(el2, wr, 2.5, 2.1, SLEEVE_G)
		p.capsule(el2.lerp(wr, 0.3), wr, 2.5, 2.2, BRACER)
		for band in [0.5, 0.82]:
			var bb: Vector2 = el2.lerp(wr, float(band))
			p.line(bb + nn * 2.4, bb - nn * 2.4, BRACER.darkened(0.5))
	# ---- bow, arrow, hands
	if down:
		_bow(p, Vector2(cx - 26.0, 90.0), Vector2(1.0, -0.04), Vector2(0.0, -1.0), 21.0, 3.0)
		_arrow(p, Vector2(cx + 20, 94.5), Vector2(cx + 36, 93.0))
		_arrow(p, Vector2(cx + 24, 92.0), Vector2(cx + 38, 94.5))
	else:
		_bow(p, rwr, b_axis, b_out, b_half, b_bend, nock)
	if has_arrow:
		_arrow(p, arrow_tail, arrow_head)
	_fist(p, rwr, r_dir, LEATHER.lightened(0.04), 2.0)
	if l_open:
		_open_hand(p, lwr, l_dir, LEATHER.lightened(0.04), 0.9, 2.8)
	else:
		_fist(p, lwr, l_dir, LEATHER.lightened(0.04), 1.9)
	if pain:
		_wound(p, Vector2(cx + 7.0, 33.0), 1.2)
	if down:
		p.xf = txf
		_wound(p, Vector2(cx + 4.5, 40.0), 1.7)
		p.xf = Transform2D.IDENTITY
	if cast:
		glows.append([arrow_head, 3.0, FOCUS, 0.8])
		glows.append([arrow_head, 1.2, Color(0.9, 1, 0.8), 0.9])
	p.grime(Color(0.12, 0.1, 0.06), 0.34, 0.1, 0.15, 0.6)
	return glows


static func _hunter_legs(p: Painter, r: Dictionary) -> void:
	## Trousers, leather knee pads, tall boots with folded cuffs and straps.
	var down: bool = r["down"]
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var key := "l" if s < 0.0 else "r"
		var hp: Vector2 = r[key + "hip"]
		var kn: Vector2 = r[key + "knee"]
		var an: Vector2 = r[key + "ank"]
		var shin := (an - kn).normalized()
		var sn := Vector2(-shin.y, shin.x)
		p.capsule(hp, kn, 3.5, 2.8, PANTS)
		p.capsule(kn + shin * 2.0, an, 2.8, 2.4, BOOT)
		p.capsule(kn + shin * 2.6 + sn * 2.9, kn + shin * 2.6 - sn * 2.9, 1.3, 1.3, BOOT.lightened(0.16))
		for k in 2:
			var sp := kn.lerp(an, 0.5 + k * 0.22)
			p.line(sp + sn * 2.6, sp - sn * 2.6 + shin * 0.6, BOOT.darkened(0.45))
		p.ball(kn.x, kn.y, 2.6, 2.3, LEATHER.lightened(0.06))
		if down:
			_down_boot(p, an, BOOT)
		else:
			var foot := an + Vector2(s * 0.5, 2.9)
			p.ball(foot.x, foot.y, 3.4, 2.3, BOOT)


static func _hunter_head(p: Painter, hx: float, hy: float, mouth_open: bool, eye_glow: bool, glows: Array) -> void:
	p.ball(hx, hy - 0.6, 7.0, 8.0, HOOD_G)
	_cyl(p, PackedVector2Array([Vector2(hx - 5.2, hy - 4.6), Vector2(hx + 5.2, hy - 4.6), Vector2(hx + 1.4, hy - 10.4), Vector2(hx - 0.4, hy - 10.8)]), HOOD_G, Vector2(hx, hy - 10.8), Vector2(hx, hy - 4.6), 5.2, -0.5)
	p.ellipse(hx, hy + 1.4, 4.7, 6.0, Color(0.035, 0.04, 0.03))
	# face: eyes and nose bridge visible above the mask
	p.ball(hx, hy + 1.2, 3.9, 4.8, SKIN_H)
	p.ball(hx - 1.4, hy - 1.2, 1.5, 1.1, SKIN_H.lightened(0.07))
	p.ellipse(hx, hy - 3.0, 3.4, 1.2, Color(0.03, 0.035, 0.02, 0.5))
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.line(Vector2(hx + s * 0.6, hy + 0.2), Vector2(hx + s * 3.2, hy - 0.2), Color(0.17, 0.1, 0.05))
		if eye_glow:
			p.tput(hx + s * 1.7, hy + 1.2, Color(0.9, 1.0, 0.7))
			glows.append([p.tp(Vector2(hx + s * 1.7 + 0.5, hy + 1.7)), 2.0, FOCUS, 0.85])
		else:
			p.tput(hx + s * 1.3, hy + 1.2, Color(0.1, 0.07, 0.04))
			p.tput(hx + s * 2.3, hy + 1.2, Color(0.74, 0.7, 0.62))
	var mask := PackedVector2Array([Vector2(hx - 4.8, hy + 3.0), Vector2(hx - 1.5, hy + 2.7), Vector2(hx + 1.5, hy + 2.7), Vector2(hx + 4.8, hy + 3.0), Vector2(hx + 5.2, hy + 7.5), Vector2(hx + 4.4, hy + 10.5), Vector2(hx, hy + 11.6), Vector2(hx - 4.4, hy + 10.5), Vector2(hx - 5.2, hy + 7.5)])
	_cyl(p, mask, MASK, Vector2(hx, hy + 2.5), Vector2(hx, hy + 11.5), 5.4, -0.2, 0.0, 1.5, 0.35)
	p.ball(hx + 0.3, hy + 3.9, 1.1, 1.0, MASK.lightened(0.12))
	p.line(Vector2(hx - 4.8, hy + 5.9), Vector2(hx + 4.8, hy + 5.7), MASK.darkened(0.42))
	p.line(Vector2(hx - 4.4, hy + 8.8), Vector2(hx + 4.4, hy + 8.6), MASK.darkened(0.35))
	if mouth_open:
		p.ellipse(hx, hy + 7.2, 1.6, 0.7, MASK.darkened(0.45))
	var rim := PackedVector2Array([Vector2(hx - 5.4, hy + 8.5), Vector2(hx - 5.8, hy + 1.0), Vector2(hx - 4.2, hy - 4.2), Vector2(hx, hy - 5.6), Vector2(hx + 4.2, hy - 4.2), Vector2(hx + 5.8, hy + 1.0), Vector2(hx + 5.4, hy + 8.5)])
	p.strand(rim, 1.1, 1.1, HOOD_G.lightened(0.1))
	for i in rim.size():
		var q := rim[i]
		p.tput(q.x, q.y, Color(0.52, 0.5, 0.36))
