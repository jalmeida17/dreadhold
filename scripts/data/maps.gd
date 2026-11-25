extends RefCounted
## Playable maps (chosen before a run) and the boss rotation (one boss every 5 nights,
## each fought in its own arena).

const ORDER := ["keep", "crypt", "village", "cathedral", "forged"]
const ArenaForge := preload("res://scripts/world/arena_forge.gd")

const MAPS := {
	"keep": {
		"name": "Blackstone Keep",
		"desc": "The fallen keep's courtyard under a stormy moon. Open ground, four gates and a haunted graveyard.",
		"difficulty": 1,
		"thumb": "res://assets/ui/maps/keep.png",
		"ambience": "amb_keep",
	},
	"crypt": {
		"name": "The Sunken Crypt",
		"desc": "A vaulted ossuary beneath the keep. Narrow halls, low ceilings and the dead pouring in from every tomb.",
		"difficulty": 3,
		"thumb": "res://assets/ui/maps/crypt.png",
		"ambience": "amb_crypt",
	},
	"village": {
		"name": "Hollowmere",
		"desc": "A ruined village lost in the mist. Burned houses, crooked fences and lanes that hide the horde.",
		"difficulty": 2,
		"thumb": "res://assets/ui/maps/village.png",
		"ambience": "amb_village",
	},
	"cathedral": {
		"name": "The Defiled Cathedral",
		"desc": "A dark vaulted nave split by a rood screen and walled chapels. Grave-fire burns on the defiled altar.",
		"difficulty": 2,
		"thumb": "res://assets/ui/maps/cathedral.png",
		"ambience": "amb_cathedral",
	},
	"forged": {
		"name": "Uncharted Lands",
		"desc": "A battlefield forged anew for every vigil: ruins, ossuaries, foundries, glaciers, mires or temples, never the same twice.",
		"difficulty": 2,
		"thumb": "",
		"ambience": "amb_keep",
	},
}

## Bosses in the order they are met (nights 5, 10, 15, 20, then the cycle repeats stronger).
const BOSSES := [
	{"enemy": "boss", "arena": "boss_barrow", "arena_name": "THE BARROW THRONE", "arena_line": "There is no escape", "color": Color(0.5, 1.0, 0.55), "music": "music_boss_hollow"},
	{"enemy": "boss_rot", "arena": "boss_pit", "arena_name": "THE ROTTING PIT", "arena_line": "The air itself is poison", "color": Color(0.8, 1.0, 0.35), "music": "music_boss_rot"},
	{"enemy": "boss_cinder", "arena": "boss_forge", "arena_name": "THE MOLTEN FORGE", "arena_line": "The ground burns beneath you", "color": Color(1.0, 0.55, 0.2), "music": "music_boss_cinder"},
	{"enemy": "boss_rime", "arena": "boss_sanctum", "arena_name": "THE FROZEN SANCTUM", "arena_line": "Your breath turns to ice", "color": Color(0.55, 0.9, 1.0), "music": "music_boss_rime"},
]


## Night music gets heavier every 5 nights: nights 1-4, 6-9, 11-14, then 16 and beyond.
static func night_music(night: int) -> String:
	return "music_night_%d" % (clampi((maxi(night, 1) - 1) / 5, 0, 3) + 1)


static func ambience(map_id: String) -> String:
	if map_id.begins_with("forged:"):
		return str(ArenaForge.info(map_id).ambience)
	return str(MAPS.get(map_id, {}).get("ambience", "amb_keep"))


static func map_name(map_id: String) -> String:
	if map_id.begins_with("forged:"):
		return str(ArenaForge.info(map_id).name)
	return str(MAPS.get(map_id, {}).get("name", "?"))


static func resolve(map_id: String, rng_seed: int) -> String:
	## "forged" (Uncharted Lands) becomes a concrete forged battlefield for this vigil.
	return "forged:%d" % (absi(rng_seed) % 1000000000) if map_id == "forged" else map_id


static func boss_for_night(night: int, run_seed: int = 0) -> Dictionary:
	## The four legends first (nights 5 to 20), then a forged boss every five nights.
	var idx := maxi(night / 5 - 1, 0)
	if idx < BOSSES.size():
		return BOSSES[idx]
	var s := absi(hash([run_seed, night]))
	return load("res://scripts/data/bestiary.gd").boss_entry(s, night)
