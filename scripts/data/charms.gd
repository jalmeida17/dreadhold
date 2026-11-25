extends RefCounted
## Charms: trinkets generated for Grizzle's black market, so it never runs dry.
## A charm rolls 1 to 4 bonuses (by rarity) from STATS; rarer charms appear and every value
## grows as the nights go by. Bonuses add up with the abilities (player.mods).

const BASES := ["Amulet", "Ring", "Talisman", "Sigil", "Idol", "Phylactery", "Fetish", "Locket", "Rune", "Brooch", "Charm", "Relic"]

## v: value of one roll at night 1 (common). pct: shown as a percentage.
const STATS := {
	"damage": {"v": 0.06, "pct": true, "text": "%s damage", "icon": "damage", "prefix": "Brutal", "suffix": "of Ruin"},
	"attack_speed": {"v": 0.05, "pct": true, "text": "%s attack speed", "icon": "speed", "prefix": "Hasted", "suffix": "of the Gale"},
	"crit": {"v": 0.03, "pct": true, "text": "%s critical strike chance", "icon": "crit", "prefix": "Keen", "suffix": "of the Hawk"},
	"crit_mult": {"v": 0.15, "pct": true, "text": "%s critical strike damage", "icon": "crit", "prefix": "Deadly", "suffix": "of Slaughter"},
	"armor": {"v": 0.025, "pct": true, "text": "%s damage reduction", "icon": "armor", "prefix": "Warded", "suffix": "of the Bear"},
	"speed": {"v": 0.03, "pct": true, "text": "%s movement speed", "icon": "speed", "prefix": "Fleet", "suffix": "of the Hare"},
	"regen": {"v": 0.6, "pct": false, "text": "%s health per second", "icon": "regen", "prefix": "Mending", "suffix": "of the Troll"},
	"lifesteal": {"v": 0.015, "pct": true, "text": "%s of damage dealt healed", "icon": "lifesteal", "prefix": "Vampiric", "suffix": "of the Leech"},
	"cooldown": {"v": -0.04, "pct": true, "text": "abilities recharge %s faster", "icon": "cooldown", "prefix": "Arcane", "suffix": "of Haste"},
	"resource_regen": {"v": 0.08, "pct": true, "text": "%s resource regeneration", "icon": "resource", "prefix": "Brimming", "suffix": "of the Wellspring"},
	"gold": {"v": 0.08, "pct": true, "text": "%s gold from fallen foes", "icon": "gold", "prefix": "Greedy", "suffix": "of Avarice"},
	"execute": {"v": 0.08, "pct": true, "text": "%s damage to foes below 35%% health", "icon": "skull", "prefix": "Merciless", "suffix": "of the Headsman"},
	"thorns": {"v": 0.08, "pct": true, "text": "%s of melee damage reflected", "icon": "armor", "prefix": "Barbed", "suffix": "of Thorns"},
	"max_hp": {"v": 12.0, "pct": false, "text": "%s max health", "icon": "health", "prefix": "Hale", "suffix": "of Vigor"},
}
const ROLLS := {"common": 1, "rare": 2, "epic": 3, "legendary": 4}
const POWER := {"common": 1.0, "rare": 1.15, "epic": 1.3, "legendary": 1.5}
const PRICES := {"common": 70, "rare": 130, "epic": 210, "legendary": 340}
## Hard ceilings, so endless stacking never breaks the game.
const CAPS := {"speed": 1.8, "lifesteal": 0.3, "thorns": 2.0, "armor": 0.75}


static func roll(night: int, rng: RandomNumberGenerator) -> Dictionary:
	var n := float(maxi(night, 1))
	var weights := {"common": 60.0, "rare": 22.0 + n, "epic": 5.0 + n * 0.8, "legendary": 1.0 + n * 0.35}
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	var rarity := "common"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			rarity = k
			break
	var keys: Array = STATS.keys()
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = keys[i]
		keys[i] = keys[j]
		keys[j] = t
	var picked: Array = keys.slice(0, int(ROLLS[rarity]))
	var growth := 1.0 + 0.06 * (n - 1.0)
	var mods := {}
	for k in picked:
		var v: float = float(STATS[k].v) * growth * float(POWER[rarity]) * rng.randf_range(0.85, 1.15)
		if k == "max_hp":
			v = roundf(v)
		mods[k] = snappedf(v, 0.001) if bool(STATS[k].pct) else snappedf(v, 0.1)
	var first: Dictionary = STATS[picked[0]]
	var cname := "%s %s" % [first.prefix, BASES[rng.randi_range(0, BASES.size() - 1)]]
	if picked.size() > 1:
		cname += " " + str(STATS[picked[1]].suffix)
	return {"name": cname, "rarity": rarity, "icon": str(first.icon), "mods": mods}


static func line(key: String, v: float) -> String:
	var s: Dictionary = STATS.get(key, {})
	if s.is_empty():
		return ""
	var amount := ("%d%%" % int(round(absf(v) * 100.0))) if bool(s.pct) else (str(int(absf(v))) if key == "max_hp" else str(snappedf(absf(v), 0.1)))
	if key != "cooldown":
		amount = "+" + amount
	return str(s.text) % amount


static func describe(c: Dictionary) -> String:
	var lines := []
	var mods: Dictionary = c.get("mods", {})
	for k in mods:
		lines.append(line(str(k), float(mods[k])))
	return "\n".join(lines)
