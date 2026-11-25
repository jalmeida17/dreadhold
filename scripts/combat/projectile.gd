extends Node3D
## Ray-stepped projectile (fireballs, arrows, shadow bolts, soul orbs).
## Player projectiles hit world + enemies, enemy projectiles hit world + player.

const Fx := preload("res://scripts/combat/fx.gd")
const Sprites := preload("res://scripts/util/sprites.gd")

const MASK_PLAYER_SHOTS := 1 | 4
const MASK_ENEMY_SHOTS := 1 | 2

var kind := "fireball"
var velocity := Vector3.ZERO
var damage := 10.0
var splash_radius := 0.0
var splash_damage := 0.0
var from_player := true
var owner_player: Node = null
var owner_enemy: Node = null
var target: Node3D = null
var homing := 0.0
var pierce := 0
var life := 3.5
var gravity := 0.0
var crit := false
var knockback := 2.0
var _exclude: Array[RID] = []
var _sprite: Sprite3D
var _t := 0.0


static func launch(parent: Node, p_kind: String, pos: Vector3, vel: Vector3, dmg: float, by_player: bool) -> Node3D:
	var p: Node3D = load("res://scripts/combat/projectile.gd").new()
	p.kind = p_kind
	p.velocity = vel
	p.damage = dmg
	p.from_player = by_player
	parent.add_child(p)
	p.global_position = pos
	p._build_visual()
	return p


func _build_visual() -> void:
	match kind:
		"fireball", "shadow", "soul", "acid", "ember", "ice":
			var sheet: String = {"fireball": "fireball", "shadow": "shadow_bolt", "soul": "soul_bolt", "acid": "soul_bolt", "ember": "fireball", "ice": "shadow_bolt"}[kind]
			var tex: Texture2D = load("res://assets/sprites/fx/%s.png" % sheet)
			_sprite = Sprite3D.new()
			_sprite.texture = tex
			_sprite.hframes = Sprites.frame_count(tex)
			var size: float = {"fireball": 0.75, "shadow": 0.6, "soul": 0.8, "acid": 0.8, "ember": 0.9, "ice": 0.7}[kind]
			_sprite.pixel_size = size / float(tex.get_height())
			_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			_sprite.shaded = false
			_sprite.modulate = {"acid": Color(1.2, 1.4, 0.4), "ice": Color(0.6, 1.2, 1.6)}.get(kind, Color(1, 1, 1))
			add_child(_sprite)
			var l := OmniLight3D.new()
			l.light_color = {"fireball": Color(1.0, 0.55, 0.2), "shadow": Color(0.7, 0.3, 1.0), "soul": Color(0.4, 1.0, 0.5), "acid": Color(0.7, 1.0, 0.3), "ember": Color(1.0, 0.5, 0.15), "ice": Color(0.5, 0.85, 1.0)}[kind]
			l.light_energy = 1.6
			l.omni_range = 5.0
			add_child(l)
		"arrow", "enemy_arrow":
			_build_arrow()
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)


func _build_arrow() -> void:
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, 0.8)
	shaft.mesh = bm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.36, 0.22) if kind == "arrow" else Color(0.55, 0.52, 0.45)
	shaft.material_override = wood
	add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := PrismMesh.new()
	hm.size = Vector3(0.09, 0.14, 0.03)
	head.mesh = hm
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.78)
	steel.metallic = 0.7
	head.material_override = steel
	head.rotation_degrees = Vector3(-90, 0, 0)
	head.position = Vector3(0, 0, -0.45)
	add_child(head)
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.12, 0.01, 0.16)
	fl.mesh = fm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.1, 0.08) if kind == "arrow" else Color(0.2, 0.25, 0.15)
	fl.material_override = red
	fl.position = Vector3(0, 0, 0.32)
	add_child(fl)
	var fl2 := fl.duplicate()
	fl2.rotation_degrees = Vector3(0, 0, 90)
	add_child(fl2)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if _sprite != null:
		_sprite.frame = int(_t * 14.0) % _sprite.hframes
	if homing > 0.0 and is_instance_valid(target):
		var to := (target.global_position + Vector3(0, 1.2, 0) - global_position).normalized()
		var spd := velocity.length()
		velocity = velocity.normalized().slerp(to, clampf(homing * delta, 0.0, 1.0)) * spd
	velocity.y -= gravity * delta
	var from := global_position
	var to_pos := from + velocity * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to_pos, MASK_PLAYER_SHOTS if from_player else MASK_ENEMY_SHOTS, _exclude)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position = to_pos
		if kind == "arrow" or kind == "enemy_arrow":
			look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)
		return
	var col: Object = hit.collider
	var point: Vector3 = hit.position
	if from_player and col != null and col.has_method("hurt"):
		var dealt := damage
		if owner_player != null:
			dealt = owner_player.compute_damage(damage, col)
		col.hurt(dealt, from, knockback, owner_player)
		if pierce > 0:
			pierce -= 1
			_exclude.append(hit.rid)
			global_position = point + velocity.normalized() * 0.05
			return
	elif not from_player and col != null and col.has_method("take_damage"):
		col.take_damage(damage, from, "ranged", owner_enemy if is_instance_valid(owner_enemy) else null)
	_impact(point, hit.normal, col)


func _impact(point: Vector3, normal: Vector3, col: Object) -> void:
	var scene := get_parent()
	match kind:
		"ice":
			Fx.spawn(scene, "frost", point, 1.4, 14.0)
			Sfx.play_at("ice_shatter", point, -5.0)
			if not from_player and col != null and col.has_method("apply_slow"):
				col.apply_slow(1.2)
		"fireball", "ember":
			Fx.spawn(scene, "explosion", point + normal * 0.2, 1.4 + splash_radius * 0.5, 18.0)
			Fx.flash(scene, point + normal * 0.4, Color(1.0, 0.55, 0.2), 4.0, 7.0, 0.3)
			Sfx.play_at("fireball_explode", point, -2.0)
		"shadow":
			Fx.spawn(scene, "shadow_bolt", point, 1.0, 20.0)
			Fx.flash(scene, point, Color(0.6, 0.2, 1.0), 2.5, 5.0, 0.25)
			Sfx.play_at("bolt_impact", point, -3.0)
		"soul", "acid":
			Fx.spawn(scene, "portal", point, 1.4, 16.0)
			Fx.flash(scene, point, Color(0.3, 1.0, 0.4), 3.0, 6.0, 0.3)
			Sfx.play_at("acid_splash" if kind == "acid" else "bolt_impact", point, -1.0)
		_:
			var on_enemy := col != null and col.has_method("hurt")
			if not on_enemy:
				Fx.spawn(scene, "dust", point + normal * 0.1, 0.6, 16.0)
				Sfx.play_at("arrow_hit", point, -6.0)
	if splash_radius > 0.0 and splash_damage > 0.0:
		if from_player:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e == col or not e.is_alive():
					continue
				var d: float = e.global_position.distance_to(point)
				if d <= splash_radius + e.radius:
					var dmg := splash_damage * (1.0 - 0.5 * clampf(d / splash_radius, 0.0, 1.0))
					if owner_player != null:
						dmg = owner_player.compute_damage(dmg, e)
					e.hurt(dmg, point, 3.0, owner_player)
		else:
			var pl := get_tree().get_first_node_in_group("player")
			if pl != null and pl != col and pl.global_position.distance_to(point) <= splash_radius:
				pl.take_damage(splash_damage, point, "ranged", owner_enemy if is_instance_valid(owner_enemy) else null)
	queue_free()
