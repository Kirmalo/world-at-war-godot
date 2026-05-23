extends Control
# Pre- and post-mission briefing screen with portrait dialogue.
# Instantiated by main.gd and configured via setup_pre() / setup_post()
# before the transition plays.

# ── DATA ─────────────────────────────────────────────────────────────────────
var _lines:        Array    = []      # [{speaker, text}, ...]
var _line_idx:     int      = 0
var _full_text:    String   = ""
var _chars_shown:  int      = 0
var _typewriting:  bool     = false
var _tw_timer:     float    = 0.0
const _TW_SPEED := 0.028            # seconds per character

var _title_str:    String   = ""
var _sub_str:      String   = ""
var _is_pre:       bool     = true   # pre-mission vs post-mission
var _is_victory:   bool     = false  # used for post-mission confirm label
var _on_complete:  Callable

# ── BUILT NODES ──────────────────────────────────────────────────────────────
var _title_lbl:      Label
var _sub_lbl:        Label
var _portrait_l:     Panel
var _portrait_r:     Panel
var _portrait_l_lbl: Label
var _portrait_r_lbl: Label
var _speaker_lbl:    Label
var _text_lbl:       RichTextLabel
var _continue_btn:   Button
var _skip_btn:       Button
var _progress_lbl:   Label

# ── SETUP API ─────────────────────────────────────────────────────────────────

func setup_pre(title: String, subtitle: String, lines: Array, on_complete: Callable) -> void:
	_title_str   = title
	_sub_str     = subtitle
	_lines       = lines
	_is_pre      = true
	_on_complete = on_complete
	if is_node_ready():
		_apply_setup()

func setup_post(title: String, subtitle: String, lines: Array, victory: bool, on_complete: Callable) -> void:
	_title_str   = title
	_sub_str     = subtitle
	_lines       = lines
	_is_pre      = false
	_is_victory  = victory
	_on_complete = on_complete
	if is_node_ready():
		_apply_setup()

# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_apply_setup()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# ── dark background ──────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.04, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── decorative top bar ───────────────────────────────────────────────────
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.10, 0.24, 0.10, 1.0)
	top_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_bar.anchor_bottom = 0.0
	top_bar.offset_bottom = 64
	add_child(top_bar)

	# ── mission title ────────────────────────────────────────────────────────
	_title_lbl = Label.new()
	_title_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_title_lbl.offset_left   = 40
	_title_lbl.offset_top    = 8
	_title_lbl.offset_right  = 1880
	_title_lbl.offset_bottom = 44
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.43))
	add_child(_title_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_sub_lbl.offset_left   = 40
	_sub_lbl.offset_top    = 40
	_sub_lbl.offset_right  = 1880
	_sub_lbl.offset_bottom = 64
	_sub_lbl.add_theme_font_size_override("font_size", 16)
	_sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55))
	add_child(_sub_lbl)

	# ── portrait area ────────────────────────────────────────────────────────
	var portrait_row := HBoxContainer.new()
	portrait_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_row.offset_left   = 80
	portrait_row.offset_top    = 80
	portrait_row.offset_right  = -80
	portrait_row.offset_bottom = -220
	portrait_row.alignment     = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_theme_constant_override("separation", 80)
	add_child(portrait_row)

	_portrait_l     = _make_portrait("COMMANDER", CampaignData.CHARACTERS["self"]["color"])
	_portrait_l_lbl = _portrait_l.get_child(0) as Label
	portrait_row.add_child(_portrait_l)

	# centre column — speaker name + dialogue text
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.add_theme_constant_override("separation", 18)
	portrait_row.add_child(centre)

	_speaker_lbl = Label.new()
	_speaker_lbl.add_theme_font_size_override("font_size", 22)
	_speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_speaker_lbl)

	_text_lbl = RichTextLabel.new()
	_text_lbl.bbcode_enabled = false
	_text_lbl.fit_content    = false
	_text_lbl.scroll_active  = false
	_text_lbl.custom_minimum_size = Vector2(0, 200)
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_lbl.add_theme_font_size_override("normal_font_size", 22)
	_text_lbl.add_theme_color_override("default_color", Color(0.92, 0.92, 0.88))
	centre.add_child(_text_lbl)

	_portrait_r     = _make_portrait("GHOST  [HQ]", CampaignData.CHARACTERS["hq"]["color"])
	_portrait_r_lbl = _portrait_r.get_child(0) as Label
	portrait_row.add_child(_portrait_r)

	# ── bottom controls ──────────────────────────────────────────────────────
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left   = 80
	bottom.offset_right  = -80
	bottom.offset_top    = -120
	bottom.offset_bottom = -40
	bottom.alignment     = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 24)
	add_child(bottom)

	_progress_lbl = Label.new()
	_progress_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_lbl.add_theme_font_size_override("font_size", 18)
	_progress_lbl.add_theme_color_override("font_color", Color(0.50, 0.70, 0.50))
	_progress_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_progress_lbl)

	_skip_btn = Button.new()
	_skip_btn.text = "SKIP BRIEFING"
	_skip_btn.add_theme_font_size_override("font_size", 18)
	_skip_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_skip_btn.pressed.connect(_on_skip)
	bottom.add_child(_skip_btn)

	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(260, 60)
	_continue_btn.add_theme_font_size_override("font_size", 22)
	_continue_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.43))
	_continue_btn.pressed.connect(_on_continue)
	bottom.add_child(_continue_btn)

func _make_portrait(char_name: String, accent: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(240, 360)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color     = accent.darkened(0.70)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = char_name
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", accent.lightened(0.35))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_bottom = -10
	p.add_child(lbl)

	# Decorative silhouette lines (ASCII-style person outline in label)
	var sil := Label.new()
	sil.text = "◆"
	sil.add_theme_font_size_override("font_size", 80)
	sil.add_theme_color_override("font_color", accent.lightened(0.10))
	sil.modulate.a = 0.22
	sil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sil.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	sil.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(sil)

	return p

func _apply_setup() -> void:
	if _title_lbl == null: return  # _build_ui not yet called
	_title_lbl.text = _title_str
	_sub_lbl.text   = _sub_str

	# Progress dots  e.g. "● ● ○ ○ ○"
	_progress_lbl.text = _mission_progress_str()

	# Continue button label
	if _is_pre:
		_continue_btn.text = "▶  DEPLOY"
	else:
		_continue_btn.text = "▶  CONTINUE" if _is_victory else "▶  FALL BACK"

	if _lines.size() > 0:
		_show_line(0)
	else:
		_on_complete.call()

# ── DIALOGUE ──────────────────────────────────────────────────────────────────

func _show_line(idx: int) -> void:
	if idx >= _lines.size():
		_continue_btn.text = _confirm_label()
		return
	_line_idx    = idx
	var line: Dictionary = _lines[idx]
	var speaker_key: String = str(line.get("speaker", "hq"))
	var char_data: Dictionary = CampaignData.CHARACTERS.get(speaker_key, CampaignData.CHARACTERS["hq"])

	_speaker_lbl.text = str(char_data.get("name", "UNKNOWN"))
	_speaker_lbl.add_theme_color_override("font_color", char_data.get("color", Color.WHITE))

	var is_left: bool = str(char_data.get("side", "right")) == "left"
	_portrait_l.modulate = Color(1, 1, 1, 1.0) if is_left  else Color(0.4, 0.4, 0.4, 0.55)
	_portrait_r.modulate = Color(1, 1, 1, 1.0) if not is_left else Color(0.4, 0.4, 0.4, 0.55)

	_full_text   = str(line.get("text", ""))
	_chars_shown = 0
	_typewriting = true
	_tw_timer    = 0.0
	_text_lbl.text = ""
	_continue_btn.text = "▶"  # indicate 'tap to skip typewriter'

func _process(delta: float) -> void:
	if not _typewriting: return
	_tw_timer += delta
	while _tw_timer >= _TW_SPEED and _chars_shown < _full_text.length():
		_tw_timer    -= _TW_SPEED
		_chars_shown += 1
		_text_lbl.text = _full_text.substr(0, _chars_shown)
	if _chars_shown >= _full_text.length():
		_typewriting = false
		# Determine whether more lines follow
		var more_lines: bool = (_line_idx + 1) < _lines.size()
		_continue_btn.text = "▶  NEXT" if more_lines else _confirm_label()

func _confirm_label() -> String:
	if _is_pre:
		return "▶  DEPLOY"
	return "▶  CONTINUE" if _is_victory else "▶  FALL BACK"

func _on_continue() -> void:
	if _typewriting:
		# Snap to full text first
		_typewriting   = false
		_chars_shown   = _full_text.length()
		_text_lbl.text = _full_text
		var more_lines: bool = (_line_idx + 1) < _lines.size()
		_continue_btn.text = "▶  NEXT" if more_lines else _confirm_label()
		return
	var next := _line_idx + 1
	if next < _lines.size():
		_show_line(next)
	else:
		_on_complete.call()

func _on_skip() -> void:
	_on_complete.call()

# ── HELPERS ───────────────────────────────────────────────────────────────────

func _mission_progress_str() -> String:
	if Campaign.prologue_done: return "PROLOGUE COMPLETE"
	var s := "MISSION  "
	var total := CampaignData.PROLOGUE_MISSIONS.size()
	for i in total:
		if i < Campaign.current_mission:
			s += "● "
		elif i == Campaign.current_mission:
			s += "◆ "
		else:
			s += "○ "
	return s.strip_edges()
