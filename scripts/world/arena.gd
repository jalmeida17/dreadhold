extends Node3D
## Builds a playable map from a grid ("keep" = Blackstone Keep, "boss" = the Barrow Throne) (walls, floors, roofs, props, lights,
## sky and fog) and answers grid queries + a flow field used by enemy navigation.

const Sprites := preload("res://scripts/util/sprites.gd")

const CELL := 2.0
const WALL_H := 4.0
var W := 29
var H := 29
const WALLS := "#MBDRGT"
const BLOCKING_PROPS := "ASbXrg"
const FAR := 1 << 20

const WALL_MAT := {"#": "wall_stone", "T": "wall_stone", "M": "wall_moss", "B": "wall_banner", "D": "wall_dark", "R": "wall_rune", "G": "wall_gate"}
const FLOOR_MAT := {".": "floor_flagstone", ",": "floor_cobble", "_": "floor_dirt", "c": "floor_flagstone"}

const PROPS := {
	"A": {"tex": "altar", "frames": 4, "h": 1.3, "fps": 6.0, "radius": 1.0, "light": Color(0.35, 1.0, 0.45), "energy": 1.6, "range": 8.0, "light_y": 1.2},
	"S": {"tex": "statue", "frames": 1, "h": 3.5, "radius": 0.7},
	"b": {"tex": "brazier", "frames": 4, "h": 1.4, "fps": 10.0, "radius": 0.5, "unshaded": true, "light": Color(1.0, 0.55, 0.22), "energy": 2.4, "range": 10.0, "light_y": 1.6},
	"X": {"tex": "tree", "frames": 1, "h": 5.8, "radius": 0.45},
	"g": {"tex": "graves", "frames": 3, "h": 1.15, "radius": 0.35, "variants": true},
	"k": {"tex": "bones", "frames": 1, "h": 0.45, "radius": 0.0},
	"r": {"tex": "barrel", "frames": 1, "h": 1.15, "radius": 0.45},
	"v": {"tex": "brazier", "frames": 4, "h": 1.6, "fps": 9.0, "radius": 0.5, "unshaded": true, "modulate": Color(0.55, 1.5, 0.7), "light": Color(0.35, 1.0, 0.5), "energy": 2.8, "range": 12.0, "light_y": 1.8},
}

var tiles: Array = []
var props := {}
var roof := {}
var spawn_cells: Array[Vector2i] = []
var player_spawn_cell := Vector2i(14, 22)
var boss_cell := Vector2i(14, 10)
var layout := "keep"
var _circle: MeshInstance3D
var flow := PackedInt32Array()
var flow_target := Vector2i(-99, -99)
var torch_lights: Array = []
var anim_sprites: Array = []
var debris: Node3D
var time := 0.0
var _mats := {}
var _noise := FastNoiseLite.new()


func build(p_layout: String = "keep") -> void:
	layout = p_layout
	if layout == "boss":
		_make_layout_boss()
	else:
		_make_layout()
	_build_geometry()
	_build_props()
	_build_environment()
	if layout == "boss":
		_build_ritual_circle()
	debris = Node3D.new()
	debris.name = "Debris"
	add_child(debris)
	flow.resize(W * H)
	flow.fill(FAR)


# ============================================================================= layout

func _put_tile(x: int, y: int, ch: String) -> void:
	tiles[y][x] = ch


func _make_layout() -> void:
	tiles = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append(",")
		tiles.append(row)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for x in W:
		_put_tile(x, 0, "#")
		_put_tile(x, H - 1, "#")
	for y in H:
		_put_tile(0, y, "#")
		_put_tile(W - 1, y, "#")
	for y in H:
		for x in W:
			if tiles[y][x] == "#" and rng.randf() < 0.3:
				_put_tile(x, y, "M")
	# north cloister (roofed colonnade) with a corridor to the north gate
	for y in range(1, 5):
		for x in range(1, W - 1):
			_put_tile(x, y, "c")
			roof[Vector2i(x, y)] = true
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
	# gates
	_put_tile(14, 0, "G")
	_put_tile(14, H - 1, "G")
	_put_tile(0, 16, "G")
	_put_tile(W - 1, 16, "G")
	for p in [Vector2i(13, H - 1), Vector2i(15, H - 1), Vector2i(0, 15), Vector2i(0, 17), Vector2i(W - 1, 15), Vector2i(W - 1, 17)]:
		_put_tile(p.x, p.y, "T")
	for p in [Vector2i(7, H - 1), Vector2i(21, H - 1), Vector2i(0, 9), Vector2i(W - 1, 9), Vector2i(0, 23), Vector2i(W - 1, 23)]:
		_put_tile(p.x, p.y, "B")
	# central plaza with the altar, braziers and statues
	for y in range(12, 21):
		for x in range(10, 19):
			_put_tile(x, y, ".")
	props[Vector2i(14, 16)] = "A"
	for p in [Vector2i(12, 14), Vector2i(16, 14), Vector2i(12, 18), Vector2i(16, 18)]:
		props[p] = "b"
	for p in [Vector2i(10, 12), Vector2i(18, 12), Vector2i(10, 20), Vector2i(18, 20)]:
		props[p] = "S"
	# graveyard (south-west)
	for y in range(21, H - 1):
		for x in range(1, 9):
			_put_tile(x, y, "_")
	for p in [Vector2i(3, 22), Vector2i(5, 22), Vector2i(7, 22), Vector2i(3, 25), Vector2i(5, 25), Vector2i(7, 25)]:
		props[p] = "g"
	props[Vector2i(2, 27)] = "X"
	props[Vector2i(6, 27)] = "k"
	props[Vector2i(4, 24)] = "k"
	# overgrown garden (south-east)
	for y in range(21, H - 1):
		for x in range(20, W - 1):
			_put_tile(x, y, "_")
	props[Vector2i(24, 23)] = "X"
	props[Vector2i(21, 26)] = "X"
	for p in [Vector2i(27, 27), Vector2i(26, 27), Vector2i(27, 26)]:
		props[p] = "r"
	props[Vector2i(23, 25)] = "k"
	# ruined walls and rune obelisks (north courtyard)
	for p in [Vector2i(4, 8), Vector2i(5, 8), Vector2i(4, 9), Vector2i(23, 8), Vector2i(24, 8), Vector2i(24, 9)]:
		_put_tile(p.x, p.y, "D")
	_put_tile(8, 10, "R")
	_put_tile(20, 10, "R")
	# side cover pillars
	for p in [Vector2i(6, 15), Vector2i(6, 17), Vector2i(22, 15), Vector2i(22, 17)]:
		_put_tile(p.x, p.y, "P")
	props[Vector2i(2, 13)] = "k"
	props[Vector2i(26, 19)] = "k"
	props[Vector2i(14, 7)] = "k"
	# spawn points: inside each gate + the graveyard
	spawn_cells = [Vector2i(14, 1), Vector2i(14, H - 2), Vector2i(1, 16), Vector2i(W - 2, 16), Vector2i(4, 23), Vector2i(6, 23)]


func _make_layout_boss() -> void:
	## The Barrow Throne: a circular ritual arena of black stone in the void.
	W = 23
	H = 23
	tiles = []
	var c := Vector2(11.5, 11.5)
	for y in H:
		var row: Array = []
		for x in W:
			row.append("." if Vector2(x + 0.5, y + 0.5).distance_to(c) <= 10.0 else "D")
		tiles.append(row)
	for p in [Vector2i(11, 0), Vector2i(11, 22), Vector2i(0, 11), Vector2i(22, 11), Vector2i(4, 3), Vector2i(18, 3), Vector2i(4, 19), Vector2i(18, 19)]:
		_put_tile(p.x, p.y, "R")
	for k in 8:
		var a := deg_to_rad(22.5 + 45.0 * k)
		_put_tile(int(floor(c.x + cos(a) * 6.5)), int(floor(c.y + sin(a) * 6.5)), "P")
	for k in 4:
		var a := deg_to_rad(45.0 + 90.0 * k)
		props[Vector2i(int(floor(c.x + cos(a) * 8.3)), int(floor(c.y + sin(a) * 8.3)))] = "v"
	player_spawn_cell = Vector2i(11, 19)
	boss_cell = Vector2i(11, 4)
	spawn_cells = [boss_cell]


func _build_ritual_circle() -> void:
	_circle = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(17, 17)
	_circle.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/sprites/fx/magic_circle.png")
	m.albedo_color = Color(0.5, 1.0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_circle.material_override = m
	_circle.position = Vector3(W * CELL * 0.5, 0.03, H * CELL * 0.5)
	add_child(_circle)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 1.0, 0.5)
	l.light_energy = 2.2
	l.omni_range = 16.0
	l.position = Vector3(W * CELL * 0.5, 3.0, H * CELL * 0.5)
	add_child(l)
	torch_lights.append([l, 2.2, 0.0])


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

func _mat(tex_name: String) -> StandardMaterial3D:
	if _mats.has(tex_name):
		return _mats[tex_name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.95
	m.metallic_specular = 0.15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if layout == "boss":
		m.albedo_color = Color(0.55, 0.62, 0.6)
	if tex_name == "wall_rune":
		m.emission_enabled = true
		m.emission_texture = load("res://assets/textures/wall_rune_emit.png")
		m.emission = Color(0, 0, 0)  # ADD operator: emission colour + texture
		m.emission_energy_multiplier = 3.0
	_mats[tex_name] = m
	return m


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
		return "floor_flagstone" if roof.has(c) else "floor_cobble"
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
					_vquad(get_st.call(WALL_MAT[ch]), cell_center(c) + n * CELL * 0.5, n, CELL * 0.5, 0.0, WALL_H, 0.0, 1.0, 0.0, 1.0)
				if exposed:
					_add_box(body, cell_center(c) + Vector3(0, 3.0, 0), Vector3(CELL, 6.0, CELL))
				continue
			# floor (+ roof)
			_hquad(get_st.call(_floor_mat_for(c)), c, 0.0, true)
			if roof.has(c):
				_hquad(get_st.call("ceiling_wood"), c, WALL_H, false)
				for o: Vector2i in dirs:
					var nb := c + o
					if in_bounds(nb) and not is_wall(nb) and not roof.has(nb):
						var n := Vector3(o.x, 0, o.y)
						_vquad(get_st.call("ceiling_wood"), cell_center(c) + n * CELL * 0.5, n, CELL * 0.5, WALL_H - 0.55, WALL_H, 0.0, 1.0, 0.0, 0.28)
			if ch == "P":
				var hw := 0.45
				for o: Vector2i in dirs:
					var n := Vector3(o.x, 0, o.y)
					_vquad(get_st.call("wall_stone" if roof.has(c) else "wall_dark"), cell_center(c) + n * hw, n, hw, 0.0, WALL_H, 0.0, 0.45, 0.0, 1.0)
				_add_box(body, cell_center(c) + Vector3(0, WALL_H * 0.5, 0), Vector3(hw * 2, WALL_H, hw * 2))
	# ground slab
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
		var tex: Texture2D = load("res://assets/sprites/props/%s.png" % def.tex)
		var frames: int = def.frames
		var root := Node3D.new()
		root.position = cell_center(c)
		if key == "k" or key == "g":
			root.position += Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		add_child(root)
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
	# wall torches
	var torch_tex: Texture2D = load("res://assets/sprites/props/torch.png")
	var tframes := 4
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
				var spr := Sprites.make(torch_tex, tframes, 0.8, false, false)
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
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := PanoramaSkyMaterial.new()
	sm.panorama = load("res://assets/textures/sky_void.png" if layout == "boss" else "res://assets/textures/sky.png")
	sm.filter = false
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.38, 0.5)
	e.ambient_light_energy = 0.75
	e.fog_enabled = true
	e.fog_light_color = Color(0.06, 0.05, 0.09)
	e.fog_density = 0.016
	if layout == "boss":
		e.ambient_light_color = Color(0.3, 0.42, 0.36)
		e.fog_light_color = Color(0.02, 0.07, 0.04)
		e.fog_density = 0.022
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
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.7, 0.85)
	moon.light_energy = 0.55
	if layout == "boss":
		moon.light_color = Color(0.5, 0.9, 0.6)
		moon.light_energy = 0.35
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
