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
