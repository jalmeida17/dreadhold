extends RefCounted
## Weapon tiers per class. A champion starts with tier 0 and claims the next weapon each
## time a boss falls (every 5 nights). "bonus" is added to player.mods when equipped.

const WEAPONS := {
	"warrior": [
		{"name": "Bearded Axe", "sheet": "res://assets/weapons/axe.png", "bonus": {}, "desc": "A battered war axe from the keep's armoury."},
		{"name": "Reaver Greataxe", "sheet": "res://assets/weapons/axe_2.png", "bonus": {"damage": 0.25, "cleave_range": 0.3}, "desc": "+25% damage. Cleave reaches further."},
		{"name": "Doomcleaver", "sheet": "res://assets/weapons/axe_3.png", "bonus": {"damage": 0.3, "cleave_range": 0.3, "cleave_heal": 1.0}, "desc": "+30% damage. Cleave reaches further and drinks the blood of the dead."},
	],
	"mage": [
		{"name": "Ember Staff", "sheet": "res://assets/weapons/staff.png", "bonus": {}, "desc": "A gnarled staff holding a smouldering ember."},
		{"name": "Moonsilver Staff", "sheet": "res://assets/weapons/staff_2.png", "bonus": {"damage": 0.25, "resource_regen": 0.25}, "desc": "+25% damage. Mana flows faster."},
		{"name": "Staff of the Burning Eye", "sheet": "res://assets/weapons/staff_3.png", "bonus": {"damage": 0.3, "splash": 0.35}, "desc": "+30% damage. Fireballs explode wider."},
	],
	"hunter": [
		{"name": "Yew Longbow", "sheet": "res://assets/weapons/bow.png", "bonus": {}, "desc": "A plain, honest yew bow."},
		{"name": "Hornbow of the Wilds", "sheet": "res://assets/weapons/bow_2.png", "bonus": {"damage": 0.25, "attack_speed": 0.12}, "desc": "+25% damage. Shoots faster."},
		{"name": "Wyrmbone Greatbow", "sheet": "res://assets/weapons/bow_3.png", "bonus": {"damage": 0.3, "pierce": 1.0}, "desc": "+30% damage. Arrows pierce one more foe."},
	],
}
