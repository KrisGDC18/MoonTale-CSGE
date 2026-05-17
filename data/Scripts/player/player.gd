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
const COYOTE_TIME         := 0.088

# ─── Escalado automático de bordes (step-up) ──────────────────────────
const STEP_UP_HEIGHT := 6.0  # píxeles máximos que intenta subir

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
const BOOSTER1_LIFT_FORCE     := 200.0
const BOOSTER1_GRAVITY_REDUCED:= 600.0
const BOOSTER1_MAX_UP_SPEED   := -280.0
const BOOSTER1_GAS_DRAIN      := 180.0
const BOOSTER_GAS_MAX         := 100.0

# ─── Booster 2.0 ──────────────────────────────────────────────────────
const BOOSTER2_SPEED_X        := 450.0 
const BOOSTER2_GRAVITY_REDUCED := 0.0
const BOOSTER2_MAX_UP_SPEED   := -310.0
const BOOSTER2_DOWN_FORCE     := 400.0
const BOOSTER2_GAS_DRAIN      := 100.0

# ─── Animación de caída ───────────────────────────────────────────────
const FALL_ANIM_TIME      := 0.35


# ─── Cooldown post-diálogo ────────────────────────────────────────────
# Tiempo en segundos que el jugador ignora inputs después de que
# playerStay vuelve a false (evita saltos/acciones accidentales).
const POST_STAY_COOLDOWN  := 0.20

# ─── Diálogo de muerte ────────────────────────────────────────────────
# Acción positiva: asígnala desde fuera antes de que el jugador muera,
# o conecta la señal "death_positive_chosen".
# La acción negativa siempre reinicia la escena actual.
signal death_positive_chosen
var death_dialog_positive_action : Callable = Callable()

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
@onready var weapon_manager = $WeaponManager


# ─── Variables de booster ─────────────────────────────────────────────
var jetpack_equipped    : bool  = false
var jetpack_upgrade     : bool  = false
var jetpack_gas         : float = BOOSTER_GAS_MAX
var jetpack_gas_max     : float = BOOSTER_GAS_MAX
var _booster1_active    : bool  = false
var _booster2_active    : bool  = false
var _booster2_locked_dir : float = 0.0
var _booster2_locked_vert : float = 0.0 
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
var _iframes_drowning   : bool  = false
var _death_phase        : int   = 0
var _death_flash_timer  : float = 0.0
var _death_respawn_timer: float = 0.0
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
var _prev_position : Vector2 = Vector2.ZERO
# Cooldown activo tras soltar el control al jugador (playerStay → false).
# Mientras sea > 0 se bloquean saltos y movimiento igual que playerStay.
var _post_stay_timer    : float = 0.0
var _prev_player_stay   : bool  = false   # para detectar el flanco descendente

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



# ═══════════════════════════════════════════════════════════════════════
func _ready():
	add_to_group("player")
	dmg.body_entered.connect(_on_damage_detect_body_entered)
	weapon_manager.init(self)
	# ─── Asignar todos los SFX del jugador al bus "SFX" ──────────────────
	for sfx in [jump_sfx, step_sfx, land_sfx, water_sfx,
				bonk_sfx, hurt_sfx, death_sfx, death_drown_sfx,
				booster_sfx, booster2_sfx]:
		sfx.bus = "SFX"
	# ─── Invencibilidad al aparecer en el mapa ───────────────────────────
	# Cubre tanto nuevo juego como carga de partida. Se conecta a map_changed
	# del Level para aplicar los iframes cada vez que se entra a un mapa.
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_signal("map_changed"):
		level.map_changed.connect(_on_map_changed)


# ═══════════════════════════════════════════════════════════════════════
func _physics_process(delta):
	if Globals.playerPlayable == false:
		return

	# ─── Cooldown post-diálogo ────────────────────────────────────────
	# Detecta el flanco descendente de playerStay (true → false) e inicia
	# el cooldown para evitar saltos/acciones accidentales al cerrar el diálogo.
	if _prev_player_stay and not Globals.playerStay:
		_post_stay_timer = POST_STAY_COOLDOWN
	_prev_player_stay = Globals.playerStay
	if _post_stay_timer > 0.0:
		_post_stay_timer -= delta

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
			_booster2_locked_vert = 0.0 
			_jump_grace_frame    = false
			_is_falling          = false
			_air_time            = 0.0
			_death_phase         = 0
			_death_flash_timer   = 0.0
			_death_respawn_timer = 0.0
			_iframes_drowning    = false
			allowMovement        = true
			Globals.playerPlayable = true
		else:
			_update_death_flash(delta)
			_death_respawn_timer += delta
		return

	var anim = "IdleRight"

	_update_coyote_time(delta)
	_update_jump_buffer(delta)
	_apply_gravity(delta)
	_update_fall_anim(delta)

	if _knockback_timer > 0.0:
		_knockback_timer     -= delta
		_booster1_active      = false
		_booster2_active      = false
		_booster2_locked_dir  = 0.0
		_jump_grace_frame     = false
		if booster_sfx.playing:  booster_sfx.stop()
		if booster2_sfx.playing: booster2_sfx.stop()
	else:
		_handle_jump()
		_handle_booster1(delta)
		_handle_booster2(delta)
		_handle_horizontal(delta)

	_update_air_supply(delta)
	_prev_position = global_position
	move_and_slide()


	if is_on_floor() and jetpack_equipped:
		jetpack_gas          = BOOSTER_GAS_MAX
		_booster2_locked_dir = 0.0
		_booster2_locked_vert = 0.0 

	_handle_check_action()
	handle_animation(anim)
	_handle_sounds(delta)
	_update_iframes(delta)
	if _jump_grace_frame:
		_jump_grace_frame = false


# ═══════════════════════════════════════════════════════════════════════
# ─── Helper: ¿está el jugador bloqueado por diálogo o cooldown? ───────
func _is_stayed() -> bool:
	return Globals.playerStay or _post_stay_timer > 0.0


# ═══════════════════════════════════════════════════════════════════════
# ─── Gravedad ─────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if wamder:
		velocity.y += GRAVITY_WATER * delta
		return

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
		_booster2_locked_vert = 0.0 
		_jump_grace_frame    = false
	if _is_stayed():
		return

	var can_jump       := is_on_floor() or (_coyote_timer > 0.0 and not _is_jumping)
	var jump_requested := Input.is_action_just_pressed("Jump") or _jump_buffer_timer > 0.0

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
		_booster2_locked_vert = 0.0 
		_jump_grace_frame    = true
		jump_sfx.play()
		return


	if not is_on_floor() and jetpack_equipped \
			and jetpack_gas > 0.0 and not _jump_grace_frame:

		if Input.is_action_just_pressed("Jump"):
			if jetpack_upgrade:
				var input_dir := Input.get_axis("Left", "Right")
				var locked : float = input_dir
				_booster2_locked_dir = locked
				_booster2_active     = true
				_booster1_active     = false

				if locked != 0.0:
					_booster2_locked_vert = 0.0
					velocity.x = locked * BOOSTER2_SPEED_X
					velocity.y = 0.0
				elif Input.is_action_pressed("Down"):
					_booster2_locked_vert = 1.0
					velocity.x = 0.0
					velocity.y = 0.0
				else:
					_booster2_locked_vert = -1.0
					velocity.x = 0.0
					velocity.y = BOOSTER2_MAX_UP_SPEED
			else:
				_booster1_active = true
				_booster2_active = false
				velocity.y       = BOOSTER1_MAX_UP_SPEED

		if Input.is_action_just_released("Jump"):
			_booster1_active     = false
			_booster2_active     = false
			_booster2_locked_dir = 0.0
			_booster2_locked_vert = 0.0 

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

	var BOOSTER1_HOVER_GRAVITY := 40.0
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

	if _booster2_locked_dir != 0.0:
		velocity.x = _booster2_locked_dir * BOOSTER2_SPEED_X

	if _booster2_locked_vert == 1.0:
		velocity.x  = 0.0
		velocity.y += (GRAVITY_DOWN + BOOSTER2_DOWN_FORCE) * delta
		velocity.y  = min(velocity.y, MAX_FALL_SPEED)

	elif _booster2_locked_vert == -1.0 and _booster2_locked_dir == 0.0:
		velocity.y = BOOSTER2_MAX_UP_SPEED
		var input_dir := Input.get_axis("Left", "Right")
		velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)

	else:
		var input_dir := Input.get_axis("Left", "Right")
		velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)

	if _booster2_locked_dir != 0.0:
		if abs(global_position.x - _prev_position.x) < 0.5:
			velocity.y = move_toward(velocity.y, -80.0, 300.0 * delta)

	jetpack_gas -= BOOSTER2_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster2_active     = false
		_booster2_locked_dir  = 0.0
		_booster2_locked_vert = 0.0
		_is_falling          = true
		booster2_sfx.stop()


# ═══════════════════════════════════════════════════════════════════════
# ─── Movimiento horizontal ────────────────────────────────────────────

func _handle_horizontal(delta: float) -> void:
	if _booster2_active:
		return
	if _is_stayed():
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
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
	_spawn_damage_label(amount)

	if currentLife <= 0:
		_die(is_drowning)
	else:
		if apply_knockback:
			_apply_knockback(source_global_pos)
		if is_drowning:
			_is_invincible    = true
			_iframes_timer    = AIR_DMG_INTERVAL
			_flash_timer      = 0.0
			_iframes_drowning = true
		else:
			remove_weapon_xp(amount)


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
	_booster2_locked_vert = 0.0 
	_jump_grace_frame    = false
	_death_phase         = 0
	_death_flash_timer   = 0.0
	_death_respawn_timer = 0.0
	if booster_sfx.playing:  booster_sfx.stop()
	if booster2_sfx.playing: booster2_sfx.stop()

	var idle_anim := "IdleLeft" if lastDirection == 1 else "IdleRight"
	animator.play(idle_anim)

	if is_drowning:
		animator.modulate = Color(0.55, 0.78, 1.0, 1.0)
		death_drown_sfx.play()
	else:
		_death_phase      = 1
		_death_flash_timer = 0.0
		animator.modulate  = Color(1.0, 0.0, 0.0, 1.0)
		death_sfx.play()

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
	_iframes_drowning    = false
	checking             = false
	hasChecked           = false


func _spawn_damage_label(amount: int) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12))
	label.add_theme_font_override("font", load("res://data/Fonts/monogatari.ttf"))
	label.add_theme_font_size_override("font_size", 20)
	label.z_index        = 10
	label.global_position = global_position - Vector2(8.0, 16.0)
	get_tree().root.add_child(label)

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


func _update_iframes(delta: float) -> void:
	if not _is_invincible:
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	_iframes_timer -= delta

	if _iframes_timer <= 0.0:
		_is_invincible    = false
		_iframes_timer    = 0.0
		_flash_timer      = 0.0
		_iframes_drowning = false
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	_flash_timer += delta
	if _flash_timer >= IFRAMES_FLASH_RATE:
		_flash_timer = 0.0
		if animator.modulate.a > 0.5:
			animator.modulate = Color(1.0, 1.0, 1.0, 0.0)
		else:
			if _iframes_drowning:
				animator.modulate = Color(0.7, 0.2, 1.0, 1.0)
			else:
				animator.modulate = Color(1.0, 0.3, 0.3, 1.0)


func _update_death_flash(delta: float) -> void:
	if _death_phase == 0:
		return

	_death_flash_timer += delta

	if _death_phase == 1:
		var t : float = min(_death_flash_timer / 0.3, 1.0)
		animator.modulate = Color(1.0, t, t, 1.0)
		if t >= 1.0:
			_death_phase       = 2
			_death_flash_timer = 0.0

	elif _death_phase == 2:
		if _death_flash_timer >= 0.5:
			_death_phase       = 3
			_death_flash_timer = 0.0
			animator.modulate  = Color(1.0, 1.0, 1.0, 0.0)

	elif _death_phase == 3:
		# Esperar un breve instante invisible antes de mostrar el diálogo
		if _death_flash_timer >= 0.3:
			_death_phase = 4
			_show_death_dialog()


func _show_death_dialog() -> void:
	# Las lambdas se declaran fuera del diccionario para evitar
	# errores de indentación de GDScript con lambdas multilínea en arrays.
	var action_positive := func():
		if death_dialog_positive_action.is_valid():
			death_dialog_positive_action.call()
			canContinue = true
		else:
			_load_save_with_fade()

	var action_negative := func():
		# Detener la música del mapa via AudioManager antes de abrir el título
		var am := get_tree().get_first_node_in_group("audio_manager")
		if am:
			am.stop()
		# Sacar al jugador del mapa inmediatamente para evitar daño
		global_position   = Vector2(-99999.0, -99999.0)
		velocity          = Vector2.ZERO
		visible           = false
		# Limpiar estado del jugador
		playerDead        = false
		_death_phase      = 0
		_is_invincible    = false
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Mostrar la pantalla de título — está siempre en el árbol,
		# solo necesita show_menu() para activarse. Ella sola bloquea
		# al jugador y lo oculta vía _lock_player().
		var title := get_tree().get_first_node_in_group("title_screen")
		if title and title.has_method("show_menu"):
			title.call_deferred("show_menu")

	var bloques := {
		"muerte": [
			{
				"text":          "¿Qué deseas hacer?",
				"choices":       ["Continuar", "Reiniciar"],
				"target_blocks": [null, null],
				"actions":       [action_positive, action_negative]
			}
		]
	}
	DialogBox.start(bloques, "muerte", false)

# ═══════════════════════════════════════════════════════════════════════
# ─── Carga de partida con fade ────────────────────────────────────────

func _on_map_changed(_map_name: String) -> void:
	# Se dispara al cargar cualquier mapa (nuevo juego o carga de partida).
	# Usamos call_deferred para que los iframes se apliquen DESPUÉS de que
	# SaveSystem._restore_player_deferred termine de restaurar el estado
	# (que incluye resetear _is_invincible a false).
	if _map_name == "":   # señal de descarga, ignorar
		return
	_apply_spawn_iframes.call_deferred()


func _apply_spawn_iframes() -> void:
	# Esperar suficientes frames para que _restore_player_deferred haya terminado
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_is_invincible    = true
	_iframes_timer    = 0.5
	_flash_timer      = 0.0
	_iframes_drowning = false

func _load_save_with_fade() -> void:
	# Bloquea al jugador durante el fade out
	Globals.playerStay     = true
	Globals.playerPlayable = false

	# Mover al jugador fuera del mapa inmediatamente para que no reciba
	# daño ni colisione mientras está en el lugar de muerte durante la carga.
	global_position        = Vector2(-99999.0, -99999.0)
	velocity               = Vector2.ZERO
	visible                = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# Conectar load_completed UNA sola vez para hacer el fade in después de cargar
	if not SaveSystem.load_completed.is_connected(_on_save_loaded):
		SaveSystem.load_completed.connect(_on_save_loaded, CONNECT_ONE_SHOT)

	# Fade a negro y luego cargar
	var tween: Tween = camera.fade_to_black(0.6)
	tween.tween_callback(func():
		SaveSystem.load_game(SaveSystem.current_slot)
	)


func _on_save_loaded(_slot: int) -> void:
	# load_completed se emite al inicio de _apply_state, ANTES de que
	# _restore_player_deferred termine. Esperamos suficientes frames para
	# que change_map y _restore_player_deferred hayan concluido del todo.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Restaurar visibilidad, colisiones y control del jugador
	visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	animator.modulate  = Color(1.0, 1.0, 1.0, 1.0)
	playerDead         = false   # ← debe ir ANTES de refrescar el arma
	_death_phase       = 0
	# Medio segundo de invencibilidad al revivir
	_is_invincible     = true
	_iframes_timer     = 0.5
	_flash_timer       = 0.0
	_iframes_drowning  = false

	# Refrescar el arma: _process del WeaponManager la oculta mientras
	# playerDead == true, así que reequipamos DESPUÉS de poner playerDead = false.
	if weapon_manager != null and not weapon_manager._weapons.is_empty():
		weapon_manager._equip(weapon_manager._current_index, false)

	Globals.playerPlayable = true
	Globals.playerStay     = false

	camera.fade_from_black(0.5)


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
		var question_mark = load("res://data/Entities/Misc/question_mark.tscn")
		var mark = question_mark.instantiate()
		mark.position = self.position
		get_tree().root.add_child(mark)


# ═══════════════════════════════════════════════════════════════════════
# ─── Estado del jugador ───────────────────────────────────────────────

func _process(_delta):
	move_state()
	
	if OS.is_debug_build() and Input.is_action_just_pressed("Debug"):
		if playerDead:
			canContinue = true


func move_state():
	if Input.is_action_pressed("Right"):
		lastDirection = 0
	elif Input.is_action_pressed("Left"):
		lastDirection = 1

	if _booster2_active and _booster2_locked_dir != 0:
		lastDirection = 1 if _booster2_locked_dir < 0 else 0

	playerJump = not is_on_floor()


# ═══════════════════════════════════════════════════════════════════════
# ─── Animaciones ──────────────────────────────────────────────────────

func handle_animation(anim):
	if playerDead:
		return
		
	if _is_stayed():
		var idle := "Check" if lastDirection == 1 else "Check"
		if _current_anim != idle:
			_current_anim = idle
			animator.play(idle)
		return

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
		var jump_base := "JumpLeft" if lastDirection == 1 else "JumpRight"

		if _booster2_active:
			anim = jump_base
			if Input.is_action_pressed("Up"):
				anim = jump_base + "LookUp"
			elif Input.is_action_pressed("Down"):
				anim = jump_base + "LookDown"

		elif _booster1_active:
			anim = jump_base
			if Input.is_action_pressed("Up"):
				anim = jump_base + "LookUp"
			elif Input.is_action_pressed("Down"):
				anim = jump_base + "LookDown"

		elif _is_falling:
			var fall_base := "FallingLeft" if lastDirection == 1 else "FallingRight"
			if Input.is_action_pressed("Down"):
				anim = ("JumpLeft" if lastDirection == 1 else "JumpRight") + "LookDown"
			elif Input.is_action_pressed("Up"):
				anim = ("JumpLeft" if lastDirection == 1 else "JumpRight") + "LookUp"
			else:
				anim = fall_base

		else:
			anim = jump_base
			if Input.is_action_pressed("Up"):
				anim = jump_base + "LookUp"
			elif Input.is_action_pressed("Down"):
				anim = jump_base + "LookDown"

	else:
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
# ─── API de cámara (delegates → camera_controller.gd) ─────────────────

func camera_focus_on(target: Node2D, speed: float = 5.0) -> void:
	camera.focus_on(target, speed)


func camera_move_to(target_offset: Vector2, speed: float = 5.0) -> void:
	camera.move_to(target_offset, speed)


func camera_release() -> void:
	camera.release()


func jump_speed() -> float:
	return WATER_JUMP_VELOCITY if wamder else JUMP_VELOCITY


# ═══════════════════════════════════════════════════════════════════════
# ─── Señales de área ──────────────────────────────────────────────────

func _on_water_detect_area_entered(_area):
	wamder = true

func _on_water_detect_area_exited(_area):
	wamder            = false
	_iframes_drowning = false

func _on_interactable_area_entered(_area):
	able_to_interact = true

func _on_interactable_area_exited(_area):
	able_to_interact = false

func _on_damage_detect_body_entered(body: Node2D) -> void:
	var amount : int = 127
	if body.get("damage") != null:
		amount = body.damage
	take_damage(amount, body.global_position)


func add_weapon_xp(amount: int):
	weapon_manager._current_weapon.add_xp(amount)
	

func remove_weapon_xp(amount: int):
	weapon_manager._current_weapon.remove_xp(amount)
	

func health(amount: int):
	currentLife = min(currentLife + amount, PLAYER_MAX_LIFE)
	
