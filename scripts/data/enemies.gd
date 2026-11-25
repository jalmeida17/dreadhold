extends RefCounted
## Enemy archetypes. "height" is the world height in metres of one full sprite frame
## (the sprite's pixel size is derived from it, whatever the sheet resolution).

const FRAME_WALK_A := 0
const FRAME_WALK_B := 1
const FRAME_WINDUP := 2
const FRAME_STRIKE := 3
const FRAME_PAIN := 4
const FRAME_DIE_A := 5
const FRAME_DIE_B := 6
const FRAME_CORPSE := 7
const FRAME_CAST := 8

const TYPES := {
	"ghoul": {
		"name": "Ghoul", "sheet": "res://assets/sprites/enemies/ghoul.png", "frames": 8, "height": 2.05,
		"hp": 42.0, "speed": 6.0, "damage": 9.0, "range": 1.7, "atk_cd": 0.85, "windup": 0.28,
		"radius": 0.42, "body_h": 1.5, "pain": 0.7, "cost": 1, "score": 10, "gold": [3, 6],
		"gib": "blood", "alert": "ghoul_alert", "attack_sfx": "ghoul_attack", "death": "ghoul_death", "hit": "hit_flesh",
	},
	"skeleton": {
		"name": "Risen Skeleton", "sheet": "res://assets/sprites/enemies/skeleton.png", "frames": 8, "height": 2.05,
		"hp": 70.0, "speed": 3.9, "damage": 13.0, "range": 1.9, "atk_cd": 1.3, "windup": 0.45,
		"radius": 0.45, "body_h": 1.8, "pain": 0.45, "cost": 2, "score": 15, "gold": [5, 9],
		"gib": "dust", "alert": "skeleton_alert", "attack_sfx": "swing", "death": "skeleton_death", "hit": "hit_bone",
	},
	"archer": {
		"name": "Bone Archer", "sheet": "res://assets/sprites/enemies/archer.png", "frames": 8, "height": 2.05,
		"hp": 48.0, "speed": 3.4, "damage": 10.0, "range": 26.0, "atk_cd": 2.3, "windup": 0.65,
		"radius": 0.42, "body_h": 1.8, "pain": 0.6, "cost": 2, "score": 15, "gold": [5, 9],
		"ranged": true, "projectile": "arrow", "proj_speed": 26.0, "keep_min": 7.0,
		"gib": "dust", "alert": "skeleton_alert", "attack_sfx": "enemy_arrow", "death": "skeleton_death", "hit": "hit_bone",
	},
	"cultist": {
		"name": "Shadow Acolyte", "sheet": "res://assets/sprites/enemies/cultist.png", "frames": 8, "height": 2.05,
		"hp": 60.0, "speed": 3.2, "damage": 15.0, "range": 24.0, "atk_cd": 2.7, "windup": 0.75,
		"radius": 0.45, "body_h": 1.8, "pain": 0.5, "cost": 3, "score": 25, "gold": [8, 13],
		"ranged": true, "projectile": "shadow", "proj_speed": 13.0, "homing": 1.4, "keep_min": 8.0,
		"gib": "blood", "alert": "cultist_cast", "attack_sfx": "shadow_bolt", "death": "cultist_death", "hit": "hit_flesh",
	},
	"brute": {
		"name": "Barrow Brute", "sheet": "res://assets/sprites/enemies/brute.png", "frames": 8, "height": 3.1,
		"hp": 340.0, "speed": 2.9, "damage": 30.0, "range": 2.9, "atk_cd": 2.2, "windup": 0.85,
		"radius": 0.8, "body_h": 2.7, "pain": 0.15, "cost": 8, "score": 80, "gold": [25, 40],
		"smash": 3.4, "knockback": 9.0,
		"gib": "blood", "alert": "brute_roar", "attack_sfx": "brute_smash", "death": "brute_death", "hit": "hit_flesh",
	},
	"boss": {
		"name": "The Hollow King", "sheet": "res://assets/sprites/enemies/boss.png", "frames": 9, "height": 4.3,
		"hp": 2600.0, "speed": 3.3, "damage": 34.0, "range": 3.7, "atk_cd": 1.9, "windup": 0.7,
		"radius": 0.75, "body_h": 3.8, "pain": 0.0, "cost": 0, "score": 1000, "gold": [150, 220],
		"smash": 4.0, "knockback": 10.0, "boss": true,
		"gib": "dust", "alert": "boss_roar", "attack_sfx": "spin", "death": "boss_death", "hit": "hit_bone",
		"title": "Lord of the Barrow", "portrait": "res://assets/ui/portrait_boss.png", "color": Color(0.65, 1.0, 0.6),
		"casts": ["summon", "volley"], "proj": "soul", "summon": ["skeleton", "ghoul"],
	},
	"boss_rot": {
		"name": "Mother of Rot", "sheet": "res://assets/sprites/enemies/boss_rot.png", "frames": 9, "height": 4.2,
		"hp": 3000.0, "speed": 2.6, "damage": 30.0, "range": 3.4, "atk_cd": 2.2, "windup": 0.8,
		"radius": 0.85, "body_h": 3.6, "pain": 0.0, "cost": 0, "score": 1200, "gold": [170, 240],
		"smash": 4.0, "knockback": 8.0, "boss": true, "tint": Color(0.75, 1.0, 0.45),
		"gib": "blood", "alert": "brute_roar", "attack_sfx": "brute_smash", "death": "brute_death", "hit": "hit_flesh",
		"title": "Matron of the Plague Pits", "portrait": "res://assets/ui/portrait_boss_rot.png", "color": Color(0.8, 1.0, 0.35),
		"casts": ["rain", "summon", "volley"], "proj": "acid", "summon": ["ghoul", "ghoul", "ghoul"],
	},
	"boss_cinder": {
		"name": "The Cinder Tyrant", "sheet": "res://assets/sprites/enemies/boss_cinder.png", "frames": 9, "height": 4.5,
		"hp": 3300.0, "speed": 3.0, "damage": 38.0, "range": 3.8, "atk_cd": 2.0, "windup": 0.75,
		"radius": 0.85, "body_h": 4.0, "pain": 0.0, "cost": 0, "score": 1400, "gold": [190, 260],
		"smash": 4.5, "knockback": 11.0, "boss": true, "tint": Color(1.3, 0.6, 0.4),
		"gib": "dust", "alert": "boss_roar", "attack_sfx": "brute_smash", "death": "boss_death", "hit": "hit_metal",
		"title": "Lord of the Molten Forge", "portrait": "res://assets/ui/portrait_boss_cinder.png", "color": Color(1.0, 0.6, 0.25),
		"casts": ["meteor", "nova", "volley"], "proj": "ember", "summon": ["brute"],
	},
	"boss_rime": {
		"name": "Lady Rime", "sheet": "res://assets/sprites/enemies/boss_rime.png", "frames": 9, "height": 4.3,
		"hp": 2800.0, "speed": 3.6, "damage": 32.0, "range": 3.4, "atk_cd": 1.8, "windup": 0.6,
		"radius": 0.75, "body_h": 3.8, "pain": 0.0, "cost": 0, "score": 1600, "gold": [210, 280],
		"smash": 3.6, "knockback": 8.0, "boss": true, "tint": Color(0.6, 0.85, 1.3),
		"gib": "dust", "alert": "cultist_cast", "attack_sfx": "frost_nova", "death": "boss_death", "hit": "hit_bone",
		"title": "Queen of the Frozen Sanctum", "portrait": "res://assets/ui/portrait_boss_rime.png", "color": Color(0.6, 0.9, 1.0),
		"casts": ["blink", "volley", "frost_nova", "summon"], "proj": "ice", "summon": ["archer", "archer"],
	},
}


static func get_type(id: String) -> Dictionary:
	return TYPES[id]
