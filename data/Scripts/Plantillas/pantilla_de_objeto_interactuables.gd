extends Sprite2D

var interactable     = false
var _transitioning   = false  # evita que se llame change_scene dos veces seguidas
							   # mientras el sonido y el fade están en curso

@export var next_scene_path: String
@export var pos_Change: Array
@export var next_music_intro : AudioStream = null  # intro de la zona destino (opcional)
@export var next_music_loop  : AudioStream = null  # loop de la zona destino (opcional)
@onready var door_sfx = $door_sfx  # sonido de la puerta al teletransportar


func _ready():
	pass


@warning_ignore("unused_parameter")
func _process(delta):
	# Si el jugador presiona "Down" estando en el área de este objeto,
	# se ejecuta el cambio de escena.
	# _transitioning evita que el input se procese mientras ya está en curso
	if Input.is_action_just_pressed("Down") and interactable and not _transitioning:
		_transitioning = true
	


@warning_ignore("unused_parameter")
func _on_area_2d_area_entered(area):
	interactable = true


@warning_ignore("unused_parameter")
func _on_area_2d_area_exited(area):
	interactable = false

	door_sfx.play()

	var canvas  := CanvasLayer.new()
	canvas.layer = 100
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	# CAMBIO: crear el tween desde el root en lugar de desde la puerta
	# la puerta puede ser liberada durante el cambio de escena
	# el root siempre existe y el tween no se invalida
	var tween := get_tree().root.create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.4)
	await tween.finished

	Globals.needs_fade_in = true

	if next_music_intro != null or next_music_loop != null:
		AudioManager.play(next_music_intro, next_music_loop)

	# CAMBIO: guardar la referencia al árbol ANTES del cambio de escena
	# después de change_scene_to_file get_tree() puede ser null en el nodo actual
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player")
	tree.change_scene_to_file(next_scene_path)
	player.position = Vector2(pos_Change[0], pos_Change[1])
