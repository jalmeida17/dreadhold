extends SceneTree
## Monster forge generator: renders every modular monster part on the shared rig
## (tools/art/monsters/rig.gd), writes assets/sprites/monsters/parts/<layer>/<name>.png
## (768x96 strips, 8 frames of 96x96, enemy frame order) + parts.json, then composes random test
## monsters into tools/preview/ (git-ignored).
## Run:  bash tools/run_tool.sh res://tools/gen_monsters.gd 600
## Optional user args (after --): only=body,head  (re-render a subset, other layers are read back
## from disk for the previews)   combos=16   seed=4242   noparts (previews only)

const Painter := preload("res://tools/art/painter.gd")
const Rig := preload("res://tools/art/monsters/rig.gd")
const Bodies := preload("res://tools/art/monsters/bodies.gd")
const Armor := preload("res://tools/art/monsters/armor.gd")
const Heads := preload("res://tools/art/monsters/heads.gd")
const Weapons := preload("res://tools/art/monsters/weapons.gd")
const Offhand := preload("res://tools/art/monsters/offhand.gd")
const Auras := preload("res://tools/art/monsters/auras.gd")

const OUT := "res://assets/sprites/monsters/parts"
const PREVIEW := "res://tools/preview"
const ORDER := ["body", "armor", "head", "offhand", "weapon", "aura"]
const FS := 96

var parts := {}
var images := {}


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	var combos := 16
	var seed_v := 4242
	var render := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
		elif a.begins_with("combos="):
			combos = int(a.substr(7))
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		elif a == "noparts":
			render = false
	parts = {
		"body": Bodies.NAMES, "armor": Armor.NAMES, "head": Heads.NAMES,
		"offhand": Offhand.NAMES, "weapon": Weapons.NAMES, "aura": Auras.NAMES,
	}
	for layer in ORDER:
		images[layer] = {}
		for n in parts[layer]:
			var name: String = n
			var path := "%s/%s/%s.png" % [OUT, layer, name]
			if render and (only == "" or layer in only.split(",") or ("%s/%s" % [layer, name]) in only.split(",")):
				var t1 := Time.get_ticks_msec()
				var img := render_part(layer, name)
				Painter.save_image(img, path)
				images[layer][name] = img
				print("  wrote %s  %dx%d  (%d ms)" % [path, img.get_width(), img.get_height(), Time.get_ticks_msec() - t1])
			else:
				var gp := ProjectSettings.globalize_path(path)
				if FileAccess.file_exists(gp):
					images[layer][name] = Image.load_from_file(gp)
	write_manifest()
	write_previews(combos, seed_v)
	print("gen_monsters done in %d ms" % (Time.get_ticks_msec() - t0))
	quit()


# =============================================================================== rendering

func render_part(layer: String, name: String) -> Image:
	var frames: Array = []
	var key := "%s/%s" % [layer, name]
	for i in Rig.FRAMES:
		var r := Rig.frame(i)
		var p := Painter.new(FS, FS, 5000 + absi(key.hash() % 90000) + i * 131)
		p.set_real(1.0)
		p.xf = r["xf"]
		p.k = r["k"]
		var glows: Array = []
		match layer:
			"body":
				glows = Bodies.draw(name, p, r)
			"armor":
				glows = Armor.draw(name, p, r)
			"head":
				glows = Heads.draw(name, p, r)
			"offhand":
				glows = Offhand.draw(name, p, r)
			"weapon":
				glows = Weapons.draw(name, p, r)
			"aura":
				glows = Auras.draw(name, p, r)
		p.xf = Transform2D.IDENTITY
		p.k = 1.0
		p.spec = 0.0
		if layer == "body":
			var rim := Bodies.rim_amount(name)
			p.rim(rim.x, rim.y)
			Bodies.post(name, p, r)
		elif layer == "weapon":
			# thin blades and shafts would turn black under the full silhouette rim
			p.rim(0.3, 0.0)
		elif layer != "aura":
			p.rim(0.42, 0.12)
		for g in glows:
			var gp: Vector2 = g[0]
			p.glow_px(gp.x, gp.y, g[1], g[2], g[3])
		p.harden_alpha(0.5)
		frames.append(p.img)
	return Painter.strip(frames)


func write_manifest() -> void:
	var m := {
		"frame_size": FS,
		"frames": Rig.FRAMES,
		"order": ORDER,
		"parts": parts,
		"under_body": Armor.UNDER_BODY,
	}
	var f := FileAccess.open(OUT + "/parts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(m, "\t", false))
	f.close()
	print("  wrote %s/parts.json" % OUT)


# =============================================================================== previews

func compose(sel: Dictionary) -> Image:
	## Stack a selection in game order (under-body armour first).
	var out := Image.create(FS * Rig.FRAMES, FS, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var stack: Array = []
	var arm: String = sel.get("armor", "")
	if arm != "" and arm in Armor.UNDER_BODY:
		stack.append(images["armor"].get(arm))
	for layer in ORDER:
		var n: String = sel.get(layer, "")
		if n == "":
			continue
		if layer == "armor" and n in Armor.UNDER_BODY:
			continue
		stack.append(images[layer].get(n))
	for im in stack:
		if im != null:
			out.blend_rect(im, Rect2i(0, 0, out.get_width(), FS), Vector2i.ZERO)
	return out


func pick_combos(count: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var decks := {}
	for layer in ORDER:
		var d: Array = (parts[layer] as Array).duplicate()
		_shuffle(d, rng)
		decks[layer] = d
	var out: Array = []
	for i in count:
		var sel := {}
		for layer in ORDER:
			var d: Array = decks[layer]
			var idx := (i / 2) if layer == "aura" else i
			var n: String = d[idx % d.size()]
			var skip := false
			if layer == "armor" and i % 5 == 4:
				skip = true
			elif layer == "offhand" and i % 4 == 3:
				skip = true
			elif layer == "aura" and i % 2 == 1:
				skip = true
			sel[layer] = "" if skip else n
		out.append(sel)
	return out


func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _label(sel: Dictionary) -> String:
	var bits: Array = []
	for layer in ORDER:
		bits.append(sel[layer] if sel[layer] != "" else "-")
	return " + ".join(bits)


func write_previews(count: int, seed_v: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW))
	if not FileAccess.file_exists(ProjectSettings.globalize_path(PREVIEW + "/.gdignore")):
		var g := FileAccess.open(PREVIEW + "/.gdignore", FileAccess.WRITE)
		g.store_string("")
		g.close()
	# ---- every part, per layer (2x)
	var rows: Array = []
	for layer in ORDER:
		for n in parts[layer]:
			if images[layer].has(n):
				rows.append(images[layer][n])
	_sheet(rows, 2, PREVIEW + "/monster_parts.png", Color(0.32, 0.34, 0.38))
	# ---- random monsters (2x overview with the existing skeleton/ghoul on top for scale)
	var combos := pick_combos(count, seed_v)
	var strips: Array = []
	for e in ["skeleton", "ghoul"]:
		var ep := ProjectSettings.globalize_path("res://assets/sprites/enemies/%s.png" % e)
		if FileAccess.file_exists(ep):
			strips.append(Image.load_from_file(ep))
	for i in combos.size():
		var sel: Dictionary = combos[i]
		var im := compose(sel)
		strips.append(im)
		print("  combo %02d: %s   rows %s" % [i, _label(sel), bounds_report(im)])
		# 4x zoom, two rows of four frames
		var z := Image.create(4 * FS * 4 + 5 * 4, 2 * FS * 4 + 3 * 4, false, Image.FORMAT_RGBA8)
		z.fill(Color(0.3, 0.32, 0.36))
		for fi in Rig.FRAMES:
			var fr := im.get_region(Rect2i(fi * FS, 0, FS, FS))
			fr.resize(FS * 4, FS * 4, Image.INTERPOLATE_NEAREST)
			var col := fi % 4
			var row := fi / 4
			# ground line for alignment checks
			var gx := 4 + col * (FS * 4 + 4)
			var gy := 4 + row * (FS * 4 + 4)
			z.fill_rect(Rect2i(gx, gy + int(Rig.GROUND + 0.5) * 4, FS * 4, 1), Color(0.42, 0.44, 0.5))
			z.blend_rect(fr, Rect2i(0, 0, FS * 4, FS * 4), Vector2i(gx, gy))
		Painter.save_image(z, PREVIEW + "/monster_combo_%02d.png" % i)
	_sheet(strips, 2, PREVIEW + "/monster_combos.png", Color(0.13, 0.14, 0.16))
	# ---- fit matrices: every armour on every body, every head / weapon / off-hand on one body
	for b in parts["body"]:
		var rows_b: Array = []
		for a in [""] + Array(parts["armor"]):
			rows_b.append(compose({"body": b, "armor": a, "head": "skull", "offhand": "shield", "weapon": "sword", "aura": ""}))
		_sheet(rows_b, 2, PREVIEW + "/monster_matrix_%s.png" % b, Color(0.3, 0.32, 0.36))
	var rows_h: Array = []
	for h in parts["head"]:
		rows_h.append(compose({"body": "knight", "armor": "", "head": h, "offhand": "", "weapon": "mace", "aura": ""}))
	_sheet(rows_h, 2, PREVIEW + "/monster_matrix_heads.png", Color(0.3, 0.32, 0.36))
	var rows_w: Array = []
	for w in parts["weapon"]:
		rows_w.append(compose({"body": "cultist", "armor": "", "head": "hood", "offhand": "", "weapon": w, "aura": ""}))
	for o in parts["offhand"]:
		rows_w.append(compose({"body": "cultist", "armor": "", "head": "hood", "offhand": o, "weapon": "", "aura": ""}))
	_sheet(rows_w, 2, PREVIEW + "/monster_matrix_weapons.png", Color(0.3, 0.32, 0.36))
	print("  wrote previews: %s/monster_combos.png, monster_combo_00..%02d.png, monster_parts.png" % [PREVIEW, combos.size() - 1])


func _sheet(imgs: Array, scale: int, path: String, bg: Color) -> void:
	var maxw := 0
	var total := 4
	for im in imgs:
		maxw = maxi(maxw, (im as Image).get_width() * scale)
		total += (im as Image).get_height() * scale + 6
	var sheet := Image.create(maxw + 8, total + 4, false, Image.FORMAT_RGBA8)
	sheet.fill(bg)
	var y := 4
	for im in imgs:
		var c: Image = (im as Image).duplicate()
		c.resize(c.get_width() * scale, c.get_height() * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i(4, y))
		y += c.get_height() + 6
	Painter.save_image(sheet, path)


func bounds_report(sheet: Image) -> String:
	var bits: Array = []
	for i in sheet.get_width() / FS:
		var ur := sheet.get_region(Rect2i(i * FS, 0, FS, FS)).get_used_rect()
		bits.append("%d:%d-%d" % [i, ur.position.y, ur.end.y - 1])
	return " ".join(bits)
