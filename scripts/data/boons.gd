extends RefCounted
## Boons offered between waves. "mods" are added to player.mods; "special" keys are
## handled in player.apply_boon(). "class" limits a boon to one class.

const RARITY_WEIGHT := {"common": 60, "rare": 30, "epic": 10, "legendary": 3}
const RARITY_COLOR := {
	"common": Color(0.85, 0.85, 0.85),
	"rare": Color(0.35, 0.6, 1.0),
	"epic": Color(0.75, 0.4, 1.0),
	"legendary": Color(1.0, 0.6, 0.15),
}

const BOONS := {
	"whetstone": {"name": "Whetstone", "rarity": "common", "icon": "damage", "max": 6,
		"desc": "+15% damage.", "mods": {"damage": 0.15}},
	"vigor": {"name": "Vigor", "rarity": "common", "icon": "health", "max": 8,
		"desc": "+25 max health and heal 25.", "special": {"max_hp": 25.0}},
	"fleetfoot": {"name": "Fleetfoot", "rarity": "common", "icon": "speed", "max": 4,
		"desc": "+8% movement speed.", "mods": {"speed": 0.08}},
	"keen_eye": {"name": "Keen Eye", "rarity": "common", "icon": "crit", "max": 5,
		"desc": "+7% critical strike chance.", "mods": {"crit": 0.07}},
	"bulwark": {"name": "Bulwark", "rarity": "common", "icon": "armor", "max": 5,
		"desc": "+6% damage reduction.", "mods": {"armor": 0.06}},
	"deep_reserves": {"name": "Deep Reserves", "rarity": "common", "icon": "resource", "max": 4,
		"desc": "+20 max resource, +20% resource regeneration.", "mods": {"resource_max": 20.0, "resource_regen": 0.2}},
	"greed": {"name": "Greed", "rarity": "common", "icon": "gold", "max": 3,
		"desc": "+35% gold from fallen foes.", "mods": {"gold": 0.35}},
	"quickening": {"name": "Quickening", "rarity": "rare", "icon": "cooldown", "max": 4,
		"desc": "Abilities recharge 12% faster.", "mods": {"cooldown": -0.12}},
	"ironblood": {"name": "Ironblood", "rarity": "rare", "icon": "regen", "max": 4,
		"desc": "Regenerate 1.5 health per second.", "mods": {"regen": 1.5}},
	"vampiric": {"name": "Vampiric Edge", "rarity": "rare", "icon": "lifesteal", "max": 4,
		"desc": "Heal for 4% of damage dealt.", "mods": {"lifesteal": 0.04}},
	"frenzy": {"name": "Frenzy", "rarity": "rare", "icon": "speed", "max": 4,
		"desc": "Attack 12% faster.", "mods": {"attack_speed": 0.12}},
	"thorns": {"name": "Barbed Hide", "rarity": "rare", "icon": "armor", "max": 3,
		"desc": "Reflect 40% of melee damage taken back to the attacker.", "mods": {"thorns": 0.4}},
	"second_wind": {"name": "Second Wind", "rarity": "rare", "icon": "potion", "max": 2,
		"desc": "+1 potion capacity and refill all potions.", "special": {"potion_cap": 1}},
	"executioner": {"name": "Executioner", "rarity": "epic", "icon": "skull", "max": 2,
		"desc": "+50% damage against foes below 35% health.", "mods": {"execute": 0.5}},
	"deadly": {"name": "Deadly Precision", "rarity": "epic", "icon": "crit", "max": 2,
		"desc": "Critical strikes deal +60% more damage.", "mods": {"crit_mult": 0.6}},
	"undying": {"name": "Undying Oath", "rarity": "legendary", "icon": "health", "max": 1,
		"desc": "Once per run, survive a killing blow with 40% health.", "special": {"undying": 1}},

	# --- warrior
	"wide_arc": {"name": "Wide Arc", "rarity": "rare", "icon": "cleave", "max": 3, "class": "warrior",
		"desc": "Cleave reaches 0.6 m further and sweeps wider.", "mods": {"cleave_range": 0.6}},
	"bloodlust": {"name": "Bloodlust", "rarity": "rare", "icon": "lifesteal", "max": 3, "class": "warrior",
		"desc": "Each enemy hit by Cleave heals you for 2.", "mods": {"cleave_heal": 2.0}},
	"tempest": {"name": "Tempest", "rarity": "epic", "icon": "spin", "max": 2, "class": "warrior",
		"desc": "Reaving Spin costs 10 less Rage and reaches 1 m further.", "mods": {"spin_bonus": 1.0}},
	"juggernaut": {"name": "Juggernaut", "rarity": "rare", "icon": "charge", "max": 2, "class": "warrior",
		"desc": "Iron Charge recharges 2 s faster and stuns longer.", "mods": {"charge_bonus": 1.0}},
	# --- mage
	"pyroclasm": {"name": "Pyroclasm", "rarity": "rare", "icon": "area", "max": 3, "class": "mage",
		"desc": "Fireball explosions are 40% larger.", "mods": {"splash": 0.4}},
	"twin_flames": {"name": "Twin Flames", "rarity": "epic", "icon": "fireball", "max": 2, "class": "mage",
		"desc": "Fireball launches an extra flame.", "mods": {"extra_fireball": 1.0}},
	"deep_freeze": {"name": "Deep Freeze", "rarity": "rare", "icon": "frostnova", "max": 3, "class": "mage",
		"desc": "Frost Nova reaches 1.5 m further and freezes longer.", "mods": {"nova_bonus": 1.0}},
	"arcane_flow": {"name": "Arcane Flow", "rarity": "common", "icon": "resource", "max": 3, "class": "mage",
		"desc": "+35% mana regeneration.", "mods": {"resource_regen": 0.35}},
	# --- hunter
	"piercing": {"name": "Piercing Shots", "rarity": "rare", "icon": "shot", "max": 3, "class": "hunter",
		"desc": "Arrows pierce through one more enemy.", "mods": {"pierce": 1.0}},
	"barrage": {"name": "Barrage", "rarity": "rare", "icon": "volley", "max": 3, "class": "hunter",
		"desc": "Volley fires 3 more arrows.", "mods": {"volley_extra": 3.0}},
	"predator": {"name": "Predator", "rarity": "epic", "icon": "crit", "max": 2, "class": "hunter",
		"desc": "+10% crit chance and +40% crit damage.", "mods": {"crit": 0.1, "crit_mult": 0.4}},
	"swift_quiver": {"name": "Swift Quiver", "rarity": "common", "icon": "dash", "max": 3, "class": "hunter",
		"desc": "Shoot 12% faster and Shadow Step recharges faster.", "mods": {"attack_speed": 0.12, "cooldown": -0.06}},
}


static func roll(class_id: String, owned: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	## Picks `count` distinct boon ids weighted by rarity, honouring class limits and max stacks.
	var pool: Array = []
	for id in BOONS:
		var b: Dictionary = BOONS[id]
		if b.has("class") and b["class"] != class_id:
			continue
		if int(owned.get(id, 0)) >= int(b.get("max", 99)):
			continue
		pool.append(id)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0
		for id in pool:
			total += int(RARITY_WEIGHT[BOONS[id]["rarity"]])
		var r := rng.randi_range(0, total - 1)
		for id in pool:
			r -= int(RARITY_WEIGHT[BOONS[id]["rarity"]])
			if r < 0:
				out.append(id)
				pool.erase(id)
				break
	return out
