extends CharacterBody2D

@export var qMark: PackedScene
@export var dmg: Area2D
@export var damage_material: ShaderMaterial

# ─── Velocidad y aceleración en el suelo ─────────────────────────────
# Valores raw del desmontaje de Cave Story (unidades internas: 1px = 512u)
# CS corre a 50fps fijos. Factor mundo: 32px/16px = 2.0
#
# Fórmula velocidad : raw/512 × 2.0 × 50   = px/s
# Fórmula aceleración: raw/512 × 2.0 × 50² = px/s²
#
# max_speed : 810/512 × 2.0 × 50  = 158 px/s
# accel     :  51/512 × 2.0 × 2500 = 498 px/s²
# friction  :  32/512 × 2.0 × 2500 = 313 px/s²
#
# JUMP_VELOCITY se sube de 300 a 339 para compensar que el sprite
# mide 41px vs 16px de Quote: se escala para mantener la misma
# proporción de "alturas de personaje" que en el original.
const MAX_SPEED           := 200.0
const JUMP_VELOCITY       := 354.0
const ACCR                := 498.0
const FRICTION            := 313.0
const SKID_FRICTION         := 5000.0  # frenado al invertir dirección en el suelo (derrape muy corto)
const AIR_SKID_FRICTION     := 50.0    # derrape mínimo en el aire, igual a la fricción aérea normal
const LANDING_SKID_FRICTION := 20000.0 # frenado suave al invertir dirección justo tras aterrizar (~1px)
const LANDING_SKID_DURATION := 0.12    # segundos tras aterrizar en los que aplica el frenado suave
const LANDING_EXCESS_FRICTION := 4000.0 # frena el exceso de velocidad (salto/booster2) al aterrizar

# ─── Velocidad y aceleración en el aire ──────────────────────────────
# air_accel: 20/512 × 2.0 × 2500 = 195 px/s²
# Cave Story da control aéreo mínimo y casi no frena en el aire.
const AIR_ACCR            := 195.0
const AIR_FRICTION        := 50.0

# ─── Movimiento en agua ───────────────────────────────────────────────
const WATER_MAX_SPEED     := 80.0
const WATER_JUMP_VELOCITY := 140.0
const WATER_ACCR          := 300.0
const AIR_MAX             := 100.0
const AIR_TICK            := 0.075
const AIR_DMG_INTERVAL    := 0.5

# ─── Movimiento en hielo ────────────────────────────────────────────────
# Se detecta revisando si el tile/cuerpo de piso sobre el que estás parado
# tiene activo el bit de la capa de colisión 7 (ver _update_ice_from_floor).
# Poca aceleración y casi nada de fricción: cuesta arrancar y cuesta parar.
const ICE_ACCR                 := 150.0
const ICE_FRICTION             := 60.0
const ICE_SKID_FRICTION        := 300.0  # derrape al invertir dirección sobre hielo
const ICE_COLLISION_LAYER_BIT  := 6      # Layer 7 en el editor = bit índice 6 (1<<6 = 64)

# ─── Gravedad ─────────────────────────────────────────────────────────
# grav_hold_jump: 64/512 × 2.0 × 2500  =  625 px/s²  (al mantener Jump)
# grav_normal  : 128/512 × 2.0 × 2500  = 1250 px/s²  (caída libre)
# max_fall     : 1600/512 × 2.0 × 50   =  313 px/s   (igual que jump inicial)
# Con estos valores el salto alcanza ~92px ≈ 2.9 bloques de 32px.
const GRAVITY_UP          := 625.0
const GRAVITY_DOWN        := 1250.0
const GRAVITY_WATER       := 200.0
const MAX_FALL_SPEED      := 313.0

# ─── Gravedad alternativa (para escenarios especiales) ────────────────
# Se activa con altGravityEnabled = true (desde un trigger/script del
# nivel). Mientras esté activa, reemplaza GRAVITY_UP/DOWN/MAX_FALL_SPEED
# por estos valores. No afecta la gravedad del agua (GRAVITY_WATER).
@export var altGravityEnabled  : bool  = false
@export var altGravityUp       : float = 625.0
@export var altGravityDown     : float = 1250.0
@export var altMaxFallSpeed    : float = 313.0

# ─── Salto variable ───────────────────────────────────────────────────
const JUMP_CUT_MULTIPLIER := 0.35

# ─── Hop de interacción con NPCs ───────────────────────────────────────
# Pequeño salto en el sitio, como el que hace Quote en Cave Story al
# iniciar ciertos diálogos con NPCs. Se dispara con trigger_npc_interact_jump().
const NPC_INTERACT_JUMP_VELOCITY := 180.0
const NPC_INTERACT_JUMP_PUSH_X   := 85.0  # empuje horizontal leve, opuesto a hacia dónde mira
const NPC_INTERACT_JUMP_PUSH_LOCK := 0.15  # segundos en que _handle_horizontal no toca el empuje

# ─── Coyote Time ──────────────────────────────────────────────────────
const COYOTE_TIME         := 0.088

# ─── Jump Buffer ──────────────────────────────────────────────────────
const JUMP_BUFFER_TIME    := 0.05

# ─── Knockback ────────────────────────────────────────────────────────
const KNOCKBACK_SPEED_X   := 100.0
const KNOCKBACK_SPEED_Y   := 180.0
const KNOCKBACK_DURATION  := 0.4

# ─── Retroceso al interactuar con un NPC (como en Cave Story) ────────
# Empujón horizontal leve y breve, sin daño ni i-frames, para cuando
# empieza un diálogo. Llamar a trigger_npc_interact_recoil() desde el
# NPC/sistema de diálogo justo al iniciar la conversación.
const NPC_RECOIL_SPEED_X  := 50.0
const NPC_RECOIL_DURATION := 0.12

# ─── I-frames ─────────────────────────────────────────────────────────
const IFRAMES_DURATION    := 1.25
const IFRAMES_FLASH_RATE  := 0.07

# ─── Booster 1.0 ──────────────────────────────────────────────────────
const BOOSTER1_LIFT_FORCE     := 200.0
const BOOSTER1_GRAVITY_REDUCED:= 600.0
const BOOSTER1_MAX_UP_SPEED   := -280.0
const BOOSTER1_GAS_DRAIN      := 180.0
const BOOSTER_GAS_MAX         := 100.0

# ─── Humo de boosters (sprite animado, instanciado periódicamente) ───
const BOOSTER_PARTICLE_INTERVAL := 0.06  # segundos entre cada tanda de puffs
const BOOSTER_PARTICLE_COUNT    := 3     # puffs generados juntos en cada tanda

# ─── Partículas de golpe en el techo (GPUParticles2D configurado como burst) ──
const BONK_SPAWN_OFFSET_Y := -17.0  # qué tan arriba del centro del jugador aparecen (ajustar a la altura real de la cabeza)
const QMARK_OFFSET_Y := -20.0  # qué tan arriba del centro del jugador aparece el signo de interrogación
const BONK_SPAWN_OFFSET_X := 5.0    # separación horizontal de cada chispa respecto al centro

# ─── Partículas en el agua (burbujas, etc.) ──────────────────────────
const WATER_PARTICLE_INTERVAL := 0.35  # segundos entre cada partícula mientras está en el agua

# ─── Booster 2.0 ──────────────────────────────────────────────────────
# Calibrado en relación a las constantes de movimiento normal, ya que
# el mundo usa una cuadrícula de 32x32 (vs 16x16 del Cave Story original):
# horizontal ~2.5x MAX_SPEED, subida ~1.24x JUMP_VELOCITY,
# bajada ~1.76x MAX_FALL_SPEED. Ajustar a sensación en el juego.
const BOOSTER2_SPEED_X         := 500.0   # 2.5x MAX_SPEED (200)
const BOOSTER2_GRAVITY_REDUCED := 0.0
const BOOSTER2_MAX_UP_SPEED    := -440.0  # 1.24x JUMP_VELOCITY (354)
const BOOSTER2_DOWN_FORCE      := 500.0   # fuerza extra sumada a GRAVITY_DOWN
const BOOSTER2_MAX_DOWN_SPEED  := 550.0   # 1.76x MAX_FALL_SPEED (313)
const BOOSTER2_GAS_DRAIN       := 100.0

# ─── Animación de caída ───────────────────────────────────────────────
const FALL_ANIM_TIME      := 0.35

# ─── Cooldown post-diálogo ────────────────────────────────────────────
const POST_STAY_COOLDOWN  := 0.20

# ─── Diálogo de muerte ────────────────────────────────────────────────
signal death_positive_chosen
signal npc_interact_jump_finished  # se emite al aterrizar tras trigger_npc_interact_jump()
var death_dialog_positive_action : Callable = Callable()

# ─── enum para dirección vertical del booster2 ───────────────────────
enum BoostVert { NONE, UP, DOWN }

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var animator        = $AnimatedSprite2D
@onready var camera          = $Camera2D
# Los sonidos ya no usan nodos AudioStreamPlayer propios: se reproducen
# posicionalmente a través del autoload AudioManager (AudioManager.play_sfx),
# que crea y libera sus propios reproductores por cada disparo.
@export var jump_sfx        : AudioStream
@export var step_sfx        : AudioStream
@export var land_sfx        : AudioStream
@export var water_sfx       : AudioStream
@export var bonk_sfx        : AudioStream
@export var hurt_sfx        : AudioStream
@export var death_sfx       : AudioStream
@export var death_drown_sfx : AudioStream
@export var booster_sfx     : AudioStream
@export var booster2_sfx    : AudioStream
@export var heal_sfx           : AudioStream  # curas (health() / fullHealth())
@export var weapon_level_up_sfx   : AudioStream  # llamar desde el arma al subir de nivel
@export var weapon_level_down_sfx : AudioStream  # llamar desde el arma al bajar de nivel
@export var booster_particle_scene  : PackedScene
@export var booster2_particle_scene : PackedScene
@export var bonk_particle_scene     : PackedScene
var _booster_particle_timer  : float = 0.0
var _booster2_particle_timer : float = 0.0
var _booster_trail_last_pos  : Vector2 = Vector2.ZERO
var _booster2_trail_last_pos : Vector2 = Vector2.ZERO
@onready var weapon_manager = $WeaponManager

var _damage_font := preload("res://data/Fonts/monogatari.ttf")

# ─── Variables de booster ─────────────────────────────────────────────
var jetpack_equipped    : bool  = false
var jetpack_upgrade     : bool  = false
var jetpack_gas         : float = BOOSTER_GAS_MAX
var jetpack_gas_max     : float = BOOSTER_GAS_MAX
var _booster1_active    : bool  = false
var _booster2_active    : bool  = false
var _booster2_locked_dir  : float     = 0.0
var _booster2_locked_vert : BoostVert = BoostVert.NONE
var _jump_grace_frame   : bool  = false

# ─── Variables de animación ───────────────────────────────────────────
var _air_time           : float = 0.0
var _is_falling         : bool  = false
var _current_anim       : String = "IdleRight"

# ─── Variables de vida y daño ─────────────────────────────────────────
const PLAYER_MAX_LIFE   : int   = 12
var currentLife         := PLAYER_MAX_LIFE
var _knockback_timer    := 0.0
var _npc_recoil_timer   := 0.0
var _npc_hop_active     := false
var _npc_hop_push_timer := 0.0
var _npc_hop_exit_checking := false
var useIdlePoseWhileStayed : bool = false  # si es true, _is_stayed() muestra Idle en vez de Check
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
var inWater             := false
var wamder              : bool:
	get: return inWater
	set(v): inWater = v
var inIce               := false
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
var _post_stay_timer    : float = 0.0
var _prev_player_stay   : bool  = false
# Congela la física mientras el jugador está bloqueado (diálogo, menú)
var _was_stayed         : bool  = false

# ─── Variables de agua ────────────────────────────────────────────────
var airSupply           : float = AIR_MAX
var _air_tick_timer     : float = 0.0
var _air_dmg_timer      : float = 0.0
@export var infiniteAir : bool  = false  # true = el jugador no se ahoga (ítem/power-up puede togglearlo por código)
@export var water_particle_scene : PackedScene  # escena que se genera periódicamente mientras el jugador está en el agua
var _water_particle_timer : float = 0.0

# ─── Variables de sonido ──────────────────────────────────────────────
var _was_on_floor       := true
var _floor_last_move    : bool  = true
var _landing_skid_timer : float = 0.0
var _was_on_ceiling     := false
var _step_timer         := 0.0
const STEP_INTERVAL      := 0.28

# ─── Buffer de acciones recientes ─────────────────────────────────────
const ACTION_BUFFER_SIZE := 20
const RECENT_JUMP_BLOCK_WINDOW := 0.3  # segundos tras presionar Jump en los que no se puede empezar a interactuar
var _action_buffer : Array = []  # cada entrada: {"action": String, "time": float}

# ─── Buffer de inputs crudos ───────────────────────────────────────────
# A diferencia de _action_buffer (que registra acciones ya resueltas por
# la física, ej. "jump" solo si el salto se ejecutó), esto registra el
# instante exacto en que se PRESIONA una tecla, sin importar si la
# acción resultante se ejecutó o no. Más preciso para detectar "el
# jugador tocó Jump hace poco", incluso si el salto se negó o se bufferizó.
const INPUT_BUFFER_SIZE := 20
const TRACKED_INPUT_ACTIONS := ["Jump", "Left", "Right", "Up", "Down"]
var _input_buffer : Array = []  # cada entrada: {"input": String, "time": float}


# ═══════════════════════════════════════════════════════════════════════
func _ready():
	add_to_group("player")
	if dmg:
		dmg.body_entered.connect(_on_damage_detect_body_entered)
	else:
		push_warning("Player: falta asignar 'Dmg' (Area2D) en el Inspector de la escena.")
	if not booster_particle_scene:
		push_warning("Player: falta asignar 'Booster Particle Scene' en el Inspector.")
	if not booster2_particle_scene:
		push_warning("Player: falta asignar 'Booster2 Particle Scene' en el Inspector.")
	if not bonk_particle_scene:
		push_warning("Player: falta asignar 'Bonk Particle Scene' en el Inspector.")
	weapon_manager.init(self)

	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_signal("map_changed"):
		level.map_changed.connect(_on_map_changed)


# ═══════════════════════════════════════════════════════════════════════
func _physics_process(delta):
	if Globals.playerPlayable == false:
		return

	if _prev_player_stay and not Globals.playerStay:
		_post_stay_timer = POST_STAY_COOLDOWN
		useIdlePoseWhileStayed = false
	_prev_player_stay = Globals.playerStay
	if _post_stay_timer > 0.0:
		_post_stay_timer -= delta

	if playerDead:
		if canContinue:
			_reset_after_death()
		else:
			_update_death_flash(delta)
			_death_respawn_timer += delta
		return

	var anim = "IdleRight"

	_update_input_buffer()

	_update_stayed_freeze()

	_update_coyote_time(delta)
	_update_jump_buffer(delta)
	_apply_gravity(delta)
	_update_fall_anim(delta)

	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		_reset_booster_state()
	elif _npc_recoil_timer > 0.0:
		_npc_recoil_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, (NPC_RECOIL_SPEED_X / NPC_RECOIL_DURATION) * delta)
	else:
		_handle_jump()
		_handle_booster1(delta)
		_handle_booster2(delta)
		if _npc_hop_push_timer > 0.0:
			_npc_hop_push_timer -= delta
		else:
			_handle_horizontal(delta)

	_update_air_supply(delta)
	_prev_position = global_position
	_move_with_step_up(delta)

	var _floor_now := is_on_floor()
	if _floor_now and not _floor_last_move:
		_landing_skid_timer = LANDING_SKID_DURATION
		if _npc_hop_active:
			_npc_hop_active = false
			if _npc_hop_exit_checking:
				checking   = false
				hasChecked = false
				_npc_hop_exit_checking = false
				useIdlePoseWhileStayed = true
			npc_interact_jump_finished.emit()
	elif _landing_skid_timer > 0.0:
		_landing_skid_timer -= delta
	_floor_last_move = _floor_now

	_update_ice_from_floor()

	if is_on_floor() and jetpack_equipped:
		jetpack_gas          = BOOSTER_GAS_MAX
		_booster2_locked_dir = 0.0
		_booster2_locked_vert = BoostVert.NONE

	_handle_check_action()
	handle_animation(anim)
	_handle_sounds(delta)
	_update_iframes(delta)
	if _jump_grace_frame:
		_jump_grace_frame = false


# ═══════════════════════════════════════════════════════════════════════
func _reset_after_death() -> void:
	canContinue          = false
	_is_invincible       = false
	currentLife          = PLAYER_MAX_LIFE
	animator.modulate    = Color(1.0, 1.0, 1.0, 1.0)
	airSupply            = AIR_MAX
	jetpack_gas          = BOOSTER_GAS_MAX
	_reset_booster_state()
	_is_falling          = false
	_air_time            = 0.0
	_death_phase         = 0
	_death_flash_timer   = 0.0
	_death_respawn_timer = 0.0
	_iframes_drowning    = false
	allowMovement        = true
	playerDead           = false
	Globals.playerPlayable = true


# ═══════════════════════════════════════════════════════════════════════
func _reset_booster_state() -> void:
	_booster1_active     = false
	_booster2_active     = false
	_booster2_locked_dir = 0.0
	_booster2_locked_vert = BoostVert.NONE
	_jump_grace_frame    = false
	_booster_particle_timer  = 0.0
	_booster2_particle_timer = 0.0

## Reproduce un sonido posicional a través de AudioManager (bus SFX),
## en la posición actual del jugador. Si el stream no está asignado en
## el Inspector, no hace nada (evita null errors sin necesidad de
## comprobar en cada punto de llamada).
func _play_sfx(stream: AudioStream, pitch_variation: float = 0.0) -> void:
	if stream == null:
		return
	AudioManager.play_sfx(stream, global_position, 0.0, pitch_variation)


# ═══════════════════════════════════════════════════════════════════════
# ─── Partículas de humo de los boosters ───────────────────────────────
# Cada puff es una instancia independiente que se autodestruye al
# terminar su animación (ver booster_puff.gd). Se instancia en el
# árbol principal para que no herede la rotación/escala del jugador.

func _spawn_booster_particle(scene: PackedScene, rotation_rad: float, count: int,
		from_pos: Vector2, to_pos: Vector2) -> void:
	if not scene:
		return
	var opposite : Vector2 = Vector2(-_facing_sign(), 0.0)

	for i in count:
		var t : float = 0.0 if count <= 1 else float(i) / float(count - 1)
		var base_pos := from_pos.lerp(to_pos, t)

		var puff := scene.instantiate()
		get_tree().root.add_child(puff)
		var offset := Vector2(
			randf_range(-1.5, 1.5),
			randf_range(-1.5, 1.5)
		)
		puff.global_position = base_pos + offset
		if puff is Node2D:
			puff.rotation = rotation_rad + randf_range(-0.25, 0.25)
		# lastDirection: 0 = mirando a la derecha, 1 = mirando a la izquierda.
		# El puff deriva hacia el lado opuesto al que mira el jugador.
		if "drift" in puff:
			puff.drift = opposite


# ═══════════════════════════════════════════════════════════════════════
# ─── Partículas de golpe en el techo ──────────────────────────────────
# Ráfaga radial (no un rastro): cada partícula sale disparada en una
# dirección distinta, como las "estrellitas" de Cave Story al chocar
# la cabeza contra un techo.

func _spawn_bonk_particles() -> void:
	if not bonk_particle_scene:
		return
	var spawn_pos := global_position + Vector2(0.0, BONK_SPAWN_OFFSET_Y)

	for side in [-1.0, 1.0]:
		var spark := bonk_particle_scene.instantiate()
		get_tree().root.add_child(spark)
		spark.global_position = spawn_pos + Vector2(side * BONK_SPAWN_OFFSET_X, 0.0)
		if "travel_dir" in spark:
			spark.travel_dir = side


# ═══════════════════════════════════════════════════════════════════════
# ─── Step-up ──────────────────────────────────────────────────────────
const STEP_UP_HEIGHT : float = 4.0
const STEP_UP_SKIN   : float = 0.5
const _COLLIDER_HALF_WIDTH : float = 5.5
const _COLLIDER_FOOT_Y     : float = 17.0

func _move_with_step_up(_delta: float) -> void:
	move_and_slide()

	if velocity.x == 0.0 or not is_on_floor() or get_slide_collision_count() == 0:
		return

	var has_h_col := false
	for i in get_slide_collision_count():
		if abs(get_slide_collision(i).get_normal().x) > 0.5:
			has_h_col = true
			break
	if not has_h_col:
		return

	var dir      : float = sign(velocity.x)
	var foot_y   : float = global_position.y + _COLLIDER_FOOT_Y
	var ray_from := Vector2(
		global_position.x + dir * (_COLLIDER_HALF_WIDTH + 1.0),
		foot_y - STEP_UP_HEIGHT
	)
	var ray_to   := Vector2(ray_from.x, foot_y)

	var space  := get_world_2d().direct_space_state
	var query  := PhysicsRayQueryParameters2D.create(ray_from, ray_to, collision_mask)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	if not result:
		return

	var obstacle_height := foot_y - (result["position"] as Vector2).y

	if obstacle_height > STEP_UP_HEIGHT or obstacle_height <= 0.0:
		return

	var saved_pos := global_position
	var saved_vel := velocity
	global_position.y -= obstacle_height + STEP_UP_SKIN
	velocity = saved_vel
	move_and_slide()

	for i in get_slide_collision_count():
		if abs(get_slide_collision(i).get_normal().x) > 0.5:
			global_position = saved_pos
			velocity        = saved_vel
			move_and_slide()
			return


# ═══════════════════════════════════════════════════════════════════════
# ─── Detección de hielo por capa de colisión ──────────────────────────
# Revisa las colisiones de piso generadas por el último move_and_slide()
# y comprueba si el cuerpo/tile con el que se está pisando tiene activo
# el bit de la capa de colisión 7 (ICE_COLLISION_LAYER_BIT). No depende
# de ninguna Area2D: el hielo es una propiedad física del tile en sí.

func _update_ice_from_floor() -> void:
	if not is_on_floor():
		inIce = false
		return

	var found_ice := false
	for i in get_slide_collision_count():
		var col    := get_slide_collision(i)
		var normal := col.get_normal()
		if normal.y > -0.5:
			continue  # no es una colisión de piso

		var collider = col.get_collider()
		if collider and "collision_layer" in collider:
			var layer : int = collider.collision_layer
			if layer & (1 << ICE_COLLISION_LAYER_BIT) != 0:
				found_ice = true
				break

	inIce = found_ice


# ═══════════════════════════════════════════════════════════════════════
# ─── Congelado de física durante diálogos / menús ────────────────────
# Al entrar en stayed: velocity se pone a cero (sin inercia acumulada).
# Al salir de stayed: velocity.x queda en 0 (sin salir disparado),
#                     velocity.y se restaura solo si estaba en el aire
#                     para que la gravedad no se pierda.

func _is_stayed() -> bool:
	return Globals.playerStay or _post_stay_timer > 0.0

func _update_stayed_freeze() -> void:
	var stayed_now := _is_stayed()

	if stayed_now and not _was_stayed:
		# Flanco de entrada: congelar
		velocity = Vector2.ZERO
		_reset_booster_state()
		_coyote_timer      = 0.0
		_jump_buffer_timer = 0.0
		_is_jumping        = false

	elif not stayed_now and _was_stayed:
		# Flanco de salida: limpiar inercia horizontal, mantener vertical
		# solo si el jugador está en el aire (para que no flote ni caiga raro)
		velocity.x = 0.0
		if is_on_floor():
			velocity.y = 0.0

	_was_stayed = stayed_now


# ═══════════════════════════════════════════════════════════════════════
# ─── Gravedad ─────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if _is_stayed():
		return

	if inWater:
		velocity.y += GRAVITY_WATER * delta
		return

	if _booster1_active or _booster2_active:
		return

	# Flote continuo del arma equipada (ej. Machine Gun nivel 3 disparando
	# hacia abajo en el aire): reemplaza la gravedad de este tick en vez
	# de sumarse a ella, para que el ascenso sea suave y controlable en
	# vez de competir contra GRAVITY_DOWN cada frame.
	var current_weapon = weapon_manager._current_weapon if weapon_manager else null
	if current_weapon and current_weapon.has_method("is_level3_hovering") and current_weapon.is_level3_hovering():
		velocity.y = move_toward(velocity.y, current_weapon.level3_lift_speed, current_weapon.level3_lift_accel * delta)
		return

	var grav_up      : float = altGravityUp   if altGravityEnabled else GRAVITY_UP
	var grav_down    : float = altGravityDown if altGravityEnabled else GRAVITY_DOWN
	var max_fall     : float = altMaxFallSpeed if altGravityEnabled else MAX_FALL_SPEED

	if _is_jumping and Input.is_action_pressed("Jump") and velocity.y < 0:
		velocity.y += grav_up * delta
	else:
		velocity.y += grav_down * delta

	velocity.y = min(velocity.y, max_fall)


func _handle_jump() -> void:
	if is_on_floor():
		_is_jumping  = false
		_is_falling  = false
		_air_time    = 0.0
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
		_jump_grace_frame  = true
		_play_sfx(jump_sfx)
		_log_action("jump")
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
				_booster2_trail_last_pos = global_position
				_booster2_particle_timer = 0.0
				_log_action("booster2_start")

				if locked != 0.0:
					_booster2_locked_vert = BoostVert.NONE
					velocity.x = locked * BOOSTER2_SPEED_X
					velocity.y = 0.0
				elif Input.is_action_pressed("Down"):
					_booster2_locked_vert = BoostVert.DOWN
					velocity.x = 0.0
					velocity.y = 0.0
				else:
					_booster2_locked_vert = BoostVert.UP
					velocity.x = 0.0
					velocity.y = BOOSTER2_MAX_UP_SPEED
			else:
				_booster1_active = true
				_booster2_active = false
				velocity.y       = BOOSTER1_MAX_UP_SPEED
				_booster_trail_last_pos = global_position
				_booster_particle_timer = 0.0
				_log_action("booster1_start")

		if Input.is_action_just_released("Jump"):
			_booster1_active     = false
			_booster2_active     = false
			_booster2_locked_dir = 0.0
			_booster2_locked_vert = BoostVert.NONE

	if Input.is_action_just_released("Jump") and velocity.y < 0 \
			and _is_jumping and not _booster1_active and not _booster2_active:
		velocity.y *= JUMP_CUT_MULTIPLIER


func _handle_booster1(delta: float) -> void:
	if not _booster1_active:
		_booster_particle_timer = 0.0
		_booster_trail_last_pos = global_position
		return

	_booster_particle_timer -= delta
	if _booster_particle_timer <= 0.0:
		_spawn_booster_particle(booster_particle_scene, 0.0, BOOSTER_PARTICLE_COUNT,
				_booster_trail_last_pos, global_position)
		_booster_trail_last_pos = global_position
		_play_sfx(booster_sfx)  # un disparo de sonido por cada tanda de partículas
		_booster_particle_timer = BOOSTER_PARTICLE_INTERVAL

	var BOOSTER1_HOVER_GRAVITY := 40.0
	velocity.y += BOOSTER1_HOVER_GRAVITY * delta
	velocity.y  = min(velocity.y, 20.0)

	jetpack_gas -= BOOSTER1_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster1_active = false
		_is_falling      = true


func _handle_booster2(delta: float) -> void:
	if not _booster2_active:
		_booster2_particle_timer = 0.0
		_booster2_trail_last_pos = global_position
		return

	var puff_rotation : float = 0.0

	if _booster2_locked_dir != 0.0:
		velocity.x = _booster2_locked_dir * BOOSTER2_SPEED_X
		# El humo sale hacia atrás del vuelo (dirección contraria al movimiento)
		puff_rotation = 0.0 if _booster2_locked_dir < 0.0 else PI

	if _booster2_locked_vert == BoostVert.DOWN:
		velocity.x  = 0.0
		velocity.y += (GRAVITY_DOWN + BOOSTER2_DOWN_FORCE) * delta
		velocity.y  = min(velocity.y, BOOSTER2_MAX_DOWN_SPEED)
		puff_rotation = -PI / 2.0  # humo hacia arriba (vuela hacia abajo)

	elif _booster2_locked_vert == BoostVert.UP and _booster2_locked_dir == 0.0:
		velocity.y = BOOSTER2_MAX_UP_SPEED
		var input_dir := Input.get_axis("Left", "Right")
		velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)
		puff_rotation = PI / 2.0  # humo hacia abajo (vuela hacia arriba)

	else:
		var input_dir := Input.get_axis("Left", "Right")
		velocity.x = move_toward(velocity.x, input_dir * (MAX_SPEED * 0.4), AIR_ACCR * delta)

	_booster2_particle_timer -= delta
	if _booster2_particle_timer <= 0.0:
		_spawn_booster_particle(booster2_particle_scene, puff_rotation, BOOSTER_PARTICLE_COUNT,
				_booster2_trail_last_pos, global_position)
		_booster2_trail_last_pos = global_position
		_play_sfx(booster2_sfx)  # un disparo de sonido por cada tanda de partículas
		_booster2_particle_timer = BOOSTER_PARTICLE_INTERVAL

	if _booster2_locked_dir != 0.0:
		if abs(global_position.x - _prev_position.x) < 0.5:
			velocity.y = move_toward(velocity.y, -80.0, 300.0 * delta)

	jetpack_gas -= BOOSTER2_GAS_DRAIN * delta
	jetpack_gas  = max(jetpack_gas, 0.0)

	if jetpack_gas <= 0.0:
		_booster2_active     = false
		_booster2_locked_dir = 0.0
		_booster2_locked_vert = BoostVert.NONE
		_is_falling          = true


# ═══════════════════════════════════════════════════════════════════════
# ─── Movimiento horizontal ────────────────────────────────────────────
# Usa move_toward + delta de forma consistente en todos los casos.
# Cave Story frena primero al cambiar de dirección en el suelo,
# y da muy poco control aéreo (AIR_FRICTION mínima).
#
# El derrape (cambio brusco de dirección) usa una fricción propia
# (SKID_FRICTION) distinta de la fricción normal de soltar el input.
# En el aire el derrape es casi nulo (AIR_SKID_FRICTION). Justo al
# aterrizar, durante LANDING_SKID_DURATION segundos, se usa un frenado
# suave (LANDING_SKID_FRICTION) para no cortar de golpe la inercia
# horizontal que traías del salto.
#
# Resistencia de aterrizaje: si tocas el suelo trayendo más velocidad
# horizontal de la normal (por un salto largo o, sobre todo, por el
# Booster 2.0, que llega a 500 px/s vs los 200 px/s de correr), durante
# esa misma ventana se aplica LANDING_EXCESS_FRICTION para devolverte
# rápido a un rango controlable, en vez de dejar que el exceso se
# disipe lento con el accel/fricción normales (lo que se sentía como
# un derrape/deslizamiento extremo).

func _handle_horizontal(delta: float) -> void:
	if _booster2_active:
		return
	if _is_stayed():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return

	var direction = Input.get_axis("Left", "Right")
	@warning_ignore("narrowing_conversion")
	currentDirection = direction

	var accel        : float
	var fric         : float
	var target_speed : float
	var on_ice : bool = inIce and not inWater and is_on_floor()

	if inWater:
		accel        = WATER_ACCR
		fric         = WATER_ACCR
		target_speed = WATER_MAX_SPEED
	elif on_ice:
		accel        = ICE_ACCR
		fric         = ICE_FRICTION
		target_speed = MAX_SPEED
	elif is_on_floor():
		accel        = ACCR
		fric         = FRICTION
		target_speed = MAX_SPEED
	else:
		accel        = AIR_ACCR
		fric         = AIR_FRICTION
		target_speed = MAX_SPEED

	var has_landing_excess : bool = is_on_floor() and not on_ice and _landing_skid_timer > 0.0 \
			and abs(velocity.x) > target_speed

	if direction != 0:
		if sign(velocity.x) != sign(direction) and velocity.x != 0.0:
			var skid_fric : float
			if not is_on_floor():
				skid_fric = AIR_SKID_FRICTION
			elif on_ice:
				skid_fric = ICE_SKID_FRICTION
			elif _landing_skid_timer > 0.0:
				skid_fric = LANDING_SKID_FRICTION
			else:
				skid_fric = SKID_FRICTION
			velocity.x = move_toward(velocity.x, 0.0, skid_fric * delta)
		else:
			var accel_to_use : float = LANDING_EXCESS_FRICTION if has_landing_excess else accel
			velocity.x = move_toward(velocity.x, direction * target_speed, accel_to_use * delta)
	else:
		var fric_to_use : float = LANDING_EXCESS_FRICTION if has_landing_excess else fric
		velocity.x = move_toward(velocity.x, 0.0, fric_to_use * delta)


# ═══════════════════════════════════════════════════════════════════════
# ─── Coyote time y jump buffer ────────────────────────────────────────

func _update_coyote_time(delta: float) -> void:
	if _is_stayed():
		return
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta


func _update_jump_buffer(delta: float) -> void:
	if _is_stayed():
		_jump_buffer_timer = 0.0
		return
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
	_play_sfx(hurt_sfx)
	_spawn_damage_label(amount)
	_log_action("damage_taken:%d" % amount)

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

	_log_action("death_drowning" if is_drowning else "death")
	playerDead           = true
	_is_invincible       = true
	velocity             = Vector2.ZERO
	_knockback_timer     = 0.0
	_reset_booster_state()
	_death_phase         = 0
	_death_flash_timer   = 0.0
	_death_respawn_timer = 0.0

	var idle_anim := "IdleLeft" if lastDirection == 1 else "IdleRight"
	animator.play(idle_anim)

	if is_drowning:
		animator.modulate  = Color(0.55, 0.78, 1.0, 1.0)
		_play_sfx(death_drown_sfx)
		_death_phase       = 1
		_death_flash_timer = 0.0
	else:
		_death_phase       = 1
		_death_flash_timer = 0.0
		animator.modulate  = Color(1.0, 0.0, 0.0, 1.0)
		_play_sfx(death_sfx)


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


## Retroceso leve al iniciar un diálogo con un NPC (como en Cave Story):
## un empujón horizontal breve, en la dirección opuesta a la que mira el
## jugador, sin daño, sin i-frames y sin cancelar la revisión en curso.
## Llamar desde el NPC/sistema de diálogo justo al arrancar la conversación.
func trigger_npc_interact_recoil() -> void:
	if _is_stayed() or not is_on_floor() or _knockback_timer > 0.0:
		return
	var recoil_dir : float = -_facing_sign()  # opuesto a hacia dónde mira
	velocity.x         = recoil_dir * NPC_RECOIL_SPEED_X
	_npc_recoil_timer  = NPC_RECOIL_DURATION


## Pequeño salto en el sitio al iniciar un diálogo con un NPC (como el
## "hop" de Quote en Cave Story). Reutiliza la física/animación normal
## de salto (JumpLeft/JumpRight) con una velocidad más baja que un
## salto real. Solo funciona en el suelo y fuera de diálogo/knockback.
## exit_checking: si es true, al aterrizar se cancela el estado de
## "revisar" (checking) y la animación vuelve a Idle mirando hacia la
## misma dirección en la que estaba el jugador antes de interactuar,
## en vez de quedarse pegado en la animación de Check.
func trigger_npc_interact_jump(exit_checking: bool = false) -> void:
	if _is_stayed() or not is_on_floor() or _knockback_timer > 0.0 or _npc_recoil_timer > 0.0:
		# No se pudo iniciar el hop: avisamos igual (en el siguiente frame,
		# para no emitir la señal antes de que quien llama alcance a
		# conectarse con "await") para que un await no se quede colgado.
		call_deferred("emit_signal", "npc_interact_jump_finished")
		return
	velocity.y         = -NPC_INTERACT_JUMP_VELOCITY
	velocity.x         = -_facing_sign() * NPC_INTERACT_JUMP_PUSH_X
	_is_jumping        = true
	_is_falling        = false
	_air_time          = 0.0
	_coyote_timer      = 0.0
	_jump_buffer_timer = 0.0
	_reset_booster_state()
	_jump_grace_frame  = true
	_npc_hop_active     = true
	_npc_hop_push_timer = NPC_INTERACT_JUMP_PUSH_LOCK
	_npc_hop_exit_checking = exit_checking


func _spawn_damage_label(amount: int) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12))
	label.add_theme_font_override("font", _damage_font)
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
		if _iframes_drowning:
			animator.modulate = Color(t, t, 1.0, 1.0)
		else:
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
		if _death_flash_timer >= 0.3:
			_death_phase = 4
			_show_death_dialog()


func _show_death_dialog() -> void:
	var action_positive := func():
		if death_dialog_positive_action.is_valid():
			death_dialog_positive_action.call()
			canContinue = true
		else:
			_load_save_with_fade()

	var action_negative := func():
		var am := get_tree().get_first_node_in_group("audio_manager")
		if am:
			am.stop()
		global_position   = Vector2(-99999.0, -99999.0)
		velocity          = Vector2.ZERO
		visible           = false
		playerDead        = false
		_death_phase      = 0
		_is_invincible    = false
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
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
	if _map_name == "":
		return
	_apply_spawn_iframes.call_deferred()


func _apply_spawn_iframes() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_is_invincible    = true
	_iframes_timer    = 0.5
	_flash_timer      = 0.0
	_iframes_drowning = false


func _load_save_with_fade() -> void:
	Globals.playerStay     = true
	Globals.playerPlayable = false

	global_position        = Vector2(-99999.0, -99999.0)
	velocity               = Vector2.ZERO
	visible                = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if not SaveSystem.load_completed.is_connected(_on_save_loaded):
		SaveSystem.load_completed.connect(_on_save_loaded, CONNECT_ONE_SHOT)

	var tween: Tween = camera.fade_to_black(0.6)
	tween.tween_callback(func():
		SaveSystem.load_game(SaveSystem.current_slot)
	)


func _on_save_loaded(_slot: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	visible = true
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	animator.modulate  = Color(1.0, 1.0, 1.0, 1.0)
	playerDead         = false
	_death_phase       = 0
	_is_invincible     = true
	_iframes_timer     = 0.5
	_flash_timer       = 0.0
	_iframes_drowning  = false

	if weapon_manager != null and not weapon_manager._weapons.is_empty():
		weapon_manager._equip(weapon_manager._current_index, false)

	Globals.playerPlayable = true
	Globals.playerStay     = false

	camera.fade_from_black(0.5)


# ═══════════════════════════════════════════════════════════════════════
# ─── Aire bajo el agua ────────────────────────────────────────════════

func _update_air_supply(delta: float) -> void:
	_update_water_particles(delta)

	if not inWater or infiniteAir:
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


# ─── Partículas mientras está en el agua ──────────────────────────────
# Independiente del flag infiniteAir: las burbujas son un efecto visual
# de estar sumergido, no están atadas a si el ahogamiento está activo.
func _update_water_particles(delta: float) -> void:
	if not inWater:
		_water_particle_timer = 0.0
		return
	if not water_particle_scene:
		return

	_water_particle_timer -= delta
	if _water_particle_timer <= 0.0:
		_water_particle_timer = WATER_PARTICLE_INTERVAL
		var bubble := water_particle_scene.instantiate()
		get_tree().root.add_child(bubble)
		bubble.global_position = global_position + Vector2(randf_range(-4.0, 4.0), 0.0)


# ═══════════════════════════════════════════════════════════════════════
# ─── Acción de inspección ─────────────────────────────────────────────

func _handle_check_action() -> void:
	if _is_stayed():
		checking   = false
		hasChecked = false
		return

	var jump_pending : bool = _jump_buffer_timer > 0.0 or _has_recent_input("Jump", RECENT_JUMP_BLOCK_WINDOW)

	if Input.is_action_just_pressed("Down") and currentDirection == 0 and is_on_floor() and not jump_pending:
		checking = true
		_log_action("interact_check")
	elif checking and (currentDirection != 0 or not is_on_floor()):
		checking   = false
		hasChecked = false

	if checking and not able_to_interact and not hasChecked:
		hasChecked = true
		if qMark:
			var mark = qMark.instantiate()
			get_tree().root.add_child(mark)
			mark.global_position = global_position + Vector2(0.0, QMARK_OFFSET_Y)
			if mark.has_method("show_balloon"):
				mark.show_balloon("question")


# ═══════════════════════════════════════════════════════════════════════
# ─── Estado del jugador ───────────────────────────────────────────────

func _process(_delta):
	move_state()

	if OS.is_debug_build() and Input.is_action_just_pressed("Debug"):
		if playerDead:
			canContinue = true


func move_state():
	# No actualizar lastDirection mientras stayed: evita que el sprite
	# voltee al presionar direcciones durante un diálogo o menú.
	if not _is_stayed():
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
		var idle : String
		if useIdlePoseWhileStayed:
			idle = "IdleLeft" if lastDirection == 1 else "IdleRight"
		else:
			idle = "CheckLeft" if lastDirection == 1 else "CheckRight"
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

		if _booster1_active or _booster2_active:
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
	# Guarda el estado del frame anterior ANTES de actualizarlo, para poder
	# detectar el flanco de entrada (ej. "no estaba en el techo y ahora sí").
	var prev_on_ceiling := _was_on_ceiling
	var prev_on_floor   := _was_on_floor
	_was_on_ceiling = is_on_ceiling()
	_was_on_floor   = is_on_floor()
	if _is_stayed():
		_step_timer = STEP_INTERVAL
		return

	var input_dir := Input.get_axis("Left", "Right")

	if not prev_on_ceiling and is_on_ceiling():
		_play_sfx(bonk_sfx)
		_spawn_bonk_particles()

	if not prev_on_floor and is_on_floor():
		_play_sfx(land_sfx)
		_step_timer = STEP_INTERVAL
		_log_action("land")

	if is_on_floor() and input_dir != 0 and not checking:
		_step_timer -= delta
		if _step_timer <= 0.0:
			if inWater:
				_play_sfx(water_sfx, 0.1)
			else:
				_play_sfx(step_sfx, 0.1)
			_step_timer = STEP_INTERVAL
	else:
		_step_timer = STEP_INTERVAL


# ═══════════════════════════════════════════════════════════════════════
# ─── API de cámara ────────────────────────────────────────────────────

func camera_focus_on(target: Node2D, speed: float = 5.0) -> void:
	camera.focus_on(target, speed)


func camera_move_to(target_offset: Vector2, speed: float = 5.0) -> void:
	camera.move_to(target_offset, speed)


func camera_release() -> void:
	camera.release()


# ═══════════════════════════════════════════════════════════════════════
# ─── Helpers genéricos de buffers con timestamp ───────────────────────
# Tanto el buffer de acciones como el de inputs comparten exactamente la
# misma lógica (agregar con límite de tamaño, y consultar "¿hubo X hace
# menos de N segundos?"), así que viven en un solo lugar.

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _buffer_log(buffer: Array, key: String, value: String, max_size: int) -> void:
	buffer.append({key: value, "time": _now()})
	if buffer.size() > max_size:
		buffer.pop_front()

func _buffer_has_recent(buffer: Array, key: String, value: String, within_seconds: float) -> bool:
	var now : float = _now()
	for i in range(buffer.size() - 1, -1, -1):
		var entry : Dictionary = buffer[i]
		if entry["time"] < now - within_seconds:
			break  # el buffer está en orden cronológico: lo que sigue es aún más viejo
		if entry[key] == value:
			return true
	return false


# ─── Buffer de acciones recientes ─────────────────────────────────────
# Guarda las últimas ACTION_BUFFER_SIZE acciones con su timestamp, en
# orden cronológico (la más reciente al final). Útil para depuración,
# combos, o cualquier sistema que necesite saber "qué hizo el jugador
# hace poco".

func _log_action(action_name: String) -> void:
	_buffer_log(_action_buffer, "action", action_name, ACTION_BUFFER_SIZE)

func get_action_history() -> Array:
	return _action_buffer.duplicate()

func clear_action_history() -> void:
	_action_buffer.clear()

func _has_recent_action(action_name: String, within_seconds: float) -> bool:
	return _buffer_has_recent(_action_buffer, "action", action_name, within_seconds)


# ─── Buffer de inputs crudos ───────────────────────────────────────────
# A diferencia de _action_buffer (acciones ya resueltas por la física),
# registra el instante exacto en que se PRESIONA una tecla, sin importar
# si la acción resultante se ejecutó o no.

func _update_input_buffer() -> void:
	for input_name in TRACKED_INPUT_ACTIONS:
		if Input.is_action_just_pressed(input_name):
			_log_input(input_name)

func _log_input(input_name: String) -> void:
	_buffer_log(_input_buffer, "input", input_name, INPUT_BUFFER_SIZE)

func get_input_history() -> Array:
	return _input_buffer.duplicate()

func clear_input_history() -> void:
	_input_buffer.clear()

func _has_recent_input(input_name: String, within_seconds: float) -> bool:
	return _buffer_has_recent(_input_buffer, "input", input_name, within_seconds)


func jump_speed() -> float:
	return WATER_JUMP_VELOCITY if inWater else JUMP_VELOCITY


## Signo (1.0 = derecha, -1.0 = izquierda) de hacia dónde mira el
## jugador actualmente, según lastDirection (0 = derecha, 1 = izquierda).
func _facing_sign() -> float:
	return 1.0 if lastDirection == 0 else -1.0


# ═══════════════════════════════════════════════════════════════════════
# ─── Gravedad alternativa por multiplicador ───────────────────────────
# Ejemplo: set_gravity_multiplier(2.0) duplica la gravedad, lo que reduce
# la altura del salto a la mitad (altura = velocidad² / (2 · gravedad)).
# Llamar con 1.0 (o set_gravity_multiplier_off) para volver a la normal.

func set_gravity_multiplier(factor: float) -> void:
	altGravityEnabled = true
	altGravityUp      = GRAVITY_UP   * factor
	altGravityDown    = GRAVITY_DOWN * factor
	altMaxFallSpeed   = MAX_FALL_SPEED * factor

func set_gravity_multiplier_off() -> void:
	altGravityEnabled = false


# ═══════════════════════════════════════════════════════════════════════
# ─── Señales de área ──────────────────────────────────────────────────

func _on_water_detect_area_entered(_area):
	inWater = true

func _on_water_detect_area_exited(_area):
	inWater           = false
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


## Llamar desde el script del arma (o weapon_manager) justo cuando el
## arma sube de nivel por XP acumulada.
func play_weapon_level_up_sfx() -> void:
	_play_sfx(weapon_level_up_sfx)


## Llamar desde el script del arma (o weapon_manager) justo cuando el
## arma baja de nivel (ej. al recibir daño y perder XP).
func play_weapon_level_down_sfx() -> void:
	_play_sfx(weapon_level_down_sfx)


func health(amount: int):
	if amount > 0 and currentLife < PLAYER_MAX_LIFE:
		_play_sfx(heal_sfx)
	currentLife = min(currentLife + amount, PLAYER_MAX_LIFE)

func fullHealth():
	if currentLife < PLAYER_MAX_LIFE:
		_play_sfx(heal_sfx)
	currentLife = min(currentLife + (PLAYER_MAX_LIFE - currentLife), PLAYER_MAX_LIFE)
