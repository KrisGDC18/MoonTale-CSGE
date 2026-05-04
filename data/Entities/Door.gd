extends Sprite2D

var interactable = false

# Ruta del archivo de la escena a la que se navegará al interactuar.
# Se asigna desde el Inspector de Godot.
@export var next_scene_path: String

# Array exportable con la posición destino del jugador en la nueva escena.
# Formato: [x, y] — se asigna desde el Inspector de Godot.
# Ejemplo: [150.0, 200.0] colocará al jugador en x=150, y=200 al llegar.
@export var pos_Change: Array

func _ready():
	pass

@warning_ignore("unused_parameter")
func _process(delta):
	# Si el jugador presiona "Down" estando en el área de este objeto,
	# se ejecuta el cambio de escena.
	if Input.is_action_just_pressed("Down") and interactable:
		change_scene()

# Se activa cuando un área entra en contacto con el Area2D de este objeto.
# Habilita la interacción para que el jugador pueda usar el portal/puerta.
@warning_ignore("unused_parameter")
func _on_area_2d_area_entered(area):
	interactable = true

# Se activa cuando un área sale del Area2D de este objeto.
# Deshabilita la interacción para evitar cambios de escena accidentales.
@warning_ignore("unused_parameter")
func _on_area_2d_area_exited(area):
	interactable = false

func change_scene():
	# Guarda en Globals la posición destino antes de cambiar de escena.
	# Convierte los dos valores del array pos_Change en un Vector2
	# para que la nueva escena pueda leerlo y reposicionar al jugador.

	# Cambia a la escena indicada en next_scene_path.
	# La nueva escena debe leer Globals.player_spawn_pos en su _ready()
	# y aplicarlo a la posición del nodo del jugador.
	get_tree().change_scene_to_file(next_scene_path)
	player.position = Vector2(pos_Change[0], pos_Change[1])
