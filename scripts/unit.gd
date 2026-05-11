extends Node3D
class_name Unit

enum State { HOLDING, MOVING, ATTACKING }

# --- Stats ---
var kind: String      = "militia"
var team: String      = "player"
var hp: int           = 60
var hp_max: int       = 60
var speed: float      = 4.0
var attack_range: float = 7.0
var dmg_min: int      = 10
var dmg_max: int      = 20
var fire_rate: float  = 1.0
var is_vehicle: bool  = false

# --- State ---
var state: State      = State.HOLDING
var target_pos: Vector3 = Vector3.ZERO
var fire_timer: float = 0.0
var path: Array       = []   # Array of Vector3
var path_idx: int     = 0
var suppression: float = 0.0
var selected: bool    = false
var attack_move: bool = false
var in_cover: bool    = false
var cover_seek_timer: float = 0.0
var heal_timer: float = 0.0
var ability_cooldown: float = 0.0
var overwatch: bool   = false
var suppressing: bool = false
var suppressing_timer: float = 0.0
var garrisoned: bool          = false
var garrison_tile: Vector2i   = Vector2i(-1, -1)
var garrison_pending: Vector2i = Vector2i(-1, -1)
var vet_kills: int            = 0

func setup(p_kind: String, p_team: String, def: Dictionary) -> void:
	kind         = p_kind
	team         = p_team
	hp           = int(def.hp)
	hp_max       = int(def.hp)
	speed        = float(def.speed)
	attack_range = float(def.range)
	dmg_min      = int(def.dmg_min)
	dmg_max      = int(def.dmg_max)
	fire_rate    = float(def.fire_rate)
	is_vehicle   = bool(def.get("is_vehicle", false))
	_refresh_hp_bar()

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	suppression = min(1.0, suppression + 0.25)
	_refresh_hp_bar()

func set_selected(v: bool) -> void:
	selected = v
	var ring := get_node_or_null("SelRing")
	if ring:
		ring.visible = v

func issue_move(dest: Vector3) -> void:
	target_pos = dest
	path = [dest]
	path_idx = 0
	state = State.MOVING

func _process(delta: float) -> void:
	suppression       = max(0.0, suppression       - delta * 0.25)
	fire_timer        = max(0.0, fire_timer        - delta)
	heal_timer        = max(0.0, heal_timer        - delta)
	cover_seek_timer  = max(0.0, cover_seek_timer  - delta)
	ability_cooldown  = max(0.0, ability_cooldown  - delta)
	if suppressing_timer > 0.0:
		suppressing_timer = max(0.0, suppressing_timer - delta)
		if suppressing_timer <= 0.0:
			suppressing = false
	_refresh_hp_bar()

func _refresh_hp_bar() -> void:
	var bar := get_node_or_null("HPBar") as MeshInstance3D
	if bar == null:
		return
	var ratio := float(hp) / float(hp_max)
	bar.scale.x = max(0.01, ratio)
	bar.position.x = (ratio - 1.0) * 0.36
	var mat := bar.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		if ratio > 0.6:
			mat.albedo_color = Color(0.2, 0.9, 0.2)
		elif ratio > 0.3:
			mat.albedo_color = Color(0.9, 0.75, 0.1)
		else:
			mat.albedo_color = Color(0.95, 0.15, 0.1)
