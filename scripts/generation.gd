extends Control

const _S        := preload("res://scripts/secrets.gd")
const REAL_HALF := 100.0   # metres from centre to edge — 200 × 200 m battlefield
const TG        := 20

@onready var status_label : Label       = $VBox/StatusLabel
@onready var progress_bar : ProgressBar = $VBox/ProgressBar
@onready var sat_preview  : TextureRect = $VBox/SatPreview
@onready var http_sat     : HTTPRequest = $HTTPImg
@onready var http_osm     : HTTPRequest = $HTTPGemini

var _clat: float
var _clon: float
var _road_geoms: Array = []
var _bld_geoms:  Array = []

func _ready() -> void:
	progress_bar.value = 0
	var main := _main()
	_clat = main.active_lat
	_clon = main.active_lon
	_ensure_cache_dir()
	_set_status("FETCHING SATELLITE PREVIEW...")
	http_sat.request_completed.connect(_on_sat_done)
	http_osm.request_completed.connect(_on_osm_done)
	var url := ("https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/%.6f,%.6f,17,0/600x600?access_token=%s"
		% [_clon, _clat, _S.MAPBOX])
	http_sat.request(url)

# ── Cache helpers ─────────────────────────────────────────────────

func _cache_key() -> String:
	return "%.4f_%.4f" % [_clat, _clon]

func _cache_dir() -> String:
	return "user://map_cache/"

func _ensure_cache_dir() -> void:
	DirAccess.make_dir_recursive_absolute(_cache_dir())

func _osm_cache_path() -> String:
	return _cache_dir() + _cache_key() + ".json"

func _sat_cache_path() -> String:
	return _cache_dir() + _cache_key() + ".sat"

# ── Satellite preview ─────────────────────────────────────────────

func _on_sat_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result == OK and code == 200:
		var img := Image.new()
		if img.load_jpg_from_buffer(body) == OK:
			sat_preview.texture = ImageTexture.create_from_image(img)
	progress_bar.value = 30

	# Check OSM cache before hitting the network
	var osm_path := _osm_cache_path()
	if FileAccess.file_exists(osm_path):
		_set_status("LOADING MAP DATA FROM CACHE...")
		var f := FileAccess.open(osm_path, FileAccess.READ)
		var cached := f.get_as_text()
		f.close()
		_process_osm(cached, true)
	else:
		_set_status("READING OPENSTREETMAP DATA...")
		_fetch_osm()

# ── OSM fetch ─────────────────────────────────────────────────────

func _fetch_osm() -> void:
	var cos_lat := cos(deg_to_rad(_clat))
	var dlat    := REAL_HALF / 111000.0
	var dlon    := REAL_HALF / (111000.0 * maxf(cos_lat, 0.0001))
	var s       := _clat - dlat;  var n := _clat + dlat
	var w       := _clon - dlon;  var e := _clon + dlon
	var bb      := "%.6f,%.6f,%.6f,%.6f" % [s, w, n, e]
	var q := (
		"[out:json][timeout:25];("
		+ "way[building](%s);" % bb
		+ "way[highway](%s);" % bb
		+ "way[natural=water](%s);" % bb
		+ "way[waterway](%s);" % bb
		+ "way[landuse=park](%s);" % bb
		+ "way[landuse=forest](%s);" % bb
		+ "way[natural=wood](%s);" % bb
		+ "way[leisure=park](%s);" % bb
		+ ");out geom;")
	http_osm.request("https://overpass-api.de/api/interpreter?data=" + q.uri_encode())

func _on_osm_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK or code != 200:
		_fallback("OSM UNAVAILABLE (CODE %d) — PROCEDURAL MAP" % code)
		return
	var body_str := body.get_string_from_utf8()
	# Persist to cache for next visit
	var f := FileAccess.open(_osm_cache_path(), FileAccess.WRITE)
	if f:
		f.store_string(body_str)
		f.close()
	_process_osm(body_str, false)

# ── OSM processing (shared between network and cache paths) ───────

func _process_osm(body_str: String, from_cache: bool) -> void:
	progress_bar.value = 70
	_set_status("PLACING BUILDINGS AND ROADS...")
	var json := JSON.new()
	if json.parse(body_str) != OK:
		_fallback("OSM PARSE ERROR — PROCEDURAL MAP")
		return
	var data: Dictionary = json.get_data()
	var elements: Array  = data.get("elements", [])
	if elements.is_empty():
		_fallback("NO OSM DATA FOR THIS LOCATION — PROCEDURAL MAP")
		return
	var grid := _rasterize(elements)
	var hits := 0
	for row in grid:
		for cell in row:
			if cell != "GRASS": hits += 1
	if hits < 4:
		_fallback("SPARSE OSM DATA — PROCEDURAL MAP")
		return
	var road_n := 0; var bld_n := 0
	for row in grid:
		for cell in row:
			if cell == "ROAD":     road_n += 1
			elif cell == "BUILDING": bld_n += 1
	if road_n == 0 and bld_n == 0:
		_fallback("EMPTY OSM GRID — PROCEDURAL MAP")
		return
	_main().ai_tile_grid  = grid
	_main().using_ai_map  = true
	_main().osm_roads     = _road_geoms
	_main().osm_buildings = _bld_geoms
	var src := " (CACHED)" if from_cache else ""
	_set_status("MAPPED%s: %d BUILDINGS · %d ROAD TILES — FETCHING GROUND TEXTURE..." % [src, bld_n, road_n])
	progress_bar.value = 85

	# Check satellite ground texture cache
	var sat_path := _sat_cache_path()
	if FileAccess.file_exists(sat_path):
		_set_status("LOADING SATELLITE FROM CACHE...")
		var sf := FileAccess.open(sat_path, FileAccess.READ)
		_main().sat_image_data = sf.get_buffer(sf.get_length())
		sf.close()
		progress_bar.value = 100
		_set_status("MAP READY — LAUNCHING" + (" (CACHED)" if from_cache else ""))
		_launch()
	else:
		_fetch_sat_ground()

# ── Rasterisation ─────────────────────────────────────────────────
# Pass order matters: later passes overwrite earlier ones.
# green space < water < buildings < roads

func _rasterize(elements: Array) -> Array:
	_road_geoms.clear()
	_bld_geoms.clear()
	var grid: Array = []
	for _r in TG:
		var row: Array = []; for _c in TG: row.append("GRASS")
		grid.append(row)

	# 1. Green space
	for el in elements:
		if el.get("type") != "way": continue
		var tags: Dictionary = el.get("tags", {})
		var luse: String = tags.get("landuse", "")
		var nat:  String = tags.get("natural", "")
		var lei:  String = tags.get("leisure", "")
		if nat == "wood" or lei == "park" or luse in ["forest","park","grass","meadow","recreation_ground","village_green"]:
			_fill_poly(grid, _geom_to_cells(el.get("geometry", [])), "TREE")

	# 2. Water
	for el in elements:
		if el.get("type") != "way": continue
		var tags: Dictionary = el.get("tags", {})
		if tags.get("natural","") == "water" or tags.has("waterway"):
			_fill_poly(grid, _geom_to_cells(el.get("geometry", [])), "WATER")

	# 3. Buildings (fill polygon + collect footprint for 3D extrusion)
	for el in elements:
		if el.get("type") != "way": continue
		var tags: Dictionary = el.get("tags", {})
		if tags.has("building"):
			var geom: Array = el.get("geometry", [])
			_fill_poly(grid, _geom_to_cells(geom), "BUILDING")
			if geom.size() >= 3:
				var h_str: String = str(tags.get("height", "0")).split(" ")[0]
				_bld_geoms.append({
					"geom":   geom,
					"levels": int(float(str(tags.get("building:levels", "0")))),
					"height": float(h_str) if h_str.is_valid_float() else 0.0,
					"type":   str(tags.get("building", "yes"))
				})

	# 4. Roads (polyline with width, drawn last so they cut through buildings)
	for el in elements:
		if el.get("type") != "way": continue
		var tags: Dictionary = el.get("tags", {})
		var hw: String = tags.get("highway", "")
		if hw == "" or hw in ["footway","path","cycleway","steps","track","bridleway"]:
			continue
		var w := 2 if hw in ["motorway","trunk","primary","secondary","pedestrian"] else 1
		var geom: Array = el.get("geometry", [])
		if geom.size() >= 2:
			_road_geoms.append({"geom": geom, "width": w})
		var cells := _geom_to_cells(geom)
		for i in range(cells.size() - 1):
			_draw_line(grid, cells[i].x, cells[i].y, cells[i+1].x, cells[i+1].y, "ROAD", w)

	return grid

func _geom_to_cells(geom: Array) -> Array:
	var cells: Array = []
	var cos_lat := cos(deg_to_rad(_clat))
	for pt in geom:
		var lat: float = float(pt.get("lat", 0.0))
		var lon: float = float(pt.get("lon", 0.0))
		var dy  := (lat - _clat) * 111000.0
		var dx  := (lon - _clon) * 111000.0 * cos_lat
		var nc  := (dx / REAL_HALF + 1.0) * 0.5
		var nr  := (-dy / REAL_HALF + 1.0) * 0.5
		var col := clampi(int(nc * TG), 0, TG - 1)
		var row := clampi(int(nr * TG), 0, TG - 1)
		cells.append(Vector2i(col, row))
	return cells

func _fill_poly(grid: Array, verts: Array, label: String) -> void:
	if verts.size() < 3: return
	var min_r := TG; var max_r := 0; var min_c := TG; var max_c := 0
	for v in verts:
		min_r = mini(min_r, v.y); max_r = maxi(max_r, v.y)
		min_c = mini(min_c, v.x); max_c = maxi(max_c, v.x)
	for r in range(clampi(min_r, 0, TG - 1), clampi(max_r + 1, 0, TG)):
		for c in range(clampi(min_c, 0, TG - 1), clampi(max_c + 1, 0, TG)):
			if _pip(c, r, verts):
				grid[r][c] = label

func _pip(px: int, py: int, poly: Array) -> bool:
	var inside := false; var n := poly.size(); var j := n - 1
	for i in n:
		var xi := float(poly[i].x); var yi := float(poly[i].y)
		var xj := float(poly[j].x); var yj := float(poly[j].y)
		if (yi > float(py)) != (yj > float(py)):
			if float(px) < (xj - xi) * (float(py) - yi) / (yj - yi) + xi:
				inside = !inside
		j = i
	return inside

func _draw_line(grid: Array, c0: int, r0: int, c1: int, r1: int, label: String, width: int) -> void:
	var dc: int = abs(c1 - c0); var dr: int = abs(r1 - r0)
	var sc: int = 1 if c1 > c0 else (-1 if c1 < c0 else 0)
	var sr: int = 1 if r1 > r0 else (-1 if r1 < r0 else 0)
	if sc == 0 and sr == 0:
		_mark(grid, r0, c0, label, width); return
	var err: int = dc - dr
	while true:
		_mark(grid, r0, c0, label, width)
		if c0 == c1 and r0 == r1: break
		var e2: int = 2 * err
		if e2 >= -dr: err -= dr; c0 += sc
		if e2 <= dc:  err += dc; r0 += sr

func _mark(grid: Array, r: int, c: int, label: String, half_w: int) -> void:
	for dr in range(-half_w / 2, half_w / 2 + 1):
		for dc in range(-half_w / 2, half_w / 2 + 1):
			var rr := r + dr; var cc := c + dc
			if rr >= 0 and rr < TG and cc >= 0 and cc < TG:
				grid[rr][cc] = label

# ── Satellite ground texture ──────────────────────────────────────

func _fetch_sat_ground() -> void:
	var cos_lat := cos(deg_to_rad(_clat))
	var dlat    := REAL_HALF / 111000.0
	var dlon    := REAL_HALF / (111000.0 * maxf(cos_lat, 0.0001))
	var s := _clat - dlat;  var n := _clat + dlat
	var w := _clon - dlon;  var e := _clon + dlon
	var url := ("https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/[%.6f,%.6f,%.6f,%.6f]/1024x1024?access_token=%s"
		% [w, s, e, n, _S.MAPBOX])
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		if result == OK and code == 200:
			_main().sat_image_data = body
			# Save satellite to cache for next visit
			var sf := FileAccess.open(_sat_cache_path(), FileAccess.WRITE)
			if sf:
				sf.store_buffer(body)
				sf.close()
		req.queue_free()
		progress_bar.value = 100
		_set_status("MAP READY — LAUNCHING")
		_launch()
	)
	req.request(url)

# ── Helpers ───────────────────────────────────────────────────────

func _fallback(msg: String) -> void:
	_main().ai_tile_grid = []
	_main().using_ai_map = false
	_set_status(msg)
	progress_bar.value = 100
	_launch()

func _launch() -> void:
	await get_tree().create_timer(0.8).timeout
	_main().show_game()

func _set_status(msg: String) -> void:
	status_label.text = msg

func _main() -> Node:
	return get_tree().root.get_node("Main")
