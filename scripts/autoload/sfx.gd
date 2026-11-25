extends Node
## Sound effects, music and ambience beds. Sounds are looked up by name in assets/sfx/ and
## assets/music/ (<name>.ogg first, then <name>.wav). A missing sound falls back to an older
## one when FALLBACK names it, otherwise it is silently skipped.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const POOL := 20
const EXTS := [".ogg", ".wav"]
## Stand-ins used while a newer sound is missing.
const FALLBACK := {
	"meteor_impact": "fireball_explode",
	"acid_splash": "bolt_impact",
	"shockwave": "brute_smash",
	"ice_shatter": "frost_nova",
	"frost_cast": "cultist_cast",
	"rime_cast": "cultist_cast",
	"rot_roar": "brute_roar",
	"rot_death": "brute_death",
	"cinder_roar": "boss_roar",
	"cinder_death": "boss_death",
	"rime_death": "boss_death",
	"goblin_greet": "coin_pickup",
	"purchase": "coin_pickup",
	"weapon_upgrade": "boon_select",
	"torch_ignite": "fireball_cast",
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""
var _last_played := {}
## 3D sounds are parented here (the world SubViewport) when set.
var world_root: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "SFX"
	add_child(_amb)
	# safety net for the browser, whose sample player may ignore the loop flag:
	# a track that ends while it is still the current one starts again
	for p in [_music_a, _music_b]:
		p.finished.connect(_on_music_finished.bind(p))
	_amb.finished.connect(func():
		if _amb_name != "" and _amb.stream != null:
			_amb.play())


func stream_for(sound: String, dir: String = SFX_DIR) -> AudioStream:
	var key := dir + sound
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for ext in EXTS:
		var path: String = dir + sound + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s == null and FALLBACK.has(sound):
		s = stream_for(FALLBACK[sound], dir)
	_cache[key] = s
	return s


static func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)


func _throttled(sound: String, min_gap: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -10.0)) < min_gap:
		return true
	_last_played[sound] = now
	return false


func play(sound: String, volume_db: float = 0.0, pitch_var: float = 0.06, min_gap: float = 0.03) -> void:
	var s := stream_for(sound)
	if s == null or _throttled(sound, min_gap):
		return
	var p: AudioStreamPlayer = null
	for i in POOL:
		var c := _players[(_next + i) % POOL]
		if not c.playing:
			p = c
			break
	if p == null:
		p = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, pitch_var: float = 0.08, min_gap: float = 0.03) -> void:
	var s := stream_for(sound)
	if s == null or _throttled(sound + "@3d", min_gap):
		return
	var scene: Node = world_root if is_instance_valid(world_root) else get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 55.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func music(track: String, fade: float = 1.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	var s := stream_for(track, MUSIC_DIR)
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.stop)
	if s == null:
		return
	_set_loop(s)
	_music_a.stream = s
	_music_a.volume_db = -40.0
	_music_a.play()
	var tw2 := create_tween()
	tw2.tween_property(_music_a, "volume_db", 0.0, fade)


func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p == _music_a and _music_name != "" and p.stream != null:
		p.play()


func stop_music(fade: float = 1.0) -> void:
	_music_name = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, fade)
			tw.tween_callback(p.stop)


func ambience(track: String, fade: float = 2.0) -> void:
	## A quiet looping bed under the music (wind, drips, organ drone...). "" stops it.
	if track == _amb_name:
		return
	_amb_name = track
	var s: AudioStream = stream_for(track, MUSIC_DIR) if track != "" else null
	if s == null and not _amb.playing:
		return
	var tw := create_tween()
	if _amb.playing:
		tw.tween_property(_amb, "volume_db", -40.0, fade * 0.5)
		tw.tween_callback(_amb.stop)
	if s == null:
		return
	_set_loop(s)
	tw.tween_callback(func():
		_amb.stream = s
		_amb.volume_db = -40.0
		_amb.play())
	tw.tween_property(_amb, "volume_db", 0.0, fade)
