extends RefCounted
## Pixel-art raster toolkit used by the asset generators (tools/gen_art.gd).
## Two looks:
##  - stylized (default, used by UI icons): posterized hue-shifted ramps + dark outlines;
##  - realistic (`real = true`): neutral ramps, many bands, film-like grain, specular
##    glints, soft silhouette rim darkening instead of black outlines (Doom/Heretic-like
##    "digitized" sprites).
## `k` is a design-unit scale: positions go through `xf`, radii/thicknesses are multiplied by k.

const OUTLINE := Color(0.06, 0.035, 0.08, 1.0)
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var img: Image
var w: int
var h: int
var light: Vector3 = Vector3(-0.55, -0.7, 0.6).normalized()
var ambient: float = 0.28
var bands: float = 5.0
var dither: float = 0.4
var rng := RandomNumberGenerator.new()
## Transform applied to every primitive's anchor points (design scale, falling poses).
var xf: Transform2D = Transform2D.IDENTITY
## Radius / thickness multiplier (keep equal to the scale inside xf).
var k: float = 1.0
## Realistic shading mode.
var real: bool = false
## Grain amplitude (shade units) in realistic mode.
var grain: float = 0.0
## Specular strength for the next primitives (metal, wet flesh).
var spec: float = 0.0
var shininess: float = 18.0
var _nfine: FastNoiseLite
var _nmid: FastNoiseLite


func _init(width: int, height: int, seed_value: int = 1) -> void:
	w = width
	h = height
	img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	rng.seed = seed_value
	_nfine = FastNoiseLite.new()
	_nfine.seed = seed_value * 7 + 3
	_nfine.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	_nfine.frequency = 0.55
	_nfine.fractal_octaves = 2
	_nmid = FastNoiseLite.new()
	_nmid.seed = seed_value * 13 + 5
	_nmid.frequency = 0.09
	_nmid.fractal_octaves = 3


func set_real(scale: float = 1.0) -> void:
	## Switch to the realistic look with a design-unit scale.
	real = true
	k = scale
	xf = Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2.ZERO)
	light = Vector3(-0.42, -0.62, 0.66).normalized()
	ambient = 0.2
	bands = 10.0
	dither = 0.25
	grain = 0.11


# ---------------------------------------------------------------- colour helpers

static func ramp(base: Color, s: float) -> Color:
	## Stylized ramp. s: 0 = deep shadow, 1 = base colour, up to 1.5 = highlight.
	var c: Color
	if s <= 1.0:
		var shadow := Color(base.r * 0.2 + 0.035, base.g * 0.18 + 0.025, base.b * 0.28 + 0.075)
		c = shadow.lerp(base, clampf(s, 0.0, 1.0))
	else:
		var hi := base.lerp(Color(1.0, 0.96, 0.82), 0.6)
		c = base.lerp(hi, clampf((s - 1.0) / 0.5, 0.0, 1.0))
	c.a = base.a
	return c


static func ramp_real(base: Color, s: float) -> Color:
	## Neutral ramp: shadows darker + slightly cooler/desaturated, restrained highlights.
	var c: Color
	if s <= 1.0:
		var lum := base.get_luminance()
		var shadow := Color(base.r * 0.13 + lum * 0.03, base.g * 0.14 + lum * 0.03, base.b * 0.17 + lum * 0.04)
		c = shadow.lerp(base, pow(clampf(s, 0.0, 1.0), 0.85))
	else:
		var hi := base.lerp(Color(1.0, 0.97, 0.9), 0.5)
		c = base.lerp(hi, clampf((s - 1.0) / 0.6, 0.0, 1.0))
	c.a = base.a
	return c


static func hex(code: String) -> Color:
	return Color.html(code)


func col(base: Color, s: float) -> Color:
	return ramp_real(base, s) if real else ramp(base, s)


func grain_at(x: int, y: int) -> float:
	return _nfine.get_noise_2d(x, y) * 0.75 + (rng.randf() - 0.5) * 0.5


func mid_noise(x: float, y: float) -> float:
	return _nmid.get_noise_2d(x, y)


func shade_value(n: Vector3, x: int, y: int) -> float:
	var d := maxf(n.dot(light), 0.0)
	var s: float
	if real:
		s = ambient + d * (1.0 - ambient) * 1.08
		if spec > 0.0:
			var hv := (light + Vector3(0, 0, 1)).normalized()
			s += spec * pow(maxf(n.dot(hv), 0.0), shininess)
		if grain > 0.0:
			s += grain_at(x, y) * grain
	else:
		s = ambient + d * 1.12
	if dither > 0.0:
		var b: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) - 7.5) / 16.0
		s += b * dither / bands
	return floorf(s * bands + 0.5) / bands


# ---------------------------------------------------------------- raw pixels

func put(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	elif c.a > 0.004:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)


func fill(c: Color) -> void:
	img.fill(c)


# ---------------------------------------------------------------- flat primitives

func tp(v: Vector2) -> Vector2:
	return xf * v


func rect(x: float, y: float, rw: float, rh: float, c: Color) -> void:
	if xf == Transform2D.IDENTITY:
		for yy in range(int(floor(y)), int(ceil(y + rh))):
			for xx in range(int(floor(x)), int(ceil(x + rw))):
				put(xx, yy, c)
	else:
		poly(PackedVector2Array([Vector2(x, y), Vector2(x + rw, y), Vector2(x + rw, y + rh), Vector2(x, y + rh)]), c)


func tput(x: float, y: float, c: Color) -> void:
	## A design-unit "pixel" through the current transform.
	if k <= 1.01:
		var q := tp(Vector2(x + 0.5, y + 0.5))
		put(int(floor(q.x)), int(floor(q.y)), c)
	else:
		rect(x, y, 1.0, 1.0, c)


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var cc := tp(Vector2(cx, cy))
	rx *= k
	ry *= k
	for y in range(int(floor(cc.y - ry)), int(ceil(cc.y + ry)) + 1):
		for x in range(int(floor(cc.x - rx)), int(ceil(cc.x + rx)) + 1):
			var dx := (x + 0.5 - cc.x) / rx
			var dy := (y + 0.5 - cc.y) / ry
			if dx * dx + dy * dy <= 1.0:
				put(x, y, c)


func poly(pts: PackedVector2Array, c: Color) -> void:
	var t := PackedVector2Array()
	for v in pts:
		t.append(tp(v))
	var r := _bounds(t)
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), t):
				put(x, y, c)


func line(a: Vector2, b: Vector2, c: Color, thick: float = 1.0) -> void:
	var ta := tp(a)
	var tb := tp(b)
	thick *= k
	var n := int(maxf(absf(tb.x - ta.x), absf(tb.y - ta.y))) + 1
	for i in range(n + 1):
		var q := ta.lerp(tb, float(i) / float(n))
		if thick <= 1.0:
			put(int(floor(q.x)), int(floor(q.y)), c)
		else:
			var r := thick * 0.5
			for yy in range(int(floor(q.y - r)), int(ceil(q.y + r))):
				for xx in range(int(floor(q.x - r)), int(ceil(q.x + r))):
					if Vector2(xx + 0.5, yy + 0.5).distance_to(q) <= r:
						put(xx, yy, c)


func glow(cx: float, cy: float, r: float, c: Color, strength: float = 1.0) -> void:
	var cc := tp(Vector2(cx, cy))
	r *= k
	for y in range(int(floor(cc.y - r)), int(ceil(cc.y + r)) + 1):
		for x in range(int(floor(cc.x - r)), int(ceil(cc.x + r)) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(cc) / r
			if d < 1.0:
				var a := (1.0 - d) * (1.0 - d) * strength
				_add_light(x, y, c, a)


func glow_px(cx: float, cy: float, r: float, c: Color, strength: float = 1.0) -> void:
	## Glow at an already-transformed pixel position (radius in pixels).
	for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
		for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) / r
			if d < 1.0:
				_add_light(x, y, c, (1.0 - d) * (1.0 - d) * strength)


func light_only(cx: float, cy: float, r: float, c: Color, strength: float = 1.0) -> void:
	## Adds coloured light on existing opaque pixels only (no halo outside the silhouette).
	var cc := tp(Vector2(cx, cy))
	r *= k
	for y in range(int(floor(cc.y - r)), int(ceil(cc.y + r)) + 1):
		for x in range(int(floor(cc.x - r)), int(ceil(cc.x + r)) + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var o := img.get_pixel(x, y)
			if o.a < 0.5:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(cc) / r
			if d < 1.0:
				var a := (1.0 - d) * (1.0 - d) * strength
				img.set_pixel(x, y, Color(minf(o.r + c.r * a, 1.0), minf(o.g + c.g * a, 1.0), minf(o.b + c.b * a, 1.0), o.a))


func _add_light(x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= w or y >= h or a <= 0.003:
		return
	var o := img.get_pixel(x, y)
	if o.a <= 0.003:
		img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))
	else:
		var na := maxf(o.a, clampf(a, 0.0, 1.0))
		img.set_pixel(x, y, Color(minf(o.r + c.r * a, 1.0), minf(o.g + c.g * a, 1.0), minf(o.b + c.b * a, 1.0), na))


# ---------------------------------------------------------------- shaded primitives

func ball(cx: float, cy: float, rx: float, ry: float, base: Color, rough: float = 0.0) -> void:
	## Shaded ellipsoid.
	var cc := tp(Vector2(cx, cy))
	rx *= k
	ry *= k
	for y in range(int(floor(cc.y - ry)), int(ceil(cc.y + ry)) + 1):
		for x in range(int(floor(cc.x - rx)), int(ceil(cc.x + rx)) + 1):
			var dx := (x + 0.5 - cc.x) / rx
			var dy := (y + 0.5 - cc.y) / ry
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				var n := Vector3(dx, dy, sqrt(1.0 - d2))
				var s := shade_value(n, x, y)
				if rough > 0.0:
					s += (rng.randf() - 0.5) * rough
				put(x, y, col(base, s))


func capsule(a: Vector2, b: Vector2, ra: float, rb: float, base: Color, rough: float = 0.0) -> void:
	## Shaded tapered limb from a (radius ra) to b (radius rb).
	var ta := tp(a)
	var tb := tp(b)
	ra *= k
	rb *= k
	var r := maxf(ra, rb)
	var minx := int(floor(minf(ta.x, tb.x) - r))
	var maxx := int(ceil(maxf(ta.x, tb.x) + r))
	var miny := int(floor(minf(ta.y, tb.y) - r))
	var maxy := int(ceil(maxf(ta.y, tb.y) + r))
	var ab := tb - ta
	var len2 := maxf(ab.length_squared(), 0.0001)
	for y in range(maxi(miny, -2), mini(maxy, h + 1) + 1):
		for x in range(maxi(minx, -2), mini(maxx, w + 1) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - ta).dot(ab) / len2, 0.0, 1.0)
			var rr := lerpf(ra, rb, t)
			var d := p - (ta + ab * t)
			var dl := d.length()
			if dl <= rr:
				var nxy := d / maxf(rr, 0.001)
				var nz := sqrt(maxf(1.0 - nxy.length_squared(), 0.0))
				var s := shade_value(Vector3(nxy.x, nxy.y, nz), x, y)
				if rough > 0.0:
					s += (rng.randf() - 0.5) * rough
				put(x, y, col(base, s))


func strand(pts: PackedVector2Array, r0: float, r1: float, base: Color, rough: float = 0.0) -> void:
	## Chain of tapered capsules along a polyline (ribs, fingers, roots, antlers).
	var n := pts.size()
	for i in n - 1:
		var t0 := float(i) / float(n - 1)
		var t1 := float(i + 1) / float(n - 1)
		capsule(pts[i], pts[i + 1], lerpf(r0, r1, t0), lerpf(r0, r1, t1), base, rough)


func cyl_poly(pts: PackedVector2Array, base: Color, cx: float, hw: float, tilt: float = -0.25, rough: float = 0.0) -> void:
	## Polygon shaded like a vertical cylinder centred on cx with half-width hw (robes, torsos).
	var t := PackedVector2Array()
	for v in pts:
		t.append(tp(v))
	var tcx := tp(Vector2(cx, 0)).x
	hw *= k
	var r := _bounds(t)
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), t):
				var nx := clampf((x + 0.5 - tcx) / hw, -0.98, 0.98)
				var n := Vector3(nx, tilt, sqrt(1.0 - nx * nx)).normalized()
				var s := shade_value(n, x, y)
				if rough > 0.0:
					s += (rng.randf() - 0.5) * rough
				put(x, y, col(base, s))


func cloth(pts: PackedVector2Array, base: Color, cx: float, hw: float, folds: float = 0.5, fold_amp: float = 0.45, tilt: float = -0.15) -> void:
	## Cylinder-shaded fabric with vertical folds (noise-modulated sine creases).
	var t := PackedVector2Array()
	for v in pts:
		t.append(tp(v))
	var tcx := tp(Vector2(cx, 0)).x
	hw *= k
	var r := _bounds(t)
	var f := folds / k
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), t):
				var nx := clampf((x + 0.5 - tcx) / hw, -0.95, 0.95)
				var wob := _nmid.get_noise_2d(x * 0.6, y * 0.08) * 2.5
				nx = clampf(nx + sin(x * f + wob) * fold_amp, -0.97, 0.97)
				var n := Vector3(nx, tilt, sqrt(1.0 - nx * nx)).normalized()
				put(x, y, col(base, shade_value(n, x, y)))


func flat_poly(pts: PackedVector2Array, base: Color, n: Vector3) -> void:
	## Polygon lit as a flat facet with normal n.
	var t := PackedVector2Array()
	for v in pts:
		t.append(tp(v))
	var r := _bounds(t)
	n = n.normalized()
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), t):
				put(x, y, col(base, shade_value(n, x, y)))


func grad_poly(pts: PackedVector2Array, base: Color, origin: Vector2, dir: Vector2, length: float, s0: float, s1: float, steps: float = 4.0) -> void:
	## Polygon shaded by a banded linear gradient along dir (blades, metal plates).
	var t := PackedVector2Array()
	for v in pts:
		t.append(tp(v))
	var o := tp(origin)
	var r := _bounds(t)
	length *= k
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			var pp := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(pp, t):
				var kk := clampf((pp - o).dot(dir) / length, 0.0, 1.0)
				kk = floorf(kk * steps + 0.5) / steps
				var s := lerpf(s0, s1, kk)
				if real and grain > 0.0:
					s += grain_at(x, y) * grain * 0.6
				put(x, y, col(base, s))


func blade(a: Vector2, b: Vector2, wa: float, wb: float, base: Color) -> void:
	## Flat metal blade from a to b, bevelled: one half lit, one half dark, bright edge.
	var ta := tp(a)
	var tb := tp(b)
	wa *= k
	wb *= k
	var dir := (tb - ta).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([ta + nrm * wa, tb + nrm * wb, tb - nrm * wb, ta - nrm * wa])
	var r := _bounds(pts)
	var ab := tb - ta
	var len2 := maxf(ab.length_squared(), 0.0001)
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, pts):
				var t := clampf((p - ta).dot(ab) / len2, 0.0, 1.0)
				var side := (p - ta).dot(nrm) / maxf(lerpf(wa, wb, t), 0.01)
				var s := 1.25 if side > 0.45 else (1.0 if side > 0.0 else 0.62)
				if real:
					s = 1.18 if side > 0.55 else (0.95 if side > 0.0 else 0.55)
					s += grain_at(x, y) * grain * 0.5
				put(x, y, col(base, s))


# ---------------------------------------------------------------- post effects

func outline(c: Color = OUTLINE, threshold: float = 0.5) -> void:
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > threshold:
				continue
			var hit := false
			if x > 0 and src.get_pixel(x - 1, y).a > threshold:
				hit = true
			elif x < w - 1 and src.get_pixel(x + 1, y).a > threshold:
				hit = true
			elif y > 0 and src.get_pixel(x, y - 1).a > threshold:
				hit = true
			elif y < h - 1 and src.get_pixel(x, y + 1).a > threshold:
				hit = true
			if hit:
				img.set_pixel(x, y, c)


func _edge_dist(src: Image, x: int, y: int) -> int:
	## 1 if the pixel touches transparency, 2 if one pixel further in, else 0.
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + o
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or src.get_pixel(q.x, q.y).a < 0.5:
			return 1
	for o in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var q: Vector2i = Vector2i(x, y) + o
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or src.get_pixel(q.x, q.y).a < 0.5:
			return 2
	return 0


func rim(amount: float = 0.4, inner: float = 0.15) -> void:
	## Soft silhouette darkening (replaces cartoon outlines): edge pixels darker, next ring slightly.
	var src := img.duplicate() as Image
	var ur := img.get_used_rect()
	for y in range(ur.position.y, ur.end.y):
		for x in range(ur.position.x, ur.end.x):
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var e := _edge_dist(src, x, y)
			if e == 1:
				img.set_pixel(x, y, Color(c.r * (1.0 - amount), c.g * (1.0 - amount), c.b * (1.0 - amount) * 1.02, c.a))
			elif e == 2 and inner > 0.0:
				img.set_pixel(x, y, Color(c.r * (1.0 - inner), c.g * (1.0 - inner), c.b * (1.0 - inner), c.a))


func grime(dirt: Color, amount: float, freq: float = 0.08, threshold: float = 0.1, streak: float = 0.0, seed_value: int = 0) -> void:
	## Noise-masked dirt/rust/rot on opaque pixels; streak > 0 stretches it vertically (drips).
	var n := FastNoiseLite.new()
	n.seed = seed_value if seed_value != 0 else rng.randi()
	n.frequency = freq
	n.fractal_octaves = 3
	var ur := img.get_used_rect()
	for y in range(ur.position.y, ur.end.y):
		for x in range(ur.position.x, ur.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var v := n.get_noise_2d(x, y * (1.0 - streak * 0.85))
			if v > threshold:
				var a := clampf((v - threshold) * 3.0, 0.0, 1.0) * amount
				var lum := c.get_luminance()
				var tgt := Color(dirt.r * (0.5 + lum), dirt.g * (0.5 + lum), dirt.b * (0.5 + lum))
				img.set_pixel(x, y, Color(lerpf(c.r, tgt.r, a), lerpf(c.g, tgt.g, a), lerpf(c.b, tgt.b, a), c.a))


func erase_ellipse(cx: float, cy: float, rx: float, ry: float) -> void:
	## Punch a transparent hole (gaps between bones, torn cloth).
	var cc := tp(Vector2(cx, cy))
	rx *= k
	ry *= k
	for y in range(int(floor(cc.y - ry)), int(ceil(cc.y + ry)) + 1):
		for x in range(int(floor(cc.x - rx)), int(ceil(cc.x + rx)) + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var dx := (x + 0.5 - cc.x) / rx
			var dy := (y + 0.5 - cc.y) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func contact_shadow(cx: float, cy: float, rx: float, ry: float, strength: float = 0.55) -> void:
	## Soft dark ellipse on the ground under a figure (drawn first).
	var cc := tp(Vector2(cx, cy))
	rx *= k
	ry *= k
	for y in range(int(floor(cc.y - ry)), int(ceil(cc.y + ry)) + 1):
		for x in range(int(floor(cc.x - rx)), int(ceil(cc.x + rx)) + 1):
			var dx := (x + 0.5 - cc.x) / rx
			var dy := (y + 0.5 - cc.y) / ry
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				put(x, y, Color(0.03, 0.025, 0.03, 1.0 if d2 < 0.55 else 0.0))


func posterize(levels: int = 24) -> void:
	var f := float(levels)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(floorf(c.r * f + 0.5) / f, floorf(c.g * f + 0.5) / f, floorf(c.b * f + 0.5) / f, c.a))


func harden_alpha(threshold: float = 0.5) -> void:
	## Sprites are alpha-cut in game: make every pixel fully opaque or fully transparent.
	var ur := img.get_used_rect()
	for y in range(ur.position.y, ur.end.y):
		for x in range(ur.position.x, ur.end.x):
			var c := img.get_pixel(x, y)
			if c.a >= threshold:
				if c.a < 1.0:
					img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			elif c.a > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func tint(c: Color, amount: float) -> void:
	for y in h:
		for x in w:
			var o := img.get_pixel(x, y)
			if o.a > 0.0:
				var n := o.lerp(Color(c.r, c.g, c.b, o.a), amount)
				img.set_pixel(x, y, n)


func blit(src: Image, x: int, y: int) -> void:
	img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))


func flip_h() -> void:
	img.flip_x()


func save(path: String) -> void:
	save_image(img, path)


static func strip(frames: Array) -> Image:
	var fw: int = frames[0].get_width()
	var fh: int = frames[0].get_height()
	var out := Image.create(fw * frames.size(), fh, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	return out


static func save_image(im: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := im.save_png(abs_path)
	if err != OK:
		push_error("save failed %s (%d)" % [path, err])


func _bounds(pts: PackedVector2Array) -> Rect2i:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for v in pts:
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
	var x0 := clampi(int(floor(mn.x)), 0, w - 1)
	var y0 := clampi(int(floor(mn.y)), 0, h - 1)
	var x1 := clampi(int(ceil(mx.x)), 0, w - 1)
	var y1 := clampi(int(ceil(mx.y)), 0, h - 1)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)
