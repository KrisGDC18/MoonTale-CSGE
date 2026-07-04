extends Node2D

@onready var intro_bgm    : AudioStreamPlayer = $intro_bgm
@onready var loop_bgm     : AudioStreamPlayer = $loop_bgm


func _ready():
	Globals.small_room = true   # activar al entrar a la escena

	_setup_camera()

	if Globals.needs_fade_in:
		Globals.needs_fade_in = false
		_fade_in()

	var intro = intro_bgm
	var loop  = loop_bgm
	# play() verifica si ya está sonando → no se reinicia al volver a la escena
	Audiomanager.play(intro, loop)

	# si la escena no tiene intro:
	# MusicManager.play_loop_only(load("res://Audio/Music/pueblo_loop.ogg"))


func _exit_tree():
	Globals.small_room = false  # limpiar al salir para no afectar la siguiente escena


# Crea una cámara fija en (0,0) mundial, hija de esta misma sala.
# Al no estar apegada al Player ni moverse, la vista queda estática
# aunque el jugador camine dentro de la habitación. Como es hija de
# la sala, se destruye sola cuando la escena se libera al salir.
func _setup_camera() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.position = Vector2.ZERO
	cam.position_smoothing_enabled = false
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
