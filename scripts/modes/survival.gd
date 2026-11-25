extends Node
## Survival mode ("The Vigil"): endless nights of the dead.
## Night -> dawn (a black-market goblin sells abilities for the looted gold) -> next night.
## Every 5th night the champion is pulled into the Barrow Throne to face the Hollow King.

const WorldView := preload("res://scripts/world/world_view.gd")
const Arena := preload("res://scripts/world/arena.gd")
const Player := preload("res://scripts/player/player.gd")
const Enemy := preload("res://scripts/enemies/enemy.gd")
const EnemyData := preload("res://scripts/data/enemies.gd")
const Boons := preload("res://scripts/data/boons.gd")
const Goblin := preload("res://scripts/world/goblin.gd")
const BlackMarket := preload("res://scripts/ui/black_market.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const GameOver := preload("res://scripts/ui/game_over.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Maps := preload("res://scripts/data/maps.gd")

enum Phase { PREP, NIGHT, CLEARED, DAWN, TELEPORT, BOSS, OVER }

const MAX_CORPSES := 45

var world: SubViewport
var entities: Node3D
var arena: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var game_over: CanvasLayer

var phase := Phase.PREP
var phase_t := 0.0
var wave := 0
var queue: Array = []
var spawn_t := 0.0
var alive_count := 0
var wave_total := 0
var wave_killed := 0
var score := 0
var boss: Node = null
var corpses: Array = []
var goblin: Node3D = null
var market: CanvasLayer
## True while the mouse was captured last frame (browser pointer-lock watch).
var _had_capture := false
var rng := RandomNumberGenerator.new()
var stats := {
	"damage_dealt": 0.0, "damage_taken": 0.0, "potions_used": 0, "gold_earned": 0, "biggest_hit": 0.0,
	"bosses": 0, "kills_by_type": {}, "gold_spent": 0,
}
var _prep_len := 4.0
var boss_entry: Dictionary = {}
var _new_weapon := false
var _flow_t := 0.0


func _ready() -> void:
	rng.randomize()
	world = WorldView.create(self)
	Sfx.world_root = world
	_build_arena(Game.selected_map)
	player = Player.new()
	entities.add_child(player)
	player.setup(Game.selected_class, arena, self)
	_place_player()
	player.died.connect(_on_player_died)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, self)
	market = BlackMarket.new()
	add_child(market)
	market.setup(player, self)
	market.begin_night.connect(_on_begin_night)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	game_over = GameOver.new()
	add_child(game_over)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.music("music_battle")
	if Game.test.has("god"):
		player.invuln = 99999.0
	if Game.test.has("torch"):
		player.equip_torch()
	if Game.test.has("tier"):
		for i in int(Game.test["tier"]):
			player.upgrade_weapon()
	if Game.test.has("wave"):
		wave = int(Game.test["wave"]) - 1
	if Game.test.has("face"):
		var fc: PackedStringArray = str(Game.test["face"]).split(",")
		player.look_at_point(arena.cell_center(Vector2i(int(fc[0]), int(fc[1]))))
	if not Game.pending_save.is_empty():
		var data := Game.pending_save
		Game.pending_save = {}
		_restore(data)
		_begin_dawn(data)
		return
	if Game.test.has("dawn"):
		player.gold = int(Game.test.get("gold", "0"))
		_begin_dawn()
		if Game.test.has("shop"):
			market.open_shop.call_deferred()
		return
	_begin_prep(4.0)
	if Game.test.has("demo"):
		_prep_len = 999.0
		var fwd: Vector3 = player.flat_forward()
		var right := fwd.cross(Vector3.UP)
		var base: Vector3 = player.global_position
		for l in [["skeleton", 5.5, -1.6], ["ghoul", 6.5, 1.4], ["cultist", 10.0, -3.0], ["archer", 10.5, 2.8], ["brute", 13.0, 0.0]]:
			var e := spawn_enemy(l[0], base + fwd * float(l[1]) + right * float(l[2]))
			e.set_physics_process(Game.test.has("live"))
			e.state = 1
			e.sprite.position.y = float(e.d.height) * 0.5
		alive_count = 0


func _exit_tree() -> void:
	Sfx.world_root = null


func _build_arena(layout: String) -> void:
	if arena != null:
		arena.queue_free()
	if entities != null:
		for c in entities.get_children():
			if c != player:
				c.queue_free()
	else:
		entities = Node3D.new()
		entities.name = "Entities"
		world.add_child(entities)
	corpses.clear()
	goblin = null
	arena = Arena.new()
	arena.name = "Arena"
	world.add_child(arena)
	world.move_child(arena, 0)
	arena.build(layout)
	if player != null:
		player.arena = arena
	arena.update_flow(arena.player_spawn_cell)


func _place_player() -> void:
	player.velocity = Vector3.ZERO
	player.global_position = arena.player_spawn() + Vector3(0, 0.1, 0)
	player.look_at_point(arena.cell_center(arena.look_cell))
	player.pitch = 0.0


# ======================================================================= input

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		player.look(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and phase != Phase.OVER:
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and phase != Phase.OVER and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _watch_pointer_lock() -> void:
	## In a browser, Esc releases the pointer lock before the game ever sees the key:
	## pause instead of leaving the champion unable to look around.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _had_capture and not captured and OS.has_feature("web") and phase != Phase.OVER and not get_tree().paused:
		pause_menu.open()
	_had_capture = captured


# ======================================================================= main loop

func _process(delta: float) -> void:
	_watch_pointer_lock()
	phase_t += delta
	_flow_t -= delta
	if _flow_t <= 0.0 and player.alive and phase != Phase.TELEPORT:
		_flow_t = 0.2
		arena.update_flow(arena.world_to_cell(player.global_position))
	match phase:
		Phase.PREP:
			if phase_t >= _prep_len:
				_start_night()
		Phase.NIGHT, Phase.BOSS:
			_process_spawning(delta)
			if queue.is_empty() and alive_count <= 0 and phase_t > 1.0:
				_night_cleared()
		Phase.CLEARED:
			if phase_t >= 2.5:
				if arena.is_boss_arena():
					_return_to_keep()
				else:
					_begin_dawn()
		Phase.DAWN:
			_process_dawn()


func prep_left() -> float:
	return maxf(_prep_len - phase_t, 0.0) if phase == Phase.PREP else 0.0


func _begin_prep(duration: float) -> void:
	phase = Phase.PREP
	phase_t = 0.0
	_prep_len = duration
	var next := wave + 1
	if next % 5 == 0:
		var be := Maps.boss_for_night(next)
		hud.show_banner("NIGHT %s" % UiTheme.roman(next), "Something calls you to %s..." % str(be.arena_name).capitalize(), be.color)
	else:
		hud.show_banner("NIGHT %s" % UiTheme.roman(next), "Prepare yourself", UiTheme.GOLD)


# ======================================================================= nights

func _start_night() -> void:
	wave += 1
	wave_killed = 0
	phase_t = 0.0
	if wave % 5 == 0:
		_start_boss_night()
		return
	phase = Phase.NIGHT
	queue = _compose_wave(wave)
	wave_total = queue.size()
	spawn_t = 0.5
	Sfx.play("wave_start")
	Sfx.music("music_battle")
	hud.show_banner("NIGHT %s" % UiTheme.roman(wave), _wave_flavour(), Color(0.95, 0.35, 0.25))
	if Game.test.has("log"):
		print("[night] start %d with %d foes" % [wave, wave_total])


func _wave_flavour() -> String:
	var lines := ["The dead stir beyond the gates", "Bones rattle in the dark", "The graves split open", "A cold wind howls through the keep", "They hunger for the living", "The night grows darker"]
	return lines[(wave - 1) % lines.size()]


func _compose_wave(n: int) -> Array:
	var budget := 6 + n * 4
	var types := ["ghoul", "skeleton"]
	if n >= 2:
		types.append("archer")
	if n >= 3:
		types.append("cultist")
	if n >= 4:
		types.append("brute")
	var out: Array = []
	while budget > 0:
		var t: String = types[rng.randi_range(0, types.size() - 1)]
		if t == "brute" and rng.randf() < 0.55:
			t = "skeleton"
		var c: int = EnemyData.TYPES[t].cost
		if c > budget:
			t = "ghoul"
			c = 1
		out.append(t)
		budget -= c
	out.shuffle()
	return out


func _max_alive() -> int:
	return mini(8 + wave * 2, 30)


func _process_spawning(delta: float) -> void:
	if queue.is_empty():
		return
	spawn_t -= delta
	if spawn_t > 0.0 or alive_count >= _max_alive():
		return
	spawn_t = maxf(1.1 - wave * 0.05, 0.35) * rng.randf_range(0.7, 1.3)
	var t: String = queue.pop_front()
	var pts: Array = arena.spawn_points()
	pts.sort_custom(func(a, b): return a.distance_to(player.global_position) > b.distance_to(player.global_position))
	var p: Vector3 = pts[rng.randi_range(0, mini(2, pts.size() - 1))]
	spawn_enemy(t, p + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))


func spawn_enemy(type_id: String, pos: Vector3) -> Node:
	var e: CharacterBody3D = Enemy.new()
	entities.add_child(e)
	e.global_position = pos + Vector3(0, 0.05, 0)
	e.setup(type_id, arena, player, self, wave)
	alive_count += 1
	var big: bool = EnemyData.TYPES[type_id].get("boss", false)
	Fx.spawn(entities, "portal", pos + Vector3(0, 1.0, 0), 4.5 if big else 2.0, 6.0)
	Fx.flash(entities, pos + Vector3(0, 1.2, 0), Color(0.35, 1.0, 0.45), 2.5, 6.0, 0.8)
	Sfx.play_at("enemy_spawn", pos, -4.0, 0.1, 0.15)
	hud.ping(pos)
	return e


func summon_minions(center: Vector3, count: int, types: Array = ["skeleton", "ghoul"]) -> void:
	for i in count:
		var p: Vector3 = arena.random_floor_near(center, 3, rng)
		spawn_enemy(str(types[rng.randi_range(0, types.size() - 1)]), p)


func on_enemy_killed(e: Node) -> void:
	alive_count = maxi(alive_count - 1, 0)
	wave_killed += 1
	score += int(e.d.score) * (1 + wave / 5)
	var kbt: Dictionary = stats.kills_by_type
	kbt[e.type_id] = int(kbt.get(e.type_id, 0)) + 1
	player.on_kill(e)
	if e == boss:
		boss = null
		stats.bosses += 1
		hud.boss_defeated()
		hud.show_banner("%s FALLS" % str(e.d.name).to_upper(), "...but death is patient", e.d.get("color", UiTheme.GOLD))
		_new_weapon = player.upgrade_weapon()
		player.heal(player.max_hp)
		Sfx.music("music_battle")
		# his court crumbles with him
		for other in get_tree().get_nodes_in_group("enemies"):
			if other.is_alive():
				other.hurt(99999.0, other.global_position, 0.0, null)


func boss_hp_changed(_e: Node) -> void:
	pass


func boss_phase(_e: Node, p: int) -> void:
	hud.boss_phase(p)
	var nm := str(_e.d.name).to_upper()
	var lines := ["", "", "%s GROWS WRATHFUL" % nm, "%s UNLEASHES ITS FURY" % nm]
	hud.show_banner(lines[p], "A phylactery shatters!", _e.d.get("color", UiTheme.GOLD))


func add_corpse(holder: Node3D, pos: Vector3) -> void:
	arena.debris.add_child(holder)
	holder.global_position = Vector3(pos.x, 0.0, pos.z)
	corpses.append(holder)
	while corpses.size() > MAX_CORPSES:
		var old: Node = corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _night_cleared() -> void:
	phase = Phase.CLEARED
	phase_t = 0.0
	score += wave * 50
	Sfx.play("wave_clear")
	if not arena.is_boss_arena():
		hud.show_banner("DAWN BREAKS", "Night %s survived" % UiTheme.roman(wave), Color(1.0, 0.85, 0.45))
	if Game.test.has("log"):
		print("[night] cleared %d kills=%d hp=%d gold=%d t=%.1f" % [wave, player.kills, int(player.hp), player.gold, player.time_alive])


# ======================================================================= boss night

func _start_boss_night() -> void:
	phase = Phase.TELEPORT
	queue = []
	wave_total = 1
	Sfx.play("boss_warning")
	boss_entry = Maps.boss_for_night(wave)
	await hud.fade_to(boss_entry.color, 0.9)
	_build_arena(boss_entry.arena)
	_place_player()
	Sfx.music("music_boss")
	await get_tree().create_timer(0.25).timeout
	hud.fade_from(1.0)
	hud.show_banner(boss_entry.arena_name, boss_entry.arena_line, boss_entry.color)
	await get_tree().create_timer(2.2).timeout
	if phase == Phase.OVER:
		return
	phase = Phase.BOSS
	phase_t = 0.0
	boss = spawn_enemy(boss_entry.enemy, arena.boss_spawn())
	# later cycles bring the bosses back stronger
	var cycle := (wave / 5 - 1) / Maps.BOSSES.size()
	if cycle > 0:
		boss.max_hp *= 1.0 + 0.6 * cycle
		boss.hp = boss.max_hp
		boss.damage *= 1.0 + 0.3 * cycle
	hud.show_boss(boss)
	Sfx.play_at("boss_roar", arena.boss_spawn(), 6.0)
	hud.show_banner(str(boss.d.name).to_upper(), str(boss.d.title), boss.d.get("color", UiTheme.GOLD))


func _return_to_keep() -> void:
	phase = Phase.TELEPORT
	await hud.fade_to(Color(1.0, 0.9, 0.6), 0.8)
	_build_arena(Game.selected_map)
	_place_player()
	await get_tree().create_timer(0.2).timeout
	hud.fade_from(0.9)
	if _new_weapon:
		_new_weapon = false
		var w: Dictionary = player.weapon()
		hud.show_banner("NEW WEAPON: %s" % str(w.name).to_upper(), str(w.desc), UiTheme.GOLD)
		await get_tree().create_timer(3.4).timeout
	_begin_dawn()


# ======================================================================= dawn: the black market

func _begin_dawn(from_save: Dictionary = {}) -> void:
	phase = Phase.DAWN
	phase_t = 0.0
	if from_save.is_empty():
		var bounty := 25 + wave * 10
		player.gold += bounty
		stat_add("gold_earned", bounty)
		pickup_message("+%d gold  (dawn bounty)" % bounty)
		market.new_stock()
	else:
		var m: Dictionary = from_save.get("market", {})
		market.restore_stock(m.get("stock", []), int(m.get("restock_cost", 20)))
		pickup_message("Vigil resumed at the dawn of night %s" % UiTheme.roman(wave))
	goblin = Goblin.new()
	entities.add_child(goblin)
	goblin.global_position = arena.cell_center(arena.goblin_cell)
	hud.ping(goblin.global_position, Color(1.0, 0.8, 0.3))
	hud.show_banner("A BLACK MARKET GOBLIN APPEARS", "Talk to Grizzle with [%s] to spend your gold" % Game.key_label(KEY_F), Color(1.0, 0.85, 0.45))
	Sfx.play("boon_select")
	if from_save.is_empty():
		save_run()
		pickup_message("Vigil saved")


func goblin_near() -> bool:
	return goblin != null and is_instance_valid(goblin) and goblin.near(player.global_position)


func _process_dawn() -> void:
	var near := goblin_near()
	if near:
		goblin.greet()
	hud.show_prompt(("[%s]  Trade with Grizzle" % Game.key_label(KEY_F)) if near else "")
	if get_tree().paused or not player.alive:
		return
	if Game.test.has("bot") and phase_t > 1.5:
		market.bot_shop()
		return
	if near and Input.is_action_just_pressed("interact") and not market.is_open():
		market.open_shop()


func _on_begin_night() -> void:
	if goblin != null and is_instance_valid(goblin):
		goblin.leave()
	goblin = null
	hud.show_prompt("")
	if Game.test.has("log"):
		print("[market] owned: ", player.boons, " gold left ", player.gold)
	_begin_prep(6.0)


func can_shop() -> bool:
	return phase == Phase.DAWN


# ======================================================================= saving

func save_run() -> void:
	## Checkpoint of the run, taken at dawn (and after every purchase at the market).
	if phase != Phase.DAWN or not player.alive:
		return
	# automated test runs never touch the player's real save (unless asked with "save")
	if not Game.test.is_empty() and not Game.test.has("save"):
		return
	Game.write_save({
		"class": player.class_id,
		"map": Game.selected_map,
		"wave": wave,
		"score": score,
		"kills": player.kills,
		"time": player.time_alive,
		"stats": stats,
		"player": {
			"hp": player.hp,
			"gold": player.gold,
			"potions": player.potions,
			"boons": player.boons,
			"weapon_tier": player.weapon_tier,
			"torch": player.has_torch,
			"undying": player.undying,
		},
		"market": {"stock": market.stock, "restock_cost": market.restock_cost},
	})


func _restore(d: Dictionary) -> void:
	wave = int(d.get("wave", 0))
	score = int(d.get("score", 0))
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	var kbt: Dictionary = {}
	var saved_kbt: Dictionary = st.get("kills_by_type", {})
	for k in saved_kbt:
		kbt[k] = int(saved_kbt[k])
	stats["kills_by_type"] = kbt
	player.kills = int(d.get("kills", 0))
	player.time_alive = float(d.get("time", 0.0))
	var p: Dictionary = d.get("player", {})
	# rebuild the character by re-applying every upgrade, then restore the live values
	var boons: Dictionary = p.get("boons", {})
	for id in boons:
		if Boons.BOONS.has(id):
			for i in int(boons[id]):
				player.apply_boon(id)
	for i in int(p.get("weapon_tier", 0)):
		player.upgrade_weapon()
	if bool(p.get("torch", false)):
		player.equip_torch()
	player.hp = clampf(float(p.get("hp", player.max_hp)), 1.0, player.max_hp)
	player.gold = int(p.get("gold", 0))
	player.potions = clampi(int(p.get("potions", 1)), 0, player.max_potions)
	player.undying = int(p.get("undying", 0))
	player.power_flash = 0.0
	player.heal_flash = 0.0


# ======================================================================= stats & messages

func stat_add(key: String, v: float) -> void:
	stats[key] = float(stats.get(key, 0.0)) + v


func stat_max(key: String, v: float) -> void:
	stats[key] = maxf(float(stats.get(key, 0.0)), v)


func show_message(text: String, color: Color = Color(1, 1, 1)) -> void:
	hud.show_banner(text, "", color)


func pickup_message(text: String) -> void:
	hud.pickup(text)


# ======================================================================= game over

func _on_player_died() -> void:
	phase = Phase.OVER
	phase_t = 0.0
	Sfx.music("music_menu")
	Sfx.play("game_over")
	if Game.test.has("log"):
		print("[player] died at night %d kills=%d" % [wave, player.kills])
	# the vigil ends with the champion: no save survives death
	var best := false
	if Game.test.is_empty():
		Game.delete_save()
		best = Game.submit_record(Game.selected_class, wave, player.kills, score)
	var t := get_tree().create_timer(2.5, true)
	t.timeout.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.visible = false
		game_over.open(self, best))
