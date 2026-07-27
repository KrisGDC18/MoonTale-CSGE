extends Node2D
class_name ParallaxBackgroundManager
## Manejador de fondos parallax con transición suave (crossfade). No tiene
## ningún registro propio de biomas: cada escena de mapa define su propio
## fondo (un nodo hijo "Background" que es una instancia de una escena de
## Parallax2D), y el Overworld le pasa esa ruta directamente con
## set_background(). Si dos mapas comparten el mismo Background (misma
## ruta de escena), no se dispara ningún crossfade al pasar de uno a otro.

@export var fade_time: float = 0.8

var _current_path : String = ""
var _current      : Node = null   # fondo activo (o entrando)
var _outgoing     : Node = null   # fondo anterior, saliendo
var _tween        : Tween = null


## Llamar con la ruta (scene_file_path) de la escena de fondo que
## corresponde a donde está el jugador ahora. Pasar "" para "sin fondo".
func set_background(scene_path: String) -> void:
	if scene_path == _current_path:
		return
	_current_path = scene_path

	# si ya había una transición en curso, la corto: no queremos tres
	# fondos superpuestos si el jugador cambia de zona muy rápido
	if _tween and _tween.is_valid():
		_tween.kill()
	if _outgoing:
		_outgoing.free()
		_outgoing = null

	var new_instance : Node = null
	if scene_path != "":
		var packed : PackedScene = load(scene_path)
		new_instance = packed.instantiate()
		new_instance.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(new_instance)

	_outgoing = _current
	_current  = new_instance

	_tween = create_tween()
	_tween.set_parallel(true)
	if _current:
		_tween.tween_property(_current, "modulate:a", 1.0, fade_time)
	if _outgoing:
		_tween.tween_property(_outgoing, "modulate:a", 0.0, fade_time)
	_tween.chain().tween_callback(_clear_outgoing)


func _clear_outgoing() -> void:
	if _outgoing:
		_outgoing.free()
	_outgoing = null
