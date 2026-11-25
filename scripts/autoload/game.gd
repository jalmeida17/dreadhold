extends Node
## Global state: chosen class, settings, records, input map and UI theme.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

const TITLE := "DREADHOLD"
const VERSION := "0.1.0"
const SETTINGS_PATH := "user://settings.cfg"
const RECORDS_PATH := "user://records.cfg"
const SAVE_PATH := "user://vigil_save.json"
const SAVE_VERSION := 1

const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_SURVIVAL := "res://scenes/survival.tscn"

var selected_class := "warrior"
var menu_page := "title"
var selected_map := "keep"
## Run state to restore when the survival scene starts (set by continue_run()).
var pending_save: Dictionary = {}
var settings := {
	"mouse_sens": 0.12,
	"master": 0.8,
	"music": 0.55,
	"sfx": 0.85,
	"fullscreen": false,
	"player_name": "",
}
var records := {}
var theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_ask_web_layout()
	net = load("res://scripts/net/net.gd").new()
	net.name = "Net"
	get_tree().root.add_child.call_deferred(net)
	_setup_buses()
	_load_settings()
	_load_records()
	UiTheme.build_fonts()
	theme = UiTheme.build_theme()
	ThemeDB.fallback_font = UiTheme.body_font
	ThemeDB.fallback_font_size = 18
	get_tree().root.theme = theme
	_setup_cursor()
	get_tree().node_added.connect(_on_node_added)
	apply_settings()
	_parse_test_args()


# ------------------------------------------------------------------ test harness
# Command-line options after "--":  class=mage  start  demo  god  wave=5
#   shot=C:/path.png  shot_at=3.5  quit_at=6   (used for automated checks)

var test := {}
var _clock := 0.0
var _shot_done := false
var _key_labels := {}
## Duo session (scripts/net/net.gd), living at /root/Net on every machine.
var net: Node


func _parse_test_args() -> void:
	for a in OS.get_cmdline_user_args():
		var arg := a.trim_prefix("--")
		var kv := arg.split("=", true, 1)
		test[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if test.has("class"):
		selected_class = test["class"]
	if test.has("map"):
		selected_map = test["map"]
	if test.has("classes"):
		menu_page = "classes"
	if test.has("maps"):
		menu_page = "maps"
	if test.has("lobby"):
		menu_page = "lobby"
	if test.has("continue"):
		continue_run.call_deferred()
	if test.has("start"):
		goto.call_deferred(SCENE_SURVIVAL)


func _process(delta: float) -> void:
	if test.is_empty():
		return
	_clock += delta
	if test.has("shot") and not _shot_done and _clock >= float(test.get("shot_at", "3")):
		_shot_done = true
		var img := get_viewport().get_texture().get_image()
		if img.get_width() != 1280:  # hi-dpi windows: keep README shots at the design size
			img.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		img.save_png(test["shot"])
		print("screenshot saved: ", test["shot"])
	if test.has("quit_at") and _clock >= float(test["quit_at"]):
		get_tree().quit()


# ------------------------------------------------------------------ input

func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("attack_primary", [], [MOUSE_BUTTON_LEFT])
	_bind("attack_secondary", [], [MOUSE_BUTTON_RIGHT])
	_bind("ability_utility", [KEY_E, KEY_SHIFT])
	_bind("use_potion", [KEY_R])
	_bind("pause", [KEY_ESCAPE, KEY_P])
	_bind("interact", [KEY_F])
	_bind("shop_potion", [KEY_B])
	_bind("shop_reroll", [KEY_N])
	_bind("shop_extra", [KEY_V])
	_bind("shop_heal", [KEY_H])


func _bind(action: String, keys: Array, buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)


func key_label(physical: Key) -> String:
	## Name of the key at this physical position on the current keyboard layout (WASD -> ZQSD on AZERTY).
	if _key_labels.has(physical):
		return _key_labels[physical]
	var k: Key = physical
	if OS.has_feature("web"):
		var web := _web_key_label(physical)
		if web != "":
			_key_labels[physical] = web
			return web
		# layout not known (yet): answer with the physical name, without caching it
		return OS.get_keycode_string(physical).to_upper()
	if DisplayServer.get_name() != "headless":
		k = DisplayServer.keyboard_get_label_from_physical(physical)
	if k == KEY_NONE:
		k = physical
	var label := OS.get_keycode_string(k).to_upper()
	_key_labels[physical] = label
	return label


func _ask_web_layout() -> void:
	## Browsers hide the keyboard layout from Godot; Chromium exposes it to JavaScript.
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.dreadholdKeys = '';
		if (navigator.keyboard && navigator.keyboard.getLayoutMap) {
			navigator.keyboard.getLayoutMap().then(function (m) {
				var o = {}; m.forEach(function (v, k) { o[k] = v; });
				window.dreadholdKeys = JSON.stringify(o);
			}).catch(function () {});
		}
	""", true)


func _web_key_label(physical: Key) -> String:
	var name := OS.get_keycode_string(physical)
	if name.length() != 1 or not name.to_upper().is_valid_identifier():
		return ""  # only letters move between layouts here
	var raw = JavaScriptBridge.eval("window.dreadholdKeys || ''", true)
	if typeof(raw) != TYPE_STRING or str(raw) == "":
		return ""
	var layout = JSON.parse_string(str(raw))
	if typeof(layout) != TYPE_DICTIONARY:
		return ""
	return str(layout.get("Key" + name.to_upper(), "")).to_upper()


func move_keys_label() -> String:
	return key_label(KEY_W) + key_label(KEY_A) + key_label(KEY_S) + key_label(KEY_D)


func _setup_cursor() -> void:
	## Armoured gauntlet cursor (hotspot on the fingertip), glowing over buttons.
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists("res://assets/ui/cursor.png"):
		Input.set_custom_mouse_cursor(load("res://assets/ui/cursor.png"), Input.CURSOR_ARROW, Vector2(4, 4))
	if ResourceLoader.exists("res://assets/ui/cursor_hover.png"):
		Input.set_custom_mouse_cursor(load("res://assets/ui/cursor_hover.png"), Input.CURSOR_POINTING_HAND, Vector2(4, 4))


# ------------------------------------------------------------------ audio buses & settings

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(settings.master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(settings.music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(settings.sfx, 0.0001)))
	var want_fs: bool = settings.fullscreen
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_fs != is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cfg.get_value("settings", k, settings[k])


# ------------------------------------------------------------------ records

func _load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return
	for c in cfg.get_sections():
		records[c] = {"wave": cfg.get_value(c, "wave", 0), "kills": cfg.get_value(c, "kills", 0), "score": cfg.get_value(c, "score", 0)}


func submit_record(class_id: String, wave: int, kills: int, score: int) -> bool:
	## Returns true when this run beat the stored best score.
	var r: Dictionary = records.get(class_id, {"wave": 0, "kills": 0, "score": 0})
	var better := score > int(r.score)
	r.wave = maxi(int(r.wave), wave)
	r.kills = maxi(int(r.kills), kills)
	r.score = maxi(int(r.score), score)
	records[class_id] = r
	var cfg := ConfigFile.new()
	for c in records:
		for k in records[c]:
			cfg.set_value(c, k, records[c][k])
	cfg.save(RECORDS_PATH)
	return better


# ------------------------------------------------------------------ scenes

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# ------------------------------------------------------------------ run save (checkpoint at every dawn)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and not read_save().is_empty()


func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return {}
	return data


func write_save(data: Dictionary) -> void:
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("could not write the save file")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# write-then-rename so a crash mid-write never corrupts the previous save
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	pending_save = {}


func continue_run() -> void:
	var data := read_save()
	if data.is_empty():
		return
	pending_save = data
	selected_class = str(data.get("class", selected_class))
	selected_map = str(data.get("map", selected_map))
	goto(SCENE_SURVIVAL)


func goto(path: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
