extends Node

# Procedural audio — no asset files required.
# All sounds are synthesised from sine waves, noise and envelopes.

const RATE := 44100

var _cache: Dictionary = {}
var master_volume_db: float = 0.0
var _ambient_player: AudioStreamPlayer = null

func _ready() -> void:
	_load_volume()
	# Pre-generate everything so first combat has no stutter
	for s in ["shot_rifle","shot_mg","shot_sniper","explode","click","death","wave_alarm","victory","defeat","heal","capture","capture_lost","deploy","hq_alarm"]:
		_cache[s] = _gen(s)
	_start_ambient()

func _start_ambient() -> void:
	var samples := _gen_ambient()
	if samples.is_empty(): return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate      = float(RATE)
	gen.buffer_length = float(samples.size()) / float(RATE) + 0.1
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream    = gen
	_ambient_player.volume_db = -28.0 + master_volume_db
	get_tree().root.add_child(_ambient_player)
	_ambient_player.play()
	var pb := _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		for i in samples.size():
			pb.push_frame(Vector2(samples[i], samples[i]))
	# Loop by restarting when playback ends
	_ambient_player.finished.connect(func()->void: _restart_ambient())

func _restart_ambient() -> void:
	if not is_instance_valid(_ambient_player): return
	var pb := _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null: return
	var samples := _gen_ambient()
	for i in samples.size():
		pb.push_frame(Vector2(samples[i], samples[i]))
	_ambient_player.play()

func set_ambient_volume(db: float) -> void:
	if is_instance_valid(_ambient_player):
		_ambient_player.volume_db = clampf(db, -60.0, 0.0)

func set_master_volume(db: float) -> void:
	master_volume_db = clampf(db, -40.0, 0.0)
	if is_instance_valid(_ambient_player):
		_ambient_player.volume_db = -28.0 + master_volume_db
	_save_volume()

func _load_volume() -> void:
	if not FileAccess.file_exists("user://settings.json"): return
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f == null: return
	var j := JSON.new()
	if j.parse(f.get_as_text()) == OK:
		var d = j.get_data()
		if d is Dictionary:
			master_volume_db = clampf(float(d.get("volume_db", 0.0)), -40.0, 0.0)
	f.close()

func _save_volume() -> void:
	var existing: Dictionary = {}
	if FileAccess.file_exists("user://settings.json"):
		var rf := FileAccess.open("user://settings.json", FileAccess.READ)
		if rf != null:
			var j := JSON.new()
			if j.parse(rf.get_as_text()) == OK:
				var d = j.get_data()
				if d is Dictionary: existing = d
			rf.close()
	existing["volume_db"] = master_volume_db
	var wf := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if wf != null:
		wf.store_string(JSON.stringify(existing))
		wf.close()

# ── Public API ────────────────────────────────────────────────

func play(sound: String, vol_db: float = 0.0) -> void:
	if not _cache.has(sound):
		_cache[sound] = _gen(sound)
	_emit(_cache[sound], vol_db)

# ── Playback ──────────────────────────────────────────────────

func _emit(samples: PackedFloat32Array, vol_db: float) -> void:
	if samples.is_empty(): return
	var dur    := float(samples.size()) / float(RATE)
	var gen    := AudioStreamGenerator.new()
	gen.mix_rate     = float(RATE)
	gen.buffer_length = dur + 0.08
	var player := AudioStreamPlayer.new()
	player.stream    = gen
	player.volume_db = vol_db + master_volume_db
	# Add to root so scene switches don't cut off playing sounds
	get_tree().root.add_child(player)
	player.play()
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		for i in samples.size():
			pb.push_frame(Vector2(samples[i], samples[i]))
	get_tree().create_timer(dur + 0.18).timeout.connect(
		func() -> void: if is_instance_valid(player): player.queue_free())

# ── Dispatcher ────────────────────────────────────────────────

func _gen(sound: String) -> PackedFloat32Array:
	match sound:
		"shot_rifle":  return _rifle()
		"shot_mg":     return _mg_shot()
		"shot_sniper": return _sniper()
		"explode":     return _explosion()
		"click":       return _click()
		"death":       return _death_sfx()
		"wave_alarm":  return _alarm()
		"victory":       return _victory()
		"defeat":        return _defeat_sfx()
		"heal":          return _heal_sfx()
		"capture":       return _capture_sfx()
		"capture_lost":  return _capture_lost_sfx()
		"deploy":        return _deploy_sfx()
		"hq_alarm":      return _hq_alarm_sfx()
	return PackedFloat32Array()

# ── Sound generators ──────────────────────────────────────────

func _rifle() -> PackedFloat32Array:
	var n := int(RATE * 0.22)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var crack := sin(TAU * 1100.0 * t) * exp(-t * 115.0) * 0.75
		var noise := randf_range(-1.0, 1.0) * exp(-t * 20.0) * 0.55
		var boom  := sin(TAU * 90.0 * t)   * exp(-t * 14.0) * 0.35
		s[i] = clampf(crack + noise + boom, -1.0, 1.0)
	return s

func _mg_shot() -> PackedFloat32Array:
	var n := int(RATE * 0.14)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var crack := sin(TAU * 1400.0 * t) * exp(-t * 145.0) * 0.65
		var noise := randf_range(-1.0, 1.0) * exp(-t * 28.0) * 0.60
		var boom  := sin(TAU * 110.0 * t)  * exp(-t * 18.0) * 0.25
		s[i] = clampf(crack + noise + boom, -1.0, 1.0)
	return s

func _sniper() -> PackedFloat32Array:
	var n := int(RATE * 0.34)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var crack := sin(TAU * 900.0 * t)  * exp(-t * 80.0)  * 0.92
		var noise := randf_range(-1.0, 1.0) * exp(-t * 11.0) * 0.45
		var boom  := sin(TAU * 55.0 * t)   * exp(-t * 7.5)   * 0.58
		s[i] = clampf(crack + noise + boom, -1.0, 1.0)
	return s

func _explosion() -> PackedFloat32Array:
	var n := int(RATE * 0.62)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var noise := randf_range(-1.0, 1.0) * exp(-t * 7.0)  * 0.85
		var boom  := sin(TAU * 55.0 * t)   * exp(-t * 4.5)  * 0.72
		var mid   := sin(TAU * 190.0 * t)  * exp(-t * 14.0) * 0.35
		s[i] = clampf(noise + boom + mid, -1.0, 1.0)
	return s

func _click() -> PackedFloat32Array:
	var n := int(RATE * 0.046)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		s[i] = sin(TAU * 680.0 * t) * exp(-t * 90.0) * 0.45
	return s

func _death_sfx() -> PackedFloat32Array:
	var n := int(RATE * 0.30)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var freq  := maxf(400.0 - t * 900.0, 80.0)
		var noise := randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.40
		var tone  := sin(TAU * freq * t)    * exp(-t * 10.0) * 0.35
		s[i] = clampf(noise + tone, -1.0, 1.0)
	return s

func _alarm() -> PackedFloat32Array:
	var n := int(RATE * 1.1)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t    := float(i) / float(RATE)
		var freq: float = 880.0 if fmod(t, 0.28) < 0.14 else 660.0
		var env  := minf(t * 12.0, 1.0) * maxf(1.0 - maxf(t - 0.85, 0.0) * 5.0, 0.0)
		s[i] = sin(TAU * freq * t) * env * 0.55
	return s

func _victory() -> PackedFloat32Array:
	var notes := [261.6, 329.6, 392.0, 523.3, 659.3]
	var nd    := 0.32
	var n     := int(RATE * (float(notes.size()) * nd + 0.4))
	var s     := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t    := float(i) / float(RATE)
		var ni   := mini(int(t / nd), notes.size() - 1)
		var nt   := fmod(t, nd)
		var freq: float = float(notes[ni])
		var env  := minf(nt / 0.02, 1.0) * maxf(1.0 - maxf(nt - nd * 0.65, 0.0) / (nd * 0.35), 0.0)
		s[i] = clampf(sin(TAU * freq * t) * env * 0.50
		             + sin(TAU * freq * 2.0 * t) * env * 0.14, -1.0, 1.0)
	return s

func _defeat_sfx() -> PackedFloat32Array:
	var notes := [392.0, 329.6, 261.6, 220.0, 196.0]
	var nd    := 0.40
	var n     := int(RATE * (float(notes.size()) * nd + 0.5))
	var s     := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t    := float(i) / float(RATE)
		var ni   := mini(int(t / nd), notes.size() - 1)
		var nt   := fmod(t, nd)
		var freq: float = float(notes[ni])
		var env  := minf(nt / 0.03, 1.0) * maxf(1.0 - nt / nd, 0.0)
		s[i] = clampf(sin(TAU * freq * t)       * env * 0.45
		             + sin(TAU * freq * 0.5 * t) * env * 0.30, -1.0, 1.0)
	return s

func _heal_sfx() -> PackedFloat32Array:
	var n := int(RATE * 0.26)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t   := float(i) / float(RATE)
		var env := minf(t * 28.0, 1.0) * maxf(1.0 - t * 4.2, 0.0)
		s[i] = clampf(
			sin(TAU * 660.0 * t) * env * 0.40
		  + sin(TAU * 990.0 * t) * env * 0.22, -1.0, 1.0)
	return s

func _capture_sfx() -> PackedFloat32Array:
	var n := int(RATE * 0.50)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t   := float(i) / float(RATE)
		var env := minf(t * 18.0, 1.0) * maxf(1.0 - t * 2.2, 0.0)
		s[i] = clampf(
			sin(TAU * 523.0 * t) * env * 0.36
		  + sin(TAU * 659.0 * t) * env * minf(t * 14.0, 1.0) * 0.28
		  + sin(TAU * 784.0 * t) * env * minf(t * 22.0, 1.0) * 0.18, -1.0, 1.0)
	return s

func _capture_lost_sfx() -> PackedFloat32Array:
	var n := int(RATE * 0.48)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t    := float(i) / float(RATE)
		var env  := minf(t * 15.0, 1.0) * maxf(1.0 - t * 2.4, 0.0)
		var freq := maxf(784.0 - t * 820.0, 300.0)
		s[i] = clampf(sin(TAU * freq * t) * env * 0.46, -1.0, 1.0)
	return s

func _deploy_sfx() -> PackedFloat32Array:
	var n := int(RATE * 0.22)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t     := float(i) / float(RATE)
		var thud  := sin(TAU * 85.0 * t)   * exp(-t * 26.0) * 0.62
		var noise := randf_range(-1.0,1.0) * exp(-t * 20.0) * 0.32
		var tone  := sin(TAU * 430.0 * t)  * exp(-t * 42.0) * 0.26
		s[i] = clampf(thud + noise + tone, -1.0, 1.0)
	return s

func _gen_ambient() -> PackedFloat32Array:
	# ~8 seconds: low-frequency drone + slowly filtered wind noise
	var dur  := 8.0
	var n    := int(RATE * dur)
	var s    := PackedFloat32Array(); s.resize(n)
	# Simple one-pole low-pass filter state
	var lp: float = 0.0
	var alpha := 0.015   # cutoff ~200 Hz at 44100
	for i in n:
		var t    := float(i) / float(RATE)
		# Drone: two detuned low sines with slow beat
		var d1   := sin(TAU * 58.0 * t) * 0.18
		var d2   := sin(TAU * 61.7 * t) * 0.12
		# Wind noise: broadband filtered to low-mid
		var raw_noise := randf_range(-1.0, 1.0)
		lp = lp + alpha * (raw_noise - lp)
		var wind := lp * 0.22
		# Slow amplitude modulation simulating gusts
		var mod := 0.55 + 0.45 * sin(TAU * 0.08 * t + 1.2)
		s[i] = clampf((d1 + d2 + wind) * mod, -1.0, 1.0)
	return s

func _hq_alarm_sfx() -> PackedFloat32Array:
	var n := int(RATE * 0.38)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t  := float(i) / float(RATE)
		var b1 := sin(TAU * 1080.0 * t) * maxf(minf(t * 42.0, 1.0) * maxf(1.0-(t-0.01)*12.0, 0.0), 0.0)
		var t2 := maxf(t - 0.19, 0.0)
		var b2 := sin(TAU * 1080.0 * t) * maxf(minf(t2 * 42.0, 1.0) * maxf(1.0-(t2-0.01)*12.0, 0.0), 0.0)
		s[i] = clampf((b1 + b2) * 0.52, -1.0, 1.0)
	return s
