extends CharacterBody2D

@export var qMark: PackedScene
@export var dmg: Area2D
@export var damage_material: ShaderMaterial

# ─── Velocidad y aceleración en el suelo ─────────────────────────────
const MAX_SPEED           := 190.0
const JUMP_VELOCITY       := 295.0
const ACCR                := 1200.0
const FRICTION            := 1000.0

# ─── Velocidad y aceleración en el aire ──────────────────────────────
const AIR_ACCR            := 380.0
const AIR_FRICTION        := 180.0

# ─── Movimiento en agua ───────────────────────────────────────────────
const WATER_MAX_SPEED     := 80.0
const WATER_JUMP_VELOCITY := 140.0
const WATER_ACCR          := 300.0
const AIR_MAX             := 100.0
const AIR_TICK            := 0.075
const AIR_DMG_INTERVAL    := 0.5

# ─── Gravedad ─────────────────────────────────────────────────────────
const GRAVITY_UP          := 450.0
const GRAVITY_DOWN        := 980.0
const GRAVITY_WATER       := 200.0
const MAX_FALL_SPEED      := 700.0

# ─── Salto variable ───────────────────────────────────────────────────
const JUMP_CUT_MULTIPLIER := 0.35

# ─── Coyote Time ──────────────────────────────────────────────────────
const COYOTE_TIME         := 0.083

# ─── Jump Buffer ──────────────────────────────────────────────────────
const JUMP_BUFFER_TIME    := 0.05

# ─── Knockback ────────────────────────────────────────────────────────
const KNOCKBACK_SPEED_X   := 100.0
const KNOCKBACK_SPEED_Y   := 180.0
const KNOCKBACK_DURATION  := 0.4

# ─── I-frames ─────────────────────────────────────────────────────────
const IFRAMES_DURATION    := 1.25
const IFRAMES_FLASH_RATE  := 0.07

# ─── Booster 1.0 ──────────────────────────────────────────────────────
# jetpack de elevación vertical:
#   - se activa con just_pressed Jump en el aire (nunca al saltar)
#   - aplica fuerza hacia arriba gradualmente mientras mantienes Jump
#   - la gravedad se aplica reducida (BOOSTER1_GRAVITY_REDUCED) para
#     dar sensación de jetpack — no flotación completa ni caída libre
#   - el gas se recarga INMEDIATAMENTE al tocar el suelo
#   - la altura máxima es equivalente a Cave Story
# para equipar: player.jetpack_equipped = true
# para quitar:  player.jetpack_equipped = false
const BOOSTER1_LIFT_FORCE     := 200.0  # fuerza de elevación por segundo
										 # más baja que antes para altura correcta
const BOOSTER1_GRAVITY_REDUCED:= 600.0  # gravedad reducida mientras el booster está activo
										 # GRAVITY_DOWN(980) - 300 = empuje neto de 680
										 # da la sensación de jetpack sin flotar
const BOOSTER1_MAX_UP_SPEED   := -280.0  # más alto que antes (-120) para ganar más altura velocidad máxima hacia arriba del booster 1.0
										 # limita la altura para que cuadre con CS
const BOOSTER1_GAS_DRAIN      := 60.0   # gas por segundo — dura ~1.6s con gas lleno
const BOOSTER_GAS_MAX         := 100.0  # gas máximo compartido entre ambos boosters

# ─── Booster 2.0 ──────────────────────────────────────────────────────
# vuelo direccional al estilo Cave Story:
#   - se activa con just_pressed Jump en el aire
#   - al activar fija la dirección horizontal hasta que sueltes Jump
#   - la dirección fijada NO puede cambiarse mientras mantienes Jump
#   - al soltar y volver a presionar puedes cambiar la dirección
#   - la gravedad se aplica reducida para dar sensación de vuelo controlado
#   - Down acelera la caída durante el vuelo
#   - el gas se recarga INMEDIATAMENTE al tocar el suelo
# para equipar: player.jetpack_equipped = true + player.jetpack_upgrade = true
const BOOSTER2_SPEED_X := 350.0  # antes 190.0
const BOOSTER2_GRAVITY_REDUCED := 880.0
const BOOSTER2_MAX_UP_SPEED    := -80.0
const BOOSTER2_DOWN_FORCE      := 400.0
const BOOSTER2_GAS_DRAIN       := 100.0  # antes 50.0 — se acaba más rápido como CS

# ─── Recarga de gas ───────────────────────────────────────────────────
# el gas se recarga INMEDIATAMENTE al tocar el suelo (no gradualmente)
# esto es exactamente como Cave Story — al aterrizar tienes gas lleno
# para recargar manualmente: player.jetpack_gas = player.BOOSTER_GAS_MAX

# ─── Animación de caída ───────────────────────────────────────────────
const FALL_ANIM_TIME      := 0.35

# ─── Cámara ───────────────────────────────────────────────────────────
# API pública:
#   player.camera_focus_on(nodo)     → seguir un nodo
#   player.camera_move_to(offset)    → desplazar la vista
#   player.camera_release()          → volver al seguimiento normal
#   player.cam_quake = true/false    → activar/apagar temblor
#   player.cam_quake_intensity = N   → intensidad del temblor
const CAM_H_LEAD          := 48.0
const CAM_V_LOOK_UP       := 64.0
const CAM_H_LERP          := 4.0
const CAM_V_LERP          := 3.0
const CAM_LOOK_LERP       := 2.5
const CAM_OVERRIDE_LERP   := 5.0

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var animator        = $AnimatedSprite2D
@onready var camera          = $Camera2D
@onready var jump_sfx        : AudioStreamPlayer = $jump_sfx
@onready var step_sfx        : AudioStreamPlayer = $step_sfx
@onready var land_sfx        : AudioStreamPlayer = $land_sfx
@onready var water_sfx       : AudioStreamPlayer = $water_sfx
@onready var bonk_sfx        : AudioStreamPlayer = $bonk_sfx
@onready var hurt_sfx        : AudioStreamPlayer = $hurt_sfx
@onready var death_sfx       : AudioStreamPlayer = $death_sfx
@onready var death_drown_sfx : AudioStreamPlayer = $death_drown_sfx
@onready var booster_sfx     : AudioStreamPlayer = $booster_sfx
@onready var booster2_sfx    : AudioStreamPlayer = $booster2_sfx

# ─── Variables de booster ─────────────────────────────────────────────
var jetpack_equipped    : bool  = true
var jetpack_upgrade     : bool  = true
var jetpack_gas         : float = BOOSTER_GAS_MAX
var jetpack_gas_max     : float = BOOSTER_GAS_MAX
var _booster1_active    : bool  = false
var _booster2_active    : bool  = false

# dirección fijada del booster 2.0 al activarse
# no puede cambiarse hasta soltar Jump — igual que Cave Story
# 0 = sin dirección fijada, -1 = izquierda, 1 = derecha
var _booster2_locked_dir : float = 0.0

# evita que el booster se active el mismo frame del salto
# true al saltar → false un frame después
var _jump_grace_frame   : bool  = false

# ─── Variables de animación ───────────────────────────────────────────
var _air_time           : float = 0.0
var _is_falling         : bool  = false
var _current_anim       : String = "IdleRight"

# ─── Variables de vida y daño ─────────────────────────────────────────
const PLAYER_MAX_LIFE   : int   = 12
var currentLife         := PLAYER_MAX_LIFE
var _knockback_timer    := 0.0
var _iframes_timer      := 0.0
var _flash_timer        := 0.0
var _is_invincible      := false
var canContinue         := false
var playerDead          := false

# ─── Variables de movimiento ──────────────────────────────────────────
var currentGravity      := GRAVITY_DOWN
var allowMovement       := true
var wamder              := false
var checking            := false
var able_to_interact    := false
var hasChecked          := false
var currentDirection    := 0
var lastDirection       := 0
var playerJump          := false
var _is_jumping         := false
var _coyote_timer       := 0.0
var _jump_buffer_timer  := 0.0

# ─── Variables de agua ────────────────────────────────────────────────
var airSupply           : float = AIR_MAX
var _air_tick_timer     : float = 0.0
var _air_dmg_timer      : float = 0.0
var infiniteAir         : bool  = false

# ─── Variables de sonido ──────────────────────────────────────────────
var _was_on_floor       := true
var _was_on_ceiling     := false
var _step_timer         := 0.0
const STEP_INTERVAL      := 0.28

# ─── Variables de cámara ──────────────────────────────────────────────
var _cam_offset           := Vector2.ZERO
var _cam_target           := Vector2.ZERO
var _cam_small_room       := false
var _cam_override_active  := false
var _cam_override_target  := Vector2.ZERO
var _cam_override_speed   := CAM_OVERRIDE_LERP
var _cam_focus_node       : Node2D = null
var cam_quake             := false
var cam_quake_intensity   := 4.0
var cam_quake_speed       := 22.0
var _quake_offset         := Vector2.ZERO
var _quake_time           := 0.0


# ═══════════════════════════════════════════════════════════════════════
func _ready():
	add_to_group("player")
	dmg.body_entered.connect(_on_damage_detect_body_entered)
	camera.anchor_mode                = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.offset                     = Vector2.ZERO
	camera.position_smoothing_enabled = false


# ═══════════════════════════════════════════════════════════════════════
func _physics_process(delta):
	if Globals.playerPlayable == false:
		return

	if playerDead:
		if canContinue:
			playerDead           = false
			canContinue          = false
			_is_invincible       = false
			currentLife          = PLAYER_MAX_LIFE
			animator.modulate    = Color(1.0, 1.0, 1.0, 1.0)
			airSupply            = AIR_MAX
			jetpack_gas          = BOOSTER_GAS_MAX
			_booster1_active     = false
			_booster2_active     = false
			_booster2_locked_dir = 0.0
			_jump_grace_frame    = false
			_is_falling          = false
			_air_time            = 0.0
		return

	var anim = "IdleRight"

	_update_coyote_time(delta)    # 1. coyote time
	_update_jump_buffer(delta)    # 2. jump buffer

	# 3. gravedad:
	#   - booster 1.0 activo → gravedad reducida (sensación de jetpack)
	#   - booster 2.0 activo → gravedad reducida (casi flota)
	#   - ningún booster     → gravedad normal completa
	_apply_gravity(delta)

	_update_fall_anim(delta)      # 4. animación de caída

	if _knockback_timer > 0.0:
		_knockback_timer     -= delta
		_booster1_active      = false
		_booster2_active      = false
		_booster2_locked_dir  = 0.0
		_jump_grace_frame     = false
		if booster_sfx.playing:  booster_sfx.stop()
		if booster2_sfx.playing: booster2_sfx.stop()
	else:
		_handle_jump()              # 5. salto y activación de boosters
		_handle_booster1(delta)     # 6. física del booster 1.0
		_handle_booster2(delta)     # 7. física del booster 2.0
		_handle_horizontal(delta)   # 8. movimiento horizontal

	_update_air_supply(delta)    # 9. aire bajo el agua
	move_and_slide()             # 10. mover y detectar colisiones

	# 11. recarga inmediata de gas al tocar el suelo
	# se hace DESPUÉS de move_and_slide para que is_on_floor() sea correcto
	# en Cave Story el gas se recarga al instante al aterrizar — no gradualmente
	if is_on_floor() and jetpack_equipped:
		jetpack_gas          = BOOSTER_GAS_MAX
		_booster2_locked_dir = 0.0  # liberar dirección fijada al aterrizar

	_handle_check_action()       # 12. agacharse e inspeccionar
	handle_animation(anim)       # 13. animación
	_handle_sounds(delta)        # 14. sonidos
	_update_iframes(delta)       # 15. i-frames con tinte rojo
	_update_camera(delta)        # 16. cámara

	# apagar grace frame al final del frame
	if _jump_grace_frame:
		_jump_grace_frame = false


# ═══════════════════════════════════════════════════════════════════════
# ─── Gravedad ─────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if wamder:
		velocity.y += GRAVITY_WATER * delta
		return

	# si cualquier booster está activo, él gestiona su vertical — aquí no tocar nada
	if _booster1_active or _booster2_active:
		return

	if _is_jumping and Input.is_action_pressed("Jump") and velocity.y < 0:
		velocity.y += GRAVITY_UP * delta
	else:
		velocity.y += GRAVITY_DOWN * delta

	velocity.y = min(velocity.y, MAX_FALL_SPEED)


func _handle_jump() -> void:
	if is_on_floor():
		_is_jumping          = false
		_is_falling          = false
		_air_time            = 0.0
		_booster1_active     = false
		_booster2_active     = false
		_booster2_locked_dir = 0.0
		_jump_grace_frame    = false

	var can_jump       := is_on_floor() or (_coyote_timer > 0.0 and not _is_jumping)
	var jump_requested := Input.is_action_just_pressed("Jump") or _jump_buffer_timer > 0.0

	# ── Salto normal ──────────────────────────────────────────────────
	if jump_requested and can_jump:
		velocity.y           = -jump_speed()
		_is_jumping          = true
		_is_falling          = false
		_air_time            = 0.0
		_coyote_timer        = 0.0
		_jump_buffer_timer   = 0.0
		_booster1_active     = false
		_booster2_active     = false
		_booster2_locked_dir = 0.0
		_jump_grace_frame    = true
		jump_sfx.play()
		return

	# ── Boosters: solo en el aire, con gas, sin grace frame ───────────
	if not is_on_floor() and jetpack_equipped \
			and jetpack_gas > 0.0 and not _jump_grace_frame:

		if Input.is_action_just_pressed("Jump"):
			if jetpack_upgrade:
				# ── Activar Booster 2.0 ───────────────────────────────
				var input_dir := Input.get_axis("Left", "Right")
				var locked : float = input_dir

				_booster2_locked_dir = locked
				_booster2_active     = true
				_booster1_active     = false

				if locked != 0.0:
					velocity.x =  locked * BOOSTER2_SPEED_X
					velocity.y = -150.0
				else:
					velocity.x = 0.0
					velocity.y = -200.0

			else:
				# ── Activar Booster 1.0 ───────────────────────────────
				_booster1_active = true
				_booster2_active = false
				velocity.y       = BOOSTER1_MAX_UP_SPEED

		# soltar Jump desactiva el booster activo
		if Input.is_action_just_released("Jump"):
			_booster1_active     = false
			_booster2_active     = false
			_booster2_locked_dir = 0.0

	# corte de salto normal — solo si ningún booster está activo
	if Input.is_action_just_released("Jump") and velocity.y < 0 \
			and _is_jumping and not _booster1_active and not _booster2_active:
		velocity.y *= JUMP_CUT_MULTIPLIER


func _handle_booster1(delta: float) -> void:
	if not _booster1_active:
		if booster_sfx.playing:
			booster_sfx.stop()
		return

	if not booster_sfx.playing:
		booster_sfx.play()

	# gravedad muy baja para no frenar el impulso inicial
	# el jugador sube rápido al principio y luego flota levemente
	var BOOSTER1_HOVER_GRAVITY := 40.0   # antes 120.0 — demasiado frenante
	velocity.y += BOOSTER1_HOVER_GRAVITY * delta
	velocity.y  = min(velocity.y, 20.0)

	jetpack_gas -= BOOSTER1_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster1_active = false
		_is_falling      = true
		booster_sfx.stop()


func _handle_booster2(delta: float) -> void:
	if not _booster2_active:
		if booster2_sfx.playing:
			booster2_sfx.stop()
		return

	if not booster2_sfx.playing:
		booster2_sfx.play()

	# ── Horizontal ────────────────────────────────────────────────────
	if _booster2_locked_dir != 0.0:
		# dirección fijada: mantener velocidad horizontal constante
		velocity.x = _booster2_locked_dir * BOOSTER2_SPEED_X
	# si locked_dir es 0.0 (vertical puro) no tocar velocity.x

	# ── Vertical ──────────────────────────────────────────────────────
	if Input.is_action_pressed("Down"):
		# Down → caída recta hacia abajo
		# resetear horizontal para que sea completamente recto
		velocity.x  = 0.0
		velocity.y += (GRAVITY_DOWN + BOOSTER2_DOWN_FORCE) * delta
		velocity.y  = min(velocity.y, MAX_FALL_SPEED)
	elif _booster2_locked_dir != 0.0:
		# impulso horizontal activo → subida leve y constante
		velocity.y = -60.0
	else:
		# vertical puro → subida fuerte constante
		velocity.y = -150.0

	# consumir gas
	jetpack_gas -= BOOSTER2_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster2_active     = false
		_booster2_locked_dir = 0.0
		_is_falling          = true
		booster2_sfx.stop()


# ═══════════════════════════════════════════════════════════════════════
# ─── Salto y boosters ─────────────────────────────────────────────────





# ═══════════════════════════════════════════════════════════════════════
# ─── Movimiento horizontal ────────────────────────────────────────────

func _handle_horizontal(delta: float) -> void:
	# durante el booster 2.0 la dirección la controla _handle_booster2
	if _booster2_active:
		return

	var direction = Input.get_axis("Left", "Right")
	@warning_ignore("narrowing_conversion")
	currentDirection = direction

	var accel : float
	var fric  : float

	if wamder:
		accel = WATER_ACCR
		fric  = WATER_ACCR
	elif is_on_floor():
		accel = ACCR
		fric  = FRICTION
	else:
		accel = AIR_ACCR
		fric  = AIR_FRICTION

	var target_speed := WATER_MAX_SPEED if wamder else MAX_SPEED

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, fric * delta)


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


# ═══════════════════════════════════════════════════════════════════════
# ─── Motor de daño ────────────────────────────────────────────────────

func take_damage(amount: int, source_global_pos: Vector2,
				 ignore_iframes: bool = false, apply_knockback: bool = true,
				 is_drowning: bool = false) -> void:
	if (not ignore_iframes and _is_invincible) or playerDead:
		return

	currentLife = max(currentLife - amount, 0)
	hurt_sfx.play()

	# descomenta si tienes WeaponManager:
	# var active_id := WeaponManager.get_active_weapon_id()
	# if active_id != "": WeaponManager.lose_exp(active_id, 10)

	# descomenta si tienes HealSystem:
	# HealSystem.cancel_gradual()

	if currentLife <= 0:
		_die(is_drowning)
	else:
		if apply_knockback:
			_apply_knockback(source_global_pos)
		if is_drowning:
			_is_invincible = true
			_iframes_timer = AIR_DMG_INTERVAL
			_flash_timer   = 0.0


func _die(is_drowning: bool = false) -> void:
	if playerDead:
		return

	playerDead           = true
	_is_invincible       = true
	velocity             = Vector2.ZERO
	_knockback_timer     = 0.0
	_booster1_active     = false
	_booster2_active     = false
	_booster2_locked_dir = 0.0
	_jump_grace_frame    = false
	if booster_sfx.playing:  booster_sfx.stop()
	if booster2_sfx.playing: booster2_sfx.stop()

	if is_drowning:
		var idle_anim := "IdleLeft" if lastDirection == 1 else "IdleRight"
		animator.play(idle_anim)
		animator.modulate = Color(0.35, 0.55, 1.0, 1.0)
		death_drown_sfx.play()
	else:
		death_sfx.play()
		animator.modulate.a = 0.0

	print("jugador muerto")


func _apply_knockback(source_global_pos: Vector2) -> void:
	var knock_dir : float = signf(global_position.x - source_global_pos.x)
	if knock_dir == 0:
		knock_dir = -1 if lastDirection == 1 else 1

	velocity.x           = knock_dir * KNOCKBACK_SPEED_X
	velocity.y           = -KNOCKBACK_SPEED_Y
	_knockback_timer     = KNOCKBACK_DURATION
	_is_invincible       = true
	_iframes_timer       = IFRAMES_DURATION
	_flash_timer         = 0.0
	checking             = false
	hasChecked           = false


func _update_iframes(delta: float) -> void:
	if not _is_invincible:
		# fuera de i-frames: restaurar color completamente
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	_iframes_timer -= delta

	if _iframes_timer <= 0.0:
		_is_invincible    = false
		_iframes_timer    = 0.0
		_flash_timer      = 0.0
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	# parpadeo con tinte rojo al estilo Cave Story
	# frame visible   → tinte rojo (1, 0.3, 0.3, 1)
	# frame invisible → transparente (1, 1, 1, 0)
	_flash_timer += delta
	if _flash_timer >= IFRAMES_FLASH_RATE:
		_flash_timer = 0.0
		if animator.modulate.a > 0.5:
			animator.modulate = Color(1.0, 1.0, 1.0, 0.0)  # invisible
		else:
			animator.modulate = Color(1.0, 0.3, 0.3, 1.0)  # visible con tinte rojo


# ═══════════════════════════════════════════════════════════════════════
# ─── Aire bajo el agua ────────────────────────────────────────════════

func _update_air_supply(delta: float) -> void:
	if not wamder or infiniteAir:
		airSupply       = AIR_MAX
		_air_tick_timer = 0.0
		_air_dmg_timer  = 0.0
		return

	if airSupply > 0:
		_air_tick_timer += delta
		if _air_tick_timer >= AIR_TICK:
			_air_tick_timer = 0.0
			airSupply       = max(airSupply - 1, 0.0)
	else:
		_air_dmg_timer += delta
		if _air_dmg_timer >= AIR_DMG_INTERVAL:
			_air_dmg_timer = 0.0
			take_damage(3, global_position, true, false, true)


# ═══════════════════════════════════════════════════════════════════════
# ─── Acción de inspección ─────────────────────────────────────────────

func _handle_check_action() -> void:
	if Input.is_action_just_pressed("Down") and currentDirection == 0 and is_on_floor():
		checking = true
	elif checking and (currentDirection != 0 or not is_on_floor()):
		checking   = false
		hasChecked = false

	if checking and not able_to_interact and not hasChecked:
		hasChecked = true
		var question_mark = load("res://data/Entities/Misc/question_mark.tscn")
		var mark = question_mark.instantiate()
		mark.position = self.position
		get_tree().root.add_child(mark)


# ═══════════════════════════════════════════════════════════════════════
# ─── Estado del jugador ───────────────────────────────────────────────

func _process(_delta):
	move_state()


func move_state():
	if Input.is_action_pressed("Right"):
		lastDirection = 0
	elif Input.is_action_pressed("Left"):
		lastDirection = 1

	# durante el booster 2.0 la dirección visual la controla _booster2_locked_dir
	# así la animación muestra la dirección correcta aunque no se mueva el joystick
	if _booster2_active and _booster2_locked_dir != 0:
		lastDirection = 1 if _booster2_locked_dir < 0 else 0

	playerJump = not is_on_floor()


# ═══════════════════════════════════════════════════════════════════════
# ─── Animaciones ──────────────────────────────────────────────────────

func handle_animation(anim):
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

	if playerJump:
		# base de la animación según dirección
		var jump_base := "JumpLeft" if lastDirection == 1 else "JumpRight"

		if _booster2_active:
			# booster 2.0: usar JumpLeft/Right con sus variantes LookUp y LookDown
			# la dirección la controla _booster2_locked_dir actualizada en move_state
			anim = jump_base
			if Input.is_action_pressed("Up"):
				anim = jump_base + "LookUp"
			elif Input.is_action_pressed("Down"):
				anim = jump_base + "LookDown"

		elif _booster1_active:
			# booster 1.0: usar JumpLeft/Right con sus variantes
			anim = jump_base
			if Input.is_action_pressed("Up"):
				anim = jump_base + "LookUp"
			elif Input.is_action_pressed("Down"):
				anim = jump_base + "LookDown"

		elif _is_falling:
			# caída libre después de FALL_ANIM_TIME segundos bajando
			anim = "FallingLeft" if lastDirection == 1 else "FallingRight"

		else:
			# salto normal
			anim = jump_base
			if Input.is_action_pressed("Up"):
				anim = jump_base + "LookUp"

	else:
		# en el suelo
		if lastDirection == 1:
			anim = "WalkLeft" if input_dir < 0 else "IdleLeft"
		else:
			anim = "WalkRight" if input_dir > 0 else "IdleRight"

		if Input.is_action_pressed("Up"):
			anim = anim + "LookUp"
		elif checking and is_on_floor() and not anim.begins_with("Walk"):
			anim = anim + "Check"
		elif Input.is_action_pressed("Down") and not anim.begins_with("Walk"):
			anim = anim + "LookDown"

	_current_anim = anim
	animator.play(anim)


# ═══════════════════════════════════════════════════════════════════════
# ─── Sonidos ──────────────────────────────────────────────────────────

func _handle_sounds(delta: float) -> void:
	var input_dir := Input.get_axis("Left", "Right")

	if not _was_on_ceiling and is_on_ceiling():
		bonk_sfx.play()
	_was_on_ceiling = is_on_ceiling()

	if not _was_on_floor and is_on_floor():
		land_sfx.play()
		_step_timer = STEP_INTERVAL
	_was_on_floor = is_on_floor()

	if is_on_floor() and input_dir != 0 and not checking:
		_step_timer -= delta
		if _step_timer <= 0.0:
			if wamder:
				water_sfx.play()
			else:
				step_sfx.play()
			_step_timer = STEP_INTERVAL
	else:
		_step_timer = STEP_INTERVAL


# ═══════════════════════════════════════════════════════════════════════
# ─── Cámara estilo Cave Story ─────────────────────────────────────────

func _update_camera(delta: float) -> void:
	_cam_small_room = Globals.small_room

	if _cam_small_room:
		_cam_target = Vector2.ZERO
		_cam_offset = Vector2.ZERO
		var fixed_offset := -global_position

		if cam_quake:
			_quake_time += delta * cam_quake_speed
			_quake_offset.x = sin(_quake_time * 1.1) * cam_quake_intensity
			_quake_offset.y = sin(_quake_time * 1.7) * cam_quake_intensity
		else:
			_quake_offset = _quake_offset.lerp(Vector2.ZERO, 10.0 * delta)

		camera.offset = fixed_offset + _quake_offset
		return

	if _cam_override_active or _cam_focus_node != null:
		_cam_target = Vector2.ZERO
		var dest := Vector2.ZERO
		if _cam_focus_node != null:
			dest = to_local(_cam_focus_node.global_position)
		else:
			dest = _cam_override_target
		_cam_offset = _cam_offset.lerp(dest, _cam_override_speed * delta)

	else:
		var lead_x := CAM_H_LEAD if lastDirection == 0 else -CAM_H_LEAD
		var lead_y := 0.0
		if Input.is_action_pressed("Up"):
			lead_y = -CAM_V_LOOK_UP

		_cam_target.x = lead_x
		_cam_target.y = lerp(_cam_target.y, lead_y, CAM_LOOK_LERP * delta)
		_cam_offset.x = lerp(_cam_offset.x, _cam_target.x, CAM_H_LERP * delta)
		_cam_offset.y = lerp(_cam_offset.y, _cam_target.y, CAM_V_LERP * delta)

	if cam_quake:
		_quake_time += delta * cam_quake_speed
		_quake_offset.x = sin(_quake_time * 1.1) * cam_quake_intensity
		_quake_offset.y = sin(_quake_time * 1.7) * cam_quake_intensity
	else:
		_quake_offset = _quake_offset.lerp(Vector2.ZERO, 10.0 * delta)

	camera.offset = _cam_offset + _quake_offset


# ─── API pública de cámara ────────────────────────────────────────────

func camera_focus_on(target: Node2D, speed: float = CAM_OVERRIDE_LERP) -> void:
	_cam_focus_node      = target
	_cam_override_active = true
	_cam_override_speed  = speed


func camera_move_to(offset: Vector2, speed: float = CAM_OVERRIDE_LERP) -> void:
	_cam_focus_node      = null
	_cam_override_active = true
	_cam_override_target = offset
	_cam_override_speed  = speed


func camera_release() -> void:
	_cam_focus_node      = null
	_cam_override_active = false

func jump_speed() -> float:
	return WATER_JUMP_VELOCITY if wamder else JUMP_VELOCITY


# ═══════════════════════════════════════════════════════════════════════
# ─── Señales de área ──────────────────────────────────────────────────

func _on_water_detect_area_entered(_area):
	wamder = true

func _on_water_detect_area_exited(_area):
	wamder = false

func _on_interactable_area_entered(_area):
	able_to_interact = true

func _on_interactable_area_exited(_area):
	able_to_interact = false

func _on_damage_detect_body_entered(body: Node2D) -> void:
	var amount : int = 127
	if body.get("damage") != null:
		amount = body.damage
	take_damage(amount, body.global_position)
