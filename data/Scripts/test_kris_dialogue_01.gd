extends CharacterBody2D

var interactable                 = false
# Referencia al nodo DialogBox en tu escena
@onready var dialog : CanvasLayer = $DialogBox

func _ready():
	pass

func _physics_process(delta: float):
	if Input.is_action_just_pressed("Down") and interactable and !Globals.playerStay:
		print("Hola Mundo de Mootale, soy yo Kris!")
		_on_interact()
		

func _on_interact() -> void:
	var pages = [
		{
			"speaker"  : "Kris",
			"portrait" : preload("res://data/Sprites/Faces/Kris.png"),
			"text"     : "Hola Moontale!",
		},
		{
			"speaker"  : "Kris",
			"portrait" : preload("res://data/Sprites/Faces/Kris.png"),
			"text"     : "¿Quieres activar el Booster?",
			"choices"  : ["El 1.0", "El 2.0", "Ninguno", "item"],
			"targets"  : [2, 2, 2, 3],
			"actions"  : [
				func(): _activar_booster_1(),   # se ejecuta si elige opción 0
				func(): _activar_booster_2(),   # se ejecuta si elige opción 1
				func(): _disable_booster(),     # no hace nada si elige opción 2
				func(): _give_jet2(),
			]
		},
		{
			"speaker" : "Kris",
			"portrait" : preload("res://data/Sprites/Faces/Kris.png"),
			"text"    : "¡Listo!"
		},
		{
			"speaker" : "Kris",
			"portrait" : preload("res://data/Sprites/Faces/Kris.png"),
			"text"    : "¡Listo! esta en tu inventario"
		}
	]



	dialog.start(pages)
	await dialog.dialog_finished

func _give_jet2():
	var jet2 = preload("res://data/Items/jetpack2.tres")
	jet2.on_use = func():
		var player = get_tree().get_first_node_in_group("player")
		player.currentLife = min(player.currentLife + 4, player.PLAYER_MAX_LIFE)
	PlayerInventory.add_item(jet2)



func _activar_booster_1() -> void:
	# cambia variables, llama funciones, lo que necesites
	var player = get_tree().get_first_node_in_group("player")
	player.jetpack_equipped = true
	player.jetpack_upgrade = false
	print("Booster 1 activado")

func _activar_booster_2() -> void:
	var player = get_tree().get_first_node_in_group("player")
	player.jetpack_equipped = true
	player.jetpack_upgrade = true
	print("Booster 2 activado")
	
func _disable_booster() -> void:
	var player = get_tree().get_first_node_in_group("player")
	player.jetpack_equipped = false
	player.jetpack_upgrade = false
	print("desactivado")


func _on_area_2d_body_entered(body) -> void:
	interactable = true
func _on_area_2d_body_exited(body) -> void:
	interactable = false
func _on_area_2d_area_entered(area: Area2D) -> void:
	interactable = true
func _on_area_2d_area_exited(area: Area2D) -> void:
	interactable = false
