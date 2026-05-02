extends CharacterBody2D

@export var player_anim: AnimatedSprite2D

var player_movement: bool = false
var player_jump: bool = false
var player_idle: bool
var _last_direction: int = 0
var player_falling: bool
var allowMovement = true
var gravity = 400
var currentGravity = gravity
var jumpTime = 0.0
var currentDirection = 0
var wamder = false
var checking = false
var able_to_interact = false
var hasChecked = false

const MAX_SPEED = 150.0
const ACCR = 10.0
const FRICTION = 12.0
const JUMP_VELOCITY = 280
const WATER_MAX_SPEED = 80.0
const WATER_JUMP_VELOCITY = 140.0
const WATER_ACCR = 4.0

func _ready():
	player_idle = true
	player_falling = false
	
func _physics_process(delta):
	#Gravedad
	velocity.y += currentGravity * delta
	var direction = Input.get_axis("ui_left", "ui_right")
	currentDirection = direction
	if not is_on_floor():
		jumpTime = 0.0
	# Saltar
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		currentGravity = gravity / 2
		velocity.y = jump_speed()
	if Input.is_action_just_released("Jump") or velocity.y > 0:
		currentGravity = gravity
	
	# Movimiento lateral
	if direction:
		if wamder == true:
			velocity.x = move_toward(velocity.x, direction * WATER_MAX_SPEED, WATER_ACCR)
		else:
			velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCR)
		if is_on_floor():
			if _last_direction == 0:
				player_anim.play("WalkRight")
			elif _last_direction == 1:
				player_anim.play("WalkLeft")
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION)

		move_and_slide()
		
	if Input.is_action_just_pressed("ui_down") and direction == 0 and is_on_floor():
		checking = true
	elif checking == true and (direction != 0 or not is_on_floor()):
		checking = false
		hasChecked = false
			
	if checking == true:
		player_anim.play("Check")
	if able_to_interact == false and hasChecked == false:
				hasChecked = true
				var question_mark = load("res://Entities/Misc/question_mark.tscn")
				var mark = question_mark.instantiate()
				mark.position = self.position
				get_tree().root.add_child(mark)

func _process(delta):
	animate_player()	
	move_state_detect()

# Esta Funcion detecta el estado de movimiento del jugador
func move_state_detect():
	if player_movement == true or player_jump == true:
		player_idle = false
	else:
		player_idle = true
	
	if velocity.x != 0:
		player_movement = true
	else:
		player_movement = false
		
	if velocity.y != 0:
		player_jump = true
	else:
		player_jump = false
		
	if velocity.x != 0 or velocity.y != 0:
		player_movement = true
	else:
		player_movement = false
	if velocity.y < 0:
		player_falling = true
	else:
		player_falling = false
		
	#if player_jump == true or player_movement == true:
		#print("hay movimiento")
		#player_idle == false
	# else:
		#print("Totalmente quieto")
		#player_idle == true

func animate_player():
	
# Determina el sprite de reposo del jugador dependiendo de la ultima direccion reportada
	if player_idle == true:
		# Jugador quieto
		# Revisa si esta a la derecha, si esta brincando y si esta en el suelo
		if _last_direction == 0 and player_jump == false and is_on_floor():
			player_anim.play("IdleRight")
			print("Mirando a la derecha")
			
		elif _last_direction != 0 and player_jump == false and is_on_floor():
			print("Mirando a la izquierda")
			player_anim.play("IdleLeft")
	
		
		# Jugador saltando		
		elif _last_direction == 0 and player_jump == true:
			print("Salto viendo a la derecha")
			player_anim.play("JumpRight")
		elif _last_direction != 0 and player_jump == true:
			print("Salto viendo a la izquierda")
			player_anim.play("JumpLeft")
		
		#Jugador callendo
		if !is_on_floor():
			if _last_direction == 0:
				player_anim.play("JumpRight")
			elif _last_direction == 1:
				player_anim.play("JumpLeft")
			jumpTime = 0.0
		
	# Jugador caminando
	else:
		if _last_direction == 0 and player_jump == false and is_on_floor():
			player_anim.play("WalkRight")
			print("Caminando a la derecha")
		elif _last_direction == 1 and player_jump == false and is_on_floor():
			player_anim.play("WalkLeft")
			print("Caminando a la izquierda")
			
	# Cambio de direccion durante el salto
	if player_jump == true and Input.is_action_just_pressed("ui_right"):
		player_anim.play("JumpRight")
	elif player_jump == true and Input.is_action_just_pressed("ui_left"):
		player_anim.play("JumpLeft")
	# 

func jump_speed():
	
	var speed_incr: float = 12.0
	if wamder == false:
		return -(JUMP_VELOCITY + speed_incr * int(abs(velocity.x) / 30))
	else:
		return -(WATER_JUMP_VELOCITY + speed_incr * int(abs(velocity.x) / 30))

func handle_animation(direction):
	if direction < 0:
	  player_anim.play("IdleRight")
	elif direction > 0: 
		_last_direction = 1

func _on_water_detect_area_entered(area):
	wamder = true

func _on_water_detect_area_exited(area):
	wamder = false

func _on_interactable_area_entered(area):
	able_to_interact = true

func _on_interactable_area_exited(area):
	able_to_interact = false
