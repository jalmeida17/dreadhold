extends CanvasLayer
## Escape menu during a run.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const OptionsPanel := preload("res://scripts/ui/options_panel.gd")

var root: Control
var menu: PanelContainer
var options: PanelContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = Game.theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	menu = PanelContainer.new()
	center.add_child(menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(380, 0)
	menu.add_child(v)
	v.add_child(UiTheme.title("PAUSED", 44, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiTheme.label("The dead wait patiently.", 18, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER))
	var note := UiTheme.label("Your vigil is saved at every dawn. Quitting resumes it from the last dawn.", 15, UiTheme.GREY, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)
	v.add_child(note)
	for item in [["RETURN TO GAME", close], ["OPTIONS", _show_options], ["QUIT TO MENU", _quit], ["ABANDON VIGIL", _abandon]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(380, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(item[1])
		b.mouse_entered.connect(func(): Sfx.play("ui_hover", -8.0))
		v.add_child(b)
	options = OptionsPanel.new()
	options.visible = false
	options.closed.connect(func():
		options.visible = false
		menu.visible = true)
	center.add_child(options)


func open() -> void:
	if root.visible:
		close()
		return
	root.visible = true
	menu.visible = true
	options.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui_click")


func close() -> void:
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("ui_click")


func _unhandled_input(event: InputEvent) -> void:
	if root.visible and event.is_action_pressed("pause"):
		if options.visible:
			options.visible = false
			menu.visible = true
		else:
			close()
		get_viewport().set_input_as_handled()


func _show_options() -> void:
	Sfx.play("ui_click")
	menu.visible = false
	options.visible = true


func _quit() -> void:
	Sfx.play("ui_confirm")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.goto(Game.SCENE_MENU)


func _abandon() -> void:
	Game.delete_save()
	_quit()
