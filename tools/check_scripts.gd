extends SceneTree
## Loads every script under res://scripts to surface parse errors. Run headless.

func _init() -> void:
	var bad := 0
	for path in _walk("res://scripts"):
		var s = load(path)
		if s == null or not (s as Script).can_instantiate():
			print("FAILED: ", path)
			bad += 1
	print("checked, failures: ", bad)
	quit()

func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _walk(dir + "/" + sub)
	return out
