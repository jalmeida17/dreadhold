extends CanvasLayer
## Defeat screen in the style of a classic RTS score screen: big title, tabbed ornate
## panel (Overview / Combat / Upgrades) with comparisons to personal bests.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const ClassData := preload("res://scripts/data/classes.gd")
const EnemyData := preload("res://scripts/data/enemies.gd")
const Boons := preload("res://scripts/data/boons.gd")

var root: Control
var pages: Array = []
var tabs: Array = []
var director: Node


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = Game.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)


func _tab_style(on: bool) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/wc3/tab_on.png" if on else "res://assets/ui/wc3/tab.png")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func open(p_director: Node, best: bool) -> void:
	director = p_director
	for c in root.get_children():
		c.queue_free()
	pages.clear()
	tabs.clear()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var vig := UiTheme.pix(load("res://assets/ui/hud/vignette_blood.png"), 4.0)
	vig.modulate.a = 0.7
	root.add_child(vig)
	var title := UiTheme.title("DEFEAT", 88, Color(0.92, 0.2, 0.14), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 14)
	title.size = Vector2(1280, 100)
	root.add_child(title)
	var cdef: Dictionary = ClassData.CLASSES[Game.selected_class]
	var sub := UiTheme.label("The %s fell during the %s night. The keep is lost... for now." % [str(cdef.name).to_lower(), _ordinal(director.wave)], 22, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 112)
	sub.size = Vector2(1280, 30)
	root.add_child(sub)
	if best:
		var rec := UiTheme.title("NEW PERSONAL RECORD", 22, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		rec.position = Vector2(0, 142)
		rec.size = Vector2(1280, 30)
		root.add_child(rec)

	var frame := PanelContainer.new()
	frame.position = Vector2(150, 176)
	frame.size = Vector2(980, 440)
	frame.custom_minimum_size = Vector2(980, 440)
	root.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	frame.add_child(v)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	v.add_child(tab_row)
	var body := Control.new()
	body.custom_minimum_size = Vector2(900, 330)
	v.add_child(body)
	var names := ["OVERVIEW", "COMBAT", "UPGRADES"]
	var builders := [_page_overview, _page_combat, _page_upgrades]
	for i in 3:
		var t := Button.new()
		t.text = names[i]
		t.add_theme_font_size_override("font_size", 18)
		t.pressed.connect(_select.bind(i))
		t.mouse_entered.connect(func(): Sfx.play("ui_hover", -8.0))
		tab_row.add_child(t)
		tabs.append(t)
		var page: Control = builders[i].call()
		page.visible = false
		body.add_child(page)
		pages.append(page)
	_select(0)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	h.position = Vector2(0, 640)
	h.size = Vector2(1280, 56)
	root.add_child(h)
	var items := [["RISE AGAIN", _retry], ["NEW CHAMPION", _change], ["MAIN MENU", _menu]]
	if Game.net.duo():
		items = [["MAIN MENU", _menu]]
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(250, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(item[1])
		b.mouse_entered.connect(func(): Sfx.play("ui_hover", -8.0))
		h.add_child(b)
	root.visible = true
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.8)


func _select(i: int) -> void:
	for k in pages.size():
		pages[k].visible = k == i
		var tb: Button = tabs[k]
		for st in ["normal", "hover", "pressed"]:
			tb.add_theme_stylebox_override(st, _tab_style(k == i or st == "hover"))
		tb.add_theme_color_override("font_color", UiTheme.GOLD if k == i else UiTheme.GREY)
	Sfx.play("ui_click", -6.0)


func _ordinal(n: int) -> String:
	var words := ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
	if n >= 1 and n <= 10:
		return words[n - 1]
	return "%dth" % n


# ======================================================================= pages

func _stat_row(parent: Container, label: String, value: String, best_txt: String, ratio: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label(label, 20, UiTheme.CREAM)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var val := UiTheme.title(value, 22, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	val.custom_minimum_size = Vector2(110, 0)
	row.add_child(val)
	var b := UiTheme.bar(Vector2(180, 12), "night")
	b.value = clampf(ratio, 0.0, 1.0) * 100.0
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	row.add_child(UiTheme.label(best_txt, 16, UiTheme.GREY))
	parent.add_child(row)


func _page_overview() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 34)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	var cdef: Dictionary = ClassData.CLASSES[Game.selected_class]
	var ptex: Texture2D = load(cdef.portrait)
	var nfr := maxi(1, ptex.get_width() / ptex.get_height())
	var pic := UiTheme.pix(UiTheme.frame_tex(ptex, nfr - 1 if nfr >= 8 else 0, nfr), 3.0 * 48.0 / float(ptex.get_height()))
	left.add_child(pic)
	left.add_child(UiTheme.title(str(cdef.name).to_upper(), 26, UiTheme.GOLD))
	left.add_child(UiTheme.label(str(cdef.title), 16, UiTheme.GREY))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	h.add_child(right)
	var p: Node = director.player
	var rec: Dictionary = Game.records.get(Game.selected_class, {})
	var bw: int = maxi(int(rec.get("wave", 0)), director.wave)
	var bk: int = maxi(int(rec.get("kills", 0)), p.kills)
	var bs: int = maxi(int(rec.get("score", 0)), director.score)
	var t: float = p.time_alive
	_stat_row(right, "Nights survived", str(maxi(director.wave - 1, 0)), "best: night %d" % bw, float(director.wave) / float(maxi(bw, 1)))
	_stat_row(right, "Foes slain", str(p.kills), "best: %d" % bk, float(p.kills) / float(maxi(bk, 1)))
	_stat_row(right, "Bosses slain", str(int(director.stats.bosses)), "", float(director.stats.bosses) / 3.0)
	_stat_row(right, "Gold earned", str(int(director.stats.gold_earned)), "", float(director.stats.gold_earned) / 500.0)
	_stat_row(right, "Time survived", "%d:%02d" % [int(t) / 60, int(t) % 60], "", t / 900.0)
	_stat_row(right, "Score", str(director.score), "best: %d" % bs, float(director.score) / float(maxi(bs, 1)))
	return h


func _page_combat() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	v.add_child(grid)
	var kbt: Dictionary = director.stats.kills_by_type
	for id in ["ghoul", "skeleton", "archer", "cultist", "brute", "boss"]:
		var d: Dictionary = EnemyData.get_type(id)
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(140, 0)
		var tex: Texture2D = load(d.sheet)
		var pic := TextureRect.new()
		pic.texture = UiTheme.frame_tex(tex, 0, int(d.frames))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.custom_minimum_size = Vector2(120, 120)
		var n := int(kbt.get(id, 0))
		if n == 0:
			pic.modulate = Color(0.25, 0.25, 0.28)
		cell.add_child(pic)
		cell.add_child(UiTheme.label(str(d.name), 16, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(UiTheme.title(str(n), 26, UiTheme.GOLD if n > 0 else UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	var s: Dictionary = director.stats
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 40)
	for pair in [["Damage dealt", int(s.damage_dealt)], ["Damage taken", int(s.damage_taken)], ["Biggest hit", int(s.biggest_hit)], ["Potions drunk", int(s.potions_used)]]:
		var c := VBoxContainer.new()
		c.add_child(UiTheme.label(pair[0], 16, UiTheme.GREY))
		c.add_child(UiTheme.title(str(pair[1]), 26, UiTheme.CREAM))
		line.add_child(c)
	v.add_child(line)
	return v


func _page_upgrades() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var owned: Dictionary = director.player.boons
	if owned.is_empty():
		grid.add_child(UiTheme.label("No ability or upgrade was bought from the goblin.", 20, UiTheme.GREY))
	for id in owned:
		var b: Dictionary = Boons.BOONS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiTheme.pix(load("res://assets/ui/icons/%s.png" % b.icon), 2.0))
		var tv := VBoxContainer.new()
		var name_txt: String = str(b.name) + ("  x%d" % int(owned[id]) if int(owned[id]) > 1 else "")
		tv.add_child(UiTheme.title(name_txt, 20, Boons.RARITY_COLOR[b.rarity]))
		var dl := UiTheme.label(str(b.desc), 16, UiTheme.CREAM)
		dl.custom_minimum_size = Vector2(340, 0)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		row.add_child(tv)
		grid.add_child(row)
	return scroll


# ======================================================================= buttons

func _retry() -> void:
	Sfx.play("ui_confirm")
	Game.goto(Game.SCENE_SURVIVAL)


func _change() -> void:
	Sfx.play("ui_confirm")
	Game.menu_page = "classes"
	Game.goto(Game.SCENE_MENU)


func _menu() -> void:
	Sfx.play("ui_confirm")
	Game.net.leave()
	Game.goto(Game.SCENE_MENU)
