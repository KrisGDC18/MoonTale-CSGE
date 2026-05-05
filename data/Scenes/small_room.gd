extends Node2D

func _ready():
	Globals.small_room = true   # activar al entrar a la escena
	if Globals.needs_fade_in:
		Globals.needs_fade_in = false
		_fade_in()

func _exit_tree():
	Globals.small_room = false  # limpiar al salir para no afectar la siguiente escena
	
	
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
