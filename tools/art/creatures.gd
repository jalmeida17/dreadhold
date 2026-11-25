extends RefCounted
## Enemy sprite sheets, realistic pixel style. Each sheet is a horizontal strip of square frames:
## 0 walk A, 1 walk B, 2 attack wind-up, 3 attack strike, 4 pain, 5 dying A, 6 dying B, 7 corpse
## (the boss adds 8 = cast). Bodies are designed in "design units" and scaled to the frame size.

const Painter := preload("res://tools/art/painter.gd")

const POSES := [
	{"step": 1.0},
	{"step": -1.0, "bob": 1.0},
	{"atk": 1},
	{"atk": 2},
	{"pain": true},
	{"die": 1},
	{"die": 2},
	{"corpse": true},
]

const BONE := Color(0.68, 0.62, 0.5)
const BONE_DIRT := Color(0.3, 0.23, 0.15)
const RUST := Color(0.36, 0.23, 0.15)
const IRON := Color(0.33, 0.33, 0.36)
const DARK_STEEL := Color(0.2, 0.2, 0.24)
const LEATHER := Color(0.25, 0.17, 0.11)
const WOOD := Color(0.3, 0.2, 0.13)
const GOLD := Color(0.62, 0.48, 0.22)
const CRIMSON := Color(0.3, 0.07, 0.07)
const BLOOD := Color(0.32, 0.03, 0.04)
const SOUL := Color(0.45, 1.0, 0.55)
const VOID := Color(0.04, 0.03, 0.035)

## design size per kind
const DESIGN := {"skeleton": 96, "archer": 96, "ghoul": 96, "cultist": 96, "brute": 96, "boss": 128}


static func build_sheet(kind: String, size: int, poses: Array) -> Image:
	var design: int = DESIGN.get(kind, size)
	var scale := float(size) / float(design)
	var frames: Array = []
	for i in poses.size():
		var pose: Dictionary = poses[i]
		var p := Painter.new(size, size, 1000 + i * 31 + absi(kind.hash() % 1000))
		p.set_real(scale)
		var base_xf := p.xf
		var glows: Array = []
		if pose.get("corpse", false):
			glows = call_corpse(kind, p)
		else:
			var die: int = pose.get("die", 0)
			if die > 0:
				var pivot := Vector2(design * 0.5, design - 2)
				var ang := 0.32 if die == 1 else 1.12
				var off := Vector2(-design * 0.04, design * 0.05) if die == 1 else Vector2(-design * 0.26, design * 0.07)
				p.xf = base_xf * Transform2D(0.0, pivot + off) * Transform2D(ang, Vector2.ZERO) * Transform2D(0.0, -pivot)
			glows = call_body(kind, p, pose)
		p.xf = base_xf
		p.rim(0.42, 0.12)
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1] * scale, g[2], g[3])
		p.harden_alpha(0.5)
		frames.append(p.img)
	return Painter.strip(frames)


static func call_body(kind: String, p: Painter, pose: Dictionary) -> Array:
	match kind:
		"skeleton":
			return skeleton(p, pose, false)
		"archer":
			return skeleton(p, pose, true)
		"ghoul":
			return ghoul(p, pose)
		"cultist":
			return cultist(p, pose)
		"brute":
			return brute(p, pose)
		"boss":
			return boss(p, pose)
	return []


static func call_corpse(kind: String, p: Painter) -> Array:
	match kind:
		"skeleton", "archer":
			return bone_pile(p, kind == "archer")
		"ghoul":
			return ghoul_corpse(p)
		"cultist":
			return cultist_corpse(p)
		"brute":
			return brute_corpse(p)
		"boss":
			return boss_corpse(p)
	return []


# =============================================================================== shared anatomy

static func _bone(p: Painter, a: Vector2, b: Vector2, r: float, c: Color = BONE) -> void:
	p.capsule(a, b, r, r * 0.82, c)
	p.ball(a.x, a.y, r * 1.35, r * 1.15, c)
	p.ball(b.x, b.y, r * 1.3, r * 1.1, c)


static func _bone_hand(p: Painter, wrist: Vector2, dir: Vector2, spread: float, c: Color = BONE, length: float = 4.5) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	p.ball(wrist.x, wrist.y, 1.7, 1.4, c)
	for f in 4:
		var off := (float(f) - 1.5) * spread
		var b0 := wrist + d * 1.4 + n * off * 0.7
		var tip := b0 + d * length + n * off * 0.5
		p.strand(PackedVector2Array([b0, b0.lerp(tip, 0.5) + n * 0.25, tip]), 0.6, 0.4, c)
	p.capsule(wrist + n * 1.6, wrist + n * 2.6 + d * 2.4, 0.6, 0.45, c)


static func _skull(p: Painter, hx: float, hy: float, s: float, jaw_open: float, eye: Color, glows: Array, c: Color = BONE) -> void:
	# cranium
	p.ball(hx, hy, 5.5 * s, 6.3 * s, c)
	# temples
	p.ball(hx - 4.0 * s, hy + 0.5 * s, 1.5 * s, 2.6 * s, c.darkened(0.25))
	p.ball(hx + 4.0 * s, hy + 0.5 * s, 1.5 * s, 2.6 * s, c.darkened(0.1))
	# cheekbones & maxilla
	p.ball(hx - 3.2 * s, hy + 2.6 * s, 1.7 * s, 1.2 * s, c)
	p.ball(hx + 3.2 * s, hy + 2.6 * s, 1.7 * s, 1.2 * s, c)
	p.ball(hx, hy + 4.0 * s, 3.1 * s, 1.7 * s, c)
	# mandible
	var jy := hy + (6.6 + jaw_open) * s
	p.ball(hx, jy, 3.3 * s, 1.6 * s, c)
	p.capsule(Vector2(hx - 3.4 * s, hy + 3.4 * s), Vector2(hx - 2.6 * s, jy), 0.8 * s, 0.8 * s, c)
	p.capsule(Vector2(hx + 3.4 * s, hy + 3.4 * s), Vector2(hx + 2.6 * s, jy), 0.8 * s, 0.8 * s, c)
	if jaw_open > 0.5:
		p.ellipse(hx, hy + 5.6 * s + jaw_open * 0.5 * s, 2.2 * s, jaw_open * 0.5 * s, VOID)
	# teeth
	for i in 6:
		var tx := hx - 2.5 * s + i * s
		p.rect(tx, hy + 4.7 * s, 0.7 * s, 0.9 * s, Color(0.78, 0.74, 0.6))
		p.rect(tx, jy - 1.4 * s, 0.7 * s, 0.8 * s, Color(0.7, 0.66, 0.54))
	# sockets + nose
	p.ellipse(hx - 2.3 * s, hy + 0.7 * s, 1.75 * s, 1.85 * s, VOID)
	p.ellipse(hx + 2.3 * s, hy + 0.7 * s, 1.75 * s, 1.85 * s, VOID)
	p.poly(PackedVector2Array([Vector2(hx - 0.9 * s, hy + 2.3 * s), Vector2(hx + 0.9 * s, hy + 2.3 * s), Vector2(hx, hy + 3.7 * s)]), VOID)
	# eye lights
	for ex in [-2.3, 2.3]:
		var e := p.tp(Vector2(hx + float(ex) * s, hy + 0.8 * s))
		p.put(int(e.x), int(e.y), eye.lightened(0.5))
		glows.append([e, 1.8 * s, eye, 0.9])


# =============================================================================== skeletons

static func _arm_pose(pose: Dictionary, cx: float, by: float, archer: bool) -> Dictionary:
	var atk: int = pose.get("atk", 0)
	var step: float = pose.get("step", 0.0)
	var j := {
		"lel": Vector2(cx - 13.5, 40 + by), "lwr": Vector2(cx - 14.0, 53 + by - step * 1.5),
		"rel": Vector2(cx + 13.5, 40 + by), "rwr": Vector2(cx + 14.5, 54 + by + step * 1.5),
	}
	if pose.get("pain", false):
		j.lel = Vector2(cx - 16, 36 + by); j.lwr = Vector2(cx - 21, 45 + by)
		j.rel = Vector2(cx + 16, 35 + by); j.rwr = Vector2(cx + 21, 43 + by)
	elif archer:
		if atk == 1:
			j.lel = Vector2(cx - 9, 33 + by); j.lwr = Vector2(cx - 4, 35 + by)
			j.rel = Vector2(cx + 13, 33 + by); j.rwr = Vector2(cx + 6, 31 + by)
		elif atk == 2:
			j.lel = Vector2(cx - 9, 33 + by); j.lwr = Vector2(cx - 4, 35 + by)
			j.rel = Vector2(cx + 16, 30 + by); j.rwr = Vector2(cx + 19, 22 + by)
	else:
		if atk == 1:
			j.rel = Vector2(cx + 17, 18 + by); j.rwr = Vector2(cx + 13, 7 + by)
			j.lwr = Vector2(cx - 12, 47 + by)
		elif atk == 2:
			j.rel = Vector2(cx + 11, 37 + by); j.rwr = Vector2(cx + 1, 47 + by)
			j.lel = Vector2(cx - 15, 37 + by); j.lwr = Vector2(cx - 18, 48 + by)
	return j


static func skeleton(p: Painter, pose: Dictionary, archer: bool) -> Array:
	var glows: Array = []
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cx := 48.0 + (1.5 if pain else 0.0)
	var by := bob + (1.0 if pain else 0.0)
	var cloak := Color(0.19, 0.21, 0.17)
	var arms := _arm_pose(pose, cx, by, archer)
	# ---- behind the body
	if archer:
		# quiver across the back, arrows over the right shoulder
		p.capsule(Vector2(cx + 4, 40 + by), Vector2(cx + 11, 18 + by), 2.6, 2.4, LEATHER)
		for i in 4:
			var ax := cx + 9.5 + i * 1.3
			p.line(Vector2(ax, 20 + by), Vector2(ax + 0.8, 12 + by - i * 0.5), Color(0.45, 0.33, 0.2))
			p.capsule(Vector2(ax + 0.6, 13.5 + by - i * 0.5), Vector2(ax + 1.0, 10.5 + by - i * 0.5), 0.9, 0.5, Color(0.55, 0.52, 0.48))
		# cloak back panel
		var hem := PackedVector2Array([Vector2(cx - 12, 23 + by), Vector2(cx + 12, 23 + by), Vector2(cx + 16, 50), Vector2(cx + 15, 66)])
		for i in 9:
			var hx := cx + 15 - i * 3.75
			hem.append(Vector2(hx, 74 - (i % 2) * 6 - (3 if i % 3 == 0 else 0)))
		hem.append(Vector2(cx - 16, 50))
		p.cloth(hem, cloak.darkened(0.25), cx, 16.0, 0.9, 0.35)
	# spine column (visible through the ribs)
	for i in 14:
		var vy := 21.0 + i * 1.95 + by
		var lumbar := vy > 40.0 + by
		p.ball(cx, vy, 2.6 if lumbar else 1.8, 1.05 if lumbar else 0.9, BONE.darkened(0.15))
	# ---- legs
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var lift := maxf(step * s, 0.0)
		var hip := Vector2(cx + s * 5.6, 51 + by * 0.5)
		var knee := Vector2(cx + s * (5.9 - lift * 0.8), 71.0 - lift * 5.0)
		var ankle := Vector2(cx + s * (5.4 - lift * 0.4), 89.5 - lift * 6.0)
		_bone(p, hip, knee, 2.0)
		p.ball(knee.x, knee.y - 0.6, 1.5, 1.3, BONE.lightened(0.05))
		p.capsule(knee + Vector2(-s * 0.6, 1), ankle + Vector2(-s * 0.4, 0), 1.55, 1.2, BONE)
		p.capsule(knee + Vector2(s * 1.6, 1.5), ankle + Vector2(s * 1.5, -0.5), 0.8, 0.7, BONE.darkened(0.1))
		p.ball(ankle.x, ankle.y, 1.8, 1.4, BONE)
		# foot (front view, pointing at the camera)
		p.ball(ankle.x + s * 0.6, ankle.y + 2.6, 2.6, 1.5, BONE)
		for t in 4:
			p.capsule(Vector2(ankle.x + s * 0.6 - 1.8 + t * 1.2, ankle.y + 3.0), Vector2(ankle.x + s * 0.6 - 2.2 + t * 1.45, ankle.y + 4.2), 0.5, 0.45, BONE)
	# ---- pelvis
	p.ball(cx - 5.0, 46.8 + by, 4.4, 3.1, BONE.darkened(0.12))
	p.ball(cx + 5.0, 46.8 + by, 4.4, 3.1, BONE.darkened(0.05))
	p.erase_ellipse(cx - 5.4, 47.6 + by, 1.6, 1.2)
	p.erase_ellipse(cx + 5.4, 47.6 + by, 1.6, 1.2)
	p.ball(cx, 48.0 + by, 2.4, 3.2, BONE.darkened(0.2))
	p.capsule(Vector2(cx - 4.2, 52.5 + by), Vector2(cx + 4.2, 52.5 + by), 1.3, 1.3, BONE)
	p.erase_ellipse(cx - 3.1, 51.0 + by, 1.3, 1.1)
	p.erase_ellipse(cx + 3.1, 51.0 + by, 1.3, 1.1)
	# ---- ribcage
	var widths := [6.8, 8.8, 10.2, 11.0, 11.4, 11.0, 10.0, 8.6]
	for i in 8:
		var y0 := 26.6 + i * 2.15 + by
		var wi: float = widths[i]
		var drop := 2.6 + i * 0.2
		var start := 1.3 if i < 6 else 3.6
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var pts := PackedVector2Array([
				Vector2(cx + s * start, y0 + (0.6 if i >= 6 else 0.0)),
				Vector2(cx + s * wi * 0.55, y0 - 0.5),
				Vector2(cx + s * wi * 0.88, y0 + drop * 0.4),
				Vector2(cx + s * wi, y0 + drop)])
			p.strand(pts, 1.05, 0.8, BONE)
	p.capsule(Vector2(cx, 26.0 + by), Vector2(cx, 37.5 + by), 1.5, 1.0, BONE.lightened(0.05))
	p.ball(cx, 25.8 + by, 2.0, 1.4, BONE)
	# clavicles
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.strand(PackedVector2Array([Vector2(cx + s * 1.5, 24.6 + by), Vector2(cx + s * 6.0, 23.6 + by), Vector2(cx + s * 10.8, 24.8 + by)]), 1.05, 0.9, BONE)
	# neck
	for i in 3:
		p.ball(cx, 19.5 + i * 1.5 + by, 1.6, 0.8, BONE.darkened(0.1))
	# ---- gear under the arms
	if not archer:
		# belt + tattered tabard
		var tab := PackedVector2Array([Vector2(cx - 6.5, 50 + by), Vector2(cx + 6.5, 50 + by), Vector2(cx + 5.5, 62), Vector2(cx + 3.5, 66), Vector2(cx + 1.5, 61), Vector2(cx - 0.5, 68), Vector2(cx - 2.5, 62), Vector2(cx - 5.5, 65)])
		p.cloth(tab, CRIMSON, cx, 7.0, 1.3, 0.3)
		p.capsule(Vector2(cx - 8.5, 49.5 + by), Vector2(cx + 8.5, 49.5 + by), 1.1, 1.1, LEATHER)
		p.spec = 0.6
		p.ball(cx, 49.5 + by, 1.4, 1.2, IRON.lightened(0.2))
		p.spec = 0.0
	else:
		# cloak drapes over the shoulders
		for sv in [-1.0, 1.0]:
			var s: float = sv
			var dr := PackedVector2Array([Vector2(cx + s * 4, 19 + by), Vector2(cx + s * 13.5, 23 + by), Vector2(cx + s * 15.5, 36 + by), Vector2(cx + s * 13, 44 + by), Vector2(cx + s * 11, 39 + by), Vector2(cx + s * 9, 30 + by), Vector2(cx + s * 5, 26 + by)])
			p.cloth(dr, cloak, cx + s * 10, 7.0, 1.1, 0.3)
	# ---- arms
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var sh := Vector2(cx + s * 11.0, 25.5 + by)
		var el: Vector2 = arms.rel if s > 0 else arms.lel
		var wr: Vector2 = arms.rwr if s > 0 else arms.lwr
		p.ball(sh.x, sh.y, 2.3, 2.0, BONE)
		_bone(p, sh, el, 1.7)
		var fn := Vector2(-(wr - el).normalized().y, (wr - el).normalized().x)
		p.capsule(el + fn * 0.7, wr + fn * 0.7, 1.0, 0.85, BONE)
		p.capsule(el - fn * 0.8, wr - fn * 0.6, 0.85, 0.7, BONE.darkened(0.08))
		var hand_dir := (wr - el).normalized()
		if (not archer) and s > 0:
			_bone_hand(p, wr, hand_dir, 0.55, BONE, 3.0)
		elif archer and atk == 2 and s > 0:
			_bone_hand(p, wr, Vector2(0.4, -1.0), 1.0, BONE, 4.0)
		else:
			_bone_hand(p, wr, hand_dir, 0.75, BONE, 4.2)
	# ---- skull
	var hx := cx + (2.5 if pain else 0.0)
	var hy := 13.0 + by
	if archer:
		p.ball(hx, hy - 0.5, 7.8, 8.6, cloak.darkened(0.15))
		p.poly(PackedVector2Array([Vector2(hx - 6, hy - 5), Vector2(hx + 6, hy - 5), Vector2(hx + 1, hy - 11.5)]), cloak.darkened(0.15))
		p.ellipse(hx, hy + 1.0, 6.2, 7.4, VOID)
	_skull(p, hx, hy, 0.92 if archer else 1.0, 1.4 if (atk == 2 and not archer) or pain else 0.0, SOUL, glows)
	if archer:
		# hood rim shadow over the brow
		p.cloth(PackedVector2Array([Vector2(hx - 7, hy - 1), Vector2(hx - 5, hy - 6.5), Vector2(hx + 5, hy - 6.5), Vector2(hx + 7, hy - 1), Vector2(hx + 4, hy - 3.5), Vector2(hx - 4, hy - 3.5)]), cloak, hx, 7.0, 0.8, 0.2)
	else:
		# dented rusty half-helm with nasal guard
		p.spec = 0.5
		p.cyl_poly(PackedVector2Array([Vector2(hx - 6.3, hy - 0.6), Vector2(hx - 6.0, hy - 4.2), Vector2(hx - 3.4, hy - 7.4), Vector2(hx, hy - 9.2), Vector2(hx + 3.4, hy - 7.4), Vector2(hx + 6.0, hy - 4.2), Vector2(hx + 6.3, hy - 0.6)]), IRON, hx, 6.3, -0.5)
		for bxs in [-3.2, 0.0, 3.2]:
			var bxv: float = bxs
			p.line(Vector2(hx + bxv * 0.4, hy - 8.6), Vector2(hx + bxv, hy - 1.0), RUST.darkened(0.2))
		p.capsule(Vector2(hx - 6.4, hy - 0.9), Vector2(hx + 6.4, hy - 0.9), 0.95, 0.95, RUST)
		p.capsule(Vector2(hx, hy - 1.2), Vector2(hx, hy + 2.8), 0.75, 0.55, IRON)
		p.spec = 0.0
	# ---- weapons & shield
	if archer:
		var lw: Vector2 = arms.lwr
		var bc := lw + Vector2(-0.5, 0)
		var bend := -4.0 if atk == 0 else -3.0
		var top := bc + Vector2(-2.5 if atk == 0 else 0.0, -19)
		var bot := bc + Vector2(-2.5 if atk == 0 else 0.0, 18)
		var pull: Vector2 = arms.rwr if atk == 1 else Vector2(top.x + 0.5, bc.y)
		p.line(top, pull, Color(0.78, 0.76, 0.68))
		p.line(pull, bot, Color(0.78, 0.76, 0.68))
		p.strand(PackedVector2Array([top, top.lerp(bc, 0.5) + Vector2(bend, 0), bc, bc.lerp(bot, 0.5) + Vector2(bend, 0), bot]), 1.25, 1.25, Color(0.42, 0.29, 0.17))
		p.capsule(bc + Vector2(0, -2), bc + Vector2(0, 2), 1.4, 1.4, LEATHER)
		if atk == 1:
			var rwa: Vector2 = arms.rwr
			p.line(rwa, Vector2(bc.x - 1.5, rwa.y + 0.5), Color(0.45, 0.32, 0.2))
			p.spec = 0.8
			p.ball(bc.x - 1.5, rwa.y + 0.5, 1.2, 1.0, IRON.lightened(0.25))
			p.spec = 0.0
	else:
		var rw: Vector2 = arms.rwr
		var sdir := Vector2(0.3, 1.0)
		if atk == 1:
			sdir = Vector2(0.55, -1.0)
		elif atk == 2:
			sdir = Vector2(-1.0, 0.7)
		elif pain:
			sdir = Vector2(0.9, 0.5)
		sdir = sdir.normalized()
		var sn := Vector2(-sdir.y, sdir.x)
		p.spec = 0.5
		p.blade(rw + sdir * 3.5, rw + sdir * 25.0, 1.5, 0.45, Color(0.46, 0.44, 0.42))
		p.spec = 0.0
		p.capsule(rw + sn * 3.2 + sdir * 2.8, rw - sn * 3.2 + sdir * 2.8, 0.75, 0.75, RUST)
		p.capsule(rw - sdir * 1.5, rw + sdir * 2.4, 0.8, 0.8, LEATHER)
		p.ball(rw.x - sdir.x * 2.2, rw.y - sdir.y * 2.2, 1.0, 1.0, RUST)
		# round shield strapped to the left forearm
		var lw2: Vector2 = arms.lwr
		var sc := lw2 + Vector2(1.5, -4.5)
		if atk == 2:
			sc = lw2 + Vector2(-1.0, -5.0)
		var shield_wood := Color(0.27, 0.19, 0.12)
		p.ball(sc.x, sc.y, 8.0, 8.8, shield_wood)
		for kk in 4:
			p.line(Vector2(sc.x - 6 + kk * 4, sc.y - 8.2), Vector2(sc.x - 6 + kk * 4, sc.y + 8.2), shield_wood.darkened(0.55))
		p.line(Vector2(sc.x + 2, sc.y - 6), Vector2(sc.x + 4.5, sc.y + 3), VOID)
		p.spec = 0.5
		for a in 20:
			var ang := float(a) / 20.0 * TAU
			p.ball(sc.x + cos(ang) * 7.6, sc.y + sin(ang) * 8.4, 1.0, 1.0, RUST)
		p.ball(sc.x, sc.y, 2.6, 2.6, IRON)
		p.spec = 0.0
		if atk == 2:
			for kk in 14:
				var t := float(kk) / 13.0
				var pt := Vector2(cx + 22, 6).lerp(Vector2(cx - 22, 62), t) + Vector2(-sin(t * PI) * 9.0, 0)
				glows.append([p.tp(pt), 2.2, Color(0.55, 0.55, 0.6), 0.28])
	p.grime(BONE_DIRT, 0.55, 0.11, 0.05, 0.6)
	return glows


static func bone_pile(p: Painter, archer: bool) -> Array:
	var glows: Array = []
	if archer:
		p.cloth(PackedVector2Array([Vector2(16, 93), Vector2(24, 83), Vector2(46, 81), Vector2(66, 84), Vector2(78, 93)]), Color(0.17, 0.19, 0.15), 48, 30, 0.7, 0.35, -0.6)
		p.strand(PackedVector2Array([Vector2(8, 92), Vector2(26, 80), Vector2(46, 74)]), 0.9, 0.9, WOOD)
	else:
		p.ball(28, 89, 9.0, 3.6, Color(0.27, 0.19, 0.12))
		p.spec = 0.5
		p.ball(28, 88.5, 2.4, 1.2, IRON)
		p.blade(Vector2(46, 92), Vector2(80, 90), 1.4, 0.5, Color(0.46, 0.44, 0.42))
		p.spec = 0.0
		p.capsule(Vector2(46, 89), Vector2(46, 95), 0.8, 0.8, RUST)
	var bones := [[Vector2(20, 90), Vector2(36, 87)], [Vector2(52, 91), Vector2(70, 89)], [Vector2(36, 92), Vector2(54, 93)], [Vector2(30, 85), Vector2(33, 93)], [Vector2(60, 86), Vector2(74, 93)]]
	for b in bones:
		var a: Vector2 = b[0]
		var e: Vector2 = b[1]
		_bone(p, a, e, 1.5)
	# broken ribcage piece
	for i in 4:
		p.strand(PackedVector2Array([Vector2(40 + i * 3.2, 82), Vector2(38 + i * 3.4, 86), Vector2(39 + i * 3.4, 90)]), 0.9, 0.7, BONE)
	p.capsule(Vector2(38, 81), Vector2(52, 81), 1.0, 1.0, BONE)
	# pelvis fragment
	p.ball(58, 88, 4.5, 3.0, BONE)
	p.erase_ellipse(58, 88, 1.2, 1.0)
	# skull lying on its side
	_skull(p, 66, 85, 0.85, 1.0, Color(0.15, 0.25, 0.15), glows)
	glows.clear()
	p.grime(BONE_DIRT, 0.55, 0.12, 0.0, 0.3)
	return glows


# =============================================================================== ghoul

static func ghoul(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var flesh := Color(0.43, 0.46, 0.39)
	var dark := Color(0.3, 0.31, 0.27)
	var claw := Color(0.55, 0.5, 0.38)
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cx := 48.0 + (1.5 if pain else 0.0)
	var by := bob + (1.5 if pain else 0.0)
	# ---- legs (crouched, knees out)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var lift := maxf(step * s, 0.0)
		var hip := Vector2(cx + s * 5.5, 61 + by * 0.5)
		var knee := Vector2(cx + s * 12.0, 74.0 - lift * 4.0)
		var ankle := Vector2(cx + s * 8.5, 89.0 - lift * 4.5)
		p.capsule(hip, knee, 3.6, 2.6, flesh)
		p.ball(hip.x + s * 1.5, hip.y + 4, 2.8, 4.2, flesh)
		p.ball(knee.x, knee.y, 2.6, 2.4, dark.lightened(0.1))
		p.capsule(knee, ankle, 2.4, 1.6, flesh)
		p.capsule(knee + Vector2(-s * 1.2, 2), ankle + Vector2(-s * 0.6, -3), 1.2, 0.8, dark)
		p.ball(ankle.x + s * 0.8, ankle.y + 2.5, 3.4, 1.8, dark)
		for t in 4:
			var tb := Vector2(ankle.x + s * 0.8 - 2.6 + t * 1.75, ankle.y + 3.4)
			p.capsule(tb, tb + Vector2((t - 1.5) * 0.4, 1.8), 0.6, 0.35, claw)
	# loin rag
	var rag := PackedVector2Array([Vector2(cx - 8, 58 + by), Vector2(cx + 8, 58 + by), Vector2(cx + 6.5, 68), Vector2(cx + 3.5, 66), Vector2(cx + 1, 72), Vector2(cx - 2, 66), Vector2(cx - 6.5, 69)])
	p.cloth(rag, Color(0.25, 0.2, 0.14), cx, 9.0, 1.4, 0.35)
	# ---- torso: emaciated, hunched forward (chest high and wide, waist pinched)
	var torso := PackedVector2Array([Vector2(cx - 12, 37 + by), Vector2(cx + 12, 37 + by), Vector2(cx + 10.5, 47 + by), Vector2(cx + 7, 55 + by), Vector2(cx + 7.5, 60 + by), Vector2(cx - 7.5, 60 + by), Vector2(cx - 7, 55 + by), Vector2(cx - 10.5, 47 + by)])
	p.cyl_poly(torso, flesh, cx, 12.0, -0.35)
	# pectorals / ribs under skin / sunken belly
	p.ball(cx - 5, 41 + by, 5.0, 3.2, flesh)
	p.ball(cx + 5, 41 + by, 5.0, 3.2, flesh)
	for i in 3:
		var ry := 45.5 + i * 3.0 + by
		for sv in [-1.0, 1.0]:
			var s: float = sv
			p.line(Vector2(cx + s * 4.5, ry + 0.4), Vector2(cx + s * 9.5, ry + 1.8), dark.darkened(0.2))
			p.line(Vector2(cx + s * 4.5, ry - 0.6), Vector2(cx + s * 9.0, ry + 0.8), flesh.lightened(0.08))
	p.line(Vector2(cx, 43 + by), Vector2(cx, 58 + by), dark.darkened(0.3))
	# rotting wound with exposed ribs
	p.ball(cx + 6, 52 + by, 3.0, 3.6, Color(0.24, 0.05, 0.06))
	for i in 3:
		p.capsule(Vector2(cx + 3.8, 50.2 + i * 1.6 + by), Vector2(cx + 8.0, 51 + i * 1.6 + by), 0.5, 0.45, BONE)
	# ---- shoulders & neck (head sunk low between them)
	var lsh := Vector2(cx - 12.5, 37 + by)
	var rsh := Vector2(cx + 12.5, 37 + by)
	p.ball(lsh.x, lsh.y, 4.4, 3.8, flesh)
	p.ball(rsh.x, rsh.y, 4.4, 3.8, flesh)
	p.capsule(Vector2(cx - 4, 31 + by), lsh, 2.8, 3.2, flesh)
	p.capsule(Vector2(cx + 4, 31 + by), rsh, 2.8, 3.2, flesh)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.strand(PackedVector2Array([Vector2(cx + s * 1.5, 37.5 + by), Vector2(cx + s * 6, 36.5 + by), Vector2(cx + s * 11, 37.5 + by)]), 0.8, 0.7, flesh.lightened(0.15))
	# ---- arms (long, hanging past the knees)
	var lel := Vector2(cx - 18, 52 + by)
	var lwr := Vector2(cx - 19, 68 + by + step)
	var rel := Vector2(cx + 18, 52 + by)
	var rwr := Vector2(cx + 19, 68 + by - step)
	var claw_dir_l := Vector2(0, 1)
	var claw_dir_r := Vector2(0, 1)
	if atk == 1:
		lel = Vector2(cx - 22, 30 + by); lwr = Vector2(cx - 19, 15 + by)
		rel = Vector2(cx + 22, 30 + by); rwr = Vector2(cx + 19, 15 + by)
		claw_dir_l = Vector2(0.2, -1); claw_dir_r = Vector2(-0.2, -1)
	elif atk == 2:
		lel = Vector2(cx - 17, 47 + by); lwr = Vector2(cx - 5, 55 + by)
		rel = Vector2(cx + 17, 47 + by); rwr = Vector2(cx + 6, 58 + by)
		claw_dir_l = Vector2(1, 0.4); claw_dir_r = Vector2(-1, 0.5)
	elif pain:
		lel = Vector2(cx - 20, 45 + by); lwr = Vector2(cx - 25, 55 + by)
		rel = Vector2(cx + 20, 44 + by); rwr = Vector2(cx + 26, 52 + by)
	for arm in [[lsh, lel, lwr, claw_dir_l], [rsh, rel, rwr, claw_dir_r]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var wr: Vector2 = arm[2]
		var cd: Vector2 = (arm[3] as Vector2).normalized()
		p.capsule(sh, el, 2.9, 2.0, flesh)
		p.ball(el.x, el.y, 2.1, 2.0, dark.lightened(0.1))
		p.capsule(el, wr, 2.0, 1.5, flesh)
		p.capsule(el.lerp(wr, 0.15), wr, 0.9, 0.7, dark)
		var cn := Vector2(-cd.y, cd.x)
		p.ball(wr.x + cd.x * 1.5, wr.y + cd.y * 1.5, 2.4, 2.2, dark.lightened(0.1))
		for f in 4:
			var off := (float(f) - 1.5) * 1.3
			var f0 := wr + cd * 2.5 + cn * off
			var f1 := f0 + cd * 4.0 + cn * off * 0.3
			var f2 := f1 + cd * 3.0 + cn * off * 0.2
			p.strand(PackedVector2Array([f0, f1]), 0.75, 0.6, flesh)
			p.strand(PackedVector2Array([f1, f2]), 0.55, 0.25, claw)
	# ---- head: elongated, gaunt, jaw hanging open
	var hx := cx + (2.5 if pain else 0.0)
	var hy := 31.0 + by
	var jaw := 2.5 if atk == 0 else 4.5
	p.ball(hx, hy - 0.5, 5.6, 6.2, flesh)
	p.ball(hx, hy - 3.0, 5.2, 4.2, flesh.lightened(0.04))
	p.ball(hx - 3.2, hy + 0.8, 1.4, 1.8, dark)
	p.ball(hx + 3.2, hy + 0.8, 1.4, 1.8, dark.lightened(0.05))
	p.ball(hx, hy + 4.0 + jaw * 0.5, 3.4, 1.8 + jaw * 0.35, flesh.darkened(0.08))
	p.ellipse(hx, hy + 3.4 + jaw * 0.45, 2.6, 0.6 + jaw * 0.5, Color(0.12, 0.02, 0.03))
	for i in 5:
		var tx := hx - 2.0 + i
		p.rect(tx, hy + 2.6, 0.6, 1.0, Color(0.62, 0.58, 0.42))
		p.rect(tx, hy + 3.6 + jaw * 0.9, 0.6, 0.9, Color(0.58, 0.54, 0.4))
	# pointed ears and sparse hair
	p.poly(PackedVector2Array([Vector2(hx - 5.0, hy - 1.0), Vector2(hx - 8.5, hy - 2.5), Vector2(hx - 4.8, hy + 1.5)]), flesh.darkened(0.2))
	p.poly(PackedVector2Array([Vector2(hx + 5.0, hy - 1.0), Vector2(hx + 8.5, hy - 2.5), Vector2(hx + 4.8, hy + 1.5)]), flesh.darkened(0.08))
	for i in 5:
		var side := -1.0 if i % 2 == 0 else 1.0
		var hx0 := hx + side * (1.5 + i * 0.8)
		p.strand(PackedVector2Array([Vector2(hx0, hy - 5.8), Vector2(hx0 + side * 1.6, hy - 2.0), Vector2(hx0 + side * 2.4, hy + 2.0 + (i % 3) * 1.5)]), 0.35, 0.3, Color(0.22, 0.2, 0.17))
	# brow ridge + sunken eyes
	p.capsule(Vector2(hx - 3.5, hy - 1.2), Vector2(hx + 3.5, hy - 1.2), 0.9, 0.9, flesh.darkened(0.1))
	var eye := Color(0.95, 0.82, 0.35)
	for ex in [-1.8, 1.8]:
		p.ellipse(hx + float(ex), hy + 0.2, 1.1, 0.9, VOID)
		var e := p.tp(Vector2(hx + float(ex), hy + 0.2))
		p.put(int(e.x), int(e.y), eye)
		glows.append([e, 1.6, eye, 0.7])
	if atk == 2:
		for kk in 3:
			for t in 6:
				var pt := Vector2(cx - 16 + kk * 5 + t * 3.5, 40 + t * 3.0 + kk)
				glows.append([p.tp(pt), 1.4, Color(0.7, 0.7, 0.7), 0.25])
	# rot, bruises, filth
	p.grime(Color(0.26, 0.17, 0.24), 0.5, 0.09, 0.15, 0.0)
	p.grime(Color(0.18, 0.2, 0.1), 0.45, 0.14, 0.2, 0.3)
	p.grime(Color(0.25, 0.05, 0.05), 0.35, 0.2, 0.42, 0.7)
	return glows


static func ghoul_corpse(p: Painter) -> Array:
	var flesh := Color(0.43, 0.46, 0.39)
	p.ellipse(48, 92, 30, 3.4, Color(0.17, 0.02, 0.03))
	p.ellipse(44, 91.5, 18, 2.2, Color(0.27, 0.03, 0.04))
	# body lying on its side, seen from the front
	p.capsule(Vector2(18, 88), Vector2(34, 86), 3.0, 3.4, flesh)
	p.cyl_poly(PackedVector2Array([Vector2(30, 80), Vector2(58, 80), Vector2(60, 91), Vector2(28, 91)]), flesh, 44, 16, -0.6)
	for i in 4:
		p.line(Vector2(36 + i * 4, 82), Vector2(37 + i * 4, 89), flesh.darkened(0.5))
	p.ball(48, 84, 3.0, 2.6, Color(0.24, 0.05, 0.06))
	p.capsule(Vector2(56, 86), Vector2(74, 90), 2.6, 2.0, flesh)
	p.capsule(Vector2(52, 83), Vector2(66, 78), 2.0, 1.6, flesh)
	p.ball(68, 84, 4.6, 4.2, flesh)
	p.ellipse(70, 85.5, 2.2, 1.2, Color(0.12, 0.02, 0.03))
	p.ellipse(67, 82.5, 0.9, 0.7, VOID)
	p.capsule(Vector2(14, 92), Vector2(24, 92), 1.8, 1.6, flesh.darkened(0.2))
	p.grime(Color(0.26, 0.17, 0.24), 0.5, 0.09, 0.15)
	return []


# =============================================================================== cultist

static func cultist(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var robe := Color(0.2, 0.13, 0.22)
	var mantle := Color(0.24, 0.16, 0.26)
	var skin := Color(0.55, 0.5, 0.5)
	var magic := Color(0.72, 0.38, 1.0)
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cx := 48.0 + (1.5 if pain else 0.0)
	var by := bob + (1.0 if pain else 0.0)
	var sway := step * 2.5
	# ---- robe body with frayed hem
	var body := PackedVector2Array([Vector2(cx - 10.5, 25 + by), Vector2(cx + 10.5, 25 + by), Vector2(cx + 13, 50 + by), Vector2(cx + 17 + sway, 90)])
	for i in 13:
		var hx := cx + 17 + sway - i * (34.0 / 12.0)
		body.append(Vector2(hx, 93.5 - (i % 2) * 2.5 - (1.5 if i % 4 == 1 else 0.0)))
	body.append(Vector2(cx - 13, 50 + by))
	p.cloth(body, robe, cx + sway * 0.3, 16.0, 0.75, 0.42)
	# feet peeking out
	if step != 0.0:
		var fs := -signf(step)
		p.ball(cx + fs * 6 + sway, 92.5, 3.0, 1.6, Color(0.14, 0.1, 0.08))
	# embroidered hem band (dull gold, worn)
	for i in 30:
		var t := float(i) / 29.0
		var bx := lerpf(cx - 15.5 + sway, cx + 15.5 + sway, t)
		var byy := 86.0 + sin(t * 18.0) * 0.8
		p.tput(bx, byy, GOLD.darkened(0.25 if i % 3 == 0 else 0.45))
	# rope belt, hanging cords, bone charm
	p.capsule(Vector2(cx - 11.5, 50 + by), Vector2(cx + 11.5, 50 + by), 1.2, 1.2, Color(0.4, 0.33, 0.22))
	p.strand(PackedVector2Array([Vector2(cx + 3, 50.5 + by), Vector2(cx + 3.5, 58 + by), Vector2(cx + 3 + sway * 0.4, 65 + by)]), 0.8, 0.6, Color(0.4, 0.33, 0.22))
	p.strand(PackedVector2Array([Vector2(cx - 2, 50.5 + by), Vector2(cx - 2.5, 57 + by), Vector2(cx - 2 + sway * 0.4, 62 + by)]), 0.8, 0.6, Color(0.4, 0.33, 0.22))
	p.ball(cx - 2 + sway * 0.4, 63.5 + by, 1.6, 1.8, BONE)
	p.ellipse(cx - 2.6 + sway * 0.4, 63.2 + by, 0.5, 0.5, VOID)
	p.ellipse(cx - 1.4 + sway * 0.4, 63.2 + by, 0.5, 0.5, VOID)
	# mantle over the shoulders
	var mt := PackedVector2Array([Vector2(cx - 12.5, 24 + by), Vector2(cx + 12.5, 24 + by), Vector2(cx + 12, 33 + by), Vector2(cx + 7, 41 + by), Vector2(cx, 44 + by), Vector2(cx - 7, 41 + by), Vector2(cx - 12, 33 + by)])
	p.cloth(mt, mantle, cx, 13.0, 1.1, 0.3, -0.35)
	p.strand(PackedVector2Array([Vector2(cx - 7, 41 + by), Vector2(cx, 44 + by), Vector2(cx + 7, 41 + by)]), 0.6, 0.6, GOLD.darkened(0.4))
	# ---- arms in wide sleeves
	var lsh := Vector2(cx - 11, 27 + by)
	var rsh := Vector2(cx + 11, 27 + by)
	var lel := Vector2(cx - 13, 39 + by)
	var rel := Vector2(cx + 13, 39 + by)
	var lha := Vector2(cx - 4, 47 + by)
	var rha := Vector2(cx + 4, 47 + by)
	if atk == 1:
		lel = Vector2(cx - 14, 20 + by); lha = Vector2(cx - 6, 9 + by)
		rel = Vector2(cx + 14, 20 + by); rha = Vector2(cx + 6, 9 + by)
	elif atk == 2:
		lel = Vector2(cx - 12, 35 + by); lha = Vector2(cx - 4, 34 + by)
		rel = Vector2(cx + 12, 35 + by); rha = Vector2(cx + 4, 34 + by)
	elif pain:
		lel = Vector2(cx - 16, 34 + by); lha = Vector2(cx - 18, 42 + by)
		rel = Vector2(cx + 15, 33 + by); rha = Vector2(cx + 19, 40 + by)
	for arm in [[lsh, lel, lha], [rsh, rel, rha]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var hd: Vector2 = arm[2]
		p.capsule(sh, el, 3.6, 3.8, robe.lightened(0.04))
		var cuff := hd + (el - hd).normalized() * 2.2
		p.capsule(el, cuff, 3.8, 4.8, robe.lightened(0.04))
		p.ellipse(cuff.x, cuff.y, 2.6, 2.0, VOID)
		var hdir := (hd - el).normalized()
		var hn := Vector2(-hdir.y, hdir.x)
		p.ball(hd.x, hd.y, 1.9, 2.0, skin)
		for f in 4:
			var f0 := hd + hn * ((float(f) - 1.5) * 0.9)
			p.capsule(f0, f0 + hdir * 3.6 + hn * ((float(f) - 1.5) * 0.4), 0.55, 0.4, skin)
	# ritual dagger held low when idle
	if atk == 0 and not pain:
		p.spec = 0.6
		p.blade(Vector2(cx, 47 + by), Vector2(cx - 1, 60 + by), 1.1, 0.3, Color(0.5, 0.48, 0.5))
		p.spec = 0.0
		p.capsule(Vector2(cx - 2.5, 47 + by), Vector2(cx + 2.5, 47 + by), 0.7, 0.7, GOLD.darkened(0.3))
	# ---- hood with a shadowed gaunt face
	var hx := cx + (2.0 if pain else 0.0)
	var hy := 15.0 + by
	p.ball(hx, hy, 7.2, 8.2, mantle.darkened(0.08))
	p.cloth(PackedVector2Array([Vector2(hx - 6.5, hy - 4), Vector2(hx + 6.5, hy - 4), Vector2(hx + 1.5, hy - 12.5)]), mantle.darkened(0.08), hx, 6.0, 1.0, 0.3)
	p.ellipse(hx, hy + 1.6, 4.4, 5.6, VOID)
	p.ball(hx, hy + 4.8, 2.5, 2.0, skin.darkened(0.45))
	p.rect(hx - 1.2, hy + 5.0, 2.4, 0.6, Color(0.1, 0.05, 0.06))
	# hood rim
	p.strand(PackedVector2Array([Vector2(hx - 4.8, hy + 6.5), Vector2(hx - 5.2, hy - 1), Vector2(hx, hy - 4.8), Vector2(hx + 5.2, hy - 1), Vector2(hx + 4.8, hy + 6.5)]), 1.0, 1.0, mantle)
	var eye := Color(0.85, 0.55, 1.0)
	for ex in [-1.8, 1.8]:
		var e := p.tp(Vector2(hx + float(ex), hy + 1.6))
		p.put(int(e.x), int(e.y), Color(1, 0.9, 1))
		glows.append([e, 1.8, eye, 0.9])
	if atk == 1:
		var oc := Vector2(cx, 5 + by)
		p.light_only(oc.x, oc.y + 8, 16, magic, 0.9)
		glows.append([p.tp(oc), 6.0, magic, 1.3])
		glows.append([p.tp(oc), 2.5, Color(1, 0.92, 1), 1.0])
	elif atk == 2:
		var oc2 := Vector2(cx, 33 + by)
		p.light_only(oc2.x, oc2.y, 14, magic, 0.8)
		glows.append([p.tp(oc2), 7.0, magic, 1.3])
		glows.append([p.tp(oc2), 3.0, Color(1, 0.92, 1), 1.0])
	p.grime(Color(0.12, 0.1, 0.08), 0.45, 0.1, 0.1, 0.8)
	return glows


static func cultist_corpse(p: Painter) -> Array:
	var robe := Color(0.2, 0.13, 0.22)
	p.ellipse(46, 92, 24, 3.0, Color(0.1, 0.03, 0.08))
	p.cloth(PackedVector2Array([Vector2(16, 93), Vector2(22, 84), Vector2(40, 80), Vector2(62, 82), Vector2(76, 93)]), robe, 46, 30, 0.9, 0.4, -0.6)
	p.strand(PackedVector2Array([Vector2(20, 91), Vector2(46, 89), Vector2(72, 91)]), 0.6, 0.6, GOLD.darkened(0.45))
	p.ball(70, 84, 6.0, 5.0, robe.lightened(0.04))
	p.ellipse(71.5, 85.5, 3.2, 2.6, VOID)
	p.ball(24, 87, 1.9, 1.6, Color(0.55, 0.5, 0.5))
	for f in 4:
		p.capsule(Vector2(22, 86 + f * 0.8), Vector2(18, 87 + f * 1.2), 0.5, 0.4, Color(0.55, 0.5, 0.5))
	p.blade(Vector2(6, 92), Vector2(16, 90), 1.0, 0.3, Color(0.5, 0.48, 0.5))
	p.grime(Color(0.12, 0.1, 0.08), 0.45, 0.1, 0.1)
	return []


# =============================================================================== brute (designed at 96, drawn at 144)

static func brute(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var flesh := Color(0.36, 0.4, 0.41)
	var bruise := Color(0.28, 0.22, 0.3)
	var plate := Color(0.3, 0.29, 0.3)
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var pain: bool = pose.get("pain", false)
	var cx := 48.0 + (1.5 if pain else 0.0)
	var by := bob * 0.8 + (1.0 if pain else 0.0)
	# ---- legs
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var lift := maxf(step * s, 0.0)
		var hip := Vector2(cx + s * 10.0, 64 + by * 0.5)
		var knee := Vector2(cx + s * 13.0, 78.0 - lift * 3.0)
		var ankle := Vector2(cx + s * 13.0, 90.0 - lift * 3.5)
		p.capsule(hip, knee, 7.0, 5.2, flesh)
		p.capsule(knee, ankle, 5.0, 3.8, LEATHER)
		for kk in 3:
			p.capsule(knee.lerp(ankle, 0.25 + kk * 0.25) + Vector2(-5, 0), knee.lerp(ankle, 0.25 + kk * 0.25) + Vector2(5, 0.5), 0.6, 0.6, LEATHER.darkened(0.35))
		p.spec = 0.4
		p.ball(knee.x, knee.y, 4.0, 3.4, plate)
		p.spec = 0.0
		p.ball(ankle.x + s * 1.5, ankle.y + 2.4, 5.6, 2.6, LEATHER.darkened(0.25))
	# ---- plated war-skirt on leather straps
	p.cloth(PackedVector2Array([Vector2(cx - 17, 59 + by), Vector2(cx + 17, 59 + by), Vector2(cx + 16, 72 + by), Vector2(cx - 16, 72 + by)]), LEATHER, cx, 18, 0.9, 0.25)
	p.spec = 0.35
	for kk in 5:
		var px := cx - 15 + kk * 6.3
		p.flat_poly(PackedVector2Array([Vector2(px, 61 + by), Vector2(px + 5, 61 + by), Vector2(px + 5.4, 74 + by), Vector2(px - 0.4, 74 + by)]), RUST if kk % 2 == 0 else plate, Vector3((kk - 2) * 0.35, -0.2, 1))
		p.ball(px + 2.5, 62.5 + by, 0.7, 0.7, IRON.lightened(0.3))
	p.spec = 0.0
	# ---- huge torso: barrel chest + bloated gut
	p.ball(cx, 51 + by, 18.0, 12.0, flesh)
	p.ball(cx, 36 + by, 20.5, 13.0, flesh)
	p.ball(cx - 8, 34 + by, 9.0, 6.5, flesh)
	p.ball(cx + 8, 34 + by, 9.0, 6.5, flesh)
	p.line(Vector2(cx - 15, 40 + by), Vector2(cx + 15, 40 + by), flesh.darkened(0.45))
	# long stitched autopsy scar with crude staples
	p.line(Vector2(cx - 3, 27 + by), Vector2(cx + 2, 60 + by), Color(0.2, 0.06, 0.08), 1.0)
	for kk in 9:
		var sp := Vector2(cx - 3, 27 + by).lerp(Vector2(cx + 2, 60 + by), float(kk) / 8.0)
		p.line(sp + Vector2(-1.6, -0.4), sp + Vector2(1.6, 0.4), Color(0.55, 0.5, 0.42))
	# exposed ribs on the flank
	p.ball(cx + 13, 44 + by, 4.5, 5.5, Color(0.25, 0.05, 0.06))
	for i in 3:
		p.capsule(Vector2(cx + 9.5, 41 + i * 2.6 + by), Vector2(cx + 16, 42.5 + i * 2.6 + by), 0.7, 0.6, BONE)
	# rusted breastplate fragment strapped across
	p.spec = 0.4
	p.flat_poly(PackedVector2Array([Vector2(cx - 18, 27 + by), Vector2(cx - 4, 25 + by), Vector2(cx - 2, 38 + by), Vector2(cx - 16, 42 + by)]), Color(0.27, 0.18, 0.12), Vector3(-0.3, -0.35, 1))
	p.line(Vector2(cx - 18, 27 + by), Vector2(cx - 4, 25 + by), Color(0.5, 0.38, 0.28))
	for rv in [Vector2(cx - 15, 29), Vector2(cx - 6, 27.5), Vector2(cx - 14, 39)]:
		var rvv: Vector2 = rv
		p.ball(rvv.x, rvv.y + by, 0.8, 0.8, IRON.lightened(0.3))
	p.spec = 0.0
	p.capsule(Vector2(cx - 20, 24 + by), Vector2(cx + 17, 48 + by), 1.0, 1.0, LEATHER)
	# hanging chain
	p.spec = 0.6
	for kk in 9:
		var cp := Vector2(cx + 5 + kk * 1.9, 23 + kk * 2.6 + by)
		p.ball(cp.x, cp.y, 1.1, 0.8, IRON)
	p.spec = 0.0
	# ---- shoulders & arms
	var lsh := Vector2(cx - 23, 27 + by)
	var rsh := Vector2(cx + 23, 27 + by)
	p.capsule(Vector2(cx - 6, 18 + by), lsh, 5.0, 6.0, flesh)
	p.capsule(Vector2(cx + 6, 18 + by), rsh, 5.0, 6.0, flesh)
	p.ball(lsh.x, lsh.y, 8.0, 7.0, flesh)
	p.ball(rsh.x, rsh.y, 8.0, 7.0, flesh)
	# layered pauldron on the left shoulder
	p.spec = 0.45
	for kk in 3:
		p.ball(lsh.x - 1, lsh.y - 2 + kk * 3.2, 8.5 - kk * 0.8, 4.0, plate if kk % 2 == 0 else RUST)
	for kk in 3:
		var bx := lsh.x - 5 + kk * 4.5
		p.poly(PackedVector2Array([Vector2(bx - 1.3, lsh.y - 5), Vector2(bx + 1.3, lsh.y - 5), Vector2(bx + (kk - 1) * 0.8, lsh.y - 11 + absi(kk - 1) * 2)]), BONE)
	p.spec = 0.0
	var lel := Vector2(cx - 30, 44 + by)
	var lwr := Vector2(cx - 30, 59 + by)
	var rel := Vector2(cx + 30, 44 + by)
	var rwr := Vector2(cx + 31, 58 + by)
	if atk == 1:
		lel = Vector2(cx - 24, 18 + by); lwr = Vector2(cx - 6, 8 + by)
		rel = Vector2(cx + 24, 18 + by); rwr = Vector2(cx + 6, 8 + by)
	elif atk == 2:
		lel = Vector2(cx - 24, 46 + by); lwr = Vector2(cx - 6, 58 + by)
		rel = Vector2(cx + 24, 46 + by); rwr = Vector2(cx + 6, 58 + by)
	elif pain:
		lel = Vector2(cx - 32, 38 + by); lwr = Vector2(cx - 38, 50 + by)
		rel = Vector2(cx + 32, 38 + by); rwr = Vector2(cx + 38, 48 + by)
	for arm in [[lsh, lel, lwr], [rsh, rel, rwr]]:
		var sh: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var wr: Vector2 = arm[2]
		p.capsule(sh + Vector2(0, 3), el, 6.5, 5.0, flesh)
		var bic := sh.lerp(el, 0.55)
		p.ball(bic.x, bic.y, 5.6, 5.0, flesh)
		p.capsule(el, wr, 5.2, 4.4, flesh)
		p.ball(el.x, el.y, 4.5, 4.0, flesh.darkened(0.05))
		var mid := el.lerp(wr, 0.6)
		var dn := (wr - el).normalized()
		var nn := Vector2(-dn.y, dn.x)
		p.capsule(mid - dn * 3.5, wr, 5.0, 4.8, LEATHER)
		p.capsule(mid - dn * 3.5 + nn * 5, mid - dn * 3.5 - nn * 5, 0.9, 0.9, IRON)
		p.ball(wr.x + dn.x * 3, wr.y + dn.y * 3, 5.2, 4.8, flesh.darkened(0.1))
		for f in 4:
			var kn := wr + dn * 5.0 + nn * ((float(f) - 1.5) * 2.2)
			p.ball(kn.x, kn.y, 1.4, 1.3, flesh.darkened(0.15))
	# ---- head: small, sunk between the shoulders, iron cage helm
	var hx := cx + (2.5 if pain else 0.0)
	var hy := 16.5 + by
	p.ball(hx, hy + 1.5, 7.0, 7.0, flesh)
	p.ball(hx, hy + 5.0, 6.0, 3.6, flesh.darkened(0.08))
	p.ellipse(hx, hy + 5.6, 3.6, 1.2 + (1.2 if atk > 0 else 0.0), Color(0.12, 0.03, 0.04))
	for i in 5:
		p.rect(hx - 2.6 + i * 1.2, hy + 4.6, 0.6, 0.8, BONE)
	p.spec = 0.55
	p.cyl_poly(PackedVector2Array([Vector2(hx - 7.2, hy - 6.5), Vector2(hx + 7.2, hy - 6.5), Vector2(hx + 7.6, hy + 3.8), Vector2(hx - 7.6, hy + 3.8)]), plate, hx, 7.6, -0.2)
	p.ball(hx, hy - 6.5, 7.2, 2.0, plate.lightened(0.08))
	p.capsule(Vector2(hx - 7.4, hy - 3.2), Vector2(hx + 7.4, hy - 3.2), 0.9, 0.9, RUST)
	p.capsule(Vector2(hx, hy - 6.5), Vector2(hx, hy + 3.6), 0.9, 0.9, RUST)
	p.rect(hx - 6.0, hy + 0.6, 12.0, 1.5, VOID)
	for i in 3:
		p.rect(hx - 5.0 + i * 0.9, hy + 2.8, 0.6, 0.6, VOID)
		p.rect(hx + 3.0 + i * 0.9, hy + 2.8, 0.6, 0.6, VOID)
	for rv2 in [Vector2(hx - 6, hy - 5), Vector2(hx + 6, hy - 5), Vector2(hx - 6, hy + 2.6), Vector2(hx + 6, hy + 2.6)]:
		var r2: Vector2 = rv2
		p.ball(r2.x, r2.y, 0.6, 0.6, IRON.lightened(0.35))
	p.spec = 0.0
	var eye := SOUL
	for ex in [-2.6, 2.6]:
		var e := p.tp(Vector2(hx + float(ex), hy + 1.3))
		p.put(int(e.x), int(e.y), eye.lightened(0.5))
		glows.append([e, 2.2, eye, 0.9])
	# ---- maul
	var top: Vector2
	var bot: Vector2
	if atk == 1:
		bot = Vector2(cx, 16 + by); top = Vector2(cx - 1, -8 + by)
	elif atk == 2:
		bot = Vector2(cx, 52 + by); top = Vector2(cx - 1, 84)
	else:
		bot = rwr + Vector2(0, 12); top = rwr + Vector2(6, -32)
	p.capsule(bot, top, 1.7, 1.7, WOOD)
	for kk in 3:
		var bp := bot.lerp(top, 0.2 + kk * 0.25)
		p.capsule(bp + Vector2(-2, 0), bp + Vector2(2, 0), 0.6, 0.6, IRON)
	var hd := (top - bot).normalized()
	var hn := Vector2(-hd.y, hd.x)
	var c0 := top - hd * 4.0
	var stone := Color(0.4, 0.39, 0.37)
	var depth := Vector2(-2.6, -2.6)
	var hw2 := 9.0
	var hl := 7.5
	var front := PackedVector2Array([c0 + hn * hw2 - hd * hl, c0 + hn * hw2 + hd * hl, c0 - hn * hw2 + hd * hl, c0 - hn * hw2 - hd * hl])
	var topf := PackedVector2Array([front[0], front[0] + depth, front[1] + depth, front[1]])
	var sidef := PackedVector2Array([front[1], front[1] + depth, front[2] + depth, front[2]])
	p.flat_poly(topf, stone.lightened(0.1), Vector3(-0.4, -0.8, 0.5))
	p.flat_poly(sidef, stone, Vector3(-0.8, -0.2, 0.5))
	p.flat_poly(front, stone, Vector3(0.1, 0.1, 1))
	for crk in 4:
		var c1 := c0 + hn * (-6.0 + crk * 4.0) + hd * (-5.0 + (crk % 2) * 4.0)
		p.line(c1, c1 + hd * 3.0 + hn * 1.5, stone.darkened(0.55))
	p.spec = 0.5
	for band in [-4.0, 4.0]:
		var bf: float = band
		p.capsule(c0 + hn * (hw2 + 0.6) + hd * bf, c0 - hn * (hw2 + 0.6) + hd * bf, 1.1, 1.1, IRON)
	p.spec = 0.0
	if atk == 2:
		for kk in 10:
			glows.append([p.tp(Vector2(cx - 24 + kk * 5.3, 90 - (kk % 3))), 3.5, Color(0.45, 0.42, 0.36), 0.55])
	p.grime(bruise, 0.5, 0.07, 0.12)
	p.grime(Color(0.2, 0.22, 0.14), 0.4, 0.12, 0.25, 0.4)
	p.grime(Color(0.25, 0.04, 0.05), 0.4, 0.16, 0.45, 0.8)
	return glows


static func brute_corpse(p: Painter) -> Array:
	var flesh := Color(0.42, 0.46, 0.47)
	p.ellipse(48, 91, 40, 4.0, Color(0.17, 0.02, 0.03))
	p.ball(48, 84, 26, 9.0, flesh)
	p.ball(40, 82, 12, 6, flesh)
	p.line(Vector2(36, 80), Vector2(58, 86), Color(0.2, 0.06, 0.08))
	p.spec = 0.4
	p.ball(20, 86, 9, 5.5, Color(0.3, 0.29, 0.3))
	p.spec = 0.0
	p.capsule(Vector2(66, 88), Vector2(88, 91), 5.0, 4.0, flesh)
	p.ball(76, 79, 7, 5.5, flesh)
	p.spec = 0.5
	p.ball(76, 77.5, 7.4, 4.0, Color(0.3, 0.29, 0.3))
	p.spec = 0.0
	p.capsule(Vector2(4, 92), Vector2(32, 92), 1.7, 1.7, WOOD)
	p.flat_poly(PackedVector2Array([Vector2(1, 84), Vector2(11, 84), Vector2(11, 95), Vector2(1, 95)]), Color(0.42, 0.41, 0.4), Vector3(0, -1, 0.6))
	p.grime(Color(0.3, 0.26, 0.32), 0.5, 0.07, 0.12)
	return []


# =============================================================================== boss (designed at 128, drawn at 192)

static func boss(p: Painter, pose: Dictionary) -> Array:
	var glows: Array = []
	var armor := DARK_STEEL
	var cape := Color(0.16, 0.09, 0.18)
	var fur := Color(0.32, 0.3, 0.28)
	var bob: float = pose.get("bob", 0.0)
	var step: float = pose.get("step", 0.0)
	var atk: int = pose.get("atk", 0)
	var cast: bool = pose.get("cast", false)
	var pain: bool = pose.get("pain", false)
	var cx := 64.0 + (2.0 if pain else 0.0)
	var by := bob * 1.2 + (1.5 if pain else 0.0)
	# ---- tattered mantle behind
	var cp := PackedVector2Array([Vector2(cx - 24, 38 + by), Vector2(cx + 24, 38 + by), Vector2(cx + 36, 90), Vector2(cx + 40, 120)])
	for i in 17:
		var x := cx + 40 - i * 5.0
		cp.append(Vector2(x, 126 - (i % 2) * 7 - (5 if i % 3 == 0 else 0) - (3 if i % 5 == 2 else 0)))
	cp.append(Vector2(cx - 36, 90))
	p.cloth(cp, cape, cx, 40.0, 0.55, 0.4)
	for i in 4:
		p.erase_ellipse(cx - 30 + i * 19, 112 - (i % 2) * 6, 1.6, 2.6)
	# ---- legs: dark greaves with gold edging
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var lift := maxf(step * s, 0.0)
		var hip := Vector2(cx + s * 8.5, 82 + by * 0.5)
		var knee := Vector2(cx + s * 11.0, 102.0 - lift * 5.0)
		var ankle := Vector2(cx + s * 11.5, 121.0 - lift * 6.0)
		p.spec = 0.7
		p.capsule(hip, knee, 5.2, 4.2, armor)
		p.capsule(knee, ankle, 4.2, 3.4, armor)
		p.line(knee + Vector2(-s * 3.5, 3), ankle + Vector2(-s * 2.8, -2), GOLD.darkened(0.2))
		p.ball(knee.x, knee.y, 4.6, 4.0, armor.lightened(0.08))
		p.poly(PackedVector2Array([knee + Vector2(-1.5, -2.5), knee + Vector2(1.5, -2.5), knee + Vector2(0, -9)]), BONE)
		p.ball(ankle.x + s * 1.5, ankle.y + 2.5, 6.2, 3.0, armor)
		p.spec = 0.0
	# ---- armoured tassets
	p.spec = 0.35
	for kk in 4:
		var tx := cx - 16 + kk * 8.2
		p.cyl_poly(PackedVector2Array([Vector2(tx, 74 + by), Vector2(tx + 7.8, 74 + by), Vector2(tx + 8.6, 92 + by), Vector2(tx + 3.9, 93.5 + by), Vector2(tx - 0.8, 92 + by)]), armor.darkened(0.15), tx + 3.9, 5.0, -0.1)
		p.line(Vector2(tx - 0.6, 91.6 + by), Vector2(tx + 3.9, 93 + by), GOLD.darkened(0.3))
		p.line(Vector2(tx + 3.9, 93 + by), Vector2(tx + 8.4, 91.6 + by), GOLD.darkened(0.45))
	p.spec = 0.0
	# ---- torso: cuirass split open over the ribs, soul fire within
	p.spec = 0.6
	p.cyl_poly(PackedVector2Array([Vector2(cx - 17, 39 + by), Vector2(cx + 17, 39 + by), Vector2(cx + 20, 47 + by), Vector2(cx + 18, 58 + by), Vector2(cx + 13, 66 + by), Vector2(cx + 14, 76 + by), Vector2(cx - 14, 76 + by), Vector2(cx - 13, 66 + by), Vector2(cx - 18, 58 + by), Vector2(cx - 20, 47 + by)]), armor, cx, 20, -0.3)
	for lame in 3:
		var ly := 66.0 + lame * 3.4 + by
		p.line(Vector2(cx - 13.5, ly), Vector2(cx + 13.5, ly), armor.darkened(0.6))
		p.line(Vector2(cx - 13.5, ly + 0.8), Vector2(cx + 13.5, ly + 0.8), armor.lightened(0.25))
	p.spec = 0.0
	p.poly(PackedVector2Array([Vector2(cx - 6, 46 + by), Vector2(cx + 7, 45 + by), Vector2(cx + 9, 58 + by), Vector2(cx + 3, 70 + by), Vector2(cx - 4, 68 + by), Vector2(cx - 9, 57 + by)]), Color(0.05, 0.12, 0.07))
	for i in 5:
		var ry := 48.0 + i * 4.0 + by
		p.strand(PackedVector2Array([Vector2(cx - 0.5, ry), Vector2(cx - 5, ry + 1.0), Vector2(cx - 8.5, ry + 3.0)]), 1.2, 0.9, BONE)
		p.strand(PackedVector2Array([Vector2(cx + 0.5, ry), Vector2(cx + 5, ry + 1.0), Vector2(cx + 8.5, ry + 3.0)]), 1.2, 0.9, BONE)
	p.capsule(Vector2(cx, 45 + by), Vector2(cx, 70 + by), 1.6, 1.4, BONE.darkened(0.1))
	p.ball(cx, 57 + by, 3.2, 3.8, SOUL)
	p.light_only(cx, 57 + by, 14, SOUL, 0.7)
	glows.append([p.tp(Vector2(cx, 57 + by)), 6.0, SOUL, 1.1])
	# gold filigree on the plate edges
	p.line(Vector2(cx - 18, 41 + by), Vector2(cx - 14, 75 + by), GOLD.darkened(0.1))
	p.line(Vector2(cx + 18, 41 + by), Vector2(cx + 14, 75 + by), GOLD.darkened(0.35))
	p.capsule(Vector2(cx - 15, 74 + by), Vector2(cx + 15, 74 + by), 1.2, 1.2, LEATHER)
	# ---- fur collar + pauldrons with bone spikes
	p.ball(cx, 38 + by, 20.0, 5.0, fur, 0.35)
	var lsh := Vector2(cx - 22, 42 + by)
	var rsh := Vector2(cx + 22, 42 + by)
	for sh in [lsh, rsh]:
		var shv: Vector2 = sh
		p.spec = 0.7
		for kk in 3:
			p.ball(shv.x, shv.y - 2 + kk * 4.0, 12.5 - kk * 1.5, 6.0, armor if kk != 1 else armor.lightened(0.06))
			p.strand(PackedVector2Array([Vector2(shv.x - 11 + kk * 1.5, shv.y + 1 + kk * 4.0), Vector2(shv.x + 11 - kk * 1.5, shv.y + 1 + kk * 4.0)]), 0.6, 0.6, GOLD.darkened(0.15))
		p.spec = 0.0
		for kk in 3:
			var bx := shv.x - 7 + kk * 7
			p.strand(PackedVector2Array([Vector2(bx, shv.y - 6), Vector2(bx + (kk - 1) * 1.5, shv.y - 13), Vector2(bx + (kk - 1) * 3.0, shv.y - 19 + absi(kk - 1) * 3)]), 2.0, 0.4, BONE)
	# ---- arms: armoured upper arm, bare skeletal forearm and hand
	var lel := Vector2(cx - 28, 62 + by)
	var lwr := Vector2(cx - 27, 79 + by)
	var rel := Vector2(cx + 29, 61 + by)
	var rwr := Vector2(cx + 31, 78 + by)
	if cast:
		lel = Vector2(cx - 30, 30 + by); lwr = Vector2(cx - 18, 15 + by)
		rel = Vector2(cx + 30, 30 + by); rwr = Vector2(cx + 18, 15 + by)
	elif atk == 1:
		rel = Vector2(cx + 33, 30 + by); rwr = Vector2(cx + 27, 15 + by)
		lel = Vector2(cx - 22, 34 + by); lwr = Vector2(cx - 4, 24 + by)
	elif atk == 2:
		rel = Vector2(cx + 20, 62 + by); rwr = Vector2(cx + 3, 73 + by)
		lel = Vector2(cx - 24, 62 + by); lwr = Vector2(cx - 11, 72 + by)
	elif pain:
		lel = Vector2(cx - 32, 54 + by); lwr = Vector2(cx - 40, 64 + by)
		rel = Vector2(cx + 32, 54 + by); rwr = Vector2(cx + 40, 62 + by)
	for arm in [[lsh, lel, lwr], [rsh, rel, rwr]]:
		var sh2: Vector2 = arm[0]
		var el: Vector2 = arm[1]
		var wr: Vector2 = arm[2]
		p.spec = 0.6
		p.capsule(sh2 + Vector2(0, 6), el, 4.6, 4.0, armor)
		p.ball(el.x, el.y, 4.2, 3.8, armor.lightened(0.06))
		p.spec = 0.0
		var dn := (wr - el).normalized()
		var nn := Vector2(-dn.y, dn.x)
		p.capsule(el + nn * 1.0, wr + nn * 1.0, 1.4, 1.1, BONE)
		p.capsule(el - nn * 1.2, wr - nn * 0.8, 1.1, 0.9, BONE.darkened(0.1))
		_bone_hand(p, wr, dn, 1.2, BONE, 6.0)
	# ---- skull with antler crown
	var hx := cx + (3.0 if pain else 0.0)
	var hy := 27.0 + by
	p.capsule(Vector2(hx, hy + 8), Vector2(hx, hy + 13), 2.2, 2.2, BONE.darkened(0.15))
	_skull(p, hx, hy, 1.35, 1.6 if (atk == 2 or cast or pain) else 0.6, SOUL, glows)
	p.light_only(hx, hy + 1, 7, SOUL, 0.35)
	p.spec = 0.8
	p.capsule(Vector2(hx - 8, hy - 5.5), Vector2(hx + 8, hy - 5.5), 1.5, 1.5, GOLD.darkened(0.1))
	p.spec = 0.0
	for kk in 3:
		p.ball(hx - 5 + kk * 5, hy - 5.8, 1.1, 1.1, SOUL)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var a0 := Vector2(hx + s * 6.5, hy - 6.5)
		var a1 := a0 + Vector2(s * 6.0, -9.0)
		var a2 := a1 + Vector2(s * 5.5, -8.5)
		var a3 := a2 + Vector2(s * 1.0, -6.0)
		p.strand(PackedVector2Array([a0, a1, a2, a3]), 1.7, 0.6, BONE.darkened(0.05))
		p.strand(PackedVector2Array([a1, a1 + Vector2(-s * 1.5, -5.5), a1 + Vector2(-s * 1.0, -9.5)]), 1.1, 0.5, BONE.darkened(0.05))
		p.strand(PackedVector2Array([a0.lerp(a1, 0.45), a0.lerp(a1, 0.45) + Vector2(s * 6.5, -1.5), a0.lerp(a1, 0.45) + Vector2(s * 9.0, -4.0)]), 1.0, 0.45, BONE.darkened(0.05))
		p.strand(PackedVector2Array([a2, a2 + Vector2(s * 4.5, -1.0)]), 0.9, 0.4, BONE.darkened(0.05))
	# ---- scythe
	var s_bot: Vector2
	var s_top: Vector2
	if cast:
		s_bot = Vector2(cx + 42, 126); s_top = Vector2(cx + 44, 32)
	elif atk == 1:
		s_bot = rwr + Vector2(6, 28); s_top = rwr + Vector2(-8, -14)
	elif atk == 2:
		s_bot = rwr + Vector2(22, -30); s_top = rwr + Vector2(-30, 42)
	else:
		s_bot = rwr + Vector2(2, 44); s_top = rwr + Vector2(5, -66)
	p.capsule(s_bot, s_top, 1.6, 1.6, Color(0.16, 0.11, 0.1))
	p.spec = 0.6
	for kk in 4:
		var rp := s_bot.lerp(s_top, 0.15 + kk * 0.22)
		p.ball(rp.x, rp.y, 2.0, 1.4, IRON)
	var dirv := (s_top - s_bot).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	var prev := s_top
	var steel := Color(0.5, 0.55, 0.52)
	for kk in 16:
		var t := float(kk + 1) / 16.0
		var pt := s_top + nrm * (t * 36.0) + dirv * (sin(t * PI * 0.9) * 10.0 - t * 7.0)
		p.capsule(prev, pt, lerpf(3.8, 0.5, t), lerpf(3.4, 0.4, t), steel)
		if kk % 4 == 1:
			p.erase_ellipse(pt.x - dirv.x * 2.8, pt.y - dirv.y * 2.8, 0.8, 0.8)
		prev = pt
		if kk % 5 == 0:
			glows.append([p.tp(pt), 2.2, SOUL, 0.35])
	p.spec = 0.0
	if cast:
		var oc := Vector2(cx, 8 + by)
		p.light_only(oc.x, oc.y + 12, 26, SOUL, 0.9)
		glows.append([p.tp(oc), 10.0, SOUL, 1.3])
		glows.append([p.tp(oc), 4.0, Color(0.9, 1, 0.9), 1.0])
	if atk == 2:
		for kk in 16:
			var t2 := float(kk) / 15.0
			glows.append([p.tp(Vector2(cx + 52, 20).lerp(Vector2(cx - 52, 112), t2) + Vector2(-sin(t2 * PI) * 16, 0)), 3.5, SOUL, 0.4])
	p.grime(Color(0.12, 0.1, 0.1), 0.4, 0.06, 0.12, 0.5)
	return glows


static func boss_corpse(p: Painter) -> Array:
	var glows: Array = []
	var armor := DARK_STEEL
	p.ellipse(64, 121, 50, 5.0, Color(0.04, 0.1, 0.06))
	p.cloth(PackedVector2Array([Vector2(16, 124), Vector2(30, 106), Vector2(92, 104), Vector2(114, 124)]), Color(0.16, 0.09, 0.18), 64, 48, 0.5, 0.4, -0.6)
	p.spec = 0.6
	p.ball(40, 112, 13, 7, armor)
	p.ball(88, 113, 12, 6.5, armor)
	p.ball(64, 113, 15, 7.5, armor)
	p.spec = 0.0
	for kk in 4:
		p.strand(PackedVector2Array([Vector2(53 + kk * 6, 104), Vector2(51 + kk * 6, 108), Vector2(52 + kk * 6, 112)]), 1.2, 0.9, BONE)
	_skull(p, 98, 103, 1.2, 1.5, Color(0.2, 0.4, 0.25), glows)
	glows.clear()
	p.capsule(Vector2(90, 96), Vector2(106, 96), 1.4, 1.4, GOLD.darkened(0.1))
	for sv in [-1.0, 1.0]:
		var s: float = sv
		p.strand(PackedVector2Array([Vector2(98 + s * 6, 96), Vector2(98 + s * 11, 89), Vector2(98 + s * 15, 83)]), 1.4, 0.5, BONE)
	p.capsule(Vector2(4, 124), Vector2(72, 120), 1.6, 1.6, Color(0.16, 0.11, 0.1))
	p.blade(Vector2(4, 124), Vector2(16, 102), 3.4, 0.5, Color(0.5, 0.55, 0.52))
	glows.append([p.tp(Vector2(64, 108)), 10.0, Color(0.3, 0.9, 0.4), 0.45])
	p.grime(Color(0.12, 0.1, 0.1), 0.4, 0.06, 0.12)
	return glows
