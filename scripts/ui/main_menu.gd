extends Node
## Title screen + champion selection. The keep at night slowly orbits behind the UI
## (rendered pixelated in a SubViewport), menus use the RTS-style frames and fonts.

const WorldView := preload("res://scripts/world/world_view.gd")
const Arena := preload("res://scripts/world/arena.gd")
const Sprites := preload("res://scripts/util/sprites.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const ClassData := preload("res://scripts/data/classes.gd")
const EnemyData := preload("res://scripts/data/enemies.gd")
const OptionsPanel := preload("res://scripts/ui/options_panel.gd")
const Maps := preload("res://scripts/data/maps.gd")

var world: SubViewport
var arena: Node3D
var cam: Camera3D
var ui: Control
var page_title: Control
var page_classes: Control
var page_maps: Control
var page_lobby: Control
## "solo" or "duo": where the champion page leads.
var _mode := "solo"
var _class_go: Button
# duo hall widgets
var _name_edit: LineEdit
var _code_edit: LineEdit
var _lobby_split: Control
var _lobby_room: Control
var _room_code: Label
var _room_hint: Label
var _room_players: VBoxContainer
var _room_maps := {}
var _lobby_status: Label
var _lobby_go: Button
var _map_cards := {}
var _selected_map := "keep"
var options_center: CenterContainer
var options: PanelContainer
var _t := 0.0

# champion selection state
var _selected := "warrior"
var _shown := ""
var _plates := {}
var _plate_pics := {}
var _detail: Dictionary = {}
var _detail_frames: Array = []
var _blink := 2.0


func _ready() -> void:
	world = WorldView.create(self)
	arena = Arena.new()
	world.add_child(arena)
	arena.build("keep")
	cam = Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	cam.current = true
	# extras gather in the north courtyard, well outside the camera's orbit
	var show := [["skeleton", Vector2i(12, 9), 0], ["ghoul", Vector2i(16, 9), 1], ["cultist", Vector2i(14, 8), 2], ["brute", Vector2i(10, 10), 0], ["archer", Vector2i(18, 10), 1], ["boss", Vector2i(14, 6), 0]]
	for s in show:
		var dd: Dictionary = EnemyData.TYPES[s[0]]
		var spr := Sprites.make(load(dd.sheet), int(dd.frames), float(dd.height), true, true)
		spr.frame = int(s[2])
		var holder := Node3D.new()
		holder.add_child(spr)
		world.add_child(holder)
		holder.position = arena.cell_center(s[1])
	_selected = Game.selected_class
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.music("music_menu")
	Sfx.ambience("amb_keep")
	if Game.test.has("log"):
		print("[menu] main menu")
	Game.net.lobby_changed.connect(_refresh_lobby)
	Game.net.status.connect(_on_net_status)
	if Game.menu_page == "classes":
		_show_classes()
	elif Game.menu_page == "maps":
		_show_maps()
	elif Game.menu_page == "lobby":
		_mode = "duo"
		_show_lobby()
	Game.menu_page = "title"


func _process(delta: float) -> void:
	_t += delta
	var center: Vector3 = arena.cell_center(Vector2i(14, 16))
	var a := _t * 0.05 + 2.2
	# orbit in the clear ring between the braziers and the statues of the plaza
	cam.position = center + Vector3(cos(a) * 8.5, 3.4 + sin(_t * 0.2) * 0.3, sin(a) * 8.5)
	cam.look_at(center + Vector3(0, 1.8, 0), Vector3.UP)
	if page_classes.visible and not _detail_frames.is_empty():
		_blink -= delta
		var pic: TextureRect = _detail.pic
		pic.texture = _detail_frames[1 if (_blink < 0.0 and _detail_frames.size() > 1) else 0]
		if _blink < -0.14:
			_blink = randf_range(2.0, 4.5)


func _unhandled_input(event: InputEvent) -> void:
	if page_lobby.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_leave_lobby()
		return
	if page_maps.visible and event is InputEventKey and event.pressed and not event.echo:
		var keys := [KEY_1, KEY_2, KEY_3, KEY_4]
		var idx := keys.find(event.physical_keycode)
		if idx >= 0 and idx < Maps.ORDER.size():
			_select_map(Maps.ORDER[idx])
		elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_begin()
		elif event.physical_keycode == KEY_ESCAPE:
			_show_classes()
		return
	if not page_classes.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_select(ClassData.ORDER[0])
			KEY_2, KEY_KP_2:
				_select(ClassData.ORDER[1])
			KEY_3, KEY_KP_3:
				_select(ClassData.ORDER[2])
			KEY_UP:
				_select(ClassData.ORDER[(ClassData.ORDER.find(_selected) + 2) % 3])
			KEY_DOWN:
				_select(ClassData.ORDER[(ClassData.ORDER.find(_selected) + 1) % 3])
			KEY_ENTER, KEY_KP_ENTER:
				_after_class()
			KEY_ESCAPE:
				_show_title()


# ======================================================================= UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = Game.theme
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var vig := UiTheme.pix(load("res://assets/ui/hud/vignette_dark.png"), 4.0)
	vig.modulate.a = 0.85
	ui.add_child(vig)

	# ---- title page
	page_title = Control.new()
	page_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(page_title)
	var logo := UiTheme.pix(load("res://assets/ui/logo.png"), 2.0)
	logo.position = Vector2(70, 70)
	page_title.add_child(logo)
	var tag := UiTheme.title("THE DEAD WILL NOT REST", 22, Color(0.85, 0.78, 0.62))
	tag.position = Vector2(76, 70 + logo.size.y + 10)
	page_title.add_child(tag)
	var panel := PanelContainer.new()
	panel.position = Vector2(870, 180)
	page_title.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var save := Game.read_save()
	if not save.is_empty():
		_menu_button(v, "CONTINUE", func(): Game.continue_run())
		var cname: String = str(ClassData.CLASSES.get(str(save.get("class", "")), {}).get("name", "?"))
		var mname: String = str(Maps.MAPS.get(str(save.get("map", "")), {}).get("name", "?"))
		var pl: Dictionary = save.get("player", {})
		var summary := UiTheme.label("%s  -  %s
Dawn after night %s  -  %d gold" % [cname, mname, UiTheme.roman(int(save.get("wave", 1))), int(pl.get("gold", 0))], 15, Color(0.8, 0.75, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(summary)
	_menu_button(v, "SURVIVAL" if save.is_empty() else "NEW VIGIL", func():
		_mode = "solo"
		_show_classes())
	var duo := _menu_button(v, "DUO", func():
		_mode = "duo"
		_show_classes())
	duo.tooltip_text = "Survive the nights with an ally, online"
	_menu_button(v, "OPTIONS", _show_options)
	if not OS.has_feature("web"):  # a browser tab is closed, not quit
		_menu_button(v, "QUIT", func(): get_tree().quit())
	v.add_child(UiTheme.label("Duo: two champions, online", 16, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER))
	var ver := UiTheme.label("v%s" % Game.VERSION, 16, UiTheme.GREY)
	ver.position = Vector2(16, 690)
	page_title.add_child(ver)
	var credit := UiTheme.label("Art, sound and music generated procedurally  -  Font: Pixelify Sans (SIL Open Font License)", 15, UiTheme.GREY, HORIZONTAL_ALIGNMENT_RIGHT)
	credit.position = Vector2(400, 692)
	credit.size = Vector2(864, 20)
	page_title.add_child(credit)

	_build_class_page()
	_build_map_page()
	_build_lobby_page()

	options_center = CenterContainer.new()
	options_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(options_center)
	options = OptionsPanel.new()
	options.visible = false
	options.closed.connect(_show_title)
	options_center.add_child(options)


func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 60)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func():
		Sfx.play("ui_click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -8.0))
	parent.add_child(b)
	return b


func _show_page(p: Control) -> void:
	for page in [page_title, page_classes, page_maps, page_lobby]:
		page.visible = page == p
	options.visible = false


func _show_title() -> void:
	_show_page(page_title)


func _show_classes() -> void:
	_show_page(page_classes)
	_class_go.text = "TO THE DUO HALL" if _mode == "duo" else "CHOOSE BATTLEFIELD"
	_select(_selected, true)


func _after_class() -> void:
	if _mode == "duo":
		_show_lobby()
	else:
		_show_maps()


func _show_options() -> void:
	_show_page(null)
	options.visible = true


func _show_maps() -> void:
	Sfx.play("ui_confirm", -4.0)
	_show_page(page_maps)
	_select_map(Game.selected_map, true)


# ======================================================================= champion selection

func _plate_style(state: int) -> StyleBoxTexture:
	## 0 idle, 1 hover, 2 selected
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/wc3/frame.png")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 28)
		sb.set_content_margin(side, 18)
	sb.modulate_color = [Color(0.8, 0.8, 0.8), Color(0.95, 0.93, 0.9), Color(1.5, 1.3, 0.9)][state]
	return sb


func _build_class_page() -> void:
	page_classes = Control.new()
	page_classes.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_classes.visible = false
	page_classes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(page_classes)
	var title := UiTheme.title("CHOOSE YOUR CHAMPION", 44, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 56)
	page_classes.add_child(title)
	var hint := UiTheme.label("Click a champion or press 1 / 2 / 3  -  ENTER to continue  -  double-click to pick at once", 16, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 72)
	hint.size = Vector2(1280, 22)
	page_classes.add_child(hint)
	for i in ClassData.ORDER.size():
		page_classes.add_child(_class_plate(ClassData.ORDER[i], i))
	_build_detail()
	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(60, 650)
	back.custom_minimum_size = Vector2(220, 58)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func():
		Sfx.play("ui_click")
		_show_title())
	page_classes.add_child(back)
	var go := Button.new()
	go.text = "CHOOSE BATTLEFIELD"
	go.position = Vector2(880, 648)
	go.custom_minimum_size = Vector2(340, 64)
	go.add_theme_font_size_override("font_size", 26)
	go.pressed.connect(_after_class)
	go.mouse_entered.connect(func(): Sfx.play("ui_hover", -8.0))
	page_classes.add_child(go)
	_class_go = go


func _class_plate(id: String, index: int) -> Button:
	var c: Dictionary = ClassData.CLASSES[id]
	var btn := Button.new()
	btn.position = Vector2(56, 108 + index * 172)
	btn.custom_minimum_size = Vector2(400, 158)
	btn.size = Vector2(400, 158)
	btn.add_theme_stylebox_override("normal", _plate_style(0))
	btn.add_theme_stylebox_override("hover", _plate_style(1))
	btn.add_theme_stylebox_override("pressed", _plate_style(2))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 28
	h.offset_top = 28
	h.offset_right = -26
	h.offset_bottom = -26
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var ptex: Texture2D = load(c.portrait)
	var nfr := maxi(1, ptex.get_width() / ptex.get_height())
	var pic := UiTheme.pix(UiTheme.frame_tex(ptex, 0, nfr), 96.0 / float(ptex.get_height()))
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiTheme.title(str(c.name).to_upper(), 32, UiTheme.GOLD))
	var role := UiTheme.label(str(c.role), 17, UiTheme.CREAM)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.custom_minimum_size = Vector2(230, 0)
	v.add_child(role)
	var diff := int(c.difficulty) - 1
	v.add_child(UiTheme.label("Difficulty:  %s" % ["Easy", "Medium", "Hard"][diff], 16, [UiTheme.GREEN, Color(1.0, 0.8, 0.3), UiTheme.RED][diff]))
	var key := UiTheme.title(str(index + 1), 18, UiTheme.GREY)
	key.position = Vector2(354, 22)
	btn.add_child(key)
	btn.mouse_entered.connect(func(): Sfx.play("ui_hover", -10.0))
	btn.pressed.connect(func(): _select(id))
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.double_click:
			_select(id)
			_after_class())
	_plates[id] = btn
	_plate_pics[id] = [pic, ptex, nfr]
	return btn


func _build_detail() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(480, 100)
	panel.custom_minimum_size = Vector2(744, 524)
	panel.size = Vector2(744, 524)
	page_classes.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.custom_minimum_size = Vector2(144, 144)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(pic)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	head.add_child(hv)
	var name_l := UiTheme.title("", 40, UiTheme.GOLD)
	hv.add_child(name_l)
	var title_l := UiTheme.label("", 20, Color(0.85, 0.8, 0.68))
	hv.add_child(title_l)
	var res_l := UiTheme.label("", 18, UiTheme.CREAM)
	hv.add_child(res_l)
	var rec_l := UiTheme.label("", 16, UiTheme.GOLD)
	hv.add_child(rec_l)
	# attributes fill the top-right corner of the panel
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(sv)
	sv.add_child(UiTheme.title("ATTRIBUTES", 18, UiTheme.GOLD))
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 14)
	stats.add_theme_constant_override("v_separation", 10)
	sv.add_child(stats)
	var lore := UiTheme.label("", 19, UiTheme.CREAM)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(660, 0)
	v.add_child(lore)
	var abil := VBoxContainer.new()
	abil.add_theme_constant_override("separation", 8)
	v.add_child(abil)
	_detail = {"pic": pic, "name": name_l, "title": title_l, "res": res_l, "rec": rec_l, "stats": stats, "lore": lore, "abil": abil}


func _preview(id: String) -> void:
	if id == _shown:
		return
	_shown = id
	var c: Dictionary = ClassData.CLASSES[id]
	var ptex: Texture2D = load(c.portrait)
	var nfr := maxi(1, ptex.get_width() / ptex.get_height())
	_detail_frames = [UiTheme.frame_tex(ptex, 0, nfr)]
	if nfr >= 8:
		_detail_frames.append(UiTheme.frame_tex(ptex, 1, nfr))
	_detail.pic.texture = _detail_frames[0]
	_detail.name.text = str(c.name).to_upper()
	_detail.title.text = str(c.title)
	_detail.res.text = "Resource: %s" % c.resource
	_detail.res.add_theme_color_override("font_color", c.resource_color.lightened(0.25))
	var rec: Dictionary = Game.records.get(id, {})
	_detail.rec.text = ("Best vigil: night %d  -  %d points" % [int(rec.wave), int(rec.score)]) if not rec.is_empty() else "No vigil kept yet"
	var stats: GridContainer = _detail.stats
	for ch in stats.get_children():
		ch.queue_free()
	for stat in c.stats:
		stats.add_child(UiTheme.label(str(stat), 18, UiTheme.CREAM))
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		for i in 10:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(17, 12)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = c.resource_color if i < int(c.stats[stat]) * 2 else Color(0.12, 0.11, 0.13)
			pips.add_child(pip)
		stats.add_child(pips)
	_detail.lore.text = str(c.lore)
	var abil: VBoxContainer = _detail.abil
	for ch in abil.get_children():
		ch.queue_free()
	var slot_tex: Texture2D = load("res://assets/ui/wc3/slot_%s.png" % id)
	for ab in c.abilities:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(56, 56)
		holder.add_child(UiTheme.pix(slot_tex))
		var ic := UiTheme.pix(load("res://assets/ui/icons/%s.png" % ab.icon), 2.0)
		ic.position = Vector2(4, 4)
		holder.add_child(ic)
		row.add_child(holder)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		var key: String = ab.input
		if key == "UTIL":
			key = Game.key_label(KEY_E) + " / SHIFT"
		tv.add_child(UiTheme.title("%s   [%s]" % [ab.name, key], 20, UiTheme.GOLD))
		var dl := UiTheme.label(str(ab.desc), 17, UiTheme.CREAM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(600, 0)
		tv.add_child(dl)
		row.add_child(tv)
		abil.add_child(row)


func _select(id: String, silent: bool = false) -> void:
	_selected = id
	Game.selected_class = id
	for k in _plates:
		var b: Button = _plates[k]
		b.add_theme_stylebox_override("normal", _plate_style(2 if k == id else 0))
		var pp: Array = _plate_pics[k]
		var pic: TextureRect = pp[0]
		var nfr: int = pp[2]
		pic.texture = UiTheme.frame_tex(pp[1], (6 if (k == id and nfr >= 8) else 0), nfr)
	_shown = ""
	_preview(id)
	if not silent:
		Sfx.play("ui_confirm", -4.0)


func _build_map_page() -> void:
	page_maps = Control.new()
	page_maps.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_maps.visible = false
	page_maps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(page_maps)
	var title := UiTheme.title("CHOOSE YOUR BATTLEFIELD", 44, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 56)
	page_maps.add_child(title)
	var hint := UiTheme.label("Click a battlefield or press 1 - 4  -  ENTER to begin the vigil", 16, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 72)
	hint.size = Vector2(1280, 22)
	page_maps.add_child(hint)
	for i in Maps.ORDER.size():
		page_maps.add_child(_map_card(Maps.ORDER[i], i))
	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(60, 650)
	back.custom_minimum_size = Vector2(220, 58)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func():
		Sfx.play("ui_click")
		_show_classes())
	page_maps.add_child(back)
	var go := Button.new()
	go.text = "BEGIN THE VIGIL"
	go.position = Vector2(880, 648)
	go.custom_minimum_size = Vector2(340, 64)
	go.add_theme_font_size_override("font_size", 28)
	go.pressed.connect(_begin)
	page_maps.add_child(go)


func _map_card(id: String, index: int) -> Button:
	var m: Dictionary = Maps.MAPS[id]
	var btn := Button.new()
	btn.position = Vector2(42 + index * 302, 150)
	btn.custom_minimum_size = Vector2(290, 400)
	btn.size = Vector2(290, 400)
	btn.add_theme_stylebox_override("normal", _plate_style(0))
	btn.add_theme_stylebox_override("hover", _plate_style(1))
	btn.add_theme_stylebox_override("pressed", _plate_style(2))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 24
	v.offset_right = -24
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(240, 135)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(m.thumb):
		thumb.texture = load(m.thumb)
	v.add_child(thumb)
	var name_l := UiTheme.title(str(m.name).to_upper(), 22, UiTheme.GOLD)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(238, 0)
	v.add_child(name_l)
	var diff := int(m.difficulty) - 1
	v.add_child(UiTheme.label("Difficulty:  %s" % ["Easy", "Medium", "Hard"][diff], 16, [UiTheme.GREEN, Color(1.0, 0.8, 0.3), UiTheme.RED][diff]))
	var desc := UiTheme.label(str(m.desc), 17, UiTheme.CREAM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(238, 0)
	v.add_child(desc)
	var key := UiTheme.title(str(index + 1), 18, UiTheme.GREY)
	key.position = Vector2(254, 22)
	btn.add_child(key)
	btn.mouse_entered.connect(func(): Sfx.play("ui_hover", -10.0))
	btn.pressed.connect(func(): _select_map(id))
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.double_click:
			_select_map(id)
			_begin())
	_map_cards[id] = btn
	return btn


func _select_map(id: String, silent: bool = false) -> void:
	_selected_map = id
	Game.selected_map = id
	for k in _map_cards:
		var b: Button = _map_cards[k]
		b.add_theme_stylebox_override("normal", _plate_style(2 if k == id else 0))
	if not silent:
		Sfx.play("ui_confirm", -4.0)


func _begin() -> void:
	if Game.has_save():
		_confirm_new_vigil()
		return
	_start_new()


func _confirm_new_vigil() -> void:
	## A saved vigil exists: ask before replacing it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(460, 0)
	panel.add_child(v)
	v.add_child(UiTheme.title("ABANDON YOUR VIGIL?", 30, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var msg := UiTheme.label("A saved vigil is waiting for you. Starting a new one will erase it for good.", 18, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var keep := Button.new()
	keep.text = "KEEP IT"
	keep.custom_minimum_size = Vector2(190, 52)
	keep.pressed.connect(func():
		Sfx.play("ui_click")
		dim.queue_free())
	h.add_child(keep)
	var erase := Button.new()
	erase.text = "START NEW VIGIL"
	erase.custom_minimum_size = Vector2(230, 52)
	erase.pressed.connect(func():
		Game.delete_save()
		_start_new())
	h.add_child(erase)


func _start_new() -> void:
	Sfx.play("ui_confirm")
	Game.selected_map = _selected_map
	Game.selected_class = _selected
	Game.goto(Game.SCENE_SURVIVAL)


# ======================================================================= duo hall

func _edit_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, 0.95)
	sb.border_color = UiTheme.GOLD_DARK
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _line_edit(placeholder: String, size: int, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", size)
	e.add_theme_color_override("font_color", UiTheme.GOLD)
	e.add_theme_color_override("font_placeholder_color", Color(0.5, 0.47, 0.4))
	e.add_theme_stylebox_override("normal", _edit_style())
	var focus := _edit_style()
	focus.border_color = UiTheme.GOLD
	e.add_theme_stylebox_override("focus", focus)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return e


func _hall_panel(pos: Vector2, size: Vector2, parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	p.size = size
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	return v


func _build_lobby_page() -> void:
	page_lobby = Control.new()
	page_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_lobby.visible = false
	page_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(page_lobby)
	var title := UiTheme.title("THE DUO HALL", 44, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 18)
	title.size = Vector2(1280, 56)
	page_lobby.add_child(title)
	var hint := UiTheme.label("Two champions, one vigil. Nothing is saved: the vigil ends when both have fallen.", 16, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 72)
	hint.size = Vector2(1280, 22)
	page_lobby.add_child(hint)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 14)
	name_row.position = Vector2(0, 108)
	name_row.size = Vector2(1280, 48)
	page_lobby.add_child(name_row)
	name_row.add_child(UiTheme.title("YOUR NAME", 20, UiTheme.CREAM))
	_name_edit = _line_edit("Champion", 22, 16)
	_name_edit.custom_minimum_size = Vector2(300, 44)
	_name_edit.text = str(Game.settings.get("player_name", ""))
	_name_edit.text_changed.connect(func(t: String):
		Game.settings.player_name = t.strip_edges()
		Game.save_settings())
	name_row.add_child(_name_edit)

	# ---- before a room exists: host or join
	_lobby_split = Control.new()
	_lobby_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_lobby.add_child(_lobby_split)
	var hv := _hall_panel(Vector2(130, 190), Vector2(490, 330), _lobby_split)
	hv.add_child(UiTheme.title("HOST A VIGIL", 30, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var hd := UiTheme.label("Open a room, then give its four-letter code to your ally. You choose the battlefield.", 17, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	hd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hd.custom_minimum_size = Vector2(420, 0)
	hv.add_child(hd)
	var host_btn := Button.new()
	host_btn.text = "OPEN A ROOM"
	host_btn.custom_minimum_size = Vector2(300, 60)
	host_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host_btn.add_theme_font_size_override("font_size", 24)
	host_btn.pressed.connect(func():
		Sfx.play("ui_confirm")
		Game.net.host(_selected, Game.selected_map))
	hv.add_child(host_btn)
	var jv := _hall_panel(Vector2(660, 190), Vector2(490, 330), _lobby_split)
	jv.add_child(UiTheme.title("JOIN AN ALLY", 30, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var jd := UiTheme.label("Enter the code your ally gave you.", 17, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	jv.add_child(jd)
	_code_edit = _line_edit("CODE", 40, 4)
	_code_edit.custom_minimum_size = Vector2(220, 64)
	_code_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_code_edit.text_changed.connect(func(t: String):
		var clean := ""
		for ch in t.to_upper():
			if ch >= "A" and ch <= "Z":
				clean += ch
		if clean != t:
			_code_edit.text = clean
			_code_edit.caret_column = clean.length())
	_code_edit.text_submitted.connect(func(_t: String): _join())
	jv.add_child(_code_edit)
	var join_btn := Button.new()
	join_btn.text = "JOIN"
	join_btn.custom_minimum_size = Vector2(300, 60)
	join_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	join_btn.add_theme_font_size_override("font_size", 24)
	join_btn.pressed.connect(_join)
	jv.add_child(join_btn)

	# ---- inside a room
	_lobby_room = Control.new()
	_lobby_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_room.visible = false
	page_lobby.add_child(_lobby_room)
	var rv := _hall_panel(Vector2(190, 172), Vector2(900, 400), _lobby_room)
	rv.add_theme_constant_override("separation", 10)
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 22)
	rv.add_child(code_row)
	code_row.add_child(UiTheme.title("ROOM CODE", 24, UiTheme.CREAM))
	_room_code = UiTheme.title("----", 56, UiTheme.GOLD)
	code_row.add_child(_room_code)
	_room_hint = UiTheme.label("", 16, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER)
	rv.add_child(_room_hint)
	_room_players = VBoxContainer.new()
	_room_players.add_theme_constant_override("separation", 8)
	rv.add_child(_room_players)
	rv.add_child(UiTheme.title("BATTLEFIELD", 20, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var maps_row := HBoxContainer.new()
	maps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	maps_row.add_theme_constant_override("separation", 10)
	rv.add_child(maps_row)
	for id in Maps.ORDER:
		var b := Button.new()
		b.text = str(Maps.MAPS[id].name)
		b.custom_minimum_size = Vector2(205, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.toggle_mode = true
		b.pressed.connect(func():
			Sfx.play("ui_click")
			Game.net.set_map(id))
		maps_row.add_child(b)
		_room_maps[id] = b

	_lobby_status = UiTheme.label("", 18, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_lobby_status.position = Vector2(0, 594)
	_lobby_status.size = Vector2(1280, 26)
	page_lobby.add_child(_lobby_status)
	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(60, 650)
	back.custom_minimum_size = Vector2(220, 58)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func():
		Sfx.play("ui_click")
		_leave_lobby())
	page_lobby.add_child(back)
	_lobby_go = Button.new()
	_lobby_go.text = "BEGIN THE VIGIL"
	_lobby_go.position = Vector2(880, 648)
	_lobby_go.custom_minimum_size = Vector2(340, 64)
	_lobby_go.add_theme_font_size_override("font_size", 26)
	_lobby_go.pressed.connect(func():
		Sfx.play("ui_confirm")
		Game.net.start_game())
	page_lobby.add_child(_lobby_go)


func _show_lobby() -> void:
	Sfx.play("ui_confirm", -4.0)
	_show_page(page_lobby)
	_lobby_status.text = ""
	_refresh_lobby()
	if _name_edit.text == "":
		_name_edit.grab_focus()


func _join() -> void:
	Sfx.play("ui_confirm")
	Game.net.join(_code_edit.text, _selected)


func _leave_lobby() -> void:
	Game.net.leave()
	_lobby_status.text = ""
	_show_classes()


func _on_net_status(text: String, is_error: bool) -> void:
	if _lobby_status == null:
		return
	_lobby_status.text = text
	_lobby_status.add_theme_color_override("font_color", UiTheme.RED if is_error else UiTheme.CREAM)
	if is_error:
		Sfx.play("ui_click", -4.0)


func _refresh_lobby() -> void:
	if page_lobby == null:
		return
	var net: Node = Game.net
	var in_room: bool = net.connected() and net.room_code != ""
	_lobby_split.visible = not in_room
	_lobby_room.visible = in_room
	_lobby_go.visible = in_room
	if not in_room:
		return
	var host: bool = net.is_host()
	_room_code.text = " ".join(str(net.room_code).split(""))
	_room_hint.text = "Give this code to your ally" if host else "You joined this vigil"
	for c in _room_players.get_children():
		c.queue_free()
	var ids: Array = net.players.keys()
	ids.sort()
	for i in 2:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		_room_players.add_child(row)
		if i < ids.size():
			var p: Dictionary = net.players[ids[i]]
			var cdef: Dictionary = ClassData.CLASSES.get(str(p.get("class", "warrior")), ClassData.CLASSES["warrior"])
			var pic := TextureRect.new()
			pic.custom_minimum_size = Vector2(44, 44)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var ptex: Texture2D = load(cdef.portrait)
			pic.texture = UiTheme.frame_tex(ptex, 0, maxi(1, int(round(float(ptex.get_width()) / float(ptex.get_height())))))
			row.add_child(pic)
			var who := str(p.get("name", "Champion"))
			if int(ids[i]) == net.my_id():
				who += "  (you)"
			var nl := UiTheme.title(who, 22, UiTheme.GOLD if int(ids[i]) == 1 else Color(0.55, 0.85, 1.0))
			nl.custom_minimum_size = Vector2(300, 0)
			row.add_child(nl)
			var cl := UiTheme.label(str(cdef.name) + ("  -  host" if int(ids[i]) == 1 else ""), 18, UiTheme.CREAM)
			cl.custom_minimum_size = Vector2(300, 0)
			row.add_child(cl)
		else:
			row.add_child(UiTheme.label("Waiting for an ally...", 20, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER))
	for id in _room_maps:
		var b: Button = _room_maps[id]
		var chosen: bool = id == net.map_id
		b.button_pressed = chosen
		b.disabled = not host
		b.modulate = Color(1, 1, 1) if chosen else Color(0.55, 0.55, 0.55)
		b.text = ("> %s <" if chosen else "%s") % str(Maps.MAPS[id].name)
	if host:
		_lobby_go.text = "BEGIN THE VIGIL"
		_lobby_go.disabled = not net.can_start()
	else:
		_lobby_go.text = "THE HOST BEGINS"
		_lobby_go.disabled = true
