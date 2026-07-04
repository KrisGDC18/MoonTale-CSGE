## level.gd
## Gestiona qué mapa está activo. Solo existe un mapa a la vez.
extends Node

signal map_changed(map_name: String)

## Mapa inicial para partidas nuevas. Asígnalo en el Inspector de Game.tscn.
@export var start_map : PackedScene

var _current_map  : Node = null


func _ready() -> void:
	add_to_group("level")
	# Conectar con TitleScreen para saber cuándo iniciar/cargar partida
	var title := get_tree().get_first_node_in_group("title_screen")
	if title and title.has_signal("game_started"):
		title.game_started.connect(_on_game_started)


# ── Señal de TitleScreen ───────────────────────────────────────────────

func _on_game_started(slot: int, is_new: bool) -> void:
	if is_new:
		# Nuevo juego: cargar el mapa inicial y posicionar en SpawnStart
		if start_map:
			_load_map(start_map, "SpawnStart")
		else:
			push_error("[Level] start_map no asignado en el Inspector.")
	# Si is_new == false, SaveSystem.load_game() ya llamó change_map() internamente


# ── API pública ────────────────────────────────────────────────────────

func change_map(map_scene: PackedScene, spawn_point: String = "") -> void:
	_unload_current()
	await get_tree().process_frame
	_load_map(map_scene, spawn_point)


# ── Privado ────────────────────────────────────────────────────────────

func _unload_current() -> void:
	if _current_map == null:
		return
	emit_signal("map_changed", "")  # avisa a las balas que se destruyan antes del cambio
	_current_map.queue_free()
	_current_map = null


func _load_map(map_scene: PackedScene, spawn_point: String) -> void:
	var fresh_scene : PackedScene = ResourceLoader.load(map_scene.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_current_map = fresh_scene.instantiate()
	add_child(_current_map)

	if spawn_point != "":
		var point : Node = null
		if _current_map.has_method("get_spawn_point"):
			# el mapa sabe resolver spawns que aún no están cargados
			# (ej. Overworld con streaming de pantallas)
			point = _current_map.get_spawn_point(spawn_point)
		else:
			point = _current_map.find_child(spawn_point, true, false)

		if point:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				player.global_position = point.global_position
		else:
			push_warning("SpawnPoint '%s' no encontrado en el mapa." % spawn_point)

	emit_signal("map_changed", _current_map.name)

	if Globals.needs_fade_in:
		Globals.needs_fade_in = false
		_do_fade_in()


func _do_fade_in() -> void:
	var canvas  := CanvasLayer.new()
	canvas.layer = 100
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	var tween := get_tree().root.create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.4)
	await tween.finished

	canvas.queue_free()
