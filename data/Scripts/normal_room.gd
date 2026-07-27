extends Node2D

@onready var intro_bgm : AudioStreamPlayer = $intro_bgm
@onready var loop_bgm  : AudioStreamPlayer = $loop_bgm

# Opcional: límites de cámara para esta sala. Si no los tocas, quedan
# en el rango por defecto de Godot (sin clamp).
@export var limit_left:   int = -10000000
@export var limit_top:    int = -10000000
@export var limit_right:  int = 10000000
@export var limit_bottom: int = 10000000


func _ready() -> void:
	if Globals.player_spawn_pos != Vector2.ZERO:
		position = Globals.player_spawn_pos
		Globals.player_spawn_pos = Vector2.ZERO

	_setup_camera()

	if Globals.needs_fade_in:
		Globals.needs_fade_in = false
		_fade_in()

	# cargar las pistas de esta escena
	var intro = intro_bgm
	var loop  = loop_bgm
	# play() verifica si ya está sonando → no se reinicia al volver a la escena
	AudioManager.play(intro, loop)

	# si la escena no tiene intro:
	# MusicManager.play_loop_only(load("res://Audio/Music/pueblo_loop.ogg"))


func _process(delta: float) -> void:
	pass


# Activa la cámara del jugador (la que sigue con scroll normal) y le
# aplica los límites de esta sala. Como el jugador ya trae su propio
# Camera2D, no hay que mover nada manualmente: solo hacerla "current".
func _setup_camera() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("normal_room: no se encontró el Player en el grupo 'player'.")
		return

	var cam: Camera2D = player.get_node("Camera2D")
	if cam == null:
		push_warning("normal_room: el Player no tiene un hijo Camera2D.")
		return

	cam.limit_left   = limit_left
	cam.limit_top    = limit_top
	cam.limit_right  = limit_right
	cam.limit_bottom = limit_bottom
	cam.position_smoothing_enabled = true
	cam.make_current()


func _fade_in() -> void:
	# buscar el overlay que dejó la puerta en el root
	# es el último CanvasLayer añadido al root
	var canvas: CanvasLayer = null
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer == 100:
			canvas = child
			break

	if canvas == null:
		return

	var overlay := canvas.get_child(0) as ColorRect

	# fade de negro a transparente
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.4)
	await tween.finished

	# limpiar el overlay una vez terminado el fade-in
	canvas.queue_free()
