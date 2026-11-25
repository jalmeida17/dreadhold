extends Control
## Half-disc day/night dial: the moon crosses the sky as the night's horde is slain,
## the sun rises at dawn, a green eclipse during the boss night.

var director: Node
var _moon: Texture2D = preload("res://assets/ui/hud/moon.png")
var _sun: Texture2D = preload("res://assets/ui/hud/sun.png")
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, 0.0)
	var r := size.x * 0.5
	var ph: int = director.phase
	var dawn: bool = ph == 3 or ph == 2  # DAWN or CLEARED
	var boss: bool = director.arena.is_boss_arena()
	var top := Color(0.03, 0.03, 0.1)
	var bottom := Color(0.12, 0.07, 0.2)
	if dawn:
		top = Color(0.25, 0.3, 0.55)
		bottom = Color(0.95, 0.55, 0.25)
	elif boss:
		var bc: Color = director.boss_entry.get("color", Color(0.3, 1.0, 0.45))
		top = bc.darkened(0.92)
		bottom = bc.darkened(0.6)
	var steps := 10
	for i in steps:
		var y0 := r * float(i) / steps
		var y1 := r * float(i + 1) / steps
		var col := top.lerp(bottom, float(i) / steps)
		var hw0 := sqrt(maxf(r * r - y0 * y0, 0.0))
		var hw1 := sqrt(maxf(r * r - y1 * y1, 0.0))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-hw0, y0), c + Vector2(hw0, y0), c + Vector2(hw1, y1), c + Vector2(-hw1, y1)]), col)
	for k in 9:
		var a := PI * float(k) / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 6), c + d * (r - 1), Color(1, 0.9, 0.6, 0.5), 1.0)
	var prog := 0.0
	if director.wave_total > 0:
		prog = clampf(float(director.wave_killed) / float(maxi(director.wave_total, 1)), 0.0, 1.0)
	var icon := _moon
	if dawn:
		icon = _sun
		prog = 0.5
	elif ph == 0:
		prog = 0.0
	var ang := PI - prog * PI
	var pos := c + Vector2(cos(ang), sin(ang)) * (r - 16.0)
	if boss and not dawn:
		pos = c + Vector2(0, r * 0.45)
		var gc: Color = director.boss_entry.get("color", Color(0.3, 1.0, 0.45))
		draw_circle(pos, 14.0 + sin(_t * 3.0) * 1.5, Color(gc.r, gc.g, gc.b, 0.35))
		draw_circle(pos, 10.0, Color(0.02, 0.05, 0.03))
		return
	draw_texture(icon, pos - icon.get_size() * 0.5)
