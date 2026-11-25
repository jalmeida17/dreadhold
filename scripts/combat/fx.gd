extends Sprite3D
## One-shot animated billboard effect (explosions, blood, dust, frost...). Frees itself.
## Usage: Fx.spawn(parent, "explosion", pos, 2.4)

const Sprites := preload("res://scripts/util/sprites.gd")

var fps := 14.0
var t := 0.0
var velocity := Vector3.ZERO
var gravity := 0.0
var loop_time := 0.0


static func spawn(parent: Node, sheet: String, pos: Vector3, size: float, fps_value: float = 14.0, shaded: bool = false) -> Sprite3D:
	if parent == null:
		return null
	var tex: Texture2D = load("res://assets/sprites/fx/%s.png" % sheet)
	var s: Sprite3D = load("res://scripts/combat/fx.gd").new()
	s.texture = tex
	s.hframes = Sprites.frame_count(tex)
	s.pixel_size = size / float(tex.get_height())
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = shaded
	s.fps = fps_value
	parent.add_child(s)
	s.global_position = pos
	return s


static func flash(parent: Node, pos: Vector3, color: Color, energy: float = 3.0, radius: float = 6.0, duration: float = 0.25) -> void:
	if parent == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


static func ring(parent: Node, pos: Vector3, radius: float, color: Color, duration: float = 0.45) -> void:
	## Expanding flat ring on the ground (frost nova, smashes).
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/sprites/fx/ring.png")
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


func _process(delta: float) -> void:
	t += delta
	if velocity != Vector3.ZERO or gravity != 0.0:
		velocity.y -= gravity * delta
		global_position += velocity * delta
	var f := int(t * fps)
	if f >= hframes:
		queue_free()
		return
	frame = f
