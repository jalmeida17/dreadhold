extends Control
## Minimap: the arena grid rendered once, then player / enemies / goblin / pings on top.

const Arena := preload("res://scripts/world/arena.gd")

var director: Node
var arena: Node3D
var _base: ImageTexture
var _scale := 4.0
var _origin := Vector2.ZERO
var _pings: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func ping(world_pos: Vector3, color: Color) -> void:
	_pings.append([world_pos, color, 0.0])


func _rebuild() -> void:
	arena = director.arena
	var w: int = arena.W
	var h: int = arena.H
	_scale = floorf(minf(size.x, size.y) / float(maxi(w, h)))
	_origin = ((size - Vector2(w, h) * _scale) * 0.5).floor()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch: String = arena.tile(c)
			var col := Color(0.3, 0.29, 0.27)
			match ch:
				"G":
					col = Color(0.25, 0.6, 0.32)
				"R":
					col = Color(0.3, 0.75, 0.4)
				"#", "M", "B", "T", "D", "P":
					col = Color(0.09, 0.085, 0.09)
				",":
					col = Color(0.27, 0.27, 0.29)
				"_":
					col = Color(0.24, 0.2, 0.13)
				".", "c":
					col = Color(0.33, 0.31, 0.28)
			if arena.roof.has(c) and col.r > 0.2:
				col = col.darkened(0.25)
			if arena.props.has(c) and Arena.BLOCKING_PROPS.contains(arena.props[c]):
				col = Color(0.16, 0.15, 0.14)
			img.set_pixel(x, y, col)
	_base = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if director == null:
		return
	if director.arena != arena:
		_rebuild()
	for p in _pings:
		p[2] += delta
	_pings = _pings.filter(func(p): return p[2] < 2.4)
	queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	return _origin + Vector2(p.x, p.z) / Arena.CELL * _scale


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
	if _base == null:
		return
	draw_texture_rect(_base, Rect2(_origin, Vector2(arena.W, arena.H) * _scale), false)
	for n in get_tree().get_nodes_in_group("enemies"):
		var mp := _to_map(n.global_position).floor()
		var r := 2.0
		var col := Color(1.0, 0.2, 0.15)
		if n.type_id == "brute":
			r = 3.0
		elif n.is_boss:
			r = 5.0
			col = Color(0.4, 1.0, 0.5)
		draw_rect(Rect2(mp - Vector2(r, r), Vector2(r, r) * 2.0), Color(0, 0, 0))
		draw_rect(Rect2(mp - Vector2(r - 1, r - 1), Vector2(r - 1, r - 1) * 2.0), col)
	var gob: Node3D = director.goblin
	if gob != null and is_instance_valid(gob):
		var gp := _to_map(gob.global_position).floor()
		draw_rect(Rect2(gp - Vector2(4, 4), Vector2(8, 8)), Color(0, 0, 0))
		draw_rect(Rect2(gp - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.8, 0.3))
	var pl: Node3D = director.player
	if pl != null:
		_pixel_arrow(_to_map(pl.global_position).floor(), pl.yaw)
	for p in _pings:
		var t: float = p[2]
		var mp := _to_map(p[0])
		var col: Color = p[1]
		for k in 2:
			var tt := fmod(t + k * 0.4, 1.2) / 1.2
			draw_arc(mp, 3.0 + tt * 16.0, 0.0, TAU, 20, Color(col.r, col.g, col.b, (1.0 - tt) * 0.9), 2.0)


func _pixel_arrow(mp: Vector2, yaw: float) -> void:
	## Player marker drawn as chunky 2x2 pixels (outlined arrow pointing where we look).
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	for pass_i in 2:
		var grow := 1.6 if pass_i == 0 else 0.0
		var col := Color(0, 0, 0) if pass_i == 0 else Color(1.0, 0.92, 0.35)
		for j in range(-6, 7):
			for i in range(-6, 7):
				var c := Vector2(i, j) * 2.0
				var u := c.dot(fwd)
				var v := absf(c.dot(side))
				var tip := 7.0 + grow
				var back := -4.0 - grow
				if u <= tip and u >= back and v <= (tip - u) / (tip - back) * (5.0 + grow):
					draw_rect(Rect2(mp + c - Vector2(1, 1), Vector2(2, 2)), col)
