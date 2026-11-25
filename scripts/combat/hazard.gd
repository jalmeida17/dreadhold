extends Node3D
## Boss hazards. Modes:
##  "strike": a telegraphed circle on the ground, then an impact (meteor / acid glob).
##  "pool":   a lingering damage zone (toxic puddle) that hurts every half second.
##  "nova":   an expanding shockwave ring that hits the player if they are on the ground
##            when it passes (jump over it!).

const Fx := preload("res://scripts/combat/fx.gd")
const HazardScript := "res://scripts/combat/hazard.gd"

var mode := "strike"
var radius := 2.2
var damage := 20.0
var delay := 1.1
var duration := 6.0
var color := Color(1.0, 0.5, 0.2)
var style := "fire"          # fire | acid | frost
var max_radius := 16.0
var speed := 12.0
var source: Node = null
var _t := 0.0
var _tick := 0.0
var _hit := false
var _decal: MeshInstance3D
var _mat: StandardMaterial3D
var _falling: Sprite3D


static func spawn(parent: Node, p_mode: String, pos: Vector3, p_style: String, p_damage: float, p_source: Node = null, params: Dictionary = {}) -> Node3D:
	var h: Node3D = load(HazardScript).new()
	h.mode = p_mode
	h.style = p_style
	h.damage = p_damage
	h.source = p_source
	h.color = {"fire": Color(1.0, 0.45, 0.15), "acid": Color(0.7, 1.0, 0.25), "frost": Color(0.55, 0.9, 1.0)}.get(p_style, Color(1, 1, 1))
	for k in params:
		h.set(k, params[k])
	parent.add_child(h)
	h.global_position = Vector3(pos.x, 0.05, pos.z)
	return h


func _ready() -> void:
	_decal = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	_decal.mesh = pm
	_mat = StandardMaterial3D.new()
	var tex_path := "res://assets/sprites/fx/acid_pool.png" if mode == "pool" and ResourceLoader.exists("res://assets/sprites/fx/acid_pool.png") else "res://assets/sprites/fx/ring.png"
	_mat.albedo_texture = load(tex_path)
	_mat.albedo_color = color
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if mode != "pool":
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_decal.material_override = _mat
	add_child(_decal)
	match mode:
		"strike":
			_decal.scale = Vector3(radius, 1, radius)
			if style == "fire":
				var mpath := "res://assets/sprites/fx/meteor.png"
				var tex: Texture2D = load(mpath) if ResourceLoader.exists(mpath) else load("res://assets/sprites/fx/fireball.png")
				_falling = Sprite3D.new()
				_falling.texture = tex
				_falling.hframes = maxi(1, tex.get_width() / tex.get_height())
				_falling.pixel_size = 1.6 / float(tex.get_height())
				_falling.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				_falling.shaded = false
				_falling.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				_falling.position = Vector3(2.0, 14.0, 1.0)
				add_child(_falling)
				Sfx.play_at("meteor_fall", global_position + Vector3(0, 4.0, 0), -2.0, 0.1, 0.12)
		"pool":
			_decal.scale = Vector3(radius, 1, radius)
			Sfx.play_at("acid_pool", global_position, -4.0, 0.12, 0.2)
		"nova":
			_decal.scale = Vector3(0.5, 1, 0.5)
			_decal.position.y = 0.15


func _physics_process(delta: float) -> void:
	_t += delta
	var player: Node3D = get_tree().get_first_node_in_group("player")
	match mode:
		"strike":
			var k := clampf(_t / delay, 0.0, 1.0)
			_mat.albedo_color = Color(color.r, color.g, color.b, 0.35 + 0.5 * k + 0.15 * sin(_t * 20.0))
			if _falling != null:
				_falling.position = Vector3(2.0, 14.0, 1.0).lerp(Vector3(0, 0.6, 0), k * k)
				_falling.frame = int(_t * 12.0) % _falling.hframes
			if _t >= delay:
				_impact(player)
		"pool":
			_tick -= delta
			var fade := clampf((duration - _t) / 0.8, 0.0, 1.0)
			_mat.albedo_color = Color(color.r, color.g, color.b, 0.85 * fade)
			if _tick <= 0.0 and player != null and player.alive:
				_tick = 0.5
				if _flat_dist(player) <= radius and player.global_position.y < 0.8:
					player.take_damage(damage * 0.5, Vector3.INF, "hazard", null)
			if _t >= duration:
				queue_free()
		"nova":
			var r := minf(_t * speed, max_radius)
			_decal.scale = Vector3(r, 1, r)
			_mat.albedo_color = Color(color.r, color.g, color.b, clampf(1.0 - r / max_radius, 0.0, 1.0) + 0.2)
			if not _hit and player != null and player.alive:
				var d := _flat_dist(player)
				if absf(d - r) < 0.9 and player.is_on_floor():
					_hit = true
					player.take_damage(damage, global_position, "smash", null)
			if r >= max_radius:
				queue_free()


func _flat_dist(n: Node3D) -> float:
	return Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()


func _impact(player: Node3D) -> void:
	var parent := get_parent()
	match style:
		"fire":
			Fx.spawn(parent, "explosion", global_position + Vector3(0, 0.8, 0), 3.2, 16.0)
			Fx.flash(parent, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.2), 5.0, 8.0, 0.35)
			Sfx.play_at("meteor_impact", global_position, 0.0, 0.1, 0.08)
		"acid":
			Fx.spawn(parent, "dust", global_position + Vector3(0, 0.5, 0), 2.0, 14.0, true)
			Sfx.play_at("acid_splash", global_position, 0.0, 0.1, 0.08)
			var pool: Node3D = load(HazardScript).spawn(parent, "pool", global_position, "acid", damage * 0.5, source)
			pool.radius = radius * 1.1
			pool.duration = 6.0
		_:
			Fx.spawn(parent, "frost", global_position + Vector3(0, 0.6, 0), 2.4, 12.0)
			Sfx.play_at("ice_shatter", global_position, -2.0, 0.1, 0.08)
	if player != null and player.alive and _flat_dist(player) <= radius + 0.3 and player.global_position.y < 1.5:
		player.take_damage(damage, global_position, "smash", null)
	queue_free()
