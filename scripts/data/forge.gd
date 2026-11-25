extends RefCounted
## The weapon forge: every boss slain offers three generated weapons to choose from.
## weapon = base (per class) x material (tier) x enchantment x properties, with a rarity.
## A weapon is a plain Dictionary of ids and numbers (it goes into saves as JSON):
##   {class, base, material, enchant, rarity, level, affixes: {mod: value}, name}
## Colours, sheets and the final stat bonus are derived from those ids (see mods(), tint()...).

const SHEET_DIR := "res://assets/weapons/forge/"
## Until the forge art exists, each base falls back to one of the original sheets.
const FALLBACK_SHEET := {
	"axe": "res://assets/weapons/axe.png", "greataxe": "res://assets/weapons/axe_2.png",
	"sword": "res://assets/weapons/axe.png", "mace": "res://assets/weapons/axe_3.png", "warhammer": "res://assets/weapons/axe_3.png",
	"staff": "res://assets/weapons/staff.png", "scepter": "res://assets/weapons/staff_2.png", "bonestaff": "res://assets/weapons/staff_3.png",
	"longbow": "res://assets/weapons/bow.png", "recurve": "res://assets/weapons/bow_2.png", "crossbow": "res://assets/weapons/bow_3.png",
}

const BASES := {
	"warrior": {
		"axe": {"name": "Axe", "desc": "Balanced and reliable.", "mods": {}},
		"greataxe": {"name": "Greataxe", "desc": "Huge, slow cleaves that reach further.", "mods": {"damage": 0.25, "attack_speed": -0.15, "cleave_range": 0.4}},
		"sword": {"name": "Longsword", "desc": "Quick, precise strikes.", "mods": {"damage": -0.1, "attack_speed": 0.22, "crit": 0.05}},
		"mace": {"name": "Mace", "desc": "Crushes the wounded.", "mods": {"damage": 0.08, "execute": 0.25}},
		"warhammer": {"name": "Warhammer", "desc": "Slow, devastating blows and a wider spin.", "mods": {"damage": 0.35, "attack_speed": -0.25, "spin_bonus": 0.5}},
	},
	"mage": {
		"staff": {"name": "Staff", "desc": "Balanced and reliable.", "mods": {}},
		"scepter": {"name": "Scepter", "desc": "Faster casting, steadier mana.", "mods": {"attack_speed": 0.2, "damage": -0.05, "resource_regen": 0.15}},
		"bonestaff": {"name": "Bonestaff", "desc": "Slower casting, wider explosions.", "mods": {"damage": 0.15, "splash": 0.3, "attack_speed": -0.1}},
	},
	"hunter": {
		"longbow": {"name": "Longbow", "desc": "Balanced and reliable.", "mods": {}},
		"recurve": {"name": "Recurve Bow", "desc": "Fast, keen shots.", "mods": {"attack_speed": 0.18, "crit": 0.05, "damage": -0.06}},
		"crossbow": {"name": "Crossbow", "desc": "Slow, heavy bolts that pierce.", "mods": {"damage": 0.4, "attack_speed": -0.3, "pierce": 1.0}},
	},
}
const STARTERS := {"warrior": "axe", "mage": "staff", "hunter": "longbow"}
## Bases whose material is wood-like (named Yew, Ash... in the first tiers).
const WOODEN := ["staff", "bonestaff", "longbow", "recurve"]

## Tiers, worst to best. "dmg" is the damage bonus the material grants.
const MATERIALS := [
	{"metal": "Iron", "wood": "Yew", "dmg": 0.0, "tint": Color(0.82, 0.8, 0.76)},
	{"metal": "Steel", "wood": "Ash", "dmg": 0.08, "tint": Color(0.92, 0.94, 1.0)},
	{"metal": "Bone", "wood": "Bone", "dmg": 0.14, "tint": Color(1.0, 0.93, 0.78)},
	{"metal": "Blackiron", "wood": "Ironwood", "dmg": 0.22, "tint": Color(0.5, 0.5, 0.56)},
	{"metal": "Bloodsteel", "wood": "Bloodwood", "dmg": 0.3, "tint": Color(0.95, 0.45, 0.42)},
	{"metal": "Obsidian", "wood": "Obsidian", "dmg": 0.4, "tint": Color(0.42, 0.36, 0.52)},
	{"metal": "Moonsilver", "wood": "Moonsilver", "dmg": 0.5, "tint": Color(0.78, 0.9, 1.15)},
	{"metal": "Dragonbone", "wood": "Dragonbone", "dmg": 0.62, "tint": Color(1.15, 0.82, 0.45)},
	{"metal": "Voidglass", "wood": "Voidglass", "dmg": 0.75, "tint": Color(0.62, 0.42, 1.1)},
]

## On-hit enchantments. "element" effects are applied by the enemy (scripts/enemies/enemy.gd).
const ENCHANTS := {
	"none": {"adj": "", "glow": Color(0.9, 0.85, 0.7), "text": ""},
	"flame": {"adj": "Burning", "glow": Color(1.0, 0.5, 0.15), "element": "burn", "power": 0.45, "text": "Hits set foes ablaze (45% of the hit as fire over 3 s)."},
	"frost": {"adj": "Frostbitten", "glow": Color(0.5, 0.85, 1.0), "element": "chill", "power": 1.0, "text": "Hits chill foes: 40% slower for 2 s."},
	"venom": {"adj": "Venomous", "glow": Color(0.45, 1.0, 0.3), "element": "poison", "power": 0.3, "text": "Hits poison foes (stacks up to 5 times)."},
	"storm": {"adj": "Thundering", "glow": Color(0.7, 0.8, 1.0), "element": "storm", "power": 0.35, "text": "Hits arc lightning to 2 nearby foes."},
	"shadow": {"adj": "Shadowed", "glow": Color(0.65, 0.3, 1.0), "mods": {"lifesteal": 0.05}, "text": "Heals you for 5% of the damage you deal."},
	"holy": {"adj": "Blessed", "glow": Color(1.0, 0.9, 0.55), "mods": {"holy": 0.3}, "text": "+30% damage to bosses and elites."},
}

## Properties, named by their suffix. "v" is one roll at weapon level 1.
const AFFIXES := {
	"damage": {"suffix": "of Ruin", "v": 0.1},
	"attack_speed": {"suffix": "of Haste", "v": 0.08},
	"crit": {"suffix": "of the Hawk", "v": 0.04},
	"crit_mult": {"suffix": "of Slaughter", "v": 0.2},
	"lifesteal": {"suffix": "of the Leech", "v": 0.02},
	"cooldown": {"suffix": "of the Sage", "v": -0.06},
	"resource_regen": {"suffix": "of the Wellspring", "v": 0.12},
	"execute": {"suffix": "of the Headsman", "v": 0.15},
	"armor": {"suffix": "of the Bastion", "v": 0.03},
	"speed": {"suffix": "of the Wind", "v": 0.04},
}
const RARITY_AFFIXES := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
const RARITY_POWER := {"common": 1.0, "rare": 1.1, "epic": 1.2, "legendary": 1.35}

const MOD_TEXT := {
	"damage": "%s damage", "attack_speed": "%s attack speed", "crit": "%s critical strike chance",
	"crit_mult": "%s critical strike damage", "lifesteal": "%s of damage dealt healed", "cooldown": "abilities recharge %s faster",
	"resource_regen": "%s resource regeneration", "execute": "%s damage to foes below 35%% health", "armor": "%s damage reduction",
	"speed": "%s movement speed", "cleave_range": "Cleave reaches %s m further", "spin_bonus": "wider Reaving Spin",
	"splash": "%s larger explosions", "pierce": "arrows pierce %s more foe", "holy": "%s damage to bosses and elites",
}


static func starter(class_id: String) -> Dictionary:
	var w := {"class": class_id, "base": STARTERS.get(class_id, "axe"), "material": 0, "enchant": "none",
		"rarity": "common", "level": 0, "affixes": {}}
	w["name"] = weapon_name(w)
	return w


static func forge(class_id: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	## A random weapon for a champion who has slain `level` bosses.
	var bases: Array = BASES[class_id].keys()
	var base: String = bases[rng.randi_range(0, bases.size() - 1)]
	var mat := clampi(level + rng.randi_range(-1, 1), 0, MATERIALS.size() - 1)
	var lv := float(level)
	var weights := {"common": maxf(40.0 - lv * 6.0, 4.0), "rare": 40.0, "epic": 12.0 + lv * 4.0, "legendary": 2.0 + lv * 2.0}
	var rarity := _pick(weights, rng)
	var enchant := "none"
	if rarity != "common" or rng.randf() < 0.35:
		var keys: Array = ENCHANTS.keys()
		keys.erase("none")
		enchant = keys[rng.randi_range(0, keys.size() - 1)]
	var pool: Array = AFFIXES.keys()
	var affixes := {}
	var growth := (1.0 + 0.12 * lv) * float(RARITY_POWER[rarity])
	for i in int(RARITY_AFFIXES[rarity]):
		var k: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		affixes[k] = snappedf(float(AFFIXES[k].v) * growth * rng.randf_range(0.85, 1.15), 0.001)
	var w := {"class": class_id, "base": base, "material": mat, "enchant": enchant, "rarity": rarity, "level": level, "affixes": affixes}
	w["name"] = weapon_name(w)
	return w


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


static func material_name(w: Dictionary) -> String:
	var m: Dictionary = MATERIALS[clampi(int(w.material), 0, MATERIALS.size() - 1)]
	return str(m.wood if str(w.base) in WOODEN else m.metal)


static func weapon_name(w: Dictionary) -> String:
	var parts := []
	var adj := str(ENCHANTS.get(w.enchant, ENCHANTS["none"]).adj)
	if adj != "":
		parts.append(adj)
	parts.append(material_name(w))
	parts.append(str(BASES[w["class"]][w.base].name))
	var nm := " ".join(parts)
	var affixes: Dictionary = w.get("affixes", {})
	if not affixes.is_empty():
		nm += " " + str(AFFIXES[affixes.keys()[0]].suffix)
	var beyond := int(w.get("level", 0)) - (MATERIALS.size() - 1)
	if beyond > 0 and int(w.material) == MATERIALS.size() - 1:
		nm += " +%d" % beyond
	return nm


static func mods(w: Dictionary) -> Dictionary:
	## Every bonus the weapon grants, merged (base + material + enchantment + properties).
	var out := {}
	var base_mods: Dictionary = BASES[w["class"]][w.base].mods
	for k in base_mods:
		out[k] = float(out.get(k, 0.0)) + float(base_mods[k])
	var mat_dmg := float(MATERIALS[clampi(int(w.material), 0, MATERIALS.size() - 1)].dmg)
	# beyond the last material, every forge keeps adding power: the vigil is endless
	mat_dmg += 0.08 * maxf(float(w.get("level", 0)) - float(MATERIALS.size() - 1), 0.0)
	out["damage"] = float(out.get("damage", 0.0)) + mat_dmg
	var ench: Dictionary = ENCHANTS.get(w.enchant, {})
	var em: Dictionary = ench.get("mods", {})
	for k in em:
		out[k] = float(out.get(k, 0.0)) + float(em[k])
	var af: Dictionary = w.get("affixes", {})
	for k in af:
		out[k] = float(out.get(k, 0.0)) + float(af[k])
	return out


static func describe(w: Dictionary) -> Array:
	## Lines for the forge cards and tooltips.
	var lines := []
	var b: Dictionary = BASES[w["class"]][w.base]
	lines.append("%s  -  %s" % [str(b.name), str(b.desc)])
	# the enchantment is described by its own sentence: leave its bonus out of the numbers
	var m := mods(w)
	var em: Dictionary = ENCHANTS.get(w.enchant, {}).get("mods", {})
	for k in em:
		m[k] = float(m.get(k, 0.0)) - float(em[k])
	for k in ["damage", "attack_speed", "crit", "crit_mult", "lifesteal", "cooldown", "resource_regen", "execute", "armor", "speed", "splash", "cleave_range", "pierce", "holy", "spin_bonus"]:
		if not m.has(k) or absf(float(m[k])) < 0.001:
			continue
		var v := float(m[k])
		var amount: String
		match k:
			"cleave_range":
				amount = str(snappedf(v, 0.1))
			"pierce":
				amount = str(int(v))
			_:
				amount = "%d%%" % int(round(absf(v) * 100.0))
		if k == "spin_bonus":
			lines.append(MOD_TEXT[k])
			continue
		var t: String = MOD_TEXT[k] % amount
		if k != "cooldown" and k != "cleave_range" and k != "pierce":
			t = ("+" if v >= 0.0 else "-") + t
		lines.append(t)
	var et := str(ENCHANTS.get(w.enchant, {}).get("text", ""))
	if et != "":
		lines.append(et)
	return lines


const ENCHANT_SHORT := {"flame": "Burns foes", "frost": "Slows foes", "venom": "Poisons foes", "storm": "Chain lightning", "shadow": "Drains life", "holy": "Bane of bosses"}
const EXTRA_SHORT := {"crit": "crit", "crit_mult": "crit damage", "lifesteal": "lifesteal", "cooldown": "cooldowns", "resource_regen": "resource",
	"execute": "vs wounded", "armor": "armour", "speed": "move speed", "splash": "blast size", "holy": "vs bosses"}


static func summary(w: Dictionary) -> Dictionary:
	## The few numbers that matter, for a quick choice: damage, speed, enchantment, one extra line.
	var m := mods(w)
	var em: Dictionary = ENCHANTS.get(w.enchant, {}).get("mods", {})
	for k in em:
		m[k] = float(m.get(k, 0.0)) - float(em[k])
	var extras := []
	# the weapon's own properties first (they give it its name), then what its base type adds
	var order: Array = w.get("affixes", {}).keys()
	for k in ["crit", "crit_mult", "lifesteal", "execute", "cooldown", "armor", "speed", "resource_regen", "splash"]:
		if not k in order:
			order.append(k)
	for k in order:
		if not EXTRA_SHORT.has(k):
			continue
		if absf(float(m.get(k, 0.0))) >= 0.005:
			extras.append("%s%d%% %s" % ["+" if k != "cooldown" else "-", int(round(absf(float(m[k])) * 100.0)), EXTRA_SHORT[k]])
	if float(m.get("pierce", 0.0)) > 0.0:
		extras.append("+%d pierce" % int(m.pierce))
	return {"damage": float(m.get("damage", 0.0)), "speed": float(m.get("attack_speed", 0.0)),
		"enchant": str(ENCHANT_SHORT.get(w.enchant, "")), "extras": extras.slice(0, 2)}


static func tint(w: Dictionary) -> Color:
	return MATERIALS[clampi(int(w.material), 0, MATERIALS.size() - 1)].tint


static func glow(w: Dictionary) -> Color:
	return ENCHANTS.get(w.enchant, ENCHANTS["none"]).glow


static func glow_power(w: Dictionary) -> float:
	return 0.15 if str(w.enchant) == "none" else 0.85


static func element(w: Dictionary) -> String:
	return str(ENCHANTS.get(w.enchant, {}).get("element", ""))


static func element_power(w: Dictionary) -> float:
	return float(ENCHANTS.get(w.enchant, {}).get("power", 0.0))


static func sheet(w: Dictionary) -> String:
	var p: String = SHEET_DIR + str(w.base) + ".png"
	return p if ResourceLoader.exists(p) else str(FALLBACK_SHEET.get(w.base, FALLBACK_SHEET["axe"]))


static func mask(w: Dictionary) -> String:
	var p: String = SHEET_DIR + str(w.base) + "_mask.png"
	return p if ResourceLoader.exists(p) else ""


static func from_tier(class_id: String, tier: int) -> Dictionary:
	## Old saves stored a weapon tier: turn it into an equivalent forged weapon.
	var w := starter(class_id)
	w.material = clampi(tier * 2, 0, MATERIALS.size() - 1)
	w.level = tier
	w.name = weapon_name(w)
	return w
