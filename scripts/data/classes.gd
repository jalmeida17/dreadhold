extends RefCounted
## Playable classes. Abilities are implemented in scripts/player/kits/<id>_kit.gd.

const ORDER := ["warrior", "mage", "hunter"]

const CLASSES := {
	"warrior": {
		"role": "Melee  -  Heavy armor",
		"difficulty": 1,
		"name": "Warrior",
		"title": "Oathbound Warrior",
		"lore": "A sworn shield of the fallen keep. Wades into the horde and feeds on the fury of battle.",
		"max_hp": 170.0,
		"armor": 0.2,
		"speed": 7.6,
		"resource": "Rage",
		"resource_bar": "rage",
		"resource_color": Color(0.9, 0.35, 0.1),
		"portrait": "res://assets/ui/portrait_warrior.png",
		"stats": {"Health": 5, "Power": 4, "Speed": 2, "Range": 1},
		"abilities": [
			{"id": "cleave", "name": "Cleave", "icon": "cleave", "input": "LMB", "desc": "Heavy axe swing hitting every foe in front of you."},
			{"id": "spin", "name": "Reaving Spin", "icon": "spin", "input": "RMB", "desc": "35 Rage. Whirl your axe, striking all enemies around you."},
			{"id": "charge", "name": "Iron Charge", "icon": "charge", "input": "UTIL", "desc": "Rush forward, trampling and stunning foes in your path."},
		],
	},
	"mage": {
		"role": "Ranged  -  Glass cannon",
		"difficulty": 3,
		"name": "Mage",
		"title": "Emberbound Mage",
		"lore": "Last scholar of the burning tower. Fragile, but commands fire and frost.",
		"max_hp": 100.0,
		"armor": 0.0,
		"speed": 7.8,
		"resource": "Mana",
		"resource_bar": "mana",
		"resource_color": Color(0.25, 0.5, 1.0),
		"portrait": "res://assets/ui/portrait_mage.png",
		"stats": {"Health": 2, "Power": 5, "Speed": 3, "Range": 4},
		"abilities": [
			{"id": "fireball", "name": "Fireball", "icon": "fireball", "input": "LMB", "desc": "6 Mana. Hurl an exploding ball of fire."},
			{"id": "frostnova", "name": "Frost Nova", "icon": "frostnova", "input": "RMB", "desc": "35 Mana. Freeze and damage every nearby enemy."},
			{"id": "blink", "name": "Blink", "icon": "blink", "input": "UTIL", "desc": "Teleport a short distance forward."},
		],
	},
	"hunter": {
		"role": "Ranged  -  Swift, precise",
		"difficulty": 2,
		"name": "Hunter",
		"title": "Wildwood Hunter",
		"lore": "A ranger of the dead forests. Swift, precise and deadly at range.",
		"max_hp": 120.0,
		"armor": 0.08,
		"speed": 8.6,
		"resource": "Focus",
		"resource_bar": "focus",
		"resource_color": Color(0.85, 0.8, 0.2),
		"portrait": "res://assets/ui/portrait_hunter.png",
		"stats": {"Health": 3, "Power": 3, "Speed": 5, "Range": 5},
		"abilities": [
			{"id": "shot", "name": "Arrow Shot", "icon": "shot", "input": "LMB", "desc": "Fire a swift arrow. High critical chance."},
			{"id": "volley", "name": "Volley", "icon": "volley", "input": "RMB", "desc": "40 Focus. Loose a fan of seven arrows."},
			{"id": "dash", "name": "Shadow Step", "icon": "dash", "input": "UTIL", "desc": "Dash quickly in the direction you are moving."},
		],
	},
}
