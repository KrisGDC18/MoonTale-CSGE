extends CharacterBody2D

var interactable                 = false
# Referencia al nodo DialogBox en tu escena
@onready var dialog : CanvasLayer = $DialogBox

func _ready():
	pass

func _physics_process(delta: float):
	if Input.is_action_just_pressed("Down") and interactable:
		print("Hola Mundo de Mootale, soy yo Kris!")
		_on_interact()
		

func _on_interact() -> void:
	var pages = [
		{"speaker": "Kris", "text": "¡Hola Moontale! Esto es una prueba."},
		{"speaker": "Test", "text": "¿Funciona el sistema?",
		"choices": ["Sí", "No"], "targets": [2, 2]},
		{"speaker": "Test", "text": "¡Perfecto!"},
	]
	dialog.start(pages)


func _on_area_2d_body_entered(body) -> void:
	interactable = true
func _on_area_2d_body_exited(body) -> void:
	interactable = false
func _on_area_2d_area_entered(area: Area2D) -> void:
	interactable = true
func _on_area_2d_area_exited(area: Area2D) -> void:
	interactable = false
