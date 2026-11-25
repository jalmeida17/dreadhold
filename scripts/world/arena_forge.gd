extends RefCounted
## The arena forge: battlefields and boss arenas generated from a seed.
##   "forged:<seed>"                     a battlefield (chosen as "Uncharted Lands")
##   "forged_boss:<seed>:<element>"      the arena of a forged boss
## Layouts are mirrored on both axes (fair from every side), every floor cell is reachable,
## and a theme sets the materials, props, lights, atmosphere and ambience.

const Arena := "res://scripts/world/arena.gd"

const THEMES := {
	"ruins": {"walls": ["#", "M", "B"], "floors": [",", ",", ".", "_"], "blockers": ["g", "g", "X", "S", "r"], "decor": ["k"], "lights": ["b"],
		"roof": false, "env": "keep", "amb": "amb_keep", "pillar": "wall_stone",
		"adj": ["Fallen", "Ashen", "Forsaken", "Broken", "Weeping"], "noun": ["Ruins", "Bastion", "Courtyard", "Watch"],
		"desc": "Crumbling walls under a dead moon, graves between the stones."},
	"ossuary": {"walls": ["K", "D"], "floors": [".", "."], "blockers": ["C", "C", "g"], "decor": ["k", "k", "n"], "lights": ["n", "v"],
		"roof": true, "env": "crypt", "amb": "amb_crypt", "pillar": "wall_dark",
		"adj": ["Silent", "Drowned", "Hollow", "Endless", "Bleached"], "noun": ["Ossuary", "Catacombs", "Charnel Halls", "Barrows"],
		"desc": "Bone-lined halls under a low vault, sarcophagi in every alcove."},
	"foundry": {"walls": ["O", "D"], "floors": [",", ",", "l"], "blockers": ["J", "J", "r"], "decor": ["k"], "lights": ["o"],
		"roof": false, "env": "boss_forge", "amb": "amb_boss", "pillar": "wall_dark",
		"adj": ["Burning", "Smouldering", "Cinder", "Molten", "Black"], "noun": ["Foundry", "Forgeworks", "Furnace", "Slag Pits"],
		"desc": "Obsidian and slag under a burning sky, rivers of lava between the anvils."},
	"glacier": {"walls": ["I"], "floors": ["s"], "blockers": ["Y", "Y", "X"], "decor": ["k"], "lights": ["Y"],
		"roof": false, "env": "boss_sanctum", "amb": "amb_village", "pillar": "wall_ice",
		"adj": ["Frozen", "Silent", "Pale", "Shattered", "Howling"], "noun": ["Glacier", "Icefields", "Frost Hollow", "Rime Gardens"],
		"desc": "Walls of ice and drifting snow, crystals humming in the cold."},
	"mire": {"walls": ["H", "M"], "floors": ["u", "_", "_"], "blockers": ["U", "F", "F", "r", "W", "X"], "decor": ["k"], "lights": ["b"],
		"roof": false, "env": "village", "amb": "amb_village", "pillar": "wall_wood",
		"adj": ["Rotting", "Sunken", "Blighted", "Drowned", "Festering"], "noun": ["Mire", "Hamlet", "Fens", "Marsh"],
		"desc": "A drowned hamlet in the fog: fences, cauldrons and the stink of the bog."},
	"temple": {"walls": ["Q", "R"], "floors": ["m"], "blockers": ["S", "S", "A"], "decor": ["n", "n"], "lights": ["v", "n"],
		"roof": true, "env": "cathedral", "amb": "amb_cathedral", "pillar": "wall_cathedral",
		"adj": ["Defiled", "Profane", "Forgotten", "Hollow", "Accursed"], "noun": ["Temple", "Sanctum", "Chapel", "Basilica"],
		"desc": "Marble aisles of a forsaken faith, statues watching from the shadows."},
}
## Boss arenas take their theme from the boss's element.
const ELEMENT_THEME := {"frost": "glacier", "flame": "foundry", "plague": "mire", "void": "temple", "none": "ossuary"}
const ELEMENT_CIRCLE := {"frost": Color(0.5, 0.85, 1.0), "flame": Color(1.0, 0.5, 0.15), "plague": Color(0.8, 1.0, 0.3), "void": Color(0.7, 0.4, 1.0), "none": Color(0.5, 1.0, 0.6)}


static func _rng(id: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var parts := id.split(":")
	rng.seed = int(parts[1]) if parts.size() > 1 else 1
	return rng


static func theme_of(id: String) -> String:
	var parts := id.split(":")
	if id.begins_with("forged_boss") and parts.size() > 2:
		return str(ELEMENT_THEME.get(parts[2], "ossuary"))
	var keys: Array = THEMES.keys()
	return keys[_rng(id).randi_range(0, keys.size() - 1)]


static func info(id: String) -> Dictionary:
	## Name, description and ambience of a forged battlefield.
	var theme := theme_of(id)
	var t: Dictionary = THEMES[theme]
	var rng := _rng(id)
	rng.randi()
	var name := "The %s %s" % [t.adj[rng.randi_range(0, t.adj.size() - 1)], t.noun[rng.randi_range(0, t.noun.size() - 1)]]
	return {"name": name, "desc": str(t.desc), "ambience": str(t.amb), "theme": theme}


static func generate(a: Node, id: String) -> Dictionary:
	## Fills the arena's grid, props and markers; returns its environment settings.
	var theme := theme_of(id)
	var t: Dictionary = THEMES[theme]
	var rng := _rng(id)
	rng.randi()
	rng.randi()
	rng.randi()
	var env: Dictionary = load(Arena).ENV[t.env].duplicate()
	if id.begins_with("forged_boss"):
		_boss_layout(a, t, rng)
		var el := id.split(":")[2] if id.split(":").size() > 2 else "none"
		env["circle"] = ELEMENT_CIRCLE.get(el, Color(0.5, 1.0, 0.6))
	else:
		_field_layout(a, t, rng)
		env.erase("circle")
	a.pillar_tex = str(t.pillar)
	if bool(t.roof):
		a.ceiling_tex = "ceiling_stone"
	return env


# ============================================================================= battlefields

static func _field_layout(a: Node, t: Dictionary, rng: RandomNumberGenerator) -> void:
	var size := 25 + 2 * rng.randi_range(0, 3)
	a.W = size
	a.H = size
	var main_wall: String = t.walls[0]
	a.tiles = []
	for y in size:
		var row: Array = []
		for x in size:
			row.append(t.floors[rng.randi_range(0, t.floors.size() - 1)])
		a.tiles.append(row)
	a.roof = {}
	a.props = {}
	for x in size:
		a.tiles[0][x] = main_wall
		a.tiles[size - 1][x] = main_wall
	for y in size:
		a.tiles[y][0] = main_wall
		a.tiles[y][size - 1] = main_wall
	var c := size / 2
	var mirror := func(x: int, y: int) -> Array:
		return [Vector2i(x, y), Vector2i(size - 1 - x, y), Vector2i(x, size - 1 - y), Vector2i(size - 1 - x, size - 1 - y)]
	var free_zone := func(x: int, y: int) -> bool:
		# keep a ring corridor along the walls and a clearing in the middle
		return x <= 1 or y <= 1 or Vector2(x - c, y - c).length() < 4.5
	# wall blocks, mirrored into the four quarters
	for i in rng.randi_range(4, 8):
		var w := rng.randi_range(1, 4)
		var h := rng.randi_range(1, 3)
		var x0 := rng.randi_range(2, c - 2)
		var y0 := rng.randi_range(2, c - 2)
		var ch: String = t.walls[rng.randi_range(0, t.walls.size() - 1)]
		for y in range(y0, mini(y0 + h, c - 1)):
			for x in range(x0, mini(x0 + w, c - 1)):
				if free_zone.call(x, y):
					continue
				for p in mirror.call(x, y):
					a.tiles[p.y][p.x] = ch
	# pillars and props
	for i in rng.randi_range(2, 5):
		var x := rng.randi_range(2, c - 2)
		var y := rng.randi_range(2, c - 2)
		if not free_zone.call(x, y) and not _is_wall(a, x, y):
			for p in mirror.call(x, y):
				a.tiles[p.y][p.x] = "P"
	for pass_ in [[t.blockers, rng.randi_range(3, 6)], [t.decor, rng.randi_range(2, 5)], [t.lights, rng.randi_range(2, 3)]]:
		var kinds: Array = pass_[0]
		for i in int(pass_[1]):
			var x := rng.randi_range(2, c - 1)
			var y := rng.randi_range(2, c - 1)
			if free_zone.call(x, y) or _is_wall(a, x, y) or a.tiles[y][x] == "P" or a.props.has(Vector2i(x, y)):
				continue
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			for p in mirror.call(x, y):
				a.props[p] = kind
	# torches in the outer walls, mirrored
	var step := rng.randi_range(5, 7)
	for k in range(step, c, step):
		for p in [Vector2i(k, 0), Vector2i(size - 1 - k, 0), Vector2i(k, size - 1), Vector2i(size - 1 - k, size - 1), Vector2i(0, k), Vector2i(0, size - 1 - k), Vector2i(size - 1, k), Vector2i(size - 1, size - 1 - k)]:
			a.tiles[p.y][p.x] = "T"
	if bool(t.roof):
		for y in size:
			for x in size:
				if not _is_wall(a, x, y):
					a.roof[Vector2i(x, y)] = true
	# markers
	a.player_spawn_cell = Vector2i(c, size - 5)
	a.look_cell = Vector2i(c, c)
	a.goblin_cell = Vector2i(c, size - 8)
	a.boss_cell = Vector2i(c, 4)
	a.spawn_cells.assign([Vector2i(c, 1), Vector2i(c, size - 2), Vector2i(1, c), Vector2i(size - 2, c), Vector2i(2, 2), Vector2i(size - 3, size - 3)])
	for m in [a.player_spawn_cell, a.goblin_cell, a.look_cell]:
		_clear(a, m, 1, t)
	for m in a.spawn_cells:
		_clear(a, m, 0, t)
	_seal_unreachable(a, a.look_cell, main_wall)
	_cap_lights(a, c, 22)


static func _cap_lights(a: Node, c: int, budget: int) -> void:
	## The browser renderer shows at most 32 lights: drop mirrored groups of lit props.
	var props_def: Dictionary = load(Arena).PROPS
	var lit := func(cell: Vector2i) -> bool:
		return a.props.has(cell) and props_def.get(str(a.props[cell]), {}).has("light")
	var count := func() -> int:
		var n := 0
		for cell in a.props:
			if lit.call(cell):
				n += 1
		for y in a.H:
			for x in a.W:
				if str(a.tiles[y][x]) == "T":
					n += 1
		return n
	while count.call() > budget:
		var victim := Vector2i(-1, -1)
		for cell in a.props:
			if lit.call(cell) and cell.x <= c and cell.y <= c:
				victim = cell
				break
		if victim.x < 0:
			return
		for p in [victim, Vector2i(a.W - 1 - victim.x, victim.y), Vector2i(victim.x, a.H - 1 - victim.y), Vector2i(a.W - 1 - victim.x, a.H - 1 - victim.y)]:
			a.props.erase(p)


static func _is_wall(a: Node, x: int, y: int) -> bool:
	return str(a.tiles[y][x]) in load(Arena).WALLS or str(a.tiles[y][x]) == "P"


static func _clear(a: Node, cell: Vector2i, r: int, t: Dictionary) -> void:
	for y in range(cell.y - r, cell.y + r + 1):
		for x in range(cell.x - r, cell.x + r + 1):
			if x <= 0 or y <= 0 or x >= a.W - 1 or y >= a.H - 1:
				continue
			if _is_wall(a, x, y):
				a.tiles[y][x] = t.floors[0]
			a.props.erase(Vector2i(x, y))


static func _seal_unreachable(a: Node, from: Vector2i, wall: String) -> void:
	## Every floor cell must be reachable: what the flood cannot reach becomes wall.
	var blocking: String = load(Arena).BLOCKING_PROPS
	var walk := func(cell: Vector2i) -> bool:
		if cell.x <= 0 or cell.y <= 0 or cell.x >= a.W - 1 or cell.y >= a.H - 1:
			return false
		if _is_wall(a, cell.x, cell.y):
			return false
		return not (a.props.has(cell) and str(a.props[cell]) in blocking)
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + o
			if not seen.has(n) and walk.call(n):
				seen[n] = true
				q.append(n)
	for y in range(1, a.H - 1):
		for x in range(1, a.W - 1):
			var cell := Vector2i(x, y)
			if not seen.has(cell) and walk.call(cell):
				a.tiles[y][x] = wall
				a.props.erase(cell)
				a.roof.erase(cell)


# ============================================================================= boss arenas

static func _boss_layout(a: Node, t: Dictionary, rng: RandomNumberGenerator) -> void:
	a.W = 23
	a.H = 23
	var c := Vector2(11.5, 11.5)
	var shape := rng.randi_range(0, 2)   # 0 round, 1 octagon, 2 cross-shaped hall
	var wall: String = t.walls[0]
	var floor_ch: String = t.floors[0]
	a.tiles = []
	a.props = {}
	a.roof = {}
	for y in 23:
		var row: Array = []
		for x in 23:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var inside := false
			match shape:
				0:
					inside = p.length() <= 10.0
				1:
					inside = absf(p.x) <= 10.0 and absf(p.y) <= 10.0 and absf(p.x) + absf(p.y) <= 14.0
				_:
					inside = (absf(p.x) <= 10.0 and absf(p.y) <= 5.5) or (absf(p.y) <= 10.0 and absf(p.x) <= 5.5) or p.length() <= 7.5
			row.append(floor_ch if inside else wall)
		a.tiles.append(row)
	# a ring of pillars or crystals, and lights at the diagonals
	var ring := rng.randf_range(5.5, 7.0)
	var count := 8 if rng.randf() < 0.6 else 6
	var use_pillar: bool = rng.randf() < 0.5
	for k in count:
		var ang := TAU * (float(k) + 0.5) / float(count)
		var cell := Vector2i(int(floor(c.x + cos(ang) * ring)), int(floor(c.y + sin(ang) * ring)))
		if use_pillar:
			a.tiles[cell.y][cell.x] = "P"
		else:
			a.props[cell] = t.blockers[0]
	var light: String = t.lights[0]
	for k in 4:
		var ang := deg_to_rad(45.0 + 90.0 * k)
		a.props[Vector2i(int(floor(c.x + cos(ang) * 8.3)), int(floor(c.y + sin(ang) * 8.3)))] = light
	a.player_spawn_cell = Vector2i(11, 19)
	a.boss_cell = Vector2i(11, 4)
	a.goblin_cell = Vector2i(11, 15)
	a.look_cell = a.boss_cell
	a.spawn_cells.assign([a.boss_cell])
	for m in [a.player_spawn_cell, a.boss_cell, a.goblin_cell]:
		_clear(a, m, 1, t)
