extends SceneTree
## Generates every visual asset of the game (textures, sprites, weapons, UI, font).
## Run:  Godot --headless --path . --script res://tools/gen_art.gd
## Optional: -- only=textures,creatures,items,ui   to regenerate a subset.

const Painter := preload("res://tools/art/painter.gd")
const Tex := preload("res://tools/art/textures.gd")
const Creatures := preload("res://tools/art/creatures.gd")
const Items := preload("res://tools/art/items.gd")
const UIArt := preload("res://tools/art/ui_art.gd")
const Weapons := preload("res://tools/art/weapons_fp.gd")
const Props := preload("res://tools/art/props_real.gd")
const Npc := preload("res://tools/art/npc.gd")
const Bosses2 := preload("res://tools/art/bosses2.gd")
const Tex2 := preload("res://tools/art/textures2.gd")
const Props2 := preload("res://tools/art/props2.gd")
const Champions := preload("res://tools/art/champions.gd")
const Forge := preload("res://tools/art/forge_weapons.gd")

var previews := {}


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	var all := only == ""
	if all or "textures" in only:
		gen_textures()
		print("  [t] textures %d ms" % (Time.get_ticks_msec() - t0))
	if all or "creatures" in only:
		gen_creatures()
		print("  [t] creatures %d ms" % (Time.get_ticks_msec() - t0))
	if all or "items" in only:
		gen_items()
		print("  [t] items %d ms" % (Time.get_ticks_msec() - t0))
	if all or "mappack" in only:
		gen_mappack()
		print("  [t] mappack %d ms" % (Time.get_ticks_msec() - t0))
	if all or "bosses" in only:
		gen_bosses()
		print("  [t] bosses %d ms" % (Time.get_ticks_msec() - t0))
	if all or "ui" in only:
		gen_ui()
		print("  [t] ui %d ms" % (Time.get_ticks_msec() - t0))
	if all or "champions" in only:
		gen_champions()
		print("  [t] champions %d ms" % (Time.get_ticks_msec() - t0))
	if all or "forge" in only:
		gen_forge()
		print("  [t] forge %d ms" % (Time.get_ticks_msec() - t0))
	write_previews()
	print("gen_art done in %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func save(img: Image, path: String, group: String = "") -> void:
	Painter.save_image(img, path)
	if group != "":
		if not previews.has(group):
			previews[group] = []
		previews[group].append(img)
	print("  wrote ", path, "  ", img.get_width(), "x", img.get_height())


func gen_textures() -> void:
	print("[textures]")
	save(Tex.wall_stone(11, 0.0), "res://assets/textures/wall_stone.png", "textures")
	save(Tex.wall_stone(12, 0.75), "res://assets/textures/wall_moss.png", "textures")
	save(Tex.wall_dark(13), "res://assets/textures/wall_dark.png", "textures")
	save(Tex.wall_banner(14), "res://assets/textures/wall_banner.png", "textures")
	save(Tex.wall_gate(15), "res://assets/textures/wall_gate.png", "textures")
	var rune := Tex.wall_rune(16)
	save(rune[0], "res://assets/textures/wall_rune.png", "textures")
	save(rune[1], "res://assets/textures/wall_rune_emit.png", "textures")
	save(Tex.floor_flagstone(21), "res://assets/textures/floor_flagstone.png", "textures")
	save(Tex.floor_cobble(22), "res://assets/textures/floor_cobble.png", "textures")
	save(Tex.floor_dirt(23), "res://assets/textures/floor_dirt.png", "textures")
	save(Tex.ceiling_wood(24), "res://assets/textures/ceiling_wood.png", "textures")
	var sky := Tex.sky(31)
	Painter.save_image(sky, "res://assets/textures/sky.png")
	Painter.save_image(sky, "res://tools/preview/sky.png")


func gen_creatures() -> void:
	print("[creatures]")
	save(Creatures.build_sheet("skeleton", 96, Creatures.POSES), "res://assets/sprites/enemies/skeleton.png", "enemies")
	save(Creatures.build_sheet("archer", 96, Creatures.POSES), "res://assets/sprites/enemies/archer.png", "enemies")
	save(Creatures.build_sheet("ghoul", 96, Creatures.POSES), "res://assets/sprites/enemies/ghoul.png", "enemies")
	save(Creatures.build_sheet("cultist", 96, Creatures.POSES), "res://assets/sprites/enemies/cultist.png", "enemies")
	save(Creatures.build_sheet("brute", 144, Creatures.POSES), "res://assets/sprites/enemies/brute.png", "enemies_big")
	var boss_poses := Creatures.POSES.duplicate()
	boss_poses.append({"cast": true})
	save(Creatures.build_sheet("boss", 192, boss_poses), "res://assets/sprites/enemies/boss.png", "enemies_big")


func gen_items() -> void:
	print("[items]")
	save(Props.torch_sheet(), "res://assets/sprites/props/torch.png", "props")
	save(Props.brazier_sheet(), "res://assets/sprites/props/brazier.png", "props")
	save(Props.tree(), "res://assets/sprites/props/tree.png", "props")
	save(Props.graves_sheet(), "res://assets/sprites/props/graves.png", "props")
	save(Props.bones_prop(), "res://assets/sprites/props/bones.png", "props")
	save(Props.barrel(), "res://assets/sprites/props/barrel.png", "props")
	save(Props.statue(), "res://assets/sprites/props/statue.png", "props")
	save(Props.altar_sheet(), "res://assets/sprites/props/altar.png", "props")
	save(Props.gold_sheet(), "res://assets/sprites/pickups/gold.png", "props")
	save(Props.potion(Color(0.6, 0.06, 0.08)), "res://assets/sprites/pickups/potion_red.png", "props")
	save(Props.potion(Color(0.14, 0.28, 0.7)), "res://assets/sprites/pickups/potion_blue.png", "props")
	save(Props.orb_sheet(48, 4, Props.FIRE6, 11.0, Color(1, 0.45, 0.1)), "res://assets/sprites/fx/fireball.png", "fx")
	save(Props.explosion_sheet(), "res://assets/sprites/fx/explosion.png", "fx")
	save(Props.frost_sheet(), "res://assets/sprites/fx/frost.png", "fx")
	save(Props.orb_sheet(32, 4, Props.SHADOW6, 7.5, Color(0.55, 0.2, 0.95)), "res://assets/sprites/fx/shadow_bolt.png", "fx")
	save(Props.orb_sheet(40, 4, Props.SOUL6, 9.5, Color(0.3, 1.0, 0.4)), "res://assets/sprites/fx/soul_bolt.png", "fx")
	save(Props.burst_sheet(48, Color(0.42, 0.03, 0.04), 900, true), "res://assets/sprites/fx/blood.png", "fx")
	save(Props.burst_sheet(48, Color(0.55, 0.52, 0.46), 901, false), "res://assets/sprites/fx/dust.png", "fx")
	save(Props.portal_sheet(), "res://assets/sprites/fx/portal.png", "fx")
	save(Props.ring_decal(), "res://assets/sprites/fx/ring.png", "fx")
	save(Weapons.axe_frames(), "res://assets/weapons/axe.png", "weapons")
	save(Weapons.staff_frames(), "res://assets/weapons/staff.png", "weapons")
	save(Weapons.bow_frames(), "res://assets/weapons/bow.png", "weapons")
	for tier in [2, 3]:
		save(Weapons.axe_frames(tier), "res://assets/weapons/axe_%d.png" % tier, "weapons_tiers")
		save(Weapons.staff_frames(tier), "res://assets/weapons/staff_%d.png" % tier, "weapons_tiers")
		save(Weapons.bow_frames(tier), "res://assets/weapons/bow_%d.png" % tier, "weapons_tiers")
	save(Weapons.torch_offhand_frames(), "res://assets/weapons/torch_offhand.png", "weapons_tiers")
	for k in ["warrior", "mage", "hunter"]:
		save(Props.portrait_sheet(k), "res://assets/ui/portrait_%s.png" % k, "portraits")
	save(Props.boss_portrait(), "res://assets/ui/portrait_boss.png", "portraits")
	save(Props.pedestal(), "res://assets/sprites/props/pedestal.png", "props")
	save(Npc.goblin_sheet(), "res://assets/sprites/npc/goblin.png", "npc")
	save(Npc.goblin_portrait(), "res://assets/ui/portrait_goblin.png", "portraits")


func gen_mappack() -> void:
	print("[mappack]")
	save(Tex2.wall_wood(51), "res://assets/textures/wall_wood.png", "textures2")
	save(Tex2.wall_cathedral(52), "res://assets/textures/wall_cathedral.png", "textures2")
	save(Tex2.wall_bone(53), "res://assets/textures/wall_bone.png", "textures2")
	save(Tex2.wall_ice(54), "res://assets/textures/wall_ice.png", "textures2")
	var obs := Tex2.wall_obsidian(55)
	save(obs[0], "res://assets/textures/wall_obsidian.png", "textures2")
	save(obs[1], "res://assets/textures/wall_obsidian_emit.png", "textures2")
	save(Tex2.floor_marble(61), "res://assets/textures/floor_marble.png", "textures2")
	save(Tex2.floor_snow(62), "res://assets/textures/floor_snow.png", "textures2")
	var lava := Tex2.floor_lava(63)
	save(lava[0], "res://assets/textures/floor_lava.png", "textures2")
	save(lava[1], "res://assets/textures/floor_lava_emit.png", "textures2")
	save(Tex2.floor_sludge(64), "res://assets/textures/floor_sludge.png", "textures2")
	save(Tex2.ceiling_stone(65), "res://assets/textures/ceiling_stone.png", "textures2")
	save(Props2.sarcophagus(), "res://assets/sprites/props/sarcophagus.png", "props2")
	save(Props2.well(), "res://assets/sprites/props/well.png", "props2")
	save(Props2.fence(), "res://assets/sprites/props/fence.png", "props2")
	save(Props2.crystal(), "res://assets/sprites/props/crystal.png", "props2")
	save(Props2.obsidian_spike(), "res://assets/sprites/props/obsidian_spike.png", "props2")
	save(Props2.candles_sheet(), "res://assets/sprites/props/candles.png", "props2")
	save(Props2.cauldron_sheet(), "res://assets/sprites/props/cauldron.png", "props2")
	save(Props2.acid_pool(), "res://assets/sprites/fx/acid_pool.png", "props2")
	save(Props2.meteor_sheet(), "res://assets/sprites/fx/meteor.png", "props2")


func gen_bosses() -> void:
	print("[bosses]")
	for k in ["rot", "cinder", "rime"]:
		save(Bosses2.build_sheet(k), "res://assets/sprites/enemies/boss_%s.png" % k, "bosses")
		save(Bosses2.portrait(k), "res://assets/ui/portrait_boss_%s.png" % k, "boss_portraits")


func gen_champions() -> void:
	## Co-op partner billboards (one 8-frame 96x96 strip per class) + a comparison preview
	## against two enemy sheets (tools/preview/champions_vs_enemies.png).
	print("[champions]")
	for k in ["warrior", "mage", "hunter"]:
		var sheet := Champions.build_sheet(k)
		save(sheet, "res://assets/sprites/players/%s.png" % k, "champions")
		print("    rows ", Champions.bounds_report(sheet))
	for e in ["skeleton", "cultist"]:
		var path := ProjectSettings.globalize_path("res://assets/sprites/enemies/%s.png" % e)
		if FileAccess.file_exists(path):
			if not previews.has("champions_vs_enemies"):
				previews["champions_vs_enemies"] = []
			var eimg := Image.load_from_file(path)
			previews["champions_vs_enemies"].append(eimg)
			print("    %s rows " % e, Champions.bounds_report(eimg))
	if previews.has("champions_vs_enemies"):
		for im in previews["champions"]:
			previews["champions_vs_enemies"].append(im)


func gen_forge() -> void:
	## Weapon forge base weapons (neutral palette) + tint masks, plus preview sheets in
	## tools/preview/ (forge_sheets, forge_masks, forge_tints_<class>: shader formula applied).
	## Optional subset while iterating: -- only=forge forge=sword,crossbow
	print("[forge]")
	var kinds: Array = Forge.ALL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("forge="):
			kinds = Array(a.substr(6).split(","))
	var built: Array = []
	for k in kinds:
		var r: Array = Forge.build(k)
		save(r[0], "res://assets/weapons/forge/%s.png" % k)
		save(r[1], "res://assets/weapons/forge/%s_mask.png" % k)
		built.append([k, r[0], r[1]])
	Forge.write_previews(built, "res://tools/preview")


func gen_ui() -> void:
	print("[ui]")
	var fa := UIArt.font_atlas()
	save(fa[0], "res://assets/fonts/pixel_font.png", "ui")
	var f := FileAccess.open("res://assets/fonts/pixel_font.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(fa[1], "\t"))
	f.close()
	save(UIArt.logo("DREADHOLD"), "res://assets/ui/logo.png", "ui")
	save(UIArt.panel(Color(0.2, 0.18, 0.22), 701), "res://assets/ui/panel.png", "ui")
	for i in 4:
		save(UIArt.button(i), "res://assets/ui/button_%s.png" % ["normal", "hover", "pressed", "disabled"][i], "ui")
	var rar := {"common": Color(0.7, 0.7, 0.7), "rare": Color(0.3, 0.55, 1.0), "epic": Color(0.7, 0.35, 1.0), "legendary": Color(1.0, 0.55, 0.1)}
	for r in rar:
		save(UIArt.card(rar[r]), "res://assets/ui/card_%s.png" % r, "ui")
	save(UIArt.bar_bg(), "res://assets/ui/bar_bg.png", "ui")
	var bars := {"hp": Color(0.75, 0.08, 0.1), "rage": Color(0.85, 0.3, 0.05), "mana": Color(0.15, 0.4, 0.95), "focus": Color(0.75, 0.75, 0.15), "boss": Color(0.35, 0.8, 0.3), "xp": Color(0.6, 0.3, 0.9)}
	for b in bars:
		save(UIArt.bar_fill(bars[b]), "res://assets/ui/bar_%s.png" % b, "ui")
	save(UIArt.hud_slab(), "res://assets/ui/hud_slab.png")
	Painter.save_image(UIArt.hud_slab(), "res://tools/preview/hud_slab.png")
	save(UIArt.crosshair(), "res://assets/ui/crosshair.png", "ui")
	save(UIArt.app_icon(), "res://assets/ui/icon.png", "ui")
	for n in ["cleave", "spin", "charge", "fireball", "frostnova", "blink", "shot", "volley", "dash", "potion",
			"damage", "health", "speed", "cooldown", "regen", "lifesteal", "crit", "armor", "resource", "gold", "area", "skull"]:
		save(UIArt.icon(n), "res://assets/ui/icons/%s.png" % n, "icons")


func write_previews() -> void:
	var gd := ProjectSettings.globalize_path("res://tools/preview")
	DirAccess.make_dir_recursive_absolute(gd)
	var f := FileAccess.open("res://tools/preview/.gdignore", FileAccess.WRITE)
	f.store_string("")
	f.close()
	for group in previews:
		var imgs: Array = previews[group]
		var scale: int = {"champions_vs_enemies": 2, "enemies": 2, "enemies_big": 1, "bosses": 1, "weapons_tiers": 1, "textures2": 2, "props2": 2, "weapons": 1, "textures": 2, "props": 2, "fx": 2}.get(group, 3)
		var maxw := 0
		var total_h := 0
		var flow: bool = group in ["icons", "portraits", "props", "fx", "ui", "textures", "textures2", "props2", "boss_portraits"]
		var sheet: Image
		if flow:
			# wrap images in rows up to 1200px wide
			var x := 4
			var y := 4
			var row_h := 0
			var places: Array = []
			for im in imgs:
				var w: int = im.get_width() * scale
				var h: int = im.get_height() * scale
				if x + w > 1400 and x > 4:
					x = 4
					y += row_h + 6
					row_h = 0
				places.append(Vector2i(x, y))
				x += w + 6
				row_h = maxi(row_h, h)
				maxw = maxi(maxw, x)
			total_h = y + row_h + 4
			sheet = Image.create(maxw + 4, total_h, false, Image.FORMAT_RGBA8)
			sheet.fill(Color(0.13, 0.14, 0.16))
			for i in imgs.size():
				var im: Image = (imgs[i] as Image).duplicate()
				im.resize(im.get_width() * scale, im.get_height() * scale, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), places[i])
		else:
			for im in imgs:
				maxw = maxi(maxw, im.get_width() * scale)
				total_h += im.get_height() * scale + 6
			sheet = Image.create(maxw + 8, total_h + 8, false, Image.FORMAT_RGBA8)
			sheet.fill(Color(0.13, 0.14, 0.16))
			var y := 4
			for im in imgs:
				var c: Image = (im as Image).duplicate()
				c.resize(c.get_width() * scale, c.get_height() * scale, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i(4, y))
				y += c.get_height() + 6
		Painter.save_image(sheet, "res://tools/preview/%s.png" % group)
