extends CharacterBody2D

var interactable                 = false
@export var dialogue_id : String = "test_kris_dialogue_01"

func _ready():
	pass

func _physics_process(delta: float):
	if Input.is_action_just_pressed("Down") and interactable:
		print("Hola Mundo de Mootale, soy yo Kris!")

func _on_area_2d_body_entered(body) -> void:
	interactable = true
func _on_area_2d_body_exited(body) -> void:
	interactable = false
func _on_area_2d_area_entered(area: Area2D) -> void:
	interactable = true
func _on_area_2d_area_exited(area: Area2D) -> void:
	interactable = false
