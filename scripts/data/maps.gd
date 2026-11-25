extends RefCounted
## Playable maps (chosen before a run) and the boss rotation (one boss every 5 nights,
## each fought in its own arena).

const ORDER := ["keep", "crypt", "village", "cathedral"]

const MAPS := {
	"keep": {
		"name": "Blackstone Keep",
		"desc": "The fallen keep's courtyard under a stormy moon. Open ground, four gates and a haunted graveyard.",
		"difficulty": 1,
		"thumb": "res://assets/ui/maps/keep.png",
	},
	"crypt": {
		"name": "The Sunken Crypt",
		"desc": "A vaulted ossuary beneath the keep. Narrow halls, low ceilings and the dead pouring in from every tomb.",
		"difficulty": 3,
		"thumb": "res://assets/ui/maps/crypt.png",
	},
	"village": {
		"name": "Hollowmere",
		"desc": "A ruined village lost in the mist. Burned houses, crooked fences and lanes that hide the horde.",
		"difficulty": 2,
		"thumb": "res://assets/ui/maps/village.png",
	},
	"cathedral": {
		"name": "The Defiled Cathedral",
		"desc": "A dark vaulted nave split by a rood screen and walled chapels. Grave-fire burns on the defiled altar.",
		"difficulty": 2,
		"thumb": "res://assets/ui/maps/cathedral.png",
	},
}

## Bosses in the order they are met (nights 5, 10, 15, 20, then the cycle repeats stronger).
const BOSSES := [
	{"enemy": "boss", "arena": "boss_barrow", "arena_name": "THE BARROW THRONE", "arena_line": "There is no escape", "color": Color(0.5, 1.0, 0.55)},
	{"enemy": "boss_rot", "arena": "boss_pit", "arena_name": "THE ROTTING PIT", "arena_line": "The air itself is poison", "color": Color(0.8, 1.0, 0.35)},
	{"enemy": "boss_cinder", "arena": "boss_forge", "arena_name": "THE MOLTEN FORGE", "arena_line": "The ground burns beneath you", "color": Color(1.0, 0.55, 0.2)},
	{"enemy": "boss_rime", "arena": "boss_sanctum", "arena_name": "THE FROZEN SANCTUM", "arena_line": "Your breath turns to ice", "color": Color(0.55, 0.9, 1.0)},
]


static func boss_for_night(night: int) -> Dictionary:
	var idx := maxi(night / 5 - 1, 0) % BOSSES.size()
	return BOSSES[idx]
