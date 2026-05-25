# ═══════════════════════════════════════════════════════════════════════
# player_animation.gd — Componente de animación y sonido
#
# Responsabilidades:
#   • Seleccionar y reproducir la animación correcta cada frame
#   • Acción de inspección (checking / question mark)
#   • Efectos de sonido de pasos, aterrizaje y techo
# ═══════════════════════════════════════════════════════════════════════
extends PlayerCombat
class_name PlayerAnimation


# ═══════════════════════════════════════════════════════════════════════
# ─── Acción de inspección ─────────────────────────────────────────────

func _handle_check_action() -> void:
	if _is_stayed():
		checking   = false
		hasChecked = false
		return

	if Input.is_action_just_pressed("Down") and currentDirection == 0 and is_on_floor():
		checking = true
	elif checking and (currentDirection != 0 or not is_on_floor()):
		checking   = false
		hasChecked = false

	if checking and not able_to_interact and not hasChecked:
		hasChecked = true
		if qMark:
			var mark = qMark.instantiate()
			mark.position = position
			get_tree().root.add_child(mark)


# ═══════════════════════════════════════════════════════════════════════
# ─── Animaciones ──────────────────────────────────────────────────────

func handle_animation(anim: String) -> void:
	if playerDead:
		return

	# ─── Bloqueado por diálogo ────────────────────────────────────────
	if _is_stayed():
		var idle := "CheckLeft" if lastDirection == 1 else "CheckRight"
		if _current_anim != idle:
			_current_anim = idle
			animator.play(idle)
		return

	# ─── Animación de inspección con LookUp ───────────────────────────
	if checking and (_current_anim.ends_with("Check") or _current_anim.ends_with("LookUp")):
		var base := "IdleLeft" if lastDirection == 1 else "IdleRight"
		if Input.is_action_pressed("Up"):
			_current_anim = base + "LookUp"
			animator.play(_current_anim)
		elif _current_anim.ends_with("LookUp"):
			checking      = false
			hasChecked    = false
			_current_anim = base
			animator.play(_current_anim)
		else:
			animator.play(_current_anim)
		return

	var input_dir := Input.get_axis("Left", "Right")

	# ─── En el aire ───────────────────────────────────────────────────
	if playerJump:
		anim = _get_air_anim()

	# ─── En el suelo ──────────────────────────────────────────────────
	else:
		anim = _get_ground_anim(input_dir)

	_current_anim = anim
	animator.play(anim)


func _get_air_anim() -> String:
	var jump_base := "JumpLeft" if lastDirection == 1 else "JumpRight"

	# Booster 1 y 2 comparten la misma lógica de animación
	if _booster1_active or _booster2_active:
		if Input.is_action_pressed("Up"):   return jump_base + "LookUp"
		if Input.is_action_pressed("Down"): return jump_base + "LookDown"
		return jump_base

	if _is_falling:
		var fall_base := "FallingLeft" if lastDirection == 1 else "FallingRight"
		if Input.is_action_pressed("Down"): return jump_base + "LookDown"
		if Input.is_action_pressed("Up"):   return jump_base + "LookUp"
		return fall_base

	# Salto normal
	if Input.is_action_pressed("Up"):   return jump_base + "LookUp"
	if Input.is_action_pressed("Down"): return jump_base + "LookDown"
	return jump_base


func _get_ground_anim(input_dir: float) -> String:
	var anim : String
	if lastDirection == 1:
		anim = "WalkLeft"  if input_dir < 0 else "IdleLeft"
	else:
		anim = "WalkRight" if input_dir > 0 else "IdleRight"

	if Input.is_action_pressed("Up"):
		return anim + "LookUp"
	if checking and is_on_floor() and not anim.begins_with("Walk"):
		return anim + "Check"
	if Input.is_action_pressed("Down") and not anim.begins_with("Walk"):
		return anim + "LookDown"
	return anim


# ═══════════════════════════════════════════════════════════════════════
# ─── Sonidos ──────────────────────────────────────────────────────────

func _handle_sounds(delta: float) -> void:
	var input_dir := Input.get_axis("Left", "Right")

	# Golpe en el techo
	if not _was_on_ceiling and is_on_ceiling():
		bonk_sfx.play()
	_was_on_ceiling = is_on_ceiling()

	# Aterrizaje
	if not _was_on_floor and is_on_floor():
		land_sfx.play()
		_step_timer = STEP_INTERVAL
	_was_on_floor = is_on_floor()

	# Pasos
	if is_on_floor() and input_dir != 0 and not checking:
		_step_timer -= delta
		if _step_timer <= 0.0:
			(water_sfx if inWater else step_sfx).play()
			_step_timer = STEP_INTERVAL
	else:
		_step_timer = STEP_INTERVAL
