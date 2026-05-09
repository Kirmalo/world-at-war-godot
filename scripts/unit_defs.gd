extends RefCounted
class_name UnitDefs

const DEFS := {
	"assault":   {"name":"ASSAULT",   "cost":100,"hp":100,"speed":4.5,"range":8.0, "dmg_min":20,"dmg_max":35,"fire_rate":1.2,"is_vehicle":false},
	"mg":        {"name":"MG TEAM",   "cost":200,"hp":80, "speed":3.0,"range":12.0,"dmg_min":30,"dmg_max":50,"fire_rate":0.7,"is_vehicle":false},
	"sniper":    {"name":"SNIPER",    "cost":250,"hp":60, "speed":3.5,"range":18.0,"dmg_min":60,"dmg_max":90,"fire_rate":0.4,"is_vehicle":false},
	"engineer":  {"name":"ENGINEER",  "cost":150,"hp":90, "speed":4.0,"range":7.0, "dmg_min":15,"dmg_max":25,"fire_rate":1.0,"is_vehicle":false},
	"grenadier": {"name":"GRENADIER","cost":175,"hp":85, "speed":4.0,"range":10.0,"dmg_min":40,"dmg_max":65,"fire_rate":0.6,"is_vehicle":false},
	"jeep":      {"name":"JEEP",      "cost":300,"hp":60, "speed":9.0,"range":6.0, "dmg_min":15,"dmg_max":25,"fire_rate":1.8,"is_vehicle":true},
	"apc":       {"name":"APC",       "cost":500,"hp":200,"speed":5.0,"range":8.0, "dmg_min":25,"dmg_max":40,"fire_rate":1.0,"is_vehicle":true},
}
