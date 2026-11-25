extends Control
## Duo chat: a short log of messages and a line to type in.
## In game the line opens with Enter (and closes with Enter to send, Esc to cancel) and the
## messages fade after a while; in the Duo Hall the line is always there and nothing fades.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const MAX_LINES := 6
const LINE_TIME := 9.0

signal typing_changed(on: bool)

var in_game := true
var log_box: VBoxContainer
var input: LineEdit
var _typing := false


func setup(p_size: Vector2, p_in_game: bool) -> void:
	in_game = p_in_game
	size = p_size
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box = VBoxContainer.new()
	log_box.position = Vector2.ZERO
	log_box.size = Vector2(p_size.x, p_size.y - 40)
	log_box.alignment = BoxContainer.ALIGNMENT_END
	log_box.add_theme_constant_override("separation", 2)
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_box)
	input = LineEdit.new()
	input.position = Vector2(0, p_size.y - 36)
	input.size = Vector2(p_size.x, 34)
	input.max_length = Game.net.MAX_CHAT
	input.placeholder_text = "Say something to your ally..." if not in_game else "Enter to send, Esc to cancel"
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", UiTheme.CREAM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.03, 0.88)
	sb.border_color = UiTheme.GOLD_DARK
	sb.set_border_width_all(1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	input.add_theme_stylebox_override("normal", sb)
	input.add_theme_stylebox_override("focus", sb)
	input.visible = not in_game
	input.text_submitted.connect(func(_t: String): _submit())
	add_child(input)
	Game.net.chat.connect(add_line)


func add_line(who: String, text: String, mine: bool) -> void:
	var l := UiTheme.label("%s:  %s" % [who, text], 16, UiTheme.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(size.x, 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_color_override("font_color", UiTheme.GOLD if mine else Color(0.6, 0.87, 1.0))
	l.set_meta("t", LINE_TIME)
	log_box.add_child(l)
	while log_box.get_child_count() > MAX_LINES:
		var old := log_box.get_child(0)
		log_box.remove_child(old)
		old.queue_free()
	if not mine:
		Sfx.play("ui_click", -6.0)


func is_typing() -> bool:
	return _typing


func open() -> void:
	if _typing:
		return
	_typing = true
	input.visible = true
	input.text = ""
	input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	typing_changed.emit(true)


func close() -> void:
	if not _typing:
		return
	_typing = false
	input.release_focus()
	input.visible = not in_game
	if in_game:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	typing_changed.emit(false)


func _submit() -> void:
	Game.net.say(input.text)
	input.text = ""
	if in_game:
		close()


func _input(event: InputEvent) -> void:
	if _typing and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not in_game:
		return
	for c in log_box.get_children():
		var t := float(c.get_meta("t", LINE_TIME)) - delta
		c.set_meta("t", t)
		# while typing, the whole conversation stays readable
		c.modulate.a = 1.0 if _typing else clampf(t / 1.5, 0.0, 1.0)
