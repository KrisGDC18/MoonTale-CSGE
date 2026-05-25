# ═══════════════════════════════════════════════════════════════════════
# player_movement.gd — Componente de movimiento
#
# Responsabilidades:
#   • Gravedad (normal, agua, booster)
#   • Salto (coyote time, jump buffer, jump cut)
#   • Booster 1.0 (hover / jetpack básico)
#   • Booster 2.0 (dash direccional)
#   • Movimiento horizontal
#   • Estado de dirección (move_state)
# ═══════════════════════════════════════════════════════════════════════
extends PlayerBase
class_name PlayerMovement


# ═══════════════════════════════════════════════════════════════════════
# ─── Estado de dirección ──────────────────────────────────────────────

func _update_move_state() -> void:
	if Input.is_action_pressed("Right"):
		lastDirection = 0
	elif Input.is_action_pressed("Left"):
		lastDirection = 1

	if _booster2_active and _booster2_locked_dir != 0:
		lastDirection = 1 if _booster2_locked_dir < 0 else 0

	playerJump = not is_on_floor()


# ═══════════════════════════════════════════════════════════════════════
# ─── Gravedad ─────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if inWater:
		velocity.y += GRAVITY_WATER * delta
		return

	if _booster1_active or _booster2_active:
		return

	if _is_jumping and Input.is_action_pressed("Jump") and velocity.y < 0:
		velocity.y += GRAVITY_UP * delta
	else:
		velocity.y += GRAVITY_DOWN * delta

	velocity.y = min(velocity.y, MAX_FALL_SPEED)


# ═══════════════════════════════════════════════════════════════════════
# ─── Coyote time y jump buffer ────────────────────────────────────────

func _update_coyote_time(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("Jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta
	else:
		_jump_buffer_timer = 0.0


# ═══════════════════════════════════════════════════════════════════════
# ─── Salto ────────────────────────────────────────────────────────────

func _handle_jump() -> void:
	if is_on_floor():
		_is_jumping = false
		_is_falling = false
		_air_time   = 0.0
		_reset_booster_state()

	if _is_stayed():
		return

	var can_jump       := is_on_floor() or (_coyote_timer > 0.0 and not _is_jumping)
	var jump_requested := Input.is_action_just_pressed("Jump") or _jump_buffer_timer > 0.0

	if jump_requested and can_jump:
		velocity.y         = -jump_speed()
		_is_jumping        = true
		_is_falling        = false
		_air_time          = 0.0
		_coyote_timer      = 0.0
		_jump_buffer_timer = 0.0
		_reset_booster_state()
		_jump_grace_frame  = true   # _reset_booster_state lo pone false; lo reactivamos aquí
		jump_sfx.play()
		return

	# ─── Jetpack ──────────────────────────────────────────────────────
	if not is_on_floor() and jetpack_equipped \
			and jetpack_gas > 0.0 and not _jump_grace_frame:

		if Input.is_action_just_pressed("Jump"):
			if jetpack_upgrade:
				_activate_booster2()
			else:
				_booster1_active = true
				_booster2_active = false
				velocity.y       = BOOSTER1_MAX_UP_SPEED

		if Input.is_action_just_released("Jump"):
			_booster1_active      = false
			_booster2_active      = false
			_booster2_locked_dir  = 0.0
			_booster2_locked_vert = BoostVert.NONE

	# ─── Jump cut (soltar el botón frena el salto) ─────────────────────
	if Input.is_action_just_released("Jump") and velocity.y < 0 \
			and _is_jumping and not _booster1_active and not _booster2_active:
		velocity.y *= JUMP_CUT_MULTIPLIER


func _activate_booster2() -> void:
	var input_dir  := Input.get_axis("Left", "Right")
	_booster2_locked_dir = input_dir
	_booster2_active     = true
	_booster1_active     = false

	if input_dir != 0.0:
		_booster2_locked_vert = BoostVert.NONE
		velocity.x = input_dir * BOOSTER2_SPEED_X
		velocity.y = 0.0
	elif Input.is_action_pressed("Down"):
		_booster2_locked_vert = BoostVert.DOWN
		velocity.x = 0.0
		velocity.y = 0.0
	else:
		_booster2_locked_vert = BoostVert.UP
		velocity.x = 0.0
		velocity.y = BOOSTER2_MAX_UP_SPEED


# ═══════════════════════════════════════════════════════════════════════
# ─── Booster 1.0 (hover) ──────────────────────────────────────────────

func _handle_booster1(delta: float) -> void:
	if not _booster1_active:
		if booster_sfx.playing:
			booster_sfx.stop()
		return

	if not booster_sfx.playing:
		booster_sfx.play()

	const HOVER_GRAVITY := 40.0
	velocity.y += HOVER_GRAVITY * delta
	velocity.y  = min(velocity.y, 20.0)

	jetpack_gas -= BOOSTER1_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster1_active = false
		_is_falling      = true
		booster_sfx.stop()


# ═══════════════════════════════════════════════════════════════════════
# ─── Booster 2.0 (dash direccional) ───────────────────────────────────

func _handle_booster2(delta: float) -> void:
	if not _booster2_active:
		if booster2_sfx.playing:
			booster2_sfx.stop()
		return

	if not booster2_sfx.playing:
		booster2_sfx.play()

	if _booster2_locked_dir != 0.0:
		velocity.x = _booster2_locked_dir * BOOSTER2_SPEED_X

	match _booster2_locked_vert:
		BoostVert.DOWN:
			velocity.x  = 0.0
			velocity.y += (GRAVITY_DOWN + BOOSTER2_DOWN_FORCE) * delta
			velocity.y  = min(velocity.y, MAX_FALL_SPEED)

		BoostVert.UP:
			if _booster2_locked_dir == 0.0:
				velocity.y = BOOSTER2_MAX_UP_SPEED
				var input_dir := Input.get_axis("Left", "Right")
				velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)
			else:
				var input_dir := Input.get_axis("Left", "Right")
				velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)

		_:
			var input_dir := Input.get_axis("Left", "Right")
			velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)

	# Anti-stall: si el jugador está empujado contra una pared, sube suavemente
	if _booster2_locked_dir != 0.0:
		if abs(global_position.x - _prev_position.x) < 0.5:
			velocity.y = move_toward(velocity.y, -80.0, 300.0 * delta)

	jetpack_gas -= BOOSTER2_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster2_active      = false
		_booster2_locked_dir  = 0.0
		_booster2_locked_vert = BoostVert.NONE
		_is_falling           = true
		booster2_sfx.stop()


# ═══════════════════════════════════════════════════════════════════════
# ─── Movimiento horizontal ────────────────────────────────────────────

func _handle_horizontal(delta: float) -> void:
	if _booster2_active:
		return

	if _is_stayed():
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		return

	var direction := Input.get_axis("Left", "Right")
	@warning_ignore("narrowing_conversion")
	currentDirection = direction

	var accel : float
	var fric  : float

	if inWater:
		accel = WATER_ACCR
		fric  = WATER_ACCR
	elif is_on_floor():
		accel = ACCR
		fric  = FRICTION
	else:
		accel = AIR_ACCR
		fric  = AIR_FRICTION

	var target_speed := WATER_MAX_SPEED if inWater else MAX_SPEED

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, fric * delta)


# ═══════════════════════════════════════════════════════════════════════
# ─── Animación de caída ───────────────────────────────────────────────

func _update_fall_anim(delta: float) -> void:
	if not is_on_floor():
		_air_time += delta
		if _air_time >= FALL_ANIM_TIME and velocity.y > 0:
			_is_falling = true
	else:
		_air_time   = 0.0
		_is_falling = false

	if _booster1_active or _booster2_active:
		_is_falling = false
