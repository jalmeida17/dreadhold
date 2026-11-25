extends Node
## Base class for class kits: resource, cooldowns, first-person weapon animation state.

var player: Node
var resource := 0.0
var resource_max := 100.0
var resource_regen := 0.0
var weapon_tex: Texture2D
var weapon_frames := 4
var weapon_frame := 0
var weapon_x := 0.0
var weapon_y := 0.0
var kick := Vector2.ZERO
var cooldowns := {}
var base_cooldowns := {}
var costs := {}
var attack_timer := 0.0
var anim_t := 0.0
var anim := ""


func setup(p: Node) -> void:
	player = p


func max_resource() -> float:
	return resource_max + float(player.mods.resource_max)


func tick(delta: float) -> void:
	for k in cooldowns:
		cooldowns[k] = maxf(float(cooldowns[k]) - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	kick = kick.lerp(Vector2.ZERO, clampf(delta * 10.0, 0.0, 1.0))
	if anim != "":
		anim_t += delta
	_update(delta)
	resource = clampf(resource, 0.0, max_resource())


func _update(_delta: float) -> void:
	pass


func handle_input(_delta: float) -> void:
	if Input.is_action_pressed("attack_primary") and attack_timer <= 0.0:
		primary()
	if Input.is_action_just_pressed("attack_secondary"):
		try_ability("secondary")
	if Input.is_action_just_pressed("ability_utility"):
		try_ability("utility")


func try_ability(slot: String) -> void:
	if float(cooldowns.get(slot, 0.0)) > 0.0:
		return
	var cost := ability_cost(slot)
	if resource < cost:
		Sfx.play("ui_click", -8.0, 0.0, 0.3)
		return
	if call(slot):
		resource -= cost
		cooldowns[slot] = float(base_cooldowns.get(slot, 1.0)) * float(player.mods.cooldown)


func ability_cost(slot: String) -> float:
	return float(costs.get(slot, 0.0))


func cooldown_ratio(slot: String) -> float:
	var base := float(base_cooldowns.get(slot, 0.0)) * float(player.mods.cooldown)
	if base <= 0.0:
		return 0.0
	return clampf(float(cooldowns.get(slot, 0.0)) / base, 0.0, 1.0)


func primary() -> void:
	pass


func secondary() -> bool:
	return false


func utility() -> bool:
	return false


func start_anim(n: String) -> void:
	anim = n
	anim_t = 0.0


func on_damaged(_amount: float) -> void:
	pass


func net_pose() -> int:
	## What the ally should see: 0 idle/moving, 1 wind-up, 2 strike, 3 big cast.
	if anim in ["spin", "frost"]:
		return 3
	if weapon_frame == 1:
		return 1
	if anim != "" or weapon_frame >= 2:
		return 2
	return 0


func on_kill(_enemy: Node) -> void:
	pass


func on_dash_step(_delta: float) -> void:
	pass


func aim_origin() -> Vector3:
	return player.eye_position() + player.forward() * 0.4 + Vector3(0, -0.12, 0)


func scene_root() -> Node:
	return player.get_parent()
