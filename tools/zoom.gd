extends SceneTree
## Debug helper: crops frames from a sheet and writes an enlarged preview.
## Godot --headless --path . --script res://tools/zoom.gd -- res://assets/x.png <frame_w> <first> <count> <scale> [out]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var src := Image.load_from_file(ProjectSettings.globalize_path(a[0]))
	var fw := int(a[1])
	var fh := src.get_height()
	var first := int(a[2])
	var count := int(a[3])
	var sc := int(a[4])
	var out_path: String = a[5] if a.size() > 5 else "res://tools/preview/zoom.png"
	var out := Image.create(fw * count * sc + (count + 1) * 4, fh * sc + 8, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.32, 0.34, 0.38))
	for i in count:
		var fr := src.get_region(Rect2i((first + i) * fw, 0, fw, fh))
		fr.resize(fw * sc, fh * sc, Image.INTERPOLATE_NEAREST)
		out.blend_rect(fr, Rect2i(0, 0, fw * sc, fh * sc), Vector2i(4 + i * (fw * sc + 4), 4))
	out.save_png(ProjectSettings.globalize_path(out_path))
	quit()
