extends CharacterBody2D

@export var qMark: PackedScene
@export var dmg: Area2D
@export var damage_material: ShaderMaterial

# ─── Constantes terrestres ───────────────────────────────────────────
const MAX_SPEED          := 200.0   # sin cambio, tu valor era correcto
const JUMP_VELOCITY      := 295.0   # ligeramente más alto para sentirse ágil
const ACCR               := 1200.0  #z CAMBIO: era 20. Ahora es por delta,
									# da respuesta casi inmediata como CS
const FRICTION           := 1000.0  # CAMBIO: era 12. Detiene rápido sin
									# deslizarse demasiado

const AIR_ACCR           := 380.0   # NUEVO: ~1/3 del suelo, control reducido en el aire
const AIR_FRICTION       := 180.0   # NUEVO: casi no frenas solo mientras vuelas
# ─── Constantes de agua ──────────────────────────────────────────────
const WATER_MAX_SPEED    := 80.0
const WATER_JUMP_VELOCITY:= 140.0
const WATER_ACCR         := 300.0   # CAMBIO: era 4, ahora con delta-time

# ─── Gravedad ────────────────────────────────────────────────────────
# Cave Story tiene dos gravedades distintas:
#   - Gravedad de subida (mientras mantienes jump y velocity.y < 0): suave
#   - Gravedad de bajada: pesada y rápida
const GRAVITY_UP         := 450.0   # NUEVO: gravedad suave al subir
const GRAVITY_DOWN       := 980.0   # NUEVO: gravedad pesada al bajar/soltar
const GRAVITY_WATER      := 200.0   # NUEVO: gravedad en agua
const MAX_FALL_SPEED     := 700.0   # NUEVO: terminal velocity (CS la tiene)

# ─── Salto variable ──────────────────────────────────────────────────
# En CS al soltar el botón durante la subida, la velocidad Y se reduce
# bruscamente. Esto da control de altura al jugador.
const JUMP_CUT_MULTIPLIER := 0.35   # NUEVO: multiplica velocity.y al soltar

@onready var animator = $AnimatedSprite2D

var currentGravity  := GRAVITY_DOWN
var allowMovement   := true
var wamder          := false
var checking        := false
var able_to_interact:= false
var hasChecked      := false
var currentDirection:= 0
var lastDirection   := 0
var playerJump      := false
var playerDead      := false
var _is_jumping     := false  # NUEVO: rastrear si estamos en un salto activo



func _ready():
	dmg.body_entered.connect(_on_damage_detect_body_entered)


func _physics_process(delta):
	if Globals.playerPlayable == false:
		return

	var anim = "IdleRight"

	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)
	move_and_slide()
	_handle_check_action()
	handle_animation(anim)


func _apply_gravity(delta: float) -> void:
	# CAMBIO PRINCIPAL: antes usabas una sola gravedad dividida por 1.9
	# Ahora hay tres estados claros igual que Cave Story:
	#
	#   1. En agua → gravedad suave siempre
	#   2. Subiendo + botón presionado → gravedad suave (salto flotante)
	#   3. Bajando o botón suelto → gravedad pesada (caída rápida)
	#
	# Esto es lo que da el feeling de CS: subida controlada, bajada rápida.

	if wamder:
		currentGravity = GRAVITY_WATER
	elif _is_jumping and Input.is_action_pressed("Jump") and velocity.y < 0:
		currentGravity = GRAVITY_UP    # subiendo con botón presionado → suave
	else:
		currentGravity = GRAVITY_DOWN  # bajando o botón suelto → pesada

	velocity.y += currentGravity * delta

	# NUEVO: limitar velocidad de caída (terminal velocity de Cave Story)
	velocity.y = min(velocity.y, MAX_FALL_SPEED)


func _handle_jump() -> void:
	# Al tocar el suelo, reseteamos el estado de salto
	if is_on_floor():
		_is_jumping = false

	# Iniciar salto
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = -jump_speed()
		_is_jumping = true

	# CAMBIO: corte de salto más agresivo al soltar el botón
	# Antes: no había corte explícito, solo cambiabas la gravedad
	# Ahora: la velocidad Y se multiplica por 0.35 → caída inmediata
	# Esto es exactamente lo que hace CS para el salto variable
	if Input.is_action_just_released("Jump") and velocity.y < 0 and _is_jumping:
		velocity.y *= JUMP_CUT_MULTIPLIER


func _handle_horizontal(delta: float) -> void:
	var direction = Input.get_axis("Left", "Right")
	@warning_ignore("narrowing_conversion")
	currentDirection = direction

	# NUEVO: seleccionar aceleración y fricción según el estado del jugador
	# Antes: siempre usaba ACCR y FRICTION, sin importar si estaba en el aire
	# Ahora: en el aire se usan valores menores → la inercia se conserva
	var accel: float
	var fric: float

	if wamder:
		# En agua: control reducido, igual que antes
		accel = WATER_ACCR
		fric  = WATER_ACCR
	elif is_on_floor():
		# En el suelo: control total, respuesta inmediata
		accel = ACCR
		fric  = FRICTION
	else:
		# En el aire: inercia horizontal conservada
		# Si presionas una dirección, empujas suavemente
		# Si no presionas nada, casi no pierdes velocidad
		accel = AIR_ACCR
		fric  = AIR_FRICTION

	var target_speed := WATER_MAX_SPEED if wamder else MAX_SPEED

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, fric * delta)


func _handle_check_action() -> void:
	# Sin cambios de lógica, solo extraído a su propia función
	if Input.is_action_just_pressed("Down") and currentDirection == 0 and is_on_floor():
		checking = true
	elif checking and (currentDirection != 0 or not is_on_floor()):
		checking = false
		hasChecked = false

	if checking and not able_to_interact and not hasChecked:
		hasChecked = true
		var question_mark = load("res://Entities/Misc/question_mark.tscn")
		var mark = question_mark.instantiate()
		mark.position = self.position
		get_tree().root.add_child(mark)


func _process(_delta):
	move_state()


func move_state():
	if Input.is_action_pressed("Right"):
		lastDirection = 0
	elif Input.is_action_pressed("Left"):
		lastDirection = 1

	# CAMBIO: playerJump ahora refleja si estamos en el aire,
	# no solo si el botón está presionado. Más confiable para animaciones.
	playerJump = not is_on_floor()


func jump_speed() -> float:
	# CAMBIO: eliminado el int(abs(velocity.x)/30) también en agua
	# Cave Story no aumenta la altura del salto con la velocidad horizontal
	if wamder:
		return WATER_JUMP_VELOCITY
	else:
		return JUMP_VELOCITY


func handle_animation(anim):
	if playerJump:
		anim = "JumpLeft" if lastDirection == 1 else "JumpRight"
	else:
		if lastDirection == 1:
			anim = "WalkLeft" if velocity.x != 0 else "IdleLeft"
		else:
			anim = "WalkRight" if velocity.x != 0 else "IdleRight"

	if Input.is_action_pressed("Up"):
		anim = anim + "LookUp"
	elif Input.is_action_pressed("Down") and is_on_floor() and checking:
		anim = anim + "Check"
	elif Input.is_action_pressed("Down") and not is_on_floor():
		anim = anim + "LookDown"

	animator.play(anim)


func _on_water_detect_area_entered(_area):
	wamder = true

func _on_water_detect_area_exited(_area):
	wamder = false

func _on_interactable_area_entered(_area):
	able_to_interact = true

func _on_interactable_area_exited(_area):
	able_to_interact = false

func _on_damage_detect_body_entered(_body: Node2D) -> void:
	print("daño al jugador")
