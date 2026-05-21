extends RefCounted
class_name UnitDefs

# Canonical unit stat definitions and wave templates.
# game.gd references these via local const aliases at the top of the file.

const UNIT_DEFS := {
	# ── Player / Militia ──────────────────────────────────────────────────────
	"militia":   {"name":"MILITIA",    "cost":75,  "hp":65,  "speed":2.3, "range":7.0,  "dmg_min":12,"dmg_max":26, "fire_rate":1.1,  "desc":"Civilian defender. Weak alone, deadly en masse.",      "ability":"BARRICADE"},
	"grenadier": {"name":"GRENADIER",  "cost":130, "hp":80,  "speed":2.1, "range":9.0,  "dmg_min":35,"dmg_max":60, "fire_rate":0.55, "desc":"Explosive specialist. Area suppression.",               "ability":"GRENADE"},
	"sniper":    {"name":"SNIPER",     "cost":200, "hp":65,  "speed":1.85,"range":22.0, "dmg_min":70,"dmg_max":100,"fire_rate":0.3,  "desc":"One shot, one kill. Long range.",                       "ability":"OVERWATCH"},
	"mg_team":   {"name":"MG TEAM",   "cost":195, "hp":90,  "speed":1.4, "range":14.0, "dmg_min":20,"dmg_max":40, "fire_rate":1.1,  "desc":"Sustained fire. Suppresses enemies.",                   "ability":"SUPR.FIRE"},
	"medic":     {"name":"MEDIC",     "cost":150, "hp":55,  "speed":2.6, "range":5.0,  "dmg_min":4, "dmg_max":10, "fire_rate":0.8,  "desc":"Auto-heals injured friendlies within 3.5 units.",        "ability":"STIMPACK"},
	# ── Enemy / Military — same archetypes, stronger stats ───────────────────
	"soldier":   {"name":"SOLDIER",    "cost":0,   "hp":90,  "speed":2.5, "range":9.0,  "dmg_min":18,"dmg_max":32, "fire_rate":1.0,  "desc":""},
	"e_gren":    {"name":"E.GRENADIER","cost":0,   "hp":90,  "speed":2.1, "range":11.0, "dmg_min":40,"dmg_max":65, "fire_rate":0.5,  "desc":""},
	"e_sniper":  {"name":"E.SNIPER",   "cost":0,   "hp":65,  "speed":1.75,"range":24.0, "dmg_min":75,"dmg_max":105,"fire_rate":0.28, "desc":""},
	"e_mg":      {"name":"E.MG TEAM", "cost":0,   "hp":95,  "speed":1.55,"range":16.0, "dmg_min":22,"dmg_max":42, "fire_rate":1.1,  "desc":""},
}

const WAVE_DEFS := [
	["soldier","soldier","soldier","soldier","soldier"],
	["soldier","soldier","soldier","e_gren","soldier","soldier"],
	["soldier","e_gren","soldier","e_sniper","soldier","soldier","e_mg"],
	["soldier","e_gren","e_sniper","e_mg","soldier","soldier","e_gren","soldier"],
	["e_mg","e_gren","e_sniper","soldier","soldier","e_gren","e_mg","soldier","e_sniper","soldier"],
]

# Capture point spawn locations in world XZ (relative to map centre)
const CP_DEFS := [Vector2(0.0,-6.0), Vector2(-9.0,4.0), Vector2(9.0,1.0)]
