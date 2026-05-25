extends Node  # este autoload es un Node global accesible desde cualquier script del proyecto

# ─── Variables globales del estado del juego ─────────────────────────
var playerPlayable = true        # controla si el jugador puede recibir input (false en cutscenes/diálogos)
var current_scene = null         # referencia al nodo de la escena/sala activa dentro del nivel
var LevelNode = null             # referencia al nodo contenedor de escenas del nivel actual
var GameRoot = null              # referencia al nodo raíz del juego (padre de LevelNode)
var playerInstance = null        # referencia directa al nodo del jugador instanciado en escena
var player_spawn_pos: Vector2 = Vector2.ZERO  # posición donde debe aparecer el jugador al cargar una escena
var fadeThing                    # referencia al nodo que maneja los efectos de fade (asignada externamente)
var small_room := false          # la escena activa la pone en true si es sala pequeña
								 # el sistema de cámara la lee para fijar la vista en el (0,0) mundial
var dan = false                  # flag de propósito general (pendiente de documentar)
var needs_fade_in := false       # true cuando una puerta hizo fade-out antes de cambiar escena
								 # la nueva escena lo lee en su _ready para lanzar el fade-in de entrada
var playerStay : bool = false
var music_paused : bool  = false  # true = música en pausa
var music_volume : float = 1.0    # 0.0 = silencio, 1.0 = máximo


# ─── Inicialización ───────────────────────────────────────────────────
func _ready():
	# obtener referencias a los nodos clave del árbol de escena al iniciar
	var root = get_tree().root
	LevelNode    = root.get_child(root.get_child_count() - 1).get_child(0)           # nodo contenedor de niveles
	current_scene = root.get_child(root.get_child_count() - 1).get_child(0).get_child(0)  # primera escena/sala activa
	GameRoot     = root.get_child(root.get_child_count() - 1)                         # nodo raíz del juego
	print(OS.get_name())
	print(OS.get_version())
	print(OS.get_processor_name())
	print(OS.has_feature("64"))
	var joypads = Input.get_connected_joypads()

	print("Mandos conectados:", joypads)

	for id in joypads:
		print("ID:", id)
		print("Nombre:", Input.get_joy_name(id))


func _process(delta):
	pass  # sin lógica por frame; reservado para uso futuro
