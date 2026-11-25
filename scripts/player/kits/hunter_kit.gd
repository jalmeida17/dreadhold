extends "res://scripts/player/kits/kit.gd"
## Hunter: Arrow Shot (LMB), Volley (RMB, 40 focus), Shadow Step (utility).

const Projectile := preload("res://scripts/combat/projectile.gd")

const SHOT_TIME := 0.38
var _release_t := 0.0


func setup(p: Node) -> void:
	super.setup(p)
	resource_max = 100.0
	resource = 100.0
	weapon_tex = load("res://assets/weapons/bow.png")
	weapon_frames = 3
	weapon_x = 0.0
	base_cooldowns = {"secondary": 3.5, "utility": 4.5}
	costs = {"secondary": 40.0}


func _update(delta: float) -> void:
	resource += 14.0 * float(player.mods.resource_regen) * delta
	_release_t = maxf(_release_t - delta, 0.0)
	if _release_t > 0.0:
		weapon_frame = 2
	elif attack_timer <= 0.05 and Input.is_action_pressed("attack_primary"):
		weapon_frame = 1
	else:
		weapon_frame = 0


func _shoot(dir: Vector3, dmg: float) -> void:
	var p := Projectile.launch(scene_root(), "arrow", aim_origin(), dir * 58.0, dmg, true)
	p.owner_player = player
	p.pierce = int(player.mods.pierce)
	p.knockback = 1.5
	player.echo_shot("arrow", aim_origin(), dir * 58.0)


func primary() -> void:
	attack_timer = SHOT_TIME / float(player.mods.attack_speed)
	_release_t = 0.12
	kick = Vector2(6, 8)
	_shoot(player.forward(), 27.0)
	Sfx.play("bow_shoot", -2.0, 0.1)
	player.echo("bow")


func secondary() -> bool:
	var count := 7 + int(player.mods.volley_extra)
	var fwd: Vector3 = player.forward()
	for i in count:
		var a := lerpf(-0.3, 0.3, float(i) / float(count - 1))
		_shoot(fwd.rotated(Vector3.UP, a), 21.0)
	_release_t = 0.18
	kick = Vector2(10, 14)
	player.power_flash = 1.0
	Sfx.play("volley")
	player.echo("volley")
	return true


func utility() -> bool:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = player.transform.basis * Vector3(input.x, 0, input.y)
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -player.flat_forward()
	player.start_dash(dir, 26.0, 0.22)
	player.invuln = 0.3
	player.fov_kick = 10.0
	Sfx.play("dash")
	player.echo("dash")
	return true
