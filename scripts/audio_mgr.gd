extends Node

# Procedural audio — no asset files required.
# All sounds are synthesised from sine waves, noise and envelopes.

const RATE := 44100

var _cache: Dictionary = {}

func _ready() -> void:
	# Pre-generate everything so first combat has no stutter
	for s in ["shot_rifle","shot_mg","shot_sniper","explode","click","death","wave_alarm","victory","defeat"]:
		_cache[s] = _gen(s)

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
	player.volume_db = vol_db
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
		"victory":     return _victory()
		"defeat":      return _defeat_sfx()
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
