extends RefCounted
## Monster forge AURA layer: sparse elemental overlays stacked on top of everything, anchored on
## rig joints. Attached matter (frost shards, sores) follows the body transform; flames, smoke,
## drips and flies obey screen gravity, and they animate from frame to frame.

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const RP := preload("res://tools/art/monsters/rp.gd")

const NAMES := ["frost", "flame", "plague", "void"]

const ICE := Color(0.62, 0.83, 0.93)
const ICE_D := Color(0.3, 0.48, 0.64)
const RIME := Color(0.84, 0.94, 1.0)
const FLY := Color(0.05, 0.05, 0.04)
const SLIME := Color(0.42, 0.6, 0.1)
const SLIME_L := Color(0.72, 0.9, 0.3)
const SLIME_D := Color(0.2, 0.3, 0.05)
const VOID_OUT := Color(0.5, 0.2, 0.72)
const VOID_IN := Color(0.12, 0.03, 0.17)
const VOID_SPARK := Color(0.88, 0.66, 1.0)


static func draw(name: String, p: Painter, r: Dictionary) -> Array:
	var glows: Array = []
	match name:
		"frost":
			_frost(p, r, glows)
		"flame":
			_flame(p, r, glows)
		"plague":
			_plague(p, r, glows)
		"void":
			_void(p, r, glows)
	p.xf = r["xf"]
	return glows


static func _px(r: Dictionary, body_pt: Vector2) -> Vector2:
	return (r["xf"] as Transform2D) * body_pt


static func _head_pt(r: Dictionary, local: Vector2) -> Vector2:
	return (r["hxf"] as Transform2D) * local


static func _torso_pt(r: Dictionary, local: Vector2) -> Vector2:
	return (r["txf"] as Transform2D) * local


static func _screen_up(r: Dictionary) -> Vector2:
	return Vector2(0, -1)


# =============================================================================== frost

static func _shard(p: Painter, base: Vector2, d: Vector2, ln: float, w: float) -> void:
	var n := Vector2(-d.y, d.x)
	var tip := base + d * ln
	var mid := base + d * ln * 0.5
	RP.facet(p, PackedVector2Array([base, base - n * w, mid - n * w * 1.1, tip]), ICE, Vector3(-0.7, -0.5, 0.6))
	RP.facet(p, PackedVector2Array([base, tip, mid + n * w * 1.1, base + n * w]), ICE_D, Vector3(0.6, 0.2, 0.7))
	p.line(base - n * w * 0.4 + d * 0.5, tip - d * 0.6, RIME)


static func _frost(p: Painter, r: Dictionary, glows: Array) -> void:
	var f: int = r["frame"]
	var bxf: Transform2D = r["xf"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100
	p.xf = bxf
	var lsh: Vector2 = r["lsh"]
	var rsh: Vector2 = r["rsh"]
	var clusters := [
		[rsh + Vector2(1.0, -2.6), Vector2(0.45, -1.0), 5, 6.5],
		[lsh + Vector2(-1.0, -2.6), Vector2(-0.45, -1.0), 5, 6.5],
		[_head_pt(r, Vector2(-5.2, -3.2)), (r["hxf"] as Transform2D).basis_xform(Vector2(-1.0, -0.75)), 2, 3.0],
		[_head_pt(r, Vector2(5.2, -3.6)), (r["hxf"] as Transform2D).basis_xform(Vector2(1.0, -0.8)), 2, 3.2],
		[(r["rel"] as Vector2) + Vector2(1.6, 0), Vector2(1.0, -0.3), 2, 3.6],
		[(r["lel"] as Vector2) + Vector2(-1.6, 0), Vector2(-1.0, -0.3), 2, 3.6],
	]
	var tips: Array = []
	for cl in clusters:
		var base: Vector2 = cl[0]
		var dir: Vector2 = (cl[1] as Vector2).normalized()
		var cnt: int = cl[2]
		var size: float = cl[3]
		for i in cnt:
			var a := (float(i) - float(cnt - 1) * 0.5) * 0.42 + rng.randf_range(-0.15, 0.15)
			var d := dir.rotated(a)
			var ln := size * rng.randf_range(0.55, 1.0) * (1.15 if i == cnt / 2 else 1.0)
			var b := base + d.rotated(PI * 0.5) * rng.randf_range(-0.6, 0.6)
			_shard(p, b, d, ln, rng.randf_range(0.8, 1.25))
			tips.append(b + d * ln)
	# rime crust along the limbs, icicles under the forearms
	var down: Vector2 = r["down"]
	for e in [["l", -1.0], ["r", 1.0]]:
		var sd: String = e[0]
		var segs := [[r[sd + "sh"], r[sd + "el"]], [r[sd + "el"], r[sd + "hd"]]]
		for sg in segs:
			var a: Vector2 = sg[0]
			var b: Vector2 = sg[1]
			for j in 2:
				var q := a.lerp(b, rng.randf_range(0.15, 0.85))
				var side := (b - a).normalized().rotated(PI * 0.5)
				if side.y > 0.0:
					side = -side
				q += side * rng.randf_range(1.2, 2.2)
				RP.dot(p, q, RIME)
				RP.dot(p, q + (b - a).normalized(), ICE)
		var el: Vector2 = r[sd + "el"]
		var hd: Vector2 = r[sd + "hd"]
		for j in 3:
			var c := el.lerp(hd, 0.25 + j * 0.25)
			var n := Vector2(-down.y, down.x)
			var ln := 2.4 + float((j + f) % 3) * 0.6
			RP.facet(p, PackedVector2Array([c + n * 0.8 + down * 1.6, c - n * 0.8 + down * 1.6, c + down * (1.6 + ln)]), ICE, Vector3(-0.4, -0.3, 0.8))
	# twinkling glints (animated)
	p.xf = Transform2D.IDENTITY
	for i in 3:
		var t: Vector2 = tips[(i * 5 + f * 3) % tips.size()]
		var q := bxf * t
		p.put(int(q.x), int(q.y), Color(1, 1, 1))
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			p.put(int(q.x) + o.x, int(q.y) + o.y, RIME)
		glows.append([q, 3.0, Color(0.7, 0.9, 1.0), 0.8])
	# cold mist at the feet
	for i in 9:
		var mx := rng.randf_range(30.0, 66.0)
		var my := rng.randf_range(88.0, 93.0)
		var q := bxf * Vector2(mx, my)
		if (int(q.x) + int(q.y) + f) % 2 == 0:
			p.put(int(q.x), int(q.y), Color(0.7, 0.82, 0.9))


# =============================================================================== flame

static func _tongue(p: Painter, base: Vector2, hgt: float, w: float, lean: float, phase: float) -> void:
	## Screen-space flame tongue rising from base (bottom centre).
	var x0 := int(floor(base.x - w - absf(lean) - 2))
	var x1 := int(ceil(base.x + w + absf(lean) + 2))
	var y0 := int(floor(base.y - hgt - 1))
	var y1 := int(ceil(base.y + 1))
	for y in range(y0, y1 + 1):
		var t := (base.y - (y + 0.5)) / hgt
		if t < -0.08 or t > 1.0:
			continue
		var tt := clampf(t, 0.0, 1.0)
		var cx := base.x + lean * tt * tt + sin(tt * 7.0 + phase) * w * 0.3 * tt
		var hw := w * sqrt(maxf(1.0 - tt, 0.0)) * minf(1.0, tt * 3.0 + 0.55)
		for x in range(x0, x1 + 1):
			var u := absf(x + 0.5 - cx) / maxf(hw, 0.01)
			if u > 1.0:
				continue
			var heat := (1.0 - u) * (1.0 - tt * 0.75)
			var c: Color
			if heat > 0.62:
				c = Color(1.0, 0.95, 0.62)
			elif heat > 0.42:
				c = Color(1.0, 0.7, 0.2)
			elif heat > 0.22:
				c = Color(0.92, 0.36, 0.08)
			else:
				c = Color(0.55, 0.12, 0.04)
			p.put(x, y, c)


static func _flame(p: Painter, r: Dictionary, glows: Array) -> void:
	var f: int = r["frame"]
	var k: float = r["k"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9200 + f * 17
	# [anchor, tongues, height, width, spread]: big clustered fires on shoulders and crown,
	# smaller licks on the hands, forearms and flanks
	var anchors := [
		[r["rsh"], 3, 11.0, 2.6, 3.0], [r["lsh"], 3, 10.5, 2.6, 3.0],
		[_head_pt(r, Vector2(0, -5.0)), 3, 9.5, 2.3, 2.6],
		[r["rhd"], 2, 7.0, 2.0, 1.6], [r["lhd"], 2, 6.5, 2.0, 1.6],
		[(r["rel"] as Vector2).lerp(r["rhd"], 0.4), 1, 5.0, 1.6, 0.0], [(r["lel"] as Vector2).lerp(r["lhd"], 0.4), 1, 5.0, 1.6, 0.0],
		[_torso_pt(r, Vector2(-9.5, -12.0)), 2, 6.0, 1.8, 1.6], [_torso_pt(r, Vector2(9.0, -4.0)), 2, 5.5, 1.8, 1.6],
	]
	p.xf = Transform2D.IDENTITY
	var old_k := p.k
	p.k = 1.0
	for i in anchors.size():
		var a: Array = anchors[i]
		var c := _px(r, a[0])
		var n: int = a[1]
		var hgt0: float = float(a[2]) * k
		var w0: float = float(a[3]) * k
		var spread: float = float(a[4]) * k
		for t in n:
			var off := (float(t) - float(n - 1) * 0.5) * spread
			var centre := absf(off) < 0.1
			var base := c + Vector2(off + rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.8) + absf(off) * 0.3)
			var hgt := hgt0 * rng.randf_range(0.7, 1.15) * (1.0 if centre else 0.72)
			var w := w0 * rng.randf_range(0.85, 1.1) * (1.0 if centre else 0.8)
			_tongue(p, base, hgt, w, rng.randf_range(-1.6, 1.6) + off * 0.35, rng.randf() * TAU)
		if i < 5:
			glows.append([c + Vector2(0, -hgt0 * 0.35), hgt0 * 0.75, Color(1.0, 0.55, 0.15), 0.45])
	# embers drifting up
	for i in 8:
		var a: Array = anchors[rng.randi() % 5]
		var q := _px(r, a[0]) + Vector2(rng.randf_range(-5, 5), -rng.randf_range(9, 18) * k)
		p.put(int(q.x), int(q.y), Color(1.0, 0.75, 0.3))
		if i % 2 == 0:
			p.put(int(q.x), int(q.y) + 1, Color(0.9, 0.35, 0.08))
	p.k = old_k


# =============================================================================== plague

static func _plague(p: Painter, r: Dictionary, glows: Array) -> void:
	var f: int = r["frame"]
	var k: float = r["k"]
	var bxf: Transform2D = r["xf"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9300
	# festering sores stuck on the body (follow the body)
	p.xf = bxf
	var sores := [_torso_pt(r, Vector2(-5.5, -16.0)), _torso_pt(r, Vector2(6.5, -4.0)), (r["rsh"] as Vector2) + Vector2(-1.5, 2.5), (r["lhip"] as Vector2).lerp(r["lkn"], 0.4), (r["rel"] as Vector2).lerp(r["rhd"], 0.4)]
	for i in sores.size():
		var s: Vector2 = sores[i]
		var rad := 1.3 + float(i % 2) * 0.5
		RP.oval(p, s, rad + 0.6, rad + 0.4, SLIME_D)
		p.spec = 0.8
		RP.oval(p, s + Vector2(0, -0.2), rad, rad * 0.85, SLIME)
		p.spec = 0.0
		RP.dot(p, s + Vector2(-rad * 0.4, -rad * 0.5), SLIME_L.lightened(0.3))
	# drips running down (screen gravity, animated)
	p.xf = Transform2D.IDENTITY
	var drips := [_head_pt(r, Vector2(-1.2, 8.6)), r["rhd"], r["lhd"], _torso_pt(r, Vector2(6.5, -2.4)), _torso_pt(r, Vector2(-5.5, -14.0))]
	for i in drips.size():
		var q := _px(r, drips[i]) + Vector2(0, 1.0)
		var ln := (2.0 + float((f + i * 2) % 4) * 1.3) * k
		RP.dot(p, q, SLIME)
		p.line(q, q + Vector2(0, ln), SLIME)
		p.put(int(q.x) - 1, int(q.y), SLIME_D)
		var tip := q + Vector2(0, ln)
		p.ellipse(tip.x, tip.y + 0.6, 1.0, 1.2, SLIME)
		p.put(int(tip.x), int(tip.y), SLIME_L)
		if (f + i) % 3 == 0:
			var drop := tip + Vector2(0, 3.0 + float(i % 2) * 2.0)
			p.put(int(drop.x), int(drop.y), SLIME)
			p.put(int(drop.x), int(drop.y) + 1, SLIME_D)
	# flies buzzing around the head and torso
	var hc := _px(r, r["head"])
	var tc := _px(r, r["chest"])
	var frng := RandomNumberGenerator.new()
	frng.seed = 9310 + f * 29
	for i in 7:
		var centre := hc if i < 4 else tc
		var ang := frng.randf() * TAU
		var rad := frng.randf_range(8.0, 15.0) * k
		var q := centre + Vector2(cos(ang) * rad, sin(ang) * rad * 0.8)
		var x := int(q.x)
		var y := int(q.y)
		p.put(x, y, FLY)
		p.put(x + 1, y, FLY)
		p.put(x + (1 if i % 2 == 0 else 0), y - 1, Color(0.62, 0.66, 0.62))
	# sickly haze near the feet
	for i in 14:
		var q := _px(r, Vector2(rng.randf_range(32.0, 64.0), rng.randf_range(87.0, 93.0)))
		if (int(q.x) + int(q.y) + f) % 2 == 0:
			p.put(int(q.x), int(q.y), Color(0.32, 0.42, 0.1))
	glows.append([hc + Vector2(0, 10.0 * k), 9.0 * k, Color(0.5, 0.75, 0.15), 0.25])


# =============================================================================== void

static func _wisp(p: Painter, base: Vector2, ln: float, rad: float, phase: float, sway: float) -> Vector2:
	## Rising purple smoke tendril (screen space): dark core with a violet rim near the source,
	## breaking up into sparse motes toward the end. Returns its tip.
	var pts := PackedVector2Array()
	var n := 12
	for i in n:
		var t := float(i) / float(n - 1)
		pts.append(base + Vector2(sin(t * 5.0 + phase) * sway * (0.3 + t) + sway * 0.5 * t, -ln * t))
	var solid := PackedVector2Array()
	for i in 8:
		solid.append(pts[i])
	p.strand(solid, rad + 0.6, 0.5, VOID_OUT)
	p.strand(solid, rad, 0.25, VOID_IN)
	for i in range(8, n):
		if (i + int(phase * 3.0)) % 2 == 0:
			p.put(int(pts[i].x), int(pts[i].y), VOID_OUT.darkened(0.1 * float(i - 8)))
	return pts[n - 1]


static func _void(p: Painter, r: Dictionary, glows: Array) -> void:
	var f: int = r["frame"]
	var k: float = r["k"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9400 + f * 13
	p.xf = Transform2D.IDENTITY
	var old_k := p.k
	p.k = 1.0
	var anchors := [
		[(r["rsh"] as Vector2) + Vector2(1.5, -1.0), 16.0, 1.3], [(r["lsh"] as Vector2) + Vector2(-1.5, -1.0), 15.0, 1.3],
		[_head_pt(r, Vector2(0.5, -6.0)), 12.0, 0.9],
		[r["rhd"], 12.0, 1.1], [r["lhd"], 13.0, 1.1],
		[_torso_pt(r, Vector2(-10.0, -8.0)), 9.0, 0.9], [_torso_pt(r, Vector2(10.0, -2.0)), 9.0, 0.9],
	]
	for i in anchors.size():
		var a: Array = anchors[i]
		var base := _px(r, a[0]) + Vector2(rng.randf_range(-1.0, 1.0), 0)
		var ln: float = float(a[1]) * k * rng.randf_range(0.85, 1.15)
		var tip := _wisp(p, base, ln, float(a[2]) * k, float(f) * 0.9 + float(i) * 1.7, (2.2 if i % 2 == 0 else -2.2) * k)
		if i < 5:
			p.put(int(tip.x), int(tip.y), VOID_SPARK)
			glows.append([tip, 2.4, Color(0.7, 0.35, 1.0), 0.6])
	# orbiting void motes
	var tc := _px(r, r["chest"])
	for i in 5:
		var ang := float(i) / 5.0 * TAU + float(f) * 0.55
		var q := tc + Vector2(cos(ang) * 17.0, sin(ang) * 8.0 - 4.0) * k
		p.put(int(q.x), int(q.y), VOID_IN)
		p.put(int(q.x) + 1, int(q.y), VOID_OUT)
		p.put(int(q.x), int(q.y) - 1, VOID_SPARK)
		glows.append([q, 2.2, Color(0.6, 0.3, 0.95), 0.5])
	p.k = old_k
