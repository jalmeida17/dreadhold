extends SceneTree
## Renders a pixelated preview of every playable map (from the player's spawn point)
## into assets/ui/maps/<id>.png for the battlefield selection screen. Run windowed:
##   Godot --path . --script res://tools/map_thumbs.gd

const Arena := preload("res://scripts/world/arena.gd")
const Maps := preload("res://scripts/data/maps.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/maps"))
	for id in Maps.ORDER:
		var vp := SubViewport.new()
		vp.size = Vector2i(240, 135)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(vp)
		var a: Node3D = Arena.new()
		vp.add_child(a)
		a.build(id)
		var cam := Camera3D.new()
		cam.fov = 72.0
		vp.add_child(cam)
		cam.position = a.cell_center(a.player_spawn_cell) + Vector3(0, 1.8, 0)
		cam.look_at(a.cell_center(a.look_cell) + Vector3(0, 1.3, 0), Vector3.UP)
		cam.current = true
		for i in 10:
			await process_frame
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://assets/ui/maps/%s.png" % id))
		print("thumb ", id)
		vp.queue_free()
		await process_frame
	quit()
