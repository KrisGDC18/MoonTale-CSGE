extends NpcBase

@onready var dialog_box = get_tree().get_first_node_in_group("dialog_box")
@onready var anim: AnimatedSprite2D = $Body

var dialogo : Dictionary = {
	"inicio": [
		{
			"speaker": "Dr. Karu:",
			"portrait": preload("res://data/Sprites/Faces/Karu_portrait.png"),
			"portrait_side": "right",
			"text": "Requiere algo joven [color=red]Sakamoto[/color]?",
			"choices": ["Guardar la partida", "Nada"],
			"target_blocks": ["guardar", ""]
		}
	],
	"guardar": [
		{
			"speaker": "Dr. Karu:",
			"portrait": preload("res://data/Sprites/Faces/Karu_portrait.png"),
			"text": "He guardado tu partida.",
			"action": func(): SaveSystem.save_game(SaveSystem.current_slot)
		}
	],
}

func _ready():
	anim.play("idle")

func _physics_process(_delta: float):
	if Input.is_action_just_pressed("Down") and interactable and !Globals.playerStay:
		dialog_box.start(dialogo, "inicio")
