extends RefCounted
## UI art: pixel font atlas, title logo, icons, panels, buttons, bars, HUD slab.

const Painter := preload("res://tools/art/painter.gd")
const FontData := preload("res://tools/art/font_data.gd")
const Items := preload("res://tools/art/items.gd")
const GOLD := Color(0.88, 0.67, 0.2)
const STEEL := Color(0.7, 0.72, 0.78)


# =============================================================================== font

static func font_atlas() -> Array:
	## Returns [image, metrics dictionary].
	var cols := 16
	var cw: int = FontData.CELL_W
	var ch: int = FontData.CELL_H
	var img := Image.create(cols * cw, 6 * ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var widths := {}
	for code in range(32, 127):
		var c := char(code)
		var idx := code - 32
		var ox := (idx % cols) * cw
		var oy := (idx / cols) * ch
		var rows: Array = FontData.GLYPHS.get(c, FontData.GLYPHS["?"])
		widths[str(code)] = FontData.glyph_width(c)
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] == "#":
					img.set_pixel(ox + rx, oy + ry, Color(1, 1, 1, 1))
	return [img, {"cell_w": cw, "cell_h": ch, "baseline": FontData.BASELINE, "cols": cols, "first": 32, "widths": widths}]


static func text_mask(text: String, scale: int) -> Image:
	## Rasterises text with the pixel font into a white mask at integer scale.
	var total := 0
	for i in text.length():
		total += FontData.glyph_width(text[i]) + 1
	var img := Image.create(total * scale, FontData.CELL_H * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x0 := 0
	for i in text.length():
		var rows: Array = FontData.GLYPHS.get(text[i], FontData.GLYPHS["?"])
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] == "#":
					img.fill_rect(Rect2i((x0 + rx) * scale, ry * scale, scale, scale), Color(1, 1, 1, 1))
		x0 += FontData.glyph_width(text[i]) + 1
	return img


static func logo(text: String) -> Image:
	var scale := 5
	var mask := text_mask(text, scale)
	var mw := mask.get_width()
	var mh := 7 * scale
	var pad := 8
	var p := Painter.new(mw + pad * 2, mh + pad * 2 + 14, 700)
	# decorative blade behind the letters
	var bl_y := pad + mh + 6
	p.blade(Vector2(pad - 4, bl_y), Vector2(mw + pad + 4, bl_y), 2.5, 0.3, STEEL)
	p.capsule(Vector2(pad + mw * 0.5 - 14, bl_y), Vector2(pad + mw * 0.5 + 14, bl_y), 2.0, 2.0, GOLD)
	p.ball(pad + mw * 0.5, bl_y, 4.0, 4.0, Color(0.55, 0.06, 0.08))
	for y in mh:
		for x in mw:
			if mask.get_pixel(x, y).a < 0.5:
				continue
			var t := float(y) / float(mh)
			var c := Color(1.0, 0.92, 0.55).lerp(GOLD, smoothstep(0.0, 0.45, t)).lerp(Color(0.62, 0.3, 0.06), smoothstep(0.45, 1.0, t))
			# bevel: lit top-left edges, dark bottom-right edges
			var up := y > 0 and mask.get_pixel(x, y - 1).a > 0.5
			var left := x > 0 and mask.get_pixel(x - 1, y).a > 0.5
			var down := y < mh - 1 and mask.get_pixel(x, y + 1).a > 0.5
			var right := x < mw - 1 and mask.get_pixel(x + 1, y).a > 0.5
			if not up or not left:
				c = c.lightened(0.35)
			elif not down or not right:
				c = c.darkened(0.35)
			if (x / scale + y / scale) % 2 == 0 and t > 0.5:
				c = c.darkened(0.06)
			p.img.set_pixel(x + pad, y + pad, c)
	p.outline(Color(0.12, 0.04, 0.02))
	p.outline(Color(0.0, 0.0, 0.0, 0.85), 0.3)
	return p.img


# =============================================================================== frames, panels, buttons

static func _stone_fill(p: Painter, x0: int, y0: int, w: int, h: int, base: Color, seed_value: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.12
	n.fractal_octaves = 3
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Painter.ramp(base, 0.78 + v * 0.35)
			c.a = base.a
			p.img.set_pixel(x, y, c)


static func _gold_border(p: Painter, x0: int, y0: int, w: int, h: int, col: Color = GOLD) -> void:
	for x in range(x0, x0 + w):
		p.img.set_pixel(x, y0, Color(0.05, 0.03, 0.03))
		p.img.set_pixel(x, y0 + h - 1, Color(0.05, 0.03, 0.03))
		p.img.set_pixel(x, y0 + 1, col.lightened(0.3))
		p.img.set_pixel(x, y0 + h - 2, col.darkened(0.45))
	for y in range(y0, y0 + h):
		p.img.set_pixel(x0, y, Color(0.05, 0.03, 0.03))
		p.img.set_pixel(x0 + w - 1, y, Color(0.05, 0.03, 0.03))
		if y > y0 and y < y0 + h - 1:
			p.img.set_pixel(x0 + 1, y, col.lightened(0.1))
			p.img.set_pixel(x0 + w - 2, y, col.darkened(0.35))
	for y in range(y0 + 2, y0 + h - 2):
		p.img.set_pixel(x0 + 2, y, Color(0.08, 0.05, 0.05))
		p.img.set_pixel(x0 + w - 3, y, Color(0.08, 0.05, 0.05))
	for x in range(x0 + 2, x0 + w - 2):
		p.img.set_pixel(x, y0 + 2, Color(0.08, 0.05, 0.05))
		p.img.set_pixel(x, y0 + h - 3, Color(0.08, 0.05, 0.05))


static func panel(base: Color, seed_value: int) -> Image:
	var p := Painter.new(32, 32, seed_value)
	_stone_fill(p, 0, 0, 32, 32, base, seed_value)
	_gold_border(p, 0, 0, 32, 32)
	for c in [Vector2(4, 4), Vector2(27, 4), Vector2(4, 27), Vector2(27, 27)]:
		p.ball(c.x + 0.5, c.y + 0.5, 1.8, 1.8, GOLD)
	return p.img


static func button(state: int) -> Image:
	# 0 normal, 1 hover, 2 pressed, 3 disabled
	var p := Painter.new(32, 16, 710 + state)
	var base: Color = [Color(0.25, 0.22, 0.26), Color(0.38, 0.27, 0.2), Color(0.16, 0.13, 0.15), Color(0.17, 0.17, 0.18)][state]
	var trim: Color = [GOLD.darkened(0.15), GOLD.lightened(0.25), GOLD.darkened(0.35), Color(0.4, 0.38, 0.36)][state]
	_stone_fill(p, 0, 0, 32, 16, base, 33)
	_gold_border(p, 0, 0, 32, 16, trim)
	if state == 1:
		for x in range(3, 29):
			p.img.set_pixel(x, 3, p.img.get_pixel(x, 3).lightened(0.2))
	return p.img


static func card(rarity_col: Color) -> Image:
	var p := Painter.new(48, 64, 720)
	_stone_fill(p, 0, 0, 48, 64, Color(0.16, 0.13, 0.17), 720)
	_gold_border(p, 0, 0, 48, 64, rarity_col)
	for c in [Vector2(5, 5), Vector2(42, 5), Vector2(5, 58), Vector2(42, 58)]:
		p.ball(c.x + 0.5, c.y + 0.5, 2.0, 2.0, rarity_col)
	return p.img


static func bar_bg() -> Image:
	var p := Painter.new(16, 8, 730)
	p.fill(Color(0.04, 0.03, 0.04))
	for x in 16:
		p.img.set_pixel(x, 0, Color(0.0, 0.0, 0.0))
		p.img.set_pixel(x, 7, GOLD.darkened(0.45))
	for y in 8:
		p.img.set_pixel(0, y, Color(0.0, 0.0, 0.0))
		p.img.set_pixel(15, y, GOLD.darkened(0.45))
	return p.img


static func bar_fill(col: Color) -> Image:
	var p := Painter.new(16, 8, 731)
	for y in 8:
		var t := float(y) / 7.0
		var c := col.lightened(0.45).lerp(col, smoothstep(0.0, 0.35, t)).lerp(col.darkened(0.45), smoothstep(0.5, 1.0, t))
		for x in 16:
			p.img.set_pixel(x, y, c)
	return p.img


static func hud_slab() -> Image:
	var w := 640
	var h := 48
	var p := Painter.new(w, h, 740)
	_stone_fill(p, 0, 0, w, h, Color(0.25, 0.23, 0.27), 740)
	# carved block seams
	for x in range(0, w, 80):
		for y in range(6, h):
			p.img.set_pixel(x, y, Color(0.08, 0.06, 0.08))
			p.img.set_pixel(x + 1, y, p.img.get_pixel(x + 1, y).lightened(0.12))
	# gold top trim
	for x in w:
		p.img.set_pixel(x, 0, Color(0.05, 0.03, 0.03))
		p.img.set_pixel(x, 1, GOLD.lightened(0.3))
		p.img.set_pixel(x, 2, GOLD)
		p.img.set_pixel(x, 3, GOLD.darkened(0.4))
		p.img.set_pixel(x, 4, Color(0.05, 0.03, 0.03))
	for k in range(8, w, 16):
		p.img.set_pixel(k, 2, GOLD.lightened(0.5))
	# central portrait socket ornament
	var cx := w / 2
	p.flat_poly(PackedVector2Array([Vector2(cx - 34, 4), Vector2(cx + 34, 4), Vector2(cx + 30, 47), Vector2(cx - 30, 47)]), Color(0.3, 0.27, 0.3), Vector3(0, -0.3, 1))
	_gold_border(p, cx - 24, 3, 48, 45)
	for side in [-1.0, 1.0]:
		p.poly(PackedVector2Array([Vector2(cx + side * 25, 2), Vector2(cx + side * 40, 2), Vector2(cx + side * 25, 18)]), GOLD.darkened(0.1))
		p.ball(cx + side * 30, 26, 2.5, 2.5, Color(0.6, 0.06, 0.08))
	return p.img


static func crosshair() -> Image:
	var p := Painter.new(11, 11, 750)
	var c := Color(1.0, 0.9, 0.6, 0.9)
	for k in [0, 1, 2, 8, 9, 10]:
		p.img.set_pixel(5, k, c)
		p.img.set_pixel(k, 5, c)
	p.img.set_pixel(5, 5, Color(1, 1, 1, 1))
	return p.img


# =============================================================================== icons (24x24)

static func icon_frame(bg: Color, symbol: Image) -> Image:
	var p := Painter.new(24, 24, 760)
	for y in 24:
		for x in 24:
			var d := Vector2(x - 11.5, y - 11.5).length() / 16.0
			p.img.set_pixel(x, y, bg.lightened(0.15).lerp(bg.darkened(0.7), clampf(d, 0.0, 1.0)))
	p.img.blend_rect(symbol, Rect2i(0, 0, 24, 24), Vector2i.ZERO)
	for x in 24:
		p.img.set_pixel(x, 0, Color(0.02, 0.02, 0.02))
		p.img.set_pixel(x, 23, Color(0.02, 0.02, 0.02))
		p.img.set_pixel(x, 1, GOLD.lightened(0.2))
		p.img.set_pixel(x, 22, GOLD.darkened(0.5))
	for y in 24:
		p.img.set_pixel(0, y, Color(0.02, 0.02, 0.02))
		p.img.set_pixel(23, y, Color(0.02, 0.02, 0.02))
		if y > 0 and y < 23:
			p.img.set_pixel(1, y, GOLD)
			p.img.set_pixel(22, y, GOLD.darkened(0.4))
	return p.img


static func _sym() -> Painter:
	var p := Painter.new(24, 24, 770)
	p.dither = 0.3
	return p


static func icon(name: String) -> Image:
	var p := _sym()
	var bg := Color(0.3, 0.3, 0.3)
	var glows: Array = []
	match name:
		"cleave":
			bg = Color(0.5, 0.1, 0.08)
			p.capsule(Vector2(5, 20), Vector2(15, 7), 1.3, 1.1, Color(0.45, 0.28, 0.14))
			p.flat_poly(PackedVector2Array([Vector2(13, 6), Vector2(19, 3), Vector2(21, 10), Vector2(16, 11)]), STEEL, Vector3(-0.4, -0.6, 1))
			glows = [[Vector2(16, 16), 6.0, Color(1, 0.9, 0.8), 0.4]]
		"spin":
			bg = Color(0.55, 0.25, 0.05)
			for k in 3:
				var a := float(k) / 3.0 * TAU
				var c := Vector2(12, 12) + Vector2(cos(a), sin(a)) * 5.0
				p.flat_poly(PackedVector2Array([c, c + Vector2(cos(a + 1.2), sin(a + 1.2)) * 7.0, c + Vector2(cos(a + 0.4), sin(a + 0.4)) * 5.0]), STEEL, Vector3(-0.4, -0.6, 1))
			p.ball(12, 12, 2.5, 2.5, GOLD)
		"charge":
			bg = Color(0.45, 0.32, 0.12)
			p.ball(14, 12, 6, 7, Color(0.55, 0.56, 0.62))
			p.capsule(Vector2(10, 16), Vector2(18, 16), 1.2, 1.2, GOLD)
			for k in 3:
				p.line(Vector2(2, 7 + k * 5), Vector2(7, 7 + k * 5), Color(1, 0.9, 0.6))
		"fireball":
			bg = Color(0.4, 0.08, 0.04)
			glows = [[Vector2(12, 12), 10.0, Color(1, 0.5, 0.1), 0.8]]
			Items.orb(p, 12, 12, 5.5, 0.4, Items.FIRE)
		"frostnova":
			bg = Color(0.08, 0.22, 0.45)
			for k in 6:
				var a := float(k) / 6.0 * TAU
				var d := Vector2(cos(a), sin(a))
				p.line(Vector2(12, 12), Vector2(12, 12) + d * 9.0, Color(0.85, 0.97, 1.0), 1.5)
				p.line(Vector2(12, 12) + d * 6.0, Vector2(12, 12) + d * 6.0 + Vector2(cos(a + 0.8), sin(a + 0.8)) * 3.0, Color(0.7, 0.9, 1.0))
			glows = [[Vector2(12, 12), 6.0, Color(0.6, 0.9, 1.0), 0.6]]
		"blink":
			bg = Color(0.3, 0.1, 0.45)
			for k in 24:
				var t := float(k) / 23.0
				var a := t * 9.0
				p.put(int(12 + cos(a) * t * 9.0), int(12 + sin(a) * t * 9.0), Color(0.9, 0.7, 1.0))
			glows = [[Vector2(12, 12), 5.0, Color(1, 0.85, 1), 0.9]]
		"shot":
			bg = Color(0.12, 0.3, 0.1)
			p.capsule(Vector2(4, 20), Vector2(18, 6), 0.9, 0.9, Color(0.6, 0.45, 0.28))
			p.flat_poly(PackedVector2Array([Vector2(16, 4), Vector2(21, 3), Vector2(20, 8)]), STEEL, Vector3(-0.3, -0.6, 1))
			p.line(Vector2(4, 20), Vector2(4, 16), Color(0.8, 0.2, 0.15))
			p.line(Vector2(4, 20), Vector2(8, 20), Color(0.8, 0.2, 0.15))
		"volley":
			bg = Color(0.15, 0.35, 0.12)
			for k in 3:
				var o := Vector2(k * 4 - 4, -k * 2 + 2)
				p.capsule(Vector2(4, 20) + o, Vector2(16, 8) + o, 0.8, 0.8, Color(0.6, 0.45, 0.28))
				p.flat_poly(PackedVector2Array([Vector2(15, 6) + o, Vector2(19, 5) + o, Vector2(18, 9) + o]), STEEL, Vector3(-0.3, -0.6, 1))
		"dash":
			bg = Color(0.08, 0.32, 0.32)
			for k in 5:
				p.capsule(Vector2(6 + k * 2, 18 - k), Vector2(16 + k, 5 + k * 2), 1.6 - k * 0.2, 0.6, Color(0.85, 0.9, 0.85))
		"potion":
			bg = Color(0.35, 0.06, 0.08)
			var pi := Items.potion(Color(0.85, 0.1, 0.12))
			p.img.blend_rect(pi, Rect2i(0, 0, 16, 20), Vector2i(4, 2))
		"damage":
			bg = Color(0.5, 0.08, 0.06)
			p.blade(Vector2(6, 18), Vector2(19, 5), 1.8, 0.5, STEEL)
			p.capsule(Vector2(4, 14), Vector2(10, 20), 1.1, 1.1, GOLD)
			p.capsule(Vector2(3, 21), Vector2(6, 18), 1.2, 1.2, Color(0.4, 0.25, 0.12))
		"health":
			bg = Color(0.45, 0.05, 0.1)
			p.ball(9, 10, 4.5, 4.5, Color(0.9, 0.12, 0.15))
			p.ball(15, 10, 4.5, 4.5, Color(0.9, 0.12, 0.15))
			p.poly(PackedVector2Array([Vector2(4.6, 11.5), Vector2(19.4, 11.5), Vector2(12, 20)]), Color(0.8, 0.1, 0.13))
		"speed":
			bg = Color(0.1, 0.35, 0.35)
			p.capsule(Vector2(9, 6), Vector2(10, 16), 2.6, 2.4, Color(0.45, 0.3, 0.18))
			p.ball(13, 17, 5, 2.6, Color(0.45, 0.3, 0.18))
			for k in 3:
				p.capsule(Vector2(12, 8 + k * 2), Vector2(19, 5 + k * 3), 1.0, 0.5, Color(0.9, 0.95, 1.0))
		"cooldown":
			bg = Color(0.1, 0.2, 0.45)
			p.capsule(Vector2(6, 4), Vector2(18, 4), 1.2, 1.2, GOLD)
			p.capsule(Vector2(6, 20), Vector2(18, 20), 1.2, 1.2, GOLD)
			p.poly(PackedVector2Array([Vector2(7, 5), Vector2(17, 5), Vector2(12, 12), Vector2(17, 19), Vector2(7, 19), Vector2(12, 12)]), Color(0.75, 0.85, 0.95, 0.8))
			p.poly(PackedVector2Array([Vector2(9, 17), Vector2(15, 17), Vector2(12, 13)]), Color(0.95, 0.85, 0.5))
		"regen":
			bg = Color(0.1, 0.38, 0.12)
			p.ball(12, 14, 5.5, 5.5, Color(0.45, 0.95, 0.4))
			p.poly(PackedVector2Array([Vector2(7, 12), Vector2(17, 12), Vector2(12, 3)]), Color(0.45, 0.95, 0.4))
			p.rect(11, 11, 2, 7, Color(1, 1, 1))
			p.rect(9, 13, 6, 2, Color(1, 1, 1))
		"lifesteal":
			bg = Color(0.3, 0.02, 0.06)
			p.poly(PackedVector2Array([Vector2(6, 4), Vector2(11, 4), Vector2(9, 15)]), Color(0.95, 0.92, 0.85))
			p.poly(PackedVector2Array([Vector2(13, 4), Vector2(18, 4), Vector2(15, 15)]), Color(0.95, 0.92, 0.85))
			p.ball(12, 19, 2.5, 2.5, Color(0.85, 0.05, 0.08))
		"crit":
			bg = Color(0.5, 0.4, 0.05)
			for k in 8:
				var a := float(k) / 8.0 * TAU
				var r := 9.0 if k % 2 == 0 else 5.0
				p.line(Vector2(12, 12), Vector2(12, 12) + Vector2(cos(a), sin(a)) * r, Color(1, 0.95, 0.6), 1.5)
			glows = [[Vector2(12, 12), 5.0, Color(1, 1, 0.8), 0.9]]
		"armor":
			bg = Color(0.25, 0.27, 0.32)
			p.cyl_poly(PackedVector2Array([Vector2(5, 4), Vector2(19, 4), Vector2(19, 12), Vector2(12, 21), Vector2(5, 12)]), Color(0.6, 0.62, 0.68), 12, 7)
			p.line(Vector2(12, 5), Vector2(12, 19), GOLD)
			p.line(Vector2(6, 9), Vector2(18, 9), GOLD)
		"resource":
			bg = Color(0.18, 0.15, 0.45)
			p.flat_poly(PackedVector2Array([Vector2(12, 3), Vector2(18, 10), Vector2(12, 21), Vector2(6, 10)]), Color(0.5, 0.6, 1.0), Vector3(-0.4, -0.5, 1))
			p.flat_poly(PackedVector2Array([Vector2(12, 3), Vector2(18, 10), Vector2(12, 12)]), Color(0.75, 0.85, 1.0), Vector3(-0.4, -0.5, 1))
			glows = [[Vector2(12, 11), 6.0, Color(0.6, 0.7, 1.0), 0.6]]
		"gold":
			bg = Color(0.4, 0.3, 0.05)
			var gs := Items.gold_sheet()
			p.img.blend_rect(gs, Rect2i(0, 0, 16, 16), Vector2i(4, 4))
		"area":
			bg = Color(0.5, 0.2, 0.05)
			for k in 20:
				var a := float(k) / 20.0 * TAU
				p.ball(12 + cos(a) * 7.5, 12 + sin(a) * 7.5, 1.3, 1.3, Color(1, 0.7, 0.3))
			glows = [[Vector2(12, 12), 5.0, Color(1, 0.6, 0.2), 0.8]]
		"skull":
			bg = Color(0.15, 0.15, 0.15)
			p.ball(12, 10, 6, 6, Color(0.86, 0.81, 0.64))
			p.ball(12, 16, 3.5, 2.2, Color(0.86, 0.81, 0.64))
			p.ball(9.5, 10, 1.6, 1.8, Color(0.08, 0.05, 0.07))
			p.ball(14.5, 10, 1.6, 1.8, Color(0.08, 0.05, 0.07))
	p.outline()
	for g in glows:
		p.glow(g[0].x, g[0].y, g[1], g[2], g[3])
	return icon_frame(bg, p.img)


static func app_icon() -> Image:
	var p := Painter.new(64, 64, 790)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 30).length() / 40.0
			p.img.set_pixel(x, y, Color(0.35, 0.08, 0.1).lerp(Color(0.04, 0.02, 0.04), clampf(d, 0, 1)))
	p.ball(32, 28, 15, 16, Color(0.86, 0.81, 0.64))
	p.ball(32, 42, 9, 6, Color(0.86, 0.81, 0.64))
	p.ball(26, 29, 4.2, 4.8, Color(0.06, 0.04, 0.06))
	p.ball(38, 29, 4.2, 4.8, Color(0.06, 0.04, 0.06))
	p.poly(PackedVector2Array([Vector2(30, 37), Vector2(34, 37), Vector2(32, 33)]), Color(0.1, 0.06, 0.06))
	for k in 5:
		p.rect(25 + k * 3, 45, 2, 3, Color(0.95, 0.92, 0.85))
	p.capsule(Vector2(16, 14), Vector2(48, 14), 3.0, 3.0, GOLD)
	for k in 5:
		var x := 18 + k * 7
		p.poly(PackedVector2Array([Vector2(x - 3, 13), Vector2(x + 3, 13), Vector2(x, 2 + absi(k - 2) * 2)]), GOLD)
	p.outline()
	p.glow(26, 29, 5, Color(0.5, 1.0, 0.45), 0.9)
	p.glow(38, 29, 5, Color(0.5, 1.0, 0.45), 0.9)
	return p.img
