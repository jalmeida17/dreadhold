extends "res://scripts/player/kits/kit.gd"
## Warrior: Cleave (LMB), Reaving Spin (RMB, 35 rage), Iron Charge (utility).

const Fx := preload("res://scripts/combat/fx.gd")

const SWING_TIME := 0.56
const HIT_AT := 0.13
var _swing_hit_done := true
var _out_of_combat := 0.0


func setup(p: Node) -> void:
	super.setup(p)
	resource = 0.0
	resource_max = 100.0
	weapon_tex = load("res://assets/weapons/axe.png")
	weapon_frames = 4
	weapon_x = 150.0
	weapon_y = 70.0
	base_cooldowns = {"secondary": 4.5, "utility": 7.0}
	costs = {"secondary": 35.0}


func _update(delta: float) -> void:
	_out_of_combat += delta
	if _out_of_combat > 3.0:
		resource -= 6.0 * delta
	# swing animation frames: wind-up, smear, follow-through
	match anim:
		"swing":
			if anim_t < 0.07:
				weapon_frame = 1
			elif anim_t < 0.2:
				weapon_frame = 2
			elif anim_t < 0.33:
				weapon_frame = 3
			else:
				weapon_frame = 0
				anim = ""
			if not _swing_hit_done and anim_t >= HIT_AT:
				_swing_hit_done = true
				_cleave_hit()
		"spin":
			var phase := int(anim_t / 0.08) % 3
			weapon_frame = [1, 2, 3][phase]
			if anim_t > 0.45:
				anim = ""
				weapon_frame = 0
		_:
			weapon_frame = 0


func primary() -> void:
	attack_timer = SWING_TIME / float(player.mods.attack_speed)
	start_anim("swing")
	_swing_hit_done = false
	kick = Vector2(-10, 6)
	Sfx.play("swing", -2.0, 0.12)


func _cleave_hit() -> void:
	var reach := 2.7 + float(player.mods.cleave_range)
	var min_dot := 0.35 - float(player.mods.cleave_range) * 0.25
	var hits: Array = player.enemies_in_cone(player.global_position, player.forward(), reach, min_dot)
	var gained := 0.0
	for e in hits:
		var dmg: float = player.compute_damage(36.0 + (10.0 if player.has_torch else 0.0), e)
		e.hurt(dmg, player.global_position, 5.0, player)
		gained += 7.0
		if player.mods.cleave_heal > 0.0:
			player.heal(player.mods.cleave_heal, false)
	if hits.size() > 0:
		resource += minf(gained, 20.0)
		_out_of_combat = 0.0
		player.shake = minf(player.shake + 0.25, 1.0)
		kick += Vector2(-6, 4)
	else:
		# wall clank if we hit geometry in front
		var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(player.eye_position(), player.eye_position() + player.forward() * 2.4, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			Sfx.play("hit_metal", -4.0)
			Fx.spawn(scene_root(), "dust", hit.position + hit.normal * 0.1, 0.5, 16.0)


func secondary() -> bool:
	start_anim("spin")
	var reach := 3.8 + float(player.mods.spin_bonus)
	var hits: Array = player.enemies_in_radius(player.global_position, reach)
	for e in hits:
		var dmg: float = player.compute_damage(52.0, e)
		e.hurt(dmg, player.global_position, 8.0, player)
	Sfx.play("spin")
	Fx.ring(scene_root(), player.global_position, reach, Color(1.0, 0.85, 0.7, 0.9), 0.3)
	player.power_flash = 1.0
	player.shake = 0.5
	_out_of_combat = 0.0
	return true


func ability_cost(slot: String) -> float:
	if slot == "secondary":
		return maxf(35.0 - 10.0 * float(player.mods.spin_bonus), 10.0)
	return super.ability_cost(slot)


func utility() -> bool:
	var dir: Vector3 = player.flat_forward()
	player.start_dash(dir, 24.0, 0.42)
	player.invuln = 0.45
	player.fov_kick = 14.0
	player.power_flash = 1.0
	resource += 15.0
	_out_of_combat = 0.0
	Sfx.play("charge")
	cooldowns["utility"] = 0.0
	base_cooldowns["utility"] = 7.0 - 2.0 * float(player.mods.charge_bonus)
	return true


func on_dash_step(_delta: float) -> void:
	for e in player.enemies_in_radius(player.global_position, 1.6):
		if player.dash_hits.has(e):
			continue
		player.dash_hits[e] = true
		var dmg: float = player.compute_damage(28.0, e)
		e.hurt(dmg, player.global_position, 10.0, player)
		e.stun(1.2 + 0.6 * float(player.mods.charge_bonus))
		Sfx.play("hit_flesh")


func on_damaged(amount: float) -> void:
	resource += amount * 0.6
	_out_of_combat = 0.0
