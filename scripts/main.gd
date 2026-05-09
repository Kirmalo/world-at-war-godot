extends Node

var globe_scene      := preload("res://scenes/globe.tscn")
var generation_scene := preload("res://scenes/generation.tscn")
var game_scene       := preload("res://scenes/game.tscn")

var _current: Node = null
@onready var _fade: ColorRect = $FadeLayer/FadeRect

# Shared state passed between screens
var active_lat:   float  = 40.7128
var active_lon:   float  = -74.006
var active_name:  String = "New York, NY"
var ai_tile_grid:   Array  = []
var using_ai_map:   bool   = false
var sat_image_data: PackedByteArray = PackedByteArray()
var osm_roads:      Array  = []
var osm_buildings:  Array  = []

func _ready() -> void:
	_fade.color.a = 1.0   # Start fully black; _do_transition fades in
	show_globe()

func show_globe()      -> void: _do_transition(globe_scene.instantiate())
func show_generation() -> void: _do_transition(generation_scene.instantiate())
func show_game()       -> void: _do_transition(game_scene.instantiate())

func _do_transition(node: Node) -> void:
	# Fade to black if not already there
	if _fade.color.a < 0.95:
		_fade.visible = true
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.32)
		await t.finished
	_switch_to(node)
	# Fade back in
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.42)
	await t.finished
	_fade.visible = false

func _switch_to(node: Node) -> void:
	if _current:
		_current.queue_free()
	_current = node
	add_child(_current)
