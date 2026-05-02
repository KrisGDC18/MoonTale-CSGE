extends CharacterBody2D

var player_movement: bool = false
var _velocity_move: float = 400.0

func _physics_process(delta):
	
	if Input.is_action_pressed("ui_right"):
		velocity.x = _velocity_move
	
	elif Input.is_action_pressed("ui_left"):
		velocity.x = -_velocity_move
	
	else:
		velocity.x = 0
	move_and_slide()

	#if Input.is_action_pressed("ui_left"):
		#velocity.x = -200
		
	#else:
		#velocity.x = 0
	
		
func _process(delta):
	if velocity.x == 0:
		player_movement = false
	else:
		player_movement = true
	mi_funcion()

func _ready():
	mi_funcion()

func mi_funcion():
	if player_movement == true:
		print("se mueve")
	else:
		print("no se mueve")
