extends RefCounted
## DREADHOLD monster forge: the ONE shared humanoid rig.
##
## Every modular part (body, armour, head, off-hand, weapon, aura) is drawn on this rig, so any
## combination stacks pixel-perfectly. A part is a 768x96 strip: 8 frames of 96x96, same order as
## scripts/data/enemies.gd FRAME_*:
##   0 walk A, 1 walk B, 2 wind-up, 3 strike, 4 pain, 5 dying A, 6 dying B, 7 corpse.
##
## Coordinates
##  * Body space: an upright 96x96 design frame (x right, y down), figure centred on x = 48, soles
##    on row GROUND like the existing enemy sheets. Every joint below is a body-space point.
##  * r.xf maps body space to the frame's pixels: identity while standing, a rotation about the
##    feet while dying, rotate + scale + squash that lays the body on the floor for the corpse.
##    Parts never place pixels by hand: they draw through Painter.xf = r.xf (or a sub-frame).
##  * Sub-frames (map local coords to body space, compose as r.xf * sub):
##      r.txf  torso: origin = pelvis centre, rotated by the torso lean (see T_* landmarks)
##      r.hxf  head: origin = cranium centre, tilted by head_rot about the neck top (H_NECK)
##      r.wxf  weapon: origin = right fist centre, +x along r.rdir (held weapon axis)
##      r.oxf  off-hand: origin = left fist centre, +x along r.ldir
##  * "Right hand" = weapon hand = screen-right (like the existing skeleton's sword hand);
##    "left hand" = off-hand = screen-left.
##  * Arms never cross in front of the torso silhouette (keeps armour overlays honest); weapons
##    and off-hand items may cross anything since they stack above.
## Keys: pelvis, neck_base, neck (top), head (centre), head_rot, jaw (0..1.5 mouth opening),
## lsh/rsh, lel/rel, lhd/rhd (fist centres), rdir/ldir (unit hand axes), lhip/rhip, lkn/rkn,
## lft/rft (ankles), step (+1 right foot up, -1 left foot up), down (gravity, body space),
## k (pixel scale of xf), kind ("stand" | "die" | "corpse"), frame, atk (1 wind-up, 2 strike),
## pain (bool), die (1|2).

const FRAME := 96
const FRAMES := 8
const NAMES := ["walk_a", "walk_b", "windup", "strike", "pain", "die_a", "die_b", "corpse"]
const GROUND := 93.5
const UPPER_ARM := 14.0
const FOREARM := 14.5
const FIST := 2.3

## torso-local landmarks (origin = pelvis centre, y down)
const T_NECK_BASE := Vector2(0, -25.5)
const T_NECK_TOP := Vector2(0, -30.5)
const T_SHOULDER := Vector2(11.5, -24.0)
const T_CHEST := Vector2(0, -17.5)
const T_WAIST := Vector2(0, -7.0)
const T_HIP := Vector2(5.6, 1.5)
## neck top in head-local coords (origin = cranium centre)
const H_NECK := Vector2(0, 7.0)

## per-frame pose spec (body space)
const SPEC := [
	{ # 0 walk A: right foot lifted, left arm forward
		"pelvis": Vector2(48, 50), "lean": 0.0, "head_rot": 0.0, "jaw": 0.0, "step": 1.0,
		"rhd": Vector2(62.4, 54.0), "rdir": Vector2(0.28, 1.0), "rhint": Vector2(1, 0.1),
		"lhd": Vector2(33.8, 51.5), "ldir": Vector2(-0.05, 1.0), "lhint": Vector2(-1, 0.1),
		"lkn": Vector2(42.2, 71.0), "lft": Vector2(42.4, 89.5), "rkn": Vector2(53.6, 67.5), "rft": Vector2(53.4, 85.5),
	},
	{ # 1 walk B: left foot lifted, bob down
		"pelvis": Vector2(48, 51), "lean": 0.0, "head_rot": 0.0, "jaw": 0.0, "step": -1.0,
		"rhd": Vector2(62.4, 53.0), "rdir": Vector2(0.22, 1.0), "rhint": Vector2(1, 0.1),
		"lhd": Vector2(33.8, 55.0), "ldir": Vector2(-0.05, 1.0), "lhint": Vector2(-1, 0.1),
		"lkn": Vector2(42.4, 67.5), "lft": Vector2(42.6, 85.5), "rkn": Vector2(53.8, 71.0), "rft": Vector2(53.6, 89.5),
	},
	{ # 2 wind-up: weapon arm cocked high on the right, off-hand raised a little
		"pelvis": Vector2(48, 51), "lean": -0.04, "head_rot": -0.04, "jaw": 0.4, "step": 0.0, "atk": 1,
		"rhd": Vector2(68.5, 17.5), "rdir": Vector2(0.42, -0.91), "rhint": Vector2(1, 0.7),
		"lhd": Vector2(31.0, 47.0), "ldir": Vector2(0.15, 1.0), "lhint": Vector2(-1, -0.1),
		"lkn": Vector2(41.0, 71.5), "lft": Vector2(41.0, 89.5), "rkn": Vector2(55.0, 71.5), "rft": Vector2(55.0, 89.5),
	},
	{ # 3 strike: weapon swept down across the legs, crouched, off-hand out for balance
		"pelvis": Vector2(48, 52.5), "lean": 0.05, "head_rot": 0.05, "jaw": 1.0, "step": 0.0, "atk": 2,
		"rhd": Vector2(62.5, 50.5), "rdir": Vector2(-0.72, 0.7), "rhint": Vector2(1, -0.1),
		"lhd": Vector2(29.0, 48.5), "ldir": Vector2(-0.3, 1.0), "lhint": Vector2(-1, 0.0),
		"lkn": Vector2(40.5, 72.5), "lft": Vector2(40.0, 89.5), "rkn": Vector2(56.0, 72.5), "rft": Vector2(56.5, 89.5),
	},
	{ # 4 pain: recoil, arms flung out, head snapped aside
		"pelvis": Vector2(49.5, 51), "lean": 0.09, "head_rot": 0.24, "jaw": 1.4, "step": 0.0, "pain": true,
		"rhd": Vector2(72.5, 45.0), "rdir": Vector2(0.88, 0.48), "rhint": Vector2(1, 0.4),
		"lhd": Vector2(25.5, 45.0), "ldir": Vector2(-0.6, 0.8), "lhint": Vector2(-1, 0.3),
		"lkn": Vector2(43.2, 71.0), "lft": Vector2(42.6, 89.5), "rkn": Vector2(55.6, 71.0), "rft": Vector2(54.8, 89.5),
	},
	{ # 5 dying A: knees buckle, starting to topple right
		"pelvis": Vector2(48, 52), "lean": 0.07, "head_rot": 0.32, "jaw": 1.3, "step": 0.0, "die": 1,
		"rhd": Vector2(71.0, 45.0), "rdir": Vector2(0.97, 0.25), "rhint": Vector2(1, 0.3),
		"lhd": Vector2(26.0, 41.5), "ldir": Vector2(-0.8, 0.6), "lhint": Vector2(-1, 0.4),
		"lkn": Vector2(41.5, 72.0), "lft": Vector2(43.5, 89.5), "rkn": Vector2(57.0, 71.0), "rft": Vector2(54.5, 89.5),
		"rot": 0.3, "off": Vector2(-5.0, 1.5),
	},
	{ # 6 dying B: falling, arms trailing
		"pelvis": Vector2(48, 51), "lean": 0.0, "head_rot": 0.4, "jaw": 1.5, "step": 0.0, "die": 2,
		"rhd": Vector2(74.0, 31.0), "rdir": Vector2(0.75, -0.66), "rhint": Vector2(1, 0.6),
		"lhd": Vector2(23.0, 30.0), "ldir": Vector2(-0.7, -0.7), "lhint": Vector2(-1, 0.6),
		"lkn": Vector2(43.0, 70.0), "lft": Vector2(41.0, 88.0), "rkn": Vector2(55.0, 71.5), "rft": Vector2(57.5, 89.0),
		"rot": 1.08, "off": Vector2(-31.0, 0.5),
	},
	{ # 7 corpse: lying on the floor, head to the right
		"pelvis": Vector2(48, 50), "lean": 0.0, "head_rot": -0.3, "jaw": 1.0, "step": 0.0, "corpse": true,
		"rhd": Vector2(67.5, 51.0), "rdir": Vector2(0.18, 1.0), "rhint": Vector2(1, 0.1),
		"lhd": Vector2(28.5, 51.0), "ldir": Vector2(-0.18, 1.0), "lhint": Vector2(-1, 0.1),
		"lkn": Vector2(42.0, 71.0), "lft": Vector2(40.8, 89.5), "rkn": Vector2(54.0, 71.0), "rft": Vector2(55.2, 89.5),
	},
]

## corpse lay-down: uniform scale, foreshortening of the body's width, where the pelvis lands
const CORPSE_SCALE := 0.8
const CORPSE_SQUASH := 0.62
const CORPSE_PELVIS := Vector2(46.0, 83.5)
const DIE_PIVOT := Vector2(48.0, 93.0)

static var _cache := {}


static func frame(i: int) -> Dictionary:
	if _cache.has(i):
		return (_cache[i] as Dictionary).duplicate()
	var sp: Dictionary = SPEC[i]
	var r := {"frame": i, "name": NAMES[i]}
	for key in sp:
		r[key] = sp[key]
	r["atk"] = int(sp.get("atk", 0))
	r["pain"] = bool(sp.get("pain", false))
	r["die"] = int(sp.get("die", 0))
	var corpse := bool(sp.get("corpse", false))
	r["kind"] = "corpse" if corpse else ("die" if r["die"] > 0 else "stand")
	# ---- body -> frame transform
	var xf := Transform2D.IDENTITY
	var k := 1.0
	if corpse:
		var s := CORPSE_SCALE
		var xa := Vector2(0.0, s * CORPSE_SQUASH)
		var ya := Vector2(-s, 0.0)
		var pel: Vector2 = sp["pelvis"]
		xf = Transform2D(xa, ya, CORPSE_PELVIS - xa * pel.x - ya * pel.y)
		k = s
	elif sp.has("rot"):
		var off: Vector2 = sp["off"]
		xf = Transform2D(float(sp["rot"]), DIE_PIVOT + off) * Transform2D(0.0, -DIE_PIVOT)
	r["xf"] = xf
	r["k"] = k
	r["down"] = xf.affine_inverse().basis_xform(Vector2(0, 1)).normalized()
	# ---- torso
	var pelvis: Vector2 = sp["pelvis"]
	var txf := Transform2D(float(sp["lean"]), pelvis)
	r["txf"] = txf
	r["neck_base"] = txf * T_NECK_BASE
	r["neck"] = txf * T_NECK_TOP
	r["chest"] = txf * T_CHEST
	r["waist"] = txf * T_WAIST
	r["lsh"] = txf * Vector2(-T_SHOULDER.x, T_SHOULDER.y)
	r["rsh"] = txf * T_SHOULDER
	r["lhip"] = txf * Vector2(-T_HIP.x, T_HIP.y)
	r["rhip"] = txf * T_HIP
	# ---- head: rotate about the neck top
	var hxf := txf * Transform2D(0.0, T_NECK_TOP) * Transform2D(float(sp["head_rot"]), Vector2.ZERO) * Transform2D(0.0, -H_NECK)
	r["hxf"] = hxf
	r["head"] = hxf * Vector2.ZERO
	# ---- arms (2-bone IK toward the fist targets)
	for side in ["l", "r"]:
		var sh: Vector2 = r[side + "sh"]
		var hd: Vector2 = sp[side + "hd"]
		var hint: Vector2 = sp[side + "hint"]
		r[side + "el"] = _ik(sh, hd, UPPER_ARM, FOREARM, hint * 10.0)
		r[side + "dir"] = (sp[side + "dir"] as Vector2).normalized()
	var rdir: Vector2 = r["rdir"]
	var ldir: Vector2 = r["ldir"]
	r["wxf"] = Transform2D(rdir.angle(), sp["rhd"])
	r["oxf"] = Transform2D(ldir.angle(), sp["lhd"])
	_cache[i] = r
	return r.duplicate()


static func _ik(s: Vector2, h: Vector2, a: float, b: float, hint: Vector2) -> Vector2:
	## Elbow position for shoulder s, hand h, bone lengths a/b; hint picks the bend side.
	var d := h - s
	var dist := d.length()
	if dist >= a + b - 0.05:
		return s + d.normalized() * (dist * a / (a + b))
	dist = maxf(dist, absf(a - b) + 0.05)
	var cos_al := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var al := acos(cos_al)
	var u := d.normalized()
	var e1 := s + u.rotated(al) * a
	var e2 := s + u.rotated(-al) * a
	var target := s + hint
	return e1 if e1.distance_squared_to(target) < e2.distance_squared_to(target) else e2


static func sub(r: Dictionary, key: String) -> Transform2D:
	## r.xf composed with a sub-frame ("txf", "hxf", "wxf", "oxf").
	return (r["xf"] as Transform2D) * (r[key] as Transform2D)


static func grip(r: Dictionary, angle: float) -> Transform2D:
	## Frame -> pixels transform for an item held in the right fist along a custom angle.
	return (r["xf"] as Transform2D) * Transform2D(angle, r["rhd"])


static func off_grip(r: Dictionary, angle: float) -> Transform2D:
	return (r["xf"] as Transform2D) * Transform2D(angle, r["lhd"])


static func to_body(r: Dictionary, px: Vector2) -> Vector2:
	## Pixel position -> body space (for screen-space effects that need the body coordinate).
	return (r["xf"] as Transform2D).affine_inverse() * px
