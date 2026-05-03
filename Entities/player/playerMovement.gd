extends CharacterBody2D

@export var qMark: PackedScene
@export var dmg: Area2D
@export var damage_material: ShaderMaterial

const MAX_SPEED = 200.0
const JUMP_VELOCITY = 280
const ACCR = 20.0
const FRICTION = 12.0
const WATER_MAX_SPEED = 80.0
const WATER_JUMP_VELOCITY = 140.0
const WATER_ACCR = 4.0

@onready var animator = $AnimatedSprite2D
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = 820.0
var currentGravity = gravity
var jumpTime: float = 0.0
var allowMovement: bool = true
var wamder: bool
var checking: bool
var able_to_interact: bool
var hasChecked: bool
var currentDirection: int = 0
var lastDirection: int = 0
var playerJump: bool
var playerDead: bool


func _ready():
	dmg.body_entered.connect(_on_damage_detect_body_entered)

func _physics_process(delta):
	# Add the gravity.
	if Globals.playerPlayable == true:
		var anim = "IdleRight"
		velocity.y += currentGravity * delta
		var direction = Input.get_axis("Left", "Right")
		@warning_ignore("narrowing_conversion")
		currentDirection = direction
		# Si no esta en el suelo, entonces la animacion es de salto
		if not is_on_floor():
			jumpTime = 0.0

		# Handle jump.
		if Input.is_action_just_pressed("Jump") and is_on_floor():
			currentGravity = gravity / 1.9
			velocity.y = jump_speed()
			
		if Input.is_action_just_released("Jump") or velocity.y > 0:
			currentGravity = gravity

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		if direction:
			if wamder == true:
				velocity.x = move_toward(velocity.x, direction * WATER_MAX_SPEED, WATER_ACCR)
			else:
				velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCR)
			if is_on_floor():
				pass
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION)
		move_and_slide()

		if Input.is_action_just_pressed("Down") and direction == 0 and is_on_floor():
			checking = true
		elif checking == true and (direction != 0 or not is_on_floor()):
			checking = false
			hasChecked = false
			
		if checking == true:
			if able_to_interact == false and hasChecked == false:
				hasChecked = true
				var question_mark = load("res://Entities/Misc/question_mark.tscn")
				var mark = question_mark.instantiate()
				mark.position = self.position
				get_tree().root.add_child(mark)
		handle_animation(anim)

@warning_ignore("unused_parameter")
func _process(delta):
	move_state()

func move_state():
	if Input.is_action_pressed("Right"):
		lastDirection = 0 # Derecha 
	elif Input.is_action_pressed("Left"):
		lastDirection = 1 # Izquierda
	
	if Input.is_action_pressed("Jump") and !is_on_floor():
		playerJump = true
	elif !Input.is_action_pressed("Jump") and is_on_floor():
		playerJump = false

func jump_speed():
	var speed_incr: float = 15.0
	if wamder == false:
		# Se elimino lo siguiente * int(abs(velocity.x) / 30) para evitar sumar altura al saltar mientras te mueves. Lo que hace que sea mas preciso y similar a CS.
		return -(JUMP_VELOCITY + speed_incr)
	else:
		return -(WATER_JUMP_VELOCITY + speed_incr * int(abs(velocity.x) / 30))

func handle_animation(anim):
	
	if playerJump == true:
			if lastDirection == 1: 
				anim = "JumpLeft"
			elif lastDirection == 0:
				anim = "JumpRight"
	else:
		if lastDirection == 1:
			if velocity.x != 0: 
				anim = "WalkLeft"
			else:
				anim = "IdleLeft"
			
		elif lastDirection == 0: 
			if velocity.x != 0: 
				anim = "WalkRight"
			else:
				anim = "IdleRight"

	if Input.is_action_pressed("Up"):
		anim = anim + "LookUp"
	elif Input.is_action_pressed("Down") and is_on_floor() and checking == true:
		anim = anim + "Check"
	elif Input.is_action_pressed("Down") and !is_on_floor():
			anim = anim + "LookDown"
	animator.play(anim)

@warning_ignore("unused_parameter")
func _on_water_detect_area_entered(area):
	wamder = true

@warning_ignore("unused_parameter")
func _on_water_detect_area_exited(area):
	wamder = false

@warning_ignore("unused_parameter")
func _on_interactable_area_entered(area):
	able_to_interact = true

@warning_ignore("unused_parameter")
func _on_interactable_area_exited(area):
	able_to_interact = false


@warning_ignore("unused_parameter")
func _on_damage_detect_body_entered(body: Node2D) -> void:
	print("daño al jugador")
