extends NpcBase

@onready var dialog_box = get_tree().get_first_node_in_group("dialog_box")
@onready var anim: AnimatedSprite2D = $Body

var dialogo : Dictionary = {
	"inicio": [
		{
			"speaker": "Kris:",
			"voice": "Kiruma",
			"text_valignment": VERTICAL_ALIGNMENT_CENTER,
			"windowskin_visible": false,
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"portrait_side": "right",
			"text": "Hola! Que tal [color=red][wave intensity=500][speed=2]Kiruma[/wave][/speed][/color]? Que te gustaria [rainbow spread=1.0 speed=2]hacer[/rainbow]?",
			"choices": ["[color=red]Dame un arma[/color]", "[color=yellow]Guardar la partida[/color]", "Dame el Booster 2.0", "Test de pagina", "Nada"],
			"target_blocks": ["armeria", "guardar", "booster", "Test de pagina", ""]
		}
	],
	"armeria": [
		{
			"voice": "Kiruma",
			"speaker": "Kris:",  
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Que arma quieres?",
			"choices": ["Star-Gun", "Stelar-Gun", "Fireball", "Machine Gun", "Ninguna"],
			"target_blocks": ["dar_polar", "dar_spur", "dar_fireball", "dar_machinegun", ""]
		}
	],
	"dar_polar": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Aqui tienes.",
			"item_texture": preload("res://data/Sprites/Weapons/Laser.png"),
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
	"dar_machinegun": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Aqui tienes.",
			"action": func(): _give_weapon(preload("res://data/Entities/Weapons/machinegun.tscn"))
		}
	],
	"dar_fireball": [
		{
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Aqui tienes.",
			"action": func(): _give_weapon(preload("res://data/Entities/Weapons/fireball.tscn"))
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
	"Test de pagina": [
		{
			"voice": "Kiruma",
			"speaker": "Kris:",
			"portrait": preload("res://data/Sprites/Faces/Kris.png"),
			"text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse dignissim finibus justo, ac finibus libero tincidunt quis. Ut varius varius augue, ullamcorper aliquet dui. Vivamus odio augue, rutrum id pharetra vitae, condimentum sit amet ligula. Sed vel nisi in nisi euismod sodales. Suspendisse varius condimentum sapien eu molestie. Nulla laoreet, dui nec cursus feugiat, mi sapien dictum sem, id ultrices est mauris quis mi. In non finibus ipsum, ac dapibus nisl. Fusce consectetur arcu eget nulla dapibus, sed rhoncus velit auctor. Praesent nulla nisl, pretium sit amet turpis id, pellentesque volutpat est. Maecenas commodo facilisis ipsum. ",
		}
	],
}

func _ready():
	anim.play("idle")

func _physics_process(_delta: float):
	
	if Input.is_action_just_pressed("Down") and interactable and !Globals.playerStay and player.is_on_floor():
		dialog_box.start(dialogo, "inicio")
