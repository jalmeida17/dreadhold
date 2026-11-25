extends Node
## Sound effects and music. Sounds are looked up by name in assets/sfx/<name>.wav;
## missing files are silently ignored so the game runs even without audio.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const POOL := 20

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
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


func stream_for(sound: String, dir: String = SFX_DIR) -> AudioStream:
	var key := dir + sound
	if _cache.has(key):
		return _cache[key]
	var path := dir + sound + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[key] = s
	return s


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
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_music_a.stream = s
	_music_a.volume_db = -40.0
	_music_a.play()
	var tw2 := create_tween()
	tw2.tween_property(_music_a, "volume_db", 0.0, fade)


func stop_music(fade: float = 1.0) -> void:
	_music_name = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, fade)
			tw.tween_callback(p.stop)
