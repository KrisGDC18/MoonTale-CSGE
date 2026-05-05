extends Node

# opción A: instanciar desde la escena principal
var hud_scene = preload("res://data/Entities/Misc/HUD.tscn")


# opción B: añadirlo directamente en el editor como hijo de la escena raíz
# arrastra HUD.tscn al árbol de escena — es la forma más simple
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var hud = hud_scene.instantiate()
	add_child(hud)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
