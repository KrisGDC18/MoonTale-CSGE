extends NpcBase

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
			"text"     : "Que te gustaria hacer?",
			"choices"  : ["El 1.0", "Guardar Partida", "Ninguno", "Polar Star", "Booster 2.0"],
			"targets"  : [2, 2, 2, 3, 3],
			"actions"  : [
				func(): _activar_booster_1(),   # se ejecuta si elige opción 0
				func(): SaveSystem.save_game(SaveSystem.current_slot),   # se ejecuta si elige opción 1
				func(): _disable_booster(),     # no hace nada si elige opción 2
				func(): _give_weapon(preload("res://data/Entities/Weapons/PolarStar.tscn")),
				func(): _give_item(preload("res://data/Items/jetpack2.tres")),
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
