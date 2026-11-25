extends CharacterBody3D
## Generic enemy driven by scripts/data/enemies.gd. Doom-style behaviour: chase through a
## flow field, attack with a telegraphed wind-up, flinch in pain, die into a corpse sprite.

const EnemyData := preload("res://scripts/data/enemies.gd")
const Sprites := preload("res://scripts/util/sprites.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const Pickup := preload("res://scripts/combat/pickup.gd")
const Hazard := preload("res://scripts/combat/hazard.gd")

enum State { SPAWN, CHASE, WINDUP, STRIKE, PAIN, STUN, DEAD }

const GRAVITY := 24.0

var type_id := "ghoul"
var d: Dictionary
var arena: Node3D
var player: Node3D
var director: Node
var sprite: Sprite3D
var hp := 10.0
var max_hp := 10.0
var damage := 5.0
var speed := 3.0
var radius := 0.4
var state := State.SPAWN
var state_t := 0.0
var atk_cd := 1.0
var los := false
var _los_t := 0.0
var _walk_t := 0.0
var _flash_t := 0.0
var _frozen := false
var _stun_left := 0.0
var _knock := Vector3.ZERO
var _alerted := false
var _strafe := 1.0
var _cast_cd := 6.0
var _cast_mode := ""
var _dist := 99.0
var _spawn_h := 0.0
var is_boss := false
var phase := 1
var _base_tint := Color(1, 1, 1)
var _atk_mult := 1.0


func setup(p_type: String, p_arena: Node3D, p_player: Node3D, p_director: Node, level: int) -> void:
	type_id = p_type
	d = EnemyData.TYPES[type_id]
	arena = p_arena
	player = p_player
	director = p_director
	is_boss = d.get("boss", false)
	var scale_hp := 1.0 + 0.09 * float(level - 1)
	var scale_dmg := 1.0 + 0.05 * float(level - 1)
	if is_boss:
		scale_hp = 1.0 + 0.35 * float(level / 5 - 1)
	max_hp = float(d.hp) * scale_hp
	hp = max_hp
	damage = float(d.damage) * scale_dmg
	speed = float(d.speed) * randf_range(0.92, 1.08)
	radius = d.radius
	atk_cd = randf_range(0.5, 1.5)
	_strafe = 1.0 if randf() < 0.5 else -1.0
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(float(d.body_h), radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	var tex: Texture2D
	var tint := Color(1, 1, 1)
	if ResourceLoader.exists(d.sheet):
		tex = load(d.sheet)
	else:
		tex = load("res://assets/sprites/enemies/boss.png")
		tint = d.get("tint", Color(1, 1, 1))
	sprite = Sprites.make(tex, int(d.frames), float(d.height), true, true)
	_base_tint = tint
	add_child(sprite)
	_spawn_h = float(d.height)
	sprite.position.y = -_spawn_h * 0.5
	state = State.SPAWN
	state_t = 0.0


func is_alive() -> bool:
	return state != State.DEAD and state != State.SPAWN


func hp_ratio() -> float:
	return hp / max_hp


func _set_state(s: State) -> void:
	state = s
	state_t = 0.0


func _physics_process(delta: float) -> void:
	state_t += delta
	_flash_t = maxf(_flash_t - delta, 0.0)
	atk_cd -= delta
	if state == State.DEAD:
		_process_dead(delta)
		return
	if state == State.SPAWN:
		var k := clampf(state_t / 0.9, 0.0, 1.0)
		sprite.position.y = lerpf(-_spawn_h * 0.5, _spawn_h * 0.5, k * k * (3.0 - 2.0 * k))
		sprite.frame = EnemyData.FRAME_WALK_A
		if state_t >= 0.9:
			sprite.position.y = _spawn_h * 0.5
			_set_state(State.CHASE)
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	_dist = to_player.length()
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.25 + randf() * 0.1
		los = player.alive and arena.has_los(global_position + Vector3(0, float(d.body_h) * 0.8, 0), player.eye_position())
		if los and not _alerted and _dist < 30.0:
			_alerted = true
			Sfx.play_at(d.alert, global_position, -2.0, 0.12, 0.6)
	var move := Vector3.ZERO
	match state:
		State.CHASE:
			move = _chase(to_player, delta)
		State.WINDUP:
			sprite.frame = EnemyData.FRAME_CAST if (is_boss and _cast_mode != "" and sprite.hframes > 8) else EnemyData.FRAME_WINDUP
			if state_t >= float(d.windup):
				_strike()
				_set_state(State.STRIKE)
		State.STRIKE:
			if not (is_boss and _cast_mode != ""):
				sprite.frame = EnemyData.FRAME_STRIKE
			if state_t >= 0.35:
				_cast_mode = ""
				_set_state(State.CHASE)
		State.PAIN:
			sprite.frame = EnemyData.FRAME_PAIN
			if state_t >= 0.22:
				_set_state(State.CHASE)
		State.STUN:
			_stun_left -= delta
			if _stun_left <= 0.0:
				_frozen = false
				_set_state(State.CHASE)
	# physics
	velocity.x = move.x + _knock.x
	velocity.z = move.z + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	# tint: hurt flash / frozen
	if _frozen:
		sprite.modulate = Color(0.55, 0.85, 1.3)
	elif _flash_t > 0.0:
		sprite.modulate = Color(1.6, 0.55, 0.5)
	else:
		sprite.modulate = _base_tint


func _chase(to_player: Vector3, delta: float) -> Vector3:
	if not player.alive:
		_walk_anim(delta, 0.3)
		return Vector3.ZERO
	var ranged: bool = d.get("ranged", false)
	# attack decision
	if atk_cd <= 0.0 and los:
		if is_boss:
			_cast_cd -= delta
		if ranged and _dist <= float(d.range):
			_begin_attack()
			return Vector3.ZERO
		if not ranged and _dist <= float(d.range) + 0.3:
			_begin_attack()
			return Vector3.ZERO
		if is_boss and _cast_cd <= 0.0 and _dist < 30.0:
			var casts: Array = d.get("casts", ["summon", "volley"])
			_cast_mode = str(casts[randi() % casts.size()])
			_cast_cd = [7.0, 5.5, 4.0][phase - 1]
			_begin_attack()
			return Vector3.ZERO
	elif is_boss:
		_cast_cd -= delta
	var dir := Vector3.ZERO
	if los and _dist < 14.0:
		dir = to_player.normalized()
	else:
		dir = arena.flow_dir(global_position)
		if dir == Vector3.ZERO:
			dir = to_player.normalized()
	if ranged and los:
		var keep: float = d.get("keep_min", 6.0)
		if _dist < keep:
			dir = -to_player.normalized()
		elif _dist < float(d.range) * 0.7:
			dir = to_player.normalized().cross(Vector3.UP) * _strafe
	# separation from other enemies
	var sep := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var off: Vector3 = global_position - e.global_position
		off.y = 0
		var dd := off.length()
		var minsep: float = radius + float(e.radius) + 0.3
		if dd < minsep and dd > 0.001:
			sep += off / dd * (minsep - dd)
	dir = (dir + sep * 1.5).normalized() if (dir + sep).length() > 0.01 else Vector3.ZERO
	_walk_anim(delta, 1.0)
	var spd := speed * (0.4 if _frozen else 1.0)
	return dir * spd


func _walk_anim(delta: float, rate: float) -> void:
	_walk_t += delta * rate * (speed / 4.0)
	sprite.frame = EnemyData.FRAME_WALK_A if int(_walk_t * 3.0) % 2 == 0 else EnemyData.FRAME_WALK_B


func _begin_attack() -> void:
	_set_state(State.WINDUP)
	if is_boss and _cast_mode != "":
		Sfx.play_at(str(d.get("cast_sfx", "boss_cast")), global_position, 2.0)
	elif d.get("ranged", false) and type_id == "cultist":
		Sfx.play_at("cultist_cast", global_position, -2.0, 0.1, 0.4)


func _strike() -> void:
	atk_cd = float(d.atk_cd) * randf_range(0.85, 1.15) * _atk_mult
	var chest: Vector3 = player.global_position + Vector3(0, 1.1, 0)
	var origin := global_position + Vector3(0, float(d.body_h) * 0.75, 0)
	if is_boss and _cast_mode != "":
		_boss_cast(_cast_mode, origin, chest)
		return
	if d.get("ranged", false):
		var lead: Vector3 = player.velocity * (origin.distance_to(chest) / float(d.proj_speed)) * 0.5
		var dir := (chest + lead - origin).normalized()
		var kind := "enemy_arrow" if d.projectile == "arrow" else str(d.projectile)
		var p := Projectile.launch(get_parent(), kind, origin, dir * float(d.proj_speed), damage, false)
		p.owner_enemy = self
		if d.has("homing"):
			p.homing = float(d.homing)
			p.target = player
		Sfx.play_at(d.attack_sfx, origin, -2.0)
		return
	Sfx.play_at(d.attack_sfx, global_position, -2.0)
	if d.has("smash"):
		var center := global_position + (player.global_position - global_position).normalized() * float(d.range) * 0.6
		Fx.ring(get_parent(), center, float(d.smash), Color(0.8, 0.7, 0.55, 0.9), 0.35)
		Fx.spawn(get_parent(), "dust", center + Vector3(0, 0.4, 0), 2.2, 12.0)
		var pd: float = Vector2(player.global_position.x - center.x, player.global_position.z - center.z).length()
		if pd <= float(d.smash) and player.global_position.y < 1.2:
			player.take_damage(damage, global_position, "smash", self)
		if player.global_position.distance_to(global_position) < 12.0:
			player.shake = minf(player.shake + 0.6, 1.5)
		return
	if _dist <= float(d.range) + 0.6 and los:
		player.take_damage(damage, global_position, "melee", self)
		Sfx.play_at("hit_flesh", player.global_position, -4.0)
	elif type_id == "ghoul":
		Sfx.play_at("ghoul_attack", global_position, -4.0)


func hurt(amount: float, from_pos: Vector3, knockback: float = 2.0, _by: Node = null) -> void:
	if state == State.DEAD or state == State.SPAWN:
		return
	hp -= amount
	_flash_t = 0.12
	if not _alerted:
		_alerted = true
	var push := global_position - from_pos
	push.y = 0.0
	var kb_scale := 0.25 if is_boss else (0.45 if type_id == "brute" else 1.0)
	if push.length() > 0.01:
		_knock += push.normalized() * knockback * kb_scale
	var gib: String = d.gib
	Fx.spawn(get_parent(), gib, global_position + Vector3(0, float(d.body_h) * 0.6, 0), 0.9, 14.0, true)
	Sfx.play_at(d.hit, global_position, -5.0, 0.12, 0.05)
	if is_boss:
		var new_phase := 3 if hp_ratio() <= 0.3334 else (2 if hp_ratio() <= 0.6667 else 1)
		if hp > 0.0 and new_phase > phase:
			_enter_phase(new_phase)
		director.boss_hp_changed(self)
	if hp <= 0.0:
		_die()
		return
	if state != State.STUN and randf() < float(d.pain) * clampf(amount / (max_hp * 0.15), 0.3, 1.0):
		_set_state(State.PAIN)


func _enter_phase(p: int) -> void:
	## Boss shatters a phylactery: roars, repels the player, gets faster and angrier.
	phase = p
	speed *= 1.18
	_atk_mult *= 0.82
	_cast_cd = 1.2
	_stun_left = 1.3
	_frozen = false
	_set_state(State.STUN)
	sprite.frame = EnemyData.FRAME_CAST if sprite.hframes > 8 else EnemyData.FRAME_PAIN
	Sfx.play_at(str(d.alert), global_position, 6.0)
	Fx.ring(get_parent(), global_position, 7.0, Color(0.4, 1.0, 0.5, 1.0), 0.6)
	Fx.flash(get_parent(), global_position + Vector3(0, 2, 0), Color(0.35, 1.0, 0.45), 6.0, 16.0, 0.6)
	var d2: float = player.global_position.distance_to(global_position)
	if d2 < 7.0:
		player.take_damage(damage * 0.4, global_position, "smash", self)
	player.shake = 1.4
	director.boss_phase(self, p)


func stun(duration: float, frozen: bool = false) -> void:
	if state == State.DEAD or state == State.SPAWN:
		return
	if is_boss:
		if state == State.STUN:
			return
		duration *= 0.3
	_stun_left = maxf(_stun_left, duration)
	_frozen = frozen or _frozen
	_set_state(State.STUN)


func _die() -> void:
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	sprite.modulate = Color(1, 1, 1)
	_frozen = false
	Sfx.play_at(d.death, global_position, 0.0, 0.1, 0.05)
	var gib: String = d.gib
	for i in 3:
		Fx.spawn(get_parent(), gib, global_position + Vector3(randf_range(-0.3, 0.3), float(d.body_h) * randf_range(0.3, 0.8), randf_range(-0.3, 0.3)), 1.2, 12.0, true)
	# loot
	var g: Array = d.gold
	var total := randi_range(int(g[0]), int(g[1]))
	var coins := clampi(total / 3 + 1, 1, 6)
	for i in coins:
		Pickup.drop(get_parent(), "gold", global_position, maxi(total / coins, 1))
	if randf() < (0.1 if not is_boss else 1.0):
		Pickup.drop(get_parent(), "potion", global_position, 1)
	director.on_enemy_killed(self)


func _process_dead(delta: float) -> void:
	velocity.x = _knock.x
	velocity.z = _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 20.0 * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if state_t < 0.14:
		sprite.frame = EnemyData.FRAME_DIE_A
	elif state_t < 0.32:
		sprite.frame = EnemyData.FRAME_DIE_B
	else:
		# leave a corpse sprite behind and free the body
		var corpse := Sprites.make(sprite.texture, sprite.hframes, float(d.height), true, true)
		corpse.frame = EnemyData.FRAME_CORPSE
		var holder := Node3D.new()
		holder.add_child(corpse)
		director.add_corpse(holder, global_position)
		queue_free()


# ============================================================================== boss casts

func _boss_cast(mode: String, origin: Vector3, chest: Vector3) -> void:
	var proj: String = d.get("proj", "soul")
	var style: String = {"acid": "acid", "ember": "fire", "ice": "frost"}.get(proj, "fire")
	match mode:
		"summon":
			director.summon_minions(global_position, 2 + phase, d.get("summon", ["skeleton", "ghoul"]))
		"volley":
			var n := 3 + phase * 2
			for i in n:
				var dir := (chest - origin).normalized().rotated(Vector3.UP, lerpf(-0.45, 0.45, float(i) / float(n - 1)))
				var p := Projectile.launch(get_parent(), proj, origin, dir * 15.0, damage * 0.55, false)
				p.owner_enemy = self
				p.homing = 0.5
				p.target = player
			Sfx.play_at(str(d.get("volley_sfx", "shadow_bolt")), origin, 2.0)
		"rain", "meteor":
			# telegraphed strikes on and around the player
			var count := 3 + phase
			for i in count:
				var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-4.5, 4.5), 0, randf_range(-4.5, 4.5))
				var h: Node3D = Hazard.spawn(get_parent(), "strike", player.global_position + off, style, damage * 0.8, self)
				h.delay = 1.0 + i * 0.18
				h.radius = 2.3
			Sfx.play_at(str(d.get("cast_sfx", "boss_cast")), global_position, 2.0)
		"nova":
			var h: Node3D = Hazard.spawn(get_parent(), "nova", global_position, style, damage * 0.7, self)
			h.max_radius = 18.0
			h.speed = 11.0 + phase * 2.0
			Fx.flash(get_parent(), global_position + Vector3(0, 1.5, 0), Color(1.0, 0.5, 0.2), 5.0, 10.0, 0.4)
			Sfx.play_at("shockwave", global_position, 4.0)
			player.shake = maxf(player.shake, 0.8)
		"blink":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var dest: Vector3 = arena.random_floor_near(player.global_position, 4, rng)
			Fx.spawn(get_parent(), "portal", global_position + Vector3(0, 2.0, 0), 3.5, 12.0)
			global_position = dest
			Fx.spawn(get_parent(), "portal", global_position + Vector3(0, 2.0, 0), 3.5, 12.0)
			Sfx.play_at("blink", global_position, 2.0)
			_boss_cast("volley", global_position + Vector3(0, float(d.body_h) * 0.75, 0), chest)
		"frost_nova":
			Fx.ring(get_parent(), global_position, 9.0, Color(0.6, 0.9, 1.0, 1.0), 0.5)
			Fx.flash(get_parent(), global_position + Vector3(0, 1.5, 0), Color(0.5, 0.85, 1.0), 5.0, 12.0, 0.5)
			Sfx.play_at("frost_nova", global_position, 3.0)
			if Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < 9.0:
				player.take_damage(damage * 0.45, global_position, "ranged", self)
				player.apply_slow(3.0)
