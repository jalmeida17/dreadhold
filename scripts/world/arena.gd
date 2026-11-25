extends Node3D
## Builds a playable map from a grid (walls, floors, roofs, props, lights, sky and fog)
## and answers grid queries + a flow field used by enemy navigation.
## Maps: keep, crypt, village, cathedral. Boss arenas: boss_barrow, boss_pit, boss_forge,
## boss_sanctum.

const Sprites := preload("res://scripts/util/sprites.gd")

const CELL := 2.0
const WALL_H := 4.0
const WALLS := "#MBDRGTHQKIO"
const BLOCKING_PROPS := "ASbXrgCWFYJUv"
const FAR := 1 << 20

const WALL_MAT := {
	"#": "wall_stone", "T": "wall_stone", "M": "wall_moss", "B": "wall_banner", "D": "wall_dark",
	"R": "wall_rune", "G": "wall_gate", "H": "wall_wood", "Q": "wall_cathedral", "K": "wall_bone",
	"I": "wall_ice", "O": "wall_obsidian",
}
const FLOOR_MAT := {
	".": "floor_flagstone", ",": "floor_cobble", "_": "floor_dirt", "c": "floor_flagstone",
	"m": "floor_marble", "s": "floor_snow", "l": "floor_lava", "u": "floor_sludge",
}
## Textures that may not exist yet fall back to an existing one.
const TEX_FALLBACK := {
	"wall_wood": "wall_moss", "wall_cathedral": "wall_stone", "wall_bone": "wall_dark", "wall_ice": "wall_dark",
	"wall_obsidian": "wall_dark", "floor_marble": "floor_flagstone", "floor_snow": "floor_flagstone",
	"floor_lava": "floor_cobble", "floor_sludge": "floor_dirt", "ceiling_stone": "ceiling_wood",
}

const PROPS := {
	"A": {"tex": "altar", "frames": 4, "h": 1.3, "fps": 6.0, "radius": 1.0, "light": Color(0.35, 1.0, 0.45), "energy": 1.6, "range": 8.0, "light_y": 1.2},
	"S": {"tex": "statue", "frames": 1, "h": 3.5, "radius": 0.7},
	"b": {"tex": "brazier", "frames": 4, "h": 1.4, "fps": 10.0, "radius": 0.5, "unshaded": true, "light": Color(1.0, 0.55, 0.22), "energy": 2.4, "range": 10.0, "light_y": 1.6},
	"X": {"tex": "tree", "frames": 1, "h": 5.8, "radius": 0.45},
	"g": {"tex": "graves", "frames": 3, "h": 1.15, "radius": 0.35, "variants": true},
	"k": {"tex": "bones", "frames": 1, "h": 0.45, "radius": 0.0},
	"r": {"tex": "barrel", "frames": 1, "h": 1.15, "radius": 0.45},
	"v": {"tex": "brazier", "frames": 4, "h": 1.6, "fps": 9.0, "radius": 0.5, "unshaded": true, "modulate": Color(0.55, 1.5, 0.7), "light": Color(0.35, 1.0, 0.5), "energy": 2.8, "range": 12.0, "light_y": 1.8},
	"C": {"tex": "sarcophagus", "frames": 1, "h": 1.0, "radius": 0.7},
	"W": {"tex": "well", "frames": 1, "h": 1.9, "radius": 0.9},
	"F": {"tex": "fence", "frames": 1, "h": 1.0, "radius": 0.4},
	"Y": {"tex": "crystal", "frames": 1, "h": 2.6, "radius": 0.5, "light": Color(0.45, 0.8, 1.0), "energy": 1.8, "range": 8.0, "light_y": 1.5},
	"J": {"tex": "obsidian_spike", "frames": 1, "h": 2.8, "radius": 0.5, "light": Color(1.0, 0.45, 0.15), "energy": 1.6, "range": 7.0, "light_y": 1.0},
	"n": {"tex": "candles", "frames": 4, "h": 0.6, "fps": 8.0, "radius": 0.0, "unshaded": true, "light": Color(1.0, 0.7, 0.35), "energy": 2.0, "range": 8.5, "light_y": 0.9},
	"U": {"tex": "cauldron", "frames": 4, "h": 1.2, "fps": 6.0, "radius": 0.6, "light": Color(0.6, 1.0, 0.3), "energy": 1.8, "range": 8.0, "light_y": 1.3},
	"o": {"tex": "brazier", "frames": 4, "h": 1.6, "fps": 10.0, "radius": 0.5, "unshaded": true, "modulate": Color(1.4, 0.75, 0.5), "light": Color(1.0, 0.4, 0.15), "energy": 3.0, "range": 12.0, "light_y": 1.8},
}

## Lighting / atmosphere per map. sky "" = closed vault (black background).
const ENV := {
	"keep": {"sky": "sky", "ambient": Color(0.4, 0.38, 0.5), "ambient_e": 0.75, "fog": Color(0.06, 0.05, 0.09), "fog_d": 0.016, "moon": Color(0.62, 0.7, 0.85), "moon_e": 0.55},
	"crypt": {"sky": "", "ambient": Color(0.46, 0.42, 0.5), "ambient_e": 0.95, "fog": Color(0.035, 0.03, 0.04), "fog_d": 0.02, "moon": Color(0, 0, 0), "moon_e": 0.0},
	"village": {"sky": "sky", "ambient": Color(0.4, 0.42, 0.5), "ambient_e": 0.8, "fog": Color(0.12, 0.13, 0.15), "fog_d": 0.03, "moon": Color(0.6, 0.68, 0.8), "moon_e": 0.5},
	"cathedral": {"sky": "", "ambient": Color(0.44, 0.33, 0.4), "ambient_e": 0.85, "fog": Color(0.06, 0.015, 0.025), "fog_d": 0.026, "moon": Color(0, 0, 0), "moon_e": 0.0},
	"boss_barrow": {"sky": "sky_void", "ambient": Color(0.3, 0.42, 0.36), "ambient_e": 0.75, "fog": Color(0.02, 0.07, 0.04), "fog_d": 0.022, "moon": Color(0.5, 0.9, 0.6), "moon_e": 0.35, "circle": Color(0.5, 1.0, 0.6), "tint": Color(0.55, 0.62, 0.6)},
	"boss_pit": {"sky": "sky_rot", "ambient": Color(0.42, 0.45, 0.3), "ambient_e": 0.75, "fog": Color(0.09, 0.11, 0.03), "fog_d": 0.03, "moon": Color(0.75, 0.85, 0.45), "moon_e": 0.35, "circle": Color(0.8, 1.0, 0.3)},
	"boss_forge": {"sky": "sky_hell", "ambient": Color(0.5, 0.32, 0.28), "ambient_e": 0.8, "fog": Color(0.14, 0.04, 0.02), "fog_d": 0.024, "moon": Color(1.0, 0.55, 0.35), "moon_e": 0.45, "circle": Color(1.0, 0.5, 0.15)},
	"boss_sanctum": {"sky": "sky_frost", "ambient": Color(0.45, 0.52, 0.62), "ambient_e": 0.85, "fog": Color(0.3, 0.36, 0.44), "fog_d": 0.022, "moon": Color(0.7, 0.85, 1.0), "moon_e": 0.6, "circle": Color(0.5, 0.85, 1.0), "snow": true},
}

var W := 29
var H := 29
var tiles: Array = []
var props := {}
var roof := {}
var spawn_cells: Array[Vector2i] = []
var player_spawn_cell := Vector2i(14, 22)
var boss_cell := Vector2i(14, 10)
var goblin_cell := Vector2i(14, 19)
var look_cell := Vector2i(14, 16)
var layout := "keep"
var wall_override := {}
var pillar_tex := ""
var ceiling_tex := "ceiling_wood"
var flow := PackedInt32Array()
var flow_target := Vector2i(-99, -99)
var torch_lights: Array = []
var anim_sprites: Array = []
var debris: Node3D
var time := 0.0
var _circle: MeshInstance3D
var _mats := {}


func is_boss_arena() -> bool:
	return layout.begins_with("boss")


func build(p_layout: String = "keep") -> void:
	layout = p_layout if ENV.has(p_layout) else "keep"
	match layout:
		"crypt":
			_layout_crypt()
		"village":
			_layout_village()
		"cathedral":
			_layout_cathedral()
		"boss_barrow":
			_layout_boss_ring("D", ".", "P", "v", ["R"])
		"boss_pit":
			_layout_boss_ring("K", "u", "", "U", ["K"])
		"boss_forge":
			_layout_boss_ring("O", "l", "J", "o", ["O"])
		"boss_sanctum":
			_layout_boss_ring("I", "s", "Y", "", ["I"])
		_:
			_layout_keep()
	_build_geometry()
	_build_props()
	_build_environment()
	if ENV[layout].has("circle"):
		_build_ritual_circle(ENV[layout].circle)
	if ENV[layout].get("snow", false):
		_build_snow()
	debris = Node3D.new()
	debris.name = "Debris"
	add_child(debris)
	flow.resize(W * H)
	flow.fill(FAR)


# ============================================================================= layouts

func _put_tile(x: int, y: int, ch: String) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		tiles[y][x] = ch


func _fill(ch: String) -> void:
	tiles = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(ch)
		tiles.append(row)


func _rect(x0: int, y0: int, x1: int, y1: int, ch: String, roofed: bool = false) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put_tile(x, y, ch)
			if roofed:
				roof[Vector2i(x, y)] = true
			else:
				roof.erase(Vector2i(x, y))


func _border(ch: String) -> void:
	for x in W:
		_put_tile(x, 0, ch)
		_put_tile(x, H - 1, ch)
	for y in H:
		_put_tile(0, y, ch)
		_put_tile(W - 1, y, ch)


func _layout_keep() -> void:
	## Blackstone Keep: moonlit courtyard, cloister, graveyard and garden.
	W = 29
	H = 29
	_fill(",")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	_border("#")
	for y in H:
		for x in W:
			if tiles[y][x] == "#" and rng.randf() < 0.3:
				_put_tile(x, y, "M")
	_rect(1, 1, W - 2, 4, "c", true)
	for y in range(1, 5):
		_put_tile(13, y, "T" if y == 2 else "#")
		_put_tile(15, y, "T" if y == 2 else "#")
		_put_tile(14, y, ".")
		for x in [13, 14, 15]:
			roof.erase(Vector2i(x, y))
	for x in [3, 6, 9, 11, 17, 19, 22, 25]:
		_put_tile(x, 4, "P")
	for x in [4, 10, 18, 24]:
		_put_tile(x, 0, "T")
	for x in [7, 21]:
		_put_tile(x, 0, "B")
	_put_tile(14, 0, "G")
	_put_tile(14, H - 1, "G")
	_put_tile(0, 16, "G")
	_put_tile(W - 1, 16, "G")
	for p in [Vector2i(13, H - 1), Vector2i(15, H - 1), Vector2i(0, 15), Vector2i(0, 17), Vector2i(W - 1, 15), Vector2i(W - 1, 17)]:
		_put_tile(p.x, p.y, "T")
	for p in [Vector2i(7, H - 1), Vector2i(21, H - 1), Vector2i(0, 9), Vector2i(W - 1, 9), Vector2i(0, 23), Vector2i(W - 1, 23)]:
		_put_tile(p.x, p.y, "B")
	_rect(10, 12, 18, 20, ".")
	props[Vector2i(14, 16)] = "A"
	for p in [Vector2i(12, 14), Vector2i(16, 14), Vector2i(12, 18), Vector2i(16, 18)]:
		props[p] = "b"
	for p in [Vector2i(10, 12), Vector2i(18, 12), Vector2i(10, 20), Vector2i(18, 20)]:
		props[p] = "S"
	_rect(1, 21, 8, H - 2, "_")
	for p in [Vector2i(3, 22), Vector2i(5, 22), Vector2i(7, 22), Vector2i(3, 25), Vector2i(5, 25), Vector2i(7, 25)]:
		props[p] = "g"
	props[Vector2i(2, 27)] = "X"
	props[Vector2i(6, 27)] = "k"
	props[Vector2i(4, 24)] = "k"
	_rect(20, 21, W - 2, H - 2, "_")
	props[Vector2i(24, 23)] = "X"
	props[Vector2i(21, 26)] = "X"
	for p in [Vector2i(27, 27), Vector2i(26, 27), Vector2i(27, 26)]:
		props[p] = "r"
	props[Vector2i(23, 25)] = "k"
	for p in [Vector2i(4, 8), Vector2i(5, 8), Vector2i(4, 9), Vector2i(23, 8), Vector2i(24, 8), Vector2i(24, 9)]:
		_put_tile(p.x, p.y, "D")
	_put_tile(8, 10, "R")
	_put_tile(20, 10, "R")
	for p in [Vector2i(6, 15), Vector2i(6, 17), Vector2i(22, 15), Vector2i(22, 17)]:
		_put_tile(p.x, p.y, "P")
	props[Vector2i(2, 13)] = "k"
	props[Vector2i(26, 19)] = "k"
	props[Vector2i(14, 7)] = "k"
	spawn_cells = [Vector2i(14, 1), Vector2i(14, H - 2), Vector2i(1, 16), Vector2i(W - 2, 16), Vector2i(4, 23), Vector2i(6, 23)]
	player_spawn_cell = Vector2i(14, 22)
	goblin_cell = Vector2i(14, 19)
	look_cell = Vector2i(14, 16)


func _layout_crypt() -> void:
	## The Sunken Crypt: a vaulted ossuary hall, four burial chambers and a ring of
	## corner vaults. Everything is roofed; tombs open into gates on every side.
	W = 27
	H = 27
	_fill("D")
	ceiling_tex = "ceiling_stone"
	wall_override = {"#": "wall_dark", "T": "wall_dark"}
	pillar_tex = "wall_dark"
	_rect(9, 9, 17, 17, "c", true)          # central ossuary hall
	_rect(9, 1, 17, 4, "c", true)           # north chamber
	_rect(9, 22, 17, 25, "c", true)         # south chamber
	_rect(1, 9, 4, 17, "c", true)           # west chamber
	_rect(22, 9, 25, 17, "c", true)         # east chamber
	_rect(12, 5, 14, 8, "c", true)          # corridors
	_rect(12, 18, 14, 21, "c", true)
	_rect(5, 12, 8, 14, "c", true)
	_rect(18, 12, 21, 14, "c", true)
	for c in [[1, 1], [20, 1], [1, 20], [20, 20]]:
		_rect(c[0], c[1], c[0] + 5, c[1] + 5, "c", true)   # corner vaults
	# passages linking corner vaults to the chambers (a loop around the hall)
	_rect(7, 2, 8, 3, "c", true)
	_rect(18, 2, 19, 3, "c", true)
	_rect(7, 23, 8, 24, "c", true)
	_rect(18, 23, 19, 24, "c", true)
	_rect(2, 7, 3, 8, "c", true)
	_rect(23, 7, 24, 8, "c", true)
	_rect(2, 18, 3, 19, "c", true)
	_rect(23, 18, 24, 19, "c", true)
	for p in [Vector2i(10, 10), Vector2i(16, 10), Vector2i(10, 16), Vector2i(16, 16)]:
		_put_tile(p.x, p.y, "P")
	# ossuary walls in the vaults, runes at the chamber ends
	for y in H:
		for x in W:
			if tiles[y][x] == "D" and ((x < 8 or x > 18) and (y < 8 or y > 18)):
				_put_tile(x, y, "K")
	for p in [Vector2i(13, 0), Vector2i(13, H - 1), Vector2i(0, 13), Vector2i(W - 1, 13)]:
		_put_tile(p.x, p.y, "G")
	for p in [Vector2i(11, 0), Vector2i(15, 0), Vector2i(11, H - 1), Vector2i(15, H - 1), Vector2i(0, 11), Vector2i(0, 15), Vector2i(W - 1, 11), Vector2i(W - 1, 15)]:
		_put_tile(p.x, p.y, "T")
	for p in [Vector2i(9, 8), Vector2i(17, 8), Vector2i(9, 18), Vector2i(17, 18)]:
		_put_tile(p.x, p.y, "R")
	# wall torches around the central hall
	for p in [Vector2i(8, 10), Vector2i(8, 16), Vector2i(18, 10), Vector2i(18, 16), Vector2i(10, 8), Vector2i(16, 8), Vector2i(10, 18), Vector2i(16, 18)]:
		_put_tile(p.x, p.y, "T")
	for p in [Vector2i(11, 13), Vector2i(15, 13), Vector2i(10, 2), Vector2i(16, 2), Vector2i(10, 24), Vector2i(16, 24), Vector2i(2, 10), Vector2i(2, 16), Vector2i(24, 10), Vector2i(24, 16)]:
		props[p] = "C"
	for p in [Vector2i(9, 9), Vector2i(17, 9), Vector2i(9, 17), Vector2i(17, 17), Vector2i(3, 3), Vector2i(23, 3), Vector2i(3, 23), Vector2i(23, 23), Vector2i(13, 2), Vector2i(13, 24)]:
		props[p] = "n"
	for p in [Vector2i(5, 5), Vector2i(21, 4), Vector2i(4, 22), Vector2i(22, 21), Vector2i(12, 11)]:
		props[p] = "k"
	spawn_cells = [Vector2i(13, 1), Vector2i(13, H - 2), Vector2i(1, 13), Vector2i(W - 2, 13), Vector2i(3, 2), Vector2i(23, 24)]
	player_spawn_cell = Vector2i(13, 16)
	goblin_cell = Vector2i(13, 11)
	look_cell = Vector2i(13, 9)


func _layout_village() -> void:
	## Hollowmere: a misty ruined village with cobbled lanes, timber houses and a well.
	W = 33
	H = 33
	_fill("_")
	_border("M")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for y in H:
		for x in W:
			if tiles[y][x] == "M" and rng.randf() < 0.45:
				_put_tile(x, y, "#")
	_rect(15, 1, 17, H - 2, ",")
	_rect(1, 15, W - 2, 17, ",")
	_rect(12, 12, 20, 20, ",")
	props[Vector2i(16, 16)] = "W"
	for p in [Vector2i(12, 12), Vector2i(20, 12), Vector2i(12, 20), Vector2i(20, 20)]:
		props[p] = "b"
	# timber houses (some half burned)
	var houses := [[3, 3, 7, 6], [9, 4, 12, 8], [20, 3, 24, 6], [26, 5, 29, 9], [3, 21, 6, 25], [8, 24, 12, 28], [21, 22, 25, 25], [26, 19, 29, 23], [4, 10, 7, 12], [25, 26, 28, 29]]
	for hs in houses:
		_rect(hs[0], hs[1], hs[2], hs[3], "H")
	for p in [Vector2i(7, 6), Vector2i(12, 8), Vector2i(29, 9), Vector2i(6, 25)]:
		_put_tile(p.x, p.y, "D")
	for x in [16]:
		_put_tile(x, 0, "G")
		_put_tile(x, H - 1, "G")
	_put_tile(0, 16, "G")
	_put_tile(W - 1, 16, "G")
	# fences, trees, a little churchyard
	for p in [Vector2i(9, 13), Vector2i(10, 13), Vector2i(22, 13), Vector2i(23, 13), Vector2i(9, 19), Vector2i(10, 19), Vector2i(22, 19), Vector2i(23, 19), Vector2i(19, 9), Vector2i(19, 23), Vector2i(13, 9), Vector2i(13, 23)]:
		props[p] = "F"
	for p in [Vector2i(2, 14), Vector2i(10, 2), Vector2i(29, 13), Vector2i(23, 29), Vector2i(6, 29), Vector2i(29, 2)]:
		props[p] = "X"
	for p in [Vector2i(25, 11), Vector2i(27, 11), Vector2i(25, 13), Vector2i(27, 13), Vector2i(29, 11)]:
		props[p] = "g"
	for p in [Vector2i(8, 6), Vector2i(13, 7), Vector2i(19, 26), Vector2i(20, 27), Vector2i(7, 20)]:
		props[p] = "r"
	for p in [Vector2i(5, 15), Vector2i(27, 17), Vector2i(17, 5), Vector2i(15, 27)]:
		props[p] = "k"
	spawn_cells = [Vector2i(16, 1), Vector2i(16, H - 2), Vector2i(1, 16), Vector2i(W - 2, 16), Vector2i(26, 12)]
	player_spawn_cell = Vector2i(16, 19)
	goblin_cell = Vector2i(14, 18)
	look_cell = Vector2i(16, 16)


func _layout_cathedral() -> void:
	## The Defiled Cathedral: a vaulted, fully roofed nave cut by a rood screen, side
	## chapels walled off from the aisles, and a desecrated apse glowing with grave-fire.
	W = 23
	H = 35
	_fill("m")
	_border("Q")
	pillar_tex = "wall_cathedral"
	ceiling_tex = "ceiling_stone"
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			roof[Vector2i(x, y)] = true
	# pillar rows with walled bays between some of them
	for y in range(3, H - 3, 3):
		_put_tile(6, y, "P")
		_put_tile(16, y, "P")
	for y in [10, 11, 22, 23, 28, 29]:
		_put_tile(6, y, "Q")
		_put_tile(16, y, "Q")
	# side chapels: the aisles are walled across with a single doorway
	for y in [9, 21]:
		for x in range(1, 6):
			if x != 3:
				_put_tile(x, y, "Q")
		for x in range(17, 22):
			if x != 19:
				_put_tile(x, y, "Q")
	# rood screen across the nave, with a central passage
	for x in range(7, 16):
		if x < 10 or x > 12:
			_put_tile(x, 13, "Q")
	_put_tile(9, 13, "T")
	_put_tile(13, 13, "T")
	# confessional booths and a broken choir stall in the nave
	for p in [Vector2i(8, 19), Vector2i(14, 19), Vector2i(8, 25), Vector2i(14, 25)]:
		_put_tile(p.x, p.y, "D")
	# desecrated apse
	props[Vector2i(11, 3)] = "A"
	for p in [Vector2i(8, 3), Vector2i(14, 3), Vector2i(9, 7), Vector2i(13, 7)]:
		props[p] = "v"
	for p in [Vector2i(7, 10), Vector2i(15, 10)]:
		props[p] = "S"
	for p in [Vector2i(0, 6), Vector2i(W - 1, 6), Vector2i(0, 18), Vector2i(W - 1, 18), Vector2i(0, 28), Vector2i(W - 1, 28)]:
		_put_tile(p.x, p.y, "B")
	_put_tile(11, 0, "R")
	_put_tile(7, 0, "R")
	_put_tile(15, 0, "R")
	_put_tile(11, H - 1, "G")
	for p in [Vector2i(0, 15), Vector2i(W - 1, 15), Vector2i(0, 25), Vector2i(W - 1, 25)]:
		_put_tile(p.x, p.y, "G")
	for p in [Vector2i(10, H - 1), Vector2i(12, H - 1), Vector2i(0, 31), Vector2i(W - 1, 31)]:
		_put_tile(p.x, p.y, "T")
	for p in [Vector2i(3, 4), Vector2i(19, 4), Vector2i(3, 15), Vector2i(19, 15), Vector2i(3, 27), Vector2i(19, 27), Vector2i(10, 16), Vector2i(12, 30), Vector2i(4, 32), Vector2i(18, 32)]:
		props[p] = "n"
	for p in [Vector2i(9, 16), Vector2i(13, 21), Vector2i(4, 23), Vector2i(18, 11), Vector2i(11, 9), Vector2i(2, 31), Vector2i(20, 6), Vector2i(12, 27)]:
		props[p] = "k"
	for p in [Vector2i(2, 6), Vector2i(20, 12), Vector2i(2, 18), Vector2i(20, 24), Vector2i(4, 29)]:
		props[p] = "C"
	spawn_cells = [Vector2i(11, H - 2), Vector2i(1, 15), Vector2i(W - 2, 15), Vector2i(1, 25), Vector2i(W - 2, 25), Vector2i(3, 2)]
	player_spawn_cell = Vector2i(11, 28)
	goblin_cell = Vector2i(11, 22)
	look_cell = Vector2i(11, 14)


func _layout_boss_ring(wall: String, floor_ch: String, pillar_prop: String, light_prop: String, accent_walls: Array) -> void:
	## Circular ritual arena shared by all bosses; only materials and props change.
	W = 23
	H = 23
	var c := Vector2(11.5, 11.5)
	tiles = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(floor_ch if Vector2(x + 0.5, y + 0.5).distance_to(c) <= 10.0 else wall)
		tiles.append(row)
	var accent: String = "R" if layout == "boss_barrow" else str(accent_walls[0])
	for p in [Vector2i(11, 0), Vector2i(11, 22), Vector2i(0, 11), Vector2i(22, 11), Vector2i(4, 3), Vector2i(18, 3), Vector2i(4, 19), Vector2i(18, 19)]:
		_put_tile(p.x, p.y, accent)
	for k in 8:
		var a := deg_to_rad(22.5 + 45.0 * k)
		var cell := Vector2i(int(floor(c.x + cos(a) * 6.5)), int(floor(c.y + sin(a) * 6.5)))
		if pillar_prop == "P":
			_put_tile(cell.x, cell.y, "P")
		elif pillar_prop != "":
			props[cell] = pillar_prop
	if light_prop != "":
		for k in 4:
			var a := deg_to_rad(45.0 + 90.0 * k)
			props[Vector2i(int(floor(c.x + cos(a) * 8.3)), int(floor(c.y + sin(a) * 8.3)))] = light_prop
	pillar_tex = "wall_dark"
	player_spawn_cell = Vector2i(11, 19)
	boss_cell = Vector2i(11, 4)
	goblin_cell = Vector2i(11, 15)
	look_cell = boss_cell
	spawn_cells = [boss_cell]


func _build_ritual_circle(col: Color) -> void:
	_circle = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(17, 17)
	_circle.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/sprites/fx/magic_circle.png")
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_circle.material_override = m
	_circle.position = Vector3(W * CELL * 0.5, 0.03, H * CELL * 0.5)
	add_child(_circle)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.2
	l.omni_range = 16.0
	l.position = Vector3(W * CELL * 0.5, 3.0, H * CELL * 0.5)
	add_child(l)
	torch_lights.append([l, 2.2, 0.0])


func _build_snow() -> void:
	## Gentle snowfall over the frozen sanctum.
	var p := GPUParticles3D.new()
	p.amount = 500
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-30, -12, -30), Vector3(60, 24, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(W * CELL * 0.5, 0.5, H * CELL * 0.5)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -0.4, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.96, 1.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(W * CELL * 0.5, 9.0, H * CELL * 0.5)
	add_child(p)


func boss_spawn() -> Vector3:
	return cell_center(boss_cell)


# ============================================================================= queries

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func tile(c: Vector2i) -> String:
	if not in_bounds(c):
		return "#"
	return tiles[c.y][c.x]


func is_wall(c: Vector2i) -> bool:
	return WALLS.contains(tile(c))


func walkable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var ch := tile(c)
	if WALLS.contains(ch) or ch == "P":
		return false
	if props.has(c) and BLOCKING_PROPS.contains(props[c]):
		return false
	return true


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))


func player_spawn() -> Vector3:
	return cell_center(player_spawn_cell)


func spawn_points() -> Array:
	var out: Array = []
	for c in spawn_cells:
		out.append(cell_center(c))
	return out


func random_floor_near(center: Vector3, radius_cells: int, rng: RandomNumberGenerator) -> Vector3:
	var c0 := world_to_cell(center)
	for i in 30:
		var c := c0 + Vector2i(rng.randi_range(-radius_cells, radius_cells), rng.randi_range(-radius_cells, radius_cells))
		if walkable(c) and c != c0:
			return cell_center(c) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	return center


func has_los(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return space.intersect_ray(q).is_empty()


# ============================================================================= flow field

func update_flow(target: Vector2i) -> void:
	if target == flow_target or not walkable(target):
		return
	flow_target = target
	flow.fill(FAR)
	var q: Array[Vector2i] = [target]
	flow[target.y * W + target.x] = 0
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var d := flow[c.y * W + c.x]
		for o: Vector2i in dirs:
			var n := c + o
			if not walkable(n):
				continue
			if o.x != 0 and o.y != 0 and (not walkable(Vector2i(c.x + o.x, c.y)) or not walkable(Vector2i(c.x, c.y + o.y))):
				continue
			var cost := 14 if (o.x != 0 and o.y != 0) else 10
			var nd := d + cost
			if nd < flow[n.y * W + n.x]:
				flow[n.y * W + n.x] = nd
				q.append(n)


func flow_dir(pos: Vector3) -> Vector3:
	var c := world_to_cell(pos)
	if not in_bounds(c):
		return Vector3.ZERO
	var best := c
	var best_d := flow[c.y * W + c.x] if walkable(c) else FAR + 1
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var n := c + Vector2i(ox, oy)
			if not walkable(n):
				continue
			if ox != 0 and oy != 0 and (not walkable(Vector2i(c.x + ox, c.y)) or not walkable(Vector2i(c.x, c.y + oy))):
				continue
			var d := flow[n.y * W + n.x]
			if d < best_d:
				best_d = d
				best = n
	if best == c:
		return Vector3.ZERO
	var v := cell_center(best) - pos
	v.y = 0.0
	return v.normalized()


# ============================================================================= geometry

func _tex_path(tex_name: String) -> String:
	var p := "res://assets/textures/%s.png" % tex_name
	if ResourceLoader.exists(p):
		return p
	return "res://assets/textures/%s.png" % TEX_FALLBACK.get(tex_name, "wall_dark")


func _mat(tex_name: String) -> StandardMaterial3D:
	if _mats.has(tex_name):
		return _mats[tex_name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(_tex_path(tex_name))
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.95
	m.metallic_specular = 0.15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ENV[layout].has("tint"):
		m.albedo_color = ENV[layout].tint
	var emit := "res://assets/textures/%s_emit.png" % tex_name
	if ResourceLoader.exists(emit):
		m.emission_enabled = true
		m.emission_texture = load(emit)
		m.emission = Color(0, 0, 0)  # ADD operator: emission colour + texture
		m.emission_energy_multiplier = 3.0
	_mats[tex_name] = m
	return m


func _wall_tex(ch: String) -> String:
	return str(wall_override.get(ch, WALL_MAT[ch]))


func _vquad(st: SurfaceTool, fc: Vector3, n: Vector3, hw: float, y0: float, y1: float, u0: float, u1: float, v0: float, v1: float) -> void:
	## Vertical quad centred on fc (at floor height), facing n, half width hw.
	var right := Vector3.UP.cross(n)
	var lb := fc - right * hw + Vector3(0, y0, 0)
	var rb := fc + right * hw + Vector3(0, y0, 0)
	var lt := fc - right * hw + Vector3(0, y1, 0)
	var rt := fc + right * hw + Vector3(0, y1, 0)
	for v in [[lb, Vector2(u0, v1)], [lt, Vector2(u0, v0)], [rt, Vector2(u1, v0)], [lb, Vector2(u0, v1)], [rt, Vector2(u1, v0)], [rb, Vector2(u1, v1)]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _hquad(st: SurfaceTool, c: Vector2i, y: float, up: bool) -> void:
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	var x1 := x0 + CELL
	var z1 := z0 + CELL
	var n := Vector3.UP if up else Vector3.DOWN
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var cc := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	var verts := [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [cc, Vector2(1, 1)], [a, Vector2(0, 0)], [cc, Vector2(1, 1)], [d, Vector2(0, 1)]]
	if not up:
		verts = [[a, Vector2(0, 0)], [cc, Vector2(1, 1)], [b, Vector2(1, 0)], [a, Vector2(0, 0)], [d, Vector2(0, 1)], [cc, Vector2(1, 1)]]
	for v in verts:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _floor_mat_for(c: Vector2i) -> String:
	var ch := tile(c)
	if ch == "P":
		# pillar cells borrow the floor of a walkable neighbour
		for o in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nch := tile(c + o)
			if FLOOR_MAT.has(nch):
				return FLOOR_MAT[nch]
		return "floor_flagstone"
	return FLOOR_MAT.get(ch, "floor_cobble")


func _build_geometry() -> void:
	var sts := {}
	var get_st := func(key: String) -> SurfaceTool:
		if not sts.has(key):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[key] = s
		return sts[key]
	var body := StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var ch := tile(c)
			if WALLS.contains(ch):
				var exposed := false
				for o: Vector2i in dirs:
					var nb := c + o
					if not in_bounds(nb) or is_wall(nb):
						continue
					exposed = true
					var n := Vector3(o.x, 0, o.y)
					_vquad(get_st.call(_wall_tex(ch)), cell_center(c) + n * CELL * 0.5, n, CELL * 0.5, 0.0, WALL_H, 0.0, 1.0, 0.0, 1.0)
				if exposed:
					_add_box(body, cell_center(c) + Vector3(0, 3.0, 0), Vector3(CELL, 6.0, CELL))
				continue
			_hquad(get_st.call(_floor_mat_for(c)), c, 0.0, true)
			if roof.has(c):
				_hquad(get_st.call(ceiling_tex), c, WALL_H, false)
				for o: Vector2i in dirs:
					var nb := c + o
					if in_bounds(nb) and not is_wall(nb) and not roof.has(nb):
						var n := Vector3(o.x, 0, o.y)
						_vquad(get_st.call(ceiling_tex), cell_center(c) + n * CELL * 0.5, n, CELL * 0.5, WALL_H - 0.55, WALL_H, 0.0, 1.0, 0.0, 0.28)
			if ch == "P":
				var hw := 0.45
				var ptex := pillar_tex if pillar_tex != "" else ("wall_stone" if roof.has(c) else "wall_dark")
				for o: Vector2i in dirs:
					var n := Vector3(o.x, 0, o.y)
					_vquad(get_st.call(ptex), cell_center(c) + n * hw, n, hw, 0.0, WALL_H, 0.0, 0.45, 0.0, 1.0)
				_add_box(body, cell_center(c) + Vector3(0, WALL_H * 0.5, 0), Vector3(hw * 2, WALL_H, hw * 2))
	_add_box(body, Vector3(W * CELL * 0.5, -0.5, H * CELL * 0.5), Vector3(W * CELL, 1.0, H * CELL))
	var mesh := ArrayMesh.new()
	for key in sts:
		var st: SurfaceTool = sts[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(key))
	var mi := MeshInstance3D.new()
	mi.name = "Level"
	mi.mesh = mesh
	add_child(mi)


func _add_box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)


# ============================================================================= props & lights

func _build_props() -> void:
	var body := StaticBody3D.new()
	body.name = "PropCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for c: Vector2i in props:
		var key: String = props[c]
		var def: Dictionary = PROPS[key]
		var path := "res://assets/sprites/props/%s.png" % def.tex
		var root := Node3D.new()
		root.position = cell_center(c)
		if key == "k" or key == "g":
			root.position += Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		add_child(root)
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			var frames: int = def.frames
			var spr := Sprites.make(tex, frames, def.h, true, not def.get("unshaded", false))
			root.add_child(spr)
			if def.has("modulate"):
				spr.modulate = def.modulate
			if def.get("variants", false):
				spr.frame = (c.x * 7 + c.y * 3) % frames
			elif frames > 1:
				anim_sprites.append([spr, float(def.get("fps", 8.0)), rng.randf() * 3.0])
		if float(def.radius) > 0.0:
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = def.radius
			cy.height = maxf(def.h, 1.6)
			cs.shape = cy
			cs.position = root.position + Vector3(0, cy.height * 0.5, 0)
			body.add_child(cs)
		if def.has("light"):
			var l := OmniLight3D.new()
			l.light_color = def.light
			l.light_energy = def.energy
			l.omni_range = def.range
			l.omni_attenuation = 1.3
			l.position = Vector3(0, def.get("light_y", 1.5), 0)
			root.add_child(l)
			torch_lights.append([l, float(def.energy), rng.randf() * 10.0])
	var torch_tex: Texture2D = load("res://assets/sprites/props/torch.png")
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if tile(c) != "T":
				continue
			for o: Vector2i in dirs:
				var nb := c + o
				if not in_bounds(nb) or is_wall(nb):
					continue
				var n := Vector3(o.x, 0, o.y)
				var spr := Sprites.make(torch_tex, 4, 0.8, false, false)
				spr.position = cell_center(c) + n * (CELL * 0.5 + 0.03) + Vector3(0, 2.3, 0)
				spr.basis = Basis.looking_at(-n, Vector3.UP)
				add_child(spr)
				anim_sprites.append([spr, 10.0, rng.randf() * 3.0])
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.58, 0.25)
				l.light_energy = 1.9
				l.omni_range = 9.0
				l.omni_attenuation = 1.25
				l.position = cell_center(c) + n * (CELL * 0.5 + 0.55) + Vector3(0, 2.7, 0)
				add_child(l)
				torch_lights.append([l, 1.9, rng.randf() * 10.0])


func _build_environment() -> void:
	var env: Dictionary = ENV[layout]
	var e := Environment.new()
	var sky_name: String = env.sky
	var sky_path := "res://assets/textures/%s.png" % sky_name
	if sky_name != "" and not ResourceLoader.exists(sky_path):
		sky_path = "res://assets/textures/sky_void.png"
	if sky_name == "":
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.01, 0.01, 0.015)
	else:
		e.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sm := PanoramaSkyMaterial.new()
		sm.panorama = load(sky_path)
		sm.filter = false
		sky.sky_material = sm
		e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = env.ambient
	e.ambient_light_energy = env.ambient_e
	e.fog_enabled = true
	e.fog_light_color = env.fog
	e.fog_density = env.fog_d
	e.fog_sky_affect = 0.0
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	if float(env.moon_e) > 0.0:
		var moon := DirectionalLight3D.new()
		moon.light_color = env.moon
		moon.light_energy = env.moon_e
		moon.shadow_enabled = true
		moon.rotation_degrees = Vector3(-48, 30, 0)
		add_child(moon)


func _process(delta: float) -> void:
	time += delta
	if _circle != null:
		_circle.rotation.y = time * 0.08
	for a in anim_sprites:
		var spr: Sprite3D = a[0]
		spr.frame = int((time + float(a[2])) * float(a[1])) % spr.hframes
	for t in torch_lights:
		var l: OmniLight3D = t[0]
		var ph: float = t[2]
		l.light_energy = float(t[1]) * (0.85 + 0.15 * sin(time * 9.0 + ph) * sin(time * 5.3 + ph * 2.0))
