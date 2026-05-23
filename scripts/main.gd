extends Node
class_name Main

var globe_scene           := preload("res://scenes/globe.tscn")
var generation_scene      := preload("res://scenes/generation.tscn")
var game_scene            := preload("res://scenes/game.tscn")
var campaign_brief_scene  := preload("res://scenes/campaign_brief.tscn")
var campaign_world_scene  := preload("res://scenes/campaign_world.tscn")

var _current: Node = null
@onready var _fade: ColorRect = $FadeLayer/FadeRect

# ── SHARED STATE ─────────────────────────────────────────────────────────────
var active_lat:   float  = 40.7128
var active_lon:   float  = -74.006
var active_name:  String = "New York, NY"
var difficulty:   String = "normal"   # "easy" | "normal" | "hard"
var time_of_day:  String = "day"      # "day" | "dusk" | "night"
var ai_tile_grid:   Array           = []
var using_ai_map:   bool            = false
var sat_image_data: PackedByteArray = PackedByteArray()
var osm_roads:      Array           = []
var osm_buildings:  Array           = []

# ── CAMPAIGN STATE ────────────────────────────────────────────────────────────
## Set true while a campaign mission (prologue or world theater) is in flight.
var campaign_mode:      bool = false
## LOCATIONS index for the city currently being battled in world theater mode.
var campaign_city_idx:  int  = -1
## Wave cap for current campaign mission (0 = use all WAVE_DEFS waves).
var campaign_wave_cap:  int  = 0

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_fade.color.a = 1.0   # start fully black — _do_transition fades in
	show_globe()

# ── NAVIGATION ───────────────────────────────────────────────────────────────

func show_globe()      -> void: _do_transition(globe_scene.instantiate())
func show_generation() -> void: _do_transition(generation_scene.instantiate())
func show_game()       -> void: _do_transition(game_scene.instantiate())

func show_campaign_world() -> void:
	Campaign.world_theater_active = true
	_do_transition(campaign_world_scene.instantiate())

# ── CAMPAIGN BRIEF ────────────────────────────────────────────────────────────

## Called when the player presses "CAMPAIGN" on the globe screen.
## If no campaign is in progress, opens city-selection inline on the globe.
## Otherwise resumes at the current prologue mission's pre-brief.
func show_campaign_start() -> void:
	# If prologue already done, go straight to world theater.
	if Campaign.prologue_done:
		show_campaign_world()
		return
	# If a prologue is in flight, skip home-city selection and resume.
	if Campaign.in_campaign:
		_show_campaign_brief_pre()
		return
	# Fresh start: the globe screen handles city selection — it calls
	# campaign_begin_with_city() after the player confirms.
	var node := globe_scene.instantiate()
	node.set_meta("campaign_city_select", true)
	_do_transition(node)

## Called by globe.gd after the player picks a home city and presses CONFIRM.
func campaign_begin_with_city(city_idx: int, city_name: String, city_lat: float, city_lon: float) -> void:
	Campaign.start_campaign(city_idx, city_name, city_lat, city_lon)
	active_lat  = city_lat
	active_lon  = city_lon
	active_name = city_name
	campaign_mode = true
	# difficulty + wave_cap are applied by _show_campaign_brief_pre → _apply_mission_location
	_show_campaign_brief_pre()

## Called by game.gd after _show_endgame() when campaign_mode == true.
func campaign_mission_complete(victory: bool, kill_count: int, units_lost: int) -> void:
	campaign_mode     = false
	campaign_wave_cap = 0  # reset so free-play games aren't affected
	var stars := Campaign.compute_stars(victory, kill_count, units_lost)

	if Campaign.is_prologue_active():
		Campaign.record_mission_result(victory, stars)
		_show_campaign_brief_post(victory)
	else:
		# World theater battle
		if campaign_city_idx >= 0:
			Campaign.record_world_battle(campaign_city_idx, victory, stars)
			campaign_city_idx = -1
		show_campaign_world()

# ── INTERNAL BRIEF HELPERS ────────────────────────────────────────────────────

func _show_campaign_brief_pre() -> void:
	campaign_mode = true  # ensure game.gd sees campaign_mode regardless of entry path
	var mission := Campaign.get_current_mission_data()
	_apply_mission_location(mission)
	difficulty = str(mission.get("difficulty_override", "normal"))

	var node := campaign_brief_scene.instantiate() as Control
	node.setup_pre(
		str(mission.get("title",    "MISSION")),
		_sub(str(mission.get("subtitle", ""))),
		_sub_lines(mission.get("pre", [])),
		func()->void: show_generation()
	)
	_do_transition(node)

func _show_campaign_brief_post(victory: bool) -> void:
	var mission := Campaign.get_current_mission_data()
	var key: String   = "post_win" if victory else "post_loss"
	var lines: Array  = _sub_lines(mission.get(key, []))

	var node := campaign_brief_scene.instantiate() as Control
	node.setup_post(
		str(mission.get("title", "MISSION")),
		"DEBRIEF",
		lines,
		victory,
		func()->void:
			Campaign.advance_mission()
			if Campaign.prologue_done:
				show_campaign_world()
			else:
				_show_campaign_brief_pre()
	)
	_do_transition(node)

## Set active_lat/lon/name from mission location_key (-1 = home city).
## Also writes difficulty and wave_cap for game.gd to read.
func _apply_mission_location(mission: Dictionary) -> void:
	var key: int = int(mission.get("location_key", -1))
	if key == -1:
		active_lat  = Campaign.home_city_lat
		active_lon  = Campaign.home_city_lon
		active_name = Campaign.home_city_name
	elif key < CampaignData.LOCATIONS.size():
		var loc: Dictionary = CampaignData.LOCATIONS[key]
		active_lat  = float(loc.get("lat", 0.0))
		active_lon  = float(loc.get("lon", 0.0))
		active_name = str(loc.get("name", ""))
	# Store wave cap so game.gd can stop waves early for scripted missions.
	campaign_wave_cap = int(mission.get("wave_cap", 0))

## Replace {HOME_CITY} placeholder in a string.
func _sub(s: String) -> String:
	return s.replace("{HOME_CITY}", Campaign.home_city_name)

## Replace {HOME_CITY} in every line's text field.
func _sub_lines(lines: Array) -> Array:
	var result: Array = []
	for line in lines:
		var l: Dictionary = (line as Dictionary).duplicate()
		l["text"] = _sub(str(l.get("text", "")))
		result.append(l)
	return result

# ── TRANSITION ────────────────────────────────────────────────────────────────

func _do_transition(node: Node) -> void:
	if _fade.color.a < 0.95:
		_fade.visible = true
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.32)
		await t.finished
	_switch_to(node)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.42)
	await t.finished
	_fade.visible = false

func _switch_to(node: Node) -> void:
	if _current:
		_current.queue_free()
	_current = node
	add_child(_current)
