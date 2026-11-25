extends "res://scripts/player/kits/kit.gd"
## Mage: Fireball (LMB, 6 mana), Frost Nova (RMB, 35 mana), Blink (utility).

const Projectile := preload("res://scripts/combat/projectile.gd")
const Fx := preload("res://scripts/combat/fx.gd")

const CAST_TIME := 0.42
const FIREBALL_COST := 6.0


func setup(p: Node) -> void:
	super.setup(p)
	resource_max = 100.0
	resource = 100.0
	weapon_tex = load("res://assets/weapons/staff.png")
	weapon_frames = 4
	weapon_x = 0.0
	base_cooldowns = {"secondary": 7.0, "utility": 6.0}
	costs = {"secondary": 35.0}


func _update(delta: float) -> void:
	resource += 9.0 * float(player.mods.resource_regen) * delta
	match anim:
		"cast":
			weapon_frame = 1 if anim_t < 0.09 else (2 if anim_t < 0.22 else 0)
			if anim_t > 0.22:
				anim = ""
		"frost":
			weapon_frame = 3 if anim_t < 0.3 else 0
			if anim_t > 0.3:
				anim = ""
		_:
			weapon_frame = 0


func primary() -> void:
	if resource < FIREBALL_COST:
		attack_timer = 0.25
		Sfx.play("ui_click", -10.0, 0.0, 0.3)
		return
	resource -= FIREBALL_COST
	attack_timer = CAST_TIME / float(player.mods.attack_speed)
	start_anim("cast")
	kick = Vector2(-4, 10)
	var count := 1 + int(player.mods.extra_fireball)
	var fwd: Vector3 = player.forward()
	for i in count:
		var spread := 0.0 if count == 1 else lerpf(-0.07, 0.07, float(i) / float(count - 1))
		var dir := fwd.rotated(Vector3.UP, spread)
		var p := Projectile.launch(scene_root(), "fireball", aim_origin(), dir * 28.0, 26.0, true)
		p.owner_player = player
		p.splash_radius = 2.3 * (1.0 + float(player.mods.splash))
		p.splash_damage = 18.0
	Sfx.play("fireball_cast", -3.0)


func secondary() -> bool:
	start_anim("frost")
	var reach := 6.0 + 1.5 * float(player.mods.nova_bonus)
	for e in player.enemies_in_radius(player.global_position, reach):
		var dmg: float = player.compute_damage(30.0, e)
		e.hurt(dmg, player.global_position, 2.0, player)
		e.stun(2.4 + 0.8 * float(player.mods.nova_bonus), true)
	Fx.ring(scene_root(), player.global_position, reach, Color(0.7, 0.95, 1.0, 1.0), 0.45)
	Fx.flash(scene_root(), player.global_position + Vector3(0, 1, 0), Color(0.5, 0.85, 1.0), 4.0, reach + 2.0, 0.4)
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var pos: Vector3 = player.global_position + Vector3(cos(a), 0.4, sin(a)) * reach * 0.7
		Fx.spawn(scene_root(), "frost", pos, 1.2, 10.0)
	Sfx.play("frost_nova")
	player.power_flash = 1.0
	return true


func utility() -> bool:
	var origin: Vector3 = player.global_position + Vector3(0, 0.9, 0)
	var dir: Vector3 = player.flat_forward()
	var dist := 8.0
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * dist, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		dist = maxf(origin.distance_to(hit.position) - 0.7, 0.0)
	if dist < 1.0:
		return false
	Fx.spawn(scene_root(), "portal", player.global_position + Vector3(0, 1.0, 0), 1.8, 18.0)
	player.global_position += dir * dist
	Fx.spawn(scene_root(), "portal", player.global_position + Vector3(0, 1.0, 0), 1.8, 18.0)
	player.invuln = 0.3
	player.fov_kick = 18.0
	player.power_flash = 1.0
	Sfx.play("blink")
	return true
