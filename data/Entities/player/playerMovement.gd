extends CharacterBody2D

@export var qMark: PackedScene
@export var dmg: Area2D
@export var damage_material: ShaderMaterial

# ─── Velocidad y aceleración en el suelo ─────────────────────────────
const MAX_SPEED           := 190.0  # velocidad horizontal máxima caminando
const JUMP_VELOCITY       := 295.0  # fuerza inicial del salto (hacia arriba)
const ACCR                := 1200.0 # qué tan rápido llegas a MAX_SPEED en el suelo valor alto = respuesta casi inmediata al input
const FRICTION            := 1000.0 # qué tan rápido frenas al soltar la dirección valor alto = paras rápido sin resbalar

# ─── Velocidad y aceleración en el aire ──────────────────────────────
const AIR_ACCR            := 380.0  # aceleración en el aire, menor que en suelo da la sensación de inercia al saltar
const AIR_FRICTION        := 180.0  # fricción en el aire, muy baja sin input casi no pierdes velocidad horizontal

# ─── Movimiento en agua ───────────────────────────────────────────────
const WATER_MAX_SPEED     := 80.0   # más lento que en tierra
const WATER_JUMP_VELOCITY := 140.0  # salto más bajo dentro del agua
const WATER_ACCR          := 300.0  # aceleración reducida, movimiento pesado
const AIR_MAX             := 100.0  # valor máximo del contador de aire bajo el agua
const AIR_TICK            := 0.075  # segundos entre cada descuento de aire
const AIR_DMG_INTERVAL    := 0.5    # segundos entre cada golpe de daño por ahogamiento
									# cuando el aire llega a 0 se aplican 3 de daño cada este tiempo
# ─── Gravedad ─────────────────────────────────────────────────────────
const GRAVITY_UP          := 450.0  # gravedad mientras subes con el botón presionado suave para dar control de altura al jugador
const GRAVITY_DOWN        := 980.0  # gravedad al bajar o soltar el botón más fuerte para que la caída se sienta pesada
const GRAVITY_WATER       := 200.0  # gravedad dentro del agua, muy suave
const MAX_FALL_SPEED      := 700.0  # velocidad máxima de caída (terminal velocity) evita que el jugador caiga infinitamente rápido

# ─── Salto variable ───────────────────────────────────────────────────
const JUMP_CUT_MULTIPLIER := 0.35   # al soltar el botón de salto mientras subes, la velocidad Y se multiplica por esto 0.35 = frena bruscamente → salto corto si lo mantienes → sube más alto

# ─── Coyote Time (5 frames a 60fps) ──────────────────────────────────
const COYOTE_TIME         := 0.083  # margen de tiempo para saltar después de caminar off un borde sin estar en el suelo 5 frames ÷ 60fps = 0.083s

# ─── Jump Buffer (3 frames a 60fps) ──────────────────────────────────
const JUMP_BUFFER_TIME    := 0.05   # si presionas salto justo ANTES de aterrizar, este tiempo guarda el input y salta al tocar 3 frames ÷ 60fps = 0.05s

# ─── Knockback (estilo CS) ───────────────────────────────────
# Al recibir daño el jugador vuela en dirección contraria a la fuente
# y pierde el control por KNOCKBACK_DURATION segundos
const KNOCKBACK_SPEED_X   := 100.0  # velocidad horizontal del vuelo de daño
const KNOCKBACK_SPEED_Y   := 180.0  # pequeño impulso hacia arriba al recibir golpe
									 # no es un salto completo, solo un "brinco" de dolor
const KNOCKBACK_DURATION  := 0.4    # segundos sin control tras el golpe

# ─── I-frames (invencibilidad tras recibir daño) ─────────────────────
# Después del knockback el jugador parpadea y no puede volver a recibir daño
# hasta que terminen los i-frames, igual que en Cave Story / TLOZ
const IFRAMES_DURATION    := 1.25    # segundos de invencibilidad
const IFRAMES_FLASH_RATE  := 0.07   # segundos entre cada parpadeo del sprite
									 # valor bajo = parpadeo rápido y nervioso


# ─── Variables del jugador ───────────────────────────────────────────

@onready var animator = $AnimatedSprite2D # agrega el nodo hijo de animacion 2d
var jetpack_equipped: = false

# ─── Variables de sonidos ───────────────────────────────────────────
@onready var jump_sfx  = $jump_sfx    # sonido de salto
@onready var step_sfx  = $step_sfx    # sonido de pasos
@onready var land_sfx  = $land_sfx    # sonido de aterrizaje
@onready var water_sfx = $water_sfx   # sonido al entrar/salir del agua
@onready var bonk_sfx  = $bonk_sfx    # sonido al chocar contra un techo
@onready var hurt_sfx  = $hurt_sfx    # sonido al recibir daño
@onready var death_sfx  = $death_sfx   # sonido al morir
@onready var death_drown_sfx = $death_drown_sfx  # sonido al morir por ahogamiento

# ─── Variables del contador de aire ──────────────────────────────────
var airSupply       : float = AIR_MAX  # aire actual; arranca lleno
									   # cuando llega a 0 el jugador muere ahogado
var _air_tick_timer : float = 0.0      # acumulador de tiempo entre cada descuento
									   # cuando supera AIR_TICK se resta 1 al aire
var _air_dmg_timer  : float = 0.0      # acumulador para el intervalo de daño por ahogamiento
									   # solo corre cuando airSupply es 0
var infiniteAir       : bool  = false  # si es true el aire nunca baja
const PLAYER_MAX_LIFE : int = 12       # vida máxima del jugador
									   # 12 puntos = 3 corazones (como en TLOZ)
var currentLife      := PLAYER_MAX_LIFE  # vida actual; arranca llena
										 # es var porque cambia al recibir daño
										
var currentGravity   := GRAVITY_DOWN  # gravedad activa en este momento
var allowMovement    := true          # si el jugador puede moverse (para cutscenes, etc)
var wamder           := false         # true cuando el jugador está en agua
var checking         := false         # true cuando el jugador está agachado inspeccionando
var able_to_interact := false         # hay un objeto interactuable cerca
var hasChecked       := false         # ya se instanció el signo de pregunta en este check
var currentDirection := 0             # dirección actual: -1 izq, 0 nada, 1 der
var lastDirection    := 0             # última dirección presionada (0=der, 1=izq) se usa para saber hacia dónde mirar al estar quieto
var playerJump       := false         # true si el jugador está en el aire
var playerDead       := false         # true si el jugador está muerto
var _is_jumping      := false         # true desde que salta hasta que toca el suelo controla si la gravedad suave aplica
var _coyote_timer    := 0.0           # contador regresivo del coyote time
var _jump_buffer_timer := 0.0         # contador regresivo del jump buffer
var _current_anim: String = "IdleRight" # guarda la animación activa

var _was_on_floor   := true   # estado del suelo en el frame anterior
							  # para detectar el momento exacto de aterrizaje
var _was_on_ceiling := false  # estado del techo en el frame anterior
							  # para detectar el momento exacto de golpe contra techo
var _step_timer     := 0.0    # contador para espaciar los pasos
const STEP_INTERVAL  := 0.28  # segundos entre cada paso (~Cave Story)
							  # ajusta según la velocidad de tu animación

# ─── Variables del motor de daño ─────────────────────────────────────
var _knockback_timer := 0.0   # tiempo restante de knockback activo
							  # mientras sea > 0 el jugador no tiene control
var _iframes_timer   := 0.0   # tiempo restante de invencibilidad
							  # mientras sea > 0 no puede volver a recibir daño
var _flash_timer     := 0.0   # acumulador para alternar visibilidad del sprite
var _is_invincible   := false # flag de consulta rápida: ¿está en i-frames ahora?
var canContinue      := false # true cuando el exterior (game over, cutscene, etc.)
							  # le da permiso al jugador de volver a moverse tras morir
							  # mientras sea false el jugador queda completamente bloqueado



func _ready():
	add_to_group("player")  # NUEVO: permite que el HUD lo encuentre
	# conectar la señal del área de daño al aterrizar en enemigos/peligros
	dmg.body_entered.connect(_on_damage_detect_body_entered)


func _physics_process(delta):
	# si el jugador no es controlable (cutscene, diálogo, etc) no hacer nada
	if Globals.playerPlayable == false:
		return

	# si el jugador está muerto, esperar a que canContinue sea true
	# durante este tiempo el jugador es invencible y no puede moverse
	if playerDead:
		if canContinue:
			# el exterior autorizó continuar: resetear el estado de muerte
			playerDead          = false
			canContinue         = false
			_is_invincible      = false
			currentLife         = PLAYER_MAX_LIFE  # restaurar vida completa al continuar
			animator.modulate.a = 1.0              # volver a hacer visible al jugador
			airSupply           = 100              # devuelve el airSupply a 100 por si el jugador murio ahogado
			# restaurar color y visibilidad completa sin importar cómo murió
			animator.modulate   = Color(1.0, 1.0, 1.0, 1.0)
		return
		
	var anim = "IdleRight" # animación por defecto, se sobreescribe abajo

	_update_coyote_time(delta)  # 1. actualizar margen de salto al caer del borde
	_update_jump_buffer(delta)  # 2. actualizar input guardado de salto
	_apply_gravity(delta)       # 3. aplicar gravedad al movimiento vertical

	# 4-5. durante el knockback el jugador no tiene control
	# la física (gravedad + move_and_slide) sigue corriendo para que
	# el personaje vuele y caiga de forma natural
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
	else:
		_handle_jump()            # 4. procesar input de salto (solo sin knockback)
		_handle_horizontal(delta) # 5. procesar input horizontal (solo sin knockback)
	
	_update_air_supply(delta)   # 6. actualizar contador de aire si está en agua
	move_and_slide()            # 7. mover el personaje y detectar colisiones
	_handle_check_action()      # 8. lógica de agacharse e inspeccionar
	handle_animation(anim)      # 9. elegir y reproducir la animación correcta
	_handle_sounds(delta)       # 10. aplicar sonidos a las acciones del jugador
	_update_iframes(delta)      # 11. actualizar invencibilidad y parpadeo visual

# ─── Motor de daño ────────────────────────────────────────────────────

func take_damage(amount: int, source_global_pos: Vector2,
				 ignore_iframes: bool = false, apply_knockback: bool = true,
				 is_drowning: bool = false) -> void:
	if (not ignore_iframes and _is_invincible) or playerDead:
		return

	currentLife = max(currentLife - amount, 0)
	hurt_sfx.play()

	if currentLife <= 0:
		_die(is_drowning)
	else:
		if apply_knockback:
			_apply_knockback(source_global_pos)

		if is_drowning:
			# activar el parpadeo visual sin knockback ni bloqueo de movimiento
			# _iframes_timer dura exactamente un intervalo para que el flash
			# coincida con el tiempo entre golpes de ahogamiento
			# como el daño siempre llega con ignore_iframes=true, los i-frames
			# no bloquean el siguiente golpe, solo controlan el efecto visual
			_is_invincible = true
			_iframes_timer = AIR_DMG_INTERVAL
			_flash_timer   = 0.0
	# aquí puedes emitir una señal para actualizar la HUD de vida
	# emit_signal("life_changed", currentLife)

func _die(is_drowning: bool = false) -> void:
	# guard: si ya está muerto no ejecutar de nuevo
	if playerDead:
		return

	playerDead       = true
	_is_invincible   = true
	velocity         = Vector2.ZERO
	_knockback_timer = 0.0

	if is_drowning:
		# muerte por ahogamiento: sprite visible con tinte azul
		# congelar en la animación idle de la dirección actual
		var idle_anim := "IdleLeft" if lastDirection == 1 else "IdleRight"
		animator.play(idle_anim)
		# tinte azul: rojo y verde bajos, azul alto, alpha completo
		animator.modulate = Color(0.35, 0.55, 1.0, 1.0)
		death_drown_sfx.play()
	else:
		# muerte normal: ocultar el sprite completamente
		death_sfx.play() 
		animator.modulate.a = 0.0


	print("jugador muerto")

func _update_air_supply(delta: float) -> void:
	if not wamder or infiniteAir:
		# fuera del agua O con aire infinito: restablecer contadores a tope
		# infiniteAir permite zonas seguras, power-ups o debug sin modificar wamder
		airSupply       = AIR_MAX
		_air_tick_timer = 0.0
		_air_dmg_timer  = 0.0
		return

	# ── Drenaje de aire ───────────────────────────────────────────────
	# dentro del agua: descontar aire tick a tick hasta llegar a 0
	if airSupply > 0:
		_air_tick_timer += delta
		if _air_tick_timer >= AIR_TICK:
			_air_tick_timer  = 0.0
			airSupply       -= 1
			airSupply        = max(airSupply, 0.0)
			print("Aire: ", airSupply)
			# emit_signal("air_changed", airSupply)

	# ── Daño por ahogamiento ──────────────────────────────────────────
	# cuando el aire se agota, aplicar 3 de daño cada AIR_DMG_INTERVAL segundos
	else:
		_air_dmg_timer += delta
		if _air_dmg_timer >= AIR_DMG_INTERVAL:
			_air_dmg_timer = 0.0
			# is_drowning=true propaga hasta _die() para activar el visual azul
			take_damage(3, global_position, true, false, true)
			print("Aire: 0 — ahogamiento")

func _apply_knockback(source_global_pos: Vector2) -> void:
	# calcular dirección: el jugador vuela en dirección CONTRARIA a la fuente
	# sign() devuelve -1, 0 o 1 según el signo de la diferencia de posición
	var knock_dir: float = signf(global_position.x - source_global_pos.x)

	# fallback: si la fuente está exactamente en la misma X (raro pero posible)
	# usar la dirección en la que el jugador mira
	if knock_dir == 0:
		knock_dir = -1 if lastDirection == 1 else 1

	# aplicar velocidad de knockback: horizontal fija + pequeño impulso hacia arriba
	velocity.x = knock_dir * KNOCKBACK_SPEED_X
	velocity.y = -KNOCKBACK_SPEED_Y  # negativo = hacia arriba en Godot

	# activar el timer de pérdida de control
	_knockback_timer = KNOCKBACK_DURATION

	# activar i-frames para que no reciba daño repetido mientras parpadea
	_is_invincible = true
	_iframes_timer = IFRAMES_DURATION
	_flash_timer   = 0.0

	# cancelar cualquier inspección que estuviera haciendo
	checking   = false
	hasChecked = false


func _update_iframes(delta: float) -> void:
	# si no está en i-frames no hay nada que actualizar
	if not _is_invincible:
		return

	_iframes_timer -= delta

	if _iframes_timer <= 0.0:
		# se agotaron los i-frames: apagar el flag y restaurar visibilidad completa
		_is_invincible      = false
		_iframes_timer      = 0.0
		_flash_timer        = 0.0
		animator.modulate.a = 1.0  # garantizar que el sprite quede visible al final
		return

	# parpadeo: acumular tiempo y alternar entre visible (alpha=1) e invisible (alpha=0)
	# modulate.a es la transparencia del sprite: 1 = visible, 0 = invisible
	_flash_timer += delta
	if _flash_timer >= IFRAMES_FLASH_RATE:
		_flash_timer        = 0.0
		animator.modulate.a = 0.0 if animator.modulate.a > 0.5 else 1.0


func _update_coyote_time(delta: float) -> void:
	if is_on_floor():
		# en el suelo: recargar el timer al máximo cada frame
		# así en cuanto caigas del borde, el timer empieza lleno
		_coyote_timer = COYOTE_TIME
	else:
		# en el aire: descontar el timer
		# cuando llega a 0 o menos, el coyote time se agotó
		_coyote_timer -= delta


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("Jump"):
		# el jugador presionó salto → guardar el input por JUMP_BUFFER_TIME segundos
		_jump_buffer_timer = JUMP_BUFFER_TIME
	elif _jump_buffer_timer > 0.0:
		# input guardado pero aún no se usó → descontar el tiempo
		_jump_buffer_timer -= delta
	else:
		# tiempo agotado → limpiar el buffer
		_jump_buffer_timer = 0.0


func _apply_gravity(delta: float) -> void:
	if wamder:
		# en agua: gravedad suave sin importar dirección ni botones
		currentGravity = GRAVITY_WATER
	elif _is_jumping and Input.is_action_pressed("Jump") and velocity.y < 0:
		# subiendo y con el botón presionado → gravedad suave
		# esto permite controlar la altura del salto
		currentGravity = GRAVITY_UP
	else:
		# bajando, o soltaste el botón → gravedad pesada
		# la caída se siente rápida y arcade como en Cave Story
		currentGravity = GRAVITY_DOWN

	# aplicar la gravedad elegida a la velocidad vertical
	velocity.y += currentGravity * delta

	# clamp: nunca caer más rápido que MAX_FALL_SPEED
	velocity.y = min(velocity.y, MAX_FALL_SPEED)


func _handle_jump() -> void:
	if is_on_floor():
		# al tocar el suelo, el salto ya no está activo esto reactiva la gravedad pesada y permite volver a saltar
		_is_jumping = false

	# can_jump es true si:
	#   - estás en el suelo (salto normal), O
	#   - el coyote time está activo y aún no has saltado (caíste del borde)
	var can_jump := is_on_floor() or (_coyote_timer > 0.0 and not _is_jumping)

	# jump_requested es true si:
	#   - presionaste el botón justo ahora, O
	#   - lo presionaste hace poco y el buffer aún está activo
	var jump_requested := Input.is_action_just_pressed("Jump") or _jump_buffer_timer > 0.0

	if jump_requested and can_jump:
		velocity.y         = -jump_speed()  # aplicar velocidad hacia arriba
		_is_jumping        = true            # marcar que estamos en un salto activo
		_coyote_timer      = 0.0            # consumir el coyote time para no saltar dos veces
		_jump_buffer_timer = 0.0            # consumir el buffer para no saltar dos veces
		jump_sfx.play()                     # reproducir sonido de salto

	if Input.is_action_just_released("Jump") and velocity.y < 0 and _is_jumping:
		# soltaste el botón mientras subías → cortar el salto bruscamente
		# multiplicar por 0.35 frena casi de golpe → salto corto
		velocity.y *= JUMP_CUT_MULTIPLIER


func _handle_horizontal(delta: float) -> void:
	var direction = Input.get_axis("Left", "Right") # -1, 0 o 1
	@warning_ignore("narrowing_conversion")
	currentDirection = direction

	var accel: float
	var fric: float

	if wamder:
		# en agua: aceleración y fricción iguales y reducidas
		accel = WATER_ACCR
		fric  = WATER_ACCR
	elif is_on_floor():
		# en el suelo: control total, respuesta inmediata
		accel = ACCR
		fric  = FRICTION
	else:
		# en el aire: menos control, la inercia se conserva
		# si saltas corriendo no puedes frenar de golpe en el aire
		accel = AIR_ACCR
		fric  = AIR_FRICTION

	var target_speed := WATER_MAX_SPEED if wamder else MAX_SPEED

	if direction != 0:
		# hay input: acelerar hacia la dirección presionada
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
	else:
		# sin input: desacelerar hacia 0
		# en el aire esto es muy lento (AIR_FRICTION baja) → inercia conservada
		velocity.x = move_toward(velocity.x, 0, fric * delta)


func _handle_check_action() -> void:
	if Input.is_action_just_pressed("Down") and currentDirection == 0 and is_on_floor():
		# presionó abajo sin moverse y en el suelo → entrar en modo inspección
		checking = true
	elif checking and (currentDirection != 0 or not is_on_floor()):
		# se movió o saltó mientras inspeccionaba → cancelar inspección
		checking   = false
		hasChecked = false

	if checking and not able_to_interact and not hasChecked:
		# inspeccionando sin objeto interactuable → mostrar signo de pregunta
		hasChecked = true
		var question_mark = load("res://data/Entities/Misc/question_mark.tscn")
		var mark = question_mark.instantiate()
		mark.position = self.position
		get_tree().root.add_child(mark)


func _process(_delta):
	move_state()


func move_state():
	if Input.is_action_pressed("Right"):
		lastDirection = 0 # mirando a la derecha
	elif Input.is_action_pressed("Left"):
		lastDirection = 1 # mirando a la izquierda

	# playerJump es true siempre que el jugador no esté en el suelo
	# se usa en handle_animation para elegir la animación de salto
	playerJump = not is_on_floor()


func jump_speed() -> float:
	# devuelve la fuerza de salto según el estado actual
	if wamder:
		return WATER_JUMP_VELOCITY # salto débil en agua
	else:
		return JUMP_VELOCITY       # salto normal en tierra


func handle_animation(anim):
	# antes solo chequeaba "Check", ahora también "LookUp" dentro del check
	# para poder detectar cuando el jugador suelta Up estando en ese estado
	if checking and (_current_anim.ends_with("Check") or _current_anim.ends_with("LookUp")):
		var base := "IdleLeft" if lastDirection == 1 else "IdleRight"

		if Input.is_action_pressed("Up"):
			# mirar arriba → cambiar a LookUp
			_current_anim = base + "LookUp"
			animator.play(_current_anim)
		elif _current_anim.ends_with("LookUp"):
			# soltó Up estando en LookUp → salir del check completamente
			checking      = false
			hasChecked    = false
			_current_anim = base
			animator.play(_current_anim)
		else:
			# sin input o Down → mantener Check
			animator.play(_current_anim)
		return

	var input_dir := Input.get_axis("Left", "Right")

	if playerJump:
		anim = "JumpLeft" if lastDirection == 1 else "JumpRight"
	else:
		if lastDirection == 1:
			anim = "WalkLeft" if input_dir < 0 else "IdleLeft"
		else:
			anim = "WalkRight" if input_dir > 0 else "IdleRight"

	if Input.is_action_pressed("Up"):
		anim = anim + "LookUp"
	elif checking and is_on_floor() and not anim.begins_with("Walk"):
		# Check solo aplica en Idle: agacharse mientras caminas no tiene animación
		anim = anim + "Check"
	elif Input.is_action_pressed("Down") and not is_on_floor() and not anim.begins_with("Walk"):
		# LookDown en el aire solo aplica en Idle: si vas con impulso horizontal no aplica
		anim = anim + "LookDown"

	_current_anim = anim
	animator.play(anim)


func _handle_sounds(delta: float) -> void:
	var input_dir := Input.get_axis("Left", "Right")

	# ── Golpe contra techo (bonk) ────────────────────────────────────
	# Igual que con el aterrizaje: comparamos el estado del techo en el
	# frame anterior vs el actual para detectar el momento exacto del impacto.
	# is_on_ceiling() es true solo mientras el personaje empuja contra el techo,
	# así que la transición false → true es exactamente el frame del golpe.
	if not _was_on_ceiling and is_on_ceiling():
		bonk_sfx.play()

	_was_on_ceiling = is_on_ceiling() # guardar estado para el siguiente frame

	# ── Aterrizaje ──────────────────────────────────────────────────
	# detectar el momento exacto en que el jugador toca el suelo
	# comparando el estado del frame anterior con el actual
	if not _was_on_floor and is_on_floor():
		land_sfx.play()              # acaba de aterrizar
		_step_timer = STEP_INTERVAL  # reiniciar pasos para no solapar con land

	_was_on_floor = is_on_floor()  # guardar estado para el siguiente frame

	# ── Pasos ────────────────────────────────────────────────────────
	# solo reproducir pasos si:
	#   - está en el suelo
	#   - hay input activo (se está moviendo)
	#   - no está en modo check
	if is_on_floor() and input_dir != 0 and not checking:
		_step_timer -= delta
		if _step_timer <= 0.0:
			# elegir sonido según si está en agua o tierra
			if wamder:
				water_sfx.play()
			else:
				step_sfx.play()
			_step_timer = STEP_INTERVAL  # reiniciar el timer
	else:
		# sin movimiento → reiniciar timer para que el primer paso
		# suene inmediatamente al volver a caminar
		_step_timer = STEP_INTERVAL


func _on_water_detect_area_entered(_area):
	wamder = true  # el jugador entró al agua

func _on_water_detect_area_exited(_area):
	wamder = false # el jugador salió del agua

func _on_interactable_area_entered(_area):
	able_to_interact = true  # hay un objeto interactuable cerca

func _on_interactable_area_exited(_area):
	able_to_interact = false # ya no hay objeto interactuable cerca

func _on_damage_detect_body_entered(body: Node2D) -> void:
	# leer la propiedad "damage" del cuerpo que golpeó si existe
	# esto permite que cada enemigo o trampa defina cuánto daño hace
	# con solo añadir "var damage := N" en su propio script
	var amount: int = 127  # valor por defecto si el origen no declara "damage"
	if body.get("damage") != null:
		amount = body.damage

	# llamar al motor de daño pasando el daño calculado y la posición del origen
	take_damage(amount, body.global_position)
