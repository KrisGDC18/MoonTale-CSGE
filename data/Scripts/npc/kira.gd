extends NpcBase

@onready var dialog_box = get_tree().get_first_node_in_group("dialog_box")
@onready var anim: AnimatedSprite2D = $Body

var dialogo : Dictionary = {
	"inicio": [
		{
			"speaker": "Kira:",
			"portrait": preload("res://data/animated_faces/kira.tres"),
			"portrait_emotions": {
				"default": { "talk": "talk",  "idle": "idle" },
			},
			"portrait_emotion": "default",
			"portrait_side": "right",
			"text": "Uhm... Necisitas ayuda con tus heridas, [color=red]Sakamoto[/color]?",
			"choices": ["Curar", "No"],
			"target_blocks": ["Curar", ""]
		}
	],
	"Curar": [ 
		{
			"action": func(): player.fullHealth(),
			"speaker": "Kira:",
			"portrait": preload("res://data/animated_faces/kira.tres"),
			"portrait_emotions": {
				"default": { "talk": "talk",  "idle": "idle" },
			},
			"portrait_emotion": "default",
			"portrait_side": "right",
			"text": "Tus heridas ahora estan curadas... Porfavor , ten cuidado.",
			
		}
	],
}

func _ready():
	anim.play("idle") 

func _physics_process(_delta: float):
	if Input.is_action_just_pressed("Down") and interactable and !Globals.playerStay and player.is_on_floor():
		player.trigger_npc_interact_jump(true)
		await player.npc_interact_jump_finished
		dialog_box.start(dialogo, "inicio")
