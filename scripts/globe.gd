extends Control

var _mapbox_key: String = ""
func _get_mapbox_key() -> String:
	if _mapbox_key.is_empty():
		var s = load("res://scripts/secrets.gd")
		if s != null and s.get_script_constant_map().has("MAPBOX"):
			_mapbox_key = str(s.get_script_constant_map()["MAPBOX"])
		else:
			_mapbox_key = ProjectSettings.get_setting("mapbox/api_key", "")
	return _mapbox_key

const LOCATIONS := [
	{"name": "New York, NY",       "lat": 40.7128,  "lon": -74.0060},
	{"name": "Chicago, IL",        "lat": 41.8781,  "lon": -87.6298},
	{"name": "London, UK",         "lat": 51.5074,  "lon": -0.1278},
	{"name": "Tokyo, Japan",       "lat": 35.6762,  "lon": 139.6503},
	{"name": "Sydney, Australia",  "lat": -33.8688, "lon": 151.2093},
	{"name": "Paris, France",      "lat": 48.8566,  "lon": 2.3522},
	{"name": "Dubai, UAE",         "lat": 25.2048,  "lon": 55.2708},
	{"name": "Moscow, Russia",     "lat": 55.7558,  "lon": 37.6173},
	{"name": "Kyiv, Ukraine",      "lat": 50.4501,  "lon": 30.5234},
	{"name": "Berlin, Germany",    "lat": 52.5200,  "lon": 13.4050},
	{"name": "Fallujah, Iraq",     "lat": 33.3500,  "lon": 43.7833},
	{"name": "Stalingrad, Russia", "lat": 48.7080,  "lon": 44.5133},
]

var _locs: Array = []
var _last_search: String = ""
var _check_lat: float = 0.0
var _check_lon: float = 0.0

@onready var location_list:  ItemList = $VBox/LocationList
@onready var search_edit:    LineEdit = $VBox/SearchBox/SearchEdit
@onready var subtitle_label: Label   = $VBox/Subtitle
@onready var coords_label:   Label   = $VBox/CoordsLabel
@onready var check_label:   Label    = $VBox/CheckLabel
@onready var sat_preview:   TextureRect = $VBox/SatPreview
@onready var generate_btn:  Button   = $VBox/GenerateBtn
@onready var http:          HTTPRequest = $HTTPRequest
@onready var http_check:    HTTPRequest = $HTTPCheck

func _ready() -> void:
	_locs = LOCATIONS.duplicate(true)
	_populate_list()
	http_check.request_completed.connect(_on_check_done)
	location_list.select(0)
	_on_location_selected(0)
	search_edit.text_submitted.connect(_on_search)
	$VBox/SearchBox/SearchBtn.pressed.connect(func()->void: _on_search(search_edit.text))
	location_list.item_selected.connect(_on_location_selected)
	generate_btn.pressed.connect(func()->void: Sounds.play("click"); _on_generate())
	$VBox/QuitBtn.pressed.connect(func()->void: get_tree().quit())
	http.request_completed.connect(_on_geocode_done)
	_style_generate_btn()
	_pulse_generate_btn()

func _style_generate_btn() -> void:
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.04, 0.12, 0.04, 0.95)
	norm.border_color = Color(0.20, 0.65, 0.22, 1.0)
	norm.set_border_width_all(2); norm.border_width_left = 5
	norm.set_corner_radius_all(4)
	norm.content_margin_left = 24; norm.content_margin_right = 24
	norm.content_margin_top = 16; norm.content_margin_bottom = 16
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(0.06, 0.20, 0.06, 0.98)
	hov.border_color = Color(0.30, 1.00, 0.43, 1.0)
	hov.set_border_width_all(2); hov.border_width_left = 5
	hov.set_corner_radius_all(4)
	hov.content_margin_left = 24; hov.content_margin_right = 24
	hov.content_margin_top = 16; hov.content_margin_bottom = 16
	generate_btn.add_theme_stylebox_override("normal", norm)
	generate_btn.add_theme_stylebox_override("hover",  hov)
	generate_btn.add_theme_stylebox_override("pressed", hov)
	generate_btn.add_theme_color_override("font_color",       Color(0.30, 1.00, 0.43))
	generate_btn.add_theme_color_override("font_hover_color", Color(0.50, 1.00, 0.60))
	generate_btn.focus_mode = Control.FOCUS_NONE

func _pulse_generate_btn() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(generate_btn, "modulate", Color(1.18, 1.18, 1.18), 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(generate_btn, "modulate", Color(1.00, 1.00, 1.00), 0.9).set_ease(Tween.EASE_IN_OUT)

func _load_scores() -> Dictionary:
	if not FileAccess.file_exists("user://scores.json"): return {}
	var f := FileAccess.open("user://scores.json", FileAccess.READ)
	if f == null: return {}
	var j := JSON.new()
	var result := j.parse(f.get_as_text())
	f.close()
	if result != OK: return {}
	var d = j.get_data()
	return d if d is Dictionary else {}

func _populate_list() -> void:
	location_list.clear()
	var scores := _load_scores()
	for loc in _locs:
		var key := "%.4f_%.4f" % [float(loc.lat), float(loc.lon)]
		var sc: Dictionary = scores.get(key, {})
		var label := str(loc.name)
		if not sc.is_empty():
			var best_waves: int = int(sc.get("best_waves", 0))
			var kills: int      = int(sc.get("kills", 0))
			var wins: int       = int(sc.get("victories", 0))
			var star := "★" if wins > 0 else "◆"
			label += "  %s W%d | %d KIA" % [star, best_waves, kills]
		location_list.add_item(label)

func _on_location_selected(idx: int) -> void:
	if idx >= _locs.size(): return
	var loc: Dictionary = _locs[idx]
	var main := _main()
	main.active_lat  = float(loc.lat)
	main.active_lon  = float(loc.lon)
	main.active_name = str(loc.name)
	subtitle_label.text = "BATTLEFIELD: %s" % str(loc.name).to_upper()
	subtitle_label.add_theme_color_override("font_color", Color(0.30, 1.00, 0.43))
	coords_label.text = "LAT %.4f  LON %.4f" % [loc.lat, loc.lon]
	_load_sat_preview(float(loc.lat), float(loc.lon))
	_check_osm(float(loc.lat), float(loc.lon))

func _load_sat_preview(lat: float, lon: float) -> void:
	var url := "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/%.6f,%.6f,15,0/400x200?access_token=%s" % [lon, lat, _get_mapbox_key()]
	var img_req := HTTPRequest.new()
	add_child(img_req)
	img_req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		if result == OK and code == 200:
			var img := Image.new()
			if img.load_jpg_from_buffer(body) == OK:
				sat_preview.texture = ImageTexture.create_from_image(img)
		img_req.queue_free()
	)
	img_req.request(url)

# ── OSM validation ────────────────────────────────────────────

func _check_osm(lat: float, lon: float) -> void:
	_check_lat = lat
	_check_lon = lon
	generate_btn.disabled = true
	check_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.35))
	check_label.text = "CHECKING LOCATION DATA..."
	http_check.cancel_request()
	var cos_lat := cos(deg_to_rad(lat))
	var dlat    := 100.0 / 111000.0
	var dlon    := 100.0 / (111000.0 * maxf(cos_lat, 0.0001))
	var bb      := "%.6f,%.6f,%.6f,%.6f" % [lat - dlat, lon - dlon, lat + dlat, lon + dlon]
	var q       := "[out:json][timeout:10];(way[building](%s);way[highway](%s););out count;" % [bb, bb]
	http_check.request("https://overpass-api.de/api/interpreter?data=" + q.uri_encode())

func _on_check_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var main := _main()
	# Discard if user already moved to a different location
	if absf(main.active_lat - _check_lat) > 0.00001 or absf(main.active_lon - _check_lon) > 0.00001:
		return
	if result != OK or code != 200:
		# Network issue — allow anyway; generation.gd has its own fallback
		check_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.4))
		check_label.text = "LOCATION CHECK UNAVAILABLE"
		generate_btn.disabled = false
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		generate_btn.disabled = false
		return
	var data: Dictionary = json.get_data()
	var total := 0
	for el in data.get("elements", []):
		if el.get("type") == "count":
			total = int(str(el.get("tags", {}).get("total", "0")))
	if total == 0:
		check_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.18))
		check_label.text = "NO MAP DATA — IN OCEAN OR WILDERNESS"
		generate_btn.disabled = true
	elif total < 5:
		check_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.18))
		check_label.text = "VERY SPARSE — RURAL AREA (%d FEATURES)" % total
		generate_btn.disabled = false
	else:
		check_label.add_theme_color_override("font_color", Color(0.30, 1.00, 0.43))
		check_label.text = "%d MAP FEATURES FOUND" % total
		generate_btn.disabled = false

# ── Search ────────────────────────────────────────────────────

func _on_search(query: String) -> void:
	if query.is_empty(): return
	_last_search = query
	search_edit.editable = false
	var url := "https://api.mapbox.com/geocoding/v5/mapbox.places/%s.json?access_token=%s&limit=1" % [query.uri_encode(), _get_mapbox_key()]
	http.request(url)

func _on_geocode_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	search_edit.editable = true
	if code != 200: return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK: return
	var data: Dictionary = json.get_data()
	var features: Array = data.get("features", [])
	if features.is_empty(): return
	var feat: Dictionary = features[0]
	var center: Array = feat.get("center", [0.0, 0.0])
	var new_loc := {
		"name": feat.get("place_name", _last_search),
		"lat":  float(center[1]),
		"lon":  float(center[0])
	}
	_locs.append(new_loc)
	_populate_list()
	var idx := _locs.size() - 1
	location_list.select(idx)
	_on_location_selected(idx)
	search_edit.clear()

func _on_generate() -> void:
	_main().show_generation()

func _main() -> Node:
	return get_tree().root.get_node("Main")
