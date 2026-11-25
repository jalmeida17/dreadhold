extends PanelContainer
## Settings panel shared by the main menu and the pause menu.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UiTheme.title("OPTIONS", 40, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_slider(v, "Mouse sensitivity", "mouse_sens", 0.02, 0.4)
	_slider(v, "Master volume", "master", 0.0, 1.0)
	_slider(v, "Music volume", "music", 0.0, 1.0)
	_slider(v, "Effects volume", "sfx", 0.0, 1.0)
	var fs := CheckBox.new()
	fs.text = "  Fullscreen"
	fs.add_theme_font_size_override("font_size", 20)
	fs.button_pressed = Game.settings.fullscreen
	fs.toggled.connect(func(on: bool):
		Game.settings.fullscreen = on
		Game.apply_settings())
	v.add_child(fs)
	var keys := UiTheme.label("Move %s   -   Jump SPACE   -   Ability %s / SHIFT   -   Potion %s   -   Claim relic %s" % [Game.move_keys_label(), Game.key_label(KEY_E), Game.key_label(KEY_R), Game.key_label(KEY_F)], 16, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		Game.save_settings()
		Sfx.play("ui_click")
		closed.emit())
	v.add_child(back)


func _slider(parent: Container, text: String, key: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(text, 20, UiTheme.CREAM)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = Game.settings[key]
	s.custom_minimum_size = Vector2(320, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(val: float):
		Game.settings[key] = val
		Game.apply_settings())
	row.add_child(s)
	parent.add_child(row)
