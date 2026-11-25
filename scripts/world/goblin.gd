extends Node3D
## Grizzle, the black-market goblin: appears at dawn in a puff of smoke, idles, greets
## the player when approached and vanishes when the night begins.

const Sprites := preload("res://scripts/util/sprites.gd")
const Fx := preload("res://scripts/combat/fx.gd")

const NAME := "Grizzle"

var sprite: Sprite3D
var _light: OmniLight3D
var _t := 0.0
var _greet_t := 0.0
var _greeted := false
var _leaving := false


func _ready() -> void:
	var path := "res://assets/sprites/npc/goblin.png"
	var tex: Texture2D
	var frames := 4
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		# placeholder until the goblin art lands: a hunched, green-tinted ghoul
		tex = load("res://assets/sprites/enemies/ghoul.png")
		frames = 8
	sprite = Sprites.make(tex, frames, 2.0, true, true)
	if frames == 8:
		sprite.modulate = Color(0.8, 1.15, 0.6)
	add_child(sprite)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.light_energy = 1.6
	_light.omni_range = 5.0
	_light.position = Vector3(0.4, 1.4, 0.3)
	add_child(_light)
	scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_puff()


func _puff() -> void:
	var parent := get_parent()
	for i in 4:
		Fx.spawn(parent, "dust", global_position + Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 1.6), randf_range(-0.6, 0.6)), 1.8, 10.0, true)
	Fx.flash(parent, global_position + Vector3(0, 1.2, 0), Color(1.0, 0.75, 0.4), 3.0, 6.0, 0.4)
	Sfx.play_at("blink", global_position, -2.0)


func near(player_pos: Vector3) -> bool:
	return Vector2(player_pos.x - global_position.x, player_pos.z - global_position.z).length() < 3.0


func greet() -> void:
	if _greeted:
		return
	_greeted = true
	_greet_t = 1.2
	Sfx.play_at("goblin_greet", global_position, 0.0, 0.04, 1.0)


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	_puff()
	Sfx.play_at("goblin_laugh", global_position, -2.0, 0.04, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_greet_t = maxf(_greet_t - delta, 0.0)
	if sprite.hframes >= 8:
		sprite.frame = int(_t * 2.5) % 2
	elif _greet_t > 0.0:
		sprite.frame = 2
	else:
		sprite.frame = 3 if fmod(_t, 6.0) > 5.0 else int(_t * 2.0) % 2
	_light.light_energy = 1.5 + sin(_t * 7.0) * 0.15 + sin(_t * 3.1) * 0.1
