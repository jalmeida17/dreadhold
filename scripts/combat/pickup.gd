extends Node3D
## Gold and potions dropped by enemies. Magnetised toward the player when close.

const Sprites := preload("res://scripts/util/sprites.gd")

var kind := "gold"
var amount := 1
var _sprite: Sprite3D
var _t := 0.0
var _vel := Vector3.ZERO
var _player: Node3D
var _life := 60.0


static func drop(parent: Node, p_kind: String, pos: Vector3, p_amount: int) -> void:
	var p: Node3D = load("res://scripts/combat/pickup.gd").new()
	p.kind = p_kind
	p.amount = p_amount
	parent.add_child(p)
	p.global_position = pos + Vector3(0, 0.6, 0)
	p._vel = Vector3(randf_range(-2.5, 2.5), randf_range(3.0, 5.0), randf_range(-2.5, 2.5))


func _ready() -> void:
	var path := "res://assets/sprites/pickups/gold.png"
	var h := 0.4
	if kind == "potion":
		path = "res://assets/sprites/pickups/potion_red.png"
		h = 0.5
	var tex: Texture2D = load(path)
	_sprite = Sprites.make(tex, 4 if kind == "gold" else 1, h, true, false)
	add_child(_sprite)
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	# simple ballistic hop, then rest on the floor
	if _vel != Vector3.ZERO:
		_vel.y -= 14.0 * delta
		global_position += _vel * delta
		if global_position.y <= 0.0:
			global_position.y = 0.0
			_vel = Vector3.ZERO
	if _sprite.hframes > 1:
		_sprite.frame = int(_t * 8.0) % _sprite.hframes
	_sprite.position.y = _sprite.pixel_size * _sprite.texture.get_height() * 0.5 + 0.08 + sin(_t * 3.0) * 0.06
	if _player == null or not is_instance_valid(_player) or not _player.alive:
		return
	var to: Vector3 = _player.global_position - global_position
	var d := to.length()
	if d < 4.0 and _t > 0.4:
		global_position += to.normalized() * minf(d, (4.5 - d) * 7.0 * delta + 3.0 * delta)
	if d < 0.9 and _t > 0.3:
		if _player.collect(kind, amount):
			queue_free()
