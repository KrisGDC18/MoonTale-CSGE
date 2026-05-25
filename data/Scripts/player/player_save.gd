# ═══════════════════════════════════════════════════════════════════════
# player_save.gd — Componente de guardado, carga y cámara
#
# ► Este es el script que debes asignar al nodo CharacterBody2D.
#
# Responsabilidades:
#   • Cargar partida con fade (continuar tras muerte)
#   • Aplicar i-frames al entrar a un mapa
#   • API de cámara (delegados a camera_controller.gd)
# ═══════════════════════════════════════════════════════════════════════
extends PlayerWater


# ═══════════════════════════════════════════════════════════════════════
# ─── Cambio de mapa ───────────────────────────────────────────────────

func _on_map_changed(map_name: String) -> void:
	if map_name == "":   # señal de descarga, ignorar
		return
	_apply_spawn_iframes.call_deferred()


func _apply_spawn_iframes() -> void:
	# Esperamos varios frames para que _restore_player_deferred del SaveSystem
	# haya terminado de restaurar el estado (incluye resetear _is_invincible).
	# TODO: reemplazar por una señal explícita de SaveSystem cuando esté disponible.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_is_invincible    = true
	_iframes_timer    = 0.5
	_flash_timer      = 0.0
	_iframes_drowning = false


# ═══════════════════════════════════════════════════════════════════════
# ─── Carga de partida con fade ────────────────────────────────────────

func _load_save_with_fade() -> void:
	Globals.playerStay     = true
	Globals.playerPlayable = false

	# Sacar al jugador del mapa para evitar daño durante el fade
	global_position = Vector2(-99999.0, -99999.0)
	velocity        = Vector2.ZERO
	visible         = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if not SaveSystem.load_completed.is_connected(_on_save_loaded):
		SaveSystem.load_completed.connect(_on_save_loaded, CONNECT_ONE_SHOT)

	var tween := camera.fade_to_black(0.6)
	tween.tween_callback(func():
		SaveSystem.load_game(SaveSystem.current_slot)
	)


func _on_save_loaded(_slot: int) -> void:
	# load_completed se emite antes de que _restore_player_deferred termine;
	# esperamos suficientes frames para que change_map y el restore acaben.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	animator.modulate = Color(1, 1, 1, 1)
	playerDead        = false
	_death_phase      = 0
	_is_invincible    = true
	_iframes_timer    = 0.5
	_flash_timer      = 0.0
	_iframes_drowning = false

	if weapon_manager != null and not weapon_manager._weapons.is_empty():
		weapon_manager._equip(weapon_manager._current_index, false)

	Globals.playerPlayable = true
	Globals.playerStay     = false

	camera.fade_from_black(0.5)


# ═══════════════════════════════════════════════════════════════════════
# ─── API de cámara ────────────────────────────────────────────────────

func camera_focus_on(target: Node2D, speed: float = 5.0) -> void:
	camera.focus_on(target, speed)


func camera_move_to(target_offset: Vector2, speed: float = 5.0) -> void:
	camera.move_to(target_offset, speed)


func camera_release() -> void:
	camera.release()
