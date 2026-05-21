extends Node
# Centralised persistence for user://settings.json.
# Autoloaded as "Settings" — always initialised before Sounds (audio_mgr).

const _PATH := "user://settings.json"

var volume_db:     float = 0.0
var high_graphics: bool  = true

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(_PATH): return
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null: return
	var j := JSON.new()
	if j.parse(f.get_as_text()) == OK:
		var d = j.get_data()
		if d is Dictionary:
			volume_db     = clampf(float(d.get("volume_db",     0.0)), -40.0, 0.0)
			high_graphics = bool(d.get("high_graphics", true))
	f.close()

func save() -> void:
	var wf := FileAccess.open(_PATH, FileAccess.WRITE)
	if wf != null:
		wf.store_string(JSON.stringify({
			"volume_db":     volume_db,
			"high_graphics": high_graphics,
		}, "\t"))
		wf.close()

func set_volume_db(db: float) -> void:
	volume_db = clampf(db, -40.0, 0.0)
	save()

func set_high_graphics(on: bool) -> void:
	high_graphics = on
	save()
