extends CharacterBody3D
## The ally of a duo vigil as seen from this machine: a billboard champion driven by the
## network. On the host it is also a target for the dead; any harm it takes is sent to the
## machine that owns it (that machine applies armour, boons and the hurt effects).

const Sprites := preload("res://scripts/util/sprites.gd")
const ClassData := preload("res://scripts/data/classes.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")

## Sheet frames (assets/sprites/players/<class>.png)
const F_IDLE := 0
const F_WALK_A := 1
const F_WALK_B := 2
const F_WINDUP := 3
const F_STRIKE := 4
const F_CAST := 5
const F_PAIN := 6
const F_DOWN := 7
const STATE_SIZE := 44

var peer_id := 0
var class_id := "warrior"
var display_name := "Ally"
var alive := true
var downed := false
var hp := 100.0
var max_hp := 100.0
var has_torch := false
var weapon_tier := 0
## Enemies poke these on their target; only the owner's own camera reacts.
var shake := 0.0
var sprite: Sprite3D
var _target := Vector3.ZERO
var _pose := 0
var _walk_t := 0.0
var _pain_t := 0.0
var _got_state := false
var _light: OmniLight3D
var _fallback := false


func setup(p_peer: int, p_class: String, p_name: String) -> void:
	peer_id = p_peer
	class_id = p_class if ClassData.CLASSES.has(p_class) else "warrior"
	display_name = p_name
	name = "Ally"
	add_to_group("allies")
	# its own layer: enemies bump into it, but no shot or hazard of this machine can hurt it
	collision_layer = 8
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	var path := "res://assets/sprites/players/%s.png" % class_id
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		# until the champion art lands: a cultist sheet tinted with the class colour
		tex = load("res://assets/sprites/enemies/cultist.png")
		_fallback = true
	sprite = Sprites.make(tex, 8, 1.95, true, true)
	sprite.position.y = 1.95 * 0.5
	if _fallback:
		sprite.modulate = {"warrior": Color(1.3, 0.8, 0.6), "mage": Color(0.6, 0.8, 1.4), "hunter": Color(0.7, 1.3, 0.6)}.get(class_id, Color(1, 1, 1))
	add_child(sprite)
	# a faint halo so the ally never melts into the horde at night
	var halo := OmniLight3D.new()
	halo.light_color = Color(0.75, 0.85, 1.0)
	halo.light_energy = 0.7
	halo.omni_range = 3.2
	halo.position = Vector3(0, 1.3, 0.6)
	add_child(halo)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.28)
	_light.light_energy = 1.4
	_light.omni_range = 7.0
	_light.position = Vector3(0.4, 1.5, 0)
	_light.visible = false
	add_child(_light)


func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


func flat_forward() -> Vector3:
	return Vector3(0, 0, -1)


# ======================================================================= harm (host side)

func take_damage(amount: float, from_pos: Vector3 = Vector3.INF, kind: String = "melee", source: Node = null) -> void:
	if not alive:
		return
	var src_id := int(source.net_id) if source != null and is_instance_valid(source) and "net_id" in source else 0
	Game.net.send_to(peer_id, "hit", [amount, from_pos, kind, src_id])
	_pain_t = 0.2


func apply_slow(duration: float) -> void:
	Game.net.send_to(peer_id, "slow", [duration])


# ======================================================================= network state

static func encode(p: Node) -> PackedByteArray:
	## The local champion's pose, sent 20 times a second to the ally.
	var b := PackedByteArray()
	b.resize(STATE_SIZE)
	var pos: Vector3 = p.global_position
	b.encode_float(0, pos.x)
	b.encode_float(4, pos.y)
	b.encode_float(8, pos.z)
	b.encode_float(12, p.yaw)
	b.encode_float(16, p.velocity.x)
	b.encode_float(20, p.velocity.y)
	b.encode_float(24, p.velocity.z)
	b.encode_float(28, p.hp)
	b.encode_float(32, p.max_hp)
	var flags := 0
	if p.alive:
		flags |= 1
	if p.downed:
		flags |= 2
	if p.has_torch:
		flags |= 4
	b.encode_u8(36, flags)
	b.encode_u8(37, p.kit.net_pose())
	b.encode_u8(38, p.weapon_tier)
	b.encode_u32(40, p.kills)
	return b


func apply_state(b: PackedByteArray) -> void:
	if b.size() < STATE_SIZE:
		return
	var pos := Vector3(b.decode_float(0), b.decode_float(4), b.decode_float(8))
	velocity = Vector3(b.decode_float(16), b.decode_float(20), b.decode_float(24))
	var new_hp := b.decode_float(28)
	if new_hp < hp - 0.5:
		_pain_t = 0.2
	hp = new_hp
	max_hp = maxf(b.decode_float(32), 1.0)
	var flags := b.decode_u8(36)
	alive = flags & 1 != 0
	downed = flags & 2 != 0
	has_torch = flags & 4 != 0
	_pose = b.decode_u8(37)
	weapon_tier = b.decode_u8(38)
	_target = pos
	if not _got_state or global_position.distance_to(pos) > 4.0:
		global_position = pos  # first sight, teleports and blinks: no sliding across the map
	_got_state = true


func _physics_process(delta: float) -> void:
	if not _got_state:
		return
	# smooth toward the last known pose, extrapolating a little with its velocity
	var aim := _target + Vector3(velocity.x, 0, velocity.z) * 0.05
	global_position = global_position.lerp(aim, clampf(delta * 14.0, 0.0, 1.0))
	_pain_t = maxf(_pain_t - delta, 0.0)
	_light.visible = has_torch and alive
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if downed or (not alive):
		sprite.frame = F_DOWN
	elif _pain_t > 0.0:
		sprite.frame = F_PAIN
	elif _pose == 1:
		sprite.frame = F_WINDUP
	elif _pose == 2:
		sprite.frame = F_STRIKE
	elif _pose == 3:
		sprite.frame = F_CAST
	elif hspeed > 1.0:
		_walk_t += delta * hspeed * 0.45
		sprite.frame = F_WALK_A if int(_walk_t * 2.0) % 2 == 0 else F_WALK_B
	else:
		sprite.frame = F_IDLE


# ======================================================================= what the ally does

func play_fx(kind: String, a: Vector3, b: Vector3, r: float) -> void:
	## Cosmetic echo of the ally's actions (the damage happened on their machine).
	var root := get_parent()
	match kind:
		"swing":
			Sfx.play_at("swing", global_position, -4.0, 0.12)
		"spin":
			Fx.ring(root, global_position, r, Color(1.0, 0.85, 0.7, 0.9), 0.3)
			Sfx.play_at("spin", global_position, -2.0)
		"charge":
			Sfx.play_at("charge", global_position, -2.0)
		"frost_nova":
			Fx.ring(root, global_position, r, Color(0.7, 0.95, 1.0, 1.0), 0.45)
			Fx.flash(root, global_position + Vector3(0, 1, 0), Color(0.5, 0.85, 1.0), 4.0, r + 2.0, 0.4)
			Sfx.play_at("frost_nova", global_position, -2.0)
		"blink":
			Fx.spawn(root, "portal", a + Vector3(0, 1.0, 0), 1.8, 18.0)
			Fx.spawn(root, "portal", b + Vector3(0, 1.0, 0), 1.8, 18.0)
			Sfx.play_at("blink", b, -2.0)
		"dash":
			Sfx.play_at("dash", global_position, -2.0)
		"cast":
			Sfx.play_at("fireball_cast", global_position, -4.0)
		"bow":
			Sfx.play_at("bow_shoot", global_position, -4.0, 0.1)
		"volley":
			Sfx.play_at("volley", global_position, -2.0)
		"potion":
			Sfx.play_at("potion_drink", global_position, -6.0)
		"torch":
			Sfx.play_at("torch_ignite", global_position, -4.0)


func spawn_shot(kind: String, origin: Vector3, vel: Vector3, splash: float) -> void:
	var p := Projectile.launch(get_parent(), kind, origin, vel, 0.0, true)
	p.cosmetic = true
	p.splash_radius = splash
