extends RefCounted
## NPCs: the travelling black-market goblin merchant (world sprite + HUD portrait).
## Original design, realistic gritty pixel style (same Painter "real" mode as the enemies).

const Painter := preload("res://tools/art/painter.gd")

const SKIN := Color(0.5, 0.52, 0.29)
const SKIN_DARK := Color(0.36, 0.38, 0.2)
const CLOAK := Color(0.17, 0.15, 0.13)
const CANVAS := Color(0.36, 0.28, 0.18)
const LEATHER := Color(0.27, 0.18, 0.11)
const LINEN := Color(0.42, 0.39, 0.3)
const BONE := Color(0.68, 0.62, 0.5)
const GOLD := Color(0.78, 0.6, 0.22)
const IRON := Color(0.3, 0.29, 0.3)
const AMBER := Color(1.0, 0.68, 0.2)
const LAMP := Color(1.0, 0.72, 0.32)
const VOID := Color(0.05, 0.03, 0.03)


# =============================================================================== shared head

static func _head(p: Painter, cx: float, cy: float, s: float, expr: String, glows: Array) -> void:
	## Goblin head in design units; s scales the whole head. expr: "sly", "greet", "laugh".
	# long pointed ears (drooping slightly), with a brass ring on the right one
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		var top := Vector2(cx + sd * 6.0 * s, cy - 3.0 * s)
		var bot := Vector2(cx + sd * 5.5 * s, cy + 2.6 * s)
		var tip := Vector2(cx + sd * 19.0 * s, cy - 5.5 * s)
		p.cyl_poly(PackedVector2Array([top, tip + Vector2(0, -0.6 * s), tip + Vector2(0, 0.8 * s), bot]), SKIN, cx + sd * 12.0 * s, 7.0 * s, -0.2)
		p.poly(PackedVector2Array([top.lerp(bot, 0.3) + Vector2(sd * 1.5 * s, 0), tip.lerp(top, 0.25) + Vector2(0, 0.8 * s), top.lerp(bot, 0.75) + Vector2(sd * 1.5 * s, 0)]), Color(0.4, 0.27, 0.22))
		p.line(top.lerp(tip, 0.55), top.lerp(tip, 0.55) + Vector2(sd * 0.8 * s, 1.6 * s), SKIN_DARK.darkened(0.4))
		if sd > 0:
			p.spec = 0.9
			var ring := tip.lerp(bot, 0.42) + Vector2(0, 1.8 * s)
			p.capsule(ring + Vector2(-0.9 * s, 0), ring + Vector2(0.9 * s, 0.9 * s), 0.6 * s, 0.6 * s, GOLD)
			p.spec = 0.0
	# skull, cheekbones, narrow jaw, pointed chin
	p.ball(cx, cy - 0.8 * s, 7.8 * s, 7.2 * s, SKIN)
	p.ball(cx, cy + 3.4 * s, 5.8 * s, 4.6 * s, SKIN)
	p.ball(cx - 4.2 * s, cy + 1.8 * s, 2.3 * s, 1.9 * s, SKIN.lightened(0.05))
	p.ball(cx + 4.2 * s, cy + 1.8 * s, 2.3 * s, 1.9 * s, SKIN)
	p.ball(cx + 0.3 * s, cy + 8.2 * s, 2.0 * s, 1.7 * s, SKIN.darkened(0.03))
	# deep-set slanted eyes under a heavy brow
	var squint := expr == "laugh"
	for sv in [-1.0, 1.0]:
		var sd2: float = sv
		var ex := cx + sd2 * 3.2 * s
		var ey := cy - 0.2 * s
		p.ball(ex, ey, 2.1 * s, 1.5 * s, SKIN_DARK.darkened(0.4))
		if squint:
			p.line(Vector2(ex - 1.7 * s, ey + 0.4 * s), Vector2(ex, ey - 0.5 * s), VOID, maxf(0.8 * s, 1.0))
			p.line(Vector2(ex, ey - 0.5 * s), Vector2(ex + 1.7 * s, ey + 0.4 * s), VOID, maxf(0.8 * s, 1.0))
			p.line(Vector2(ex - 1.4 * s, ey + 1.4 * s), Vector2(ex + 1.4 * s, ey + 1.4 * s), SKIN_DARK.darkened(0.3), maxf(0.5 * s, 1.0))
		else:
			p.ellipse(ex, ey + 0.1 * s, 1.35 * s, 0.95 * s, VOID)
			p.ellipse(ex + sd2 * -0.25 * s, ey + 0.1 * s, 0.8 * s, 0.75 * s, AMBER)
			var e := p.tp(Vector2(ex + sd2 * -0.25 * s, ey + 0.1 * s))
			p.put(int(e.x), int(e.y), Color(1, 0.96, 0.72))
			glows.append([e, 1.6 * s, AMBER, 0.75])
			# slanted upper lid: inner corner low, outer corner high
			p.line(Vector2(cx + sd2 * 1.6 * s, ey - 0.2 * s), Vector2(cx + sd2 * 4.8 * s, ey - 1.2 * s), SKIN_DARK.darkened(0.5), maxf(0.6 * s, 1.0))
		p.strand(PackedVector2Array([Vector2(cx + sd2 * 5.8 * s, cy - 2.4 * s), Vector2(cx + sd2 * 3.4 * s, cy - 2.2 * s + (0.8 * s if squint else 0.0)), Vector2(cx + sd2 * 0.9 * s, cy - 1.0 * s)]), 1.2 * s, 0.8 * s, SKIN_DARK)
	# big hooked nose with a shadowed side and nostril
	p.strand(PackedVector2Array([Vector2(cx, cy - 1.2 * s), Vector2(cx + 1.2 * s, cy + 2.2 * s), Vector2(cx + 1.1 * s, cy + 4.4 * s), Vector2(cx - 0.2 * s, cy + 5.0 * s)]), 1.7 * s, 1.5 * s, SKIN.lightened(0.06))
	p.ball(cx + 0.9 * s, cy + 4.0 * s, 1.7 * s, 1.4 * s, SKIN.lightened(0.08))
	p.line(Vector2(cx + 2.3 * s, cy + 0.6 * s), Vector2(cx + 2.4 * s, cy + 4.2 * s), SKIN_DARK.darkened(0.3), maxf(0.5 * s, 1.0))
	p.ball(cx - 0.4 * s, cy + 4.9 * s, 0.6 * s, 0.4 * s, VOID)
	# nasolabial creases
	p.line(Vector2(cx - 2.0 * s, cy + 4.0 * s), Vector2(cx - 4.6 * s, cy + 6.2 * s), SKIN_DARK.darkened(0.25), maxf(0.5 * s, 1.0))
	p.line(Vector2(cx + 2.6 * s, cy + 4.0 * s), Vector2(cx + 4.8 * s, cy + 6.0 * s), SKIN_DARK.darkened(0.25), maxf(0.5 * s, 1.0))
	# sly wide grin, corners pulled up, crooked pointy teeth
	var my := cy + 6.2 * s
	var open := 0.4
	if expr == "greet":
		open = 1.2
	elif expr == "laugh":
		open = 2.4
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		var x := cx + lerpf(-5.6, 5.6, t) * s
		var corner := pow(absf(t - 0.5) * 2.0, 3.0) * 1.9 * s
		upper.append(Vector2(x, my - corner + sin(t * PI) * 0.4 * s))
		lower.append(Vector2(x, my - corner + sin(t * PI) * (0.6 + open) * s))
	var mouth := PackedVector2Array(upper)
	for i in range(lower.size() - 1, -1, -1):
		mouth.append(lower[i])
	p.poly(mouth, Color(0.15, 0.05, 0.05))
	p.strand(lower, maxf(0.5 * s, 0.6), maxf(0.5 * s, 0.6), Color(0.36, 0.3, 0.16))
	var tooth := Color(0.74, 0.68, 0.44)
	for i in [1, 2, 4, 5, 7, 9]:
		var tp0: Vector2 = upper[i]
		var lean := (0.25 if i % 2 == 0 else -0.2) * s
		var th := (1.0 + 0.35 * float(i % 3)) * s
		p.poly(PackedVector2Array([tp0 + Vector2(-0.55 * s, 0), tp0 + Vector2(0.55 * s, 0), tp0 + Vector2(lean, th)]), tooth.darkened(0.12 * float(i % 3)))
	if open > 1.0:
		for i in [3, 6, 8]:
			var bp: Vector2 = lower[i]
			p.poly(PackedVector2Array([bp + Vector2(-0.5 * s, 0), bp + Vector2(0.5 * s, 0), bp + Vector2(0.1 * s, -1.1 * s)]), tooth.darkened(0.1))
	# warts and blemishes
	for w in [Vector2(-5.4, -3.4), Vector2(4.8, 3.0), Vector2(2.2, -5.6), Vector2(-3.4, 5.0), Vector2(5.8, -1.6), Vector2(1.8, 3.0)]:
		var wv: Vector2 = w
		p.ball(cx + wv.x * s, cy + wv.y * s, 0.6 * s, 0.55 * s, SKIN_DARK.lightened(0.06))

# =============================================================================== world sprite

static func _hand(p: Painter, at: Vector2, dir: Vector2, spread: float, length: float) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	p.ball(at.x, at.y, 1.9, 1.7, SKIN)
	for f in 4:
		var off := (float(f) - 1.5) * spread
		var b0 := at + d * 1.2 + n * off * 0.6
		var tip := b0 + d * length + n * off * 0.5
		p.strand(PackedVector2Array([b0, b0.lerp(tip, 0.55) + n * 0.2, tip]), 0.6, 0.45, SKIN)
		p.tput(tip.x, tip.y, Color(0.2, 0.17, 0.1))
	p.capsule(at + n * 1.5, at + n * 2.6 + d * 2.0, 0.6, 0.5, SKIN)


static func goblin_sheet() -> Image:
	var frames: Array = []
	for f in 4:
		var p := Painter.new(96, 96, 900 + f)
		p.set_real(1.0)
		p.grain = 0.12
		var glows: Array = []
		var cx := 48.0
		var bob := 1.0 if f == 1 else 0.0
		var sway := 2.0 if f == 1 else (-1.0 if f == 3 else 0.0)
		# ---- the huge overstuffed backpack (behind): bulging sack, bedroll, side satchel
		p.ball(cx, 57 + bob, 21.0, 24.0, CANVAS)
		p.ball(cx - 9, 47 + bob, 12.0, 11.0, CANVAS.lightened(0.04))
		p.ball(cx + 10, 49 + bob, 12.0, 12.0, CANVAS.darkened(0.04))
		for i in 4:
			var fx := cx - 14 + i * 9.0
			p.line(Vector2(fx, 40 + bob), Vector2(fx + 2.0, 74), CANVAS.darkened(0.4))
		p.flat_poly(PackedVector2Array([Vector2(cx - 19, 52 + bob), Vector2(cx - 12, 51 + bob), Vector2(cx - 11, 60 + bob), Vector2(cx - 18, 61 + bob)]), LEATHER, Vector3(-0.2, 0, 1))
		for i in 5:
			p.tput(cx - 18 + i * 1.6, 51.5 + bob, Color(0.6, 0.55, 0.4))
		p.ball(cx + 21, 64 + bob, 6.0, 8.5, LEATHER)
		p.capsule(Vector2(cx + 16, 59 + bob), Vector2(cx + 26, 59 + bob), 0.9, 0.9, LEATHER.darkened(0.4))
		p.capsule(Vector2(cx - 18, 34 + bob), Vector2(cx + 18, 34 + bob), 5.0, 5.0, Color(0.32, 0.3, 0.26))
		for bx in [-12.0, 0.0, 12.0]:
			p.line(Vector2(cx + float(bx), 30 + bob), Vector2(cx + float(bx) + 0.5, 39 + bob), Color(0.2, 0.18, 0.15))
		p.capsule(Vector2(cx - 8, 29.5 + bob), Vector2(cx - 8, 38.5 + bob), 0.9, 0.9, LEATHER)
		p.capsule(Vector2(cx + 9, 29.5 + bob), Vector2(cx + 9, 38.5 + bob), 0.9, 0.9, LEATHER)
		# rope coil on the left flank, pot hanging below
		for i in 14:
			var a := float(i) / 14.0 * TAU
			p.ball(cx - 22 + cos(a) * 4.5, 66 + bob + sin(a) * 3.6, 1.2, 1.2, Color(0.52, 0.43, 0.27))
		p.line(Vector2(cx - 26, 72 + bob), Vector2(cx - 27, 76 + bob), Color(0.4, 0.33, 0.2))
		p.ball(cx - 27, 79 + bob, 3.0, 2.6, Color(0.42, 0.25, 0.16))
		# wares heaped on top: scrolls, skull, clay pot, bottles, a sword hilt
		p.capsule(Vector2(cx - 17, 31 + bob), Vector2(cx - 5, 25 + bob), 2.0, 2.0, Color(0.72, 0.66, 0.5))
		p.capsule(Vector2(cx - 11, 29 + bob), Vector2(cx - 11, 27 + bob), 2.2, 2.2, Color(0.5, 0.1, 0.08))
		p.capsule(Vector2(cx - 16, 27 + bob), Vector2(cx - 6, 21 + bob), 1.7, 1.7, Color(0.66, 0.6, 0.45))
		p.ball(cx + 5, 26 + bob, 5.0, 4.6, Color(0.45, 0.27, 0.17))
		p.ellipse(cx + 5, 22.2 + bob, 3.0, 1.0, Color(0.12, 0.07, 0.05))
		p.ball(cx - 4, 27 + bob, 3.6, 3.3, BONE)
		p.ellipse(cx - 5.2, 27 + bob, 0.9, 1.0, VOID)
		p.ellipse(cx - 2.8, 27 + bob, 0.9, 1.0, VOID)
		p.spec = 0.9
		p.capsule(Vector2(cx + 12, 31 + bob), Vector2(cx + 13, 20 + bob), 1.9, 1.5, Color(0.2, 0.36, 0.22))
		p.capsule(Vector2(cx + 16, 33 + bob), Vector2(cx + 17, 24 + bob), 1.6, 1.3, Color(0.22, 0.25, 0.45))
		p.spec = 0.0
		p.capsule(Vector2(cx + 13, 20 + bob), Vector2(cx + 13, 18 + bob), 1.0, 1.0, Color(0.42, 0.3, 0.2))
		p.capsule(Vector2(cx + 17, 24 + bob), Vector2(cx + 17, 22 + bob), 0.9, 0.9, Color(0.42, 0.3, 0.2))
		p.capsule(Vector2(cx - 21, 36 + bob), Vector2(cx - 27, 18 + bob), 0.9, 0.9, Color(0.3, 0.2, 0.14))
		p.capsule(Vector2(cx - 24, 25 + bob), Vector2(cx - 30, 26 + bob), 0.8, 0.8, IRON)
		# lantern pole + hanging lantern
		p.strand(PackedVector2Array([Vector2(cx + 20, 40 + bob), Vector2(cx + 23, 22 + bob), Vector2(cx + 25, 12 + bob), Vector2(cx + 31, 11 + bob)]), 1.1, 0.9, Color(0.3, 0.21, 0.13))
		var lx := cx + 31 + sway
		var ly := 19.0 + bob
		p.line(Vector2(cx + 31, 11 + bob), Vector2(lx, ly - 4), IRON)
		p.ball(lx, ly - 3.6, 2.4, 1.0, IRON)
		p.rect(lx - 2.6, ly - 3, 5.2, 6.4, Color(1.0, 0.78, 0.4))
		p.rect(lx - 1.2, ly - 1.8, 2.4, 3.6, Color(1.0, 0.95, 0.75))
		for bx in [-2.8, 0.0, 2.6]:
			p.line(Vector2(lx + float(bx), ly - 3.2), Vector2(lx + float(bx), ly + 3.4), IRON)
		p.ball(lx, ly + 3.8, 2.6, 0.9, IRON)
		# ---- legs: short, bent, bow-legged, rag-wrapped shins, bare clawed toes
		for sv in [-1.0, 1.0]:
			var sd: float = sv
			var hip := Vector2(cx + sd * 4.0, 77 + bob * 0.5)
			var knee := Vector2(cx + sd * 7.5, 84)
			var ankle := Vector2(cx + sd * 6.5, 90.5)
			p.capsule(hip, knee, 3.4, 2.7, SKIN)
			p.ball(knee.x, knee.y, 2.7, 2.4, SKIN_DARK)
			p.capsule(knee, ankle, 2.5, 2.0, Color(0.36, 0.3, 0.22))
			p.line(knee + Vector2(-2.4, 2), knee + Vector2(2.4, 3), Color(0.25, 0.2, 0.14))
			p.line(knee + Vector2(-2.2, 4.5), knee + Vector2(2.2, 5.5), Color(0.25, 0.2, 0.14))
			p.ball(ankle.x + sd * 1.2, 92.5, 4.0, 1.8, SKIN)
			for t in 3:
				p.tput(ankle.x + sd * 1.2 - 2.4 + t * 2.4, 94, Color(0.18, 0.15, 0.08))
		# ---- belly, belt, pouches
		p.ball(cx, 66 + bob, 7.5, 8.5, LINEN)
		p.capsule(Vector2(cx - 8, 70 + bob), Vector2(cx + 8, 70 + bob), 1.2, 1.2, LEATHER)
		p.ball(cx + 5, 73 + bob, 2.6, 3.0, LEATHER.lightened(0.05))
		p.ball(cx - 5.5, 73 + bob, 2.2, 2.5, Color(0.35, 0.26, 0.15))
		p.spec = 0.8
		p.rect(cx - 0.8, 69.2 + bob, 1.8, 1.8, GOLD)
		p.spec = 0.0
		# ---- ragged hooded cloak, open at the front
		for sv in [-1.0, 1.0]:
			var sd3: float = sv
			var panel := PackedVector2Array([Vector2(cx + sd3 * 4, 51 + bob), Vector2(cx + sd3 * 11, 51 + bob), Vector2(cx + sd3 * 14, 64 + bob), Vector2(cx + sd3 * 15, 79)])
			for i in 5:
				panel.append(Vector2(cx + sd3 * (15 - i * 2.4), 81 - (i % 2) * 3.0))
			panel.append(Vector2(cx + sd3 * 5, 64 + bob))
			p.cloth(panel, CLOAK, cx + sd3 * 9.0, 7.0, 0.9, 0.35)
		# pack straps over the shoulders
		for sv in [-1.0, 1.0]:
			var sd4: float = sv
			p.capsule(Vector2(cx + sd4 * 8.5, 50 + bob), Vector2(cx + sd4 * 10.5, 60 + bob), 1.3, 1.3, LEATHER)
		# ---- arms & hands
		var lsh := Vector2(cx - 9, 53 + bob)
		var rsh := Vector2(cx + 9, 53 + bob)
		var lel := Vector2(cx - 12, 61 + bob)
		var rel := Vector2(cx + 12, 61 + bob)
		var lha := Vector2(cx - 4, 65 + bob)
		var rha := Vector2(cx + 4, 65 + bob)
		if f == 2:
			rel = Vector2(cx + 15, 51); rha = Vector2(cx + 16, 41)
		elif f == 3:
			lha = Vector2(cx - 2.2, 60); rha = Vector2(cx + 2.2, 60)
			lel = Vector2(cx - 12, 60); rel = Vector2(cx + 12, 60)
		for arm in [[lsh, lel, lha, -1.0], [rsh, rel, rha, 1.0]]:
			var sh: Vector2 = arm[0]
			var el: Vector2 = arm[1]
			var hd: Vector2 = arm[2]
			p.capsule(sh, el, 2.6, 2.2, CLOAK.lightened(0.05))
			p.capsule(el, hd, 1.6, 1.3, SKIN)
			p.ball(el.x, el.y, 1.8, 1.6, SKIN_DARK)
		if f == 2:
			_hand(p, rha, Vector2(0.15, -1.0), 1.4, 4.2)
			_hand(p, lha, (lha - lel).normalized(), 0.8, 3.2)
		elif f == 3:
			_hand(p, lha, Vector2(1.0, -0.3), 0.7, 3.0)
			_hand(p, rha, Vector2(-1.0, -0.2), 0.7, 3.0)
			p.spec = 1.0
			p.ball(cx, 57.5, 2.0, 2.0, GOLD)
			p.spec = 0.0
		else:
			_hand(p, lha, (lha - lel).normalized(), 0.8, 3.2)
			_hand(p, rha, (rha - rel).normalized(), 0.8, 3.2)
		# ---- hood + head
		var hy := 44.0 + bob
		p.ball(cx, hy - 0.5, 11.5, 10.0, CLOAK)
		p.cloth(PackedVector2Array([Vector2(cx - 12, hy + 2), Vector2(cx - 9, hy - 9), Vector2(cx, hy - 12), Vector2(cx + 9, hy - 9), Vector2(cx + 12, hy + 2), Vector2(cx + 10, hy + 9), Vector2(cx - 10, hy + 9)]), CLOAK, cx, 12.0, 0.7, 0.3)
		_head(p, cx, hy + 0.5, 1.0, "greet" if f == 2 else ("laugh" if f == 3 else "sly"), glows)
		p.grime(Color(0.1, 0.08, 0.05), 0.4, 0.09, 0.15, 0.6)
		p.rim(0.38, 0.1)
		# warm lantern light on the pack and the goblin's right side
		p.light_only(lx, ly, 20, Color(1.0, 0.6, 0.25), 0.45)
		glows.append([p.tp(Vector2(lx, ly)), 4.0, LAMP, 0.6])
		if f == 3:
			var cg := p.tp(Vector2(cx + 0.8, 56.6))
			for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2)]:
				var ov: Vector2i = o
				p.put(int(cg.x) + ov.x, int(cg.y) + ov.y, Color(1, 0.97, 0.8))
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1], g[2], g[3])
		p.harden_alpha(0.5)
		frames.append(p.img)
	return Painter.strip(frames)


# =============================================================================== HUD portrait

static func goblin_portrait() -> Image:
	var frames: Array = []
	for f in 2:
		var p := Painter.new(64, 64, 950 + f)
		p.set_real(1.0)
		p.grain = 0.09
		p.dither = 0.15
		# painted background: dark, warm lantern glow from the upper right
		for y in 64:
			for x in 64:
				var d := Vector2(x, y).distance_to(Vector2(58, 8)) / 46.0
				var g := clampf(1.0 - d, 0.0, 1.0)
				var c := Color(0.06, 0.045, 0.035).lerp(Color(0.32, 0.18, 0.07), g * g)
				p.img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		var glows: Array = []
		var cx := 32.0
		var cy := 30.0
		# shoulders: ragged cloak + pack straps
		p.cloth(PackedVector2Array([Vector2(-4, 64), Vector2(-2, 50), Vector2(14, 44), Vector2(50, 44), Vector2(66, 50), Vector2(68, 64)]), CLOAK, 32, 32, 0.45, 0.35)
		p.capsule(Vector2(14, 46), Vector2(10, 64), 2.4, 2.4, LEATHER)
		p.capsule(Vector2(50, 46), Vector2(54, 64), 2.4, 2.4, LEATHER)
		p.ball(32, 62, 9, 5, LINEN)
		# hood behind the head
		p.ball(cx, cy - 1, 21, 19, CLOAK)
		p.ellipse(cx, cy + 2, 17, 17, Color(0.05, 0.04, 0.035))
		_head(p, cx, cy, 2.05, "laugh" if f == 1 else "sly", glows)
		# hood rim over the brow
		p.strand(PackedVector2Array([Vector2(cx - 18, cy + 10), Vector2(cx - 17, cy - 6), Vector2(cx - 9, cy - 15), Vector2(cx, cy - 17), Vector2(cx + 9, cy - 15), Vector2(cx + 17, cy - 6), Vector2(cx + 18, cy + 10)]), 2.4, 2.4, CLOAK.lightened(0.04))
		if f == 1:
			# greedy hand holding up a gold coin
			p.ball(52, 56, 6, 5.5, SKIN)
			for k in 3:
				p.capsule(Vector2(49 + k * 3, 52), Vector2(48 + k * 3, 47), 1.4, 1.2, SKIN)
			p.spec = 1.0
			p.ball(50.5, 45, 3.6, 3.6, GOLD)
			p.ellipse(50.5, 45, 2.2, 2.2, GOLD.darkened(0.25))
			p.spec = 0.0
			for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
				var ov: Vector2i = o
				p.put(48 + ov.x, 43 + ov.y, Color(1, 0.97, 0.82))
		p.light_only(58, 8, 40, Color(1.0, 0.55, 0.2), 0.3)
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1], g[2], g[3])
		p.harden_alpha(0.0)
		frames.append(p.img)
	return Painter.strip(frames)
