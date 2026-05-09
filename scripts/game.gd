extends Node3D

# Preload forces unit.gd to compile before this script parses its type annotations
const Unit = preload("res://scripts/unit.gd")

# ── UNIT DEFINITIONS ──────────────────────────────────────────
# Player units are MILITIA — local defenders, cheap, weaker individually
# Enemy units are MILITARY — invading force, better equipped
const UNIT_DEFS := {
	# Player / Militia
	"militia":   {"name":"MILITIA",    "cost":75,  "hp":60,  "speed":4.2,"range":7.0, "dmg_min":10,"dmg_max":22,"fire_rate":1.1,"desc":"Civilian defender. Weak alone, deadly en masse."},
	"grenadier": {"name":"GRENADIER",  "cost":150, "hp":75,  "speed":3.5,"range":10.0,"dmg_min":35,"dmg_max":60,"fire_rate":0.5,"desc":"Explosive specialist. Area suppression."},
	"sniper":    {"name":"SNIPER",     "cost":200, "hp":50,  "speed":3.0,"range":22.0,"dmg_min":70,"dmg_max":100,"fire_rate":0.3,"desc":"One shot, one kill. Long range."},
	"mg_team":   {"name":"MG TEAM",   "cost":175, "hp":80,  "speed":2.5,"range":14.0,"dmg_min":20,"dmg_max":40,"fire_rate":1.2,"desc":"Sustained fire. Suppresses enemies."},
	# Enemy / Military — same archetypes, stronger stats
	"soldier":   {"name":"SOLDIER",    "cost":0,   "hp":90,  "speed":4.5,"range":9.0, "dmg_min":18,"dmg_max":32,"fire_rate":1.0,"desc":""},
	"e_gren":    {"name":"E.GRENADIER","cost":0,   "hp":90,  "speed":3.8,"range":11.0,"dmg_min":40,"dmg_max":65,"fire_rate":0.5,"desc":""},
	"e_sniper":  {"name":"E.SNIPER",   "cost":0,   "hp":65,  "speed":3.2,"range":24.0,"dmg_min":75,"dmg_max":105,"fire_rate":0.28,"desc":""},
	"e_mg":      {"name":"E.MG TEAM", "cost":0,   "hp":95,  "speed":2.8,"range":16.0,"dmg_min":22,"dmg_max":42,"fire_rate":1.3,"desc":""},
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
var _drag_on: bool      = false
var _drag_lx: float     = 0.0
var _drag_ly: float     = 0.0
var _drag_sx: float     = 0.0
var _drag_sy: float     = 0.0
var _drag_moved: bool   = false

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
# Minimap
var _mm_layer:    CanvasLayer = null
var _mm_panel:    Control     = null
var _mm_cam_rect: ColorRect   = null
var _mm_dots:     Dictionary  = {}

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
	_set_status("DEFEND THE NEIGHBORHOOD  |  TAP TO SELECT  |  RIGHT-CLICK TO COMMAND")

# ── WORLD BUILDING ────────────────────────────────────────────

func _build_world() -> void:
	var main := _main()
	# Base ground — solid border/fill, always present
	var gnd := _box(Vector3(HALF*2.0+1.0, 0.12, HALF*2.0+1.0), _mat(Color(0.13,0.18,0.10)))
	gnd.position = Vector3(0.0,-0.06,0.0)
	add_child(gnd)
	# Satellite photo overlay — covers exact play area when image data is available
	var sat_raw = main.get("sat_image_data")
	if sat_raw is PackedByteArray and (sat_raw as PackedByteArray).size() > 0:
		var img := Image.new()
		if img.load_jpg_from_buffer(sat_raw as PackedByteArray) == OK:
			var sat_mat := StandardMaterial3D.new()
			sat_mat.albedo_texture = ImageTexture.create_from_image(img)
			sat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var pm := PlaneMesh.new()
			pm.size = Vector2(HALF * 2.0, HALF * 2.0)
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
	else:
		_build_procedural()

	_hq_zone(Vector3(HQ_X, 0.0, HQ_Z),   Color(0.30,1.00,0.43,0.4), "HQ")
	_hq_zone(Vector3(-HQ_X,0.0,-HQ_Z),   Color(1.00,0.20,0.18,0.4), "ENEMY")
	_build_boundary()
	_setup_environment()

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color       = Color(0.18, 0.30, 0.56)
	sky_mat.sky_horizon_color   = Color(0.52, 0.60, 0.70)
	sky_mat.ground_bottom_color   = Color(0.07, 0.09, 0.07)
	sky_mat.ground_horizon_color  = Color(0.32, 0.36, 0.28)
	sky_mat.sun_angle_max = 2.0
	var sky := Sky.new(); sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.56, 0.54)
	env.fog_density = 0.007
	env.fog_aerial_perspective = 0.3
	env.glow_enabled = false
	var we := $WorldEnvironment as WorldEnvironment
	if we: we.environment = env

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
				TILE_TREE:  _place_tree(px, pz)
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
	mi.set_surface_override_material(0, _mat(Color(0.16, 0.16, 0.16)))
	add_child(mi)

func _build_osm_buildings() -> void:
	var mn   := _main()
	var blds  = mn.get("osm_buildings")
	if not blds is Array or (blds as Array).is_empty(): return
	var clat    : float = mn.active_lat
	var clon    : float = mn.active_lon
	var cos_lat := cos(deg_to_rad(clat))
	var scale   := HALF / 100.0

	var all_verts   := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_colors  := PackedColorArray()
	var all_idx     := PackedInt32Array()

	for bld in (blds as Array):
		var geom: Array = bld.get("geom", [])
		if geom.size() < 3: continue

		# Convert lat/lon footprint to world XZ
		var pts: Array = []
		for pt in geom:
			var lat := float(pt.get("lat", 0.0))
			var lon := float(pt.get("lon", 0.0))
			var dy  := (lat - clat) * 111000.0
			var dx  := (lon - clon) * 111000.0 * cos_lat
			pts.append(Vector2(dx * scale, -dy * scale))
		# OSM closed ways repeat the first vertex — remove it
		if pts.size() >= 2 and pts[0].distance_to(pts[-1]) < 0.05:
			pts.resize(pts.size() - 1)
		if pts.size() < 3: continue

		# Height from tags, levels, or building type
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

		# Wall and roof color from building type
		var wall_col: Color
		var roof_col: Color
		match btype:
			"house","detached","semidetached_house","terrace","bungalow","residential":
				wall_col = Color(0.72, 0.62, 0.52); roof_col = Color(0.38, 0.20, 0.16)
			"apartments","block_of_flats":
				wall_col = Color(0.65, 0.60, 0.58); roof_col = Color(0.28, 0.26, 0.24)
			"office","commercial","bank","hotel":
				wall_col = Color(0.54, 0.62, 0.68); roof_col = Color(0.24, 0.30, 0.34)
			"retail","shop","supermarket":
				wall_col = Color(0.70, 0.60, 0.50); roof_col = Color(0.33, 0.26, 0.20)
			"industrial","warehouse","shed","garage","garages":
				wall_col = Color(0.55, 0.53, 0.50); roof_col = Color(0.32, 0.30, 0.28)
			"church","cathedral","chapel","mosque","synagogue":
				wall_col = Color(0.82, 0.78, 0.70); roof_col = Color(0.48, 0.46, 0.42)
			_:
				wall_col = Color(0.68, 0.64, 0.60); roof_col = Color(0.30, 0.28, 0.26)
		# Per-building tint so buildings don't all look identical
		var tint := Color(0.88 + _rng.randf()*0.24, 0.88 + _rng.randf()*0.24, 0.88 + _rng.randf()*0.24)
		wall_col = Color(wall_col.r*tint.r, wall_col.g*tint.g, wall_col.b*tint.b)

		# Centroid for outward wall normals
		var centroid := Vector2.ZERO
		for p: Vector2 in pts: centroid += p
		centroid /= float(pts.size())

		# Walls — one quad per polygon edge
		var n := pts.size()
		for i in n:
			var j   := (i + 1) % n
			var p0  := Vector3(pts[i].x, 0.02, pts[i].y)
			var p1  := Vector3(pts[j].x, 0.02, pts[j].y)
			var p0t := Vector3(pts[i].x, h,    pts[i].y)
			var p1t := Vector3(pts[j].x, h,    pts[j].y)
			var mid2d: Vector2 = ((pts[i] as Vector2) + (pts[j] as Vector2)) * 0.5
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
			all_idx.append_array([b, b+2, b+1, b+1, b+2, b+3])

		# Roof — fan triangulation from vertex 0
		var rb := all_verts.size()
		for i in pts.size():
			all_verts.append(Vector3(pts[i].x, h, pts[i].y))
			all_normals.append(Vector3.UP)
			all_colors.append(roof_col)
		for i in range(1, pts.size() - 1):
			all_idx.append_array([rb, rb + i, rb + i + 1])

	if all_verts.is_empty(): return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_verts
	arrays[Mesh.ARRAY_NORMAL] = all_normals
	arrays[Mesh.ARRAY_COLOR]  = all_colors
	arrays[Mesh.ARRAY_INDEX]  = all_idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	# Asphalt base
	var road := _box(Vector3(TCELL,0.04,TCELL), _mat(Color(0.18,0.18,0.18)))
	road.position = Vector3(px,0.02,pz)
	add_child(road)
	# Sidewalk strips on edges (simple — covers full cell, road sits above)
	var sw := _box(Vector3(TCELL-0.1,0.06,TCELL-0.1), _mat(Color(0.55,0.55,0.52)))
	sw.position = Vector3(px,-0.03,pz)
	add_child(sw)
	# Yellow lane markings (cross pattern — works for both road orientations)
	var lm := _mat(Color(0.86, 0.78, 0.10))
	var lmh := _box(Vector3(TCELL*0.64, 0.043, 0.07), lm)
	lmh.position = Vector3(px, 0.042, pz); add_child(lmh)
	var lmv := _box(Vector3(0.07, 0.043, TCELL*0.64), lm)
	lmv.position = Vector3(px, 0.042, pz); add_child(lmv)

func _place_building(px: float, pz: float, _r: int, _c: int) -> void:
	# Pick a building style by hash
	var seed_val := int(px*100.0) ^ int(pz*100.0)
	var style := seed_val % 4
	var h: float
	var wall_col: Color
	var roof_col: Color
	match style:
		0: # Concrete residential
			h = 2.5 + _rng.randf()*2.5
			wall_col = Color(0.72,0.68,0.62)
			roof_col = Color(0.55,0.52,0.48)
		1: # Brick
			h = 3.0 + _rng.randf()*4.0
			wall_col = Color(0.65,0.38,0.28)
			roof_col = Color(0.30,0.25,0.22)
		2: # Modern/glass
			h = 4.0 + _rng.randf()*6.0
			wall_col = Color(0.50,0.58,0.62)
			roof_col = Color(0.30,0.35,0.38)
		3: # Suburban house
			h = 2.0 + _rng.randf()*1.5
			wall_col = Color(0.82,0.78,0.68)
			roof_col = Color(0.42,0.22,0.18)

	var bw: float = TCELL*0.88; var bd: float = TCELL*0.88
	# Main building box
	var bm := _box(Vector3(bw, h, bd), _mat(wall_col))
	bm.position = Vector3(px, h*0.5, pz)
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(bm)
	# Roof — gable for suburban, flat cap for others
	if style == 3:
		var rh: float = 0.52; var rw: float = bw + 0.10
		for side: float in [-1.0, 1.0]:
			var rp := _box(Vector3(rw, 0.09, bd*0.54+0.06), _mat(roof_col))
			rp.position = Vector3(px, h + rh*0.5, pz + side*bd*0.26)
			rp.rotation.x = side * deg_to_rad(30.0)
			add_child(rp)
		var rdg := _box(Vector3(rw, 0.12, 0.15), _mat(roof_col.darkened(0.18)))
		rdg.position = Vector3(px, h + rh, pz); add_child(rdg)
	else:
		var roof := _box(Vector3(bw+0.05, 0.18, bd+0.05), _mat(roof_col))
		roof.position = Vector3(px, h+0.09, pz)
		add_child(roof)
	# Windows (small inset boxes on each face)
	if h > 2.0:
		_add_windows(px, pz, h, bw, bd, wall_col.darkened(0.4))

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

func _place_tree(px: float, pz: float) -> void:
	var count := 3 + _rng.randi() % 2
	for _i in count:
		var ox    := (_rng.randf() - 0.5) * TCELL * 0.85
		var oz    := (_rng.randf() - 0.5) * TCELL * 0.85
		var sx    := 0.65 + _rng.randf() * 0.60
		var trunk_h := (0.8 + _rng.randf() * 0.5) * sx
		var tm := CylinderMesh.new()
		tm.top_radius = 0.07 * sx; tm.bottom_radius = 0.13 * sx; tm.height = trunk_h
		tm.radial_segments = 6
		var trunk := MeshInstance3D.new()
		trunk.mesh = tm
		trunk.set_surface_override_material(0, _mat(Color(0.25 + _rng.randf()*0.08, 0.16, 0.07)))
		trunk.position = Vector3(px + ox, trunk_h * 0.5, pz + oz)
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(trunk)
		for layer in [0, 1]:
			var sm := SphereMesh.new()
			var cr: float = (0.48 + _rng.randf()*0.35 - float(layer)*0.14) * sx
			sm.radius = cr; sm.height = cr * 1.6
			sm.radial_segments = 7; sm.rings = 5
			var crown := MeshInstance3D.new()
			crown.mesh = sm
			var g: float = 0.20 + _rng.randf() * 0.14
			crown.set_surface_override_material(0, _mat(Color(0.07 + _rng.randf()*0.07, g, 0.05 + _rng.randf()*0.03)))
			crown.position = Vector3(px + ox, trunk_h + cr * 0.7 + float(layer) * 0.28, pz + oz)
			crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(crown)

func _place_water(px: float, pz: float) -> void:
	var mat := _mat_new(Color(0.10,0.28,0.48,0.82))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var m := _box(Vector3(TCELL,0.06,TCELL), mat)
	m.position = Vector3(px, 0.03, pz)
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
		var pos := _find_open_near(v.x, v.y)
		var cp := {"x": pos.x, "z": pos.y, "owner":"neutral","progress":0.0,"node":null}
		cp.node = _build_cp(pos.x, pos.y)
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
		elif has_e and not has_p:
			cp.progress = maxf(0.0, float(cp.progress)-delta/5.0)
			if float(cp.progress) <= 0.0 and cp.owner != "enemy":
				cp.owner = "enemy"
				_set_cp_color(cp, Color(1.0,0.2,0.15))
				_set_status("CAPTURE POINT LOST!")
		if cp.owner == "player": bonus += 15.0
	supply_accum += delta * (20.0 + bonus)
	if supply_accum >= 1.0:
		supplies += int(supply_accum)
		supply_accum = fmod(supply_accum, 1.0)

func _set_cp_color(cp: Dictionary, color: Color) -> void:
	var node := cp.node as Node3D
	if node == null: return
	var flag := node.get_node_or_null("Flag") as MeshInstance3D
	if flag:
		var mat := flag.get_surface_override_material(0) as StandardMaterial3D
		if mat: mat.albedo_color = color; mat.emission = color * 0.5
	var ring := node.get_node_or_null("Ring") as MeshInstance3D
	if ring:
		var mat := ring.get_surface_override_material(0) as StandardMaterial3D
		if mat: mat.albedo_color = color; mat.emission = color * 0.45

# ── UNIT SPAWNING ──────────────────────────────────────────────

func spawn_unit(kind: String, team: String, px: float, pz: float) -> Unit:
	var u := Unit.new()
	var def: Dictionary = UNIT_DEFS[kind]
	u.setup(kind, team, def)
	_build_unit_mesh(u, kind, team)
	u.position = Vector3(px, 0.0, pz)
	units_node.add_child(u)
	units.append(u)
	_add_mm_dot(u)
	return u

func _build_unit_mesh(u: Unit, kind: String, team: String) -> void:
	# Color palette
	var is_player: bool = team == "player"
	var body_col:  Color
	var vest_col:  Color
	var helm_col:  Color
	var skin_col:  Color = Color(0.78,0.60,0.44) if is_player else Color(0.72,0.58,0.42)
	var acc_col:   Color = Color(0.30,1.00,0.43) if is_player else Color(1.00,0.25,0.18)

	match kind:
		"militia":
			body_col = Color(0.28,0.35,0.22)  # Olive civilian
			vest_col = Color(0.38,0.30,0.22)  # Brown jacket
			helm_col = Color(0.22,0.28,0.18)  # No helmet — baseball cap
		"grenadier","e_gren":
			body_col = Color(0.22,0.30,0.18)
			vest_col = Color(0.18,0.24,0.15)
			helm_col = Color(0.16,0.20,0.12)
		"sniper","e_sniper":
			body_col = Color(0.20,0.28,0.16)
			vest_col = Color(0.16,0.22,0.12)
			helm_col = Color(0.18,0.24,0.14)
		"mg_team","e_mg":
			body_col = Color(0.20,0.28,0.16)
			vest_col = Color(0.15,0.20,0.12)
			helm_col = Color(0.14,0.18,0.10)
		_:  # soldier
			body_col = Color(0.48,0.42,0.28)  # Tan military
			vest_col = Color(0.38,0.34,0.22)
			helm_col = Color(0.32,0.28,0.18)

	# Legs
	var leg_m := CylinderMesh.new()
	leg_m.top_radius = 0.10; leg_m.bottom_radius = 0.11; leg_m.height = 0.38; leg_m.radial_segments = 6
	var legs := MeshInstance3D.new(); legs.mesh = leg_m
	legs.set_surface_override_material(0, _mat(body_col.darkened(0.15)))
	legs.position.y = 0.19; u.add_child(legs)

	# Boots
	var boot_m := BoxMesh.new(); boot_m.size = Vector3(0.22,0.10,0.26)
	var boots := MeshInstance3D.new(); boots.mesh = boot_m
	boots.set_surface_override_material(0, _mat(Color(0.12,0.10,0.08)))
	boots.position.y = 0.05; u.add_child(boots)

	# Torso / jacket
	var torso_m := CylinderMesh.new()
	torso_m.top_radius = 0.13; torso_m.bottom_radius = 0.12; torso_m.height = 0.34; torso_m.radial_segments = 6
	var torso := MeshInstance3D.new(); torso.mesh = torso_m
	torso.set_surface_override_material(0, _mat(body_col))
	torso.position.y = 0.55; u.add_child(torso)

	# Tactical vest / chest rig
	var vest_m := BoxMesh.new(); vest_m.size = Vector3(0.26, 0.24, 0.16)
	var vest := MeshInstance3D.new(); vest.mesh = vest_m
	vest.set_surface_override_material(0, _mat(vest_col))
	vest.position = Vector3(0.0, 0.56, 0.06); u.add_child(vest)

	# Arms
	for side: float in [-1.0, 1.0]:
		var arm_m := CylinderMesh.new()
		arm_m.top_radius = 0.040; arm_m.bottom_radius = 0.047
		arm_m.height = 0.28; arm_m.radial_segments = 5
		var arm := MeshInstance3D.new(); arm.mesh = arm_m
		arm.set_surface_override_material(0, _mat(body_col))
		arm.position = Vector3(side*0.18, 0.50, 0.0)
		arm.rotation.z = side * deg_to_rad(32.0)
		u.add_child(arm)
	# Backpack for non-militia
	if kind != "militia":
		var bp_m := BoxMesh.new(); bp_m.size = Vector3(0.20, 0.24, 0.10)
		var bp := MeshInstance3D.new(); bp.mesh = bp_m
		bp.set_surface_override_material(0, _mat(vest_col.darkened(0.22)))
		bp.position = Vector3(0.0, 0.56, -0.14)
		u.add_child(bp)
	# Head (skin)
	var head_m := SphereMesh.new(); head_m.radius = 0.115; head_m.height = 0.22; head_m.radial_segments = 8; head_m.rings = 6
	var head := MeshInstance3D.new(); head.mesh = head_m
	head.set_surface_override_material(0, _mat(skin_col))
	head.position.y = 0.83; u.add_child(head)

	# Helmet or cap
	if kind == "militia":
		# Baseball cap (flat disc)
		var cap_m := CylinderMesh.new(); cap_m.top_radius=0.13; cap_m.bottom_radius=0.13; cap_m.height=0.06; cap_m.radial_segments=8
		var cap := MeshInstance3D.new(); cap.mesh = cap_m
		cap.set_surface_override_material(0, _mat(Color(0.22,0.28,0.18)))
		cap.position.y = 0.90; u.add_child(cap)
		# Brim
		var brim_m := CylinderMesh.new(); brim_m.top_radius=0.10; brim_m.bottom_radius=0.10; brim_m.height=0.025; brim_m.radial_segments=8
		var brim := MeshInstance3D.new(); brim.mesh = brim_m
		brim.set_surface_override_material(0, _mat(Color(0.22,0.28,0.18)))
		brim.position = Vector3(0.0,0.875,0.12); u.add_child(brim)
	else:
		# Military helmet
		var helm_m := SphereMesh.new(); helm_m.radius=0.145; helm_m.height=0.20; helm_m.radial_segments=8; helm_m.rings=4
		var helm := MeshInstance3D.new(); helm.mesh = helm_m
		helm.set_surface_override_material(0, _mat(helm_col))
		helm.position.y = 0.88; u.add_child(helm)

	# Weapon
	var wpn_len: float
	match kind:
		"sniper","e_sniper": wpn_len = 0.72
		"mg_team","e_mg":    wpn_len = 0.60
		_:                    wpn_len = 0.50
	var wpn_m := BoxMesh.new(); wpn_m.size = Vector3(0.045, 0.045, wpn_len)
	var wpn := MeshInstance3D.new(); wpn.mesh = wpn_m
	wpn.set_surface_override_material(0, _mat(Color(0.15,0.13,0.10)))
	wpn.position = Vector3(0.14, 0.60, wpn_len*0.28); u.add_child(wpn)

	# MG Team — add bipod
	if kind in ["mg_team","e_mg"]:
		for side: float in [-0.06, 0.06]:
			var bp_m := BoxMesh.new(); bp_m.size = Vector3(0.03,0.22,0.03)
			var bp := MeshInstance3D.new(); bp.mesh = bp_m
			bp.set_surface_override_material(0, _mat(Color(0.15,0.13,0.10)))
			bp.position = Vector3(side,0.42,0.30); u.add_child(bp)

	# Selection ring
	var rim_m := TorusMesh.new(); rim_m.inner_radius=0.52; rim_m.outer_radius=0.58; rim_m.rings=4; rim_m.ring_segments=16
	var sel_mat := StandardMaterial3D.new()
	sel_mat.albedo_color = acc_col
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.albedo_color.a = 0.9
	var sel := MeshInstance3D.new(); sel.mesh = rim_m; sel.name = "SelRing"
	sel.set_surface_override_material(0, sel_mat)
	sel.rotation.x = -PI/2.0; sel.position.y = 0.04; sel.visible = false
	u.add_child(sel)

	# HP bar BG
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08,0.08,0.08,0.9)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var hpbg := _box(Vector3(0.72,0.08,0.02), bg_mat)
	hpbg.name = "HPBg"; hpbg.position = Vector3(0.0,1.45,0.0); u.add_child(hpbg)

	# HP bar fill
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2,0.9,0.2)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var hpbar := _box(Vector3(0.72,0.08,0.02), fill_mat)
	hpbar.name = "HPBar"; hpbar.position = Vector3(0.0,1.45,0.001); u.add_child(hpbar)

# ── GAME LOOP ──────────────────────────────────────────────────

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_minimap()
	if not game_active or game_paused: return
	_update_wave(delta)
	_update_units(delta)
	_update_fog()
	_update_capture_points(delta)
	_update_hud()

func _update_wave(delta: float) -> void:
	wave_timer -= delta
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
	for k in kinds:
		var raw_x: float = -HQ_X + (_rng.randf()-0.5)*10.0
		var raw_z: float = -HQ_Z + (_rng.randf()-0.5)*10.0
		var sp := _find_road_near(raw_x, raw_z)
		spawn_unit(str(k), "enemy", sp.x, sp.z)

func _update_units(delta: float) -> void:
	var dead: Array = []
	var hq_pos := Vector3(HQ_X, 0.0, HQ_Z)
	for u in units:
		var unit := u as Unit
		if unit == null: continue
		if unit.hp <= 0:
			dead.append(unit); continue
		if unit.team == "player":
			_tick_player(unit, delta)
		else:
			_tick_enemy(unit, delta)
			# Enemy units in the player HQ zone damage the HQ
			if unit.global_position.distance_to(hq_pos) < 3.5:
				hq_hp = maxi(0, hq_hp - int(5.0 * delta))
				if hq_hp <= 0:
					_show_endgame(false)
					return
	for unit in dead:
		if unit.team == "enemy":
			kill_count += 1
			supplies += 10
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
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(unit, "scale", Vector3(0.0, 0.0, 0.0), 0.26)
	await tw.finished
	if is_instance_valid(unit): unit.queue_free()
	# Attrition defeat: waves started, no player units, can't afford cheapest
	if wave_num > 0 and game_active:
		var alive := false
		for au in units:
			var au_unit := au as Unit
			if au_unit != null and au_unit.team == "player" and au_unit.hp > 0:
				alive = true; break
		if not alive and supplies < 75:
			_show_endgame(false)

func _tick_player(u: Unit, delta: float) -> void:
	if u.state == Unit.State.MOVING:
		_step_path(u, delta)
		# Attack-move: fire opportunistically while advancing
		if u.attack_move and u.fire_timer <= 0.0:
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
				u.state = Unit.State.HOLDING

func _tick_enemy(u: Unit, delta: float) -> void:
	var nearest := _nearest_enemy(u, 999.0)
	if nearest == null: return
	var dist: float = u.global_position.distance_to(nearest.global_position)

	# Seek cover when suppressed
	if u.suppression > 0.55 and _rng.randf() < 0.01:
		var cover := _find_cover_pos(u)
		if cover != Vector3.ZERO:
			u.issue_move(cover)
			return

	# Advance or fire
	if u.state == Unit.State.MOVING:
		_step_path(u, delta)
	elif dist > u.attack_range * 0.8:
		# Move toward nearest player with slight flank offset
		var flank_angle: float = _rng.randf_range(-0.4, 0.4)
		var dir: Vector3 = (nearest.global_position - u.global_position).normalized()
		dir = dir.rotated(Vector3.UP, flank_angle)
		var dest := u.global_position + dir * 3.0
		dest.x = clampf(dest.x, -HALF+1.0, HALF-1.0)
		dest.z = clampf(dest.z, -HALF+1.0, HALF-1.0)
		_move_with_path(u, dest)

	if dist <= u.attack_range and u.fire_timer <= 0.0:
		_fire(u, nearest)
		return  # Don't move on the same frame we fire

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

# ── A* PATHFINDING ────────────────────────────────────────────

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
	var fr: int = clampi(int((from_world.z + HALF) / TCELL), 0, TG-1)
	var fc: int = clampi(int((from_world.x + HALF) / TCELL), 0, TG-1)
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
	waypoints.append(Vector3(to_world.x, 0.0, to_world.z))
	return waypoints

func _move_with_path(u: Unit, dest: Vector3) -> void:
	u.attack_move = false
	var wp := _find_path(u.global_position, dest)
	u.path = wp; u.path_idx = 0; u.state = Unit.State.MOVING

func _step_path(u: Unit, delta: float) -> void:
	if u.path.is_empty() or u.path_idx >= u.path.size():
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
	u.position += dir * u.speed * delta
	u.position.y = 0.0
	u.rotation.y = atan2(dir.x, dir.z)

func _fire(shooter: Unit, target: Unit) -> void:
	shooter.fire_timer = 1.0 / shooter.fire_rate
	var dmg: int = shooter.dmg_min + randi() % maxi(1, shooter.dmg_max - shooter.dmg_min + 1)
	target.take_damage(dmg)
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
	for i in 3:
		var fi := float(i)
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.52, 0.50, 0.46, 0.55 - fi*0.08)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var sm := SphereMesh.new()
		sm.radius = 0.28 + fi*0.12; sm.height = sm.radius * 1.8
		sm.radial_segments = 6; sm.rings = 4
		var s := MeshInstance3D.new(); s.mesh = sm
		s.set_surface_override_material(0, smat)
		var off := Vector3(_rng.randf_range(-0.4,0.4), fi*0.3, _rng.randf_range(-0.4,0.4))
		s.position = pos + off + Vector3(0.0, 0.4, 0.0)
		add_child(s)
		var dur: float = 1.1 + fi*0.35
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3(3.8, 3.8, 3.8), dur)
		tw.tween_property(smat, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.finished.connect(func()->void: if is_instance_valid(s): s.queue_free())

func _issue_attack_move(wp: Vector3) -> void:
	var count: int = sel_units.size()
	for i in count:
		var su := sel_units[i] as Unit
		if su == null or su.hp <= 0: continue
		var offset := Vector3.ZERO
		if count > 1:
			var angle: float = float(i) / float(count) * TAU
			offset = Vector3(cos(angle)*0.75, 0.0, sin(angle)*0.75)
		_move_with_path(su, wp + offset)
		su.attack_move = true
	var lbl: String = "%d units" % count if count > 1 else UNIT_DEFS[(sel_units[0] as Unit).kind].name
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
	var mat := StandardMaterial3D.new()
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode   = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority   = 127
	mat.texture_filter    = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_fog_img = Image.create(TG, TG, false, Image.FORMAT_RGBA8)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	mat.albedo_texture = _fog_tex
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
	# Small flash
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0,0.92,0.5)
	mat.emission_enabled = true; mat.emission = Color(1.0,0.7,0.2)*3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flash := _box(Vector3(0.12,0.12,0.12), mat)
	flash.position = from; add_child(flash)
	get_tree().create_timer(0.07).timeout.connect(func()->void: if is_instance_valid(flash): flash.queue_free())
	# Tracer line (thin box between from and to)
	var mid := (from+to)*0.5; var len: float = from.distance_to(to)
	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.albedo_color = Color(1.0,0.95,0.7,0.5)
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tracer := _box(Vector3(0.025,0.025,len), tracer_mat)
	tracer.position = mid
	tracer.look_at(to, Vector3.UP)
	add_child(tracer)
	get_tree().create_timer(0.05).timeout.connect(func()->void: if is_instance_valid(tracer): tracer.queue_free())

# ── CAMERA ────────────────────────────────────────────────────

func _update_camera(delta: float) -> void:
	# WASD / arrow key pan
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    kb.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  kb.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  kb.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): kb.x += 1.0
	if kb.length() > 0.0:
		var spd: float = 18.0 * delta
		cam_target.x = clampf(cam_target.x + kb.normalized().x * spd, -HALF, HALF)
		cam_target.z = clampf(cam_target.z + kb.normalized().y * spd, -HALF, HALF)
	var cam_dest := Vector3(cam_target.x, 0.0, cam_target.z)
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var t := _shake_timer / 0.35
		cam_dest += Vector3(_rng.randf_range(-1.0,1.0), 0.0, _rng.randf_range(-1.0,1.0)) * _shake_intensity * t
	else:
		_shake_intensity = 0.0
	camera_pivot.position = camera_pivot.position.lerp(cam_dest, delta*5.0)
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
		var e := event as InputEventScreenTouch
		if e.pressed:
			_drag_on = true; _drag_moved = false
			_drag_lx = e.position.x; _drag_ly = e.position.y
			_drag_sx = e.position.x; _drag_sy = e.position.y
		else:
			if not _drag_moved: _handle_tap(e.position)
			_drag_on = false
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _drag_on:
			cam_target.x -= (e.position.x-_drag_lx)*0.045
			cam_target.z -= (e.position.y-_drag_ly)*0.045
			cam_target.x = clampf(cam_target.x,-HALF,HALF)
			cam_target.z = clampf(cam_target.z,-HALF,HALF)
			_drag_lx = e.position.x; _drag_ly = e.position.y
			if absf(e.position.x-_drag_sx)>8.0 or absf(e.position.y-_drag_sy)>8.0:
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
			cam_target.x -= e.relative.x*0.06
			cam_target.z -= e.relative.y*0.06
			cam_target.x=clampf(cam_target.x,-HALF,HALF)
			cam_target.z=clampf(cam_target.z,-HALF,HALF)
			if e.relative.length()>3.0: _rdrag_moved=true
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

	# Deploy mode
	if deploying_kind != "":
		if wp != Vector3.ZERO:
			_do_deploy(deploying_kind, wp.x, wp.z)
		else:
			deploying_kind = ""
		return

	var tapped := _unit_at(wp)

	if not sel_units.is_empty():
		match cur_mode:
			"move":
				if wp != Vector3.ZERO:
					_issue_move_group(wp)
					cur_mode = "none"; return
			"attack_move":
				if wp != Vector3.ZERO:
					_issue_attack_move(wp)
					cur_mode = "none"; return
			"attack":
				if tapped != null and tapped.team == "enemy":
					for u in sel_units:
						var su := u as Unit
						if su: su.state = Unit.State.ATTACKING
					_set_status("ENGAGING TARGET"); return

	if tapped != null and tapped.team == "player":
		_select_unit(tapped)
		return

	if tapped == null:
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
	_update_unit_info()
	_set_status("SELECTED: %s  |  RIGHT-CLICK TO MOVE/ATTACK" % UNIT_DEFS[u.kind].name)

func _deselect() -> void:
	for s in sel_units:
		var su := s as Unit
		if su: su.set_selected(false)
	sel_units.clear()
	sel_unit = null; cur_mode = "none"
	_update_unit_info()

func _issue_move_group(wp: Vector3) -> void:
	var count: int = sel_units.size()
	for i in count:
		var su := sel_units[i] as Unit
		if su == null or su.hp <= 0: continue
		var offset := Vector3.ZERO
		if count > 1:
			var angle: float = float(i) / float(count) * TAU
			offset = Vector3(cos(angle)*0.75, 0.0, sin(angle)*0.75)
		_move_with_path(su, wp + offset)
	var lbl: String = UNIT_DEFS[(sel_units[0] as Unit).kind].name if count == 1 else "%d units" % count
	_set_status("MOVING %s" % lbl)

func _handle_right_click(screen_pos: Vector2) -> void:
	if deploying_kind != "":
		_reset_deploy_btn(deploying_kind)
		deploying_kind = ""
		_set_status("DEPLOY CANCELLED"); return
	if sel_units.is_empty(): return
	var wp := _ground_hit(screen_pos)
	if wp == Vector3.ZERO: return
	var tapped := _unit_at(wp)
	if cur_mode == "attack_move":
		_issue_attack_move(wp); cur_mode = "none"; return
	if tapped != null and tapped.team == "enemy":
		for u in sel_units:
			var su := u as Unit
			if su and su.hp > 0: su.state = Unit.State.ATTACKING
		_set_status("ENGAGING")
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
		_set_status("SELECTED %d UNITS  |  RIGHT-CLICK TO COMMAND" % sel_units.size())
	elif sel_units.size() == 1 and sel_unit != null:
		_set_status("SELECTED: %s  |  RIGHT-CLICK TO MOVE/ATTACK" % UNIT_DEFS[sel_unit.kind].name)
	else:
		_set_status("DEFEND THE NEIGHBORHOOD  |  TAP TO SELECT  |  RIGHT-CLICK TO COMMAND")

func _do_deploy(kind: String, px: float, pz: float) -> void:
	var def: Dictionary = UNIT_DEFS[kind]
	var cost: int = int(def.cost)
	if supplies < cost:
		_set_status("NOT ENOUGH SUPPLIES! NEED %d" % cost); return
	if Vector2(px,pz).distance_to(Vector2(HQ_X,HQ_Z)) > 8.0:
		_set_status("DEPLOY WITHIN THE GREEN ZONE"); return
	supplies -= cost
	spawn_unit(kind, "player", px, pz)
	# Keep deploying_kind active so player can place more without re-selecting
	_set_status("%s DEPLOYED  |  TAP TO PLACE ANOTHER  |  RIGHT-CLICK TO CANCEL" % def.name)

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
		sub.text       = "HQ destroyed.  KIA: %d  Supplies remaining: %d" % [kill_count, supplies]

# ── HUD ───────────────────────────────────────────────────────

func _setup_hud() -> void:
	for btn in deploy_panel.get_children():
		if btn is Button and btn.has_meta("kind"):
			var k: String = str(btn.get_meta("kind"))
			btn.pressed.connect(func()->void: Sounds.play("click",-6.0); _start_deploy(k))
	$HUD/UnitInfo/ModeBar/MoveBtn.pressed.connect(_cmd_move)
	$HUD/UnitInfo/ModeBar/AtkBtn.pressed.connect(_cmd_attack)
	$HUD/UnitInfo/ModeBar/HoldBtn.pressed.connect(_cmd_hold)
	var ret_btn := $HUD/EndgamePanel/VBox/ReturnBtn as Button
	if ret_btn:
		ret_btn.pressed.connect(func()->void: _main().show_globe())
	var pause_btn := $HUD/TopBar/PauseBtn as Button
	if pause_btn:
		pause_btn.pressed.connect(func()->void: if game_active: _show_pause())

func _cmd_move() -> void:
	if not sel_units.is_empty():
		cur_mode = "move"
		_set_status("MOVE MODE — RIGHT-CLICK DESTINATION")
	else:
		_set_status("SELECT A UNIT FIRST")

func _cmd_attack() -> void:
	if not sel_units.is_empty():
		cur_mode = "attack"
		_set_status("ATTACK MODE — RIGHT-CLICK ENEMY")
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
	_set_status("DEPLOY %s (%d SUPPLIES) — TAP GREEN ZONE  |  RIGHT-CLICK TO CANCEL" % [def.name, def.cost])

func _reset_deploy_btn(kind: String) -> void:
	for btn in deploy_panel.get_children():
		if btn is Button and btn.has_meta("kind") and str(btn.get_meta("kind")) == kind:
			btn.modulate = Color(1.0, 1.0, 1.0); break

func _update_hud() -> void:
	res_label.text   = "SUPPLIES: %d" % supplies
	wave_label.text  = "WAVE %d/%d  |  %ds" % [wave_num, WAVE_DEFS.size(), maxi(0,int(wave_timer))]
	kills_label.text = "KIA: %d" % kill_count
	hq_label.text    = "HQ: %d/%d" % [hq_hp, hq_hp_max]
	hq_label.modulate = Color(0.4,0.7,1.0) if hq_hp > 50 else (Color(1.0,0.75,0.2) if hq_hp > 25 else Color(1.0,0.3,0.2))

func _update_unit_info() -> void:
	if sel_units.is_empty():
		unit_info.visible = false
	elif sel_units.size() == 1 and sel_unit != null:
		unit_info.visible = true
		var def: Dictionary = UNIT_DEFS[sel_unit.kind]
		unit_name_lbl.text = "%s  HP %d/%d" % [def.name, sel_unit.hp, sel_unit.hp_max]
	else:
		unit_info.visible = true
		unit_name_lbl.text = "%d UNITS SELECTED" % sel_units.size()

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

# ── HELPERS ───────────────────────────────────────────────────

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color; _mats[key] = m
	return _mats[key]

func _mat_new(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; return m

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new(); bm.size = size
	var mi := MeshInstance3D.new(); mi.mesh = bm
	mi.set_surface_override_material(0, mat); return mi

func _tx(c: int) -> float: return float(c - TG/2)*TCELL + TCELL/2.0
func _tz(r: int) -> float: return float(r - TG/2)*TCELL + TCELL/2.0
func _main() -> Node: return get_tree().root.get_node("Main")
