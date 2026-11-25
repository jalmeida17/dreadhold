extends Node
## Survival mode ("The Vigil"): endless nights of the dead.
## Night -> dawn (a black-market goblin sells abilities for the looted gold) -> next night.
## Every 5th night the champions are pulled into a boss arena.
##
## Duo vigils (2 players, no save): the host's machine runs the vigil (waves, every enemy,
## bosses) and tells the ally's machine what happens through Game.net; each machine runs its
## own champion, its own loot and its own shopping. Enemy shots and hazards are replayed on
## both machines and only ever hurt the local champion, so dodging feels fair on both sides.

const WorldView := preload("res://scripts/world/world_view.gd")
const Arena := preload("res://scripts/world/arena.gd")
const Player := preload("res://scripts/player/player.gd")
const RemotePlayer := preload("res://scripts/player/remote_player.gd")
const Enemy := preload("res://scripts/enemies/enemy.gd")
const EnemyData := preload("res://scripts/data/enemies.gd")
const Boons := preload("res://scripts/data/boons.gd")
const Goblin := preload("res://scripts/world/goblin.gd")
const BlackMarket := preload("res://scripts/ui/black_market.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const GameOver := preload("res://scripts/ui/game_over.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const Hazard := preload("res://scripts/combat/hazard.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Maps := preload("res://scripts/data/maps.gd")
const Forge := preload("res://scripts/data/forge.gd")
const Bestiary := preload("res://scripts/data/bestiary.gd")
const ForgeChoice := preload("res://scripts/ui/forge_choice.gd")

enum Phase { PREP, NIGHT, CLEARED, DAWN, TELEPORT, BOSS, OVER }

const MAX_CORPSES := 45
const REVIVE_TIME := 3.0
const REVIVE_RANGE := 2.4
## Duo tuning: more foes, tougher bosses, a little less gold per coin (each champion loots).
const DUO_WAVE := 1.6
const DUO_ALIVE := 1.5
const DUO_HP := 1.15
const DUO_BOSS_HP := 1.7
const DUO_LOOT := 0.75

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
## Weapons offered by the last boss slain (chosen when back at the keep).
var _forge_offer: Array = []
var forge_ui: CanvasLayer
## The forged species that walk tonight (monster forge ids).
var night_species: Array = []
var _flow_t := 0.0

# ---- duo
var duo := false
## This machine runs the vigil (solo, or the duo host).
var host := true
var partner: CharacterBody3D = null
var partner_name := ""
var enemies_by_id := {}
var _next_id := 1
var _pose_t := 0.0
var _snap_t := 0.0
var _foes_left := 0
var _waiting_ally := false
var _ally_loaded := false
var _ready_me := false
var _ready_ally := false
var _revive_t := 0.0
var _being_revived := false
var _prompt_owner := ""


func _ready() -> void:
	rng.randomize()
	duo = Game.net.duo()
	host = not duo or Game.net.is_host()
	if not duo:
		Game.run_seed = int(Game.pending_save.get("seed", rng.randi())) if not Game.pending_save.is_empty() else rng.randi()
		Game.selected_map = Maps.resolve(Game.selected_map, rng.randi())
	world = WorldView.create(self)
	Sfx.world_root = world
	_build_arena(Game.selected_map)
	player = Player.new()
	entities.add_child(player)
	player.setup(Game.selected_class, arena, self)
	player.duo = duo
	player.died.connect(_on_player_died)
	player.downed_changed.connect(_on_downed_changed)
	if duo:
		_spawn_partner()
	_place_player()
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
	forge_ui = ForgeChoice.new()
	add_child(forge_ui)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.music(Maps.night_music(wave + 1))
	Sfx.ambience(Maps.ambience(Game.selected_map))
	if Game.test.has("god"):
		player.invuln = 99999.0
	if Game.test.has("torch"):
		player.equip_torch()
	if Game.test.has("tier"):
		for i in int(Game.test["tier"]):
			player.weapon_tier += 1
			player.equip_weapon(Forge.forge(player.class_id, player.weapon_tier, rng))
	if Game.test.has("forge"):
		# test hook: show the forge as after the given number of bosses
		var lv := int(Game.test["forge"])
		var offer := []
		for i in 3:
			offer.append(Forge.forge(player.class_id, lv, rng))
		forge_ui.open.call_deferred(offer, player.weapon(), "SPOILS OF THE BARROW THRONE", "Choose a weapon forged from the fallen  -  press 1, 2 or 3")
	if Game.test.has("enchant"):
		# test hook: force an enchantment (flame, frost, venom, storm, shadow, holy)
		var tw: Dictionary = player.weapon().duplicate(true)
		tw.enchant = str(Game.test["enchant"])
		tw.name = Forge.weapon_name(tw)
		player.equip_weapon(tw)
	if Game.test.has("wave") and host:
		wave = int(Game.test["wave"]) - 1
	if Game.test.has("face"):
		var fc: PackedStringArray = str(Game.test["face"]).split(",")
		player.look_at_point(arena.cell_center(Vector2i(int(fc[0]), int(fc[1]))))
	if duo:
		if Game.test.has("face_ally") and partner != null:
			# screenshots: the ally steps a few metres aside and both face each other
			if not host:
				player.global_position += (player.global_position - partner.global_position).normalized() * 4.5
			player.look_at_point(partner.global_position)
		_start_duo()
		return
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
		var lineup := [["skeleton", 5.5, -1.6], ["ghoul", 6.5, 1.4], ["cultist", 10.0, -3.0], ["archer", 10.5, 2.8], ["brute", 13.0, 0.0]]
		if Game.test.has("forged"):
			# test hook: a line-up of forged monsters instead of the classic ones
			lineup = []
			for k in 6:
				lineup.append([Bestiary.new_id(int(Game.test["forged"]), rng), 5.5 + (k % 3) * 2.5, -3.2 + k * 1.3])
		for l in lineup:
			var e := spawn_enemy(l[0], base + fwd * float(l[1]) + right * float(l[2]))
			e.set_physics_process(Game.test.has("live"))
			e.state = 1
			e.sprite.position.y = float(e.d.height) * 0.5
		alive_count = 0


func _exit_tree() -> void:
	Sfx.world_root = null
	Sfx.ambience("")
	if duo and Game.net.director == self:
		Game.net.director = null


func _build_arena(layout: String) -> void:
	if arena != null:
		arena.queue_free()
	if entities != null:
		for c in entities.get_children():
			if c != player and c != partner:
				c.queue_free()
	else:
		entities = Node3D.new()
		entities.name = "Entities"
		world.add_child(entities)
	corpses.clear()
	enemies_by_id.clear()
	goblin = null
	arena = Arena.new()
	arena.name = "Arena"
	world.add_child(arena)
	world.move_child(arena, 0)
	arena.build(layout)
	if player != null:
		player.arena = arena
	arena.update_flow(arena.player_spawn_cell)


func _spawn_spot(slot: int) -> Vector3:
	## Duo champions arrive side by side.
	var base: Vector3 = arena.player_spawn() + Vector3(0, 0.1, 0)
	if not duo or slot == 0:
		return base
	var look: Vector3 = arena.cell_center(arena.look_cell) - base
	look.y = 0.0
	var side := look.normalized().cross(Vector3.UP) if look.length() > 0.1 else Vector3.RIGHT
	return base + side * 1.6


func _my_slot() -> int:
	return 0 if host else 1


func _place_player() -> void:
	player.velocity = Vector3.ZERO
	player.global_position = _spawn_spot(_my_slot())
	player.look_at_point(arena.cell_center(arena.look_cell))
	player.pitch = 0.0
	if partner != null and is_instance_valid(partner):
		partner.global_position = _spawn_spot(1 - _my_slot())


# ======================================================================= input

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		player.look(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and phase != Phase.OVER:
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and phase != Phase.OVER and not get_tree().paused \
			and not pause_menu.is_open() and not market.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _watch_pointer_lock() -> void:
	## In a browser, Esc releases the pointer lock before the game ever sees the key:
	## pause instead of leaving the champion unable to look around.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _had_capture and not captured and OS.has_feature("web") and phase != Phase.OVER and not get_tree().paused \
			and not pause_menu.is_open() and not market.is_open():
		pause_menu.open()
	_had_capture = captured


# ======================================================================= main loop

func _process(delta: float) -> void:
	_watch_pointer_lock()
	phase_t += delta
	_flow_t -= delta
	if host and _flow_t <= 0.0 and phase != Phase.TELEPORT:
		_flow_t = 0.2
		_update_flow()
	if duo:
		_process_duo(delta)
	match phase:
		Phase.PREP:
			if host:
				if _waiting_ally:
					if _ally_loaded or phase_t > 15.0 or partner == null:
						_waiting_ally = false
						_begin_prep(4.0)
				elif phase_t >= _prep_len:
					_start_night()
		Phase.NIGHT, Phase.BOSS:
			if host:
				_process_spawning(delta)
				if queue.is_empty() and alive_count <= 0 and phase_t > 1.0:
					_night_cleared()
		Phase.CLEARED:
			if host and phase_t >= 2.5:
				if arena.is_boss_arena():
					_return_to_keep()
				else:
					_begin_dawn()
		Phase.DAWN:
			_process_dawn()


func _update_flow() -> void:
	var cells: Array[Vector2i] = []
	for t in targets():
		cells.append(arena.world_to_cell(t.global_position))
	if not cells.is_empty():
		arena.update_flow_multi(cells)


func prep_left() -> float:
	return maxf(_prep_len - phase_t, 0.0) if phase == Phase.PREP and not _waiting_ally else 0.0


func foes_left() -> int:
	return queue.size() + alive_count if host else _foes_left


func _begin_prep(duration: float) -> void:
	phase = Phase.PREP
	phase_t = 0.0
	_prep_len = duration
	if host and duo:
		Game.net.send("prep", [wave, duration])
	var next := wave + 1
	if next % 5 == 0:
		var be := Maps.boss_for_night(next, Game.run_seed)
		hud.show_banner("NIGHT %s" % UiTheme.roman(next), "Something calls you to %s..." % str(be.arena_name).capitalize(), be.color)
	else:
		hud.show_banner("NIGHT %s" % UiTheme.roman(next), "Prepare yourself" if not duo else "Prepare yourselves", UiTheme.GOLD)


# ======================================================================= targets (the host's enemies)

func targets() -> Array:
	## Champions the dead can hurt right now (the ally's puppet included, on the host).
	var out := []
	if player.alive:
		out.append(player)
	if partner != null and is_instance_valid(partner) and partner.alive:
		out.append(partner)
	return out


func pick_target(pos: Vector3, current: Variant) -> Node:
	var ts := targets()
	if ts.is_empty():
		return current if is_instance_valid(current) else player
	var best: Node = ts[0]
	var bd := INF
	for t in ts:
		var dd: float = pos.distance_to(t.global_position)
		if dd < bd:
			bd = dd
			best = t
	# a little loyalty: don't flip between two champions standing at similar distances
	if is_instance_valid(current) and current != best and current in ts:
		if pos.distance_to(current.global_position) < bd * 1.3:
			return current
	return best


func loot_scale() -> float:
	return DUO_LOOT if duo else 1.0


func _peer_of(t: Node) -> int:
	if t == player:
		return Game.net.my_id()
	if t != null and t == partner:
		return partner.peer_id
	return 0


func _node_of_peer(id: int) -> Node:
	if partner != null and is_instance_valid(partner) and id == partner.peer_id:
		return partner
	return player


# ======================================================================= nights

func _start_night() -> void:
	wave += 1
	if wave % 5 == 0:
		wave_killed = 0
		phase_t = 0.0
		_start_boss_night()
		return
	queue = _compose_wave(wave)
	wave_total = queue.size()
	spawn_t = 0.5
	if duo:
		Game.net.send("night", [wave, night_species])
	_night_view()
	if Game.test.has("log"):
		print("[night] start %d with %d foes" % [wave, wave_total])


func _night_view() -> void:
	phase = Phase.NIGHT
	phase_t = 0.0
	wave_killed = 0
	Sfx.play("wave_start")
	Sfx.music(Maps.night_music(wave))
	var sub := _wave_flavour()
	if not night_species.is_empty():
		sub = "Tonight: " + Bestiary.describe_night(night_species)
	hud.show_banner("NIGHT %s" % UiTheme.roman(wave), sub, Color(0.95, 0.35, 0.25))
	if Game.test.has("log") and not night_species.is_empty():
		print("[bestiary] night %d: %s" % [wave, Bestiary.describe_night(night_species)])
	if Game.test.has("log") and not host:
		print("[ally] night %d begins" % wave)


func _wave_flavour() -> String:
	var lines := ["The dead stir beyond the gates", "Bones rattle in the dark", "The graves split open", "A cold wind howls through the keep", "They hunger for the living", "The night grows darker"]
	return lines[(wave - 1) % lines.size()]


func _compose_wave(n: int) -> Array:
	var budget := 6 + n * 4 + int(0.15 * n * n)
	if _duo_live():
		budget = int(budget * DUO_WAVE)
	# from night 3, forged species join the horde and soon make most of it
	night_species = []
	if n >= 3:
		for i in mini(1 + n / 5, 4):
			night_species.append(Bestiary.new_id(n, rng))
	var forged_share := clampf(0.2 + 0.06 * float(n - 3), 0.0, 0.75)
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
		if t == "brute" and rng.randf() < maxf(0.55 - 0.03 * (n - 4), 0.1):
			t = "skeleton"
		if not night_species.is_empty() and rng.randf() < forged_share:
			t = night_species[rng.randi_range(0, night_species.size() - 1)]
		var c: int = EnemyData.get_type(t).cost
		if c > budget:
			t = "ghoul"
			c = 1
		out.append(t)
		budget -= c
	out.shuffle()
	return out


func _duo_live() -> bool:
	return duo and partner != null and is_instance_valid(partner)


func _max_alive() -> int:
	var n := mini(10 + wave * 2, 36)
	return mini(int(n * DUO_ALIVE), 48) if _duo_live() else n


func _elite_chance() -> float:
	## Elites appear from night 6 and grow common (up to 35% of a wave).
	return clampf(0.04 * float(wave - 5), 0.0, 0.35)


func _process_spawning(delta: float) -> void:
	if queue.is_empty():
		return
	spawn_t -= delta
	if spawn_t > 0.0 or alive_count >= _max_alive():
		return
	spawn_t = maxf(1.1 - wave * 0.05, 0.3) * rng.randf_range(0.7, 1.3)
	var t: String = queue.pop_front()
	var pts: Array = arena.spawn_points()
	var ts := targets()
	if ts.is_empty():
		ts = [player]
	# spawn far from every champion
	var away := func(p: Vector3) -> float:
		var m := INF
		for c in ts:
			m = minf(m, p.distance_to(c.global_position))
		return m
	pts.sort_custom(func(a, b): return away.call(a) > away.call(b))
	var p: Vector3 = pts[rng.randi_range(0, mini(2, pts.size() - 1))]
	spawn_enemy(t, p + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), 1.0, 1.0, rng.randf() < _elite_chance())


func spawn_enemy(type_id: String, pos: Vector3, hp_mult: float = 1.0, dmg_mult: float = 1.0, elite: bool = false) -> Node:
	## Host (or solo) only: a new foe. In duo the ally's machine gets a puppet of it.
	var e: CharacterBody3D = Enemy.new()
	entities.add_child(e)
	e.global_position = pos + Vector3(0, 0.05, 0)
	e.setup(type_id, arena, pick_target(pos, null), self, wave)
	e.net_id = _next_id
	_next_id += 1
	enemies_by_id[e.net_id] = e
	var mult := hp_mult
	if _duo_live():
		mult *= DUO_BOSS_HP if e.is_boss else DUO_HP
	if mult != 1.0:
		e.max_hp *= mult
		e.hp = e.max_hp
	e.damage *= dmg_mult
	if elite and not e.is_boss:
		e.make_elite()
	alive_count += 1
	_spawn_fx(type_id, pos, e.elite)
	if duo:
		Game.net.send("e_spawn", [e.net_id, type_id, pos, e.max_hp, e.elite])
	return e


func _spawn_fx(type_id: String, pos: Vector3, elite: bool = false) -> void:
	var big: bool = EnemyData.get_type(type_id).get("boss", false)
	Fx.spawn(entities, "portal", pos + Vector3(0, 1.0, 0), 4.5 if big else (2.6 if elite else 2.0), 6.0)
	Fx.flash(entities, pos + Vector3(0, 1.2, 0), Color(1.0, 0.7, 0.25) if elite else Color(0.35, 1.0, 0.45), 2.5, 6.0, 0.8)
	Sfx.play_at("enemy_spawn", pos, -4.0, 0.1, 0.15)
	hud.ping(pos, Color(1.0, 0.75, 0.2) if elite else Color(1.0, 0.25, 0.2))


func summon_minions(center: Vector3, count: int, types: Array = ["skeleton", "ghoul"]) -> void:
	for i in count:
		var p: Vector3 = arena.random_floor_near(center, 3, rng)
		spawn_enemy(str(types[rng.randi_range(0, types.size() - 1)]), p)


func enemy_shot(e: Node, kind: String, origin: Vector3, vel: Vector3, dmg: float, homing: float, target: Node) -> void:
	## Host: an enemy fires. The ally's machine fires the same shot (it only hurts its own champion).
	var p := Projectile.launch(e.get_parent(), kind, origin, vel, dmg, false)
	p.owner_enemy = e
	if homing > 0.0:
		p.homing = homing
		p.target = target
	if duo:
		Game.net.send("e_shot", [e.net_id, kind, origin, vel, dmg, homing, _peer_of(target)])


func enemy_hazard(e: Node, mode: String, pos: Vector3, style: String, dmg: float, params: Dictionary) -> void:
	Hazard.spawn(e.get_parent(), mode, pos, style, dmg, e, params)
	if duo:
		Game.net.send("hazard", [e.net_id, mode, pos, style, dmg, params])


func on_enemy_killed(e: Node) -> void:
	## Host (or solo): a foe died.
	enemies_by_id.erase(e.net_id)
	alive_count = maxi(alive_count - 1, 0)
	wave_killed += 1
	score += int(e.d.score) * (1 + wave / 5) * (2 if e.elite else 1)
	var kbt: Dictionary = stats.kills_by_type
	kbt[e.type_id] = int(kbt.get(e.type_id, 0)) + 1
	var killer: int = Game.net.my_id()
	if partner != null and e.last_hitter == partner:
		killer = partner.peer_id
	else:
		player.on_kill(e)
	if duo:
		Game.net.send("e_die", [e.net_id, killer])
	if e == boss:
		if duo:
			Game.net.send("boss_fall", [])
		_boss_fall_view(e)
		# his court crumbles with him (minions still rising from the ground included)
		for other in get_tree().get_nodes_in_group("enemies"):
			other.banish()


func _boss_fall_view(e: Node) -> void:
	boss = null
	if Game.test.has("log"):
		print("[boss] falls at night %d" % wave)
	stats.bosses += 1
	hud.boss_defeated()
	var nm := str(e.d.name).to_upper() if e != null and is_instance_valid(e) else "THE TYRANT"
	var col: Color = e.d.get("color", UiTheme.GOLD) if e != null and is_instance_valid(e) else UiTheme.GOLD
	hud.show_banner("%s FALLS" % nm, "...but death is patient", col)
	# the spoils: three forged weapons, chosen back at the keep
	player.weapon_tier += 1
	_forge_offer = []
	for i in 3:
		_forge_offer.append(Forge.forge(player.class_id, player.weapon_tier, rng))
	player.heal(player.max_hp)
	# a breath of silence after the kill; dawn brings its own tune
	Sfx.stop_music(2.5)


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
	# the dawn burns whatever is still standing (nothing should be, but never leave a straggler)
	for c in get_tree().get_nodes_in_group("enemies"):
		if Game.test.has("log"):
			print("[night] %s still standing at dawn, burned" % c.type_id)
		c.banish()
	alive_count = 0
	score += wave * 50
	if duo:
		Game.net.send("cleared", [wave, score])
	_cleared_view()
	if Game.test.has("log"):
		print("[night] cleared %d kills=%d hp=%d gold=%d t=%.1f" % [wave, player.kills, int(player.hp), player.gold, player.time_alive])


func _cleared_view() -> void:
	phase = Phase.CLEARED
	phase_t = 0.0
	Sfx.play("wave_clear")
	if Game.test.has("log") and not host:
		print("[ally] cleared %d kills=%d hp=%d gold=%d score=%d" % [wave, player.kills, int(player.hp), player.gold, score])
	if not arena.is_boss_arena():
		hud.show_banner("DAWN BREAKS", "Night %s survived" % UiTheme.roman(wave), Color(1.0, 0.85, 0.45))


# ======================================================================= boss night

func _start_boss_night() -> void:
	## Both machines play the teleport; only the host summons the boss.
	phase = Phase.TELEPORT
	phase_t = 0.0
	queue = []
	wave_total = 1
	if host and duo:
		Game.net.send("boss_tp", [wave])
	Sfx.play("boss_warning")
	boss_entry = Maps.boss_for_night(wave, Game.run_seed)
	await hud.fade_to(boss_entry.color, 0.9)
	_build_arena(boss_entry.arena)
	_place_player()
	Sfx.music(str(boss_entry.get("music", "music_boss_hollow")), 0.8)
	Sfx.ambience("amb_boss")
	await get_tree().create_timer(0.25).timeout
	hud.fade_from(1.0)
	hud.show_banner(boss_entry.arena_name, boss_entry.arena_line, boss_entry.color)
	await get_tree().create_timer(2.2).timeout
	if phase == Phase.OVER:
		return
	phase = Phase.BOSS
	phase_t = 0.0
	if not host:
		return
	# later cycles bring the bosses back stronger
	var cycle := (wave / 5 - 1) / Maps.BOSSES.size()
	boss = spawn_enemy(boss_entry.enemy, arena.boss_spawn(), 1.0 + 0.6 * cycle, 1.0 + 0.3 * cycle)
	_present_boss(boss)


func _present_boss(e: Node) -> void:
	boss = e
	if Game.test.has("log"):
		print("[boss] %s appears (hp %d)" % [e.d.name, int(e.max_hp)])
	hud.show_boss(e)
	Sfx.play_at(str(e.d.alert), e.global_position, 6.0)
	hud.show_banner(str(e.d.name).to_upper(), str(e.d.title), e.d.get("color", UiTheme.GOLD))


func _return_to_keep() -> void:
	phase = Phase.TELEPORT
	if host and duo:
		Game.net.send("keep", [])
	await hud.fade_to(Color(1.0, 0.9, 0.6), 0.8)
	_build_arena(Game.selected_map)
	_place_player()
	Sfx.ambience(Maps.ambience(Game.selected_map))
	await get_tree().create_timer(0.2).timeout
	hud.fade_from(0.9)
	if not _forge_offer.is_empty():
		var offer := _forge_offer
		_forge_offer = []
		Sfx.play("weapon_upgrade")
		forge_ui.open(offer, player.weapon(), "SPOILS OF %s" % str(boss_entry.get("arena_name", "THE ARENA")), "Choose a weapon forged from the fallen  -  press 1, 2 or 3")
		var picked: Dictionary = await forge_ui.chosen
		if picked != player.weapon():
			player.equip_weapon(picked)
			hud.show_banner(str(picked.name).to_upper(), "is now in your hand", Boons.RARITY_COLOR.get(str(picked.rarity), UiTheme.GOLD))
			if Game.test.has("log"):
				print("[forge] took %s (%s)" % [picked.name, picked.rarity])
	if host and phase == Phase.TELEPORT:
		_begin_dawn()


# ======================================================================= dawn: the black market

func _begin_dawn(from_save: Dictionary = {}) -> void:
	phase = Phase.DAWN
	phase_t = 0.0
	_ready_me = false
	_ready_ally = false
	if host and duo:
		Game.net.send("dawn", [wave])
	if player.downed:
		player.revive(0.5)
	Sfx.music("music_dawn", 2.0)
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
	if from_save.is_empty() and not duo:
		save_run()
		pickup_message("Vigil saved")


func goblin_near() -> bool:
	return goblin != null and is_instance_valid(goblin) and goblin.near(player.global_position)


func _process_dawn() -> void:
	var near := goblin_near()
	if near:
		goblin.greet()
	if _ready_me and duo and not market.is_open():
		_prompt("dawn", "Waiting for %s to face the night...  ([%s] to trade again)" % [partner_name, Game.key_label(KEY_F)] if near else "Waiting for %s to face the night..." % partner_name)
	else:
		_prompt("dawn", ("[%s]  Trade with Grizzle" % Game.key_label(KEY_F)) if near else "")
	if get_tree().paused or not player.alive:
		return
	if Game.test.has("bot") and phase_t > 1.5 and not _ready_me:
		market.bot_shop()
		return
	if near and Input.is_action_just_pressed("interact") and not market.is_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		market.open_shop()


func _on_begin_night() -> void:
	if Game.test.has("log"):
		print("[market] owned: ", player.boons, " gold left ", player.gold)
	if duo:
		if _ready_me:
			return
		_ready_me = true
		Game.net.send("ready", [])
		if host:
			_check_ready()
		return
	_dawn_ends()
	_begin_prep(6.0)


func _check_ready() -> void:
	## Host: the night falls once both champions are ready (or the ally is gone).
	if phase == Phase.DAWN and _ready_me and (_ready_ally or not _duo_live()):
		_dawn_ends()
		_begin_prep(6.0)


func _dawn_ends() -> void:
	if goblin != null and is_instance_valid(goblin):
		goblin.leave()
	goblin = null
	if market.is_open():
		market.close_shop()
	_prompt("dawn", "")


func can_shop() -> bool:
	return phase == Phase.DAWN


# ======================================================================= duo: messages

func _start_duo() -> void:
	Game.net.attach(self)
	phase = Phase.PREP
	phase_t = 0.0
	_prep_len = 999.0
	if host:
		_waiting_ally = true
		hud.show_banner("DUO VIGIL", "Waiting for %s..." % partner_name, UiTheme.GOLD)
	else:
		Game.net.send("loaded", [])
		hud.show_banner("DUO VIGIL", "Waiting for the host...", UiTheme.GOLD)


func _spawn_partner() -> void:
	var info: Dictionary = Game.net.partner()
	if info.is_empty():
		return
	partner = RemotePlayer.new()
	entities.add_child(partner)
	partner.setup(Game.net.partner_id(), str(info.get("class", "warrior")), str(info.get("name", "Ally")))
	partner_name = partner.display_name


func _process_duo(delta: float) -> void:
	_pose_t -= delta
	if _pose_t <= 0.0:
		_pose_t = 0.05
		Game.net.stream("p", RemotePlayer.encode(player))
	if host:
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = 1.0 / 15.0
			_send_snapshot()
	_process_revive(delta)


func _send_snapshot() -> void:
	var list: Array = []
	for id in enemies_by_id:
		var e: Node = enemies_by_id[id]
		if is_instance_valid(e) and e.state != Enemy.State.DEAD:
			list.append(e)
	var b := PackedByteArray()
	b.resize(8 + list.size() * 20)
	b.encode_u16(0, list.size())
	b.encode_u16(2, clampi(foes_left(), 0, 65535))
	b.encode_s32(4, score)
	var o := 8
	for e in list:
		var pos: Vector3 = e.global_position
		b.encode_u32(o, e.net_id)
		b.encode_float(o + 4, pos.x)
		b.encode_float(o + 8, pos.y)
		b.encode_float(o + 12, pos.z)
		b.encode_u8(o + 16, e.sprite.frame)
		b.encode_u8(o + 17, e.net_state_flags())
		b.encode_u16(o + 18, int(clampf(e.hp_ratio(), 0.0, 1.0) * 65535.0))
		o += 20
	Game.net.stream("e", b)


func net_stream(_from: int, kind: String, b: PackedByteArray) -> void:
	match kind:
		"p":
			if partner != null and is_instance_valid(partner):
				partner.apply_state(b)
				if host:
					_check_all_fallen()
		"e":
			if host or b.size() < 8:
				return
			var n := b.decode_u16(0)
			_foes_left = b.decode_u16(2)
			score = b.decode_s32(4)
			var o := 8
			for i in n:
				if o + 20 > b.size():
					break
				var e: Node = enemies_by_id.get(int(b.decode_u32(o)))
				if e != null and is_instance_valid(e):
					e.net_apply(Vector3(b.decode_float(o + 4), b.decode_float(o + 8), b.decode_float(o + 12)), b.decode_u8(o + 16), b.decode_u8(o + 17), b.decode_u16(o + 18) / 65535.0)
				o += 20


func net_event(_from: int, kind: String, a: Array) -> void:
	match kind:
		# ---- both ways
		"p_fx":
			if partner != null and is_instance_valid(partner):
				partner.play_fx(str(a[0]), a[1], a[2], float(a[3]))
		"p_shot":
			if partner != null and is_instance_valid(partner):
				partner.spawn_shot(str(a[0]), a[1], a[2], float(a[3]))
		"ready":
			_ready_ally = true
			pickup_message("%s is ready for the night" % partner_name)
			if host:
				_check_ready()
		"revive":
			if player.downed:
				player.revive(0.5)
				pickup_message("%s raised you!" % partner_name)
		"reviving":
			_being_revived = bool(a[0])
		# ---- ally -> host
		"loaded":
			_ally_loaded = true
		"e_hurt":
			var e: Node = enemies_by_id.get(int(a[0]))
			if e != null and is_instance_valid(e):
				e.hurt(float(a[1]), a[2], float(a[3]), partner)
				if a.size() > 5 and str(a[4]) != "" and is_instance_valid(e):
					e.apply_element(str(a[4]), float(a[5]), partner)
		"e_stun":
			var e2: Node = enemies_by_id.get(int(a[0]))
			if e2 != null and is_instance_valid(e2):
				e2.stun(float(a[1]), bool(a[2]))
		# ---- host -> ally
		"prep":
			wave = int(a[0])
			if phase == Phase.DAWN:
				_dawn_ends()
			_begin_prep(float(a[1]))
		"night":
			wave = int(a[0])
			night_species = a[1] if a.size() > 1 else []
			_night_view()
		"cleared":
			wave = int(a[0])
			score = int(a[1])
			_cleared_view()
		"boss_tp":
			wave = int(a[0])
			_start_boss_night()
		"boss_fall":
			_boss_fall_view(boss)
		"keep":
			_return_to_keep()
		"dawn":
			wave = int(a[0])
			_begin_dawn()
		"over":
			wave = int(a[0])
			score = int(a[1])
			_game_over_view()
		"e_spawn":
			_spawn_puppet(int(a[0]), str(a[1]), a[2], float(a[3]), a.size() > 4 and bool(a[4]))
		"e_die":
			var dead: Node = enemies_by_id.get(int(a[0]))
			if dead != null and is_instance_valid(dead):
				enemies_by_id.erase(int(a[0]))
				alive_count = maxi(alive_count - 1, 0)
				var kbt: Dictionary = stats.kills_by_type
				kbt[dead.type_id] = int(kbt.get(dead.type_id, 0)) + 1
				if int(a[1]) == Game.net.my_id():
					player.on_kill(dead)
				dead.net_die()
		"e_fx":
			var fe: Node = enemies_by_id.get(int(a[0]))
			if fe != null and is_instance_valid(fe):
				fe.net_fx(str(a[1]), a[2], int(a[3]))
		"e_shot":
			var src: Node = enemies_by_id.get(int(a[0]))
			var p := Projectile.launch(entities, str(a[1]), a[2], a[3], float(a[4]), false)
			p.owner_enemy = src if src != null and is_instance_valid(src) else null
			if float(a[5]) > 0.0:
				p.homing = float(a[5])
				p.target = _node_of_peer(int(a[6]))
		"hazard":
			var hs: Node = enemies_by_id.get(int(a[0]))
			Hazard.spawn(entities, str(a[1]), a[2], str(a[3]), float(a[4]), hs if hs != null and is_instance_valid(hs) else null, a[5])
		"hit":
			var by: Node = enemies_by_id.get(int(a[3]))
			player.take_damage(float(a[0]), a[1], str(a[2]), by if by != null and is_instance_valid(by) else null)
		"slow":
			player.apply_slow(float(a[0]))


func _spawn_puppet(id: int, type_id: String, pos: Vector3, max_hp: float, elite: bool = false) -> void:
	var e: CharacterBody3D = Enemy.new()
	e.puppet = true
	entities.add_child(e)
	e.global_position = pos + Vector3(0, 0.05, 0)
	e.setup(type_id, arena, player, self, wave)
	e.net_id = id
	e.max_hp = max_hp
	e.hp = max_hp
	e._net_pos = e.global_position
	if elite:
		e.elite_look()
	enemies_by_id[id] = e
	alive_count += 1
	_spawn_fx(type_id, pos, elite)
	if e.is_boss:
		_present_boss(e)


func net_partner_left(who: String) -> void:
	if partner != null and is_instance_valid(partner):
		partner.queue_free()
	partner = null
	hud.show_banner("%s HAS LEFT THE VIGIL" % who.to_upper(), "You stand alone now", UiTheme.RED)
	_prompt("revive", "")
	if host:
		_ally_loaded = true
		_check_ready()
		_check_all_fallen()


func net_lost(reason: String) -> void:
	## The relay connection is gone. The host keeps fighting alone; the ally cannot.
	if host:
		net_partner_left(partner_name if partner_name != "" else "Your ally")
		return
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	hud.show_banner("THE VIGIL IS BROKEN", reason, UiTheme.RED)
	if Game.test.has("log"):
		print("[duo] connection lost: %s" % reason)
	Sfx.stop_music(1.5)
	var t := get_tree().create_timer(3.5, true)
	t.timeout.connect(func():
		Game.net.leave()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Game.goto(Game.SCENE_MENU))


# ======================================================================= duo: down & revive

func _on_downed_changed(is_down: bool) -> void:
	if Game.test.has("log"):
		print("[duo] %s %s at night %d" % ["host" if host else "ally", "is DOWN" if is_down else "is back up", wave])
	if is_down:
		hud.show_banner("YOU HAVE FALLEN", "%s can raise you - or hold on until dawn" % partner_name if _duo_live() else "No one is left to raise you", UiTheme.RED)
		if host:
			_check_all_fallen()
	else:
		_being_revived = false
		hud.show_banner("BACK ON YOUR FEET", "", UiTheme.GOLD)


func _check_all_fallen() -> void:
	## Host: the vigil ends when no champion is left standing.
	if not duo or phase == Phase.OVER or player.alive:
		return
	if partner != null and is_instance_valid(partner) and partner.alive:
		return
	Game.net.send("over", [wave, score])
	_game_over_view()


func _process_revive(delta: float) -> void:
	if player.downed:
		if _being_revived:
			_prompt("revive", "%s is raising you..." % partner_name)
		elif _duo_live():
			_prompt("revive", "Waiting for %s - or for the dawn" % partner_name)
		else:
			_prompt("revive", "")
		return
	var ok: bool = _duo_live() and player.alive and partner.downed and phase != Phase.OVER \
		and player.global_position.distance_to(partner.global_position) < REVIVE_RANGE
	if not ok:
		if _revive_t > 0.0:
			_revive_t = 0.0
			Game.net.send("reviving", [false])
		_prompt("revive", "")
		return
	var holding := (Input.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) or Game.test.has("bot")
	if not holding:
		if _revive_t > 0.0:
			_revive_t = 0.0
			Game.net.send("reviving", [false])
		_prompt("revive", "Hold [%s] to raise %s" % [Game.key_label(KEY_F), partner_name])
		return
	if _revive_t == 0.0:
		Game.net.send("reviving", [true])
	_revive_t += delta
	_prompt("revive", "Raising %s...  %d%%" % [partner_name, int(_revive_t / REVIVE_TIME * 100.0)])
	if _revive_t >= REVIVE_TIME:
		_revive_t = 0.0
		Game.net.send("revive", [])
		Sfx.play("boon_select", -4.0)
		if Game.test.has("log"):
			print("[duo] raised the ally")
		pickup_message("You raised %s" % partner_name)
		_prompt("revive", "")


func _prompt(owner_key: String, text: String) -> void:
	## Two systems share the prompt line (dawn trading, reviving): the last one speaking owns it.
	if text != "":
		_prompt_owner = owner_key
		hud.show_prompt(text)
	elif _prompt_owner == owner_key:
		_prompt_owner = ""
		hud.show_prompt("")


# ======================================================================= saving

func save_run() -> void:
	## Checkpoint of the run, taken at dawn (and after every purchase at the market).
	if duo or phase != Phase.DAWN or not player.alive:
		return
	# automated test runs never touch the player's real save (unless asked with "save")
	if not Game.test.is_empty() and not Game.test.has("save"):
		return
	Game.write_save({
		"class": player.class_id,
		"map": Game.selected_map,
		"seed": Game.run_seed,
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
			"charms": player.charms,
			"weapon_tier": player.weapon_tier,
			"weapon": player.weapon(),
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
	for c in p.get("charms", []):
		if typeof(c) == TYPE_DICTIONARY and c.has("mods"):
			player.apply_charm(c)
	player.weapon_tier = int(p.get("weapon_tier", 0))
	var saved_w = p.get("weapon", null)
	if typeof(saved_w) == TYPE_DICTIONARY and saved_w.has("base"):
		player.equip_weapon(saved_w)
	elif player.weapon_tier > 0:
		player.equip_weapon(Forge.from_tier(player.class_id, player.weapon_tier))
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
	## Solo: the champion is dead, the vigil is over.
	phase = Phase.OVER
	phase_t = 0.0
	Sfx.music("music_defeat", 2.5)
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


func _game_over_view() -> void:
	## Duo: both champions have fallen.
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	phase_t = 0.0
	_prompt("revive", "")
	Sfx.music("music_defeat", 2.5)
	Sfx.play("game_over")
	if Game.test.has("log"):
		print("[duo] the vigil ends at night %d score=%d kills=%d" % [wave, score, player.kills])
	hud.show_banner("THE VIGIL HAS FALLEN", "Both champions lie in the dark", UiTheme.RED)
	var t := get_tree().create_timer(2.5, true)
	t.timeout.connect(func():
		if market.is_open():
			market.close_shop()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.visible = false
		game_over.open(self, false))
