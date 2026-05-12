extends Node3D

# Preload forces unit.gd to compile before this script parses its type annotations
const Unit = preload("res://scripts/unit.gd")

const _CHAR_MAN  := preload("res://assets/units/KayKit_Character_Animations_1.1/Mannequin Character/characters/Mannequin_Medium.glb")
const _CHAR_GEN  := preload("res://assets/units/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
const _CHAR_WALK := preload("res://assets/units/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb")
const _CHAR_CMBT := preload("res://assets/units/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_CombatRanged.glb")
const _CHAR_DIE  := preload("res://assets/units/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_Simulation.glb")

# ── UNIT DEFINITIONS ──────────────────────────────────────────
# Player units are MILITIA — local defenders, cheap, weaker individually
# Enemy units are MILITARY — invading force, better equipped
const UNIT_DEFS := {
	# Player / Militia
	"militia":   {"name":"MILITIA",    "cost":75,  "hp":65,  "speed":2.3,"range":7.0, "dmg_min":12,"dmg_max":26,"fire_rate":1.1,"desc":"Civilian defender. Weak alone, deadly en masse.","ability":"BARRICADE"},
	"grenadier": {"name":"GRENADIER",  "cost":130, "hp":80,  "speed":2.1,"range":9.0, "dmg_min":35,"dmg_max":60,"fire_rate":0.55,"desc":"Explosive specialist. Area suppression.","ability":"GRENADE"},
	"sniper":    {"name":"SNIPER",     "cost":200, "hp":65,  "speed":1.85,"range":22.0,"dmg_min":70,"dmg_max":100,"fire_rate":0.3,"desc":"One shot, one kill. Long range.","ability":"OVERWATCH"},
	"mg_team":   {"name":"MG TEAM",   "cost":195, "hp":90,  "speed":1.4,"range":14.0,"dmg_min":20,"dmg_max":40,"fire_rate":1.1,"desc":"Sustained fire. Suppresses enemies.","ability":"SUPR.FIRE"},
	"medic":     {"name":"MEDIC",     "cost":150, "hp":55,  "speed":2.6,"range":5.0, "dmg_min":4, "dmg_max":10,"fire_rate":0.8,"desc":"Auto-heals injured friendlies within 3.5 units.","ability":"STIMPACK"},
	# Enemy / Military — same archetypes, stronger stats
	"soldier":   {"name":"SOLDIER",    "cost":0,   "hp":90,  "speed":2.5,"range":9.0, "dmg_min":18,"dmg_max":32,"fire_rate":1.0,"desc":""},
	"e_gren":    {"name":"E.GRENADIER","cost":0,   "hp":90,  "speed":2.1,"range":11.0,"dmg_min":40,"dmg_max":65,"fire_rate":0.5,"desc":""},
	"e_sniper":  {"name":"E.SNIPER",   "cost":0,   "hp":65,  "speed":1.75,"range":24.0,"dmg_min":75,"dmg_max":105,"fire_rate":0.28,"desc":""},
	"e_mg":      {"name":"E.MG TEAM", "cost":0,   "hp":95,  "speed":1.55,"range":16.0,"dmg_min":22,"dmg_max":42,"fire_rate":1.1,"desc":""},
}

const WAVE_DEFS := [
	["soldier","soldier","soldier","soldier","soldier"],
	["soldier","soldier","soldier","e_gren","soldier","soldier"],
	["soldier","e_gren","soldier","e_sniper","soldier","soldier","e_mg"],
	["soldier","e_gren","e_sniper","e_mg","soldier","soldier","e_gren","soldier"],
	["e_mg","e_gren","e_sniper","soldier","soldier","e_gren","e_mg","soldier","e_sniper","soldier"],
]

const CP_DEFS := [Vector2(0.0,-6.0), Vector2(-9.0,4.0), Vector2(9.0,1.0)]

# ── WORLD CONSTANTS ───────────────────────────────────────────
const TG    := 20
const TCELL := 2.0
const HALF  := 20.0
const HQ_X  := 16.0
const HQ_Z  := 16.0

const TILE_GROUND   := 0
const TILE_ROAD     := 1
const TILE_BUILDING := 2
const TILE_TREE     := 3
const TILE_WATER    := 4
const TILE_PARK     := 5

const LABEL_MAP := {
	"ROAD":1,"BUILDING":2,"GRASS":0,"TREE":3,
	"WATER":4,"PARKING":1,"RUBBLE":0,
}

# ── SCENE REFS ────────────────────────────────────────────────
@onready var units_node: Node3D    = $Units
@onready var camera_pivot: Node3D  = $CameraPivot
@onready var camera: Camera3D      = $CameraPivot/Camera3D
@onready var res_label: Label      = $HUD/TopBar/ResLabel
@onready var wave_label: Label     = $HUD/TopBar/WaveLabel
@onready var kills_label: Label    = $HUD/TopBar/KillsLabel
@onready var hq_label: Label       = $HUD/TopBar/HQLabel
@onready var status_label: Label   = $HUD/StatusLabel
@onready var deploy_panel: Control = $HUD/DeployPanel
@onready var unit_info: Control    = $HUD/UnitInfo
@onready var unit_name_lbl: Label  = $HUD/UnitInfo/NameLbl
@onready var mode_bar: Control     = $HUD/UnitInfo/ModeBar

# ── GAME STATE ────────────────────────────────────────────────
var tmap: Array        = []
var units: Array       = []
var sel_unit: Unit     = null
var cur_mode: String   = "none"
var deploying_kind: String = ""
var supplies: int      = 300
var wave_num: int      = 0
var wave_timer: float  = 50.0
var game_active: bool  = false
var kill_count: int    = 0
var supply_accum: float = 0.0
var hq_hp: int         = 100
var hq_hp_max: int     = 100
var game_paused: bool  = false

# Pause menu refs (built in code)
var _pause_layer:    CanvasLayer = null
var _pause_overlay:  ColorRect   = null
var _pause_panel:    Control     = null
var _settings_panel: Control     = null

# Camera
var cam_target: Vector3 = Vector3(HQ_X, 0.0, HQ_Z)
var cam_zoom: float     = 28.0
var cam_yaw: float      = 0.0
var _drag_on: bool      = false
var _drag_lx: float     = 0.0
var _drag_ly: float     = 0.0
var _drag_sx: float     = 0.0
var _drag_sy: float     = 0.0
var _drag_moved: bool   = false
var _touches:      Dictionary = {}   # finger index -> current Vector2
var _touches_prev: Dictionary = {}   # finger index -> previous Vector2

# Multi-select
var sel_units: Array = []
# Drag marquee select
var _lmarquee: bool     = false
var _lmarquee_sx: float = 0.0
var _lmarquee_sy: float = 0.0
var _sel_box_layer: CanvasLayer = null
var _sel_box: Panel     = null
# Right-click context command (separate from camera-pan drag)
var _rdrag_moved: bool  = false
var _rdrag_sx: float    = 0.0
var _rdrag_sy: float    = 0.0
# Screen shake
var _shake_intensity: float = 0.0
var _shake_timer: float     = 0.0
var _hq_alarm_timer: float  = 0.0
var _unit_flanks:    Dictionary = {}  # enemy Unit -> persistent lateral angle (radians)
var _unit_aps:       Dictionary = {}  # Unit -> AnimationPlayer
var _enemy_cp_target: Dictionary = {}  # enemy Unit -> Vector3 CP waypoint
var _enemy_cp_timer:  Dictionary = {}  # enemy Unit -> float seconds remaining

# Garrison system
const GARRISON_MAX      := 4
const GARRISON_DMG_MOD  := 0.30   # 30% damage taken in buildings (70% reduction)
const BUNKER_DMG_MOD    := 0.25   # 25% damage taken in CP bunkers (75% reduction)
const GARRISON_RANGE_BONUS := 2.0 # +2 world-units of range when garrisoned
var _garrisons:     Dictionary = {}  # Vector2i(r,c) -> Array[Unit]
var _garrison_inds: Dictionary = {}  # Vector2i(r,c) -> Node3D flag indicator
var _bunker_tiles:  Dictionary = {}  # Vector2i -> true, for CP bunker positions

# Mortar strike state
var _mortar_mode: bool   = false
var _mortar_btn:  Button = null

# Retreat / HUD extras
var _retreat_btn:     Button           = null
var _vet_star_nodes:  Dictionary       = {}    # Unit -> Node3D star indicator
var _grenade_cursor:  MeshInstance3D   = null  # AoE preview circle in grenade mode
var _is_touch_device: bool             = false
var _mm_cp_dots:      Array            = []    # ColorRect dots for CP ownership on minimap
var _mg_deploy_timers: Dictionary      = {}    # Unit -> float (time until MG can fire after stopping)
var _squad_speed: Dictionary = {}  # Unit -> float  (governed speed during group move)
var _squad_dest:  Dictionary = {}  # Unit -> Vector3 (individual formation slot to reach on arrival)
var _ability_btn: Button      = null
var _barricades:  Array       = []  # Array of {node: MeshInstance3D, pos: Vector3}
# Minimap
var _mm_layer:    CanvasLayer = null
var _mm_panel:    Control     = null
var _mm_cam_rect: ColorRect   = null
var _mm_dots:     Dictionary  = {}
var _suppression_overlay: ColorRect = null
var _wave_clear_notified: int = 0

# Capture points
var capture_points: Array = []

# Fog of war
const VISION_R      := 5   # default vision radius in tmap tiles
const VISION_R_SNIP := 9   # sniper vision
var fog:      Array          = []
var _fog_mesh: MeshInstance3D = null
var _fog_img:  Image          = null
var _fog_tex:  ImageTexture   = null

# Material cache
var _mats: Dictionary = {}
var _water_mat: ShaderMaterial = null
var _sat_img: Image = null          # decoded satellite for tree-type inference
var _tree_mats: Dictionary = {}     # tree_type -> ShaderMaterial (shared per type)
var _bld_mats:  Dictionary = {}     # bld_type  -> StandardMaterial3D (cached per type)

# RNG seeded per-map
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = hash(str(_main().active_lat) + str(_main().active_lon))
	_build_world()
	_init_capture_points()
	_setup_hud()
	_build_pause_menu()
	_build_marquee()
	_build_minimap()
	_init_fog()
	game_active = true
	_set_status("DEFEND THE NEIGHBORHOOD  |  TAP TO SELECT AND COMMAND")

# ── WORLD BUILDING ────────────────────────────────────────────

func _build_world() -> void:
	var main := _main()
	# Base ground — solid border/fill, always present
	var gnd_s := Shader.new(); gnd_s.code = _ground_shader_code()
	var gnd_mat := ShaderMaterial.new(); gnd_mat.shader = gnd_s
	var gnd_bm := BoxMesh.new(); gnd_bm.size = Vector3(HALF*2.0+1.0, 0.12, HALF*2.0+1.0)
	var gnd := MeshInstance3D.new(); gnd.mesh = gnd_bm
	gnd.set_surface_override_material(0, gnd_mat)
	gnd.position = Vector3(0.0, -0.06, 0.0)
	add_child(gnd)
	# Satellite photo overlay — covers exact play area when image data is available
	var sat_raw = main.get("sat_image_data")
	if sat_raw is PackedByteArray and (sat_raw as PackedByteArray).size() > 0:
		var img := Image.new()
		if img.load_jpg_from_buffer(sat_raw as PackedByteArray) == OK:
			_sat_img = img  # store for tree-type inference during world build
			var sat_mat := StandardMaterial3D.new()
			sat_mat.albedo_texture = ImageTexture.create_from_image(img)
			# PBR shading so the satellite photo responds to sun and SDFGI
			sat_mat.roughness  = 0.88
			sat_mat.metallic   = 0.0
			sat_mat.specular   = 0.12
			var pm := PlaneMesh.new()
			pm.size = Vector2(HALF * 2.0, HALF * 2.0)
			pm.subdivide_width  = 4
			pm.subdivide_depth  = 4
			var sat_plane := MeshInstance3D.new()
			sat_plane.mesh = pm
			sat_plane.set_surface_override_material(0, sat_mat)
			sat_plane.position = Vector3(0.0, 0.005, 0.0)
			add_child(sat_plane)

	tmap.clear()
	for r in TG:
		tmap.append([])
		for _c in TG:
			tmap[r].append(TILE_GROUND)

	if main.using_ai_map and main.ai_tile_grid.size() >= 10:
		_build_from_grid(main.ai_tile_grid)
		_build_osm_roads()
		_build_osm_buildings()
		_scatter_terrain_trees()
	else:
		_build_procedural()

	_hq_zone(Vector3(HQ_X, 0.0, HQ_Z),   Color(0.30,1.00,0.43,0.4), "HQ")
	_hq_zone(Vector3(-HQ_X,0.0,-HQ_Z),   Color(1.00,0.20,0.18,0.4), "ENEMY")
	_build_boundary()
	_setup_environment()

func _setup_environment() -> void:
	# Primary sun — warm afternoon angle, sharp shadows with PCF5 softening
	var sun := DirectionalLight3D.new()
	sun.light_color   = Color(1.00, 0.93, 0.78)
	sun.light_energy  = 2.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode         = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_fade_start   = 0.92
	sun.shadow_bias                     = 0.008
	sun.shadow_normal_bias              = 1.2
	sun.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	add_child(sun)

	# Cool sky fill — softens shadow side, adds depth
	var fill := DirectionalLight3D.new()
	fill.light_color  = Color(0.38, 0.54, 0.84)
	fill.light_energy = 0.30
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-18.0, 148.0, 0.0)
	add_child(fill)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.10, 0.20, 0.50)
	sky_mat.sky_horizon_color    = Color(0.60, 0.68, 0.80)
	sky_mat.ground_bottom_color  = Color(0.06, 0.07, 0.05)
	sky_mat.ground_horizon_color = Color(0.32, 0.35, 0.26)
	sky_mat.sun_angle_max        = 6.0   # wider, softer sun disk
	sky_mat.sun_curve            = 0.10
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode       = Environment.BG_SKY
	env.sky                   = sky
	env.ambient_light_source  = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy  = 0.50

	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white    = 5.5

	# SDFGI — proper indirect GI bounce off buildings and ground
	env.sdfgi_enabled       = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy        = 1.0
	env.sdfgi_cascades      = 4
	env.sdfgi_min_cell_size = 0.20

	env.ssao_enabled   = true
	env.ssao_radius    = 1.2
	env.ssao_intensity = 2.0
	env.ssao_power     = 1.4
	env.ssao_sharpness = 0.98

	env.ssil_enabled   = true
	env.ssil_radius    = 5.0
	env.ssil_intensity = 0.7

	env.glow_enabled       = true
	env.glow_normalized    = false
	env.glow_intensity     = 0.55
	env.glow_bloom         = 0.08
	env.glow_blend_mode    = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.80
	env.glow_hdr_scale     = 2.4
	# Level 1 = tight corona around lights; level 3 = medium bloom; level 6 = wide haze
	env.set_glow_level(0, 0.70)
	env.set_glow_level(1, 0.00)
	env.set_glow_level(2, 0.55)
	env.set_glow_level(3, 0.00)
	env.set_glow_level(4, 0.35)
	env.set_glow_level(5, 0.00)
	env.set_glow_level(6, 0.20)

	# Analytical fog (sky haze)
	env.fog_enabled            = true
	env.fog_light_color        = Color(0.56, 0.60, 0.64)
	env.fog_density            = 0.002
	env.fog_aerial_perspective = 0.25

	# Volumetric fog — depth, building occlusion, light shaft interaction
	env.volumetric_fog_enabled   = true
	env.volumetric_fog_density   = 0.010
	env.volumetric_fog_albedo    = Color(0.84, 0.82, 0.80)
	env.volumetric_fog_emission  = Color(0.28, 0.26, 0.22) * 0.03
	env.volumetric_fog_gi_inject = 0.8
	env.volumetric_fog_anisotropy = 0.20

	env.ssr_enabled         = true
	env.ssr_max_steps       = 64
	env.ssr_fade_in         = 0.15
	env.ssr_fade_out        = 2.0
	env.ssr_depth_tolerance = 0.2

	# Subtle color grading — desaturated, gritty war palette
	env.adjustment_enabled     = true
	env.adjustment_brightness  = 1.0
	env.adjustment_contrast    = 1.08
	env.adjustment_saturation  = 0.82

	var we := $WorldEnvironment as WorldEnvironment
	if we: we.environment = env

	var cam_attr := CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled    = true
	cam_attr.dof_blur_far_distance   = 34.0
	cam_attr.dof_blur_far_transition = 16.0
	cam_attr.dof_blur_near_enabled   = false
	cam_attr.dof_blur_amount         = 0.08
	camera.attributes = cam_attr

func _build_from_grid(grid: Array) -> void:
	var rows: int = mini(grid.size(), TG)
	for r in rows:
		var row: Array = grid[r]
		var cols: int = mini(row.size(), TG)
		for c in cols:
			var lbl: String = str(row[c]).to_upper()
			var tile: int = LABEL_MAP.get(lbl, TILE_GROUND)
			tmap[r][c] = tile
			var px: float = _tx(c); var pz: float = _tz(r)
			match tile:
				TILE_TREE:
					if _has_building_neighbor(r, c):
						tmap[r][c] = TILE_GROUND  # demote — don't plant into a building's shadow
					else:
						_place_tree(px, pz)
				TILE_WATER: _place_water(px, pz)

func _build_osm_roads() -> void:
	var mn  := _main()
	var roads = mn.get("osm_roads")
	if not roads is Array or (roads as Array).is_empty(): return
	var clat    : float = mn.active_lat
	var clon    : float = mn.active_lon
	var cos_lat := cos(deg_to_rad(clat))
	var scale   := HALF / 100.0   # game units per real metre

	var all_verts   := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_idx     := PackedInt32Array()
	var base := 0

	for road_entry in (roads as Array):
		var geom: Array = road_entry.get("geom", [])
		if geom.size() < 2: continue
		var rw: float = 0.7 if road_entry.get("width", 1) == 1 else 1.2

		var pts: Array = []
		for pt in geom:
			var lat := float(pt.get("lat", 0.0))
			var lon := float(pt.get("lon", 0.0))
			var dy  := (lat - clat) * 111000.0
			var dx  := (lon - clon) * 111000.0 * cos_lat
			pts.append(Vector3(dx * scale, 0.03, -dy * scale))

		for i in pts.size():
			var dir: Vector3
			if i == 0:
				dir = pts[1] - pts[0]
			elif i == pts.size() - 1:
				dir = pts[i] - pts[i - 1]
			else:
				dir = pts[i + 1] - pts[i - 1]
			dir.y = 0.0
			if dir.length_squared() < 0.00001: dir = Vector3.RIGHT
			dir = dir.normalized()
			var perp := Vector3(-dir.z, 0.0, dir.x) * rw * 0.5
			all_verts.append(pts[i] + perp)
			all_verts.append(pts[i] - perp)
			all_normals.append(Vector3.UP)
			all_normals.append(Vector3.UP)

		for i in range(pts.size() - 1):
			var b := base + i * 2
			all_idx.append(b);     all_idx.append(b + 1); all_idx.append(b + 2)
			all_idx.append(b + 1); all_idx.append(b + 3); all_idx.append(b + 2)

		base += pts.size() * 2

	if all_verts.is_empty(): return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_verts
	arrays[Mesh.ARRAY_NORMAL] = all_normals
	arrays[Mesh.ARRAY_INDEX]  = all_idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	var road_s := Shader.new(); road_s.code = _road_shader_code()
	var road_mat := ShaderMaterial.new(); road_mat.shader = road_s
	mi.set_surface_override_material(0, road_mat)
	add_child(mi)

func _build_osm_buildings() -> void:
	var mn   := _main()
	var blds  = mn.get("osm_buildings")
	if not blds is Array or (blds as Array).is_empty(): return
	var clat    : float = mn.active_lat
	var clon    : float = mn.active_lon
	var cos_lat := cos(deg_to_rad(clat))
	var scale   := HALF / 100.0

	var sat_img: Image = null
	var sat_raw = mn.get("sat_image_data")
	if sat_raw is PackedByteArray and (sat_raw as PackedByteArray).size() > 0:
		sat_img = Image.new()
		if sat_img.load_jpg_from_buffer(sat_raw as PackedByteArray) != OK:
			sat_img = null

	var all_verts   := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_colors  := PackedColorArray()
	var all_uvs     := PackedVector2Array()
	var all_idx     := PackedInt32Array()

	for bld in (blds as Array):
		var geom: Array = bld.get("geom", [])
		if geom.size() < 3: continue

		var pts: Array = []
		for pt in geom:
			var lat := float(pt.get("lat", 0.0))
			var lon := float(pt.get("lon", 0.0))
			var dy  := (lat - clat) * 111000.0
			var dx  := (lon - clon) * 111000.0 * cos_lat
			pts.append(Vector2(dx * scale, -dy * scale))
		if pts.size() >= 2 and (pts[0] as Vector2).distance_to(pts[-1] as Vector2) < 0.05:
			pts.resize(pts.size() - 1)
		if pts.size() < 3: continue

		# Skip any footprint with a vertex outside the playable area so buildings
		# don't clip through the boundary walls.
		var off_map := false
		for p: Vector2 in pts:
			if absf(p.x) > HALF - 0.3 or absf(p.y) > HALF - 0.3:
				off_map = true; break
		if off_map: continue

		var btype: String = str(bld.get("type", "yes"))
		var h_real: float = float(bld.get("height", 0.0))
		var h: float
		if h_real > 0.5:
			h = h_real * scale
		else:
			var lv: int = int(bld.get("levels", 0))
			if lv > 0:
				h = float(lv) * 3.0 * scale
			else:
				var floors: int
				match btype:
					"house","detached","semidetached_house","terrace","bungalow":
						floors = 1 + _rng.randi() % 2
					"apartments","residential","block_of_flats":
						floors = 3 + _rng.randi() % 5
					"office","commercial","bank","hotel":
						floors = 3 + _rng.randi() % 8
					"industrial","warehouse","shed","garage","garages":
						floors = 1 + _rng.randi() % 2
					_:
						floors = 2 + _rng.randi() % 3
				h = float(floors) * 3.0 * scale
		h = clampf(h, 0.3, 25.0)

		var centroid := Vector2.ZERO
		for p: Vector2 in pts: centroid += p
		centroid /= float(pts.size())

		# tmap is already populated correctly by _build_from_grid (AI raster grid);
		# just stamp the centroid so trees don't plant inside this footprint.
		var btr := clampi(int((centroid.y + HALF) / TCELL), 0, TG - 1)
		var btc := clampi(int((centroid.x + HALF) / TCELL), 0, TG - 1)
		tmap[btr][btc] = TILE_BUILDING

		# Sample satellite image at building centroid for realistic base colors
		var sat_col := Color(0.62, 0.58, 0.54)
		if sat_img != null:
			var su := (centroid.x + HALF) / (HALF * 2.0)
			var sv := (centroid.y + HALF) / (HALF * 2.0)
			var iw := sat_img.get_width()
			var ih := sat_img.get_height()
			var cr := 0.0; var cg := 0.0; var cb := 0.0
			for sdy in range(-1, 2):
				for sdx in range(-1, 2):
					var nx := clampi(int(su * iw) + sdx, 0, iw - 1)
					var ny := clampi(int(sv * ih) + sdy, 0, ih - 1)
					var sc := sat_img.get_pixel(nx, ny)
					cr += sc.r; cg += sc.g; cb += sc.b
			sat_col = Color(cr / 9.0, cg / 9.0, cb / 9.0)

		# Classify building type using OSM tag + satellite colour; encode material in vertex alpha
		var bld_type := _classify_building(sat_col, btype)
		var mat_alpha: float
		match bld_type:
			"BRICK_ROW","STONE_HISTORIC": mat_alpha = 1.0
			"SUBURBAN_HOUSE": mat_alpha = 1.0 if (sat_col.r - sat_col.b) >= 0.04 else 0.75
			"GLASS_TOWER":    mat_alpha = 0.25
			_:                mat_alpha = 0.5   # CONCRETE_BLOCK, INDUSTRIAL

		var wc  := _bld_wall_color(bld_type, sat_col)
		var lf  := 1.0 + _rng.randf() * 0.12
		var wall_col := Color(minf(wc.r * lf, 1.0), minf(wc.g * lf, 1.0), minf(wc.b * lf, 1.0), mat_alpha)
		var rc  := _bld_roof_color(bld_type, sat_col)
		var roof_col := Color(rc.r, rc.g, rc.b, mat_alpha)

		var n := pts.size()
		for i in n:
			var j    := (i + 1) % n
			var pi   := pts[i] as Vector2
			var pj   := pts[j] as Vector2
			var elen := pi.distance_to(pj)
			var p0   := Vector3(pi.x, 0.02, pi.y)
			var p1   := Vector3(pj.x, 0.02, pj.y)
			var p0t  := Vector3(pi.x, h,    pi.y)
			var p1t  := Vector3(pj.x, h,    pj.y)
			var mid2d: Vector2 = (pi + pj) * 0.5
			var out2d: Vector2 = mid2d - centroid
			var norm: Vector3
			if out2d.length_squared() > 0.00001:
				out2d = out2d.normalized()
				norm = Vector3(out2d.x, 0.0, out2d.y)
			else:
				norm = Vector3.BACK
			var b := all_verts.size()
			all_verts.append_array([p0, p1, p0t, p1t])
			all_normals.append_array([norm, norm, norm, norm])
			all_colors.append_array([wall_col, wall_col, wall_col, wall_col])
			all_uvs.append_array([Vector2(0.0, 0.0), Vector2(elen, 0.0),
				Vector2(0.0, h), Vector2(elen, h)])
			all_idx.append_array([b, b+2, b+1, b+1, b+2, b+3])

		var rb := all_verts.size()
		for i in pts.size():
			var pi := pts[i] as Vector2
			all_verts.append(Vector3(pi.x, h, pi.y))
			all_normals.append(Vector3.UP)
			all_colors.append(roof_col)
			all_uvs.append(Vector2(pi.x, pi.y))
		for i in range(1, pts.size() - 1):
			all_idx.append_array([rb, rb + i, rb + i + 1])

	if all_verts.is_empty(): return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]  = all_verts
	arrays[Mesh.ARRAY_NORMAL]  = all_normals
	arrays[Mesh.ARRAY_COLOR]   = all_colors
	arrays[Mesh.ARRAY_TEX_UV]  = all_uvs
	arrays[Mesh.ARRAY_INDEX]   = all_idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bshader := Shader.new()
	bshader.code = _bld_shader_code()
	var mat := ShaderMaterial.new()
	mat.shader = bshader
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

func _build_procedural() -> void:
	for col in [5,6,13,14]:
		for r in TG:
			tmap[r][col] = TILE_ROAD
			_place_road(_tx(col), _tz(r))
	for row in [4,5,12,13]:
		for c in TG:
			tmap[row][c] = TILE_ROAD
			_place_road(_tx(c), _tz(row))
	var blocks := [
		[0,0,3,4],[0,7,3,12],[0,15,3,19],
		[6,0,11,4],[6,7,11,12],[6,15,11,19],
		[14,0,19,4],[14,7,19,12],[14,15,19,19],
	]
	for blk in blocks:
		var t := _rng.randf()
		if   t < 0.12: _block_park(blk)
		elif t < 0.22: _block_rubble(blk)
		else:           _block_buildings(blk)
	# Street lights at block corners adjacent to road intersections
	for slx: float in [_tx(7), _tx(12)]:
		for slz: float in [_tz(3), _tz(6), _tz(11), _tz(14)]:
			_place_street_light(slx, slz)
	# Parked cars on both sides of the vertical road corridors
	for cz: float in [_tz(1), _tz(3), _tz(8), _tz(10), _tz(15), _tz(17)]:
		_place_car(_tx(5)-0.62, cz, 0.0)
		_place_car(_tx(14)+0.62, cz, 0.0)

# ── TILE PLACERS ──────────────────────────────────────────────

func _place_road(px: float, pz: float) -> void:
	# Sidewalk (below road surface)
	var sw := _box(Vector3(TCELL-0.05, 0.06, TCELL-0.05), _mat(Color(0.52,0.52,0.50)))
	sw.position = Vector3(px, -0.03, pz)
	add_child(sw)
	# Asphalt — shader-driven surface texture + lane markings
	var pm := PlaneMesh.new()
	pm.size = Vector2(TCELL, TCELL)
	pm.subdivide_width = 1; pm.subdivide_depth = 1
	var road_mi := MeshInstance3D.new(); road_mi.mesh = pm
	var road_s := Shader.new(); road_s.code = _road_shader_code()
	var road_mat := ShaderMaterial.new(); road_mat.shader = road_s
	road_mi.set_surface_override_material(0, road_mat)
	road_mi.position = Vector3(px, 0.025, pz)
	add_child(road_mi)

func _place_building(px: float, pz: float, _r: int, _c: int) -> void:
	# Skip if the tile centre is too close to any map edge — the building geometry
	# would clip through the boundary wall (wall inner face at ≈ HALF - 0.25).
	if absf(px) > HALF - TCELL or absf(pz) > HALF - TCELL:
		return
	var sat_col  := _sample_sat(px, pz)
	var bld_type := _classify_building(sat_col, "")
	match bld_type:
		"BRICK_ROW":      _build_bld_brick_row(px, pz, sat_col)
		"CONCRETE_BLOCK": _build_bld_concrete_block(px, pz, sat_col)
		"GLASS_TOWER":    _build_bld_glass_tower(px, pz, sat_col)
		"SUBURBAN_HOUSE": _build_bld_suburban_house(px, pz, sat_col)
		"INDUSTRIAL":     _build_bld_industrial(px, pz, sat_col)
		_:                _build_bld_stone_historic(px, pz, sat_col)

func _add_windows(px: float, pz: float, h: float, bw: float, bd: float, frame_col: Color) -> void:
	var ww := 0.22; var wh := 0.30; var wd := 0.05
	var win_mat := _mat_new(Color(0.35,0.48,0.58,0.85))
	win_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var frame_mat := _mat(frame_col)
	var floors := int(h / 1.2)
	for fl in range(1, floors):
		var wy: float = float(fl) * 1.2 - 0.2
		# Front face
		for xi in [-0.22, 0.22]:
			var win := _box(Vector3(ww,wh,wd), win_mat)
			win.position = Vector3(px+xi, wy, pz+bd/2.0+0.02)
			add_child(win)
		# Back face
		for xi in [-0.22, 0.22]:
			var win := _box(Vector3(ww,wh,wd), win_mat)
			win.position = Vector3(px+xi, wy, pz-bd/2.0-0.02)
			add_child(win)

func _classify_building(sat_col: Color, osm_type: String) -> String:
	match osm_type:
		"house","detached","semidetached_house","terrace","bungalow":
			return "SUBURBAN_HOUSE"
		"apartments","residential","block_of_flats":
			return "CONCRETE_BLOCK"
		"office","commercial","bank","hotel":
			return "GLASS_TOWER"
		"industrial","warehouse","shed","garage","garages":
			return "INDUSTRIAL"
		"church","cathedral","chapel","mosque","synagogue":
			return "STONE_HISTORIC"
	var r := sat_col.r; var g := sat_col.g; var b := sat_col.b
	var brightness := (r + g + b) / 3.0
	var warmth     := r - b
	var saturation := maxf(maxf(r,g),b) - minf(minf(r,g),b)
	if brightness > 0.28 and warmth < -0.02:     return "GLASS_TOWER"
	if warmth > 0.07 and brightness < 0.25:      return "BRICK_ROW"
	if warmth > 0.04 and brightness >= 0.22:     return "SUBURBAN_HOUSE"
	if brightness < 0.16 and saturation < 0.06:  return "INDUSTRIAL"
	if warmth > 0.02 and brightness > 0.18:      return "STONE_HISTORIC"
	return "CONCRETE_BLOCK"

func _bld_wall_color(bld_type: String, sat_col: Color) -> Color:
	var sb := clampf((sat_col.r + sat_col.g + sat_col.b) / 3.0 * 2.5, 0.1, 0.9)
	match bld_type:
		"BRICK_ROW":      return Color(0.52 + sb*0.15, 0.24 + sb*0.08, 0.14 + sb*0.05)
		"CONCRETE_BLOCK": return Color(0.52 + sb*0.12, 0.51 + sb*0.12, 0.50 + sb*0.12)
		"GLASS_TOWER":    return Color(0.36 + sb*0.14, 0.44 + sb*0.12, 0.54 + sb*0.16)
		"SUBURBAN_HOUSE": return Color(0.68 + sb*0.14, 0.62 + sb*0.11, 0.50 + sb*0.10)
		"INDUSTRIAL":     return Color(0.38 + sb*0.10, 0.37 + sb*0.10, 0.35 + sb*0.10)
		"STONE_HISTORIC": return Color(0.56 + sb*0.12, 0.52 + sb*0.10, 0.38 + sb*0.08)
		_:                return Color(0.55 + sb*0.12, 0.52 + sb*0.11, 0.50 + sb*0.11)

func _bld_roof_color(bld_type: String, sat_col: Color) -> Color:
	var w := _bld_wall_color(bld_type, sat_col)
	match bld_type:
		"BRICK_ROW":      return Color(0.18, 0.14, 0.12)
		"SUBURBAN_HOUSE": return Color(0.28 + w.r*0.06, 0.15, 0.12)
		"INDUSTRIAL":     return Color(w.r*0.78, w.g*0.78, w.b*0.82)
		_:                return w.darkened(0.32)

func _build_bld_brick_row(px: float, pz: float, sat_col: Color) -> void:
	var wall_col := _bld_wall_color("BRICK_ROW", sat_col)
	var roof_col := _bld_roof_color("BRICK_ROW", sat_col)
	var h := 2.2 + _rng.randf() * 1.8
	var bw := TCELL * 0.72; var bd := TCELL * 0.72
	var body := _box(Vector3(bw, h, bd), _mat(wall_col))
	body.position = Vector3(px, h * 0.5, pz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)
	var par := _box(Vector3(bw + 0.05, 0.22, bd + 0.05), _mat(roof_col))
	par.position = Vector3(px, h + 0.11, pz); add_child(par)
	var chim_w := 0.22 + _rng.randf() * 0.10
	var chim_h := 0.55 + _rng.randf() * 0.35
	var chim := _box(Vector3(chim_w, chim_h, chim_w), _mat(wall_col.darkened(0.18)))
	chim.position = Vector3(px + bw*0.5 - chim_w, h + chim_h*0.5, pz + bd*0.5 - chim_w)
	chim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(chim)
	if h > 2.0:
		_add_windows(px, pz, h, bw, bd, wall_col.darkened(0.35))

func _build_bld_concrete_block(px: float, pz: float, sat_col: Color) -> void:
	var wall_col := _bld_wall_color("CONCRETE_BLOCK", sat_col)
	var roof_col := _bld_roof_color("CONCRETE_BLOCK", sat_col)
	var h := 4.5 + _rng.randf() * 4.5
	var bw := TCELL * 0.72; var bd := TCELL * 0.72
	var body := _box(Vector3(bw, h, bd), _mat(wall_col))
	body.position = Vector3(px, h * 0.5, pz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)
	var par := _box(Vector3(bw + 0.06, 0.26, bd + 0.06), _mat(roof_col))
	par.position = Vector3(px, h + 0.13, pz); add_child(par)
	var rbox := _box(Vector3(0.38, 0.42, 0.28), _mat(roof_col.darkened(0.15)))
	rbox.position = Vector3(px + bw*0.22, h + 0.55, pz - bd*0.22); add_child(rbox)
	var ant := _box(Vector3(0.04, 0.80, 0.04), _mat(Color(0.50, 0.50, 0.52)))
	ant.position = Vector3(px + bw*0.22, h + 1.15, pz - bd*0.22); add_child(ant)
	_add_windows(px, pz, h, bw, bd, wall_col.darkened(0.30))

func _build_bld_glass_tower(px: float, pz: float, sat_col: Color) -> void:
	var wall_col := _bld_wall_color("GLASS_TOWER", sat_col)
	var roof_col := _bld_roof_color("GLASS_TOWER", sat_col)
	var h := 6.0 + _rng.randf() * 6.0
	var bw := TCELL * 0.64; var bd := TCELL * 0.64
	var body := _box(Vector3(bw, h, bd), _mat(wall_col))
	body.position = Vector3(px, h * 0.5, pz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)
	var cap := _box(Vector3(bw + 0.08, 0.12, bd + 0.08), _mat(roof_col))
	cap.position = Vector3(px, h + 0.06, pz); add_child(cap)
	var mech := _box(Vector3(bw*0.45, 0.55, bd*0.35), _mat(roof_col.darkened(0.20)))
	mech.position = Vector3(px, h + 0.38, pz); add_child(mech)

func _build_bld_suburban_house(px: float, pz: float, sat_col: Color) -> void:
	var wall_col := _bld_wall_color("SUBURBAN_HOUSE", sat_col)
	var roof_col := _bld_roof_color("SUBURBAN_HOUSE", sat_col)
	var h := 1.9 + _rng.randf() * 1.2
	var bw := TCELL * 0.70; var bd := TCELL * 0.70
	var body := _box(Vector3(bw, h, bd), _mat(wall_col))
	body.position = Vector3(px, h * 0.5, pz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)
	var rh := 0.55 + _rng.randf() * 0.20
	var rw := bw + 0.12
	for side: float in [-1.0, 1.0]:
		var rp := _box(Vector3(rw, 0.10, bd * 0.55 + 0.08), _mat(roof_col))
		rp.position = Vector3(px, h + rh * 0.5, pz + side * bd * 0.26)
		rp.rotation.x = side * deg_to_rad(32.0)
		add_child(rp)
	var rdg := _box(Vector3(rw, 0.14, 0.18), _mat(roof_col.darkened(0.16)))
	rdg.position = Vector3(px, h + rh, pz); add_child(rdg)
	var chim := _box(Vector3(0.18, 0.44, 0.18), _mat(Color(0.45, 0.28, 0.20)))
	chim.position = Vector3(px - bw*0.22, h + rh + 0.18, pz); add_child(chim)
	var porch := _box(Vector3(bw*0.45, 0.08, 0.55), _mat(wall_col.lightened(0.08)))
	porch.position = Vector3(px, h - 0.04, pz + bd*0.5 + 0.27); add_child(porch)

func _build_bld_industrial(px: float, pz: float, sat_col: Color) -> void:
	var wall_col := _bld_wall_color("INDUSTRIAL", sat_col)
	var roof_col := _bld_roof_color("INDUSTRIAL", sat_col)
	var h := 1.8 + _rng.randf() * 1.4
	var bw := TCELL * 0.76; var bd := TCELL * 0.76
	var body := _box(Vector3(bw, h, bd), _mat(wall_col))
	body.position = Vector3(px, h * 0.5, pz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)
	var roof_slab := _box(Vector3(bw + 0.06, 0.14, bd + 0.06), _mat(roof_col))
	roof_slab.position = Vector3(px, h + 0.07, pz); add_child(roof_slab)
	var skyl_n := 2 + _rng.randi() % 2
	for si in skyl_n:
		var fi := (float(si) + 0.5) / float(skyl_n)
		var skyl_cm := CylinderMesh.new()
		skyl_cm.top_radius = 0.14; skyl_cm.bottom_radius = 0.14
		skyl_cm.height = bw * 0.82; skyl_cm.radial_segments = 8
		var skyl := MeshInstance3D.new(); skyl.mesh = skyl_cm
		skyl.set_surface_override_material(0, _mat(Color(0.55, 0.58, 0.60)))
		skyl.rotation.z = PI * 0.5
		skyl.position = Vector3(px, h + 0.22, pz + (fi - 0.5) * bd * 0.70)
		add_child(skyl)
	var dock := _box(Vector3(bw * 0.44, h * 0.54, 0.30), _mat(wall_col.darkened(0.12)))
	dock.position = Vector3(px - bw*0.20, h * 0.27, pz - bd*0.5 - 0.15); add_child(dock)

func _build_bld_stone_historic(px: float, pz: float, sat_col: Color) -> void:
	var wall_col := _bld_wall_color("STONE_HISTORIC", sat_col)
	var roof_col := _bld_roof_color("STONE_HISTORIC", sat_col)
	var h := 3.2 + _rng.randf() * 2.0
	var bw := TCELL * 0.68; var bd := TCELL * 0.68
	var body := _box(Vector3(bw, h, bd), _mat(wall_col))
	body.position = Vector3(px, h * 0.5, pz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)
	var roof_cap := _box(Vector3(bw + 0.08, 0.20, bd + 0.08), _mat(roof_col))
	roof_cap.position = Vector3(px, h + 0.10, pz); add_child(roof_cap)
	var corn := _box(Vector3(bw + 0.14, 0.12, bd + 0.14), _mat(wall_col.lightened(0.08)))
	corn.position = Vector3(px, h - 0.18, pz); add_child(corn)
	if h > 4.5:
		var tw := 0.45; var th := h * 0.60
		var tower := _box(Vector3(tw, th, tw), _mat(wall_col.darkened(0.10)))
		tower.position = Vector3(px + bw*0.5 - tw*0.5, h + th*0.5, pz + bd*0.5 - tw*0.5)
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(tower)
		var tcap := _box(Vector3(tw + 0.08, 0.16, tw + 0.08), _mat(roof_col))
		tcap.position = Vector3(px + bw*0.5 - tw*0.5, h + th + 0.08, pz + bd*0.5 - tw*0.5)
		add_child(tcap)

func _sample_sat(wx: float, wz: float) -> Color:
	if _sat_img == null: return Color(0.08, 0.18, 0.05)
	var px := clampi(int((wx + HALF) / (HALF * 2.0) * _sat_img.get_width()),  0, _sat_img.get_width()  - 1)
	var pz := clampi(int((wz + HALF) / (HALF * 2.0) * _sat_img.get_height()), 0, _sat_img.get_height() - 1)
	return _sat_img.get_pixel(px, pz)

func _classify_tree(col: Color) -> String:
	# Satellite pixels are top-down and dim; analyse green channel dominance + brightness
	var r := col.r; var g := col.g; var b := col.b
	var brightness  := (r + g + b) / 3.0
	var greenness   := g - (r * 0.55 + b * 0.45)
	var warmth      := r / maxf(g, 0.01)   # >1 = warm/yellow, <0.7 = cool blue-green
	if greenness < 0.015 or brightness < 0.04: return "SHRUB"
	if brightness < 0.13 and greenness > 0.03: return "CONIFER"
	if warmth > 0.78 and brightness > 0.19:    return "BIRCH"
	if brightness > 0.24 and warmth < 0.68:    return "COLUMNAR"
	return "DECIDUOUS"

func _tree_base_color(tree_type: String, sat_col: Color) -> Color:
	# Amplify satellite colour (top-view is compressed) and shift per-type RGB ratios
	var sg := clampf(sat_col.g * 2.0, 0.0, 1.0)
	match tree_type:
		"CONIFER":  return Color(0.04 + sg*0.04, 0.11 + sg*0.11, 0.02 + sg*0.02)
		"BIRCH":    return Color(0.12 + sg*0.09, 0.28 + sg*0.16, 0.06 + sg*0.07)
		"COLUMNAR": return Color(0.05 + sg*0.06, 0.16 + sg*0.13, 0.03 + sg*0.03)
		"SHRUB":    return Color(0.05 + sg*0.05, 0.12 + sg*0.10, 0.02 + sg*0.02)
		_:          return Color(0.07 + sg*0.07, 0.19 + sg*0.13, 0.04 + sg*0.04)  # DECIDUOUS

func _get_tree_mat(tree_type: String) -> ShaderMaterial:
	if _tree_mats.has(tree_type):
		return _tree_mats[tree_type] as ShaderMaterial
	var s := Shader.new()
	s.code = _tree_conifer_shader_code() if tree_type == "CONIFER" else _tree_crown_shader_code()
	var mat := ShaderMaterial.new(); mat.shader = s
	_tree_mats[tree_type] = mat
	return mat

func _mesh_with_color(prim: PrimitiveMesh, col: Color) -> ArrayMesh:
	var sv: Array = prim.get_mesh_arrays()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sv[Mesh.ARRAY_VERTEX]
	arrays[Mesh.ARRAY_NORMAL] = sv[Mesh.ARRAY_NORMAL]
	if sv[Mesh.ARRAY_TEX_UV] != null: arrays[Mesh.ARRAY_TEX_UV] = sv[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector3Array = sv[Mesh.ARRAY_VERTEX]
	var vc := PackedColorArray(); vc.resize(verts.size()); vc.fill(col)
	arrays[Mesh.ARRAY_COLOR] = vc
	if sv[Mesh.ARRAY_INDEX] != null: arrays[Mesh.ARRAY_INDEX] = sv[Mesh.ARRAY_INDEX]
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am

func _place_tree(px: float, pz: float) -> void:
	# Sample satellite to classify tree type for this cell
	var sat_col := _sample_sat(px, pz)
	var tree_type := _classify_tree(sat_col)
	var base_col  := _tree_base_color(tree_type, sat_col)
	# Type-specific count and spread
	var count := 2 + _rng.randi() % 3
	var spread := TCELL * (0.70 if tree_type in ["BIRCH","CONIFER"] else 0.85)
	for _i in count:
		var ox := (_rng.randf() - 0.5) * spread
		var oz := (_rng.randf() - 0.5) * spread
		var sx := 0.60 + _rng.randf() * 0.65
		match tree_type:
			"CONIFER":  _build_tree_conifer(px+ox, pz+oz, sx, base_col)
			"BIRCH":    _build_tree_birch(px+ox, pz+oz, sx, base_col)
			"COLUMNAR": _build_tree_columnar(px+ox, pz+oz, sx, base_col)
			"SHRUB":    _build_tree_shrub(px+ox, pz+oz, sx, base_col)
			_:          _build_tree_deciduous(px+ox, pz+oz, sx, base_col)

func _trunk(rx: float, rz: float, trunk_h: float, top_r: float, bot_r: float, col: Color) -> void:
	var tm := CylinderMesh.new()
	tm.top_radius = top_r; tm.bottom_radius = bot_r; tm.height = trunk_h; tm.radial_segments = 6
	var t := MeshInstance3D.new(); t.mesh = tm
	t.set_surface_override_material(0, _mat(col))
	t.position = Vector3(rx, trunk_h * 0.5, rz)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(t)

func _crown_sphere(rx: float, ry: float, rz: float, radius: float, height_r: float,
		col: Color, tree_type: String, segs: int = 8, rings: int = 6) -> void:
	var sm := SphereMesh.new(); sm.radius = radius; sm.height = radius * height_r
	sm.radial_segments = segs; sm.rings = rings
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_with_color(sm, col)
	mi.set_surface_override_material(0, _get_tree_mat(tree_type))
	mi.position = Vector3(rx, ry, rz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

func _build_tree_deciduous(rx: float, rz: float, sx: float, col: Color) -> void:
	var trunk_h := (0.80 + _rng.randf() * 0.65) * sx
	_trunk(rx, rz, trunk_h, 0.07*sx, 0.14*sx, Color(0.22+_rng.randf()*0.09, 0.14, 0.06))
	# Large main crown
	var cr := (0.50 + _rng.randf() * 0.38) * sx
	var mc := Color(col.r*(0.92+_rng.randf()*0.16), col.g*(0.95+_rng.randf()*0.10), col.b*(0.90+_rng.randf()*0.16))
	_crown_sphere(rx, trunk_h + cr*0.80, rz, cr, 1.35, mc, "DECIDUOUS")
	# 2–4 offset lobes for organic silhouette
	for _l in (2 + _rng.randi() % 3):
		var angle := _rng.randf() * TAU
		var dist  := cr * (0.42 + _rng.randf() * 0.38)
		var lr    := cr  * (0.42 + _rng.randf() * 0.32)
		var lc := Color(col.r*(0.84+_rng.randf()*0.28), col.g*(0.88+_rng.randf()*0.18), col.b*(0.84+_rng.randf()*0.26))
		_crown_sphere(rx + cos(angle)*dist, trunk_h + cr*0.60 + (_rng.randf()-0.3)*cr*0.45,
				rz + sin(angle)*dist, lr, 1.25, lc, "DECIDUOUS", 7, 5)

func _build_tree_conifer(rx: float, rz: float, sx: float, col: Color) -> void:
	var trunk_h := (1.10 + _rng.randf() * 0.90) * sx
	_trunk(rx, rz, trunk_h, 0.04*sx, 0.08*sx, Color(0.17+_rng.randf()*0.07, 0.10, 0.04))
	# Stacked cone tiers: bottom widest, each successive one narrower & higher
	var tier_n := 3 + _rng.randi() % 2
	var tier_y := trunk_h
	for tier in tier_n:
		var t_frac := float(tier) / float(tier_n)
		var base_r := (0.55 - t_frac * 0.36) * sx
		var h      := (0.52 + _rng.randf() * 0.14) * sx
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015; cm.bottom_radius = base_r; cm.height = h; cm.radial_segments = 7
		var dark := clampf(0.82 + _rng.randf() * 0.22, 0.0, 1.0)
		var tc := Color(col.r*dark, col.g*dark, col.b*dark)
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh_with_color(cm, tc)
		mi.set_surface_override_material(0, _get_tree_mat("CONIFER"))
		mi.position = Vector3(rx, tier_y + h*0.5, rz)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		tier_y += h * 0.52  # next tier overlaps slightly

func _build_tree_columnar(rx: float, rz: float, sx: float, col: Color) -> void:
	# Tall, narrow profile — poplar / cypress
	var trunk_h := (0.90 + _rng.randf() * 0.50) * sx
	_trunk(rx, rz, trunk_h, 0.06*sx, 0.10*sx, Color(0.24+_rng.randf()*0.07, 0.16, 0.07))
	# Very tall narrow ellipse crown
	var cr := (0.24 + _rng.randf() * 0.10) * sx
	var height_r := 4.0 + _rng.randf() * 1.5
	var mc := Color(col.r*(0.88+_rng.randf()*0.18), col.g*(0.92+_rng.randf()*0.12), col.b*(0.85+_rng.randf()*0.18))
	_crown_sphere(rx, trunk_h + cr * height_r * 0.45, rz, cr, height_r, mc, "DECIDUOUS", 7, 8)
	# Second narrower crown above
	var cr2 := cr * (0.65 + _rng.randf() * 0.20)
	var c2 := Color(mc.r*(0.90+_rng.randf()*0.14), mc.g*(0.94+_rng.randf()*0.10), mc.b*(0.88+_rng.randf()*0.14))
	_crown_sphere(rx, trunk_h + cr*height_r*0.82 + cr2*height_r*0.45, rz, cr2, height_r, c2, "DECIDUOUS", 6, 7)

func _build_tree_birch(rx: float, rz: float, sx: float, col: Color) -> void:
	# Pale slender trunk, airy multi-cluster canopy
	var trunk_h := (0.90 + _rng.randf() * 0.70) * sx
	_trunk(rx, rz, trunk_h, 0.04*sx, 0.07*sx, Color(0.72+_rng.randf()*0.18, 0.70+_rng.randf()*0.14, 0.62+_rng.randf()*0.12))
	# Several small airy spheres in loose arrangement
	var cluster := 3 + _rng.randi() % 3
	for ci in cluster:
		var fi := float(ci) / float(cluster)
		var angle := fi * TAU * 0.72 + _rng.randf() * 0.8
		var dist  := (0.18 + _rng.randf() * 0.22) * sx
		var cr    := (0.22 + _rng.randf() * 0.18) * sx
		var light := 1.05 + _rng.randf() * 0.25  # birch leaves are lighter
		var bc := Color(clampf(col.r*light, 0.0, 1.0), clampf(col.g*light, 0.0, 1.0), clampf(col.b*light, 0.0, 1.0))
		_crown_sphere(rx + cos(angle)*dist,
				trunk_h + cr*0.9 + fi * cr * 1.2 + _rng.randf()*cr*0.4,
				rz + sin(angle)*dist, cr, 1.20, bc, "DECIDUOUS", 7, 5)

func _build_tree_shrub(rx: float, rz: float, sx: float, col: Color) -> void:
	# Low, wide, dense — no trunk or very short stub
	var stub_h := _rng.randf() * 0.22 * sx
	if stub_h > 0.06:
		_trunk(rx, rz, stub_h, 0.05*sx, 0.09*sx, Color(0.20, 0.14, 0.06))
	# 3–5 low overlapping spheres
	var n := 3 + _rng.randi() % 3
	for _si in n:
		var angle := _rng.randf() * TAU
		var dist  := (0.05 + _rng.randf() * 0.28) * sx
		var cr    := (0.25 + _rng.randf() * 0.22) * sx
		var dark  := 0.80 + _rng.randf() * 0.30
		var sc := Color(col.r*dark, col.g*dark, col.b*dark)
		_crown_sphere(rx + cos(angle)*dist, stub_h + cr*0.55 + _rng.randf()*cr*0.25,
				rz + sin(angle)*dist, cr, 0.85, sc, "DECIDUOUS", 6, 4)

func _place_water(px: float, pz: float) -> void:
	if _water_mat == null:
		var s := Shader.new()
		s.code = _water_shader_code()
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = s
	var pm := PlaneMesh.new()
	pm.size = Vector2(TCELL, TCELL)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	var m := MeshInstance3D.new()
	m.mesh = pm
	m.set_surface_override_material(0, _water_mat)
	m.position = Vector3(px, 0.04, pz)
	add_child(m)

func _place_street_light(px: float, pz: float) -> void:
	var pole := _box(Vector3(0.07, 4.0, 0.07), _mat(Color(0.58, 0.58, 0.55)))
	pole.position = Vector3(px, 2.0, pz); add_child(pole)
	var arm := _box(Vector3(0.90, 0.06, 0.06), _mat(Color(0.58, 0.58, 0.55)))
	arm.position = Vector3(px+0.45, 3.96, pz); add_child(arm)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color    = Color(1.0, 0.94, 0.78)
	lamp_mat.emission_enabled = true
	lamp_mat.emission        = Color(1.0, 0.88, 0.62) * 3.0
	lamp_mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lamp := _box(Vector3(0.24, 0.12, 0.24), lamp_mat)
	lamp.position = Vector3(px+0.92, 3.91, pz); add_child(lamp)
	var omni := OmniLight3D.new()
	omni.light_color  = Color(1.0, 0.92, 0.72)
	omni.light_energy = 1.4
	omni.omni_range   = 9.0
	omni.position     = Vector3(px+0.92, 3.86, pz)
	add_child(omni)

func _place_car(px: float, pz: float, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(px, 0.0, pz); n.rotation.y = rot_y; add_child(n)
	var body_col := Color(_rng.randf_range(0.15,0.75), _rng.randf_range(0.10,0.70), _rng.randf_range(0.10,0.70))
	var body := _box(Vector3(0.80, 0.36, 1.60), _mat(body_col))
	body.position = Vector3(0.0, 0.31, 0.0); n.add_child(body)
	var cab := _box(Vector3(0.72, 0.26, 0.82), _mat(Color(0.20, 0.22, 0.20)))
	cab.position = Vector3(0.0, 0.55, -0.08); n.add_child(cab)
	var win_mat := _mat_new(Color(0.32, 0.46, 0.58, 0.78))
	win_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wx: float in [-0.37, 0.37]:
		var win := _box(Vector3(0.04, 0.17, 0.54), win_mat)
		win.position = Vector3(wx, 0.54, -0.07); n.add_child(win)
	var wmat := _mat(Color(0.10, 0.10, 0.10))
	for wz: float in [-0.54, 0.54]:
		for wx: float in [-0.42, 0.42]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.13; wm.bottom_radius = 0.13
			wm.height = 0.12; wm.radial_segments = 8
			var wheel := MeshInstance3D.new(); wheel.mesh = wm
			wheel.set_surface_override_material(0, wmat)
			wheel.rotation.z = PI/2.0
			wheel.position = Vector3(wx, 0.13, wz); n.add_child(wheel)

func _block_buildings(blk: Array) -> void:
	var bw: int = int(blk[3]) - int(blk[1]) + 1
	var bh_t: int = int(blk[2]) - int(blk[0]) + 1
	# Paved base (parking / sidewalk)
	var base := _box(Vector3(float(bw)*TCELL-0.1, 0.04, float(bh_t)*TCELL-0.1), _mat(Color(0.52,0.52,0.50)))
	base.position = Vector3(_tx(int(blk[1]))+float(bw-1)*TCELL*0.5, 0.02, _tz(int(blk[0]))+float(bh_t-1)*TCELL*0.5)
	add_child(base)
	var nb: int = 1 + int(_rng.randf()*3.0)
	for _i in nb:
		var c: int = int(blk[1]) + int(_rng.randf()*float(bw))
		var r: int = int(blk[0]) + int(_rng.randf()*float(bh_t))
		c = clampi(c, 0, TG-1); r = clampi(r, 0, TG-1)
		_place_building(_tx(c), _tz(r), r, c)
		tmap[r][c] = TILE_BUILDING

func _block_park(blk: Array) -> void:
	var bw: int = int(blk[3]) - int(blk[1]) + 1
	var bh_t: int = int(blk[2]) - int(blk[0]) + 1
	var grass := _box(Vector3(float(bw)*TCELL-0.1, 0.05, float(bh_t)*TCELL-0.1), _mat(Color(0.18,0.38,0.12)))
	grass.position = Vector3(_tx(int(blk[1]))+float(bw-1)*TCELL*0.5, 0.025, _tz(int(blk[0]))+float(bh_t-1)*TCELL*0.5)
	add_child(grass)
	var count: int = int(float(bw*bh_t)*0.4)
	for _i in count:
		var c: int = int(blk[1]) + int(_rng.randf()*float(bw))
		var r: int = int(blk[0]) + int(_rng.randf()*float(bh_t))
		c = clampi(c, 0, TG-1); r = clampi(r, 0, TG-1)
		_place_tree(_tx(c), _tz(r))
		tmap[r][c] = TILE_TREE

func _has_building_neighbor(r: int, c: int) -> bool:
	for dr: int in [-1, 0, 1]:
		for dc: int in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			var nr: int = r + dr; var nc: int = c + dc
			if nr >= 0 and nr < TG and nc >= 0 and nc < TG:
				if tmap[nr][nc] == TILE_BUILDING: return true
	return false

func _scatter_terrain_trees() -> void:
	# In OSM maps most open ground has no explicit vegetation tag — scatter trees
	# in TILE_GROUND cells at ~18% density, leaving HQ approach lanes clear.
	var hq_c  := clampi(int((HQ_X  + HALF) / TCELL), 0, TG - 1)
	var hq_r  := clampi(int((HQ_Z  + HALF) / TCELL), 0, TG - 1)
	var ehq_c := clampi(int((-HQ_X + HALF) / TCELL), 0, TG - 1)
	var ehq_r := clampi(int((-HQ_Z + HALF) / TCELL), 0, TG - 1)
	for r in TG:
		for c in TG:
			if tmap[r][c] != TILE_GROUND: continue
			if abs(r - hq_r) <= 3 and abs(c - hq_c) <= 3: continue
			if abs(r - ehq_r) <= 3 and abs(c - ehq_c) <= 3: continue
			if _has_building_neighbor(r, c): continue
			if _rng.randf() < 0.18:
				_place_tree(_tx(c), _tz(r))
				tmap[r][c] = TILE_TREE

func _block_rubble(blk: Array) -> void:
	var bw: int = int(blk[3]) - int(blk[1]) + 1
	var bh_t: int = int(blk[2]) - int(blk[0]) + 1
	var cx: float = _tx(int(blk[1])) + float(bw-1)*TCELL*0.5
	var cz: float = _tz(int(blk[0])) + float(bh_t-1)*TCELL*0.5
	var base := _box(Vector3(float(bw)*TCELL-0.1, 0.04, float(bh_t)*TCELL-0.1), _mat(Color(0.38,0.34,0.28)))
	base.position = Vector3(cx, 0.02, cz)
	add_child(base)
	for _i in bw*bh_t*2:
		var sz: float = 0.15 + _rng.randf()*0.45
		var rm := _box(Vector3(sz, sz*0.4, sz), _mat(Color(0.50+_rng.randf()*0.1, 0.44+_rng.randf()*0.08, 0.36)))
		rm.position = Vector3(cx+((_rng.randf()-0.5)*float(bw)*TCELL), sz*0.2, cz+((_rng.randf()-0.5)*float(bh_t)*TCELL))
		rm.rotation.y = _rng.randf()*TAU
		add_child(rm)

func _hq_zone(pos: Vector3, color: Color, _label: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := MeshInstance3D.new()
	disc.mesh = CylinderMesh.new()
	(disc.mesh as CylinderMesh).top_radius = 3.5
	(disc.mesh as CylinderMesh).bottom_radius = 3.5
	(disc.mesh as CylinderMesh).height = 0.06
	(disc.mesh as CylinderMesh).radial_segments = 24
	disc.set_surface_override_material(0, mat)
	disc.position = Vector3(pos.x, 0.03, pos.z)
	add_child(disc)

func _build_boundary() -> void:
	for side: Array in [
		[Vector3(0.0,0.75,-HALF),   Vector3(HALF*2.0,1.5,0.5)],
		[Vector3(0.0,0.75, HALF),   Vector3(HALF*2.0,1.5,0.5)],
		[Vector3(-HALF,0.75,0.0),   Vector3(0.5,1.5,HALF*2.0)],
		[Vector3( HALF,0.75,0.0),   Vector3(0.5,1.5,HALF*2.0)],
	]:
		var bm := _box(side[1], _mat(Color(0.20,0.24,0.18)))
		bm.position = side[0]
		add_child(bm)

# ── CAPTURE POINTS ─────────────────────────────────────────────

func _init_capture_points() -> void:
	for v in CP_DEFS:
		var bld_tile := _find_building_near(v.x, v.y)
		# Guard: don't reuse a tile claimed by an earlier CP
		for prev in capture_points:
			if prev.get("tile") == bld_tile:
				bld_tile = Vector2i(-1, -1); break
		if bld_tile != Vector2i(-1, -1):
			# A building is nearby — use it as the CP (building garrison rules, 70% dmg reduction)
			var bx := _tx(bld_tile.y); var bz := _tz(bld_tile.x)
			var cp := {"x": bx, "z": bz, "owner":"neutral","progress":0.0,"node":null,"tile":bld_tile}
			cp.node = _build_cp_flag(bx, bz)
			capture_points.append(cp)
		else:
			# No building nearby — spawn a dedicated sandbag bunker (75% dmg reduction)
			var pos   := _find_open_near(v.x, v.y)
			var cr    := clampi(int((pos.y + HALF) / TCELL), 0, TG - 1)
			var cc    := clampi(int((pos.x + HALF) / TCELL), 0, TG - 1)
			var ctile := Vector2i(cr, cc)
			var cp    := {"x": pos.x, "z": pos.y, "owner":"neutral","progress":0.0,"node":null,"tile":ctile}
			cp.node   = _build_cp(pos.x, pos.y)
			_bunker_tiles[ctile] = true
			capture_points.append(cp)

func _find_open_near(wx: float, wz: float) -> Vector2:
	var col0 := clampi(int((wx + HALF) / TCELL), 0, TG - 1)
	var row0 := clampi(int((wz + HALF) / TCELL), 0, TG - 1)
	if tmap[row0][col0] != TILE_BUILDING and tmap[row0][col0] != TILE_WATER:
		return Vector2(_tx(col0), _tz(row0))
	for radius in range(1, TG):
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				if abs(dr) != radius and abs(dc) != radius: continue
				var r := row0 + dr; var c := col0 + dc
				if r < 0 or r >= TG or c < 0 or c >= TG: continue
				if tmap[r][c] != TILE_BUILDING and tmap[r][c] != TILE_WATER:
					return Vector2(_tx(c), _tz(r))
	return Vector2(wx, wz)

func _find_building_near(wx: float, wz: float) -> Vector2i:
	var col0 := clampi(int((wx + HALF) / TCELL), 0, TG - 1)
	var row0 := clampi(int((wz + HALF) / TCELL), 0, TG - 1)
	for radius in range(0, 4):
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				if abs(dr) != radius and abs(dc) != radius: continue
				var r := row0 + dr; var c := col0 + dc
				if r < 0 or r >= TG or c < 0 or c >= TG: continue
				if tmap[r][c] == TILE_BUILDING:
					return Vector2i(r, c)
	return Vector2i(-1, -1)

func _build_cp(px: float, pz: float) -> Node3D:
	var n := Node3D.new(); n.position = Vector3(px, 0.0, pz)
	# Concrete base
	var base := _box(Vector3(2.6, 0.32, 2.6), _mat(Color(0.36, 0.34, 0.30)))
	base.position.y = 0.16; n.add_child(base)
	# Sandbag walls — N/S run along X, E/W run along Z
	var sb := Color(0.58, 0.52, 0.33)
	for side: float in [-1.0, 1.0]:
		var wns := _box(Vector3(2.2, 0.62, 0.42), _mat(sb))
		wns.position = Vector3(0.0, 0.63, side * 1.0); n.add_child(wns)
		var tns := _box(Vector3(1.9, 0.26, 0.36), _mat(sb.darkened(0.12)))
		tns.position = Vector3(0.0, 1.07, side * 0.98); n.add_child(tns)
		var wew := _box(Vector3(0.42, 0.62, 2.2), _mat(sb))
		wew.position = Vector3(side * 1.0, 0.63, 0.0); n.add_child(wew)
		var tew := _box(Vector3(0.36, 0.26, 1.9), _mat(sb.darkened(0.12)))
		tew.position = Vector3(side * 0.98, 1.07, 0.0); n.add_child(tew)
	# Flag pole
	var pole := _box(Vector3(0.06, 1.85, 0.06), _mat(Color(0.68, 0.68, 0.68)))
	pole.position = Vector3(0.0, 1.25, 0.0); n.add_child(pole)
	# Flag — emissive, colour changes with ownership
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color    = Color(0.85, 0.82, 0.18)
	flag_mat.emission_enabled = true
	flag_mat.emission         = Color(0.85, 0.82, 0.18) * 0.5
	flag_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flag := _box(Vector3(0.55, 0.32, 0.04), flag_mat)
	flag.name = "Flag"; flag.position = Vector3(0.30, 2.08, 0.0); n.add_child(flag)
	# Capture indicator ring
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color    = Color(1.0, 0.85, 0.10)
	ring_mat.emission_enabled = true
	ring_mat.emission         = Color(1.0, 0.85, 0.10) * 0.45
	ring_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rim := TorusMesh.new(); rim.inner_radius = 1.55; rim.outer_radius = 1.82
	var ring := MeshInstance3D.new(); ring.mesh = rim; ring.name = "Ring"
	ring.set_surface_override_material(0, ring_mat)
	ring.rotation.x = -PI * 0.5; ring.position.y = 0.04; n.add_child(ring)
	# Garrison occupant count — shown above the flag when units are inside
	var gcount := Label3D.new()
	gcount.name = "GCount"
	gcount.pixel_size = 0.009
	gcount.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gcount.modulate = Color(0.28, 1.0, 0.43)
	gcount.outline_size = 4
	gcount.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	gcount.position = Vector3(0.0, 2.4, 0.0)
	gcount.visible = false
	n.add_child(gcount)
	add_child(n); return n

# Lightweight CP marker placed on top of an existing building — flag + ring only, no sandbag walls.
func _build_cp_flag(px: float, pz: float) -> Node3D:
	var n := Node3D.new(); n.position = Vector3(px, 0.0, pz)
	# Tall pole so the flag clears the building roofline (~2 m typical height)
	var pole := _box(Vector3(0.06, 2.8, 0.06), _mat(Color(0.68, 0.68, 0.68)))
	pole.position = Vector3(0.0, 2.4, 0.0); n.add_child(pole)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color     = Color(0.85, 0.82, 0.18)
	flag_mat.emission_enabled = true
	flag_mat.emission         = Color(0.85, 0.82, 0.18) * 0.5
	flag_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flag := _box(Vector3(0.55, 0.32, 0.04), flag_mat)
	flag.name = "Flag"; flag.position = Vector3(0.30, 3.95, 0.0); n.add_child(flag)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color    = Color(1.0, 0.85, 0.10)
	ring_mat.emission_enabled = true
	ring_mat.emission         = Color(1.0, 0.85, 0.10) * 0.45
	ring_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rim := TorusMesh.new(); rim.inner_radius = 1.55; rim.outer_radius = 1.82
	var ring := MeshInstance3D.new(); ring.mesh = rim; ring.name = "Ring"
	ring.set_surface_override_material(0, ring_mat)
	ring.rotation.x = -PI * 0.5; ring.position.y = 0.04; n.add_child(ring)
	var gcount := Label3D.new()
	gcount.name = "GCount"
	gcount.pixel_size = 0.009
	gcount.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gcount.modulate = Color(0.28, 1.0, 0.43)
	gcount.outline_size = 4
	gcount.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	gcount.position = Vector3(0.0, 4.4, 0.0)
	gcount.visible = false
	n.add_child(gcount)
	add_child(n); return n

func _update_capture_points(delta: float) -> void:
	var bonus: float = 0.0
	for cp in capture_points:
		var cp_pos := Vector3(float(cp.x),0.0,float(cp.z))
		var has_p := false; var has_e := false
		for u in units:
			var unit := u as Unit
			if unit == null or unit.hp <= 0: continue
			if unit.global_position.distance_to(cp_pos) < 2.6:
				if unit.team == "player": has_p = true
				else: has_e = true
		if has_p and not has_e:
			cp.progress = minf(1.0, float(cp.progress)+delta/5.0)
			if float(cp.progress) >= 1.0 and cp.owner != "player":
				cp.owner = "player"
				_set_cp_color(cp, Color(0.3,1.0,0.43))
				_set_status("CAPTURE POINT SECURED! +15 SUPPLIES/s")
				Sounds.play("capture", -2.0)
		elif has_e and not has_p:
			cp.progress = maxf(0.0, float(cp.progress)-delta/5.0)
			if float(cp.progress) <= 0.0 and cp.owner != "enemy":
				cp.owner = "enemy"
				_set_cp_color(cp, Color(1.0,0.2,0.15))
				_set_status("CAPTURE POINT LOST!")
				Sounds.play("capture_lost", -2.0)
		if cp.owner == "player": bonus += 15.0
		# Animate capture ring: scale with progress, pulse when being captured
		if cp.node:
			var ring := cp.node.get_node_or_null("Ring") as MeshInstance3D
			if ring:
				var prog := float(cp.progress)
				var s := 0.35 + prog * 0.65
				ring.scale = Vector3(s, s, s)
				ring.visible = true
	supply_accum += delta * (20.0 + bonus)
	if supply_accum >= 1.0:
		supplies += int(supply_accum)
		supply_accum = fmod(supply_accum, 1.0)

func _nearest_contestable_cp(from_pos: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_dist := INF
	for cp in capture_points:
		if cp.owner == "enemy": continue
		var cp_pos := Vector3(float(cp.x), 0.0, float(cp.z))
		var d := from_pos.distance_to(cp_pos)
		if d < best_dist:
			best_dist = d; best = cp_pos
	return best

# ── GARRISON SYSTEM ───────────────────────────────────────────

func _nearest_passable_adjacent(r: int, c: int) -> Vector2i:
	for dr: int in [-1, 0, 1]:
		for dc: int in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			var nr: int = r + dr; var nc: int = c + dc
			if _is_passable(nr, nc): return Vector2i(nr, nc)
	return Vector2i(-1, -1)

func _order_garrison(tile: Vector2i) -> void:
	var existing := _garrisons.get(tile, []) as Array
	var slots := GARRISON_MAX - existing.size()
	var is_bunker := _bunker_tiles.has(tile)
	var label := "BUNKER" if is_bunker else "BUILDING"
	if slots <= 0: _set_status("%s FULL (%d/%d)" % [label, GARRISON_MAX, GARRISON_MAX]); return
	var dest: Vector3
	if is_bunker:
		# CP tiles are passable — move directly to centre
		dest = Vector3(_tx(tile.y), 0.0, _tz(tile.x))
	else:
		var adj := _nearest_passable_adjacent(tile.x, tile.y)
		if adj == Vector2i(-1, -1): _set_status("%s NOT ACCESSIBLE" % label); return
		dest = Vector3(_tx(adj.y), 0.0, _tz(adj.x))
	var filled := 0
	for su in sel_units:
		var u := su as Unit
		if u == null or u.hp <= 0 or u.garrisoned or u.team != "player": continue
		if filled >= slots: break
		_move_with_path(u, dest)
		u.garrison_pending = tile   # set AFTER _move_with_path (which clears it)
		filled += 1
	if filled > 0:
		_set_status("MOVING TO %s — %d UNIT(S)  |  TAP ✕ TO CANCEL" % [label, filled])
	else:
		_set_status("NO ELIGIBLE UNITS TO GARRISON")

func _do_garrison(u: Unit, tile: Vector2i) -> void:
	var existing := _garrisons.get(tile, []) as Array
	if existing.size() >= GARRISON_MAX: return
	if not _garrisons.has(tile): _garrisons[tile] = []
	(_garrisons[tile] as Array).append(u)
	u.garrisoned      = true
	u.garrison_tile   = tile
	u.in_cover        = true
	u.state           = Unit.State.HOLDING
	# Move to building centre (slightly elevated so label/HPbar float above roof)
	u.position = Vector3(_tx(tile.y), 0.0, _tz(tile.x))
	# Hide 3D body mesh; HP bar and unit label remain visible above the building
	var body := u.get_node_or_null("Body") as Node3D
	if body: body.visible = false
	_refresh_garrison_indicator(tile)
	if u.team == "player":
		if _bunker_tiles.has(tile):
			_set_status("IN BUNKER — 75%% DMG REDUCTION  |  ABILITY BUTTON TO EXIT")
		else:
			_set_status("UNIT GARRISONED — FIRING FROM BUILDING  |  USE ABILITY BUTTON TO EXIT")

func _exit_garrison(u: Unit) -> void:
	if not u.garrisoned: return
	_garrison_remove(u)
	# Place unit at adjacent passable tile
	var adj := _nearest_passable_adjacent(u.garrison_tile.x, u.garrison_tile.y)
	var exit_tile := adj if adj != Vector2i(-1, -1) else Vector2i(
		clampi(u.garrison_tile.x, 1, TG-2), clampi(u.garrison_tile.y, 1, TG-2))
	u.position = Vector3(_tx(exit_tile.y), 0.0, _tz(exit_tile.x))
	u.garrisoned    = false
	u.garrison_tile = Vector2i(-1, -1)
	u.in_cover      = false
	var body := u.get_node_or_null("Body") as Node3D
	if body: body.visible = true

func _garrison_remove(u: Unit) -> void:
	var tile := u.garrison_tile
	if _garrisons.has(tile):
		(_garrisons[tile] as Array).erase(u)
		if (_garrisons[tile] as Array).is_empty(): _garrisons.erase(tile)
	_refresh_garrison_indicator(tile)

func _tick_garrisoned(u: Unit) -> void:
	# Fire from building centre at enemies in extended range
	if u.fire_timer > 0.0: return
	var garrison_range := u.attack_range + GARRISON_RANGE_BONUS
	var opp := "enemy" if u.team == "player" else "player"
	var best: Unit = null; var best_dist := INF
	for ou in units:
		var t := ou as Unit
		if t == null or t.hp <= 0 or t.team != opp: continue
		var d := u.global_position.distance_to(t.global_position)
		if d < garrison_range and d < best_dist and _has_los(u.global_position, t.global_position):
			best_dist = d; best = t
	if best: _fire(u, best)

func _refresh_garrison_indicator(tile: Vector2i) -> void:
	# All CP tiles (bunker or building) use the GCount label on the CP node
	for cp in capture_points:
		if cp.get("tile") == tile:
			var gcount := (cp.node as Node3D).get_node_or_null("GCount") as Label3D
			if gcount:
				var garrison := _garrisons.get(tile, []) as Array
				gcount.visible = not garrison.is_empty()
				if not garrison.is_empty():
					var first := garrison[0] as Unit
					gcount.modulate = Color(0.28, 1.0, 0.43) if (first and first.team == "player") else Color(1.0, 0.22, 0.15)
					var kind := "BUNKER" if _bunker_tiles.has(tile) else "BUILDING"
					gcount.text = "IN %s: %d/%d" % [kind, garrison.size(), GARRISON_MAX]
			return
	var garrison := _garrisons.get(tile, []) as Array
	if garrison.is_empty():
		if _garrison_inds.has(tile):
			var old := _garrison_inds[tile] as Node3D
			if is_instance_valid(old): old.queue_free()
			_garrison_inds.erase(tile)
		return
	# Create indicator if missing
	if not _garrison_inds.has(tile) or not is_instance_valid(_garrison_inds.get(tile)):
		var n := Node3D.new()
		n.position = Vector3(_tx(tile.y), 2.8, _tz(tile.x))
		var pole := _box(Vector3(0.05, 1.4, 0.05), _mat(Color(0.55,0.55,0.55)))
		pole.position = Vector3(0.0, 0.0, 0.0); n.add_child(pole)
		var flag_mi := MeshInstance3D.new()
		flag_mi.mesh = BoxMesh.new()
		(flag_mi.mesh as BoxMesh).size = Vector3(0.06, 0.36, 0.26)
		flag_mi.name = "GFlag"
		flag_mi.position = Vector3(0.03, 0.55, 0.0)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flag_mi.set_surface_override_material(0, fm); n.add_child(flag_mi)
		add_child(n); _garrison_inds[tile] = n
	# Update flag color
	var ind := _garrison_inds[tile] as Node3D
	if ind == null: return
	var flag_node := ind.get_node_or_null("GFlag") as MeshInstance3D
	if flag_node:
		var mat := flag_node.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var first := (garrison[0] as Unit)
			mat.albedo_color = Color(0.25,1.0,0.4) if (first and first.team=="player") else Color(1.0,0.18,0.12)

func _try_enemy_bunker(u: Unit) -> bool:
	for cp in capture_points:
		if cp.owner != "enemy": continue
		var tile := cp.get("tile") as Vector2i
		var cp_pos := Vector3(float(cp.x), 0.0, float(cp.z))
		if u.global_position.distance_to(cp_pos) > 2.5: continue
		var existing := _garrisons.get(tile, []) as Array
		if existing.size() >= GARRISON_MAX: continue
		_do_garrison(u, tile)
		return true
	return false

func _set_cp_color(cp: Dictionary, color: Color) -> void:
	var node := cp.node as Node3D
	if node == null: return
	var flag := node.get_node_or_null("Flag") as MeshInstance3D
	if flag:
		var mat := flag.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = color
			mat.emission = color * 0.5
	var ring := node.get_node_or_null("Ring") as MeshInstance3D
	if ring:
		var mat := ring.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = color
			mat.emission = color * 0.45

# ── UNIT SPAWNING ──────────────────────────────────────────────

func spawn_unit(kind: String, team: String, px: float, pz: float) -> Unit:
	var u := Unit.new()
	var def: Dictionary = UNIT_DEFS[kind]
	u.setup(kind, team, def)
	u.position = Vector3(px, 0.0, pz)
	units_node.add_child(u)          # must be in tree before BoneAttachment3D resolves bones
	_build_unit_mesh(u, kind, team)
	var _cached_ap := _find_unit_ap(u)
	if _cached_ap: _unit_aps[u] = _cached_ap
	units.append(u)
	_add_mm_dot(u)
	return u

func _build_unit_mesh(u: Unit, kind: String, team: String) -> void:
	var is_player: bool = team == "player"
	var acc_col: Color = Color(0.30, 1.00, 0.43, 0.9) if is_player else Color(1.00, 0.25, 0.18, 0.9)

	# ── KayKit Mannequin_Medium body ─────────────────────────────
	var body := _CHAR_MAN.instantiate() as Node3D
	body.scale = Vector3(0.28, 0.28, 0.28)
	body.name = "Body"
	u.add_child(body)

	# Color mesh parts and attach equipment to bones
	_dress_mannequin(body, kind, is_player)

	# Find AnimationPlayer by TYPE (more reliable than name search)
	var ap := _anim_player_in(body)
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "UnitAP"
		body.add_child(ap)
		ap.root_node = NodePath("..")

	# Inject one library per animation GLB (skip RESET)
	_inject_anim_lib(ap, "general", _CHAR_GEN)
	_inject_anim_lib(ap, "walk",    _CHAR_WALK)
	_inject_anim_lib(ap, "combat",  _CHAR_CMBT)
	_inject_anim_lib(ap, "death",   _CHAR_DIE)

	# Start idle; _tick_unit_anim drives it every frame after that
	_play_unit_anim(ap, ["general/Idle_A", "general/Idle_B"])

	# ── Unit-type label (billboard) ───────────────────────────────
	var lbl := Label3D.new()
	lbl.text = _unit_abbrev(kind)
	lbl.pixel_size = 0.0065
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1, 1, 1, 1)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 1)
	lbl.position = Vector3(0.0, 0.85, 0.0)
	u.add_child(lbl)

	# ── Small always-visible team ring ───────────────────────────
	var ind_m := TorusMesh.new()
	ind_m.inner_radius = 0.18; ind_m.outer_radius = 0.22; ind_m.rings = 3; ind_m.ring_segments = 12
	var ind_mat := StandardMaterial3D.new()
	ind_mat.albedo_color = acc_col
	ind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ind := MeshInstance3D.new(); ind.mesh = ind_m
	ind.set_surface_override_material(0, ind_mat)
	ind.rotation.x = -PI / 2.0; ind.position.y = 0.03
	u.add_child(ind)

	# ── Selection ring (larger, hidden until selected) ────────────
	var rim_m := TorusMesh.new()
	rim_m.inner_radius = 0.52; rim_m.outer_radius = 0.58; rim_m.rings = 4; rim_m.ring_segments = 16
	var sel_mat := StandardMaterial3D.new()
	sel_mat.albedo_color = acc_col
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sel := MeshInstance3D.new(); sel.mesh = rim_m; sel.name = "SelRing"
	sel.set_surface_override_material(0, sel_mat)
	sel.rotation.x = -PI / 2.0; sel.position.y = 0.04; sel.visible = false
	u.add_child(sel)

	# ── HP bar (billboard, always faces camera) ───────────────────
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.9)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var hpbg := _box(Vector3(0.72, 0.08, 0.02), bg_mat)
	hpbg.name = "HPBg"; hpbg.position = Vector3(0.0, 0.70, 0.0); u.add_child(hpbg)

	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 0.9, 0.2)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var hpbar := _box(Vector3(0.72, 0.08, 0.02), fill_mat)
	hpbar.name = "HPBar"; hpbar.position = Vector3(0.0, 0.70, 0.001); u.add_child(hpbar)

# ── KayKit helpers ────────────────────────────────────────────────

# Recursive type-based AnimationPlayer search (more reliable than find_child by name)
func _anim_player_in(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node as AnimationPlayer
	for child in node.get_children():
		var found := _anim_player_in(child)
		if found: return found
	return null

func _find_unit_ap(u: Unit) -> AnimationPlayer:
	for child in u.get_children():
		var found := _anim_player_in(child)
		if found: return found
	return null

func _inject_anim_lib(ap: AnimationPlayer, lib_name: String, scene: PackedScene) -> void:
	var root := scene.instantiate()
	var src_ap := _anim_player_in(root)
	if src_ap:
		var lib := AnimationLibrary.new()
		for anim_name: String in src_ap.get_animation_list():
			if anim_name != "RESET":
				lib.add_animation(anim_name, src_ap.get_animation(anim_name))
		if not ap.has_animation_library(lib_name):
			ap.add_animation_library(lib_name, lib)
	root.queue_free()

func _play_unit_anim(ap: AnimationPlayer, candidates: Array) -> void:
	for cand: String in candidates:
		if ap.has_animation(cand):
			if ap.current_animation != cand:
				ap.play(cand)
			return

func _tick_unit_anim(u: Unit) -> void:
	var ap := _unit_aps.get(u) as AnimationPlayer
	if ap == null: return
	match u.state:
		Unit.State.MOVING:
			_play_unit_anim(ap, ["walk/Walking_A", "walk/Walking_B", "walk/Walking_C"])
		Unit.State.ATTACKING:
			if u.attack_move:
				_play_unit_anim(ap, ["walk/Running_A", "walk/Running_B"])
			else:
				_play_unit_anim(ap, ["combat/Ranged_2H_Aiming", "combat/Ranged_2H_Shooting",
									 "combat/Ranged_1H_Aiming"])
		_:  # HOLDING
			_play_unit_anim(ap, ["general/Idle_A", "general/Idle_B"])

func _unit_abbrev(kind: String) -> String:
	match kind:
		"militia":   return "MIL"
		"grenadier": return "GREN"
		"sniper":    return "SNP"
		"mg_team":   return "MG"
		"medic":     return "MED"
		"soldier":   return "SOL"
		"e_gren":    return "GREN"
		"e_sniper":  return "SNP"
		"e_mg":      return "MG"
	return kind.left(3).to_upper()

# ── Mannequin dressing ────────────────────────────────────────────

func _dress_mannequin(body: Node3D, kind: String, is_player: bool) -> void:
	var skeleton := body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null: return

	# Per-kind color palette
	var uniform_col: Color
	var pants_col:   Color
	var helm_col:    Color
	var skin_col := Color(0.80, 0.63, 0.46)
	var boot_col := Color(0.14, 0.11, 0.08)

	match kind:
		"militia":
			uniform_col = Color(0.48, 0.42, 0.28) if is_player else Color(0.42, 0.37, 0.24)
			pants_col   = Color(0.22, 0.19, 0.13)
			helm_col    = Color(0.30, 0.27, 0.16)  # tan soft cap
		"medic":
			uniform_col = Color(0.92, 0.92, 0.90)
			pants_col   = Color(0.85, 0.85, 0.83)
			helm_col    = Color(0.90, 0.90, 0.88)
		"grenadier", "e_gren":
			uniform_col = Color(0.24, 0.34, 0.16) if is_player else Color(0.42, 0.36, 0.22)
			pants_col   = Color(0.20, 0.27, 0.13) if is_player else Color(0.34, 0.28, 0.17)
			helm_col    = Color(0.20, 0.27, 0.13) if is_player else Color(0.32, 0.27, 0.16)
		"sniper", "e_sniper":
			uniform_col = Color(0.19, 0.27, 0.13) if is_player else Color(0.36, 0.32, 0.19)
			pants_col   = Color(0.15, 0.21, 0.10) if is_player else Color(0.28, 0.24, 0.15)
			helm_col    = Color(0.16, 0.22, 0.11) if is_player else Color(0.26, 0.22, 0.14)
		"mg_team", "e_mg":
			uniform_col = Color(0.20, 0.28, 0.14) if is_player else Color(0.44, 0.38, 0.23)
			pants_col   = Color(0.17, 0.23, 0.11) if is_player else Color(0.35, 0.30, 0.18)
			helm_col    = Color(0.17, 0.23, 0.11) if is_player else Color(0.33, 0.28, 0.17)
		_:  # soldier / default
			uniform_col = Color(0.28, 0.38, 0.20) if is_player else Color(0.52, 0.46, 0.28)
			pants_col   = Color(0.22, 0.31, 0.16) if is_player else Color(0.42, 0.36, 0.22)
			helm_col    = Color(0.22, 0.30, 0.16) if is_player else Color(0.38, 0.32, 0.19)

	# Color each mesh part by name
	for child in skeleton.get_children():
		var mi := child as MeshInstance3D
		if mi == null: continue
		var n := mi.name.to_lower()
		var col: Color
		if   "head" in n: col = skin_col
		elif "leg"  in n: col = pants_col
		elif "foot" in n: col = boot_col
		else:             col = uniform_col
		_set_mi_flat_color(mi, col)

	# Bone-attached equipment
	_attach_headgear(skeleton, kind, helm_col, skin_col)
	_attach_weapon(skeleton, kind)

func _set_mi_flat_color(mi: MeshInstance3D, col: Color) -> void:
	if mi.mesh == null: return
	for surf in mi.mesh.get_surface_count():
		var m := StandardMaterial3D.new()
		m.albedo_color     = col
		m.roughness        = 0.82
		m.metallic         = 0.04
		mi.set_surface_override_material(surf, m)

func _bone_attach(skeleton: Skeleton3D, candidates: Array) -> BoneAttachment3D:
	for name: String in candidates:
		var idx := skeleton.find_bone(name)
		if idx >= 0:
			var ba := BoneAttachment3D.new()
			skeleton.add_child(ba)   # must be in tree before bone_idx resolves
			ba.bone_name = name
			ba.bone_idx  = idx
			return ba
	return null

func _attach_headgear(skeleton: Skeleton3D, kind: String, helm_col: Color, skin_col: Color) -> void:
	var ba := _bone_attach(skeleton,
		["Head", "head", "Bip001_Head", "mixamorig:Head", "Neck_01"])
	if ba == null: return

	var helm_mat := StandardMaterial3D.new()
	helm_mat.albedo_color = helm_col
	helm_mat.roughness    = 0.78

	if kind == "militia":
		# Baseball cap — flat cylinder + brim
		var cap_m := CylinderMesh.new()
		cap_m.top_radius = 0.085; cap_m.bottom_radius = 0.090
		cap_m.height = 0.050; cap_m.radial_segments = 8
		var cap := MeshInstance3D.new(); cap.mesh = cap_m
		cap.set_surface_override_material(0, helm_mat)
		cap.position = Vector3(0.0, 0.07, 0.0)
		ba.add_child(cap)
		var brim_m := CylinderMesh.new()
		brim_m.top_radius = 0.065; brim_m.bottom_radius = 0.068
		brim_m.height = 0.018; brim_m.radial_segments = 8
		var brim := MeshInstance3D.new(); brim.mesh = brim_m
		brim.set_surface_override_material(0, helm_mat)
		brim.position = Vector3(0.0, 0.052, 0.095)
		ba.add_child(brim)
	else:
		# Military helmet — flattened sphere
		var h_m := SphereMesh.new()
		h_m.radius = 0.095; h_m.height = 0.12
		h_m.radial_segments = 8; h_m.rings = 4
		var h := MeshInstance3D.new(); h.mesh = h_m
		h.set_surface_override_material(0, helm_mat)
		h.position = Vector3(0.0, 0.06, 0.0)
		ba.add_child(h)

	# Medic: red cross on forehead
	if kind == "medic":
		for sz: Vector3 in [Vector3(0.055, 0.012, 0.025), Vector3(0.012, 0.055, 0.025)]:
			var cm := BoxMesh.new(); cm.size = sz
			var ci := MeshInstance3D.new(); ci.mesh = cm
			ci.set_surface_override_material(0, _mat(Color(0.88, 0.08, 0.08)))
			ci.position = Vector3(0.0, 0.06, 0.092)
			ba.add_child(ci)

func _attach_weapon(skeleton: Skeleton3D, kind: String) -> void:
	var ba := _bone_attach(skeleton,
		["hand.r", "wrist.r", "Hand_R", "hand_r", "Hand.R",
		 "RightHand", "mixamorig:RightHand", "Bip001_R_Hand"])
	if ba == null: return

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.14, 0.11)
	metal.roughness    = 0.55
	metal.metallic     = 0.45

	var wpn_len: float
	match kind:
		"sniper","e_sniper": wpn_len = 0.38
		"mg_team","e_mg":    wpn_len = 0.30
		"medic":             wpn_len = 0.10
		_:                   wpn_len = 0.22

	var wpn_m := BoxMesh.new(); wpn_m.size = Vector3(0.028, 0.028, wpn_len)
	var wpn := MeshInstance3D.new(); wpn.mesh = wpn_m
	wpn.set_surface_override_material(0, metal)
	wpn.position = Vector3(0.0, 0.0, wpn_len * 0.5)
	ba.add_child(wpn)

	if kind in ["sniper", "e_sniper"]:
		var sc_m := CylinderMesh.new()
		sc_m.top_radius = 0.010; sc_m.bottom_radius = 0.010
		sc_m.height = 0.15; sc_m.radial_segments = 5
		var sc := MeshInstance3D.new(); sc.mesh = sc_m
		sc.set_surface_override_material(0, metal)
		sc.rotation.x = PI / 2.0
		sc.position   = Vector3(0.0, 0.024, 0.15)
		ba.add_child(sc)

	if kind in ["mg_team", "e_mg"]:
		for side: float in [-0.034, 0.034]:
			var bp_m := BoxMesh.new(); bp_m.size = Vector3(0.014, 0.10, 0.014)
			var bp := MeshInstance3D.new(); bp.mesh = bp_m
			bp.set_surface_override_material(0, metal)
			bp.position  = Vector3(side, -0.055, 0.08)
			bp.rotation.z = side * deg_to_rad(18.0)
			ba.add_child(bp)

# ── GAME LOOP ──────────────────────────────────────────────────

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_minimap()
	# Grenade AoE cursor tracks mouse in grenade mode (hidden on touch devices)
	if _grenade_cursor:
		var in_grenade := cur_mode == "grenade" and game_active and not game_paused and not _is_touch_device
		_grenade_cursor.visible = in_grenade
		if in_grenade:
			var mp := get_viewport().get_mouse_position()
			var wp := _ground_hit(mp)
			if wp != Vector3.ZERO:
				_grenade_cursor.position = Vector3(wp.x, 0.05, wp.z)
	if not game_active or game_paused: return
	_update_wave(delta)
	_update_units(delta)
	_update_fog()
	_update_capture_points(delta)
	_update_hud()

func _update_wave(delta: float) -> void:
	wave_timer -= delta
	# Clear bonus: cap wait to 10s once the field is clear
	if wave_num > 0 and wave_num < WAVE_DEFS.size() and wave_timer > 10.0:
		var has_enemies := false
		for u in units:
			var ue := u as Unit
			if ue != null and ue.team == "enemy" and ue.hp > 0:
				has_enemies = true; break
		if not has_enemies:
			wave_timer = 10.0
			if _wave_clear_notified < wave_num:
				_wave_clear_notified = wave_num
				_flash_wave_clear(wave_num)
	if wave_timer <= 0.0 and wave_num < WAVE_DEFS.size():
		_launch_wave()
		wave_timer = 50.0
	elif wave_num >= WAVE_DEFS.size():
		var enemies_left := units.filter(func(u): return (u as Unit) != null and (u as Unit).team == "enemy" and (u as Unit).hp > 0)
		if enemies_left.is_empty():
			_show_endgame(true)

func _find_road_near(wx: float, wz: float, max_r: int = 5) -> Vector3:
	var col0 := clampi(int((wx + HALF) / TCELL), 0, TG - 1)
	var row0 := clampi(int((wz + HALF) / TCELL), 0, TG - 1)
	for radius in range(0, max_r + 1):
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				if radius > 0 and abs(dr) != radius and abs(dc) != radius: continue
				var r := row0 + dr; var c := col0 + dc
				if r < 0 or r >= TG or c < 0 or c >= TG: continue
				if tmap[r][c] == TILE_ROAD:
					return Vector3(_tx(c), 0.0, _tz(r))
	return Vector3(wx, 0.0, wz)

func _launch_wave() -> void:
	var kinds: Array = WAVE_DEFS[wave_num]
	wave_num += 1
	Sounds.play("wave_alarm", 0.0)
	_set_status("ENEMY ADVANCE — WAVE %d INCOMING!" % wave_num)
	_flash_wave_banner(wave_num)
	# Later waves attack from more edges: wave 1-2 = 1 edge, 3-4 = 2, 5 = 3
	var edge_count: int = 1 + (wave_num - 1) / 2
	for i in kinds.size():
		var sp := _wave_spawn_pos(i % edge_count)
		var u := spawn_unit(str(kinds[i]), "enemy", sp.x, sp.z)
		_unit_flanks[u] = _rng.randf_range(-0.55, 0.55)

func _wave_spawn_pos(edge: int) -> Vector3:
	var j: float = (_rng.randf() - 0.5) * 14.0
	match edge:
		0: return _find_road_near(-HQ_X + (_rng.randf()-0.5)*8.0, -HQ_Z + (_rng.randf()-0.5)*8.0)  # NW corner
		1: return _find_road_near(j, -HALF + 1.0 + _rng.randf()*3.0)                               # North edge
		_: return _find_road_near(-HALF + 1.0 + _rng.randf()*3.0, j)                               # West edge

func _update_units(delta: float) -> void:
	var dead: Array = []
	var hq_pos := Vector3(HQ_X, 0.0, HQ_Z)
	_hq_alarm_timer = maxf(0.0, _hq_alarm_timer - delta)
	for u in units:
		var unit := u as Unit
		if unit == null: continue
		if unit.hp <= 0:
			dead.append(unit); continue
		unit.in_cover = _unit_in_cover(unit) or _near_barricade(unit)
		if unit.team == "player":
			_tick_player(unit, delta)
		else:
			_tick_enemy(unit, delta)
		_tick_unit_anim(unit)
		if unit.team == "enemy":
			# Enemy units in the player HQ zone damage the HQ
			if unit.global_position.distance_to(hq_pos) < 3.5:
				hq_hp = maxi(0, hq_hp - int(5.0 * delta))
				if _hq_alarm_timer <= 0.0:
					Sounds.play("hq_alarm", -1.0)
					_hq_alarm_timer = 2.8
				if hq_hp <= 0:
					_show_endgame(false)
					return
	for unit in dead:
		if unit.team == "enemy":
			kill_count += 1
			supplies += 10
			_spawn_kill_popup(unit.global_position)
		if unit.garrisoned:
			_garrison_remove(unit)
			unit.garrisoned = false
			unit.garrison_tile = Vector2i(-1,-1)
		_unit_flanks.erase(unit)
		_unit_aps.erase(unit)
		_squad_speed.erase(unit)
		_squad_dest.erase(unit)
		_enemy_cp_target.erase(unit)
		_enemy_cp_timer.erase(unit)
		_vet_star_nodes.erase(unit)
		_mg_deploy_timers.erase(unit)
		unit.overwatch   = false
		unit.suppressing = false
		sel_units.erase(unit)
		if unit == sel_unit:
			sel_unit = sel_units[0] as Unit if not sel_units.is_empty() else null
			_update_unit_info()
		if _mm_dots.has(unit):
			var dot = _mm_dots[unit]; _mm_dots.erase(unit)
			if is_instance_valid(dot): dot.queue_free()
		units.erase(unit)
		_death_effect(unit)

func _death_effect(unit: Unit) -> void:
	Sounds.play("death", -8.0)
	unit.set_selected(false)
	var pos  := unit.global_position
	var team := unit.team
	# _unit_aps is already erased before this call; look up AP directly from the tree
	var ap := _find_unit_ap(unit)
	if ap:
		_play_unit_anim(ap, ["general/Death_A", "general/Death_B"])
		ap.speed_scale = 1.8
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.30)
	tw.tween_property(unit, "scale", Vector3(0.0, 0.0, 0.0), 0.22)
	await tw.finished
	if is_instance_valid(unit): unit.queue_free()
	_spawn_body(pos, team)
	# Attrition defeat: waves started, no player units, can't afford cheapest
	if wave_num > 0 and game_active:
		var alive := false
		for au in units:
			var au_unit := au as Unit
			if au_unit != null and au_unit.team == "player" and au_unit.hp > 0:
				alive = true; break
		if not alive and supplies < 75:
			_show_endgame(false)

func _spawn_body(pos: Vector3, team: String) -> void:
	var torso_col := Color(0.52, 0.40, 0.28) if team == "player" else Color(0.26, 0.32, 0.20)
	var head_col  := Color(0.72, 0.58, 0.46)
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	root.rotation.y = _rng.randf() * TAU
	add_child(root)
	var torso := _box(Vector3(0.36, 0.07, 0.68), _mat(torso_col))
	torso.position = Vector3(0.0, 0.035, 0.0)
	root.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13; head_mesh.height = 0.18
	head_mesh.radial_segments = 6; head_mesh.rings = 4
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.set_surface_override_material(0, _mat(head_col))
	head.position = Vector3(0.0, 0.09, 0.32)
	root.add_child(head)

func _tick_player(u: Unit, delta: float) -> void:
	# Garrisoned: fire from building, skip all movement/cover logic
	if u.garrisoned:
		_tick_garrisoned(u)
		return
	if u.kind == "medic":
		_tick_medic_heal(u, delta)
	# Overwatch: hold position, fire at guaranteed max damage when enemy enters range
	if u.overwatch:
		if u.fire_timer <= 0.0:
			var enemy := _nearest_enemy(u, u.attack_range)
			if enemy:
				_fire_overwatch(u, enemy)
		return
	# Suppressing fire: spray all enemies in range
	if u.suppressing:
		_tick_mg_suppressing(u, delta)
		return
	if u.state == Unit.State.MOVING:
		_step_path(u, delta)
		# If unit just arrived and has a pending garrison order, execute it
		if u.state == Unit.State.HOLDING and u.garrison_pending != Vector2i(-1, -1):
			var pt := u.garrison_pending
			u.garrison_pending = Vector2i(-1, -1)
			_do_garrison(u, pt)
			return
		# Fire opportunistically at any visible enemy while moving
		if u.fire_timer <= 0.0:
			var enemy := _nearest_enemy(u, u.attack_range)
			if enemy: _fire(u, enemy)
	# Auto-fire when stationary
	if u.state != Unit.State.MOVING:
		if u.attack_move: u.attack_move = false
		if u.fire_timer <= 0.0:
			var enemy := _nearest_enemy(u, u.attack_range)
			if enemy:
				_fire(u, enemy)
			elif u.state == Unit.State.ATTACKING:
				var any_enemy := _nearest_enemy(u, 999.0)
				if any_enemy:
					_move_with_path(u, any_enemy.global_position)
					u.attack_move = true
				else:
					u.state = Unit.State.HOLDING
	# HQ proximity regen: slow heal when unit rests near the base with no nearby threats
	# Excluded for medics — their heal_timer governs the rate at which they heal others
	if u.kind != "medic" and u.hp < u.hp_max and u.state == Unit.State.HOLDING:
		if u.global_position.distance_to(Vector3(HQ_X, 0.0, HQ_Z)) < 5.5:
			if _nearest_enemy(u, 10.0) == null and u.heal_timer <= 0.0:
				u.hp = mini(u.hp_max, u.hp + 3)
				u._refresh_hp_bar()
				u.heal_timer = 2.5
	# Auto-seek cover when idle; heavy suppression bypasses the timer
	if wave_num > 0 and u.state == Unit.State.HOLDING and u.kind != "medic":
		if u.suppression > 0.7 and not u.in_cover:
			u.cover_seek_timer = 0.0
		if u.cover_seek_timer <= 0.0:
			u.cover_seek_timer = 4.0 + _rng.randf() * 3.0
			if not _unit_in_cover(u):
				var cp := _find_player_cover_pos(u)
				if cp != Vector3.ZERO:
					_move_with_path(u, cp)
	# Idle intelligence: facing, spacing, role-specific repositioning
	if u.state == Unit.State.HOLDING:
		_tick_player_idle(u, delta)

func _tick_enemy(u: Unit, delta: float) -> void:
	# Garrisoned enemies fire from their bunker; exit if critically wounded
	if u.garrisoned:
		if u.hp < int(float(u.hp_max) * 0.22):
			_exit_garrison(u)
		else:
			_tick_garrisoned(u)
		return
	# Critically low HP: stochastic retreat toward spawn edge
	if u.hp < int(float(u.hp_max) * 0.22) and u.state != Unit.State.MOVING and _rng.randf() < 0.008:
		var retreat_dest := Vector3(
			clampf(-HQ_X + _rng.randf_range(-4.0, 4.0), -HALF+1.0, HALF-1.0),
			0.0,
			clampf(-HQ_Z + _rng.randf_range(-4.0, 4.0), -HALF+1.0, HALF-1.0))
		_move_with_path(u, retreat_dest)
		return
	# Opportunistic bunker: garrison in a nearby enemy-owned CP when not moving
	if u.state != Unit.State.MOVING and _try_enemy_bunker(u):
		return
	var target := _pick_enemy_target(u)
	if target == null: return
	var dist: float = u.global_position.distance_to(target.global_position)

	# Heavy suppression: MGs fire back, others take cover
	if u.suppression > 0.6 and _rng.randf() < 0.015:
		if u.kind == "e_mg" and u.fire_timer <= 0.0 and dist <= u.attack_range and _has_los(u.global_position, target.global_position):
			_fire(u, target)
		else:
			var cover := _find_cover_pos(u)
			if cover != Vector3.ZERO:
				u.issue_move(cover)
		return

	match u.kind:
		"e_sniper": _tick_enemy_sniper(u, target, dist, delta); return
		"e_gren":   _tick_enemy_grenadier(u, target, dist, delta); return
		"e_mg":     _tick_enemy_mg(u, target, dist, delta); return

	# Default soldier: advance and fire
	var can_see := _has_los(u.global_position, target.global_position)
	if dist <= u.attack_range and u.fire_timer <= 0.0 and can_see:
		_fire(u, target)
		return
	# Tick CP commitment timer
	if _enemy_cp_timer.has(u):
		_enemy_cp_timer[u] = maxf(0.0, float(_enemy_cp_timer[u]) - delta)
	if u.state == Unit.State.MOVING:
		_step_path(u, delta)
	elif dist > u.attack_range * 0.8 or not can_see:
		# Odd-ID soldiers contest capture points when not in direct combat
		if u.get_instance_id() % 2 == 1:
			var cp_t := float(_enemy_cp_timer.get(u, 0.0))
			if cp_t <= 0.0:
				var cp_pos := _nearest_contestable_cp(u.global_position)
				if cp_pos != Vector3.ZERO:
					_enemy_cp_target[u] = cp_pos
					_enemy_cp_timer[u] = 9.0
			var cp_dest: Vector3 = _enemy_cp_target.get(u, Vector3.ZERO)
			if cp_dest != Vector3.ZERO and float(_enemy_cp_timer.get(u, 0.0)) > 0.0:
				if u.global_position.distance_to(cp_dest) > 1.5:
					_move_with_path(u, cp_dest)
				return
		var flank_angle: float = float(_unit_flanks.get(u, 0.0))
		var dir: Vector3 = (target.global_position - u.global_position).normalized()
		dir = dir.rotated(Vector3.UP, flank_angle)
		var dest := u.global_position + dir * 3.0
		dest.x = clampf(dest.x, -HALF+1.0, HALF-1.0)
		dest.z = clampf(dest.z, -HALF+1.0, HALF-1.0)
		_move_with_path(u, dest)

func _pick_enemy_target(u: Unit) -> Unit:
	var opp_team := "player" if u.team == "enemy" else "enemy"
	var best: Unit = null
	var best_score := -INF
	for ou in units:
		var t := ou as Unit
		if t == null or t.hp <= 0 or t.team != opp_team: continue
		var dist := u.global_position.distance_to(t.global_position)
		var score := 0.0
		if t.kind == "medic": score += 35.0
		score += (1.0 - float(t.hp) / float(t.hp_max)) * 25.0
		score -= dist * 0.8
		if score > best_score:
			best_score = score; best = t
	return best

func _tick_enemy_sniper(u: Unit, target: Unit, dist: float, delta: float) -> void:
	var can_see := _has_los(u.global_position, target.global_position)
	if dist <= u.attack_range and u.fire_timer <= 0.0 and can_see:
		_fire(u, target); return
	if u.state == Unit.State.MOVING:
		_step_path(u, delta); return
	# Already at a good standoff position with LOS — hold
	if can_see and dist >= u.attack_range * 0.5 and dist <= u.attack_range:
		return
	var dir := (target.global_position - u.global_position).normalized()
	var dest := target.global_position - dir * (u.attack_range * 0.75)
	dest.x = clampf(dest.x, -HALF+1.0, HALF-1.0)
	dest.z = clampf(dest.z, -HALF+1.0, HALF-1.0)
	_move_with_path(u, dest)

func _tick_enemy_grenadier(u: Unit, target: Unit, dist: float, delta: float) -> void:
	var can_see := _has_los(u.global_position, target.global_position)
	if dist <= u.attack_range and u.fire_timer <= 0.0 and can_see:
		_fire(u, target); return
	if u.state == Unit.State.MOVING:
		_step_path(u, delta)
	if u.state != Unit.State.MOVING:
		if dist < u.attack_range * 0.55:
			# Too close — back up to ideal range
			var dir := (u.global_position - target.global_position).normalized()
			var dest := u.global_position + dir * 2.5
			dest.x = clampf(dest.x, -HALF+1.0, HALF-1.0)
			dest.z = clampf(dest.z, -HALF+1.0, HALF-1.0)
			_move_with_path(u, dest)
		elif dist > u.attack_range * 0.9 or not can_see:
			var flank_angle: float = float(_unit_flanks.get(u, 0.0))
			var dir := (target.global_position - u.global_position).normalized()
			dir = dir.rotated(Vector3.UP, flank_angle)
			var dest := u.global_position + dir * 3.0
			dest.x = clampf(dest.x, -HALF+1.0, HALF-1.0)
			dest.z = clampf(dest.z, -HALF+1.0, HALF-1.0)
			_move_with_path(u, dest)

func _tick_enemy_mg(u: Unit, target: Unit, dist: float, delta: float) -> void:
	var can_see := _has_los(u.global_position, target.global_position)
	if dist <= u.attack_range and u.fire_timer <= 0.0 and can_see:
		_fire(u, target); return
	if u.state == Unit.State.MOVING:
		_step_path(u, delta); return
	if dist > u.attack_range * 0.7 or not can_see:
		# MGs prefer to set up at capture points — tick their CP timer and route there
		if _enemy_cp_timer.has(u):
			_enemy_cp_timer[u] = maxf(0.0, float(_enemy_cp_timer[u]) - delta)
		var cp_t := float(_enemy_cp_timer.get(u, 0.0))
		if cp_t <= 0.0:
			var cp_pos := _nearest_contestable_cp(u.global_position)
			if cp_pos != Vector3.ZERO:
				_enemy_cp_target[u] = cp_pos
				_enemy_cp_timer[u] = 12.0
		var cp_dest: Vector3 = _enemy_cp_target.get(u, Vector3.ZERO)
		if cp_dest != Vector3.ZERO and float(_enemy_cp_timer.get(u, 0.0)) > 0.0:
			if u.global_position.distance_to(cp_dest) > 1.5:
				_move_with_path(u, cp_dest)
			return
		var covered := _find_covered_advance_pos(u, target.global_position)
		if covered != Vector3.ZERO:
			_move_with_path(u, covered)
		else:
			var flank_angle: float = float(_unit_flanks.get(u, 0.0))
			var dir := (target.global_position - u.global_position).normalized()
			dir = dir.rotated(Vector3.UP, flank_angle)
			var dest := u.global_position + dir * 3.0
			dest.x = clampf(dest.x, -HALF+1.0, HALF-1.0)
			dest.z = clampf(dest.z, -HALF+1.0, HALF-1.0)
			_move_with_path(u, dest)

func _find_covered_advance_pos(u: Unit, target_pos: Vector3) -> Vector3:
	var sr := clampi(int((u.global_position.z + HALF) / TCELL), 0, TG-1)
	var sc := clampi(int((u.global_position.x + HALF) / TCELL), 0, TG-1)
	var best := Vector3.ZERO
	var best_score := -INF
	for radius in range(1, 6):
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				if absi(dr) != radius and absi(dc) != radius: continue
				var r := sr + dr; var c := sc + dc
				if r < 0 or r >= TG or c < 0 or c >= TG: continue
				if tmap[r][c] == TILE_BUILDING or tmap[r][c] == TILE_WATER: continue
				var wp := Vector3(_tx(c), 0.0, _tz(r))
				if not _has_los(wp, target_pos): continue
				var d_to_target := wp.distance_to(target_pos)
				if d_to_target > u.attack_range: continue
				var near_bld := false
				for adr: int in [-1, 0, 1]:
					for adc: int in [-1, 0, 1]:
						if adr == 0 and adc == 0: continue
						var ar: int = r + adr; var ac: int = c + adc
						if ar >= 0 and ar < TG and ac >= 0 and ac < TG and tmap[ar][ac] == TILE_BUILDING:
							near_bld = true; break
					if near_bld: break
				var score := (20.0 if near_bld else 0.0) - d_to_target
				if score > best_score:
					best_score = score; best = wp
	return best

func _tick_player_idle(u: Unit, delta: float) -> void:
	# Face nearest threat
	var threat := _nearest_enemy(u, 999.0)
	if threat:
		var dir := threat.global_position - u.global_position
		dir.y = 0.0
		if dir.length() > 0.1:
			u.rotation.y = lerp_angle(u.rotation.y, atan2(dir.x, dir.z), delta * 4.0)

	# Spread out from nearby friendly units
	var push := Vector3.ZERO
	for ou in units:
		var fu := ou as Unit
		if fu == null or fu == u or fu.team != u.team or fu.hp <= 0: continue
		var diff := u.global_position - fu.global_position
		diff.y = 0.0
		var d := diff.length()
		if d < 1.4 and d > 0.01:
			push += diff.normalized() * (1.4 - d) * 1.2
	if push.length() > 0.01:
		var new_pos := u.global_position + push * delta
		new_pos.y = 0.0
		new_pos.x = clampf(new_pos.x, -HALF + 0.5, HALF - 0.5)
		new_pos.z = clampf(new_pos.z, -HALF + 0.5, HALF - 0.5)
		var pnr := clampi(int((new_pos.z + HALF) / TCELL), 0, TG-1)
		var pnc := clampi(int((new_pos.x + HALF) / TCELL), 0, TG-1)
		if _is_passable(pnr, pnc):
			u.position = new_pos

	if threat == null: return

	# Role-specific repositioning when an enemy is too close
	var threat_dist := u.global_position.distance_to(threat.global_position)
	match u.kind:
		"grenadier":
			if threat_dist < u.attack_range * 0.45:
				var dir2 := (u.global_position - threat.global_position).normalized()
				var dest := u.global_position + dir2 * 2.5
				dest.x = clampf(dest.x, -HALF + 0.5, HALF - 0.5)
				dest.z = clampf(dest.z, -HALF + 0.5, HALF - 0.5)
				_move_with_path(u, dest)
		"sniper":
			if threat_dist < 6.0:
				var dir2 := (u.global_position - threat.global_position).normalized()
				var dest := u.global_position + dir2 * 4.0
				dest.x = clampf(dest.x, -HALF + 0.5, HALF - 0.5)
				dest.z = clampf(dest.z, -HALF + 0.5, HALF - 0.5)
				_move_with_path(u, dest)

func _has_los(from_pos: Vector3, to_pos: Vector3) -> bool:
	# Bresenham tile trace — returns false if any intermediate cell is TILE_BUILDING
	var c0 := clampi(int((from_pos.x + HALF) / TCELL), 0, TG-1)
	var r0 := clampi(int((from_pos.z + HALF) / TCELL), 0, TG-1)
	var c1 := clampi(int((to_pos.x   + HALF) / TCELL), 0, TG-1)
	var r1 := clampi(int((to_pos.z   + HALF) / TCELL), 0, TG-1)
	if c0 == c1 and r0 == r1: return true
	var dc := absi(c1 - c0); var dr := absi(r1 - r0)
	var sc := 1 if c1 > c0 else -1
	var sr := 1 if r1 > r0 else -1
	var err := dc - dr
	var cc := c0; var rr := r0
	while cc != c1 or rr != r1:
		var e2 := 2 * err
		if e2 >= -dr: err -= dr; cc += sc
		if e2 <= dc:  err += dc; rr += sr
		if cc == c1 and rr == r1: break  # skip the target cell itself
		if rr >= 0 and rr < TG and cc >= 0 and cc < TG:
			if tmap[rr][cc] == TILE_BUILDING: return false
	return true

func _unit_in_cover(u: Unit) -> bool:
	var r: int = int((u.global_position.z + HALF) / TCELL)
	var c: int = int((u.global_position.x + HALF) / TCELL)
	for ddr: int in [-1, 0, 1]:
		for ddc: int in [-1, 0, 1]:
			if ddr == 0 and ddc == 0: continue
			var nr: int = r + ddr; var nc: int = c + ddc
			if nr >= 0 and nr < TG and nc >= 0 and nc < TG:
				if tmap[nr][nc] == TILE_BUILDING: return true
	return false

func _find_player_cover_pos(u: Unit) -> Vector3:
	# Spiral outward to find the nearest passable tile adjacent to a building
	var sr: int = int((u.global_position.z + HALF) / TCELL)
	var sc: int = int((u.global_position.x + HALF) / TCELL)
	for radius in range(1, 9):
		for ddr: int in range(-radius, radius + 1):
			for ddc: int in range(-radius, radius + 1):
				if absi(ddr) != radius and absi(ddc) != radius: continue
				var r: int = sr + ddr; var c: int = sc + ddc
				if r < 0 or r >= TG or c < 0 or c >= TG: continue
				if tmap[r][c] == TILE_BUILDING or tmap[r][c] == TILE_WATER: continue
				for adj_dr: int in [-1, 0, 1]:
					for adj_dc: int in [-1, 0, 1]:
						if adj_dr == 0 and adj_dc == 0: continue
						var ar: int = r + adj_dr; var ac: int = c + adj_dc
						if ar >= 0 and ar < TG and ac >= 0 and ac < TG:
							if tmap[ar][ac] == TILE_BUILDING:
								return Vector3(_tx(c), 0.0, _tz(r))
	return Vector3.ZERO

func _find_cover_pos(u: Unit) -> Vector3:
	# Look for a nearby building tile to shelter behind
	for _attempt in 6:
		var angle: float = _rng.randf()*TAU
		var dist: float = 2.0 + _rng.randf()*4.0
		var try_pos := u.global_position + Vector3(cos(angle)*dist, 0.0, sin(angle)*dist)
		var r: int = int((try_pos.z + HALF) / TCELL)
		var c: int = int((try_pos.x + HALF) / TCELL)
		if r >= 0 and r < TG and c >= 0 and c < TG:
			if tmap[r][c] == TILE_BUILDING:
				return try_pos + Vector3(cos(angle)*1.2, 0.0, sin(angle)*1.2)
	return Vector3.ZERO

func _tick_medic_heal(u: Unit, delta: float) -> void:
	# Find most injured friendly within 8 units
	var best: Unit = null
	var best_dist := 9999.0
	var best_deficit := 0
	for ou in units:
		var other := ou as Unit
		if other == null or other == u or other.team != "player": continue
		if other.hp >= other.hp_max: continue
		var d := u.global_position.distance_to(other.global_position)
		if d >= 8.0: continue
		var deficit := other.hp_max - other.hp
		if deficit > best_deficit or (deficit == best_deficit and d < best_dist):
			best = other; best_dist = d; best_deficit = deficit
	if best == null: return
	if best_dist <= 3.5:
		if u.heal_timer <= 0.0:
			best.hp = mini(best.hp_max, best.hp + 8)
			best._refresh_hp_bar()
			_spawn_heal_pulse(best.global_position)
			u.heal_timer = 0.45
	elif u.state == Unit.State.HOLDING:
		u.issue_move(best.global_position)

func _spawn_heal_pulse(at: Vector3) -> void:
	Sounds.play("heal", -5.0)
	var ring_m := TorusMesh.new()
	ring_m.inner_radius = 0.36; ring_m.outer_radius = 0.50
	ring_m.rings = 3; ring_m.ring_segments = 12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 1.0, 0.42, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.60, 0.20)
	mat.emission_energy_multiplier = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = ring_m
	mi.set_surface_override_material(0, mat)
	mi.rotation.x = -PI / 2.0
	mi.position = at + Vector3(0.0, 0.05, 0.0)
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(2.2, 2.2, 2.2), 0.42).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "position:y", at.y + 1.1, 0.42)
	tw.tween_callback(mi.queue_free)

# ── A* PATHFINDING ────────────────────────────────────────────

func _world_pip(px: float, pz: float, poly: Array) -> bool:
	var inside := false; var n := poly.size(); var j := n - 1
	for i in n:
		var xi: float = (poly[i] as Vector2).x; var yi: float = (poly[i] as Vector2).y
		var xj: float = (poly[j] as Vector2).x; var yj: float = (poly[j] as Vector2).y
		if (yi > pz) != (yj > pz):
			if px < (xj - xi) * (pz - yi) / (yj - yi) + xi:
				inside = !inside
		j = i
	return inside

func _is_passable(r: int, c: int) -> bool:
	if r < 0 or r >= TG or c < 0 or c >= TG: return false
	return tmap[r][c] != TILE_BUILDING and tmap[r][c] != TILE_WATER

func _nearest_passable(r: int, c: int) -> Vector2i:
	if _is_passable(r, c): return Vector2i(r, c)
	for rad in range(1, 6):
		for dr in range(-rad, rad+1):
			for dc in range(-rad, rad+1):
				if absi(dr) != rad and absi(dc) != rad: continue
				var nr: int = r+dr; var nc: int = c+dc
				if _is_passable(nr, nc): return Vector2i(nr, nc)
	return Vector2i(clampi(r,0,TG-1), clampi(c,0,TG-1))

func _heur(r1: int, c1: int, r2: int, c2: int) -> float:
	return absf(float(r1-r2)) + absf(float(c1-c2))

func _find_path(from_world: Vector3, to_world: Vector3) -> Array:
	var fpr := _nearest_passable(clampi(int((from_world.z + HALF) / TCELL), 0, TG-1),
								 clampi(int((from_world.x + HALF) / TCELL), 0, TG-1))
	var fr: int = fpr.x; var fc: int = fpr.y
	var tp := _nearest_passable(int((to_world.z + HALF) / TCELL), int((to_world.x + HALF) / TCELL))
	var tr: int = tp.x; var tc: int = tp.y
	if fr == tr and fc == tc: return [to_world]
	var sk: int = fr*TG+fc; var goal_key: int = tr*TG+tc
	var open_set: Array = [[_heur(fr,fc,tr,tc), 0.0, fr, fc]]
	var g_cost:  Dictionary = {sk: 0.0}
	var par_map: Dictionary = {}
	var closed:  Dictionary = {}
	var found: bool = false
	while not open_set.is_empty():
		var bi: int = 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[bi][0]: bi = i
		var node = open_set[bi]; open_set.remove_at(bi)
		var nr: int = int(node[2]); var nc: int = int(node[3])
		var key: int = nr*TG+nc
		if closed.has(key): continue
		closed[key] = true
		if key == goal_key: found = true; break
		for off in [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]:
			var nnr: int = nr+int(off[0]); var nnc: int = nc+int(off[1])
			if not _is_passable(nnr, nnc): continue
			var nk: int = nnr*TG+nnc
			if closed.has(nk): continue
			var diagonal: bool = int(off[0]) != 0 and int(off[1]) != 0
			var step: float = 1.414 if diagonal else 1.0
			if diagonal:
				var cn1: bool = _is_passable(nr + int(off[0]), nc)
				var cn2: bool = _is_passable(nr, nc + int(off[1]))
				if not cn1 or not cn2:
					step *= 3.0  # heavily penalise corner-cutting past a building
			match tmap[nnr][nnc]:
				TILE_ROAD: step *= 0.5   # strongly prefer roads
				TILE_TREE: step *= 1.4   # slow through vegetation
			var ng: float = float(g_cost.get(key, 0.0)) + step
			if not g_cost.has(nk) or ng < float(g_cost.get(nk, INF)):
				g_cost[nk] = ng; par_map[nk] = key
				open_set.append([ng + _heur(nnr,nnc,tr,tc), ng, nnr, nnc])
	if not found: return [to_world]
	var path_keys: Array = []
	var cur: int = goal_key
	while cur != sk and par_map.has(cur):
		path_keys.push_front(cur); cur = int(par_map[cur])
	var waypoints: Array = []
	for pk in path_keys:
		var pki: int = int(pk)
		waypoints.append(Vector3(_tx(pki % TG), 0.0, _tz(pki / TG)))
	# Final waypoint: use exact click pos only if that tile is passable, otherwise use snapped goal
	var fw_r := clampi(int((to_world.z + HALF) / TCELL), 0, TG-1)
	var fw_c := clampi(int((to_world.x + HALF) / TCELL), 0, TG-1)
	if _is_passable(fw_r, fw_c):
		waypoints.append(Vector3(to_world.x, 0.0, to_world.z))
	else:
		waypoints.append(Vector3(_tx(tc), 0.0, _tz(tr)))
	return waypoints

func _move_with_path(u: Unit, dest: Vector3) -> void:
	u.attack_move = false
	u.garrison_pending = Vector2i(-1, -1)
	_squad_speed.erase(u)
	_squad_dest.erase(u)
	var wp := _find_path(u.global_position, dest)
	u.path = wp; u.path_idx = 0; u.state = Unit.State.MOVING

func _step_path(u: Unit, delta: float) -> void:
	var spd: float = _squad_speed.get(u, u.speed) if _squad_speed.has(u) else u.speed
	if u.path.is_empty() or u.path_idx >= u.path.size():
		# Squad move: walk the short distance from the shared wp to the individual formation slot
		if _squad_dest.has(u):
			var slot: Vector3 = _squad_dest[u]; slot.y = 0.0
			var here2 := u.global_position; here2.y = 0.0
			if here2.distance_to(slot) > 0.25:
				var d2 := (slot - here2).normalized()
				var next2 := here2 + d2 * spd * delta
				var snr := clampi(int((next2.z + HALF) / TCELL), 0, TG-1)
				var snc := clampi(int((next2.x + HALF) / TCELL), 0, TG-1)
				if _is_passable(snr, snc):
					u.position = Vector3(next2.x, 0.0, next2.z)
					u.rotation.y = atan2(d2.x, d2.z)
				else:
					_squad_speed.erase(u); _squad_dest.erase(u)
				return
			_squad_speed.erase(u); _squad_dest.erase(u)
		u.state = Unit.State.HOLDING; return
	var wp: Vector3 = u.path[u.path_idx]
	wp.y = 0.0
	var here := u.global_position; here.y = 0.0
	var dist: float = here.distance_to(wp)
	if dist < 0.22:
		u.path_idx += 1
		if u.path_idx >= u.path.size(): u.state = Unit.State.HOLDING
		return
	var dir: Vector3 = (wp - here).normalized()
	u.position += dir * spd * delta
	u.position.y = 0.0
	u.rotation.y = atan2(dir.x, dir.z)

func _fire(shooter: Unit, target: Unit) -> void:
	if not _has_los(shooter.global_position, target.global_position): return
	shooter.fire_timer = 1.0 / shooter.fire_rate
	var dmg: int = shooter.dmg_min + randi() % maxi(1, shooter.dmg_max - shooter.dmg_min + 1)
	if target.garrisoned:
		var mod := BUNKER_DMG_MOD if _bunker_tiles.has(target.garrison_tile) else GARRISON_DMG_MOD
		dmg = int(float(dmg) * mod)
	elif target.in_cover:
		dmg = int(float(dmg) * 0.70)
	# Veteran accuracy bonus: +5% dmg per kill tier (max 3 tiers)
	if shooter.vet_kills >= 5:
		dmg = int(float(dmg) * (1.0 + 0.05 * minf(float(shooter.vet_kills) / 5.0, 3.0)))
	target.take_damage(dmg)
	if target.hp <= 0:
		shooter.vet_kills += 1
		_refresh_vet_stars(shooter)
	_flash_hit(target)
	_spawn_hit_spark(target.global_position + Vector3(0.0, 0.5, 0.0))
	_spawn_muzzle(shooter.global_position + Vector3(0.0,0.6,0.0), target.global_position)
	# Shot sound
	match shooter.kind:
		"sniper","e_sniper": Sounds.play("shot_sniper", -4.0)
		"mg_team","e_mg":    Sounds.play("shot_mg",     -2.0)
		_:                   Sounds.play("shot_rifle",   -3.0)
	# Grenadier area splash
	if shooter.kind in ["grenadier","e_gren"]:
		_spawn_explosion(target.global_position)
		var splash_dmg := int(float(dmg) * 0.55)
		for u in units:
			var ou := u as Unit
			if ou == null or ou == target or ou.hp <= 0 or ou.team == shooter.team: continue
			if ou.global_position.distance_to(target.global_position) <= 2.2:
				ou.take_damage(splash_dmg)

func _flash_hit(u: Unit) -> void:
	# Brief white-orange emission pulse on all MeshInstances inside the unit body
	for child in u.get_children():
		var body := child as Node3D
		if body == null: continue
		var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel == null: continue
		for mi_node in skel.get_children():
			var mi := mi_node as MeshInstance3D
			if mi == null or mi.mesh == null: continue
			for surf in mi.mesh.get_surface_count():
				var orig := mi.get_surface_override_material(surf) as StandardMaterial3D
				if orig == null: continue
				var flash := orig.duplicate() as StandardMaterial3D
				flash.emission_enabled = true
				flash.emission = Color(1.0, 0.65, 0.30) * 3.5
				mi.set_surface_override_material(surf, flash)
				var tw := create_tween()
				tw.tween_interval(0.05)
				tw.tween_callback(func(): if is_instance_valid(mi): mi.set_surface_override_material(surf, orig))

func _spawn_explosion(pos: Vector3) -> void:
	Sounds.play("explode", -2.0)
	# Flash sphere
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.78, 0.28, 0.95)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.5, 0.05) * 5.0
	var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 1.1
	sm.radial_segments = 8; sm.rings = 5
	var sphere := MeshInstance3D.new(); sphere.mesh = sm
	sphere.set_surface_override_material(0, fmat)
	sphere.position = pos + Vector3(0.0, 0.55, 0.0); add_child(sphere)
	var st := create_tween().set_parallel(true)
	st.tween_property(sphere, "scale", Vector3(2.8, 2.8, 2.8), 0.18).set_ease(Tween.EASE_OUT)
	st.tween_property(fmat, "albedo_color:a", 0.0, 0.20)
	st.finished.connect(func()->void: if is_instance_valid(sphere): sphere.queue_free())
	# Expanding shock ring
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.6, 0.15, 0.75)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.emission_enabled = true; rmat.emission = Color(1.0, 0.38, 0.0) * 2.0
	var rm := TorusMesh.new(); rm.inner_radius = 0.15; rm.outer_radius = 0.45
	rm.rings = 4; rm.ring_segments = 14
	var ring := MeshInstance3D.new(); ring.mesh = rm
	ring.set_surface_override_material(0, rmat)
	ring.position = pos + Vector3(0.0, 0.08, 0.0); ring.rotation.x = -PI / 2.0
	add_child(ring)
	var rt := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	rt.tween_property(ring, "scale", Vector3(7.0, 7.0, 7.0), 0.42)
	rt.tween_property(rmat, "albedo_color:a", 0.0, 0.40)
	rt.finished.connect(func()->void: if is_instance_valid(ring): ring.queue_free())
	# Explosion light — bright orange flash that fades over 0.35s
	var elight := OmniLight3D.new()
	elight.light_color  = Color(1.0, 0.52, 0.12)
	elight.light_energy = 18.0
	elight.omni_range   = 14.0
	elight.position     = pos + Vector3(0.0, 0.5, 0.0)
	add_child(elight)
	var etw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	etw.tween_property(elight, "light_energy", 0.0, 0.35)
	etw.tween_callback(elight.queue_free)
	# Lingering smoke cloud
	_spawn_smoke(pos)
	# Screen shake scaled by distance to camera
	var dist := camera_pivot.global_position.distance_to(pos)
	if dist < 14.0:
		_apply_shake(maxf(0.05, 0.45 * (1.0 - dist / 14.0)))

func _apply_shake(intensity: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = 0.35

func _spawn_hit_spark(pos: Vector3) -> void:
	for i in 6:
		var angle: float = _rng.randf() * TAU
		var spd: float   = _rng.randf_range(1.8, 4.2)
		var up: float    = _rng.randf_range(0.3, 1.0)
		var dir := Vector3(cos(angle)*spd, up*spd, sin(angle)*spd)
		var smat := StandardMaterial3D.new()
		smat.albedo_color   = Color(1.0, 0.35 + _rng.randf()*0.45, 0.05)
		smat.emission_enabled = true
		smat.emission       = smat.albedo_color * 4.0
		smat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
		var sz: float = _rng.randf_range(0.04, 0.09)
		var spark := _box(Vector3(sz, sz, sz), smat)
		spark.position = pos; add_child(spark)
		var dur: float = _rng.randf_range(0.06, 0.16)
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "position", pos + dir * dur, dur)
		tw.tween_property(smat, "albedo_color:a", 0.0, dur)
		tw.finished.connect(func()->void: if is_instance_valid(spark): spark.queue_free())

func _spawn_smoke(pos: Vector3) -> void:
	for i in 5:
		var fi := float(i)
		var smat := StandardMaterial3D.new()
		var grey: float = 0.42 + fi * 0.06
		smat.albedo_color = Color(grey, grey * 0.97, grey * 0.93, 0.62 - fi*0.08)
		smat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.billboard_mode  = BaseMaterial3D.BILLBOARD_ENABLED
		smat.billboard_keep_scale = true
		var r0: float = 0.22 + fi*0.10
		var sm := SphereMesh.new()
		sm.radius = r0; sm.height = r0 * 1.5
		sm.radial_segments = 7; sm.rings = 5
		var s := MeshInstance3D.new(); s.mesh = sm
		s.set_surface_override_material(0, smat)
		var off := Vector3(_rng.randf_range(-0.5,0.5), fi*0.28 + _rng.randf()*0.15, _rng.randf_range(-0.5,0.5))
		s.position = pos + off + Vector3(0.0, 0.3, 0.0)
		add_child(s)
		var dur: float = 1.0 + fi*0.40
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3(4.5, 4.5, 4.5), dur)
		tw.tween_property(smat, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.finished.connect(func()->void: if is_instance_valid(s): s.queue_free())

func _issue_attack_move(wp: Vector3) -> void:
	var alive: Array = []
	for s in sel_units:
		var su := s as Unit
		if su != null and su.hp > 0: alive.append(su)
	if alive.is_empty(): return
	var positions := _assign_formation(alive, wp)
	for i in alive.size():
		var su := alive[i] as Unit
		_move_with_path(su, positions[i] as Vector3)
		su.attack_move = true
	var count := alive.size()
	var lbl: String = UNIT_DEFS[(alive[0] as Unit).kind].name if count == 1 else "%d units" % count
	_set_status("ATTACK-MOVING %s" % lbl)

# ── MINIMAP ───────────────────────────────────────────────────

const MM_SIZE   := 180.0
const MM_MARGIN := 14.0

func _build_minimap() -> void:
	_mm_layer = CanvasLayer.new(); _mm_layer.layer = 8; add_child(_mm_layer)
	_mm_panel = Control.new()
	_mm_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mm_panel.offset_left   = -(MM_SIZE + MM_MARGIN)
	_mm_panel.offset_top    = -(MM_SIZE + MM_MARGIN)
	_mm_panel.offset_right  = -MM_MARGIN
	_mm_panel.offset_bottom = -MM_MARGIN
	_mm_panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	_mm_panel.gui_input.connect(_on_minimap_click)
	_mm_layer.add_child(_mm_panel)
	# Dark border panel
	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.04, 0.08, 0.04, 0.85)
	ps.border_color = Color(0.22, 0.50, 0.22, 0.88)
	ps.set_border_width_all(2); ps.set_corner_radius_all(3)
	border.add_theme_stylebox_override("panel", ps)
	_mm_panel.add_child(border)
	# Terrain texture
	var tr := TextureRect.new()
	tr.texture = _build_minimap_texture()
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mm_panel.add_child(tr)
	# Camera viewport rect
	_mm_cam_rect = ColorRect.new()
	_mm_cam_rect.color = Color(1.0, 1.0, 1.0, 0.18)
	_mm_cam_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mm_panel.add_child(_mm_cam_rect)
	# CP dots (dynamic — colored by owner, updated each frame)
	_mm_cp_dots.clear()
	for cp in capture_points:
		var dot := ColorRect.new()
		dot.size = Vector2(8.0, 8.0)
		dot.color = Color(0.95, 0.85, 0.10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mp := _mm_w2s(Vector3(float(cp.x), 0.0, float(cp.z)))
		dot.position = mp - dot.size * 0.5
		_mm_panel.add_child(dot)
		_mm_cp_dots.append(dot)

func _build_minimap_texture() -> ImageTexture:
	var img := Image.create(TG, TG, false, Image.FORMAT_RGB8)
	for r in TG:
		for c in TG:
			var col: Color
			match tmap[r][c]:
				TILE_ROAD:     col = Color(0.24, 0.24, 0.24)
				TILE_BUILDING: col = Color(0.48, 0.44, 0.38)
				TILE_TREE:     col = Color(0.10, 0.26, 0.07)
				TILE_WATER:    col = Color(0.08, 0.20, 0.40)
				TILE_PARK:     col = Color(0.14, 0.32, 0.10)
				_:             col = Color(0.12, 0.16, 0.09)
			img.set_pixel(c, r, col)
	# Mark HQ zones
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			img.set_pixel(clampi(18+dc,0,TG-1), clampi(18+dr,0,TG-1), Color(0.28, 1.0, 0.43))
			img.set_pixel(clampi(2+dc,0,TG-1),  clampi(2+dr,0,TG-1),  Color(1.0, 0.22, 0.15))
	# Mark capture points
	for cp_v in CP_DEFS:
		var cc: int = clampi(int((float(cp_v.x) + HALF) / TCELL), 0, TG-1)
		var cr: int = clampi(int((float(cp_v.y) + HALF) / TCELL), 0, TG-1)
		img.set_pixel(cc, cr, Color(0.95, 0.85, 0.10))
	return ImageTexture.create_from_image(img)

func _update_minimap() -> void:
	if _mm_panel == null: return
	for u in _mm_dots:
		var unit := u as Unit
		var dot  := _mm_dots[u] as ColorRect
		if unit == null or dot == null: continue
		var mp := _mm_w2s(unit.global_position)
		dot.position = mp - dot.size * 0.5
	if _mm_cam_rect:
		var ctr   := _mm_w2s(Vector3(cam_target.x, 0.0, cam_target.z))
		var ppw   := MM_SIZE / (HALF * 2.0)
		var vw    := cam_zoom * ppw * 1.25
		var vh    := vw * 0.58
		_mm_cam_rect.size     = Vector2(vw, vh)
		_mm_cam_rect.position = ctr - _mm_cam_rect.size * 0.5
	# Update CP dot colors to reflect current ownership
	for i in _mm_cp_dots.size():
		if i >= capture_points.size(): break
		var dot := _mm_cp_dots[i] as ColorRect
		if dot == null: continue
		var cp_owner: String = str(capture_points[i].owner)
		match cp_owner:
			"player": dot.color = Color(0.28, 1.0, 0.43)
			"enemy":  dot.color = Color(1.0, 0.22, 0.15)
			_:        dot.color = Color(0.95, 0.85, 0.10)

func _add_mm_dot(u: Unit) -> void:
	if _mm_panel == null: return
	var dot := ColorRect.new()
	dot.size         = Vector2(5.0, 5.0)
	dot.color        = Color(0.28, 1.0, 0.43, 0.95) if u.team == "player" else Color(1.0, 0.22, 0.15, 0.95)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mm_panel.add_child(dot)
	_mm_dots[u] = dot

func _on_minimap_click(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			var world := _mm_s2w(e.position)
			cam_target.x = world.x; cam_target.z = world.z
	elif event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var world := _mm_s2w(e.position)
			cam_target.x = world.x; cam_target.z = world.z

func _mm_w2s(world: Vector3) -> Vector2:
	return Vector2((world.x + HALF) / (HALF*2.0), (world.z + HALF) / (HALF*2.0)) * MM_SIZE

func _mm_s2w(mm: Vector2) -> Vector3:
	return Vector3(mm.x / MM_SIZE * HALF*2.0 - HALF, 0.0, mm.y / MM_SIZE * HALF*2.0 - HALF)

func _init_fog() -> void:
	fog = []
	for _r in TG:
		var row: Array = []; for _c in TG: row.append(0)
		fog.append(row)
	# Pre-reveal the player HQ area so they can see their start zone
	var hq_col := clampi(int((HQ_X + HALF) / TCELL), 0, TG - 1)
	var hq_row := clampi(int((HQ_Z + HALF) / TCELL), 0, TG - 1)
	for dr in range(-4, 5):
		for dc in range(-4, 5):
			if dr*dr + dc*dc <= 20:
				var r := hq_row + dr; var c := hq_col + dc
				if r >= 0 and r < TG and c >= 0 and c < TG:
					fog[r][c] = 1
	# Build fog overlay mesh
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 2.0 + 2.0, HALF * 2.0 + 2.0)
	_fog_mesh = MeshInstance3D.new()
	_fog_mesh.mesh = pm
	_fog_mesh.position = Vector3(0.0, 0.5, 0.0)
	_fog_img = Image.create(TG, TG, false, Image.FORMAT_RGBA8)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	var mat := StandardMaterial3D.new()
	mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = 127
	mat.texture_filter  = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.albedo_texture  = _fog_tex
	_fog_mesh.set_surface_override_material(0, mat)
	add_child(_fog_mesh)

func _update_fog() -> void:
	# Decay visible → seen
	for r in TG:
		for c in TG:
			if fog[r][c] == 2: fog[r][c] = 1
	# Reveal tiles in range of each living player unit
	for u in units:
		var unit := u as Unit
		if unit == null or unit.hp <= 0 or unit.team != "player": continue
		var vision: int = VISION_R_SNIP if unit.kind == "sniper" else VISION_R
		var uc := clampi(int((unit.global_position.x + HALF) / TCELL), 0, TG - 1)
		var ur := clampi(int((unit.global_position.z + HALF) / TCELL), 0, TG - 1)
		for dr in range(-vision, vision + 1):
			for dc in range(-vision, vision + 1):
				if dr*dr + dc*dc > vision*vision: continue
				var r := ur + dr; var c := uc + dc
				if r >= 0 and r < TG and c >= 0 and c < TG:
					fog[r][c] = 2
	# Repaint fog texture
	for r in TG:
		for c in TG:
			var a: float
			match fog[r][c]:
				0: a = 0.93
				1: a = 0.55
				_: a = 0.0
			_fog_img.set_pixel(c, r, Color(0.0, 0.01, 0.04, a))
	_fog_tex.update(_fog_img)
	# Show/hide enemy units and their minimap dots
	for u in units:
		var unit := u as Unit
		if unit == null or unit.team != "enemy": continue
		var ec := clampi(int((unit.global_position.x + HALF) / TCELL), 0, TG - 1)
		var er := clampi(int((unit.global_position.z + HALF) / TCELL), 0, TG - 1)
		var in_sight: bool = fog[er][ec] == 2
		unit.visible = in_sight
		if _mm_dots.has(unit):
			var dot := _mm_dots[unit] as ColorRect
			if dot: dot.visible = in_sight

func _nearest_enemy(u: Unit, max_r: float) -> Unit:
	var best: Unit = null
	var best_d: float = max_r
	var et: String
	if u.team == "player":   et = "enemy"
	elif u.team == "enemy":  et = "player"
	else:                    return null
	for other in units:
		var ou := other as Unit
		if ou == null or ou.team != et or ou.hp <= 0: continue
		var d: float = u.global_position.distance_to(ou.global_position)
		if d < best_d: best_d = d; best = ou
	return best

func _spawn_muzzle(from: Vector3, to: Vector3) -> void:
	# Muzzle flash sprite
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0,0.92,0.5)
	mat.emission_enabled = true; mat.emission = Color(1.0,0.7,0.2)*4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flash := _box(Vector3(0.14,0.14,0.14), mat)
	flash.position = from; add_child(flash)
	get_tree().create_timer(0.06).timeout.connect(func()->void: if is_instance_valid(flash): flash.queue_free())
	# Muzzle light — illuminates nearby geometry and units for one frame
	var mlight := OmniLight3D.new()
	mlight.light_color  = Color(1.0, 0.78, 0.38)
	mlight.light_energy = 5.0
	mlight.omni_range   = 6.0
	mlight.position = from
	add_child(mlight)
	get_tree().create_timer(0.06).timeout.connect(func()->void: if is_instance_valid(mlight): mlight.queue_free())
	# Tracer line (thin box between from and to)
	var mid := (from+to)*0.5; var len: float = from.distance_to(to)
	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.albedo_color = Color(1.0,0.95,0.7,0.55)
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.emission_enabled = true
	tracer_mat.emission = Color(1.0,0.88,0.5) * 1.2
	var tracer := _box(Vector3(0.022,0.022,len), tracer_mat)
	tracer.position = mid
	tracer.look_at(to, Vector3.UP)
	add_child(tracer)
	get_tree().create_timer(0.05).timeout.connect(func()->void: if is_instance_valid(tracer): tracer.queue_free())

# ── CAMERA ────────────────────────────────────────────────────

func _update_camera(delta: float) -> void:
	# Q/E rotate camera yaw
	if Input.is_key_pressed(KEY_Q): cam_yaw += delta * 1.6
	if Input.is_key_pressed(KEY_E): cam_yaw -= delta * 1.6

	# WASD / arrow key pan — corrected for camera yaw so W always moves "up screen"
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    kb.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  kb.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  kb.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): kb.x += 1.0
	if kb.length() > 0.0:
		var spd: float = 18.0 * delta
		var kbn := kb.normalized()
		var cy := cos(cam_yaw); var sy := sin(cam_yaw)
		cam_target.x = clampf(cam_target.x + (kbn.x * cy + kbn.y * sy) * spd, -HALF, HALF)
		cam_target.z = clampf(cam_target.z + (-kbn.x * sy + kbn.y * cy) * spd, -HALF, HALF)
	var cam_dest := Vector3(cam_target.x, 0.0, cam_target.z)
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var t := _shake_timer / 0.35
		cam_dest += Vector3(_rng.randf_range(-1.0,1.0), 0.0, _rng.randf_range(-1.0,1.0)) * _shake_intensity * t
	else:
		_shake_intensity = 0.0
	camera_pivot.position = camera_pivot.position.lerp(cam_dest, delta*5.0)
	camera_pivot.rotation.y = cam_yaw
	camera.position.y = lerpf(camera.position.y, cam_zoom,       delta*4.0)
	camera.position.z = lerpf(camera.position.z, cam_zoom*0.78,  delta*4.0)
	camera.look_at(camera_pivot.global_position, Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var e := event as InputEventKey
		if e.pressed and not e.echo:
			if e.keycode == KEY_ESCAPE:
				if game_paused: _hide_pause()
				elif game_active: _show_pause()
				return
			if not game_paused and game_active and e.keycode == KEY_A:
				if not sel_units.is_empty():
					cur_mode = "attack_move"
					_set_status("ATTACK-MOVE — CLICK DESTINATION, ENGAGE ON SIGHT")
				return
	if game_paused: return
	if event is InputEventScreenTouch:
		_is_touch_device = true
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touches[e.index]      = e.position
			_touches_prev[e.index] = e.position
			if _touches.size() == 1:
				_drag_moved = false
				_drag_sx = e.position.x; _drag_sy = e.position.y
		else:
			if _touches.size() == 1 and not _drag_moved:
				_handle_tap(e.position)
			_touches.erase(e.index)
			_touches_prev.erase(e.index)
			_drag_moved = false
			if _touches.size() == 1:
				var remaining: Vector2 = _touches.values()[0]
				_drag_sx = remaining.x; _drag_sy = remaining.y
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_touches_prev[e.index] = _touches.get(e.index, e.position)
		_touches[e.index]      = e.position
		if _touches.size() < 2:
			# Single finger — pan
			var prev: Vector2 = _touches_prev.get(e.index, e.position)
			var cy := cos(cam_yaw); var sy := sin(cam_yaw)
			var rx := (e.position.x - prev.x) * 0.045
			var ry := (e.position.y - prev.y) * 0.045
			cam_target.x -= rx * cy + ry * sy
			cam_target.z -= -rx * sy + ry * cy
			cam_target.x = clampf(cam_target.x, -HALF, HALF)
			cam_target.z = clampf(cam_target.z, -HALF, HALF)
			if absf(e.position.x - _drag_sx) > 8.0 or absf(e.position.y - _drag_sy) > 8.0:
				_drag_moved = true
		else:
			# Two fingers — pinch (zoom) + twist (rotate) + midpoint (pan)
			var keys    := _touches.keys()
			var a_cur   : Vector2 = _touches[keys[0]]
			var b_cur   : Vector2 = _touches[keys[1]]
			var a_prv   : Vector2 = _touches_prev.get(keys[0], a_cur)
			var b_prv   : Vector2 = _touches_prev.get(keys[1], b_cur)
			var mid_cur := (a_cur + b_cur) * 0.5
			var mid_prv := (a_prv + b_prv) * 0.5
			var dist_cur := a_cur.distance_to(b_cur)
			var dist_prv := a_prv.distance_to(b_prv)
			var ang_cur  := atan2(b_cur.y - a_cur.y, b_cur.x - a_cur.x)
			var ang_prv  := atan2(b_prv.y - a_prv.y, b_prv.x - a_prv.x)
			# Pinch → zoom
			if dist_prv > 5.0:
				cam_zoom = clampf(cam_zoom * (dist_prv / dist_cur), 10.0, 55.0)
			# Twist → rotate
			var dang := ang_cur - ang_prv
			while dang >  PI: dang -= TAU
			while dang < -PI: dang += TAU
			cam_yaw -= dang
			# Midpoint drag → pan
			var dm := mid_cur - mid_prv
			var cy := cos(cam_yaw); var sy := sin(cam_yaw)
			var rx := dm.x * 0.045; var ry := dm.y * 0.045
			cam_target.x -= rx * cy + ry * sy
			cam_target.z -= -rx * sy + ry * cy
			cam_target.x = clampf(cam_target.x, -HALF, HALF)
			cam_target.z = clampf(cam_target.z, -HALF, HALF)
			_drag_moved = true
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = clampf(cam_zoom-2.5, 10.0, 55.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom+2.5, 10.0, 55.0)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_drag_sx=e.position.x; _drag_sy=e.position.y
				_drag_moved=false; _lmarquee=false
			else:
				if _lmarquee:
					_finish_marquee(e.position); _lmarquee=false; _drag_moved=false
				elif not _drag_moved:
					_handle_tap(e.position)
				_drag_moved=false
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			if e.pressed:
				_drag_on=true; _drag_lx=e.position.x; _drag_ly=e.position.y
				_rdrag_moved=false; _rdrag_sx=e.position.x; _rdrag_sy=e.position.y
			else:
				_drag_on=false
				if not _rdrag_moved and game_active:
					_handle_right_click(e.position)
	elif event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		if _drag_on and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var cy := cos(cam_yaw); var sy := sin(cam_yaw)
			var rx := e.relative.x * 0.06; var ry := e.relative.y * 0.06
			cam_target.x -= rx * cy + ry * sy
			cam_target.z -= -rx * sy + ry * cy
			cam_target.x=clampf(cam_target.x,-HALF,HALF)
			cam_target.z=clampf(cam_target.z,-HALF,HALF)
			if e.relative.length()>3.0: _rdrag_moved=true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			cam_yaw -= e.relative.x * 0.008
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _lmarquee:
				if absf(e.position.x-_drag_sx)>8.0 or absf(e.position.y-_drag_sy)>8.0:
					_lmarquee=true; _lmarquee_sx=_drag_sx; _lmarquee_sy=_drag_sy
					_drag_moved=true
					if _sel_box_layer: _sel_box_layer.visible=true
			if _lmarquee: _update_marquee(e.position)

# ── INPUT / TAP ───────────────────────────────────────────────

func _handle_tap(screen_pos: Vector2) -> void:
	if not game_active: return
	var wp := _ground_hit(screen_pos)

	# Deploy mode: tap green zone to place
	if deploying_kind != "":
		if wp != Vector3.ZERO:
			_do_deploy(deploying_kind, wp.x, wp.z)
		else:
			_reset_deploy_btn(deploying_kind); deploying_kind = ""
			_set_status("DEPLOY CANCELLED")
		return

	# Mortar mode: tap fires (right-click also works on desktop)
	if _mortar_mode:
		if wp != Vector3.ZERO:
			_mortar_mode = false
			_fire_mortar(wp)
		else:
			_mortar_mode = false
			_set_status("MORTAR CANCELLED")
		return

	var tapped := _unit_at(wp)

	if not sel_units.is_empty():
		# Explicit modes set by command buttons
		match cur_mode:
			"move":
				if wp != Vector3.ZERO:
					_issue_move_group(wp); cur_mode = "none"; return
			"attack_move":
				if wp != Vector3.ZERO:
					_issue_attack_move(wp); cur_mode = "none"; return
			"attack":
				if tapped != null and tapped.team == "enemy":
					for u in sel_units:
						var su := u as Unit
						if su: su.state = Unit.State.ATTACKING
					_set_status("ENGAGING TARGET"); return
			"grenade":
				if sel_unit != null and sel_unit.hp > 0 and wp != Vector3.ZERO:
					_fire_grenade(sel_unit, wp)
				cur_mode = "none"; return

		# Context-sensitive smart tap — the primary mobile command path
		if tapped != null and tapped.team == "player":
			# Tap allied unit → add/remove from selection
			_toggle_unit_select(tapped); return
		if tapped != null and tapped.team == "enemy":
			# Tap enemy → engage all selected units
			for u in sel_units:
				var su := u as Unit
				if su and su.hp > 0: su.state = Unit.State.ATTACKING
			_set_status("ENGAGING"); return
		if wp != Vector3.ZERO:
			# Tap world → garrison or move
			var used := false
			for cp in capture_points:
				var cp_pos := Vector3(float(cp.x), 0.0, float(cp.z))
				if wp.distance_to(cp_pos) < 2.8:
					_order_garrison(cp["tile"] as Vector2i)
					used = true; break
			if not used:
				var hit_r := clampi(int((wp.z + HALF) / TCELL), 0, TG - 1)
				var hit_c := clampi(int((wp.x + HALF) / TCELL), 0, TG - 1)
				if tmap[hit_r][hit_c] == TILE_BUILDING:
					_order_garrison(Vector2i(hit_r, hit_c))
				else:
					_issue_move_group(wp)
		return

	# Nothing selected — tap unit to select
	if tapped != null and tapped.team == "player":
		_select_unit(tapped); return

	_deselect()

func _unit_at(world_pos: Vector3) -> Unit:
	if world_pos == Vector3.ZERO: return null
	var best: Unit = null
	var best_d: float = 1.6   # tap pick radius in world units
	var wp2 := Vector2(world_pos.x, world_pos.z)
	for u in units:
		var unit := u as Unit
		if unit == null or unit.hp <= 0: continue
		var d := wp2.distance_to(Vector2(unit.global_position.x, unit.global_position.z))
		if d < best_d: best_d = d; best = unit
	return best

func _select_unit(u: Unit) -> void:
	for s in sel_units:
		var su := s as Unit
		if su: su.set_selected(false)
	sel_units.clear()
	sel_unit = u; sel_unit.set_selected(true)
	sel_units.append(u)
	cur_mode = "none"
	Sounds.play("click", -12.0)
	_update_unit_info()
	_set_status("SELECTED: %s  |  TAP TO MOVE OR ATTACK" % UNIT_DEFS[u.kind].name)

func _deselect() -> void:
	for s in sel_units:
		var su := s as Unit
		if su: su.set_selected(false)
	sel_units.clear()
	sel_unit = null; cur_mode = "none"
	_update_unit_info()

func _toggle_unit_select(u: Unit) -> void:
	if sel_units.has(u):
		u.set_selected(false)
		sel_units.erase(u)
		if sel_units.is_empty():
			sel_unit = null; cur_mode = "none"
		else:
			sel_unit = sel_units[sel_units.size() - 1] as Unit
		_update_unit_info()
	else:
		u.set_selected(true)
		sel_units.append(u)
		sel_unit = u
		cur_mode = "none"
		Sounds.play("click", -12.0)
		_update_unit_info()

func _cmd_cancel() -> void:
	if _mortar_mode:
		_mortar_mode = false
		if _mortar_btn: _mortar_btn.modulate = Color(1, 1, 1)
		_set_status("MORTAR CANCELLED")
	elif cur_mode == "grenade":
		cur_mode = "none"
		_set_status("GRENADE CANCELLED")
		_update_unit_info()
	elif cur_mode != "none":
		cur_mode = "none"
		_set_status("COMMAND CANCELLED")
	elif deploying_kind != "":
		_reset_deploy_btn(deploying_kind); deploying_kind = ""
		_set_status("DEPLOY CANCELLED")
	else:
		_deselect()

func _snap_passable(pos: Vector3) -> Vector3:
	var r := clampi(int((pos.z + HALF) / TCELL), 0, TG - 1)
	var c := clampi(int((pos.x + HALF) / TCELL), 0, TG - 1)
	var rc := _nearest_passable(r, c)
	return Vector3(_tx(rc.y), 0.0, _tz(rc.x))

func _assign_formation(alive: Array, wp: Vector3) -> Array:
	# Returns Array[Vector3] indexed by alive[], each element is that unit's formation slot.
	var count := alive.size()
	if count == 1: return [_snap_passable(wp)]
	var centroid := Vector3.ZERO
	for su in alive: centroid += (su as Unit).global_position
	centroid /= float(count)
	var fwd := (wp - centroid); fwd.y = 0.0
	if fwd.length() < 0.1: fwd = Vector3(0.0, 0.0, 1.0)
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	# Build grid of slot world positions (rows of 2 or 3, front row centred on wp)
	var cols := 3 if count >= 5 else 2
	var lat := 1.3; var dep := 1.6
	var slots: Array = []
	for i in count:
		var row := i / cols; var col := i % cols
		var rw := mini(cols, count - row * cols)
		var raw := wp + right * (float(col) - float(rw - 1) * 0.5) * lat - fwd * float(row) * dep
		slots.append(_snap_passable(raw))
	# Greedy: assign each slot to nearest unassigned unit
	var taken: Array = []; taken.resize(count); for i in count: taken[i] = false
	var result: Array = []; result.resize(count)
	for slot_i in count:
		var slot_wp: Vector3 = slots[slot_i]
		var best_d := INF; var best_i := -1
		for ui in count:
			if taken[ui]: continue
			var d := (alive[ui] as Unit).global_position.distance_to(slot_wp)
			if d < best_d: best_d = d; best_i = ui
		taken[best_i] = true
		result[best_i] = slot_wp
	return result

func _issue_move_group(wp: Vector3) -> void:
	var alive: Array = []
	for s in sel_units:
		var su := s as Unit
		if su != null and su.hp > 0: alive.append(su)
	if alive.is_empty(): return
	if alive.size() == 1:
		_move_with_path(alive[0] as Unit, wp)
	else:
		# Squad move: all units travel to the same point at the slowest unit's speed,
		# then each walks to its individual formation slot on arrival.
		var min_spd := INF
		var max_spd := 0.0
		for su in alive:
			min_spd = minf(min_spd, (su as Unit).speed)
			max_spd = maxf(max_spd, (su as Unit).speed)
		# Never slow the squad below 65% of the fastest unit
		var squad_spd := maxf(min_spd, max_spd * 0.65)
		var slots := _assign_formation(alive, wp)
		for i in alive.size():
			var su := alive[i] as Unit
			_move_with_path(su, wp)       # clears old squad state, starts path to shared wp
			_squad_speed[su] = squad_spd  # override speed after path is set
			_squad_dest[su]  = slots[i]   # formation slot to occupy on arrival
	var count := alive.size()
	var lbl: String = UNIT_DEFS[(alive[0] as Unit).kind].name if count == 1 else "%d units" % count
	_set_status("MOVING %s" % lbl)

func _handle_right_click(screen_pos: Vector2) -> void:
	if deploying_kind != "":
		_reset_deploy_btn(deploying_kind)
		deploying_kind = ""
		_set_status("DEPLOY CANCELLED"); return
	# Mortar mode is global — doesn't require a selected unit
	if _mortar_mode:
		var wpm := _ground_hit(screen_pos)
		if wpm != Vector3.ZERO:
			_mortar_mode = false
			_fire_mortar(wpm)
		else:
			_mortar_mode = false
			_set_status("MORTAR CANCELLED")
		return
	if sel_units.is_empty(): return
	var wp := _ground_hit(screen_pos)
	if wp == Vector3.ZERO: return
	var tapped := _unit_at(wp)
	if cur_mode == "grenade":
		if sel_unit and sel_unit.hp > 0:
			_fire_grenade(sel_unit, wp)
		cur_mode = "none"; return
	if cur_mode == "attack_move":
		_issue_attack_move(wp); cur_mode = "none"; return
	if tapped != null and tapped.team == "enemy":
		for u in sel_units:
			var su := u as Unit
			if su and su.hp > 0: su.state = Unit.State.ATTACKING
		_set_status("ENGAGING")
	else:
		# Right-click near a CP bunker → garrison in it
		var bunker_clicked := false
		if not sel_units.is_empty():
			for cp in capture_points:
				var cp_pos := Vector3(float(cp.x), 0.0, float(cp.z))
				if wp.distance_to(cp_pos) < 2.8:
					_order_garrison(cp["tile"] as Vector2i)
					bunker_clicked = true
					break
		if not bunker_clicked:
			# Right-click on a building tile → garrison order
			var hit_r := clampi(int((wp.z + HALF) / TCELL), 0, TG-1)
			var hit_c := clampi(int((wp.x + HALF) / TCELL), 0, TG-1)
			if tmap[hit_r][hit_c] == TILE_BUILDING and not sel_units.is_empty():
				_order_garrison(Vector2i(hit_r, hit_c))
			else:
				_issue_move_group(wp)

func _build_marquee() -> void:
	_sel_box_layer = CanvasLayer.new()
	_sel_box_layer.layer = 5; _sel_box_layer.visible = false
	add_child(_sel_box_layer)
	_sel_box = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color     = Color(0.28, 1.0, 0.43, 0.08)
	st.border_color = Color(0.28, 1.0, 0.43, 0.85)
	st.set_border_width_all(2)
	_sel_box.add_theme_stylebox_override("panel", st)
	_sel_box_layer.add_child(_sel_box)

func _update_marquee(cur: Vector2) -> void:
	if _sel_box == null: return
	_sel_box.position = Vector2(minf(_lmarquee_sx, cur.x), minf(_lmarquee_sy, cur.y))
	_sel_box.size     = Vector2(absf(cur.x-_lmarquee_sx), absf(cur.y-_lmarquee_sy))

func _finish_marquee(cur: Vector2) -> void:
	if _sel_box_layer: _sel_box_layer.visible = false
	var sx: float = minf(_lmarquee_sx, cur.x); var ex: float = maxf(_lmarquee_sx, cur.x)
	var sy: float = minf(_lmarquee_sy, cur.y); var ey: float = maxf(_lmarquee_sy, cur.y)
	if ex-sx < 5.0 and ey-sy < 5.0:
		_handle_tap(cur); return
	for s in sel_units:
		var su := s as Unit
		if su: su.set_selected(false)
	sel_units.clear(); sel_unit = null
	var box := Rect2(Vector2(sx, sy), Vector2(ex-sx, ey-sy))
	for u in units:
		var su := u as Unit
		if su == null or su.team != "player" or su.hp <= 0: continue
		var sp := camera.unproject_position(su.global_position)
		if box.has_point(sp):
			su.set_selected(true); sel_units.append(su)
	if not sel_units.is_empty():
		sel_unit = sel_units[0] as Unit
	cur_mode = "none"; _update_unit_info()
	if sel_units.size() > 1:
		_set_status("SELECTED %d UNITS  |  TAP TO COMMAND" % sel_units.size())
	elif sel_units.size() == 1 and sel_unit != null:
		_set_status("SELECTED: %s  |  TAP TO MOVE OR ATTACK" % UNIT_DEFS[sel_unit.kind].name)
	else:
		_set_status("DEFEND THE NEIGHBORHOOD  |  TAP TO SELECT AND COMMAND")

func _do_deploy(kind: String, px: float, pz: float) -> void:
	var def: Dictionary = UNIT_DEFS[kind]
	var cost: int = int(def.cost)
	if supplies < cost:
		_set_status("NOT ENOUGH SUPPLIES! NEED %d" % cost); return
	if Vector2(px,pz).distance_to(Vector2(HQ_X,HQ_Z)) > 8.0:
		_set_status("DEPLOY WITHIN THE GREEN ZONE"); return
	supplies -= cost
	spawn_unit(kind, "player", px, pz)
	Sounds.play("deploy", -3.0)
	# Keep deploying_kind active so player can place more without re-selecting
	_set_status("%s DEPLOYED  |  TAP TO PLACE ANOTHER  |  PRESS ✕ TO CANCEL" % def.name)

# ── RAYCASTING ────────────────────────────────────────────────

func _ground_hit(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir  := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001: return Vector3.ZERO
	var t := -from.y / dir.y
	if t < 0.0: return Vector3.ZERO
	var hit := from + dir * t
	hit.x = clampf(hit.x, -HALF+0.5, HALF-0.5)
	hit.z = clampf(hit.z, -HALF+0.5, HALF-0.5)
	return hit

# ── ENDGAME ───────────────────────────────────────────────────

func _show_endgame(victory: bool) -> void:
	if not game_active: return
	game_active = false
	Sounds.play("victory" if victory else "defeat", 0.0)
	var panel := $HUD/EndgamePanel as Control
	if panel == null: return
	panel.visible = true
	var title := panel.get_node("VBox/Title") as Label
	var sub   := panel.get_node("VBox/Sub")   as Label
	if victory:
		title.text     = "NEIGHBORHOOD DEFENDED!"
		title.modulate = Color(0.3, 1.0, 0.43)
		sub.text       = "All %d waves repelled.  KIA: %d" % [WAVE_DEFS.size(), kill_count]
	else:
		title.text     = "THE NEIGHBORHOOD HAS FALLEN"
		title.modulate = Color(1.0, 0.3, 0.2)
		var reason: String = "HQ destroyed." if hq_hp <= 0 else "Last defender fell."
		sub.text       = "%s  KIA: %d  Supplies remaining: %d" % [reason, kill_count, supplies]

# ── HUD ───────────────────────────────────────────────────────

func _setup_hud() -> void:
	for btn in deploy_panel.get_children():
		if btn is Button and btn.has_meta("kind"):
			var k: String = str(btn.get_meta("kind"))
			btn.pressed.connect(func()->void: Sounds.play("click",-6.0); _start_deploy(k))
	$HUD/UnitInfo/ModeBar/MoveBtn.pressed.connect(func()->void: Sounds.play("click",-8.0); _cmd_move())
	$HUD/UnitInfo/ModeBar/AtkBtn.pressed.connect(func()->void: Sounds.play("click",-8.0); _cmd_attack())
	$HUD/UnitInfo/ModeBar/HoldBtn.pressed.connect(func()->void: Sounds.play("click",-8.0); _cmd_hold())
	var ab := Button.new()
	ab.name = "AbilityBtn"
	ab.add_theme_font_size_override("font_size", 16)
	ab.custom_minimum_size = Vector2(130, 44)
	ab.visible = false
	ab.pressed.connect(func()->void: Sounds.play("click",-8.0); _use_ability())
	$HUD/UnitInfo/ModeBar.add_child(ab)
	_ability_btn = ab
	# Retreat button
	var rbt := Button.new()
	rbt.name = "RetreatBtn"
	rbt.text = "RETREAT"
	rbt.add_theme_font_size_override("font_size", 16)
	rbt.custom_minimum_size = Vector2(90, 44)
	rbt.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	rbt.pressed.connect(func()->void: Sounds.play("click",-8.0); _cmd_retreat())
	$HUD/UnitInfo/ModeBar.add_child(rbt)
	_retreat_btn = rbt
	# Cancel button — always last in ModeBar, dismisses any active mode or selection
	var cxb := Button.new()
	cxb.name = "CancelBtn"
	cxb.text = "✕"
	cxb.add_theme_font_size_override("font_size", 22)
	cxb.custom_minimum_size = Vector2(44, 44)
	cxb.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	cxb.pressed.connect(func()->void: Sounds.play("click",-10.0); _cmd_cancel())
	$HUD/UnitInfo/ModeBar.add_child(cxb)
	# Mortar strike button in TopBar
	var mb := Button.new()
	mb.name = "MortarBtn"
	mb.text = "MORTAR (60sup)"
	mb.add_theme_font_size_override("font_size", 14)
	mb.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	mb.pressed.connect(func()->void: Sounds.play("click",-6.0); _cmd_mortar())
	$HUD/TopBar.add_child(mb)
	_mortar_btn = mb
	var ret_btn := $HUD/EndgamePanel/VBox/ReturnBtn as Button
	if ret_btn:
		ret_btn.pressed.connect(func()->void: _main().show_globe())
	var pause_btn := $HUD/TopBar/PauseBtn as Button
	if pause_btn:
		pause_btn.pressed.connect(func()->void: if game_active: _show_pause())
	# Suppression screen tint — full-screen red overlay, alpha driven by suppression level
	var sup_ol := ColorRect.new()
	sup_ol.color = Color(0.82, 0.06, 0.04, 0.0)
	sup_ol.set_anchors_preset(Control.PRESET_FULL_RECT)
	sup_ol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(sup_ol)
	_suppression_overlay = sup_ol
	# Grenade cursor (AoE preview circle — hidden until grenade mode active)
	var gc_mesh := TorusMesh.new()
	gc_mesh.inner_radius = 2.0; gc_mesh.outer_radius = 2.25
	gc_mesh.rings = 4; gc_mesh.ring_segments = 24
	_grenade_cursor = MeshInstance3D.new(); _grenade_cursor.mesh = gc_mesh
	var gc_mat := StandardMaterial3D.new()
	gc_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.72)
	gc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grenade_cursor.set_surface_override_material(0, gc_mat)
	_grenade_cursor.visible = false
	add_child(_grenade_cursor)

func _cmd_move() -> void:
	if not sel_units.is_empty():
		cur_mode = "move"
		_set_status("MOVE MODE — TAP DESTINATION")
	else:
		_set_status("SELECT A UNIT FIRST")

func _cmd_attack() -> void:
	if not sel_units.is_empty():
		cur_mode = "attack"
		_set_status("ATTACK MODE — TAP ENEMY")
	else:
		_set_status("SELECT A UNIT FIRST")

func _cmd_hold() -> void:
	if not sel_units.is_empty():
		for u in sel_units:
			var su := u as Unit
			if su: su.state = Unit.State.HOLDING; su.attack_move = false
		cur_mode = "none"
		var lbl: String = "ALL %d UNITS" % sel_units.size() if sel_units.size() > 1 else UNIT_DEFS[(sel_units[0] as Unit).kind].name
		_set_status("%s HOLDING" % lbl)
	else:
		_set_status("SELECT A UNIT FIRST")

func _use_ability() -> void:
	if sel_unit == null or sel_unit.hp <= 0: return
	if sel_unit.garrisoned:
		_exit_garrison(sel_unit)
		_set_status("UNIT EXITED BUILDING")
		_update_unit_info()
		return
	if sel_unit.ability_cooldown > 0.0:
		_set_status("ABILITY NOT READY — %.0fs REMAINING" % sel_unit.ability_cooldown)
		return
	match sel_unit.kind:
		"militia":   _ability_militia(sel_unit)
		"grenadier": _ability_grenadier(sel_unit)
		"sniper":    _ability_sniper(sel_unit)
		"mg_team":   _ability_mg_team(sel_unit)
		"medic":     _ability_medic_stim(sel_unit)

func _ability_militia(u: Unit) -> void:
	u.ability_cooldown = 45.0
	var bnode := _build_barricade(u.global_position)
	_barricades.append({"node": bnode, "pos": u.global_position})
	u.in_cover = true
	Sounds.play("shot_rifle", -14.0)
	_set_status("BARRICADE PLACED — UNIT IN COVER")
	_update_unit_info()

func _ability_grenadier(u: Unit) -> void:
	if cur_mode == "grenade":
		cur_mode = "none"
		_set_status("GRENADE CANCELLED")
	else:
		cur_mode = "grenade"
		_set_status("THROW GRENADE — TAP TARGET  |  PRESS AGAIN TO CANCEL")
	_update_unit_info()

func _ability_sniper(u: Unit) -> void:
	if u.overwatch:
		u.overwatch = false
		_set_status("OVERWATCH CANCELLED")
	else:
		u.overwatch = true
		u.ability_cooldown = 25.0
		u.state = Unit.State.HOLDING
		_set_status("OVERWATCH — HOLDING FOR TARGET IN RANGE")
	_update_unit_info()

func _ability_mg_team(u: Unit) -> void:
	if u.suppressing:
		u.suppressing = false
		u.suppressing_timer = 0.0
		_set_status("SUPPRESSING FIRE CANCELLED")
	else:
		u.suppressing = true
		u.suppressing_timer = 4.0
		u.ability_cooldown = 20.0
		u.state = Unit.State.HOLDING
		_set_status("SUPPRESSING FIRE — LAYING DOWN FIRE FOR 4s")
	_update_unit_info()

func _ability_medic_stim(u: Unit) -> void:
	u.ability_cooldown = 30.0
	u.hp = mini(u.hp_max, u.hp + 30)
	u._refresh_hp_bar()
	_spawn_heal_pulse(u.global_position)
	for ou in units:
		var fu := ou as Unit
		if fu == null or fu == u or fu.team != u.team or fu.hp <= 0: continue
		if fu.global_position.distance_to(u.global_position) <= 4.0:
			fu.hp = mini(fu.hp_max, fu.hp + 30)
			fu._refresh_hp_bar()
			_spawn_heal_pulse(fu.global_position)
	Sounds.play("heal", -4.0)
	_set_status("STIMPACK — HEALED SELF AND NEARBY ALLIES")
	_update_unit_info()

func _fire_grenade(shooter: Unit, pos: Vector3) -> void:
	shooter.ability_cooldown = 15.0
	_spawn_explosion(pos)
	var splash_dmg := shooter.dmg_min + randi() % maxi(1, shooter.dmg_max - shooter.dmg_min + 1)
	for ou in units:
		var e := ou as Unit
		if e == null or e.hp <= 0 or e.team == shooter.team: continue
		if e.global_position.distance_to(pos) <= 3.5:
			e.take_damage(splash_dmg)
			e.suppression = minf(1.0, e.suppression + 0.6)
	_set_status("GRENADE!")
	_update_unit_info()

func _fire_overwatch(u: Unit, target: Unit) -> void:
	if not _has_los(u.global_position, target.global_position): return
	u.overwatch = false
	u.fire_timer = 1.0 / u.fire_rate
	var dmg: int = u.dmg_max  # guaranteed max, ignores cover
	target.take_damage(dmg)
	_flash_hit(target)
	_spawn_hit_spark(target.global_position + Vector3(0.0, 0.5, 0.0))
	_spawn_muzzle(u.global_position + Vector3(0.0, 0.6, 0.0), target.global_position)
	Sounds.play("shot_sniper", -3.0)
	_set_status("OVERWATCH TRIGGERED — %d DMG" % dmg)
	_update_unit_info()

func _tick_mg_suppressing(u: Unit, _delta: float) -> void:
	if u.fire_timer > 0.0: return
	for ou in units:
		var e := ou as Unit
		if e == null or e.hp <= 0 or e.team == u.team: continue
		var dist := u.global_position.distance_to(e.global_position)
		if dist <= u.attack_range and _has_los(u.global_position, e.global_position):
			u.fire_timer = 1.0 / (u.fire_rate * 1.5)
			var dmg := u.dmg_min + randi() % maxi(1, u.dmg_max - u.dmg_min + 1)
			e.take_damage(dmg)
			e.suppression = minf(1.0, e.suppression + 0.5)
			_flash_hit(e)
			_spawn_hit_spark(e.global_position + Vector3(0.0, 0.5, 0.0))
			_spawn_muzzle(u.global_position + Vector3(0.0, 0.6, 0.0), e.global_position)
			Sounds.play("shot_mg", -2.0)
			break

func _build_barricade(pos: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.52, 0.36)
	mat.roughness = 0.9
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.5, 0.45)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.position = Vector3(pos.x, 0.25, pos.z)
	add_child(mi)
	return mi

func _near_barricade(u: Unit) -> bool:
	for b in _barricades:
		var bp: Vector3 = b.get("pos", Vector3.ZERO)
		if u.global_position.distance_to(bp) <= 1.5:
			return true
	return false

func _start_deploy(kind: String) -> void:
	if deploying_kind == kind:
		# Second press on same button cancels deploy mode
		_reset_deploy_btn(kind)
		deploying_kind = ""
		_set_status("DEPLOY CANCELLED")
		return
	if deploying_kind != "":
		_reset_deploy_btn(deploying_kind)
	deploying_kind = kind
	_deselect()
	for btn in deploy_panel.get_children():
		if btn is Button and btn.has_meta("kind") and str(btn.get_meta("kind")) == kind:
			btn.modulate = Color(1.55, 1.55, 1.55)
			break
	var def: Dictionary = UNIT_DEFS[kind]
	_set_status("DEPLOY %s (%d SUPPLIES) — TAP GREEN ZONE  |  PRESS ✕ TO CANCEL" % [def.name, def.cost])

func _reset_deploy_btn(kind: String) -> void:
	for btn in deploy_panel.get_children():
		if btn is Button and btn.has_meta("kind") and str(btn.get_meta("kind")) == kind:
			btn.modulate = Color(1.0, 1.0, 1.0); break

func _update_hud() -> void:
	# Supply income rate
	var cp_owned := 0
	for cp in capture_points:
		if cp.owner == "player": cp_owned += 1
	var income_rate := 20 + cp_owned * 15
	res_label.text = "SUPPLIES: %d  (+%d/s)" % [supplies, income_rate]
	# Wave timer color coding
	var t_left := maxi(0, int(wave_timer))
	wave_label.text = "WAVE %d/%d  |  %ds" % [wave_num, WAVE_DEFS.size(), t_left]
	if wave_num >= WAVE_DEFS.size():
		wave_label.modulate = Color(1.0, 1.0, 1.0)
	elif t_left < 8:
		wave_label.modulate = Color(1.0, 0.28, 0.18)
	elif t_left < 20:
		wave_label.modulate = Color(1.0, 0.78, 0.18)
	else:
		wave_label.modulate = Color(0.7, 1.0, 0.7)
	kills_label.text = "KIA: %d" % kill_count
	hq_label.text    = "HQ: %d/%d" % [hq_hp, hq_hp_max]
	hq_label.modulate = Color(0.4,0.7,1.0) if hq_hp > 50 else (Color(1.0,0.75,0.2) if hq_hp > 25 else Color(1.0,0.3,0.2))
	# Suppression screen tint: red vignette when selected unit is suppressed
	if _suppression_overlay:
		var max_sup := 0.0
		for u in sel_units:
			var su := u as Unit
			if su != null and su.hp > 0:
				max_sup = maxf(max_sup, su.suppression)
		var target_a := max_sup * 0.25
		var c := _suppression_overlay.color
		c.a = lerpf(c.a, target_a, 0.12)
		_suppression_overlay.color = c
	_update_unit_info()

func _update_unit_info() -> void:
	if sel_units.is_empty():
		unit_info.visible = false
		if _ability_btn: _ability_btn.visible = false
		return
	elif sel_units.size() == 1 and sel_unit != null:
		unit_info.visible = true
		var def: Dictionary = UNIT_DEFS[sel_unit.kind]
		unit_name_lbl.text = "%s  HP %d/%d" % [def.name, sel_unit.hp, sel_unit.hp_max]
	else:
		unit_info.visible = true
		unit_name_lbl.text = "%d UNITS SELECTED" % sel_units.size()
	# Refresh ability button
	if _ability_btn == null: return
	if sel_units.size() == 1 and sel_unit != null and sel_unit.hp > 0:
		# Garrisoned: ability slot becomes EXIT BUILDING
		if sel_unit.garrisoned:
			_ability_btn.visible = true
			_ability_btn.text    = "EXIT BUILDING"
			_ability_btn.modulate = Color(1.0, 0.85, 0.2)
			return
		var def: Dictionary = UNIT_DEFS[sel_unit.kind]
		var ab_name: String = def.get("ability", "")
		if ab_name.is_empty():
			_ability_btn.visible = false
		else:
			_ability_btn.visible = true
			if sel_unit.overwatch:
				_ability_btn.text = "CANCEL OW"
				_ability_btn.modulate = Color(1.0, 0.7, 0.2)
			elif sel_unit.suppressing:
				_ability_btn.text = "SUPPRESSING"
				_ability_btn.modulate = Color(1.0, 0.55, 0.1)
			elif sel_unit.ability_cooldown > 0.01:
				_ability_btn.text = "%s (%.0fs)" % [ab_name, sel_unit.ability_cooldown]
				_ability_btn.modulate = Color(0.55, 0.55, 0.55)
			else:
				_ability_btn.text = ab_name
				_ability_btn.modulate = Color(0.3, 1.0, 0.43)
	else:
		_ability_btn.visible = false

func _set_status(msg: String) -> void:
	if status_label: status_label.text = msg

func _flash_wave_banner(wave: int) -> void:
	var layer := CanvasLayer.new(); layer.layer = 9; add_child(layer)
	var lbl := Label.new()
	lbl.text = "— WAVE %d —\nENEMY ADVANCING" % wave
	lbl.add_theme_font_size_override("font_size", 58)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left = -480; lbl.offset_right  = 480
	lbl.offset_top  = -100; lbl.offset_bottom = 100
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.50).set_ease(Tween.EASE_IN)
	tw.finished.connect(func()->void: layer.queue_free())

func _flash_wave_clear(wave: int) -> void:
	Sounds.play("capture", -4.0)
	var layer := CanvasLayer.new(); layer.layer = 9; add_child(layer)
	var lbl := Label.new()
	lbl.text = "— WAVE %d CLEARED —\nKIA: %d  |  SUPPLIES: %d" % [wave, kill_count, supplies]
	lbl.add_theme_font_size_override("font_size", 44)
	lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.43))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left = -560; lbl.offset_right  = 560
	lbl.offset_top  = -80;  lbl.offset_bottom = 80
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tw.finished.connect(func()->void: layer.queue_free())

# ── PAUSE MENU ────────────────────────────────────────────────

func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseLayer"; _pause_layer.layer = 10; _pause_layer.visible = false
	add_child(_pause_layer)

	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0.0, 0.02, 0.0, 0.82)
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(_pause_overlay)

	_pause_panel    = _build_main_panel()
	_pause_panel.pivot_offset = Vector2(240, 275)
	_pause_layer.add_child(_pause_panel)

	_settings_panel = _build_settings_panel_ctrl()
	_settings_panel.pivot_offset = Vector2(240, 275)
	_settings_panel.modulate.a  = 0.0
	_settings_panel.visible     = false
	_pause_layer.add_child(_settings_panel)

func _build_main_panel() -> Control:
	var c := _pause_container()
	var vbox := _styled_panel(c, 4)
	var t := _pause_label("WORLD AT WAR", 38, Color(0.30, 1.00, 0.43)); vbox.add_child(t)
	var s := _pause_label("— PAUSED —", 15, Color(0.30, 0.52, 0.30)); vbox.add_child(s)
	vbox.add_child(_pause_sep(0.75))
	var resume := _pmenu_btn("▶   RESUME"); vbox.add_child(resume)
	resume.pressed.connect(_hide_pause)
	var settings := _pmenu_btn("⚙   SETTINGS"); vbox.add_child(settings)
	settings.pressed.connect(_open_settings)
	vbox.add_child(_pause_sep(0.35))
	var quit := _pmenu_btn("✕   QUIT TO MAP"); vbox.add_child(quit)
	quit.add_theme_color_override("font_color",       Color(0.85, 0.42, 0.35))
	quit.add_theme_color_override("font_hover_color", Color(1.00, 0.40, 0.30))
	quit.pressed.connect(func()->void: _main().show_globe())
	return c

func _build_settings_panel_ctrl() -> Control:
	var c := _pause_container()
	var vbox := _styled_panel(c, 4)
	var t := _pause_label("SETTINGS", 32, Color(0.30, 1.00, 0.43)); vbox.add_child(t)
	vbox.add_child(_pause_sep(0.75))
	# Fullscreen toggle
	vbox.add_child(_settings_row("FULLSCREEN",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		func(on: bool)->void:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)))
	# Anti-aliasing toggle
	vbox.add_child(_settings_row("ANTI-ALIASING", true,
		func(on: bool)->void: get_viewport().msaa_3d = Viewport.MSAA_4X if on else Viewport.MSAA_DISABLED))
	vbox.add_child(_pause_sep(0.35))
	var back := _pmenu_btn("◀   BACK"); vbox.add_child(back)
	back.pressed.connect(_close_settings)
	return c

# ── Panel helpers ─────────────────────────────────────────────

func _pause_container() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = -240; c.offset_right  =  240
	c.offset_top  = -275; c.offset_bottom =  275
	return c

func _styled_panel(parent: Control, left_border: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.022, 0.038, 0.022, 0.97)
	ps.border_color = Color(0.20, 0.52, 0.20, 0.90)
	ps.set_border_width_all(1); ps.border_width_left = left_border
	ps.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	return vbox

func _pause_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _pause_sep(alpha: float = 0.75) -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.18, 0.45, 0.18, alpha))
	sep.add_theme_constant_override("separation", 4)
	return sep

func _settings_row(label_text: String, default_on: bool, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new(); lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 0.72))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var chk := CheckButton.new(); chk.button_pressed = default_on
	chk.focus_mode = Control.FOCUS_NONE
	chk.toggled.connect(callback)
	row.add_child(chk)
	return row

func _pmenu_btn(text: String, font_col: Color = Color(0.78, 0.92, 0.78)) -> Button:
	var btn := Button.new(); btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color",         font_col)
	btn.add_theme_color_override("font_hover_color",   Color(0.30, 1.00, 0.43))
	btn.add_theme_color_override("font_pressed_color", Color(0.50, 1.00, 0.60))
	var norm := _pmenu_style(Color(0.04,0.08,0.04,0.88), Color(0.18,0.42,0.18,0.80))
	var hov  := _pmenu_style(Color(0.06,0.16,0.06,0.96), Color(0.28,0.88,0.38,1.00))
	var prs  := _pmenu_style(Color(0.10,0.22,0.10,0.98), Color(0.30,1.00,0.43,1.00))
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_stylebox_override("focus",   norm)
	# Hover scale animation
	var _tw: Tween
	btn.mouse_entered.connect(func()->void:
		if _tw: _tw.kill()
		_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_tw.tween_property(btn, "scale", Vector2(1.035, 1.035), 0.12)
	)
	btn.mouse_exited.connect(func()->void:
		if _tw: _tw.kill()
		_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.18)
	)
	return btn

func _pmenu_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(2); s.set_corner_radius_all(3)
	s.content_margin_left = 20; s.content_margin_right = 20
	s.content_margin_top = 12; s.content_margin_bottom = 12
	return s

# ── Pause show / hide ─────────────────────────────────────────

func _show_pause() -> void:
	if _pause_layer == null: return
	game_paused = true
	_pause_layer.visible   = true
	_pause_panel.modulate.a   = 0.0
	_pause_panel.scale        = Vector2(0.90, 0.90)
	_pause_overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_pause_overlay, "modulate:a", 1.0, 0.22)
	tw.tween_property(_pause_panel, "modulate:a", 1.0, 0.22)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(_pause_panel, "scale", Vector2(1.0, 1.0), 0.24)

func _hide_pause() -> void:
	if _pause_layer == null: return
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tw.tween_property(_pause_overlay, "modulate:a", 0.0, 0.18)
	tw.tween_property(_pause_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(_pause_panel, "scale", Vector2(0.90, 0.90), 0.18)
	await tw.finished
	_pause_layer.visible = false
	game_paused = false

func _open_settings() -> void:
	_settings_panel.visible   = true
	_settings_panel.scale     = Vector2(1.0, 1.0)
	_settings_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(_pause_panel,    "modulate:a", 0.0, 0.15)
	tw.tween_property(_settings_panel, "modulate:a", 1.0, 0.22)

func _close_settings() -> void:
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(_settings_panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(_pause_panel,    "modulate:a", 1.0, 0.22)
	await tw.finished
	_settings_panel.visible = false

# ── VETERAN / KILL POPUP ──────────────────────────────────────

func _spawn_kill_popup(pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = "+KIA"
	lbl.pixel_size = 0.012
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.28, 0.18)
	lbl.outline_size = 5
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.position = pos + Vector3(0.0, 0.8, 0.0)
	add_child(lbl)
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", pos.y + 2.5, 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.finished.connect(func()->void: if is_instance_valid(lbl): lbl.queue_free())

func _refresh_vet_stars(u: Unit) -> void:
	var tiers := mini(u.vet_kills / 5, 3)
	if _vet_star_nodes.has(u) and is_instance_valid(_vet_star_nodes[u]):
		var node := _vet_star_nodes[u] as Label3D
		if node:
			node.text = "*".repeat(tiers)
			node.visible = tiers > 0
		return
	var star_lbl := Label3D.new()
	star_lbl.pixel_size = 0.0055
	star_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star_lbl.modulate = Color(1.0, 0.88, 0.22)
	star_lbl.outline_size = 4
	star_lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	star_lbl.position = Vector3(0.0, 1.05, 0.0)
	star_lbl.text = "*".repeat(tiers)
	star_lbl.visible = tiers > 0
	u.add_child(star_lbl)
	_vet_star_nodes[u] = star_lbl

# ── RETREAT / MORTAR ──────────────────────────────────────────

func _cmd_retreat() -> void:
	if sel_units.is_empty():
		_set_status("SELECT UNITS FIRST"); return
	var hq_pos := Vector3(HQ_X, 0.0, HQ_Z)
	var alive: Array = sel_units.filter(func(u): return (u as Unit) != null and (u as Unit).hp > 0)
	if alive.is_empty(): return
	var positions := _assign_formation(alive, hq_pos)
	for i in alive.size():
		var su := alive[i] as Unit
		_move_with_path(su, positions[i] as Vector3)
	_set_status("RETREATING TO HQ — %d UNIT(S)" % alive.size())

func _cmd_mortar() -> void:
	if _mortar_mode:
		_mortar_mode = false
		_set_status("MORTAR CANCELLED"); return
	if supplies < 60:
		_set_status("NOT ENOUGH SUPPLIES — MORTAR COSTS 60 SUP"); return
	_mortar_mode = true
	_set_status("MORTAR STRIKE — TAP TARGET  |  PRESS AGAIN TO CANCEL")

func _fire_mortar(pos: Vector3) -> void:
	supplies -= 60
	_set_status("MORTAR INCOMING...")
	var delay := create_tween()
	delay.tween_interval(0.85)
	delay.tween_callback(func()->void:
		_spawn_explosion(pos)
		_apply_shake(0.35)
		var blast_dmg := 45 + randi() % 30
		for ou in units:
			var e := ou as Unit
			if e == null or e.hp <= 0 or e.team == "player": continue
			var d := e.global_position.distance_to(pos)
			if d <= 4.5:
				var scaled := int(float(blast_dmg) * maxf(0.0, 1.0 - d / 4.5))
				e.take_damage(scaled)
				e.suppression = minf(1.0, e.suppression + 0.8)
		_set_status("MORTAR STRIKE!")
	)

# ── HELPERS ───────────────────────────────────────────────────

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Default PBR values — matte surface, minimal specular
		m.roughness  = 0.85
		m.metallic   = 0.0
		m.specular   = 0.18
		_mats[key] = m
	return _mats[key]

func _mat_new(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; return m

func _road_shader_code() -> String:
	return """
shader_type spatial;
render_mode depth_draw_opaque;

float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i,             vec2(127.1,311.7)))*43758.5);
	float b = fract(sin(dot(i+vec2(1,0),   vec2(127.1,311.7)))*43758.5);
	float c = fract(sin(dot(i+vec2(0,1),   vec2(127.1,311.7)))*43758.5);
	float d = fract(sin(dot(i+vec2(1,1),   vec2(127.1,311.7)))*43758.5);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

void fragment() {
	// Asphalt grain — two scale noise
	float grain = vnoise(UV * 60.0) * 0.55 + vnoise(UV * 180.0) * 0.45;
	vec3 asphalt = vec3(0.140, 0.138, 0.132) * (0.82 + grain * 0.36);

	// Dashed centre line — runs along V axis
	float dash_u = abs(UV.x - 0.5);
	float dash_v = fract(UV.y * 5.0);
	float centre_line = step(dash_u, 0.022) * step(dash_v, 0.55);

	// Solid edge lines
	float edge_line = step(abs(UV.x - 0.08), 0.018) + step(abs(UV.x - 0.92), 0.018);
	edge_line = clamp(edge_line, 0.0, 1.0);

	// Faded white markings
	float markings = clamp(centre_line * 0.55 + edge_line * 0.35, 0.0, 1.0);
	vec3 mark_col = vec3(0.82, 0.80, 0.72);
	vec3 albedo = mix(asphalt, mark_col, markings);

	// Derive cheap surface normal for micro-roughness
	float eps = 0.006;
	float nx = vnoise(UV*60.0+vec2(eps,0)) - vnoise(UV*60.0-vec2(eps,0));
	float nz = vnoise(UV*60.0+vec2(0,eps)) - vnoise(UV*60.0-vec2(0,eps));
	NORMAL_MAP       = normalize(vec3(nx*3.0, nz*3.0, 1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH = 0.25;

	ALBEDO    = albedo;
	ROUGHNESS = 0.88 - grain * 0.06;
	METALLIC  = 0.0;
	SPECULAR  = 0.22;
}
"""

func _tree_conifer_shader_code() -> String:
	return """
shader_type spatial;

void vertex() {
	// Conifers sway stiffly from base — low amplitude, slow frequency
	float phase = VERTEX.x * 1.6 + VERTEX.z * 1.3;
	// Local Y: apex is +h/2, base is -h/2; scale sway so base barely moves
	float height_factor = clamp(VERTEX.y * 2.0 + 1.0, 0.0, 1.0);
	VERTEX.x += sin(TIME * 0.80 + phase) * 0.014 * height_factor;
	VERTEX.z += cos(TIME * 0.62 + phase * 0.85) * 0.009 * height_factor;
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.92;
	METALLIC  = 0.0;
	SPECULAR  = 0.10;
}
"""

func _tree_crown_shader_code() -> String:
	return """
shader_type spatial;

void vertex() {
	// Wind sway — amplitude increases with height, per-instance phase from VERTEX.x
	float phase = VERTEX.x * 2.7 + VERTEX.z * 1.9;
	float sway  = sin(TIME * 1.4 + phase) * 0.038 + cos(TIME * 0.9 + phase * 0.7) * 0.022;
	VERTEX.x += sway * max(0.0, VERTEX.y);
	VERTEX.z += cos(TIME * 1.1 + phase * 1.3) * 0.024 * max(0.0, VERTEX.y);
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.88;
	METALLIC  = 0.0;
}
"""

func _ground_shader_code() -> String:
	return """
shader_type spatial;
render_mode depth_draw_opaque;

// Smooth value noise — no hard cell edges
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i,              vec2(127.1, 311.7))) * 43758.5);
	float b = fract(sin(dot(i + vec2(1,0),  vec2(127.1, 311.7))) * 43758.5);
	float c = fract(sin(dot(i + vec2(0,1),  vec2(127.1, 311.7))) * 43758.5);
	float d = fract(sin(dot(i + vec2(1,1),  vec2(127.1, 311.7))) * 43758.5);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	// Two octaves of smooth noise — coarse patch variation + fine detail
	float n1 = vnoise(UV * 6.0);
	float n2 = vnoise(UV * 28.0);
	float noise = n1 * 0.65 + n2 * 0.35;

	vec3 grass_lo = vec3(0.048, 0.098, 0.032);
	vec3 grass_hi = vec3(0.165, 0.260, 0.088);
	vec3 albedo = mix(grass_lo, grass_hi, noise);

	// Dirt patches follow the coarse octave
	float dirt = smoothstep(0.62, 0.76, n1);
	vec3 dirt_col = vec3(0.170, 0.122, 0.068) * (0.78 + n2 * 0.22);
	albedo = mix(albedo, dirt_col, dirt * 0.58);

	// Derive a cheap normal from the noise gradient for micro-surface depth
	float eps = 0.008;
	float nx = vnoise(UV * 6.0 + vec2(eps, 0.0)) - vnoise(UV * 6.0 - vec2(eps, 0.0));
	float nz = vnoise(UV * 6.0 + vec2(0.0, eps)) - vnoise(UV * 6.0 - vec2(0.0, eps));
	NORMAL_MAP       = normalize(vec3(nx * 4.0, nz * 4.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;

	ALBEDO    = albedo;
	ROUGHNESS = 0.90 - noise * 0.07;
	METALLIC  = 0.0;
	SPECULAR  = 0.15;
}
"""

func _bld_shader_code() -> String:
	return """
shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float is_roof = step(0.9, NORMAL.y);
	float a = COLOR.a;

	// Material type from vertex alpha: 1.0=brick, 0.75=wood, 0.5=concrete, 0.25=glass
	float is_brick = step(0.875, a);
	float is_wood  = step(0.625, a) * (1.0 - is_brick);
	float is_glass = step(a, 0.375);
	float is_conc  = 1.0 - is_brick - is_wood - is_glass;

	// Brick — running bond pattern
	vec2 b_uv   = UV / vec2(0.48, 0.26);
	float b_row = floor(b_uv.y);
	float b_off = mod(b_row, 2.0) * 0.5;
	vec2 b_cell = vec2(fract(b_uv.x + b_off), fract(b_uv.y));
	float mortar = max(step(0.91, b_cell.x), step(0.88, b_cell.y));
	float brnd   = fract(sin(dot(floor(vec2(b_uv.x + b_off, b_uv.y)),
		vec2(127.1, 311.7))) * 43758.5453);
	vec3 brick_col = mix(COLOR.rgb * (0.92 + brnd * 0.16), COLOR.rgb * 0.50, mortar);

	// Wood — horizontal grain lines
	vec2 w_uv    = UV / vec2(0.10, 0.04);
	float wgrain = fract(w_uv.y);
	float wn     = fract(sin(dot(floor(w_uv), vec2(127.1, 311.7))) * 43758.5453);
	float wline  = smoothstep(0.80, 1.0, wgrain) * 0.30;
	vec3 wood_col = COLOR.rgb * (0.85 + wn * 0.20 - wline);

	// Glass curtain wall
	vec2 g_uv   = UV / vec2(0.42, 0.36);
	vec2 g_cell = fract(g_uv);
	float frame = max(max(step(g_cell.x, 0.07), step(0.93, g_cell.x)),
		max(step(g_cell.y, 0.09), step(0.91, g_cell.y)));
	float grnd  = fract(sin(dot(floor(g_uv), vec2(127.1, 311.7))) * 43758.5453);
	vec3 glass_col = mix(COLOR.rgb * (0.75 + grnd * 0.50), COLOR.rgb, frame);
	float g_rough = mix(0.03, 0.80, frame);
	float g_metal = mix(0.55, 0.0, frame);

	// Concrete panels
	vec2 c_uv    = UV / vec2(0.55, 0.40);
	float cnoise = fract(sin(dot(floor(c_uv), vec2(127.1, 311.7))) * 43758.5453);
	float c_seam = max(step(0.96, fract(c_uv.y)), step(0.97, fract(c_uv.x)));
	vec3 conc_col = COLOR.rgb * (0.88 + cnoise * 0.20) - vec3(c_seam * 0.12);

	// Roof — granular tar/gravel, matches satellite color
	float rnoise  = fract(sin(dot(floor(UV * 12.0), vec2(127.1, 311.7))) * 43758.5453);
	vec3 roof_albedo = COLOR.rgb * (0.80 + rnoise * 0.24);

	vec3 wall_albedo = brick_col*is_brick + wood_col*is_wood + glass_col*is_glass + conc_col*is_conc;
	float wall_rough = 0.88*is_brick + 0.85*is_wood + g_rough*is_glass + 0.92*is_conc;

	ALBEDO    = mix(wall_albedo, roof_albedo, is_roof);
	ROUGHNESS = mix(wall_rough, 0.90, is_roof);
	METALLIC  = g_metal * is_glass * (1.0 - is_roof);
	SPECULAR  = 0.5;
	EMISSION  = vec3(0.18, 0.28, 0.44) * (1.0 - frame) * is_glass * (1.0 - is_roof) * 0.25;
}
"""

func _water_shader_code() -> String:
	return """
shader_type spatial;
render_mode blend_mix, depth_draw_disabled, cull_back;

void fragment() {
	// Two layers of wave UVs scrolling in different directions
	vec2 uv1 = UV * 4.0 + vec2(TIME * 0.050,  TIME * 0.028);
	vec2 uv2 = UV * 2.5 + vec2(-TIME * 0.036, TIME * 0.062);
	vec2 uv3 = UV * 8.0 + vec2(TIME * 0.022, -TIME * 0.041);

	float w1 = sin(uv1.x * 6.2832 + uv1.y * 4.1888) * 0.5 + 0.5;
	float w2 = sin(uv2.x * 3.1416 - uv2.y * 6.2832) * 0.5 + 0.5;
	float w3 = sin(uv3.x * 9.4248 + uv3.y * 3.1416) * 0.5 + 0.5;
	float wave = w1 * 0.50 + w2 * 0.32 + w3 * 0.18;

	vec3 deep    = vec3(0.04, 0.13, 0.30);
	vec3 shallow = vec3(0.09, 0.24, 0.48);
	ALBEDO    = mix(deep, shallow, wave);
	ROUGHNESS = 0.04 + wave * 0.05;
	METALLIC  = 0.0;
	SPECULAR  = 0.95;
	ALPHA     = 0.86;

	// Normal map from wave gradients (three octaves)
	float nx = sin(uv1.y * 6.2832) * 0.14 + sin(uv3.y * 9.4248) * 0.06;
	float nz = cos(uv2.x * 3.1416) * 0.14 + cos(uv3.x * 6.2832) * 0.06;
	NORMAL_MAP       = normalize(vec3(nx, nz, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.70;
}
"""

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new(); bm.size = size
	var mi := MeshInstance3D.new(); mi.mesh = bm
	mi.set_surface_override_material(0, mat); return mi

func _tx(c: int) -> float: return float(c - TG/2)*TCELL + TCELL/2.0
func _tz(r: int) -> float: return float(r - TG/2)*TCELL + TCELL/2.0
func _main() -> Node: return get_tree().root.get_node("Main")
