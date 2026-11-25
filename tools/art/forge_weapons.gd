extends RefCounted
## Weapon forge: base weapons painted in a NEUTRAL palette, each with a matching mask sheet for
## the runtime tint shader:
##     rgb = base.rgb * mix(1, material_tint, mask.r) + glow_colour * mask.b * pulse
## Mask: R = 255 material (blades, heads, guards, pommels, bands, bow limbs, prod...), painted in
## hue-free grey from dark grey to near white; B = 255 enchantment glow (gems, orbs, rune inlays),
## painted mid grey with a white core so the additive colour stays readable instead of clipping to
## white; black = untouched (hands, gauntlets, sleeves, leather, wood hafts, strings, arrows).
## Each frame is drawn as tagged layers: the pixels a layer changes take that layer's class, so
## anything drawn later (gauntlet, hand, arrow) clears the mask where it covers the weapon.
## Framing, pixel scale, hands and frame meaning match weapons_fp.gd (axe / staff / bow sheets).

const Painter := preload("res://tools/art/painter.gd")
const W := preload("res://tools/art/weapons_fp.gd")
const Items := preload("res://tools/art/items.gd")

const WARRIOR := ["axe", "greataxe", "sword", "mace", "warhammer"]
const MAGE := ["staff", "scepter", "bonestaff"]
const HUNTER := ["longbow", "recurve", "crossbow"]
const ALL := ["axe", "greataxe", "sword", "mace", "warhammer", "staff", "scepter", "bonestaff", "longbow", "recurve", "crossbow"]

const NONE := 0
const MAT := 1
const GLOW := 2

## drawing colours (hue is stripped from material / glow pixels afterwards)
const STEEL_N := Color(0.6, 0.6, 0.6)
const LIMB_N := Color(0.58, 0.58, 0.58)
const GROOVE := Color(0.08, 0.08, 0.08)
const GLOW_LO := Color(0.34, 0.34, 0.34)
const GLOW_MID := Color(0.58, 0.58, 0.58)
const GLOW_HI := Color(0.94, 0.94, 0.94)
## halo haze around mage foci: dark grey so base + glow stays a saturated colour
const HALO := Color(0.2, 0.2, 0.2)
## material luminance remap: l' = MAT_LIFT + l * MAT_GAIN (spreads steel from dark grey to near white)
const MAT_GAIN := 1.15
const MAT_LIFT := 0.03


class Tagger extends RefCounted:
	## Per-pixel class map filled by diffing the frame before / after each drawing layer.
	var img: Image
	var cls := PackedByteArray()
	var snap := PackedInt32Array()

	func _init(image: Image) -> void:
		img = image
		cls.resize(image.get_width() * image.get_height())
		cls.fill(0)

	func begin() -> void:
		snap = img.get_data().to_int32_array()

	func end(c: int) -> void:
		var cur := img.get_data().to_int32_array()
		for i in cur.size():
			if cur[i] != snap[i]:
				cls[i] = c


static func build(kind: String) -> Array:
	## [sheet, mask] for one forge base weapon.
	if kind in WARRIOR:
		return _warrior(kind)
	if kind in MAGE:
		return _mage(kind)
	if kind == "crossbow":
		return _crossbow()
	return _bow(kind == "recurve")


# =============================================================================== shared

static func _resolve(p: Painter, t: Tagger) -> Image:
	## Strips hue from material / glow pixels (material luminance remapped) and returns the mask.
	var mask := Image.create(p.w, p.h, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 1))
	var red := Color(1, 0, 0, 1)
	var blue := Color(0, 0, 1, 1)
	for y in p.h:
		var row := y * p.w
		for x in p.w:
			var c: int = t.cls[row + x]
			if c == NONE:
				continue
			var px := p.img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var l := px.r * 0.299 + px.g * 0.587 + px.b * 0.114
			if c == MAT:
				l = clampf(MAT_LIFT + l * MAT_GAIN, 0.0, 1.0)
				mask.set_pixel(x, y, red)
			else:
				mask.set_pixel(x, y, blue)
			p.img.set_pixel(x, y, Color(l, l, l, px.a))
	return mask


static func _pts(loc: Callable, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for e in arr:
		var q: Array = e
		out.append(loc.call(float(q[0]), float(q[1])))
	return out


## Rune strokes [a0, b0, a1, b1]: a = across the glyph, b = along its stem (b > 0 = glyph top).
const RUNES := [
	[[0, -4, 0, 4], [0, 4, -2.6, 1.4], [0, 4, 2.6, 1.4]],
	[[0, -4, 0, 4], [0, 0.6, -2.6, 3.8], [0, 0.6, 2.6, 3.8]],
	[[0, -4, 2.6, -0.8], [2.6, -0.8, 0, 2.4], [0, 2.4, -2.6, -0.8], [-2.6, -0.8, 0, -4], [0, 2.4, -2.4, 4.6], [0, 2.4, 2.4, 4.6]],
	[[-1.4, -4, -1.4, 4], [-1.4, 2.4, 1.8, 0.2], [1.8, 0.2, -1.4, -2.0]],
	[[-2.2, -4, -2.2, 4], [2.2, -4, 2.2, 4], [-2.2, 4, 2.2, -4], [-2.2, -4, 2.2, 4]],
	[[-1.4, -4, -1.4, 4], [-1.4, 4, 2.2, 2.0], [-1.4, 1.0, 2.2, -1.0]],
	[[-1.6, 4, 1.6, 1.4], [1.6, 1.4, -1.6, -1.4], [-1.6, -1.4, 1.6, -4]],
]


static func _glyph(p: Painter, it: Array, c: Color, th: float) -> void:
	var cen: Vector2 = it[0]
	var up: Vector2 = it[1]
	var sz: float = it[2]
	var kind: int = it[3]
	var right := Vector2(-up.y, up.x)
	for st in RUNES[kind % RUNES.size()]:
		var s: Array = st
		var a: Vector2 = cen + right * (float(s[0]) * sz) + up * (float(s[1]) * sz)
		var b: Vector2 = cen + right * (float(s[2]) * sz) + up * (float(s[3]) * sz)
		p.line(a, b, c, th)


static func _runes(p: Painter, t: Tagger, items: Array, groove: float, ink: float) -> void:
	## Engraved runes: dark groove (material) then a glowing inlay with a white core (glow).
	## items: [centre, up direction, size, kind].
	t.begin()
	for it in items:
		_glyph(p, it, GROOVE, groove)
	t.end(MAT)
	t.begin()
	for it in items:
		_glyph(p, it, GLOW_LO, ink)
	for it in items:
		_glyph(p, it, GLOW_HI, ink * 0.4)
	t.end(GLOW)


static func _crystal(p: Painter, c: Vector2, d: Vector2, n: Vector2, w: float, h: float) -> void:
	## Faceted gem standing along d: dark-grey rim facets, mid-grey table, white core.
	var lit := n if n.dot(Vector2(-0.6, -0.8)) > 0.0 else -n
	var top := c + d * h
	var bot := c - d * h * 0.85
	var s_l := c + d * h * 0.3 + lit * w
	var s_d := c + d * h * 0.3 - lit * w
	var b_l := c - d * h * 0.4 + lit * w * 0.9
	var b_d := c - d * h * 0.4 - lit * w * 0.9
	p.poly(PackedVector2Array([top, s_l, b_l, bot, b_d, s_d]), GLOW_LO)
	var ci := c + d * h * 0.05
	p.poly(PackedVector2Array([top, s_l, b_l, ci]), Color(0.47, 0.47, 0.47))
	var t0 := c + d * h * 0.55
	var t1 := c + d * h * 0.18 + lit * w * 0.52
	var t2 := c - d * h * 0.3 + lit * w * 0.45
	var t3 := c - d * h * 0.52
	var t4 := c - d * h * 0.3 - lit * w * 0.45
	var t5 := c + d * h * 0.18 - lit * w * 0.52
	p.poly(PackedVector2Array([t0, t1, t2, t3, t4, t5]), GLOW_MID)
	var edge := Color(0.22, 0.22, 0.22)
	for pair in [[top, t0], [s_l, t1], [b_l, t2], [bot, t3], [b_d, t4], [s_d, t5]]:
		var pr: Array = pair
		p.line(pr[0], pr[1], edge, 0.35)
	p.line(c - d * h * 0.18 + lit * w * 0.1, c + d * h * 0.32 + lit * w * 0.1, GLOW_HI, w * 0.32)
	p.line(top + (s_l - top) * 0.2, top + (s_l - top) * 0.65, Color(1, 1, 1), 0.4)


static func _halo(p: Painter, c: Vector2, r: float, strength: float) -> void:
	## Soft haze on EMPTY pixels only (mid grey, alpha falloff): the shader's additive glow colours
	## it without bleeding onto the weapon pixels around the gem.
	var cc := p.tp(c)
	var rp := r * p.k
	for y in range(maxi(int(cc.y - rp), 0), mini(int(cc.y + rp) + 1, p.h)):
		for x in range(maxi(int(cc.x - rp), 0), mini(int(cc.x + rp) + 1, p.w)):
			var dd := Vector2(x + 0.5, y + 0.5).distance_to(cc) / rp
			if dd >= 1.0:
				continue
			var o := p.img.get_pixel(x, y)
			if o.a >= 0.5:
				continue
			var a := minf((1.0 - dd) * (1.0 - dd) * strength, 0.48)
			if a > o.a + 0.004:
				p.img.set_pixel(x, y, Color(HALO.r, HALO.g, HALO.b, a))


static func _tube(p: Painter, pts: PackedVector2Array, radii: PackedFloat32Array, base: Color) -> void:
	## Smooth tapered tube along a polyline in pixel space (k = 1): every pixel is shaded from its
	## nearest segment, so there are no overlapping capsule caps (no scalloping on long curves).
	var npx := p.w * p.h
	var q := PackedFloat32Array()
	q.resize(npx)
	q.fill(2.0)
	var nx := PackedFloat32Array()
	nx.resize(npx)
	var ny := PackedFloat32Array()
	ny.resize(npx)
	var lo := Vector2i(p.w, p.h)
	var hi := Vector2i(-1, -1)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var r := maxf(radii[i], radii[i + 1])
		var x0 := maxi(int(floor(minf(a.x, b.x) - r)), 0)
		var x1 := mini(int(ceil(maxf(a.x, b.x) + r)), p.w - 1)
		var y0 := maxi(int(floor(minf(a.y, b.y) - r)), 0)
		var y1 := mini(int(ceil(maxf(a.y, b.y) + r)), p.h - 1)
		lo = Vector2i(mini(lo.x, x0), mini(lo.y, y0))
		hi = Vector2i(maxi(hi.x, x1), maxi(hi.y, y1))
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.0001)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var pp := Vector2(x + 0.5, y + 0.5)
				var t := clampf((pp - a).dot(ab) / len2, 0.0, 1.0)
				var rr := maxf(lerpf(radii[i], radii[i + 1], t), 0.5)
				var dv := (pp - (a + ab * t)) / rr
				var dl := dv.length()
				var idx := y * p.w + x
				if dl < q[idx]:
					q[idx] = dl
					nx[idx] = dv.x
					ny[idx] = dv.y
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var idx2 := y * p.w + x
			if q[idx2] > 1.0:
				continue
			var n2 := Vector2(nx[idx2], ny[idx2])
			var nz := sqrt(maxf(1.0 - n2.length_squared(), 0.0))
			p.put(x, y, p.col(base, p.shade_value(Vector3(n2.x, n2.y, nz), x, y)))


static func _sparkles(p: Painter, c: Vector2, radius: float, count: int, seed_value: int, phase: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in count:
		var a := float(k) / float(count) * TAU + phase + rng.randf_range(-0.2, 0.2)
		var rr := radius * rng.randf_range(0.8, 1.15)
		var sp := c + Vector2(cos(a), sin(a)) * rr
		p.ellipse(sp.x, sp.y, 0.75, 0.75, GLOW_MID)
		p.ellipse(sp.x, sp.y, 0.35, 0.35, GLOW_HI)


# =============================================================================== warrior
## Same four poses as axe.png: 0 idle, 1 wind-up, 2 strike (smear), 3 follow-through.

const WAR_POSES := [
	[Vector2(98, 82), Vector2(68, 22)],
	[Vector2(116, 42), Vector2(138, -34)],
	[Vector2(70, 90), Vector2(20, 40)],
	[Vector2(12, 118), Vector2(-40, 90)],
]
## per weapon: head reach from the fist (design units), per-frame swing-angle tweaks and a
## follow-through pull-back. Long weapons lean further back in the wind-up; big heads sink lower
## and slide back along the haft in the follow-through (the fist is below the screen there), so
## they leave through the bottom of the screen instead of being cut by the frame's left edge.
const WAR_SPEC := {
	"axe": [67.0, [0.0, 0.0, 0.0, 0.0], 0.0],
	"greataxe": [74.0, [0.0, 0.2, 0.0, -0.23], 18.0],
	"sword": [90.0, [0.0, 0.33, 0.0, 0.22], 0.0],
	"mace": [54.0, [0.0, 0.0, 0.0, 0.0], 0.0],
	"warhammer": [72.0, [0.0, 0.2, 0.0, -0.23], 16.0],
}


static func _warrior(kind: String) -> Array:
	var spec: Array = WAR_SPEC[kind]
	var reach: float = spec[0]
	var rot: Array = spec[1]
	var frames: Array = []
	var masks: Array = []
	for i in 4:
		var p := W._new(2000 + i + WARRIOR.find(kind) * 10)
		var t := Tagger.new(p.img)
		var grip: Vector2 = WAR_POSES[i][0]
		var aim: Vector2 = WAR_POSES[i][1]
		var d := (aim - grip).normalized().rotated(float(rot[i]))
		var n := Vector2(-d.y, d.x)
		if n.x > 0.0:
			n = -n
		var wgrip := grip - d * (float(spec[2]) if i == 3 else 0.0)
		if i == 2:
			_smear(p, reach)
		match kind:
			"axe":
				_axe(p, t, wgrip, d, n)
			"greataxe":
				_greataxe(p, t, wgrip, d, n)
			"sword":
				_sword(p, t, wgrip, d, n)
			"mace":
				_mace(p, t, wgrip, d, n)
			_:
				_warhammer(p, t, wgrip, d, n)
		t.begin()
		W._gauntlet(p, grip, d, Vector2(30, 32))
		t.end(NONE)
		W._finish(p)
		masks.append(_resolve(p, t))
		frames.append(p.img)
	return [Painter.strip(frames), Painter.strip(masks)]


static func _smear(p: Painter, reach: float) -> void:
	## Motion smear of the strike frame (semi-transparent, untinted).
	var sc := reach / 67.0
	for kk in 60:
		var tt := float(kk) / 59.0
		var a := lerpf(-0.35, 1.9, tt)
		var pc := Vector2(76, 118) + Vector2(cos(a + PI), sin(a + PI)) * Vector2(84, 94) * sc
		p.glow(pc.x, pc.y, 6.0 + tt * 5.0, Color(0.55, 0.57, 0.62), 0.1 + tt * 0.12)


static func _axe(p: Painter, t: Tagger, grip: Vector2, d: Vector2, n: Vector2) -> void:
	## Bearded war axe, same footprint as axe.png: wood haft, steel head, three runes on the cheek.
	var head := grip + d * 67.0
	t.begin()
	W._wood_haft(p, grip - d * 40.0, head + d * 10.0, 3.6)
	W._leather_wrap(p, grip - d * 12.0, grip + d * 16.0, 4.0, 9)
	t.end(NONE)
	var s := 1.3
	var loc := func(u: float, v: float) -> Vector2: return head + (d * u + n * v) * s
	t.begin()
	p.spec = 0.5
	for sv in [1.0, -1.0]:
		var o: Vector2 = n * (3.2 * float(sv))
		p.capsule(head - d * 16.0 + o, head + d * 4.0 + o, 0.9, 0.9, STEEL_N.darkened(0.2))
	p.shininess = 26.0
	p.grad_poly(_pts(loc, [[5, 2.5], [5, 7], [10.5, 13], [12.5, 23], [6.5, 27.5], [-4, 28.8], [-14, 27], [-24, 21], [-17, 14], [-9, 8.5], [-5, 2.5]]), STEEL_N, head, n, 29.0 * s, 0.36, 0.86, 7.0)
	p.grad_poly(_pts(loc, [[12.5, 23], [6.5, 27.5], [-4, 28.8], [-14, 27], [-24, 21], [-21, 19.5], [-13, 23.8], [-4, 25.4], [5.5, 24.2], [10.5, 20.5]]), STEEL_N, loc.call(0, 23), n, 6.0 * s, 1.0, 1.32, 3.0)
	p.line(loc.call(9.5, 20.8), loc.call(-19, 20.6), STEEL_N.darkened(0.55), 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for kk in 7:
		var uu := rng.randf_range(-14, 6)
		var vv := rng.randf_range(11, 20)
		p.line(loc.call(uu, vv), loc.call(uu + rng.randf_range(2, 5), vv + rng.randf_range(-1.0, 1.0)), STEEL_N.darkened(0.3) if kk % 2 == 0 else STEEL_N.lightened(0.25), 0.5)
	p.spec = 0.6
	p.flat_poly(_pts(loc, [[6, 3], [6, -3], [-7, -3], [-7, 3]]), STEEL_N.darkened(0.25), Vector3(0.3, 0.2, 1))
	p.flat_poly(_pts(loc, [[3.5, -3], [3.5, -7.5], [-4.5, -7.5], [-4.5, -3]]), STEEL_N.darkened(0.1), Vector3(0.4, 0.1, 1))
	p.capsule(loc.call(7.5, 3.5), loc.call(7.5, -3.5), 1.1, 1.1, STEEL_N.lightened(0.15))
	p.capsule(loc.call(-8.2, 3.5), loc.call(-8.2, -3.5), 0.9, 0.9, STEEL_N.lightened(0.05))
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	_runes(p, t, [[loc.call(-11.0, 15.2), d, 0.85, 3], [loc.call(-4.0, 15.6), d, 0.85, 1], [loc.call(3.0, 15.2), d, 0.85, 5]], 2.2, 1.1)


const BIT := [[8, 4], [6, 9], [12, 16], [19.5, 23.5], [24, 31], [16, 34.5], [6, 36.5], [-6, 36.5], [-16, 34.5], [-24, 31], [-19.5, 23.5], [-12, 16], [-6, 9], [-8, 4]]
const BIT_EDGE := [[24, 31], [16, 34.5], [6, 36.5], [-6, 36.5], [-16, 34.5], [-24, 31], [-21.5, 29.2], [-15, 31.8], [-6, 33.4], [6, 33.4], [15, 31.8], [21.5, 29.2]]


static func _greataxe(p: Painter, t: Tagger, grip: Vector2, d: Vector2, n: Vector2) -> void:
	## Huge double-bitted greataxe: two crescent bits, top spike, long wrapped haft.
	var head := grip + d * 74.0
	t.begin()
	W._wood_haft(p, grip - d * 44.0, head + d * 12.0, 4.0)
	W._leather_wrap(p, grip - d * 14.0, grip + d * 22.0, 4.3, 12)
	t.end(NONE)
	t.begin()
	p.spec = 0.6
	for b in [30.0, 37.0]:
		var bp: Vector2 = grip + d * float(b)
		p.capsule(bp - n * 5.0, bp + n * 5.0, 1.4, 1.4, STEEL_N.darkened(0.1))
	var pm := grip - d * 46.0
	p.ball(pm.x, pm.y, 4.8, 4.8, STEEL_N)
	for sv in [1.0, -1.0]:
		var o: Vector2 = n * (3.8 * float(sv))
		p.capsule(head - d * 24.0 + o, head - d * 8.0 + o, 1.0, 1.0, STEEL_N.darkened(0.2))
	p.grad_poly(PackedVector2Array([head + d * 10.0 + n * 3.4, head + d * 26.0, head + d * 10.0 - n * 3.4]), STEEL_N, head + d * 10.0 + n * 3.4, -n, 6.8, 1.2, 0.55, 3.0)
	for sv in [1.0, -1.0]:
		var side: float = sv
		var sc := 1.12 if side > 0.0 else 0.98
		var sn: Vector2 = n * side
		var loc := func(u: float, v: float) -> Vector2: return head + (d * u + sn * v) * sc
		p.shininess = 26.0
		p.grad_poly(_pts(loc, BIT), STEEL_N, head, sn, 37.0 * sc, 0.34, 0.86, 8.0)
		p.grad_poly(_pts(loc, BIT_EDGE), STEEL_N, loc.call(0, 31), sn, 6.0 * sc, 1.0, 1.32, 3.0)
		p.line(loc.call(20.5, 28.6), loc.call(6, 32.6), STEEL_N.darkened(0.45), 0.45)
		p.line(loc.call(6, 32.6), loc.call(-6, 32.6), STEEL_N.darkened(0.45), 0.45)
		p.line(loc.call(-6, 32.6), loc.call(-20.5, 28.6), STEEL_N.darkened(0.45), 0.45)
	p.flat_poly(PackedVector2Array([head + d * 13.0 + n * 5.6, head + d * 13.0 - n * 5.6, head - d * 13.0 - n * 5.6, head - d * 13.0 + n * 5.6]), STEEL_N.darkened(0.3), Vector3(0.3, 0.2, 1))
	for b2 in [10.5, -10.5]:
		var bp2: Vector2 = head + d * float(b2)
		p.capsule(bp2 - n * 6.2, bp2 + n * 6.2, 1.4, 1.4, STEEL_N.lightened(0.1))
	for rv in [head + n * 3.0, head - n * 3.0]:
		var r: Vector2 = rv
		p.ball(r.x, r.y, 1.1, 1.1, STEEL_N.lightened(0.25))
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	var lf := func(u: float, v: float) -> Vector2: return head + (d * u + n * v) * 1.12
	var lb := func(u: float, v: float) -> Vector2: return head + (d * u - n * v) * 0.98
	_runes(p, t, [[lf.call(-9.0, 21.0), d, 0.95, 0], [lf.call(0.0, 22.0), d, 0.95, 2], [lf.call(9.0, 21.0), d, 0.95, 6], [lb.call(0.0, 21.5), d, 0.9, 4]], 2.3, 1.15)


static func _sword(p: Painter, t: Tagger, grip: Vector2, d: Vector2, n: Vector2) -> void:
	## Longsword: long straight ridged blade with a rune-filled fuller, crossguard, wheel pommel.
	var bl := func(u: float, v: float) -> Vector2: return grip + d * u + n * v
	t.begin()
	W._leather_wrap(p, grip - d * 10.5, grip + d * 10.0, 3.1, 8)
	t.end(NONE)
	t.begin()
	p.spec = 0.7
	p.shininess = 24.0
	var lit_n := n.dot(Vector2(-0.6, -0.8)) > 0.0
	var hi0 := 0.95
	var hi1 := 0.78
	var lo0 := 0.52
	var lo1 := 0.4
	p.grad_poly(_pts(bl, [[12, 0], [12, 4.3], [19, 4.5], [68, 3.5], [81, 2.5], [91, 0]]), STEEL_N, grip + d * 12.0, d, 79.0, hi0 if lit_n else lo0, hi1 if lit_n else lo1, 6.0)
	p.grad_poly(_pts(bl, [[12, 0], [12, -4.3], [19, -4.5], [68, -3.5], [81, -2.5], [91, 0]]), STEEL_N, grip + d * 12.0, d, 79.0, lo0 if lit_n else hi0, lo1 if lit_n else hi1, 6.0)
	p.grad_poly(_pts(bl, [[15, 4.45], [68, 3.5], [81, 2.5], [91, 0], [87.5, 0.45], [80, 1.65], [68, 2.6], [15, 3.5]]), STEEL_N, grip, d, 90.0, 1.32 if lit_n else 0.76, 1.15 if lit_n else 0.66, 3.0)
	p.grad_poly(_pts(bl, [[15, -4.45], [68, -3.5], [81, -2.5], [91, 0], [87.5, -0.45], [80, -1.65], [68, -2.6], [15, -3.5]]), STEEL_N, grip, d, 90.0, 0.76 if lit_n else 1.32, 0.66 if lit_n else 1.15, 3.0)
	p.line(bl.call(63, 0), bl.call(89, 0), STEEL_N.lightened(0.3), 0.45)
	p.capsule(bl.call(16, 0), bl.call(62, 0), 1.3, 1.0, STEEL_N.darkened(0.6))
	var g0 := grip + d * 11.5
	p.strand(PackedVector2Array([g0 - n * 15.0 + d * 2.4, g0 - n * 7.0 + d * 0.3, g0 + n * 7.0 + d * 0.3, g0 + n * 15.0 + d * 2.4]), 2.0, 2.0, STEEL_N)
	for sv in [1.0, -1.0]:
		var e: Vector2 = g0 + n * (15.6 * float(sv)) + d * 2.7
		p.ball(e.x, e.y, 2.5, 2.5, STEEL_N.lightened(0.05))
	p.flat_poly(PackedVector2Array([g0 - n * 4.0 - d * 1.6, g0 + n * 4.0 - d * 1.6, g0 + n * 2.8 + d * 4.6, g0 - n * 2.8 + d * 4.6]), STEEL_N.darkened(0.1), Vector3(0.25, -0.2, 1))
	var pm := grip - d * 13.8
	p.ball(pm.x, pm.y, 4.4, 4.0, STEEL_N)
	var pk := grip - d * 17.8
	p.ball(pk.x, pk.y, 1.8, 1.6, STEEL_N.lightened(0.1))
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	var items: Array = []
	var kinds := [0, 3, 1, 5, 6]
	for r in 5:
		items.append([bl.call(20.0 + r * 8.6, 0.0), d, 0.42, kinds[r]])
	_runes(p, t, items, 1.4, 0.75)


static func _mace(p: Painter, t: Tagger, grip: Vector2, d: Vector2, n: Vector2) -> void:
	## Flanged mace: steel shaft with rings, gothic flanges, glowing slits between the front flanges.
	var head := grip + d * 54.0
	t.begin()
	p.spec = 0.7
	p.shininess = 24.0
	p.capsule(grip - d * 13.0, head - d * 9.0, 2.2, 2.0, STEEL_N.darkened(0.05))
	for r in [19.0, 27.0, 35.0]:
		var rp: Vector2 = grip + d * float(r)
		p.capsule(rp - n * 2.9, rp + n * 2.9, 0.9, 0.9, STEEL_N.lightened(0.08))
	var pm := grip - d * 15.0
	p.ball(pm.x, pm.y, 3.8, 3.6, STEEL_N)
	var pk := grip - d * 18.6
	p.ball(pk.x, pk.y, 1.6, 1.6, STEEL_N.lightened(0.1))
	t.end(MAT)
	t.begin()
	W._leather_wrap(p, grip - d * 11.5, grip + d * 12.0, 3.0, 9)
	t.end(NONE)
	var loc := func(u: float, v: float) -> Vector2: return head + d * u + n * v
	var lit_side := 1.0 if n.dot(Vector2(-0.6, -0.8)) > 0.0 else -1.0
	t.begin()
	p.capsule(loc.call(-15.5, -4.2), loc.call(-15.5, 4.2), 1.3, 1.3, STEEL_N.darkened(0.05))
	p.capsule(loc.call(-13.2, -5.8), loc.call(-13.2, 5.8), 1.9, 1.9, STEEL_N)
	# dark core showing between the flanges
	p.capsule(loc.call(-3.5, 0), loc.call(3.5, 0), 10.2, 10.2, STEEL_N.darkened(0.72))
	# flanges as lozenges seen from the front: outer pair in profile (with spurs), inner pair
	# turned ~50 deg, the face-on one in the middle
	for layer in 3:
		var vc: float = [12.2, 7.2, 0.0][layer]
		var w: float = [1.7, 2.3, 2.7][layer]
		for sv in ([1.0, -1.0] if layer < 2 else [1.0]):
			var side: float = sv
			var lit := side == lit_side
			var c := vc * side
			var pts := [[-13.5, c], [-10.5, c + w], [10.5, c + w], [14.0, c], [10.5, c - w], [-10.5, c - w]]
			if layer == 0:
				var o := w * side
				pts = [[-13.5, c], [-10.5, c + w], [-3.5, c + o], [-0.5, c + o + 3.6 * side], [2.5, c + o], [10.5, c + w], [14.0, c], [10.5, c - w], [-10.5, c - w]]
				if side < 0.0:
					pts = [[-13.5, c], [-10.5, c + w], [10.5, c + w], [14.0, c], [10.5, c - w], [2.5, c - w], [-0.5, c - w - 3.6], [-3.5, c - w], [-10.5, c - w]]
			var a0: float = [0.62, 0.86, 1.15][layer] + (0.12 if lit else -0.12) * (1.0 if layer < 2 else 0.0)
			var a1: float = a0 - 0.32
			p.grad_poly(_pts(loc, pts), STEEL_N, loc.call(14.0, 0), -d, 27.5, a0, a1, 5.0)
			p.line(loc.call(-10.5, c), loc.call(10.5, c), STEEL_N.lightened(0.5 if layer == 2 else 0.3), 0.4)
	p.grad_poly(PackedVector2Array([loc.call(13.0, 2.6), loc.call(19.5, 0), loc.call(13.0, -2.6)]), STEEL_N, loc.call(13.0, 2.6), -n, 5.2, 1.2, 0.55, 3.0)
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	t.begin()
	for sv3 in [1.0, -1.0]:
		var s3: float = sv3
		p.line(loc.call(-9.0, 3.85 * s3), loc.call(9.0, 3.85 * s3), GLOW_LO, 1.1)
		p.line(loc.call(-7.5, 3.85 * s3), loc.call(7.5, 3.85 * s3), GLOW_HI, 0.42)
	t.end(GLOW)


static func _warhammer(p: Painter, t: Tagger, grip: Vector2, d: Vector2, n: Vector2) -> void:
	## Two-handed warhammer: big chamfered block head with a rune on each cheek, top spike.
	var head := grip + d * 72.0
	t.begin()
	W._wood_haft(p, grip - d * 44.0, head + d * 6.0, 4.1)
	W._leather_wrap(p, grip - d * 14.0, grip + d * 24.0, 4.4, 12)
	t.end(NONE)
	var loc := func(u: float, v: float) -> Vector2: return head + d * u + n * v
	t.begin()
	p.spec = 0.6
	p.shininess = 24.0
	for b in [32.0, 40.0]:
		var bp: Vector2 = grip + d * float(b)
		p.capsule(bp - n * 5.2, bp + n * 5.2, 1.4, 1.4, STEEL_N.darkened(0.1))
	p.grad_poly(PackedVector2Array([grip - d * 44.0 + n * 4.0, grip - d * 53.0, grip - d * 44.0 - n * 4.0]), STEEL_N, grip - d * 44.0 + n * 4.0, -n, 8.0, 1.1, 0.55, 3.0)
	p.capsule(grip - d * 44.0 - n * 4.6, grip - d * 44.0 + n * 4.6, 1.5, 1.5, STEEL_N)
	for sv in [1.0, -1.0]:
		var o: Vector2 = n * (4.0 * float(sv))
		p.capsule(head - d * 28.0 + o, head - d * 9.0 + o, 1.05, 1.05, STEEL_N.darkened(0.2))
	p.grad_poly(PackedVector2Array([loc.call(10, 3.6), loc.call(23, 0), loc.call(10, -3.6)]), STEEL_N, loc.call(10, 3.6), -n, 7.2, 1.2, 0.55, 3.0)
	p.grad_poly(_pts(loc, [[-8.5, -12], [-11, -16.5], [-11, -19.5], [11, -19.5], [11, -16.5], [8.5, -12], [8.5, 12], [11, 16.5], [11, 19.5], [-11, 19.5], [-11, 16.5], [-8.5, 12]]), STEEL_N, loc.call(11, 0), -d, 22.0, 0.88, 0.38, 6.0)
	p.grad_poly(_pts(loc, [[11, -19.5], [11, -16.5], [8.5, -12], [8.5, 12], [11, 16.5], [11, 19.5], [9.4, 19.5], [9.4, 16.9], [7.0, 12], [7.0, -12], [9.4, -16.9], [9.4, -19.5]]), STEEL_N, loc.call(11, 0), -d, 4.0, 1.3, 1.05, 2.0)
	for sv in [1.0, -1.0]:
		var side: float = sv
		var fl := func(u: float, v: float) -> Vector2: return head + d * u + n * (v * side)
		var lit := (n * side).dot(Vector2(-0.6, -0.8)) > 0.0
		p.grad_poly(_pts(fl, [[11, 19.5], [11.6, 22.2], [-11.6, 22.2], [-11, 19.5]]), STEEL_N, fl.call(11, 20), -d, 23.0, 1.1 if lit else 0.7, 0.75 if lit else 0.4, 4.0)
		for k in 3:
			var uu := -6.0 + k * 6.0
			p.line(fl.call(uu, 19.7), fl.call(uu, 22.0), STEEL_N.darkened(0.6), 0.5)
	p.flat_poly(_pts(loc, [[12, -5.2], [12, 5.2], [-12, 5.2], [-12, -5.2]]), STEEL_N.darkened(0.2), Vector3(0.3, 0.2, 1))
	p.line(loc.call(12, -5.2), loc.call(-12, -5.2), STEEL_N.darkened(0.6), 0.5)
	p.line(loc.call(12, 5.2), loc.call(-12, 5.2), STEEL_N.darkened(0.6), 0.5)
	for rv in [[8.0, 0.0], [-8.0, 0.0], [0.0, 2.8], [0.0, -2.8]]:
		var r: Array = rv
		var rp: Vector2 = loc.call(float(r[0]), float(r[1]))
		p.ball(rp.x, rp.y, 1.2, 1.2, STEEL_N.lightened(0.2))
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	_runes(p, t, [[loc.call(0.0, 12.4), d, 1.0, 0], [loc.call(0.0, -12.4), d, 1.0, 4]], 2.3, 1.15)


# =============================================================================== mage
## Same four poses as staff.png: 0 idle, 1 cast A, 2 cast B, 3 frost / raised (same pose as 1).

const MAGE_POSES := [
	[Vector2(96, 78), Vector2(76, 12), 0.7],
	[Vector2(86, 74), Vector2(62, 8), 1.5],
	[Vector2(93, 77), Vector2(72, 11), 0.45],
	[Vector2(86, 74), Vector2(62, 8), 1.5],
]


static func _mage(kind: String) -> Array:
	var frames: Array = []
	var masks: Array = []
	for i in 4:
		var p := W._new(2100 + i + MAGE.find(kind) * 10)
		var t := Tagger.new(p.img)
		var grip: Vector2 = MAGE_POSES[i][0]
		var top: Vector2 = MAGE_POSES[i][1]
		var power: float = MAGE_POSES[i][2]
		var d := (top - grip).normalized()
		var n := Vector2(-d.y, d.x)
		var focus: Vector2
		match kind:
			"staff":
				focus = _staff(p, t, grip, top, d, n)
			"scepter":
				focus = _scepter(p, t, grip, d, n, i)
			_:
				focus = _bonestaff(p, t, grip, top, d, n)
		t.begin()
		_mage_hand(p, grip, d, n)
		t.end(NONE)
		W._finish(p)
		t.begin()
		_halo(p, focus, 10.0 + power * 6.0, 0.18 + power * 0.13)
		if power > 1.0:
			_sparkles(p, focus, 17.0, 10, 900 + i * 7, float(i) * 0.9)
		t.end(GLOW)
		masks.append(_resolve(p, t))
		frames.append(p.img)
	return [Painter.strip(frames), Painter.strip(masks)]


static func _mage_hand(p: Painter, grip: Vector2, d: Vector2, n: Vector2) -> void:
	## Robe sleeve and bare hand around the shaft, exactly as staff.png.
	var sleeve := Color(0.17, 0.17, 0.32)
	p.capsule(grip + Vector2(2, 6), grip + Vector2(64, 66), 12.5, 19.0, sleeve)
	for fl in 4:
		var f0 := grip + Vector2(-4 + fl * 5.0, 12 + fl * 1.5)
		p.line(f0, f0 + Vector2(22, 24), sleeve.darkened(0.45), 0.7)
	p.strand(PackedVector2Array([grip + Vector2(-10, 10), grip + Vector2(0, 2), grip + Vector2(12, -4)]), 1.6, 1.6, W.GOLD.darkened(0.25))
	p.ball(grip.x + 4, grip.y + 3, 9.0, 8.5, W.SKIN)
	for f in 4:
		var fp := grip + d * (-6.0 + f * 4.0) - n * 0.5
		p.capsule(fp + n * 8.5, fp - n * 3.0, 2.7, 2.3, W.SKIN)
		p.ball(fp.x + n.x * 2.5, fp.y + n.y * 2.5, 2.4, 2.2, W.SKIN.lightened(0.05))
		p.line(fp + n * 5.0 - d * 1.6, fp + n * 5.0 + d * 1.6, W.SKIN.darkened(0.45), 0.5)
	p.capsule(grip + n * 8.0 - d * 8.0, grip - d * 9.5 - n * 2.0, 2.8, 2.4, W.SKIN)


static func _staff(p: Painter, t: Tagger, grip: Vector2, top: Vector2, d: Vector2, n: Vector2) -> Vector2:
	## Gnarled wooden staff; a steel setting (cup, prongs, bands) holds a faceted gem.
	var wood := Color(0.27, 0.19, 0.13)
	t.begin()
	var pts := PackedVector2Array()
	for kk in 14:
		var tt := float(kk) / 13.0
		pts.append((grip - d * 44.0).lerp(top - d * 9.0, tt) + n * (sin(tt * 13.0) * 1.4 + sin(tt * 5.0) * 0.8))
	p.strand(pts, 5.0, 3.4, wood, 0.25)
	for kk in 4:
		var tk := 0.25 + kk * 0.18
		var bp := (grip - d * 44.0).lerp(top - d * 9.0, tk)
		p.ball(bp.x + n.x * 2.2, bp.y + n.y * 2.2, 2.4, 1.8, wood.darkened(0.1))
		p.line(bp - n * 2.5 - d * 4.0, bp + n * 1.5 + d * 6.0, wood.darkened(0.5), 0.5)
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		p.strand(PackedVector2Array([top - d * 12.0 + n * sd * 2.5, top - d * 3.5 + n * sd * 8.8, top + d * 6.5 + n * sd * 8.2, top + d * 12.5 + n * sd * 3.6]), 2.3, 0.7, wood.lightened(0.04))
	t.end(NONE)
	var gem := top + d * 2.5
	t.begin()
	p.spec = 0.8
	p.shininess = 24.0
	p.capsule(top - d * 15.0 - n * 4.9, top - d * 15.0 + n * 4.9, 1.8, 1.8, STEEL_N)
	p.capsule(top - d * 19.0 - n * 4.3, top - d * 19.0 + n * 4.3, 1.3, 1.3, STEEL_N.darkened(0.1))
	p.grad_poly(PackedVector2Array([top - d * 6.5 - n * 5.4, top - d * 6.5 + n * 5.4, top - d * 11.5 + n * 2.8, top - d * 11.5 - n * 2.8]), STEEL_N, top - d * 6.5, -d, 5.0, 1.15, 0.55, 3.0)
	p.capsule(top - d * 6.5 - n * 5.4, top - d * 6.5 + n * 5.4, 0.8, 0.8, STEEL_N.lightened(0.1))
	t.end(MAT)
	t.begin()
	_crystal(p, gem, d, n, 5.6, 10.5)
	t.end(GLOW)
	t.begin()
	p.spec = 0.8
	for sv in [-1.0, 1.0]:
		var sd: float = sv
		p.strand(PackedVector2Array([top - d * 6.5 + n * sd * 5.0, gem - d * 3.0 + n * sd * 6.0, gem + d * 2.0 + n * sd * 6.0, gem + d * 4.6 + n * sd * 4.4]), 0.95, 0.5, STEEL_N.lightened(0.05))
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	return gem


static func _scepter(p: Painter, t: Tagger, grip: Vector2, d: Vector2, n: Vector2, frame: int) -> Vector2:
	## Short steel scepter: spiral-grooved shaft, flared collar, caged glowing orb, finial.
	var orb := grip + d * 47.0
	t.begin()
	p.spec = 0.85
	p.shininess = 26.0
	p.capsule(grip - d * 12.0, orb - d * 14.0, 2.3, 2.7, STEEL_N)
	var prev := grip + d * 10.0
	for k in 30:
		var tk := float(k + 1) / 30.0
		var q := (grip + d * 10.0).lerp(orb - d * 16.0, tk) + n * sin(tk * 22.0) * 2.0
		p.line(prev, q, STEEL_N.darkened(0.55), 0.45)
		prev = q
	for r in [10.0, 21.0, 31.0]:
		var rp: Vector2 = grip + d * float(r)
		p.capsule(rp - n * 3.4, rp + n * 3.4, 1.1, 1.1, STEEL_N.lightened(0.1))
	var pm := grip - d * 13.5
	p.ball(pm.x, pm.y, 3.9, 3.9, STEEL_N)
	var pk := grip - d * 17.0
	p.ball(pk.x, pk.y, 1.7, 1.7, STEEL_N.lightened(0.1))
	p.grad_poly(PackedVector2Array([orb - d * 16.5 - n * 2.9, orb - d * 16.5 + n * 2.9, orb - d * 8.0 + n * 7.6, orb - d * 8.0 - n * 7.6]), STEEL_N, orb - d * 16.5, d, 8.5, 0.6, 1.15, 4.0)
	p.capsule(orb - d * 8.0 - n * 7.8, orb - d * 8.0 + n * 7.8, 1.3, 1.3, STEEL_N.lightened(0.05))
	t.end(MAT)
	t.begin()
	var op := p.tp(orb)
	Items.orb(p, op.x, op.y, 6.4 * p.k, float(frame) * 1.3, [GLOW_LO, Color(0.5, 0.5, 0.5), Color(0.72, 0.72, 0.72), GLOW_HI])
	t.end(GLOW)
	t.begin()
	p.spec = 0.85
	for v in [-8.8, -3.4, 3.4, 8.8]:
		var vv: float = v
		p.strand(PackedVector2Array([orb - d * 8.0 + n * vv * 0.8, orb - d * 3.0 + n * vv, orb + d * 3.5 + n * vv * 0.92, orb + d * 8.5 + n * vv * 0.45, orb + d * 10.5]), 1.1, 0.8, STEEL_N.lightened(0.05))
	var fp := orb + d * 11.0
	p.ball(fp.x, fp.y, 2.4, 2.4, STEEL_N)
	p.grad_poly(PackedVector2Array([orb + d * 12.0 + n * 1.8, orb + d * 18.0, orb + d * 12.0 - n * 1.8]), STEEL_N, orb + d * 12.0 + n * 1.8, -n, 3.6, 1.2, 0.6, 2.0)
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	return orb


static func _bonestaff(p: Painter, t: Tagger, grip: Vector2, top: Vector2, d: Vector2, n: Vector2) -> Vector2:
	## Bone staff: knobbed bone shaft and antler crown (material), natural skull with glowing
	## eyes, gem cradled between the antlers.
	var sk := top - d * 3.0
	var a := grip - d * 46.0
	var b := sk - d * 6.5
	t.begin()
	p.spec = 0.3
	var js := [0.0, 0.27, 0.52, 0.76, 1.0]
	for j in 4:
		var p0 := a.lerp(b, float(js[j])) + n * (0.6 if j % 2 == 0 else -0.6)
		var p1 := a.lerp(b, float(js[j + 1])) + n * (-0.6 if j % 2 == 0 else 0.6)
		p.capsule(p0, p1, 2.6, 2.2, STEEL_N)
	for j in range(1, 4):
		var jp := a.lerp(b, float(js[j]))
		for sv in [-1.0, 1.0]:
			var kp: Vector2 = jp + n * (1.6 * float(sv))
			p.ball(kp.x, kp.y, 2.5, 2.2, STEEL_N.lightened(0.06))
		p.line(jp - n * 3.2, jp + n * 3.2, STEEL_N.darkened(0.5), 0.45)
	for sv in [-1.0, 1.0]:
		var s: float = sv
		var m := func(u: float, v: float) -> Vector2: return sk + d * u + n * (v * s)
		p.strand(_pts(m, [[1, 3.5], [4, 8], [10, 11.5], [17, 10.5], [22, 7.5]]), 2.3, 0.8, STEEL_N)
		p.strand(_pts(m, [[5, 8.8], [7, 14], [11.5, 17.5]]), 1.5, 0.5, STEEL_N.lightened(0.04))
		p.strand(_pts(m, [[11, 11.6], [15, 15.5], [20, 16.5]]), 1.3, 0.45, STEEL_N)
		p.strand(_pts(m, [[16.5, 10.6], [19.5, 6.0], [20.5, 3.2]]), 1.0, 0.4, STEEL_N.darkened(0.04))
	p.spec = 0.0
	t.end(MAT)
	t.begin()
	W._leather_wrap(p, sk - d * 13.0, sk - d * 7.5, 3.0, 3)
	var bone := Color(0.72, 0.67, 0.56)
	var sl := func(u: float, v: float) -> Vector2: return sk + d * u + n * v
	p.flat_poly(_pts(sl, [[-1.0, 5.2], [-4.6, 4.4], [-7.4, 2.6], [-7.8, 0.0], [-7.4, -2.6], [-4.6, -4.4], [-1.0, -5.2]]), bone.darkened(0.06), Vector3(0.1, 0.25, 1.0))
	var cr: Vector2 = sl.call(1.6, 0.0)
	p.ball(cr.x, cr.y, 6.3, 6.3, bone)
	for sv in [-1.0, 1.0]:
		var cb: Vector2 = sl.call(-2.6, 4.0 * float(sv))
		p.ball(cb.x, cb.y, 1.6, 1.2, bone.lightened(0.05))
	var dark := Color(0.05, 0.04, 0.03)
	for sv in [-1.0, 1.0]:
		var e: float = sv
		p.poly(_pts(sl, [[0.9, 0.7 * e], [0.6, 3.6 * e], [-1.3, 3.9 * e], [-2.2, 2.4 * e], [-1.4, 0.8 * e]]), dark)
	p.line(sl.call(1.6, -4.6), sl.call(1.2, 4.6), bone.darkened(0.3), 0.35)
	p.poly(_pts(sl, [[-2.7, 0.0], [-4.2, 0.85], [-4.2, -0.85]]), dark)
	p.line(sl.call(-5.6, -2.6), sl.call(-5.6, 2.6), bone.darkened(0.55), 0.5)
	for k in 5:
		var tp0: Vector2 = sl.call(-5.0, -2.0 + k * 1.0)
		p.line(tp0, tp0 - d * 1.5, bone.darkened(0.5), 0.3)
	t.end(NONE)
	t.begin()
	for sv in [-1.0, 1.0]:
		var ep2: Vector2 = sl.call(-0.6, 2.2 * float(sv))
		p.ellipse(ep2.x, ep2.y, 0.75, 0.75, GLOW_LO)
		p.ellipse(ep2.x, ep2.y, 0.32, 0.32, GLOW_HI)
	var gem := sk + d * 14.0
	_crystal(p, gem, d, n, 3.3, 5.8)
	t.end(GLOW)
	return gem


# =============================================================================== hunter bows
## Same three frames as bow.png: 0 idle (half drawn), 1 full draw / aimed, 2 released.

static func _bow(recurve: bool) -> Array:
	var u := (W.AIM - W.REST).normalized()
	var axis := Vector2(-0.3, -1.0).normalized()
	var left := Vector2(axis.y, -axis.x)
	if left.x > 0.0:
		left = -left
	var frames: Array = []
	var masks: Array = []
	for i in 3:
		var p := Painter.new(W.FW, W.FH, 2200 + i + (10 if recurve else 0))
		p.set_real(1.0)
		p.grain = 0.08
		var t := Tagger.new(p.img)
		var draw: float = [80.0, 150.0, 0.0][i]
		var grip := W.REST + Vector2(4, 14)
		var mid := grip - left * 4.0
		var nock := W.REST - u * draw
		var anchors: Array
		if recurve:
			anchors = _recurve_limbs(p, t, mid, axis, left, u, nock, draw, i)
		else:
			anchors = _longbow_limbs(p, t, mid, axis, left, u, nock, draw, i)
		t.begin()
		p.capsule(mid + axis * 20.0, mid - axis * 20.0, 10.0, 10.0, W.LEATHER.darkened(0.15))
		for kk in 6:
			var wp := mid + axis * (-17.0 + kk * 6.8)
			p.line(wp - left * 10.0 - axis * 1.5, wp + left * 10.0 + axis * 1.5, W.LEATHER.darkened(0.6), 1.0)
		W._bow_fist(p, mid, axis, left)
		t.end(NONE)
		t.begin()
		if i < 2:
			_arrow(p, u, nock)
			var a0: Vector2 = anchors[0]
			var a1: Vector2 = anchors[1]
			W._draw_hand(p, nock, u, (a0 - nock).normalized(), (a1 - nock).normalized())
		else:
			W._released_hand(p, Vector2(500, 300), u)
		t.end(NONE)
		W._finish(p)
		masks.append(_resolve(p, t))
		frames.append(p.img)
	return [Painter.strip(frames), Painter.strip(masks)]


static func _arrow(p: Painter, u: Vector2, nock: Vector2) -> void:
	## Arrow on the aim line, as bow.png (untinted).
	var tip_p := W.REST + u * 30.0
	p.capsule(nock, tip_p, 3.0, 2.6, Color(0.56, 0.43, 0.27))
	var an := Vector2(-u.y, u.x)
	p.spec = 0.9
	p.grad_poly(PackedVector2Array([tip_p - u * 4.0 + an * 7.0, tip_p + u * 20.0, tip_p - u * 4.0 - an * 7.0]), Color(0.5, 0.52, 0.56), tip_p, an, 7.0, 0.6, 1.2, 3.0)
	p.spec = 0.0
	for kk in 7:
		var fp := nock + u * (26.0 + kk * 4.0)
		p.line(fp, fp - u * 7.0 + an * 11.0, Color(0.55, 0.12, 0.1) if kk % 2 == 0 else Color(0.42, 0.08, 0.08), 1.6)
		p.line(fp, fp - u * 7.0 - an * 11.0, Color(0.85, 0.82, 0.75) if kk % 2 == 0 else Color(0.7, 0.68, 0.62), 1.6)


static func _string(p: Painter, t: Tagger, a: Vector2, b: Vector2, nock: Vector2, released: bool, left: Vector2) -> void:
	var sc := Color(0.8, 0.78, 0.7)
	t.begin()
	if released:
		p.line(a, b, sc, 1.3)
		p.line(a + left * 3.0, b + left * 3.0, Color(sc.r, sc.g, sc.b, 0.35), 1.0)
	else:
		p.line(a, nock, sc, 1.3)
		p.line(nock, b, sc, 1.3)
	t.end(NONE)


static func _longbow_limbs(p: Painter, t: Tagger, mid: Vector2, axis: Vector2, left: Vector2, u: Vector2, nock: Vector2, draw: float, i: int) -> Array:
	## Tall self longbow (as bow.png): one continuous D-shaped stave with grain, horn nocks, runes.
	var bend := 34.0 + draw * 0.08
	var half := 225.0
	var top_tip := mid + axis * half - left * bend + (-u) * draw * 0.06
	var bot_tip := mid - axis * half - left * bend + (-u) * draw * 0.06
	_string(p, t, top_tip, bot_tip, nock, i == 2, left)
	var lim := PackedVector2Array()
	var rad := PackedFloat32Array()
	for kk in 49:
		var tt := float(kk) / 48.0
		lim.append(top_tip.lerp(bot_tip, tt) + left * sin(tt * PI) * bend)
		rad.append(5.5 + sin(tt * PI) * 7.0)
	t.begin()
	_tube(p, lim, rad, LIMB_N.darkened(0.08))
	for kk in 48:
		var r0 := rad[kk]
		var r1 := rad[kk + 1]
		p.line(lim[kk] - left * r0 * 0.3, lim[kk + 1] - left * r1 * 0.3, LIMB_N.lightened(0.2), 1.0)
		for g in 4:
			var off: float = [-0.62, -0.05, 0.32, 0.62][g]
			if (kk * 3 + g * 5) % 9 < 5:
				p.line(lim[kk] + left * r0 * off, lim[kk + 1] + left * r1 * off, LIMB_N.darkened(0.38), 1.0)
	for tip in [top_tip, bot_tip]:
		var tv: Vector2 = tip
		p.capsule(tv, tv - left * 8.0 + (Vector2(0, 5) if tv.y < 180 else Vector2(0, -5)), 4.0, 2.4, LIMB_N.lightened(0.2))
	t.end(MAT)
	var items: Array = []
	var kinds := [0, 5, 3, 1]
	var ks := [12, 16, 32, 36]
	for r in 4:
		var kk2: int = ks[r]
		var up := (lim[kk2 - 1] - lim[kk2 + 1]).normalized()
		items.append([lim[kk2] + left * 1.0, up, 1.7, kinds[r]])
	_runes(p, t, items, 3.4, 2.0)
	return [top_tip, bot_tip]


static func _catmull(ctrl: Array, per: int) -> Array:
	var out: Array = []
	var cn := ctrl.size()
	for i in cn - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, cn - 1)]
		for k in per:
			var tt := float(k) / float(per)
			var t2 := tt * tt
			var t3 := t2 * tt
			out.append(0.5 * ((p1 * 2.0) + (p2 - p0) * tt + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t3))
	out.append(ctrl[cn - 1])
	return out


## recurve limb centreline: (along the bow axis, across toward the archer) in px, grip -> tip
const RECURVE_CTRL := [Vector2(0, 0), Vector2(38, 1), Vector2(76, 8), Vector2(108, 19), Vector2(132, 27), Vector2(149, 26), Vector2(160, 17), Vector2(166, 3)]


static func _recurve_limbs(p: Painter, t: Tagger, mid: Vector2, axis: Vector2, left: Vector2, u: Vector2, nock: Vector2, draw: float, i: int) -> Array:
	## Short composite horn bow: thick riser with a set gem, limbs sweeping back toward the archer
	## then flicking forward into stiff recurved tips; the string lies on the recurve.
	var right := -left
	var flex := draw / 150.0
	var limbs: Array = []
	var radii: Array = []
	var bridges: Array = []
	var smp := _catmull(RECURVE_CTRL, 8)
	for sv in [1.0, -1.0]:
		var sg: float = sv
		var pts := PackedVector2Array()
		var rr := PackedFloat32Array()
		var best := -1e9
		var bi := 0
		for k in smp.size():
			var q: Vector2 = smp[k]
			var s := q.x / 166.0
			var along := q.x * (1.0 - flex * 0.05 * s)
			var across := q.y + flex * 26.0 * s * s
			pts.append(mid + axis * (sg * along) + right * across + (-u) * draw * 0.05 * s)
			rr.append(_recurve_th(s))
			if across > best and s > 0.5:
				best = across
				bi = k
		limbs.append(pts)
		radii.append(rr)
		bridges.append(bi)
	var up_l: PackedVector2Array = limbs[0]
	var dn_l: PackedVector2Array = limbs[1]
	var b_up: Vector2 = up_l[int(bridges[0])]
	var b_dn: Vector2 = dn_l[int(bridges[1])]
	_string(p, t, b_up, b_dn, nock, i == 2, left)
	var cnt := up_l.size()
	t.begin()
	for li in 2:
		_tube(p, limbs[li], radii[li], LIMB_N.darkened(0.32))
	for li in 2:
		var pts2: PackedVector2Array = limbs[li]
		var rr2: PackedFloat32Array = radii[li]
		var bp := PackedVector2Array()
		var br := PackedFloat32Array()
		for k in cnt:
			if float(k) / float(cnt - 1) > 0.9:
				break
			bp.append(pts2[k] + right * rr2[k] * 0.32)
			br.append(rr2[k] * 0.52)
		_tube(p, bp, br, LIMB_N.lightened(0.14))
		for k in range(6, cnt - 6, 5):
			var tg := (pts2[k + 1] - pts2[k - 1]).normalized()
			var nn := Vector2(-tg.y, tg.x)
			p.line(pts2[k] - nn * rr2[k] * 0.9, pts2[k] + nn * rr2[k] * 0.9, LIMB_N.darkened(0.5), 1.0)
		var tip := pts2[cnt - 1]
		p.ball(tip.x, tip.y, 3.8, 3.8, LIMB_N.lightened(0.25))
		var jk := int(cnt * 0.21)
		var tg2 := (pts2[jk + 1] - pts2[jk - 1]).normalized()
		var nn2 := Vector2(-tg2.y, tg2.x)
		for wv in 3:
			var wp2 := pts2[jk] + tg2 * (wv * 3.2 - 3.2)
			p.line(wp2 - nn2 * 10.5, wp2 + nn2 * 10.5, LIMB_N.darkened(0.5), 1.6)
	t.end(MAT)
	# string lying on the recurve, from the string bridge to the tip
	t.begin()
	for li2 in 2:
		var pts3: PackedVector2Array = limbs[li2]
		var rr3: PackedFloat32Array = radii[li2]
		var bi2: int = bridges[li2]
		for k in range(bi2, cnt - 1):
			p.line(pts3[k] + right * rr3[k] * 0.85, pts3[k + 1] + right * rr3[k + 1] * 0.85, Color(0.8, 0.78, 0.7), 1.3)
	t.end(NONE)
	var items: Array = []
	var kinds := [6, 2]
	for li3 in 2:
		var pts4: PackedVector2Array = limbs[li3]
		var k2 := int(cnt * 0.5)
		var up := (pts4[k2 - 1] - pts4[k2 + 1]).normalized()
		if up.y > 0.0:
			up = -up
		items.append([pts4[k2] - right * 1.0, up, 1.45, kinds[li3]])
	_runes(p, t, items, 3.2, 1.8)
	var gk := int(cnt * 0.27)
	var gp := up_l[gk]
	var gax := (up_l[gk - 1] - up_l[gk + 1]).normalized()
	t.begin()
	p.spec = 0.7
	p.ball(gp.x, gp.y, 6.2, 6.2, STEEL_N.darkened(0.15))
	p.spec = 0.0
	t.end(MAT)
	t.begin()
	_crystal(p, gp, gax, Vector2(-gax.y, gax.x), 3.9, 6.0)
	t.end(GLOW)
	return [b_up, b_dn]


static func _recurve_th(s: float) -> float:
	if s < 0.2:
		return 11.5
	if s > 0.92:
		return lerpf(3.6, 2.6, (s - 0.92) / 0.08)
	return lerpf(9.5, 3.6, (s - 0.2) / 0.72)


# =============================================================================== crossbow
## Drawn in screen pixels like the bow: stock and bolt lie on the aim line that rises from below
## the screen to the crosshair (oblique top-down view, so the stock reads at full length); the
## steel prod crosses it and sweeps back toward the viewer when spanned.
## Frames: 0 loaded at rest (lowered, canted), 1 raised and aimed, 2 just fired (bolt gone,
## string forward, small kick).

const XB_B := Vector2(372, 420)
const XB_WOOD := Color(0.33, 0.21, 0.12)
const XB_PIVOT := Vector2(350, 320)


static func _crossbow() -> Array:
	## [rotation, offset, loaded]
	var poses := [
		[0.26, Vector2(58, 66), true],
		[0.0, Vector2.ZERO, true],
		[-0.035, Vector2(0, -9), false],
	]
	var frames: Array = []
	var masks: Array = []
	for i in 3:
		var p := Painter.new(W.FW, W.FH, 2300 + i)
		p.set_real(1.0)
		p.grain = 0.08
		var t := Tagger.new(p.img)
		var rot: float = poses[i][0]
		var off: Vector2 = poses[i][1]
		var xf := Transform2D(rot, XB_PIVOT + off) * Transform2D(0.0, -XB_PIVOT)
		_xb_draw(p, t, xf, poses[i][2])
		W._finish(p)
		masks.append(_resolve(p, t))
		frames.append(p.img)
	return [Painter.strip(frames), Painter.strip(masks)]


static func _xb_draw(p: Painter, t: Tagger, xf: Transform2D, loaded: bool) -> void:
	var u := (W.AIM - XB_B).normalized()
	var r := Vector2(-u.y, u.x)
	if r.x < 0.0:
		r = -r
	var at := func(s: float, side: float) -> Vector2: return xf * (XB_B + u * s + r * side)
	var hw := func(s: float) -> float: return lerpf(30.0, 11.0, s / 210.0)
	var dep := func(s: float) -> float: return lerpf(15.0, 5.0, s / 210.0)
	var xu := xf.basis_xform(u).normalized()
	var xr := xf.basis_xform(r).normalized()
	# ---- stock (wood): top face, left side face, front cap, groove, grain
	t.begin()
	var h0: float = hw.call(0.0)
	var h1: float = hw.call(210.0)
	var e0: float = dep.call(0.0)
	var e1: float = dep.call(210.0)
	p.flat_poly(PackedVector2Array([at.call(0.0, -h0), at.call(210.0, -h1), at.call(210.0, -h1 - e1), at.call(0.0, -h0 - e0)]), XB_WOOD.darkened(0.15), Vector3(-0.9, 0.2, 0.4))
	p.grad_poly(PackedVector2Array([at.call(0.0, -h0), at.call(210.0, -h1), at.call(210.0, h1), at.call(0.0, h0)]), XB_WOOD, at.call(0.0, 0.0), xu, 210.0, 0.95, 0.72, 5.0)
	p.flat_poly(PackedVector2Array([at.call(210.0, -h1 - e1), at.call(210.0, h1), at.call(214.0, h1 - 1.0), at.call(214.0, -h1 - e1 + 1.0)]), XB_WOOD.darkened(0.3), Vector3(0.0, -0.8, 0.6))
	for g in [-0.72, -0.4, 0.3, 0.62]:
		var gs: float = g
		var s0 := 0.0 if gs < 0.0 else 30.0
		p.line(at.call(s0, gs * h0), at.call(206.0, gs * h1), XB_WOOD.darkened(0.3), 1.0)
	p.line(at.call(0.0, -h0 - e0 * 0.5), at.call(206.0, -h1 - e1 * 0.5), XB_WOOD.darkened(0.45), 1.0)
	p.line(at.call(96.0, 0.0), at.call(210.0, 0.0), XB_WOOD.darkened(0.6), 2.0)
	t.end(NONE)
	# ---- metal: bands, bridle, stirrup, prod, nut, gem bezel
	t.begin()
	p.spec = 0.7
	p.shininess = 24.0
	for bs in [40.0, 150.0]:
		var s1: float = bs
		var bh: float = hw.call(s1) + 1.0
		var bd: float = dep.call(s1)
		p.flat_poly(PackedVector2Array([at.call(s1 - 4.0, -bh), at.call(s1 + 4.0, -bh), at.call(s1 + 4.0, bh), at.call(s1 - 4.0, bh)]), STEEL_N, Vector3(0.0, -0.3, 1.0))
		p.flat_poly(PackedVector2Array([at.call(s1 - 4.0, -bh), at.call(s1 + 4.0, -bh), at.call(s1 + 4.0, -bh - bd), at.call(s1 - 4.0, -bh - bd)]), STEEL_N.darkened(0.25), Vector3(-0.9, 0.2, 0.4))
	var droop := 34.0 if loaded else 9.0
	var pc := XB_B + u * 190.0
	var ppx := PackedVector2Array()
	var prad := PackedFloat32Array()
	for k in 41:
		var tt := lerpf(-1.0, 1.0, float(k) / 40.0)
		ppx.append(xf * (pc + Vector2(tt * 205.0, droop * tt * tt - 7.0 * (1.0 - tt * tt))))
		prad.append(lerpf(9.0, 4.2, absf(tt)))
	# stirrup in front of the prod
	p.strand(PackedVector2Array([at.call(203.0, -9.0), at.call(214.0, -10.5), at.call(224.0, -7.0), at.call(228.0, 0.0), at.call(224.0, 7.0), at.call(214.0, 10.5), at.call(203.0, 9.0)]), 2.4, 2.4, STEEL_N.darkened(0.05))
	_tube(p, ppx, prad, STEEL_N)
	for k in 40:
		var up_px := xf.basis_xform(Vector2(0, -1))
		p.line(ppx[k] + up_px * (prad[k] * 0.42), ppx[k + 1] + up_px * (prad[k + 1] * 0.42), STEEL_N.lightened(0.38), 1.0)
	for e in [0, 40]:
		var tp0 := ppx[int(e)]
		p.ball(tp0.x, tp0.y, 5.2, 5.2, STEEL_N.lightened(0.1))
	var bh2: float = hw.call(190.0) + 3.0
	p.flat_poly(PackedVector2Array([at.call(180.0, -bh2), at.call(199.0, -bh2), at.call(199.0, bh2), at.call(180.0, bh2)]), STEEL_N.darkened(0.12), Vector3(0.0, -0.4, 1.0))
	p.flat_poly(PackedVector2Array([at.call(180.0, -bh2), at.call(199.0, -bh2), at.call(199.0, -bh2 - 6.0), at.call(180.0, -bh2 - 6.0)]), STEEL_N.darkened(0.35), Vector3(-0.9, 0.2, 0.4))
	for rv in [-1.0, 1.0]:
		var rp: Vector2 = at.call(189.5, float(rv) * (bh2 - 3.5))
		p.ball(rp.x, rp.y, 1.8, 1.8, STEEL_N.lightened(0.3))
	var gp: Vector2 = at.call(80.0, 0.0)
	p.ball(gp.x, gp.y, 9.0, 6.4, STEEL_N.darkened(0.1))
	p.spec = 0.0
	p.shininess = 18.0
	t.end(MAT)
	# ---- string, then the nut holding it
	var tl := ppx[0]
	var tr := ppx[40]
	var sc := Color(0.8, 0.78, 0.7)
	t.begin()
	if loaded:
		var catch: Vector2 = at.call(107.0, 0.0)
		p.line(tl, catch, sc, 1.4)
		p.line(tr, catch, sc, 1.4)
	else:
		var dn_px := xf.basis_xform(Vector2(0, 1))
		p.line(tl + dn_px * 2.0, tr + dn_px * 2.0, sc, 1.4)
		p.line(tl + dn_px * 6.0, tr + dn_px * 6.0, Color(sc.r, sc.g, sc.b, 0.35), 1.0)
	t.end(NONE)
	t.begin()
	p.spec = 0.8
	var nh: float = hw.call(105.0) - 4.0
	p.capsule(at.call(105.0, -nh), at.call(105.0, nh), 5.5, 5.5, STEEL_N)
	p.line(at.call(108.5, -3.0), at.call(108.5, 3.0), STEEL_N.darkened(0.6), 1.0)
	p.spec = 0.0
	t.end(MAT)
	# ---- glow: gem set in the stock behind the nut, runes along the prod arms
	t.begin()
	p.ellipse(gp.x, gp.y, 6.4, 4.4, GLOW_LO)
	p.ellipse(gp.x - 0.8, gp.y - 0.6, 4.2, 2.9, GLOW_MID)
	p.ellipse(gp.x - 1.8, gp.y - 1.2, 1.9, 1.3, GLOW_HI)
	t.end(GLOW)
	var items: Array = []
	var kinds := [3, 0, 5, 6]
	var ri := 0
	for k in [9, 15, 25, 31]:
		var kk: int = k
		var tg := (ppx[kk + 1] - ppx[kk - 1]).normalized()
		items.append([ppx[kk], tg if kk > 20 else -tg, 1.4, kinds[ri]])
		ri += 1
	_runes(p, t, items, 2.6, 1.5)
	# ---- bolt
	if loaded:
		t.begin()
		p.capsule(at.call(103.0, 0.0), at.call(222.0, 0.0), 3.0, 2.2, Color(0.52, 0.4, 0.25))
		var hb: Vector2 = at.call(219.0, 0.0)
		p.spec = 0.9
		p.grad_poly(PackedVector2Array([at.call(219.0, -5.5), at.call(239.0, 0.0), at.call(219.0, 5.5)]), Color(0.5, 0.52, 0.56), hb, xr, 5.5, 0.6, 1.2, 3.0)
		p.spec = 0.0
		for sv in [-1.0, 1.0]:
			var sd: float = sv
			var fv := PackedVector2Array([at.call(108.0, 0.0), at.call(113.0, 9.0 * sd), at.call(129.0, 9.0 * sd), at.call(133.0, 0.0)])
			p.poly(fv, Color(0.55, 0.12, 0.1) if sd < 0.0 else Color(0.8, 0.77, 0.7))
			p.line(fv[1], fv[2], Color(0.3, 0.06, 0.05) if sd < 0.0 else Color(0.55, 0.52, 0.46), 1.0)
		t.end(NONE)
	# ---- left fist supporting the fore-stock (the trigger hand is below the screen)
	t.begin()
	var lh: float = hw.call(140.0) + dep.call(140.0) * 0.6
	_fist(p, at.call(140.0, -lh), xu, -xr, xf.basis_xform(Vector2(-0.6, 1.0)).normalized(), 1.0)
	t.end(NONE)


static func _fist(p: Painter, grip: Vector2, axis: Vector2, left: Vector2, f: Vector2, sc: float) -> void:
	## Gloved fist around a beam running along axis (bow.png hand style); knuckles on the `left`
	## side, fingers wrapping toward the other side, forearm leaving along f.
	var rdir := -left
	var lens := [27.0, 25.5, 24.0, 21.0]
	var centres: Array = []
	for i in 4:
		centres.append(grip + axis * ((11.0 - i * 8.6) * sc))
	var c0: Vector2 = centres[0]
	var c3: Vector2 = centres[3]
	var k_top := c0 - rdir * 12.0 * sc + axis * 4.5 * sc
	var k_bot := c3 - rdir * 12.0 * sc - axis * 4.5 * sc
	var w_top := k_top + f * 30.0 * sc - rdir * 6.0 * sc
	var w_bot := k_bot + f * 20.0 * sc - rdir * 1.0 * sc
	var wrist := (w_top + w_bot) * 0.5
	W._forearm(p, wrist, f, 13.0 * sc)
	W._tpoly(p, PackedVector2Array([k_top, k_bot, w_bot, w_top]), W.GLOVE_T)
	for i in range(3, -1, -1):
		var c: Vector2 = centres[i]
		var a := c - rdir * 12.0 * sc
		var b := c + rdir * (float(lens[i]) - 12.0) * sc
		W._tcapsule(p, a, b, 4.0 * sc, W.GLOVE_T)
		W._knuckle_glint(p, a + rdir * 3.0 * sc + axis * 2.6 * sc, rdir)
	var t0 := k_top + f * 13.0 * sc - rdir * 2.0 * sc
	var t1 := c0 + rdir * 5.0 * sc + axis * 2.0 * sc
	W._tcapsule(p, t0, t1, 4.4 * sc, W.GLOVE_T)


# =============================================================================== previews

static func tinted(base: Image, mask: Image, tint: Color, glow: Color, pulse: float) -> Image:
	## Applies the runtime shader formula (for previews).
	var out := base.duplicate() as Image
	for y in base.get_height():
		for x in base.get_width():
			var c := base.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var m := mask.get_pixel(x, y)
			var r := minf(c.r * lerpf(1.0, tint.r, m.r) + glow.r * m.b * pulse, 1.0)
			var g := minf(c.g * lerpf(1.0, tint.g, m.r) + glow.g * m.b * pulse, 1.0)
			var b := minf(c.b * lerpf(1.0, tint.b, m.r) + glow.b * m.b * pulse, 1.0)
			out.set_pixel(x, y, Color(r, g, b, c.a))
	return out


static func write_previews(built: Array, dir: String) -> void:
	## built: [[kind, sheet, mask], ...]. Writes, under dir:
	##  forge_sheets.png / forge_masks.png: every frame of every sheet (half size);
	##  forge_tints_<class>.png: one frame per weapon (warrior idle, mage cast, hunter aimed),
	##  neutral then 3 materials + glows.
	var bg := Color(0.12, 0.12, 0.14)
	var sheets := Image.create(1280 + 8, built.size() * 186 + 8, false, Image.FORMAT_RGBA8)
	sheets.fill(bg)
	var masks := Image.create(1280 + 8, built.size() * 186 + 8, false, Image.FORMAT_RGBA8)
	masks.fill(bg)
	for bi in built.size():
		var e: Array = built[bi]
		for which in 2:
			var src0: Image = e[1] if which == 0 else e[2]
			var src := src0.duplicate() as Image
			src.resize(src.get_width() / 2, src.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			var dst: Image = sheets if which == 0 else masks
			dst.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(4, 4 + bi * 186))
	Painter.save_image(sheets, dir + "/forge_sheets.png")
	Painter.save_image(masks, dir + "/forge_masks.png")
	var variants := [
		["neutral", Color(1, 1, 1), Color(0, 0, 0), 0.0],
		["obsidian + ember", Color(0.35, 0.3, 0.4), Color(1.0, 0.42, 0.08), 0.9],
		["gold + soul", Color(1.0, 0.8, 0.35), Color(0.25, 1.0, 0.4), 0.9],
		["ice + arcane", Color(0.6, 0.85, 1.0), Color(0.6, 0.35, 1.0), 0.9],
	]
	for group in [["warrior", WARRIOR, 0], ["mage", MAGE, 1], ["hunter", HUNTER, 1]]:
		var g: Array = group
		var kinds: Array = g[1]
		var fi: int = g[2]
		var rows: Array = []
		for e2 in built:
			var ee: Array = e2
			if ee[0] in kinds:
				rows.append(ee)
		var cells: Array = []
		var cw := 0
		var ch := 0
		for ee2 in rows:
			var ee3: Array = ee2
			var sheet: Image = ee3[1]
			var mask: Image = ee3[2]
			var f0 := sheet.get_region(Rect2i(fi * W.FW, 0, W.FW, W.FH))
			var m0 := mask.get_region(Rect2i(fi * W.FW, 0, W.FW, W.FH))
			var ur := f0.get_used_rect()
			var row: Array = []
			for v in variants:
				var vv: Array = v
				var im := tinted(f0, m0, vv[1], vv[2], vv[3]).get_region(ur)
				row.append(im)
			cells.append(row)
			cw = maxi(cw, ur.size.x)
			ch = maxi(ch, ur.size.y)
		var out := Image.create(4 + variants.size() * (cw + 4), 4 + cells.size() * (ch + 4), false, Image.FORMAT_RGBA8)
		out.fill(bg)
		for r in cells.size():
			var row2: Array = cells[r]
			for c in row2.size():
				var im2: Image = row2[c]
				out.blend_rect(im2, Rect2i(0, 0, im2.get_width(), im2.get_height()), Vector2i(4 + c * (cw + 4), 4 + r * (ch + 4)))
		Painter.save_image(out, dir + "/forge_tints_%s.png" % g[0])
