extends CharacterBody2D

@export var qMark: PackedScene
@export var dmg: Area2D
@export var damage_material: ShaderMaterial

# ─── Velocidad y aceleración en el suelo ─────────────────────────────
const MAX_SPEED           := 200.0  # velocidad horizontal máxima caminando
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



@onready var animator = $AnimatedSprite2D

var currentGravity   := GRAVITY_DOWN # gravedad activa en este momento
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
var _current_anim: String = "IdleRight" # NUEVO: guarda la animación activa


func _ready():
	# conectar la señal del área de daño al aterrizar en enemigos/peligros
	dmg.body_entered.connect(_on_damage_detect_body_entered)


func _physics_process(delta):
	# si el jugador no es controlable (cutscene, diálogo, etc) no hacer nada
	if Globals.playerPlayable == false:
		return

	var anim = "IdleRight" # animación por defecto, se sobreescribe abajo

	_update_coyote_time(delta)  # 1. actualizar margen de salto al caer del borde
	_update_jump_buffer(delta)  # 2. actualizar input guardado de salto
	_apply_gravity(delta)       # 3. aplicar gravedad al movimiento vertical
	_handle_jump()              # 4. procesar input de salto
	_handle_horizontal(delta)   # 5. procesar input horizontal
	move_and_slide()            # 6. mover el personaje y detectar colisiones
	_handle_check_action()      # 7. lógica de agacharse e inspeccionar
	handle_animation(anim)      # 8. elegir y reproducir la animación correcta


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
		# al tocar el suelo, el salto ya no está activo
		# esto reactiva la gravedad pesada y permite volver a saltar
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
		velocity.y = -jump_speed()    # aplicar velocidad hacia arriba
		_is_jumping = true             # marcar que estamos en un salto activo
		_coyote_timer = 0.0           # consumir el coyote time para no saltar dos veces
		_jump_buffer_timer = 0.0      # consumir el buffer para no saltar dos veces

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
		checking = false
		hasChecked = false

	if checking and not able_to_interact and not hasChecked:
		# inspeccionando sin objeto interactuable → mostrar signo de pregunta
		hasChecked = true
		var question_mark = load("res://Entities/Misc/question_mark.tscn")
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
	# CAMBIO: antes solo chequeaba "Check", ahora también "LookUp" dentro del check
	# para poder detectar cuando el jugador suelta Up estando en ese estado
	if checking and (_current_anim.ends_with("Check") or _current_anim.ends_with("LookUp")):
		var base := "IdleLeft" if lastDirection == 1 else "IdleRight"

		if Input.is_action_pressed("Up"):
			# mirar arriba → cambiar a LookUp
			_current_anim = base + "LookUp"
			animator.play(_current_anim)
		elif _current_anim.ends_with("LookUp"):
			# soltó Up estando en LookUp → salir del check completamente
			checking = false
			hasChecked = false
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
	elif checking and is_on_floor():
		anim = anim + "Check"
	elif Input.is_action_pressed("Down") and not is_on_floor():
		anim = anim + "LookDown"

	_current_anim = anim
	animator.play(anim)

func _on_water_detect_area_entered(_area):
	wamder = true  # el jugador entró al agua

func _on_water_detect_area_exited(_area):
	wamder = false # el jugador salió del agua

func _on_interactable_area_entered(_area):
	able_to_interact = true  # hay un objeto interactuable cerca

func _on_interactable_area_exited(_area):
	able_to_interact = false # ya no hay objeto interactuable cerca

func _on_damage_detect_body_entered(_body: Node2D) -> void:
	print("daño al jugador") # aquí irá la lógica de daño al jugador
