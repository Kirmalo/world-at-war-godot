extends Node
# Autoloaded as "Campaign" in project.godot.
# Tracks all campaign state and persists it to user://campaign.json.

# ── PROLOGUE STATE ────────────────────────────────────────────────────────────
var in_campaign:       bool  = false  # true while playing the prologue
var prologue_done:     bool  = false  # true once mission 5 result is recorded
var current_mission:   int   = 0      # 0-4 while in prologue
var home_city_index:   int   = 0      # LOCATIONS index chosen by player
var home_city_name:    String = ""
var home_city_lat:     float = 0.0
var home_city_lon:     float = 0.0
var missions_complete: Array = []     # bool per mission (was it a win?)
# last result set by record_mission_result() — read by main.gd
var last_victory:      bool  = false

# ── WORLD THEATER STATE ───────────────────────────────────────────────────────
var world_theater_active: bool       = false
var world_stars:          Dictionary = {}   # city_index(int) -> int 0-3
var world_unlocked:       Array      = []   # bool per LOCATIONS index

const SAVE_PATH := "user://campaign.json"

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	missions_complete = [false, false, false, false, false]
	world_unlocked    = []
	world_unlocked.resize(CampaignData.LOCATIONS.size())
	world_unlocked.fill(false)
	_load_state()

# ── PROLOGUE CONTROL ──────────────────────────────────────────────────────────

func start_campaign(city_idx: int, city_name: String, city_lat: float, city_lon: float) -> void:
	in_campaign       = true
	prologue_done     = false
	current_mission   = 0
	home_city_index   = city_idx
	home_city_name    = city_name
	home_city_lat     = city_lat
	home_city_lon     = city_lon
	missions_complete = [false, false, false, false, false]
	world_stars       = {}
	world_unlocked.fill(false)
	world_unlocked[city_idx] = true  # home city always accessible
	last_victory      = false
	world_theater_active = false
	_save_state()

func record_mission_result(victory: bool, stars: int) -> void:
	last_victory = victory
	if current_mission < missions_complete.size():
		missions_complete[current_mission] = victory
	# Store stars in world map
	var loc_idx: int = _mission_loc_idx(current_mission)
	var prev_stars: int = int(world_stars.get(loc_idx, 0))
	if stars > prev_stars:
		world_stars[loc_idx] = stars
	# Unlock adjacent cities if we earned at least 1 star
	if stars >= 1:
		_unlock_adjacent(loc_idx)
	_save_state()

## Call after post-mission dialogue to advance to the next step.
func advance_mission() -> void:
	if current_mission < 4:
		current_mission += 1
	else:
		prologue_done        = true
		in_campaign          = false
		world_theater_active = true
	_save_state()

func get_current_mission_data() -> Dictionary:
	if current_mission < CampaignData.PROLOGUE_MISSIONS.size():
		return CampaignData.PROLOGUE_MISSIONS[current_mission]
	return {}

## Return true when there is an active prologue mission in flight.
func is_prologue_active() -> bool:
	return in_campaign and not prologue_done

## Locate the LOCATIONS index for the given mission number.
func _mission_loc_idx(mission_idx: int) -> int:
	var mission: Dictionary = CampaignData.PROLOGUE_MISSIONS[mission_idx]
	var key: int = int(mission.get("location_key", -1))
	return home_city_index if key == -1 else key

# ── WORLD THEATER ─────────────────────────────────────────────────────────────

func record_world_battle(city_idx: int, victory: bool, stars: int) -> void:
	var prev_stars: int = int(world_stars.get(city_idx, 0))
	if stars > prev_stars:
		world_stars[city_idx] = stars
	if stars >= 1:
		_unlock_adjacent(city_idx)
	_save_state()

func _unlock_adjacent(city_idx: int) -> void:
	var neighbours: Array = CampaignData.WORLD_ADJACENCY.get(city_idx, [])
	for n in neighbours:
		world_unlocked[int(n)] = true

func is_city_unlocked(city_idx: int) -> bool:
	if city_idx < 0 or city_idx >= world_unlocked.size(): return false
	return bool(world_unlocked[city_idx])

func get_city_stars(city_idx: int) -> int:
	return int(world_stars.get(city_idx, 0))

# ── HELPERS ───────────────────────────────────────────────────────────────────

## Star rating from game result.  Called by main.gd's campaign_mission_complete().
func compute_stars(victory: bool, kill_count: int, units_lost: int) -> int:
	if not victory:               return 0
	if units_lost == 0:           return 3
	if units_lost <= 2:           return 2
	return 1

# ── PERSISTENCE ───────────────────────────────────────────────────────────────

func _save_state() -> void:
	var data := {
		"in_campaign":          in_campaign,
		"prologue_done":        prologue_done,
		"current_mission":      current_mission,
		"home_city_index":      home_city_index,
		"home_city_name":       home_city_name,
		"home_city_lat":        home_city_lat,
		"home_city_lon":        home_city_lon,
		"missions_complete":    missions_complete,
		"world_stars":          world_stars,
		"world_unlocked":       world_unlocked,
		"world_theater_active": world_theater_active,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		f.close()
		return
	f.close()
	var d = j.get_data()
	if not d is Dictionary: return
	in_campaign          = bool(d.get("in_campaign",          false))
	prologue_done        = bool(d.get("prologue_done",        false))
	current_mission      = int(d.get("current_mission",       0))
	home_city_index      = int(d.get("home_city_index",       0))
	home_city_name       = str(d.get("home_city_name",        ""))
	home_city_lat        = float(d.get("home_city_lat",       0.0))
	home_city_lon        = float(d.get("home_city_lon",       0.0))
	world_theater_active = bool(d.get("world_theater_active", false))
	last_victory         = false
	var mc = d.get("missions_complete", [false, false, false, false, false])
	missions_complete = mc if mc is Array else [false, false, false, false, false]
	var ws = d.get("world_stars", {})
	world_stars = ws if ws is Dictionary else {}
	var wu = d.get("world_unlocked", [])
	if wu is Array and wu.size() == CampaignData.LOCATIONS.size():
		world_unlocked = wu
