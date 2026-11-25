extends CanvasLayer
## The spoils of a slain boss: three forged weapons to choose from (or keep the current one).
## The world goes on behind it (no pause): there is nothing left to fight when it opens.

signal chosen(weapon: Dictionary)

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Forge := preload("res://scripts/data/forge.gd")
const Boons := preload("res://scripts/data/boons.gd")
const SHADER := preload("res://scripts/ui/weapon_forge.gdshader")

var root: Control
var _options: Array = []
var _current: Dictionary = {}
var _open := false


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS


static func weapon_material(w: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var mp := Forge.mask(w)
	m.set_shader_parameter("has_mask", mp != "")
	if mp != "":
		m.set_shader_parameter("mask_tex", load(mp))
	m.set_shader_parameter("tint", Forge.tint(w))
	m.set_shader_parameter("glow", Forge.glow(w))
	m.set_shader_parameter("glow_power", Forge.glow_power(w))
	return m


func open(options: Array, current: Dictionary, title: String, sub: String) -> void:
	_options = options
	_current = current
	_open = true
	if root != null:
		root.queue_free()
	root = Control.new()
	root.theme = Game.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var t := UiTheme.title(title, 40, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(0, 26)
	t.size = Vector2(1280, 50)
	root.add_child(t)
	var s := UiTheme.label(sub, 18, UiTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	s.position = Vector2(0, 76)
	s.size = Vector2(1280, 24)
	root.add_child(s)
	for i in options.size():
		root.add_child(_card(options[i], i))
	var keep := Button.new()
	keep.text = "KEEP MY %s" % str(current.get("name", "WEAPON")).to_upper()
	keep.position = Vector2(390, 650)
	keep.custom_minimum_size = Vector2(500, 50)
	keep.add_theme_font_size_override("font_size", 19)
	keep.pressed.connect(func(): _take(_current))
	root.add_child(keep)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.test.has("bot"):
		get_tree().create_timer(1.0, true).timeout.connect(func():
			if _open:
				_take(_options[0]))


func _card(w: Dictionary, i: int) -> Control:
	var col: Color = Boons.RARITY_COLOR[str(w.rarity)]
	var p := PanelContainer.new()
	p.position = Vector2(32 + i * 412, 110)
	p.custom_minimum_size = Vector2(392, 524)
	p.size = Vector2(392, 524)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var pic := TextureRect.new()
	var frames := 3 if str(w["class"]) == "hunter" else 4
	var tex: Texture2D = load(Forge.sheet(w))
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width() / frames, tex.get_height())
	pic.texture = at
	pic.custom_minimum_size = Vector2(340, 150)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.material = weapon_material(w)
	v.add_child(pic)
	var key := UiTheme.title("%d" % (i + 1), 18, UiTheme.GREY)
	key.position = Vector2(4, 0)
	pic.add_child(key)
	var nm := UiTheme.title(str(w.name), 19, col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(340, 0)
	v.add_child(nm)
	v.add_child(UiTheme.label("%s  -  %s" % [str(w.rarity).capitalize(), Forge.material_name(w)], 14, col.darkened(0.15)))
	for line in Forge.describe(w):
		var l := UiTheme.label(str(line), 14, UiTheme.CREAM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(340, 0)
		v.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := Button.new()
	b.text = "TAKE THIS WEAPON"
	b.custom_minimum_size = Vector2(340, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func(): _take(w))
	b.mouse_entered.connect(func(): Sfx.play("ui_hover", -8.0))
	v.add_child(b)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var idx := [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if idx >= 0 and idx < _options.size():
		_take(_options[idx])
		get_viewport().set_input_as_handled()


func _take(w: Dictionary) -> void:
	if not _open:
		return
	_open = false
	Sfx.play("ui_confirm")
	if root != null:
		root.queue_free()
		root = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(w)


func is_open() -> bool:
	return _open
