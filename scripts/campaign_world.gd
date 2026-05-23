extends Control
# World theater — shown after the prologue completes.
# Displays all 12 cities with lock/unlock status and star ratings.
# Player selects a city, then normal generation → game flow runs,
# with Campaign.record_world_battle() called on return.

var _city_btns: Array = []  # Button per LOCATIONS entry

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.color = Color(0.08, 0.20, 0.08, 1.0)
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_bottom = 80
	add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.text = "WORLD RESISTANCE  —  THEATER OF OPERATIONS"
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.43))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_lbl.offset_bottom = 80
	add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Select a city to battle.  Earn ★ to liberate it and unlock adjacent cities."
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub_lbl.offset_top    = 76
	sub_lbl.offset_bottom = 104
	add_child(sub_lbl)

	# Scroll + city grid
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top    = 108
	scroll.offset_bottom = -80
	scroll.offset_left   = 40
	scroll.offset_right  = -40
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for i in CampaignData.LOCATIONS.size():
		var loc: Dictionary = CampaignData.LOCATIONS[i]
		var unlocked: bool  = Campaign.is_city_unlocked(i)
		var stars: int      = Campaign.get_city_stars(i)

		var card := _make_city_card(i, str(loc.get("name", "")), unlocked, stars)
		grid.add_child(card)
		_city_btns.append(card)

	# Bottom bar
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top    = -72
	bottom.offset_bottom = -12
	bottom.offset_left   = 40
	bottom.offset_right  = -40
	bottom.alignment     = BoxContainer.ALIGNMENT_END
	add_child(bottom)

	var back_btn := Button.new()
	back_btn.text = "← BACK TO GLOBE"
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	back_btn.pressed.connect(func()->void: Sounds.play("click"); _main().show_globe())
	bottom.add_child(back_btn)

func _make_city_card(city_idx: int, city_name: String, unlocked: bool, stars: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 130)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	if unlocked:
		sb.bg_color     = Color(0.06, 0.16, 0.06, 0.95)
		sb.border_color = Color(0.20, 0.65, 0.22, 1.0)
	else:
		sb.bg_color     = Color(0.06, 0.06, 0.06, 0.90)
		sb.border_color = Color(0.25, 0.25, 0.25, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 16
	vbox.offset_right  = -16
	vbox.offset_top    = 12
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 6)
	p.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = city_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	if unlocked:
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 0.90))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	vbox.add_child(name_lbl)

	var star_str := ""
	for _i in 3:
		star_str += ("★" if _i < stars else "☆")
	var star_lbl := Label.new()
	star_lbl.text = star_str
	star_lbl.add_theme_font_size_override("font_size", 22)
	star_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.25) if stars > 0 else Color(0.30, 0.30, 0.30))
	vbox.add_child(star_lbl)

	var btn := Button.new()
	if unlocked:
		btn.text = "⚔  BATTLE"
		btn.add_theme_color_override("font_color",       Color(0.3, 1.0, 0.43))
		btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.6))
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func()->void: _launch_battle(city_idx))
	else:
		btn.text = "🔒  LOCKED"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(btn)

	return p

func _launch_battle(city_idx: int) -> void:
	Sounds.play("click")
	var loc: Dictionary = CampaignData.LOCATIONS[city_idx]
	var mn := _main()
	mn.active_lat        = float(loc.get("lat", 0.0))
	mn.active_lon        = float(loc.get("lon", 0.0))
	mn.active_name       = str(loc.get("name", ""))
	mn.campaign_mode     = true
	mn.campaign_city_idx = city_idx
	mn.show_generation()

func _main() -> Node:
	return get_tree().root.get_node("Main")
