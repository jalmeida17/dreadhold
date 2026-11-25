extends CharacterBody3D
## First-person player: movement, mouse look, health, damage maths, boons, pickups.
## Class abilities live in a "kit" child node (scripts/player/kits/*).

signal died
signal boon_applied(id: String)

const ClassData := preload("res://scripts/data/classes.gd")
const Boons := preload("res://scripts/data/boons.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const KITS := {
	"warrior": preload("res://scripts/player/kits/warrior_kit.gd"),
	"mage": preload("res://scripts/player/kits/mage_kit.gd"),
	"hunter": preload("res://scripts/player/kits/hunter_kit.gd"),
}

const EYE_HEIGHT := 1.6
const GRAVITY := 24.0
const JUMP_VELOCITY := 7.0
const ACCEL := 70.0
const AIR_ACCEL := 18.0
const FRICTION := 55.0

var class_id := "warrior"
var cdef: Dictionary
var kit: Node
var head: Node3D
var camera: Camera3D
var arena: Node3D
var director: Node

var max_hp := 100.0
var hp := 100.0
var base_armor := 0.0
var base_speed := 8.0
var mods := {
	"damage": 1.0, "speed": 1.0, "cooldown": 1.0, "attack_speed": 1.0, "regen": 0.0, "lifesteal": 0.0,
	"crit": 0.05, "crit_mult": 2.0, "armor": 0.0, "resource_max": 0.0, "resource_regen": 1.0, "gold": 1.0,
	"execute": 0.0, "thorns": 0.0,
	"cleave_range": 0.0, "cleave_heal": 0.0, "spin_bonus": 0.0, "charge_bonus": 0.0,
	"splash": 0.0, "extra_fireball": 0.0, "nova_bonus": 0.0, "pierce": 0.0, "volley_extra": 0.0,
}
var boons := {}
var potions := 1
var max_potions := 3
var gold := 0
var kills := 0
var undying := 0
var alive := true

var yaw := 0.0
var pitch := 0.0
var hurt_flash := 0.0
var heal_flash := 0.0
var power_flash := 0.0
var shake := 0.0
var bob_t := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var move_amount := 0.0
var invuln := 0.0
var dash_time := 0.0
var dash_velocity := Vector3.ZERO
var dash_hits := {}
var potion_heal_left := 0.0
var last_hurt_time := -10.0
var time_alive := 0.0
var fov_kick := 0.0
var hit_marker := 0.0
var slow_t := 0.0
var has_torch := false
var _torch_light: OmniLight3D
var weapon_tier := 0
var _death_t := 0.0


func setup(p_class: String, p_arena: Node3D, p_director: Node) -> void:
	class_id = p_class
	arena = p_arena
	director = p_director
	cdef = ClassData.CLASSES[class_id]
	max_hp = cdef.max_hp
	hp = max_hp
	base_armor = cdef.armor
	base_speed = cdef.speed
	if class_id == "hunter":
		mods.crit = 0.15
	name = "Player"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 200.0
	head.add_child(camera)
	camera.current = true
	kit = KITS[class_id].new()
	kit.name = "Kit"
	add_child(kit)
	kit.setup(self)


# =================================================================== input & movement

func look(relative: Vector2) -> void:
	## Mouse look, forwarded by the mode root (the 3D world lives in a SubViewport).
	if not alive:
		return
	var sens: float = Game.settings.mouse_sens * 0.01
	yaw -= relative.x * sens
	pitch = clampf(pitch - relative.y * sens, deg_to_rad(-80), deg_to_rad(80))
	rotation.y = yaw
	head.rotation.x = pitch


func look_at_point(p: Vector3) -> void:
	var d := p - global_position
	yaw = atan2(-d.x, -d.z)


func forward() -> Vector3:
	return -camera.global_transform.basis.z


func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func eye_position() -> Vector3:
	return camera.global_position


func move_speed() -> float:
	return base_speed * mods.speed * (0.55 if slow_t > 0.0 else 1.0)


func apply_slow(duration: float) -> void:
	## Chilled by frost magic: move at about half speed for a while.
	slow_t = maxf(slow_t, duration)


func equip_torch() -> void:
	## Off-hand torch (warrior): a warm light that follows the view; Cleave burns.
	if has_torch:
		return
	has_torch = true
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.62, 0.28)
	_torch_light.light_energy = 1.8
	_torch_light.omni_range = 11.0
	_torch_light.omni_attenuation = 1.1
	_torch_light.position = Vector3(-0.45, -0.25, -0.5)
	camera.add_child(_torch_light)
	Sfx.play("fireball_cast", -4.0)


func weapon() -> Dictionary:
	return Weapons.WEAPONS[class_id][weapon_tier]


func upgrade_weapon() -> bool:
	## Claim the next weapon tier (after a boss). Returns false at the last tier.
	var tiers: Array = Weapons.WEAPONS[class_id]
	if weapon_tier >= tiers.size() - 1:
		return false
	weapon_tier += 1
	var w: Dictionary = tiers[weapon_tier]
	var b: Dictionary = w.bonus
	for k in b:
		mods[k] = float(mods.get(k, 0.0)) + float(b[k])
	if ResourceLoader.exists(w.sheet):
		kit.weapon_tex = load(w.sheet)
	power_flash = 1.0
	Sfx.play("boon_select")
	return true


func _physics_process(delta: float) -> void:
	rotation.y = yaw
	head.rotation.x = pitch
	if not alive:
		_death_t += delta
		head.position.y = lerpf(head.position.y, 0.35, clampf(delta * 3.0, 0, 1))
		camera.rotation.z = lerpf(camera.rotation.z, 0.5, clampf(delta * 2.0, 0, 1))
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	time_alive += delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if _controls_active() else Vector2.ZERO
	var wish := (transform.basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	if wish.length() > 1.0:
		wish = wish.normalized()
	if dash_time > 0.0:
		dash_time -= delta
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta * 0.3
		kit.on_dash_step(delta)
	else:
		var target := wish * move_speed()
		var hv := Vector3(velocity.x, 0, velocity.z)
		var accel := ACCEL if is_on_floor() else AIR_ACCEL
		if wish.length() > 0.01:
			hv = hv.move_toward(target, accel * delta)
		elif is_on_floor():
			hv = hv.move_toward(Vector3.ZERO, FRICTION * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif _controls_active() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			Sfx.play("jump", -10.0, 0.08, 0.2)
	var bob_before := bob_t
	move_and_slide()
	# view bob
	var hspeed := Vector2(velocity.x, velocity.z).length()
	move_amount = lerpf(move_amount, clampf(hspeed / move_speed(), 0.0, 1.0) if is_on_floor() else 0.0, clampf(delta * 10.0, 0, 1))
	bob_t += delta * hspeed * 0.95
	_movement_sounds(bob_before, hspeed)
	var shake_off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.06
	head.position = Vector3(0, EYE_HEIGHT + sin(bob_t * 2.0) * 0.045 * move_amount, 0) + shake_off
	shake = maxf(shake - delta * 3.0, 0.0)
	camera.fov = lerpf(camera.fov, 72.0 + fov_kick, clampf(delta * 12.0, 0, 1))
	fov_kick = move_toward(fov_kick, 0.0, delta * 40.0)


func _process(delta: float) -> void:
	hurt_flash = maxf(hurt_flash - delta * 1.6, 0.0)
	heal_flash = maxf(heal_flash - delta * 1.5, 0.0)
	if alive and hp < max_hp * 0.3:
		# the heart races as the champion bleeds out
		var k := clampf(hp / (max_hp * 0.3), 0.0, 1.0)
		Sfx.play("heartbeat", lerpf(-2.0, -9.0, k), 0.0, lerpf(0.62, 1.05, k))
	power_flash = maxf(power_flash - delta * 2.5, 0.0)
	hit_marker = maxf(hit_marker - delta * 5.0, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	slow_t = maxf(slow_t - delta, 0.0)
	if _torch_light != null:
		var tt := Time.get_ticks_msec() * 0.001
		_torch_light.light_energy = 1.8 * (0.85 + 0.15 * sin(tt * 11.0) * sin(tt * 6.7))
	if not alive:
		return
	if mods.regen > 0.0:
		heal(mods.regen * delta, false)
	if potion_heal_left > 0.0:
		var step := minf(potion_heal_left, max_hp * 1.2 * delta)
		potion_heal_left -= step
		heal(step, false)
	if _controls_active():
		kit.handle_input(delta)
		if Input.is_action_just_pressed("use_potion"):
			drink_potion()
	elif Game.test.has("bot") and not get_tree().paused:
		_bot(delta)
	kit.tick(delta)


func _bot(_delta: float) -> void:
	## Test autopilot: aim at the nearest enemy and attack.
	var best: Node3D = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive():
			var dd: float = global_position.distance_to(e.global_position)
			if dd < bd:
				bd = dd
				best = e
	if best == null:
		return
	var to := best.global_position + Vector3(0, 1.0, 0) - eye_position()
	yaw = atan2(-to.x, -to.z)
	pitch = atan2(to.y, Vector2(to.x, to.z).length())
	rotation.y = yaw
	head.rotation.x = pitch
	if kit.attack_timer <= 0.0:
		kit.primary()
	if bd < 5.0 and float(kit.cooldowns.get("secondary", 0.0)) <= 0.0:
		kit.try_ability("secondary")
	if hp < max_hp * 0.4:
		drink_potion()


func _movement_sounds(bob_before: float, hspeed: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	elif not _was_on_floor:
		if _fall_speed > 6.0:
			Sfx.play("land", lerpf(-12.0, -3.0, clampf((_fall_speed - 6.0) / 10.0, 0.0, 1.0)), 0.08, 0.15)
		_fall_speed = 0.0
	_was_on_floor = on_floor
	# one footstep at each low point of the view bob (sin(2 * bob_t) bottoms out at 3/4 PI + k PI)
	if on_floor and dash_time <= 0.0 and hspeed > 1.5:
		if floori((bob_t - 0.75 * PI) / PI) != floori((bob_before - 0.75 * PI) / PI):
			Sfx.play("footstep_%d" % randi_range(1, 3), -15.0, 0.1, 0.12)


func _controls_active() -> bool:
	return alive and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused


func start_dash(dir: Vector3, speed: float, duration: float) -> void:
	dash_velocity = dir.normalized() * speed
	dash_time = duration
	dash_hits.clear()


# =================================================================== health

func take_damage(amount: float, from_pos: Vector3 = Vector3.INF, kind: String = "melee", source: Node = null) -> void:
	if not alive or invuln > 0.0:
		return
	var reduction := clampf(base_armor + mods.armor, 0.0, 0.75)
	var dmg := amount * (1.0 - reduction)
	hp -= dmg
	director.stat_add("damage_taken", dmg)
	last_hurt_time = time_alive
	hurt_flash = minf(hurt_flash + 0.35 + dmg / 40.0, 1.0)
	shake = minf(shake + 0.5 + dmg / 25.0, 1.6)
	kit.on_damaged(dmg)
	Sfx.play("player_hurt", -2.0, 0.1, 0.25)
	if kind == "melee" and mods.thorns > 0.0 and source != null and is_instance_valid(source) and source.has_method("hurt"):
		source.hurt(amount * mods.thorns, global_position, 1.0, self)
	if from_pos != Vector3.INF and kind == "smash":
		var push := global_position - from_pos
		push.y = 0
		velocity += push.normalized() * 9.0 + Vector3(0, 4.0, 0)
	if hp <= 0.0:
		if undying > 0:
			undying -= 1
			hp = max_hp * 0.4
			invuln = 1.5
			heal_flash = 1.0
			Sfx.play("boon_select")
			director.show_message("UNDYING OATH!", Color(1.0, 0.6, 0.15))
			return
		hp = 0.0
		_die()


func heal(amount: float, flash: bool = true) -> void:
	if not alive:
		return
	hp = minf(hp + amount, max_hp)
	if flash and amount > 1.0:
		heal_flash = minf(heal_flash + 0.5, 1.0)


func _die() -> void:
	alive = false
	Sfx.play("player_death")
	shake = 1.0
	died.emit()


func drink_potion() -> void:
	if potions <= 0 or hp >= max_hp:
		return
	potions -= 1
	director.stat_add("potions_used", 1)
	potion_heal_left += max_hp * 0.5
	heal_flash = 1.0
	Sfx.play("potion_drink")


func collect(kind: String, amount: int) -> bool:
	match kind:
		"gold":
			var g := int(round(amount * mods.gold))
			gold += g
			director.stat_add("gold_earned", g)
			Sfx.play("coin_pickup", -4.0, 0.12, 0.05)
			director.pickup_message("+%d gold" % g)
			return true
		"potion":
			if potions < max_potions:
				potions += 1
				Sfx.play("item_pickup")
				director.pickup_message("Health potion")
				return true
			if hp < max_hp:
				heal(max_hp * 0.2)
				Sfx.play("item_pickup")
				director.pickup_message("Healed")
				return true
			return false
	return false


# =================================================================== offence

func compute_damage(base: float, target: Node) -> float:
	## Applies damage multipliers, crits, execute; also triggers lifesteal and the hit marker.
	var dmg: float = base * mods.damage
	if mods.execute > 0.0 and target != null and target.has_method("hp_ratio") and target.hp_ratio() < 0.35:
		dmg *= 1.0 + mods.execute
	if randf() < mods.crit:
		dmg *= mods.crit_mult
		hit_marker = 1.0
	else:
		hit_marker = maxf(hit_marker, 0.6)
	if mods.lifesteal > 0.0:
		heal(dmg * mods.lifesteal, false)
	director.stat_add("damage_dealt", dmg)
	director.stat_max("biggest_hit", dmg)
	return dmg


func on_kill(enemy: Node) -> void:
	kills += 1
	kit.on_kill(enemy)


func enemies_in_cone(origin: Vector3, dir: Vector3, reach: float, min_dot: float) -> Array:
	var out: Array = []
	var flat_dir := Vector3(dir.x, 0, dir.z).normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0
		var d := to.length() - float(e.radius)
		if d > reach:
			continue
		if d < 0.6 or flat_dir.dot(to.normalized()) >= min_dot:
			out.append(e)
	return out


func enemies_in_radius(origin: Vector3, r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0
		if to.length() - float(e.radius) <= r:
			out.append(e)
	return out


# =================================================================== boons

func apply_boon(id: String) -> void:
	var b: Dictionary = Boons.BOONS[id]
	boons[id] = int(boons.get(id, 0)) + 1
	var m: Dictionary = b.get("mods", {})
	for k in m:
		mods[k] = float(mods.get(k, 0.0)) + float(m[k])
	mods.cooldown = maxf(mods.cooldown, 0.35)
	var s: Dictionary = b.get("special", {})
	if s.has("max_hp"):
		max_hp += s.max_hp
		heal(s.max_hp)
	if s.has("potion_cap"):
		max_potions += int(s.potion_cap)
		potions = max_potions
	if s.has("undying"):
		undying += 1
	power_flash = 1.0
	boon_applied.emit(id)


func resource_ratio() -> float:
	return kit.resource / maxf(kit.max_resource(), 1.0)
