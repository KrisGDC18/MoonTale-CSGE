extends Node2D

@onready var intro_bgm:       = $intro_bgm
@onready var loop_bgm:        = $loop_bgm
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Globals.player_spawn_pos != Vector2.ZERO:
		position = Globals.player_spawn_pos
		Globals.player_spawn_pos = Vector2.ZERO
		
	if Globals.needs_fade_in:
		Globals.needs_fade_in = false
		_fade_in()
	# cargar las pistas de esta escena
	var intro = intro_bgm
	var loop  = loop_bgm
	# play() verifica si ya está sonando → no se reinicia al volver a la escena
	MusicManager.play(intro, loop)

	# si la escena no tiene intro:
	# MusicManager.play_loop_only(load("res://Audio/Music/pueblo_loop.ogg"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
