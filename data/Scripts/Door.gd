extends Sprite2D

var interactable   : bool = false
var _transitioning : bool = false

@export_file("*.tscn") var target_map : String = ""
@export var target_spawn                : String = ""
@export var next_music_intro  : AudioStream = null
@export var next_music_loop   : AudioStream = null

@onready var door_sfx = $door_sfx


func _ready():
	pass


@warning_ignore("unused_parameter")
func _process(delta):
	if Input.is_action_just_pressed("Down") and interactable and not _transitioning and !Globals.playerStay and player.is_on_floor():
		_transitioning = true
		_do_transition()


@warning_ignore("unused_parameter")
func _on_area_2d_area_entered(area):
	interactable = true


@warning_ignore("unused_parameter")
func _on_area_2d_area_exited(area):
	interactable = false


func _do_transition() -> void:
	if target_map.is_empty():
		push_warning("Door: no tiene target_map asignado.")
		_transitioning = false
		return

	var map : PackedScene = load(target_map)
	if map == null:
		push_warning("Door: no se pudo cargar la escena: " + target_map)
		_transitioning = false
		return
	var spawn  : String       = target_spawn
	var intro  : AudioStream  = next_music_intro
	var loop   : AudioStream  = next_music_loop
	var level                 = get_tree().get_first_node_in_group("level")

	if level == null:
		push_warning("Door: no se encontró el nodo Level en el grupo 'level'.")
		_transitioning = false
		return

	door_sfx.play()

	var canvas  := CanvasLayer.new()
	canvas.layer = 100
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	var tween := get_tree().root.create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.4)
	await tween.finished

	canvas.queue_free()

	Globals.needs_fade_in = true

	if intro != null or loop != null:
		AudioManager.play(intro, loop)

	level.change_map(map, spawn)

	_transitioning = false
