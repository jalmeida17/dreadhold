extends CanvasLayer
## In-game HUD in the spirit of classic RTS consoles (all original art):
## top resource bar + night dial, bottom console (minimap, living portrait, info panel,
## inventory, command card), boss plate with phylacteries, black-market prompt, banners.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Boons := preload("res://scripts/data/boons.gd")
const CommandSlot := preload("res://scripts/ui/widgets/command_slot.gd")
const Minimap := preload("res://scripts/ui/widgets/minimap.gd")
const NightDial := preload("res://scripts/ui/widgets/night_dial.gd")

const W := 1280
const H := 720
const CONSOLE_Y := 560

var player: Node
var director: Node
var root: Control
var weapon: Sprite2D
var crosshair: TextureRect
var blood: TextureRect
var dark: TextureRect
var flash_rect: ColorRect
var fade_rect: ColorRect
var portrait: TextureRect
var _portrait_frames: Array = []
var hp_text: Label
var res_text: Label
var name_label: Label
var stat_labels: Array = []
var hp_bar: ProgressBar
var hp_bar_text: Label
var res_bar: ProgressBar
var res_bar_text: Label
var inv_slots: Array = []
var cmd_slots: Array = []
var minimap: Control
var dial: Control
var night_label: Label
var foes_label: Label
var gold_label: Label
var kills_label: Label
var score_label: Label
var banner_title: Label
var banner_sub: Label
var feed: VBoxContainer
var boss_root: Control
var boss_portrait: TextureRect
var boss_frames: Array = []
var boss_fill: ProgressBar
var boss_ghost: ProgressBar
var boss_gems: Array = []
var _boss: Node = null
var _ghost_v := 100.0
var _banner_t := 0.0
var _blink_t := 3.0
var _glance_t := 7.0
var _glance := 0
var _boss_hit_t := 0.0
var _boon_sig := ""
var merchant_label: Label
var prompt_label: Label


func setup(p_player: Node, p_director: Node) -> void:
	player = p_player
	director = p_director
	layer = 5
	var cls: String = player.class_id
	root = Control.new()
	root.theme = Game.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	weapon = Sprite2D.new()
	weapon.centered = false
	weapon.texture = player.kit.weapon_tex
	weapon.hframes = player.kit.weapon_frames
	weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(weapon)

	dark = UiTheme.pix(load("res://assets/ui/hud/vignette_dark.png"), 4.0)
	dark.modulate.a = 0.55
	root.add_child(dark)
	blood = UiTheme.pix(load("res://assets/ui/hud/vignette_blood.png"), 4.0)
	blood.modulate.a = 0.0
	root.add_child(blood)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(0, 0, 0, 0)
	root.add_child(flash_rect)

	crosshair = UiTheme.pix(load("res://assets/ui/hud/cross_%s.png" % cls))
	crosshair.position = Vector2(W / 2, H / 2) - crosshair.size * 0.5
	root.add_child(crosshair)

	_build_top(cls)
	_build_console(cls)
	_build_boss_plate()

	banner_title = UiTheme.title("", 52, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	banner_title.position = Vector2(0, 196)
	banner_title.size = Vector2(W, 64)
	root.add_child(banner_title)
	banner_sub = UiTheme.label("", 22, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.position = Vector2(0, 262)
	banner_sub.size = Vector2(W, 30)
	root.add_child(banner_sub)

	feed = VBoxContainer.new()
	feed.position = Vector2(24, 380)
	feed.size = Vector2(360, 150)
	feed.alignment = BoxContainer.ALIGNMENT_END
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)

	prompt_label = UiTheme.title("", 24, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.position = Vector2(0, 480)
	prompt_label.size = Vector2(W, 34)
	root.add_child(prompt_label)

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0, 0, 0, 0)
	root.add_child(fade_rect)


# ======================================================================= construction

func _build_top(cls: String) -> void:
	dial = NightDial.new()
	dial.director = director
	dial.position = Vector2(W / 2 - 54, 0)
	dial.size = Vector2(108, 54)
	root.add_child(dial)
	var bar := UiTheme.pix(load("res://assets/ui/hud/topbar_%s.png" % cls))
	root.add_child(bar)
	var menu := UiTheme.title("MENU  [ESC]", 15, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	menu.position = Vector2(8, 5)
	menu.size = Vector2(176, 22)
	root.add_child(menu)
	night_label = UiTheme.title("", 22, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	night_label.position = Vector2(W / 2 - 150, 78)
	night_label.size = Vector2(300, 28)
	root.add_child(night_label)
	foes_label = UiTheme.label("", 16, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	foes_label.position = Vector2(W / 2 - 150, 106)
	foes_label.size = Vector2(300, 22)
	root.add_child(foes_label)
	var plaques := [[848, "gold"], [996, "skull"], [1136, "crit"]]
	var labels: Array = []
	for pq in plaques:
		var ic := UiTheme.pix(load("res://assets/ui/icons/%s.png" % pq[1]), 0.75)
		ic.position = Vector2(pq[0] + 6, 6)
		root.add_child(ic)
		var l := UiTheme.label("0", 16, UiTheme.GOLD if pq[1] == "gold" else UiTheme.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		l.position = Vector2(pq[0] + 30, 4)
		l.size = Vector2(100, 22)
		root.add_child(l)
		labels.append(l)
	gold_label = labels[0]
	kills_label = labels[1]
	score_label = labels[2]


func _build_console(cls: String) -> void:
	var y0 := CONSOLE_Y
	minimap = Minimap.new()
	minimap.director = director
	minimap.position = Vector2(16, y0 + 24)
	minimap.size = Vector2(128, 128)
	root.add_child(minimap)
	var ptex: Texture2D = load(player.cdef.portrait)
	var pframes := maxi(1, int(round(float(ptex.get_width()) / float(ptex.get_height()))))
	for i in pframes:
		_portrait_frames.append(UiTheme.frame_tex(ptex, i, pframes))
	portrait = TextureRect.new()
	portrait.texture = _portrait_frames[0]
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(172, y0 + 16)
	portrait.size = Vector2(96, 96)
	root.add_child(portrait)

	var console := UiTheme.pix(load("res://assets/ui/hud/console_%s.png" % cls))
	console.position = Vector2(0, y0)
	root.add_child(console)

	hp_text = UiTheme.label("", 16, UiTheme.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	hp_text.position = Vector2(168, y0 + 117)
	hp_text.size = Vector2(104, 20)
	root.add_child(hp_text)
	res_text = UiTheme.label("", 16, player.cdef.resource_color.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	res_text.position = Vector2(168, y0 + 135)
	res_text.size = Vector2(104, 20)
	root.add_child(res_text)

	# info panel (recess 292..860 x 616..714)
	name_label = UiTheme.title(str(player.cdef.title).to_upper(), 19, UiTheme.GOLD)
	name_label.position = Vector2(306, y0 + 62)
	root.add_child(name_label)
	hp_bar = UiTheme.bar(Vector2(390, 22), "hp")
	hp_bar.position = Vector2(306, y0 + 90)
	root.add_child(hp_bar)
	hp_bar_text = UiTheme.title("", 16, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	hp_bar_text.position = Vector2(306, y0 + 90)
	hp_bar_text.size = Vector2(390, 22)
	hp_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(hp_bar_text)
	res_bar = UiTheme.bar(Vector2(390, 18), str(player.cdef.resource_bar))
	res_bar.position = Vector2(306, y0 + 118)
	root.add_child(res_bar)
	res_bar_text = UiTheme.title("", 14, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	res_bar_text.position = Vector2(306, y0 + 118)
	res_bar_text.size = Vector2(390, 18)
	res_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(res_bar_text)
	var stat_icons := ["damage", "armor", "crit", "speed"]
	for i in 4:
		var col := i % 2
		var row := i / 2
		var ic := UiTheme.pix(load("res://assets/ui/icons/%s.png" % stat_icons[i]), 0.75)
		ic.position = Vector2(714 + col * 74, y0 + 90 + row * 28)
		root.add_child(ic)
		var l := UiTheme.label("", 15, UiTheme.CREAM)
		l.position = Vector2(738 + col * 74, y0 + 89 + row * 28)
		root.add_child(l)
		stat_labels.append(l)

	for r in 2:
		for c in 3:
			var s: Control = CommandSlot.new()
			s.position = Vector2(880 + c * 52, y0 + 52 + r * 52)
			root.add_child(s)
			inv_slots.append(s)
	merchant_label = UiTheme.title("DAWN MERCHANT", 16, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	merchant_label.position = Vector2(1052, y0 - 22)
	merchant_label.size = Vector2(218, 20)
	merchant_label.visible = false
	root.add_child(merchant_label)
	for r in 2:
		for c in 4:
			var s: Control = CommandSlot.new()
			s.position = Vector2(1052 + c * 56, y0 + 40 + r * 56)
			root.add_child(s)
			cmd_slots.append(s)


func _build_boss_plate() -> void:
	## Compact plate under the top bar, top-left: portrait, name, soul bar, 3 phylacteries.
	boss_root = Control.new()
	boss_root.position = Vector2(8, 38)
	boss_root.size = Vector2(400, 80)
	boss_root.visible = false
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_root)
	var bp_path := "res://assets/ui/portrait_boss.png"
	if ResourceLoader.exists(bp_path):
		var bt: Texture2D = load(bp_path)
		var fs := bt.get_height()
		var n := maxi(1, bt.get_width() / fs)
		var crop := (fs - 34) / 2
		for i in n:
			var a := AtlasTexture.new()
			a.atlas = bt
			a.region = Rect2(i * fs + crop, crop - 4, 34, 34)
			boss_frames.append(a)
	boss_portrait = TextureRect.new()
	boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	boss_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_portrait.position = Vector2(6, 6)
	boss_portrait.size = Vector2(68, 68)
	if not boss_frames.is_empty():
		boss_portrait.texture = boss_frames[0]
	boss_root.add_child(boss_portrait)
	boss_ghost = UiTheme.bar(Vector2(304, 14), "ghost")
	boss_ghost.position = Vector2(84, 54)
	boss_ghost.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	boss_root.add_child(boss_ghost)
	boss_fill = UiTheme.bar(Vector2(304, 14), "soul")
	boss_fill.position = Vector2(84, 54)
	boss_fill.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	boss_root.add_child(boss_fill)
	boss_root.add_child(UiTheme.pix(load("res://assets/ui/hud/boss_plate.png")))
	for k in 2:
		var mark := ColorRect.new()
		mark.color = Color(0.8, 0.76, 0.6)
		mark.position = Vector2(84 + 304.0 * (k + 1) / 3.0 - 1, 52)
		mark.size = Vector2(2, 18)
		boss_root.add_child(mark)
	var bname := UiTheme.title("THE HOLLOW KING", 20, Color(0.65, 1.0, 0.6))
	bname.position = Vector2(86, 6)
	boss_root.add_child(bname)
	var bsub := UiTheme.label("Lord of the Barrow", 14, Color(0.75, 0.8, 0.7))
	bsub.position = Vector2(88, 30)
	boss_root.add_child(bsub)
	var gems_tex: Texture2D = load("res://assets/ui/hud/gems.png")
	for k in 3:
		var g := TextureRect.new()
		g.texture = UiTheme.frame_tex(gems_tex, 0, 3)
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.position = Vector2(326 + k * 20, 8)
		g.pivot_offset = Vector2(8, 10)
		boss_root.add_child(g)
		boss_gems.append(g)


# ======================================================================= per frame

func _process(delta: float) -> void:
	if player == null:
		return
	var kit: Node = player.kit
	# weapon (full-screen frames drawn at 2x; older half-size frames are centred)
	var fw := float(weapon.texture.get_width()) / float(weapon.hframes)
	var s := float(W) / fw if fw >= 600.0 else 2.0
	weapon.scale = Vector2(s, s)
	weapon.frame = clampi(kit.weapon_frame, 0, weapon.hframes - 1)
	var bob: Vector2 = Vector2(sin(player.bob_t) * 18.0, absf(cos(player.bob_t)) * 14.0) * player.move_amount
	if fw >= 600.0:
		weapon.position = (Vector2(kit.weapon_x, -24.0 + kit.weapon_y) + bob + kit.kick * 2.0).round()
	else:
		weapon.position = (Vector2(W * 0.5 - fw * s * 0.5, CONSOLE_Y + 50 - weapon.texture.get_height() * s) + bob + kit.kick * 2.0).round()
	weapon.visible = player.alive
	var lv: float = 0.88 + 0.12 * player.power_flash
	weapon.modulate = Color(lv, lv * 0.97, lv * 0.94)
	# vignettes & flashes
	var hp_ratio: float = player.hp / player.max_hp
	var b: float = player.hurt_flash * 0.9
	if player.alive and hp_ratio < 0.3:
		b = maxf(b, 0.35 + 0.2 * sin(Time.get_ticks_msec() * 0.006))
	elif not player.alive:
		b = 0.9
	blood.modulate.a = clampf(b, 0.0, 1.0)
	if player.heal_flash > 0.01:
		flash_rect.color = Color(1.0, 0.85, 0.35, player.heal_flash * 0.12)
	elif flash_rect.color.g < 0.9:
		flash_rect.color = Color(0, 0, 0, 0)
	crosshair.modulate = Color(1.0, 0.35, 0.3) if player.hit_marker > 0.65 else (Color(1, 0.85, 0.6) if player.hit_marker > 0.0 else Color(1, 1, 1, 0.85))
	crosshair.visible = player.alive
	_update_portrait(delta, hp_ratio)
	# numbers & bars
	hp_text.text = "%d / %d" % [int(ceil(player.hp)), int(player.max_hp)]
	hp_text.add_theme_color_override("font_color", UiTheme.GREEN if hp_ratio > 0.5 else (Color(1.0, 0.85, 0.2) if hp_ratio > 0.25 else UiTheme.RED))
	res_text.text = "%d / %d" % [int(kit.resource), int(kit.max_resource())]
	hp_bar.value = hp_ratio * 100.0
	hp_bar.add_theme_stylebox_override("fill", UiTheme.bar_style("hp" if hp_ratio > 0.3 else "hp_low"))
	hp_bar_text.text = "%d / %d" % [int(ceil(player.hp)), int(player.max_hp)]
	res_bar.value = player.resource_ratio() * 100.0
	res_bar_text.text = "%d / %d" % [int(kit.resource), int(kit.max_resource())]
	stat_labels[0].text = "%+d%%" % int(round((player.mods.damage - 1.0) * 100.0))
	stat_labels[1].text = "%d%%" % int(round(clampf(player.base_armor + player.mods.armor, 0.0, 0.75) * 100.0))
	stat_labels[2].text = "%d%%" % int(round(player.mods.crit * 100.0))
	stat_labels[3].text = "%d%%" % int(round(player.mods.speed * 100.0))
	gold_label.text = str(player.gold)
	kills_label.text = str(player.kills)
	score_label.text = str(director.score)
	_update_night_labels()
	_update_commands(kit)
	_update_inventory()
	if _banner_t > 0.0:
		_banner_t -= delta
		var a := clampf(_banner_t / 0.7, 0.0, 1.0)
		banner_title.modulate.a = a
		banner_sub.modulate.a = a
	_update_boss(delta)
	for c in feed.get_children():
		var t := float(c.get_meta("t", 3.0)) - delta
		c.set_meta("t", t)
		c.modulate.a = clampf(t / 0.6, 0.0, 1.0)
		if t <= 0.0:
			c.queue_free()


func _update_portrait(delta: float, hp_ratio: float) -> void:
	var n := _portrait_frames.size()
	var f := 0
	_blink_t -= delta
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance = 2 if randf() < 0.5 else 3
		_glance_t = randf_range(5.0, 9.0)
	elif _glance_t < _glance_t + 0.0 and false:
		pass
	if _glance > 0 and _glance_t < randf_range(4.2, 4.4):
		_glance = 0
	if _glance > 0:
		f = _glance
	if _blink_t <= 0.0:
		f = 1
		if _blink_t < -0.13:
			_blink_t = randf_range(2.0, 5.0)
	if hp_ratio < 0.25:
		f = 5
	if player.power_flash > 0.2:
		f = 6
	if player.hurt_flash > 0.35:
		f = 4
	if not player.alive:
		f = 7
	if n < 8:
		f = 0
	portrait.texture = _portrait_frames[clampi(f, 0, n - 1)]


func _update_night_labels() -> void:
	var ph: int = director.phase
	if _boss != null:
		night_label.text = ""
		foes_label.text = ""
		return
	if ph == 3:
		night_label.text = "DAWN"
		foes_label.text = "Trade with the goblin  [%s]" % Game.key_label(KEY_F)
	elif ph == 0:
		night_label.text = "NIGHT %s" % UiTheme.roman(director.wave + 1)
		foes_label.text = "begins in %d" % int(ceil(director.prep_left()))
	elif ph == 4:
		night_label.text = ""
		foes_label.text = ""
	else:
		night_label.text = "NIGHT %s" % UiTheme.roman(maxi(director.wave, 1))
		var left: int = director.queue.size() + director.alive_count
		foes_label.text = ("%d foes remain" % left) if ph != 2 else "Dawn approaches"


func _update_commands(kit: Node) -> void:
	var abilities: Array = player.cdef.abilities
	var keys := ["LMB", "RMB", Game.key_label(KEY_E)]
	var slots := ["primary", "secondary", "utility"]
	for i in 3:
		var s: Control = cmd_slots[i]
		s.icon = load("res://assets/ui/icons/%s.png" % abilities[i].icon)
		s.hotkey = keys[i]
		if i == 0:
			s.cooldown = clampf(kit.attack_timer / 0.6, 0.0, 1.0)
			s.lacking = player.class_id == "mage" and kit.resource < 6.0
			s.corner = ""
		else:
			s.cooldown = kit.cooldown_ratio(slots[i])
			var cost: float = kit.ability_cost(slots[i])
			s.lacking = kit.resource < cost
			s.corner = str(int(cost)) if cost > 0.0 else ""
	var pot: Control = cmd_slots[3]
	pot.icon = load("res://assets/ui/icons/potion.png")
	pot.hotkey = Game.key_label(KEY_R)
	pot.corner = str(player.potions)
	pot.disabled = player.potions <= 0
	pot.cooldown = 0.0
	var shop: bool = director.can_shop()
	merchant_label.visible = false
	var row2: Array = []
	if shop:
		row2 = [["gold", Game.key_label(KEY_F), "", director.goblin_near()], ["", "", "", false], ["", "", "", false], ["skull", "ESC", "", true]]
	else:
		row2 = [["resource", "", "", true], ["", "", "", false], ["", "", "", false], ["skull", "ESC", "", true]]
	for i in 4:
		var s: Control = cmd_slots[4 + i]
		var it: Array = row2[i]
		s.icon = load("res://assets/ui/icons/%s.png" % it[0]) if it[0] != "" else null
		s.hotkey = it[1]
		s.corner = it[2]
		s.disabled = not it[3]
		s.highlight = shop and it[3] and i == 0
		s.cooldown = 0.0
		s.lacking = false


func _update_inventory() -> void:
	var sig := str(player.boons)
	if sig == _boon_sig:
		return
	_boon_sig = sig
	var ids: Array = player.boons.keys()
	for i in inv_slots.size():
		var s: Control = inv_slots[i]
		if i < ids.size():
			var id: String = ids[ids.size() - 1 - i]
			var b: Dictionary = Boons.BOONS[id]
			s.icon = load("res://assets/ui/icons/%s.png" % b.icon)
			var n := int(player.boons[id])
			s.corner = str(n) if n > 1 else ""
		else:
			s.icon = null
			s.corner = ""


func _update_boss(delta: float) -> void:
	if _boss == null:
		return
	if not is_instance_valid(_boss):
		boss_root.visible = false
		_boss = null
		return
	var v: float = _boss.hp_ratio() * 100.0
	boss_fill.value = v
	_ghost_v = maxf(v, _ghost_v - delta * 18.0)
	boss_ghost.value = _ghost_v
	_boss_hit_t = maxf(_boss_hit_t - delta, 0.0)
	if _boss._flash_t > 0.0:
		_boss_hit_t = 0.25
	if not boss_frames.is_empty():
		var f := 0
		if _boss.phase >= 3:
			f = 2
		elif _boss_hit_t > 0.0:
			f = 1
		boss_portrait.texture = boss_frames[mini(f, boss_frames.size() - 1)]
	if _boss.phase >= 3:
		var p := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		boss_root.modulate = Color(p, 1.0, p)


# ======================================================================= API used by the director

func show_banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	_banner_t = 3.2
	banner_title.modulate.a = 1.0
	banner_sub.modulate.a = 1.0


func pickup(text: String) -> void:
	var l := UiTheme.label(text, 18, UiTheme.GOLD)
	l.set_meta("t", 3.0)
	feed.add_child(l)
	while feed.get_child_count() > 5:
		var c := feed.get_child(0)
		feed.remove_child(c)
		c.queue_free()


func ping(world_pos: Vector3, color: Color = Color(1.0, 0.25, 0.2)) -> void:
	minimap.ping(world_pos, color)


func show_prompt(text: String) -> void:
	prompt_label.text = text


func show_boss(e: Node) -> void:
	_boss = e
	_ghost_v = 100.0
	boss_root.visible = true
	boss_root.modulate = Color(1, 1, 1)
	var gems_tex: Texture2D = load("res://assets/ui/hud/gems.png")
	for g in boss_gems:
		g.texture = UiTheme.frame_tex(gems_tex, 0, 3)
	boss_root.position.x = -420
	var tw := create_tween()
	tw.tween_property(boss_root, "position:x", 8.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func boss_phase(p: int) -> void:
	var gems_tex: Texture2D = load("res://assets/ui/hud/gems.png")
	for k in boss_gems.size():
		var g: TextureRect = boss_gems[k]
		if k < p - 1:
			g.texture = UiTheme.frame_tex(gems_tex, 2, 3)
	if p - 2 >= 0 and p - 2 < boss_gems.size():
		var gem: TextureRect = boss_gems[p - 2]
		var tw := create_tween()
		tw.tween_property(gem, "scale", Vector2(1.8, 1.8), 0.12)
		tw.tween_property(gem, "scale", Vector2(1, 1), 0.25)
	flash_rect.color = Color(0.4, 1.0, 0.5, 0.35)
	var tw2 := create_tween()
	tw2.tween_property(flash_rect, "color:a", 0.0, 0.6)


func boss_defeated() -> void:
	if not boss_root.visible:
		return
	_boss = null
	var tw := create_tween()
	tw.tween_property(boss_root, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func():
		boss_root.visible = false
		boss_root.modulate.a = 1.0)


func fade_to(color: Color, duration: float) -> Signal:
	fade_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, duration)
	return tw.finished


func fade_from(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, duration)
