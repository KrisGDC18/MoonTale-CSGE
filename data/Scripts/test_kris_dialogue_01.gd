extends NpcBase

@onready var dialog_box = get_tree().get_first_node_in_group("dialog_box")
@onready var anim: AnimatedSprite2D = $Body

var dialogo : Dictionary = {
	"inicio": [
		{
			"speaker": "Kris:",
			"text_valignment": VERTICAL_ALIGNMENT_CENTER,
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"portrait_side": "right",
			"text": "Hola! Que tal [color=red]Kiruma[/color]? Que te gustaria hacer?",
			"choices": ["[color=red]Dame un arma[/color]", "[color=yellow]Guardar la partida[/color]", "Dame el Booster 2.0", "Nada"],
			"target_blocks": ["armeria", "guardar", "booster", ""]
		}
	],
	"armeria": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Que arma quieres?",
			"choices": ["Polar Star", "Spur", "Ninguna"],
			"target_blocks": ["dar_polar", "dar_spur", ""]
		}
	],
	"dar_polar": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Aqui tienes.",
			"action": func(): _give_weapon(preload("res://data/Entities/Weapons/PolarStar.tscn"))
		}
	],
	"dar_spur": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Aqui tienes.",
			"action": func(): _give_weapon(preload("res://data/Entities/Weapons/Spur.tscn"))
		}
	],
	"guardar": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "He guardado tu partida.",
			"action": func(): SaveSystem.save_game(SaveSystem.current_slot)
		}
	],
	"booster": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"item_texture": preload("res://data/Sprites/Items/Jetpack_Upgraded.png"),
			"text": "Aqui tienes el Booster 2.0.",
			"action": func(): _give_item(preload("res://data/Items/jetpack2.tres"))
		}
	],
}

func _ready():
	anim.play("idle")

func _physics_process(_delta: float):
	if Input.is_action_just_pressed("Down") and interactable and !Globals.playerStay:
		dialog_box.start(dialogo, "inicio")
