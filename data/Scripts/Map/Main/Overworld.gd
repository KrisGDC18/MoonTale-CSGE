extends Node2D
## Overworld.gd (v3 — layout visual + streaming por cámara)
##
## Flujo:
## 1. En el editor, arma el mapa completo instanciando cada pantalla como
##    hija de "Layout" y posicionándola donde corresponda — podés ver el
##    conjunto completo mientras diseñas, alinear bordes, etc.
## 2. En _ready() se "cosecha" esa disposición: por cada hija de Layout se
##    guarda su ruta de escena (scene_file_path), su posición, el
##    rectángulo real que ocupan sus TileMapLayer, y los nombres de sus
##    marcadores de spawn. Después esas instancias se destruyen — ya
##    cumplieron su función de referencia visual, viven solo como datos.
## 3. Cada frame se compara el rectángulo visible de la cámara actual
##    (+ un margen de precarga) contra los rectángulos registrados: lo
##    que entra se instancia de verdad dentro de "Screens"; lo que deja
##    de entrar, se libera.
##
## OJO — costo de arranque: como las pantallas están guardadas como hijas
## reales dentro de Overworld.tscn, Godot las instancia a TODAS al cargar
## la escena (para poder leerlas en _harvest_layout), aunque se liberen
## de inmediato. Con pocas pantallas no se nota; con un mundo enorme
## puede valer la pena "hornear" este registro en el editor en vez de
## calcularlo en cada entrada al overworld — avisame si llegás a ese punto.

@export var preload_margin: float = 64.0  ## píxeles extra alrededor de lo visible, para precargar antes de que se vea
@export var fade_out_time: float = 0.4    ## duración del desvanecido antes de destruir una pantalla
@export var music_fade_time: float = 0.6  ## duración del fundido de música al cambiar de zona

@onready var layout_root       : Node2D = $Layout    ## solo diseño: se vacía apenas arranca
@onready var screens_container : Node2D = $Screens   ## acá viven las instancias reales en runtime

class ScreenData:
	var scene_path      : String
	var position        : Vector2
	var rect            : Rect2
	var spawn_names     : Array[String] = []
	var background_path : String = ""
	var intro_bgm       : AudioStream = null
	var loop_bgm        : AudioStream = null

var _screens        : Array = []       # Array[ScreenData]
var _loaded         : Dictionary = {}  # ScreenData -> instancia (visible o desvaneciéndose)
var _fade_tweens    : Dictionary = {}  # ScreenData -> Tween (solo mientras se desvanece)
var _camera         : Camera2D = null
var _player         : Node2D = null
var _current_bg_path: String = ""
var _music_owner    : ScreenData = null   # qué pantalla puso la música que suena ahora

@onready var background_manager = $Backgrounds


func _ready() -> void:
	add_to_group("overworld")
	_harvest_layout()


func _process(_delta: float) -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
		if _camera == null:
			return  # todavía no hay cámara activa (ej. el Player no se terminó de armar)

	var view_rect := _get_camera_view_rect().grow(preload_margin)
	_update_streaming(view_rect)

	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		_update_zone(_player.global_position)


## Detecta en qué pantalla está parado el jugador y actualiza fondo y
## música según lo que esa pantalla declare.
func _update_zone(player_pos: Vector2) -> void:
	var current : ScreenData = null
	for data in _screens:
		if data.rect.has_point(player_pos):
			current = data
			break

	var bg_path : String = current.background_path if current else ""
	if bg_path != _current_bg_path:
		_current_bg_path = bg_path
		background_manager.set_background(bg_path)

	# la música solo cambia si la pantalla actual declara la suya propia
	# (intro_bgm/loop_bgm) — si no declara ninguna, se deja sonando lo
	# que ya estaba (para no cortar la música en cada pasillo sin música
	# propia). Solo se llama a Audiomanager cuando cambia de "dueño" de
	# la música, no en cada frame.
	if current and (current.intro_bgm or current.loop_bgm) and current != _music_owner:
		_music_owner = current
		AudioManager.play(current.intro_bgm, current.loop_bgm, music_fade_time)


func _get_camera_view_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var half_size := (viewport_size / _camera.zoom) / 2.0
	var center := _camera.get_screen_center_position()
	return Rect2(center - half_size, half_size * 2.0)


# ─── Cosecha del layout armado a mano en el editor ─────────────────────

func _harvest_layout() -> void:
	for child in layout_root.get_children():
		if child.scene_file_path == "":
			push_warning("Overworld: '%s' dentro de Layout no es una instancia de escena guardada, se ignora." % child.name)
			continue

		var data := ScreenData.new()
		data.scene_path = child.scene_file_path
		data.position   = child.position
		data.rect       = _measure_node_rect(child)

		for candidate in child.find_children("*", "Node2D", true, false):
			data.spawn_names.append(candidate.name)

		var bg_node := child.get_node_or_null("Background")
		if bg_node:
			if bg_node.scene_file_path == "":
				push_warning("Overworld: 'Background' dentro de '%s' no es una instancia de escena guardada, se ignora." % child.name)
			else:
				data.background_path = bg_node.scene_file_path

		var intro_node := child.get_node_or_null("intro_bgm")
		if intro_node and intro_node is AudioStreamPlayer:
			data.intro_bgm = intro_node.stream

		var loop_node := child.get_node_or_null("loop_bgm")
		if loop_node and loop_node is AudioStreamPlayer:
			data.loop_bgm = loop_node.stream

		_screens.append(data)

	# ya se extrajo todo lo necesario: destruir las instancias de editor
	for child in layout_root.get_children():
		layout_root.remove_child(child)
		child.free()


## Mide el rectángulo (en el espacio local de Overworld) que ocupan todos
## los TileMapLayer de un nodo, combinados.
func _measure_node_rect(node: Node2D) -> Rect2:
	var layers := node.find_children("*", "TileMapLayer", true, false)
	var total := Rect2()
	var first := true

	for layer in layers:
		var tm : TileMapLayer = layer
		if tm.tile_set == null:
			continue
		var used : Rect2i = tm.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size : Vector2 = tm.tile_set.tile_size
		var px_rect := Rect2(
			node.position + tm.position + Vector2(used.position) * tile_size,
			Vector2(used.size) * tile_size
		)
		if first:
			total = px_rect
			first = false
		else:
			total = total.merge(px_rect)

	if first:
		push_warning("Overworld: '%s' no tiene ningún TileMapLayer con tiles pintados." % node.name)
		return Rect2(node.position, Vector2.ZERO)

	return total


# ─── Streaming ──────────────────────────────────────────────────────────

func _update_streaming(view_rect: Rect2) -> void:
	for data in _screens:
		var should_be_loaded : bool = view_rect.intersects(data.rect)

		if should_be_loaded:
			if not _loaded.has(data):
				_load_screen(data)
			elif _fade_tweens.has(data):
				# volvió a entrar en cámara mientras se desvanecía: cancelar
				_cancel_fade_out(data)
		else:
			if _loaded.has(data) and not _fade_tweens.has(data):
				_start_fade_out(data)


func _load_screen(data) -> void:
	var packed : PackedScene = load(data.scene_path)
	var instance := packed.instantiate()
	instance.position = data.position
	instance.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# "Background" acá era solo una referencia declarativa (usada en
	# _harvest_layout para saber qué fondo le corresponde a este mapa).
	# El que se dibuja de verdad es el que administra
	# ParallaxBackgroundManager en $Backgrounds — si dejáramos este vivo,
	# cada pantalla streameada pintaría su propia copia encima, y con
	# varias pantallas vecinas cargadas a la vez (todas compartiendo
	# fondo) se apilan una sobre otra hasta tapar todo.
	var bg_node := instance.get_node_or_null("Background")
	if bg_node:
		bg_node.queue_free()

	screens_container.add_child(instance)
	_loaded[data] = instance
	print("Overworld: CARGA '%s' en %s" % [data.scene_path.get_file(), data.position])


## Inicia el desvanecido de una pantalla. La instancia SIGUE existiendo
## (y sigue en _loaded) durante la animación — solo se destruye de verdad
## al terminar, en _finish_unload(). Así, si el jugador vuelve antes de
## que termine, se puede cancelar sin crear una segunda copia duplicada.
func _start_fade_out(data) -> void:
	var instance : Node = _loaded[data]
	print("Overworld: desvaneciendo '%s'..." % data.scene_path.get_file())

	var tween := create_tween()
	tween.tween_property(instance, "modulate:a", 0.0, fade_out_time)
	tween.tween_callback(_finish_unload.bind(data))
	_fade_tweens[data] = tween


func _cancel_fade_out(data) -> void:
	var tween : Tween = _fade_tweens.get(data)
	if tween and tween.is_valid():
		tween.kill()
	_fade_tweens.erase(data)

	var instance : Node = _loaded.get(data)
	if instance:
		instance.modulate = Color(1.0, 1.0, 1.0, 1.0)
	print("Overworld: cancelado el desvanecido de '%s' (volvió a entrar en cámara)" % data.scene_path.get_file())


## Se llama automáticamente cuando el tween de fade termina. Acá sí se
## destruye la instancia de verdad.
func _finish_unload(data) -> void:
	_fade_tweens.erase(data)
	var instance : Node = _loaded.get(data)
	if instance:
		screens_container.remove_child(instance)
		instance.free()
	_loaded.erase(data)
	print("Overworld: DESCARGA '%s' en %s" % [data.scene_path.get_file(), data.position])


## Llamado por level.gd en vez de get_node_or_null()/find_child() directo.
## Si el spawn pedido vive en una pantalla que ya está cargada, lo
## devuelve. Si vive en una que todavía no entra en cámara, la carga
## ahora mismo (fuera de turno) para que el marcador exista a tiempo.
func get_spawn_point(spawn_name: String) -> Node:
	for data in _loaded:
		var point : Node = _loaded[data].find_child(spawn_name, true, false)
		if point:
			if _fade_tweens.has(data):
				_cancel_fade_out(data)
			return point

	for data in _screens:
		if spawn_name in data.spawn_names:
			if not _loaded.has(data):
				_load_screen(data)
			elif _fade_tweens.has(data):
				_cancel_fade_out(data)
			return _loaded[data].find_child(spawn_name, true, false)

	push_warning("Overworld: ningún registro declara el spawn '%s'." % spawn_name)
	return null
