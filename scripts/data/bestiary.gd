extends RefCounted
## The monster forge: foes assembled from modular parts (assets/sprites/monsters/parts/) with
## an element and traits. A generated foe is named by its id, "gen:<seed>:<night>", and is
## rebuilt identically from it on every machine (duo). "...:spawn" is the small copy a
## splitting foe leaves behind.

const PARTS_DIR := "res://assets/sprites/monsters/parts/"
const FRAME := 96
const FRAMES := 8
const ORDER := ["body", "armor", "head", "offhand", "weapon", "aura"]
## Layers drawn under the body (a cape hangs behind it).
const UNDER_BODY := ["cape"]

const BODIES := {
	"skeleton": {"noun": "Skeleton", "hp": 65.0, "speed": 3.9, "dmg": 12.0, "pain": 0.45, "gib": "dust", "hit": "hit_bone", "alert": "skeleton_alert", "death": "skeleton_death", "fallback": "skeleton", "weight": 30},
	"ghoul": {"noun": "Ghoul", "hp": 52.0, "speed": 5.4, "dmg": 10.0, "pain": 0.65, "gib": "blood", "hit": "hit_flesh", "alert": "ghoul_alert", "death": "ghoul_death", "fallback": "ghoul", "weight": 25},
	"cultist": {"noun": "Acolyte", "hp": 58.0, "speed": 3.4, "dmg": 13.0, "pain": 0.5, "gib": "blood", "hit": "hit_flesh", "alert": "cultist_cast", "death": "cultist_death", "fallback": "cultist", "weight": 18},
	"knight": {"noun": "Knight", "hp": 125.0, "speed": 3.1, "dmg": 16.0, "pain": 0.25, "gib": "dust", "hit": "hit_metal", "alert": "skeleton_alert", "death": "skeleton_death", "fallback": "skeleton", "weight": 15},
	"wraith": {"noun": "Wraith", "hp": 48.0, "speed": 4.8, "dmg": 13.0, "pain": 0.55, "gib": "dust", "hit": "hit_bone", "alert": "cultist_cast", "death": "cultist_death", "fallback": "cultist", "weight": 12},
}
## The weapon decides how the foe fights.
const WEAPONS := {
	"sword": {"style": "melee", "dmg": 1.0, "range": 1.9, "atk_cd": 1.3, "windup": 0.45, "sfx": "swing", "role": ""},
	"axe": {"style": "melee", "dmg": 1.2, "range": 1.9, "atk_cd": 1.5, "windup": 0.5, "sfx": "swing", "role": ""},
	"mace": {"style": "melee", "dmg": 1.25, "range": 1.9, "atk_cd": 1.6, "windup": 0.55, "sfx": "swing", "role": ""},
	"spear": {"style": "melee", "dmg": 1.0, "range": 2.7, "atk_cd": 1.4, "windup": 0.5, "sfx": "swing", "role": "Lancer"},
	"claws": {"style": "melee", "dmg": 0.8, "range": 1.7, "atk_cd": 0.9, "windup": 0.3, "sfx": "ghoul_attack", "role": "Stalker"},
	"greatsword": {"style": "smash", "dmg": 1.7, "range": 2.6, "atk_cd": 2.3, "windup": 0.8, "sfx": "brute_smash", "role": "Executioner", "two_handed": true},
	"bow": {"style": "ranged", "dmg": 0.8, "range": 24.0, "atk_cd": 2.3, "windup": 0.65, "sfx": "enemy_arrow", "role": "Archer", "two_handed": true},
	"staff": {"style": "caster", "dmg": 1.1, "range": 22.0, "atk_cd": 2.7, "windup": 0.75, "sfx": "shadow_bolt", "role": "Caster"},
}
## Which weapons each body tends to carry.
const KIT := {
	"skeleton": ["sword", "axe", "spear", "mace", "bow", "greatsword"],
	"ghoul": ["claws", "claws", "axe", "mace"],
	"cultist": ["staff", "staff", "sword", "claws"],
	"knight": ["sword", "axe", "mace", "spear", "greatsword", "greatsword"],
	"wraith": ["claws", "staff", "sword", "spear"],
}
const HEADS := ["skull", "horned_skull", "hood", "helm", "crowned_skull", "wolf_skull"]
const ARMORS := ["", "", "rags", "chain", "pauldrons", "cape"]
const ARMOR_HP := {"": 1.0, "rags": 1.0, "chain": 1.15, "pauldrons": 1.25, "cape": 1.05}
const OFFHANDS := ["", "", "shield", "lantern", "skull_orb"]

const ELEMENTS := {
	"none": {"adj": "", "weight": 40},
	"frost": {"adj": "Frostbound", "weight": 15, "tint": Color(0.85, 0.95, 1.15)},
	"flame": {"adj": "Cinder", "weight": 15, "tint": Color(1.12, 0.92, 0.82)},
	"plague": {"adj": "Plagued", "weight": 15, "tint": Color(0.92, 1.1, 0.85)},
	"void": {"adj": "Void-touched", "weight": 15, "tint": Color(0.95, 0.85, 1.15)},
}
const TRAITS := {
	"swift": {"adj": "Swift"},
	"ironclad": {"adj": "Ironclad"},
	"vampiric": {"adj": "Bloodthirsty"},
	"volatile": {"adj": "Volatile"},
	"splitting": {"adj": "Splitting"},
	"regenerating": {"adj": "Undying"},
	"phasing": {"adj": "Phasing"},
	"frenzied": {"adj": "Frenzied"},
	"hulking": {"adj": "Hulking"},
}

static var _defs := {}
static var _textures := {}


static func new_id(night: int, rng: RandomNumberGenerator) -> String:
	return "gen:%d:%d" % [rng.randi() & 0x7fffffff, night]


static func generate(id: String) -> Dictionary:
	if id.begins_with("gboss:"):
		return generate_boss(id)
	if _defs.has(id):
		return _defs[id]
	var parts := id.split(":")
	var seed_v := int(parts[1]) if parts.size() > 1 else 1
	var night := int(parts[2]) if parts.size() > 2 else 1
	var small := parts.size() > 3 and parts[3] == "spawn"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var body: String = _weighted(BODIES, rng)
	var b: Dictionary = BODIES[body]
	var kit: Array = KIT[body]
	var weapon: String = kit[rng.randi_range(0, kit.size() - 1)]
	var w: Dictionary = WEAPONS[weapon]
	var head: String = HEADS[rng.randi_range(0, HEADS.size() - 1)]
	var armor: String = ARMORS[rng.randi_range(0, ARMORS.size() - 1)]
	var offhand: String = "" if w.get("two_handed", false) else OFFHANDS[rng.randi_range(0, OFFHANDS.size() - 1)]
	var element: String = _weighted(ELEMENTS, rng)
	# more traits as the nights go on
	var n_traits := 0
	if night >= 4:
		n_traits = rng.randi_range(0, 1)
	if night >= 9:
		n_traits = rng.randi_range(1, 2)
	if night >= 16:
		n_traits = rng.randi_range(2, 3)
	var pool: Array = TRAITS.keys()
	var traits: Array = []
	for i in n_traits:
		traits.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	if element == "void" and not "phasing" in traits:
		traits.append("phasing")
	if small:
		traits.erase("splitting")
		traits.erase("hulking")

	var hp: float = float(b.hp) * float(ARMOR_HP.get(armor, 1.0)) * (1.15 if offhand == "shield" else 1.0)
	var dmg: float = float(b.dmg) * float(w.dmg) * (1.25 if element == "flame" else 1.0)
	var speed: float = float(b.speed) * (0.85 if w.style == "smash" else 1.0)
	var atk_cd: float = float(w.atk_cd)
	var height := 2.05
	var radius := 0.45
	var body_h := 1.8
	if "swift" in traits:
		speed *= 1.4
	if "ironclad" in traits:
		hp *= 1.5
	if "frenzied" in traits:
		atk_cd *= 0.65
	if "hulking" in traits:
		hp *= 1.8
		dmg *= 1.3
		speed *= 0.85
		height *= 1.35
		radius *= 1.3
		body_h *= 1.35
	if small:
		hp *= 0.4
		dmg *= 0.6
		height *= 0.7
		radius *= 0.75
		body_h *= 0.7
	var cost := clampi(int(round(hp / 40.0 + dmg / 14.0)) + traits.size(), 1, 9)

	var name_parts := []
	for t in traits.slice(0, 1):
		name_parts.append(TRAITS[t].adj)
	if str(ELEMENTS[element].adj) != "":
		name_parts.append(ELEMENTS[element].adj)
	name_parts.append(str(b.noun) + ((" " + str(w.role)) if str(w.role) != "" else ""))

	var d := {
		"name": " ".join(name_parts), "generated": true, "parts": {"body": body, "armor": armor, "head": head, "offhand": offhand, "weapon": weapon, "aura": "" if element == "none" else element},
		"frames": FRAMES, "height": height, "hp": hp, "speed": speed, "damage": dmg, "range": float(w.range), "atk_cd": atk_cd, "windup": float(w.windup),
		"radius": radius, "body_h": body_h, "pain": float(b.pain) * (0.5 if "ironclad" in traits else 1.0), "cost": cost, "score": cost * 12,
		"gold": [cost * 2 + 1, cost * 3 + 3], "gib": b.gib, "alert": b.alert, "attack_sfx": w.sfx, "death": b.death, "hit": b.hit,
		"element": element, "traits": traits, "sheet": "res://assets/sprites/enemies/%s.png" % b.fallback,
	}
	match str(w.style):
		"ranged":
			d["ranged"] = true
			d["projectile"] = "arrow"
			d["proj_speed"] = 26.0
			d["keep_min"] = 7.0
		"caster":
			d["ranged"] = true
			d["caster"] = true
			d["projectile"] = {"frost": "ice", "flame": "ember", "plague": "acid"}.get(element, "shadow")
			d["proj_speed"] = 13.0
			d["homing"] = 1.3
			d["keep_min"] = 8.0
		"smash":
			d["smash"] = 2.8 * (1.3 if "hulking" in traits else 1.0)
			d["knockback"] = 7.0
	if ELEMENTS[element].has("tint"):
		d["tint"] = ELEMENTS[element].tint
	d["texture"] = texture_for(d.parts, d.sheet)
	_defs[id] = d
	return d


static func _weighted(table: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in table:
		total += int(table[k].weight)
	var r := rng.randi_range(0, total - 1)
	for k in table:
		r -= int(table[k].weight)
		if r < 0:
			return k
	return table.keys()[0]


static func texture_for(parts: Dictionary, fallback_sheet: String) -> Texture2D:
	## Stacks the part strips into one sheet (cached per combination). Without the parts art,
	## the body's classic enemy sheet stands in.
	var key := str(parts)
	if _textures.has(key):
		return _textures[key]
	var body_path := PARTS_DIR + "body/%s.png" % parts.body
	if not ResourceLoader.exists(body_path):
		var fb: Texture2D = load(fallback_sheet)
		_textures[key] = fb
		return fb
	var img := Image.create(FRAME * FRAMES, FRAME, false, Image.FORMAT_RGBA8)
	var layers := []
	if str(parts.get("armor", "")) in UNDER_BODY:
		layers.append(["armor", parts.armor])
	for layer in ORDER:
		if layer == "armor" and str(parts.get("armor", "")) in UNDER_BODY:
			continue
		layers.append([layer, str(parts.get(layer, ""))])
	for l in layers:
		if str(l[1]) == "":
			continue
		var path := PARTS_DIR + "%s/%s.png" % [l[0], l[1]]
		if not ResourceLoader.exists(path):
			continue
		var li: Image = (load(path) as Texture2D).get_image()
		if li.is_compressed():
			li.decompress()
		li.convert(Image.FORMAT_RGBA8)
		img.blend_rect(li, Rect2i(Vector2i.ZERO, li.get_size()), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func describe_night(ids: Array) -> String:
	var names := []
	for id in ids:
		names.append(str(generate(id).name) + "s")
	return ", ".join(names)


# ============================================================================= forged bosses

const BOSS_SYLLABLES_A := ["Vhar", "Mor", "Kael", "Thra", "Ul", "Gor", "Xal", "Zeth", "Ny", "Draug", "Sar", "Vel", "Ash", "Grim"]
const BOSS_SYLLABLES_B := ["oth", "ak", "gul", "mire", "rath", "zul", "eth", "mor", "ith", "ax", "orn", "uun"]
const BOSS_TITLES := {
	"frost": ["the Frost Warden", "the Rime Lord", "the Winter Crown"],
	"flame": ["the Ashen King", "the Pyre Tyrant", "the Ember Lord"],
	"plague": ["the Plague Matron", "the Rot Lord", "the Blight Mother"],
	"void": ["the Void Herald", "the Hollow Prophet", "the Starless One"],
	"none": ["the Bone Tyrant", "the Grave Lord", "the Barrow King"],
}
const BOSS_LINES := {
	"frost": "The cold bites to the bone", "flame": "The very air burns", "plague": "Rot seeps from the walls",
	"void": "Reality frays at the edges", "none": "The dead kneel to their master",
}
const BOSS_MUSIC := {"frost": "music_boss_rime", "flame": "music_boss_cinder", "plague": "music_boss_rot", "void": "music_boss_hollow", "none": "music_boss_hollow"}
const BOSS_CASTS := {
	"frost": ["frost_nova", "blink", "volley"], "flame": ["meteor", "nova", "volley"], "plague": ["rain", "summon", "volley"],
	"void": ["blink", "volley", "summon"], "none": ["summon", "volley", "rain"],
}
const BOSS_SHEET := {"frost": "boss_rime", "flame": "boss_cinder", "plague": "boss_rot", "void": "boss", "none": "boss"}
const BOSS_ALERT := {"frost": "rime_cast", "flame": "cinder_roar", "plague": "rot_roar", "void": "boss_roar", "none": "boss_roar"}
const BOSS_DEATH := {"frost": "rime_death", "flame": "cinder_death", "plague": "rot_death", "void": "boss_death", "none": "boss_death"}
const BOSS_COLOR := {"frost": Color(0.55, 0.9, 1.0), "flame": Color(1.0, 0.55, 0.2), "plague": Color(0.8, 1.0, 0.35), "void": Color(0.75, 0.45, 1.0), "none": Color(0.5, 1.0, 0.55)}


static func boss_element(seed_v: int) -> String:
	var keys: Array = BOSS_TITLES.keys()
	return keys[absi(seed_v) % keys.size()]


static func boss_entry(seed_v: int, night: int) -> Dictionary:
	## The boss-night entry (same shape as Maps.BOSSES) of a forged boss.
	var el := boss_element(seed_v)
	var id := "gboss:%d:%d" % [absi(seed_v), night]
	var d := generate_boss(id)
	return {"enemy": id, "arena": "forged_boss:%d:%s" % [absi(seed_v), el],
		"arena_name": "THE LAIR OF %s" % str(d.name).to_upper(), "arena_line": BOSS_LINES[el],
		"color": BOSS_COLOR[el], "music": BOSS_MUSIC[el]}


static func generate_boss(id: String) -> Dictionary:
	if _defs.has(id):
		return _defs[id]
	var parts := id.split(":")
	var seed_v := int(parts[1]) if parts.size() > 1 else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 17
	var el := boss_element(seed_v)
	var bodies := ["knight", "skeleton", "wraith", "cultist", "ghoul"]
	var body: String = bodies[rng.randi_range(0, bodies.size() - 1)]
	var kit: Array = KIT[body]
	var weapon: String = kit[rng.randi_range(0, kit.size() - 1)]
	var w: Dictionary = WEAPONS[weapon]
	var heads := ["crowned_skull", "horned_skull", "helm", "wolf_skull"]
	var offhands := ["skull_orb", "lantern", "shield"]
	var look := {"body": body, "armor": ARMORS[rng.randi_range(2, ARMORS.size() - 1)], "head": heads[rng.randi_range(0, heads.size() - 1)],
		"offhand": "" if w.get("two_handed", false) else offhands[rng.randi_range(0, offhands.size() - 1)], "weapon": weapon, "aura": "" if el == "none" else el}
	var titles: Array = BOSS_TITLES[el]
	var bname: String = BOSS_SYLLABLES_A[rng.randi_range(0, BOSS_SYLLABLES_A.size() - 1)] + BOSS_SYLLABLES_B[rng.randi_range(0, BOSS_SYLLABLES_B.size() - 1)]
	var btitle: String = titles[rng.randi_range(0, titles.size() - 1)]
	var casts: Array = BOSS_CASTS[el].duplicate()
	var extra := ["summon", "volley", "rain", "nova", "blink", "meteor", "frost_nova"]
	for i in range(extra.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = extra[i]
		extra[i] = extra[j]
		extra[j] = tmp
	for c in extra:
		if casts.size() >= 4:
			break
		if not c in casts and rng.randf() < 0.5:
			casts.append(c)
	var sheet := "res://assets/sprites/enemies/%s.png" % BOSS_SHEET[el]
	var tex: Texture2D = texture_for(look, sheet)
	var frames := 9
	var portrait: Variant = "res://assets/ui/portrait_%s.png" % BOSS_SHEET[el]
	if tex.get_width() == FRAME * FRAMES:
		# parts art: a giant made from the forged parts, twice the size
		var img := tex.get_image()
		img.resize(FRAME * FRAMES * 2, FRAME * 2, Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
		frames = FRAMES
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(48, 4, 96, 96)
		portrait = at
	var d := {
		"name": bname, "title": btitle.capitalize(), "generated": true, "texture": tex, "sheet": sheet, "frames": frames, "height": 4.4,
		"hp": 3000.0 + rng.randf_range(-200.0, 400.0), "speed": rng.randf_range(2.8, 3.6), "damage": rng.randf_range(32.0, 38.0), "range": 3.6,
		"atk_cd": rng.randf_range(1.8, 2.2), "windup": 0.7, "radius": 0.8, "body_h": 3.8, "pain": 0.0, "cost": 0, "score": 1600, "gold": [210, 290],
		"smash": 4.2, "knockback": 10.0, "boss": true, "element": el,
		"gib": "dust" if body in ["skeleton", "knight", "wraith"] else "blood", "alert": BOSS_ALERT[el], "attack_sfx": "brute_smash", "death": BOSS_DEATH[el],
		"hit": "hit_metal" if body == "knight" else ("hit_bone" if body in ["skeleton", "wraith"] else "hit_flesh"),
		"cast_sfx": "frost_cast" if el == "frost" else "boss_cast", "volley_sfx": {"frost": "frost_cast", "flame": "fireball_cast"}.get(el, "shadow_bolt"),
		"color": BOSS_COLOR[el], "casts": casts, "proj": {"frost": "ice", "flame": "ember", "plague": "acid", "void": "shadow"}.get(el, "soul"),
		"summon": ["skeleton", "ghoul", "archer"] if body != "cultist" else ["cultist", "ghoul"], "portrait": portrait,
	}
	_defs[id] = d
	return d
