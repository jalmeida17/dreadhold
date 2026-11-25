extends Control
## RTS command-card button: icon, hotkey, radial cooldown sweep, charges/cost label,
## blue tint when the resource is lacking, white flash when used.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var icon: Texture2D
var hotkey := ""
var corner := ""
var cooldown := 0.0          # 0..1 remaining fraction
var lacking := false         # not enough resource -> blue tint
var disabled := false        # unavailable -> grey
var highlight := false       # glowing border (e.g. shop item affordable)
var _flash := 0.0
var _last_cd := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	size = Vector2(48, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if cooldown > _last_cd + 0.5:
		flash()
	_last_cd = cooldown
	_flash = maxf(_flash - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if icon != null:
		var mod := Color(1, 1, 1)
		if disabled:
			mod = Color(0.35, 0.35, 0.35)
		elif lacking:
			mod = Color(0.45, 0.55, 1.0)
		draw_texture_rect(icon, r, false, mod)
	if cooldown > 0.001:
		var c := size * 0.5
		var pts := PackedVector2Array([c])
		var start := -PI * 0.5
		var sweep := TAU * cooldown
		var steps := 24
		for i in steps + 1:
			var a := start + sweep * float(i) / float(steps)
			var v := Vector2(cos(a), sin(a)) * size.x
			pts.append(c + Vector2(clampf(v.x, -c.x, c.x), clampf(v.y, -c.y, c.y)))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
	if highlight:
		draw_rect(r.grow(-1), Color(1.0, 0.85, 0.3, 0.8), false, 2.0)
	if _flash > 0.0:
		draw_rect(r, Color(1, 1, 1, _flash * 0.45))
	var f := UiTheme.title_font
	if hotkey != "":
		draw_string_outline(f, Vector2(3, 15), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0))
		draw_string(f, Vector2(3, 15), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.GOLD)
	if corner != "":
		var w := f.get_string_size(corner, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(f, Vector2(size.x - w - 3, size.y - 4), corner, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0))
		draw_string(f, Vector2(size.x - w - 3, size.y - 4), corner, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)
