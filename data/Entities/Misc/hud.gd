extends CanvasLayer

# ─── Referencias a los nodos del HUD ─────────────────────────────────
@onready var hp_bar     : ProgressBar        = $Control/hp_bar
@onready var hp_label   : Label              = $Control/hp_label
@onready var air_bar    : ProgressBar        = $Control/air_bar
@onready var air_label  : Label              = $Control/air_label
@onready var jet_bar    : ProgressBar        = $Control/jet_bar    # NUEVO: barra de jetpack
@onready var jet_label  : Label              = $Control/jet_label  # NUEVO: etiqueta de jetpack
@onready var hud_bg     : TextureRect        = $Control/hud_bg     # fondo normal
@onready var hud_bg2    : TextureRect        = $Control/hud_bg2    # NUEVO: fondo alternativo con jetpack

var _air_visible     := false
var _jet_visible     := false
var _player          : CharacterBody2D = null  # referencia cacheada al jugador


func _ready():
	# escuchar cuando el árbol de escena cambia para re-obtener al jugador
	# esto resuelve el problema de que el HUD pierda la referencia al cambiar de escena
	get_tree().node_added.connect(_on_node_added)
	_find_player()
	
	# ── Configurar fuente pixel art ────────────────────────────────────
	# descomenta estas líneas si tienes una fuente personalizada
	var font = load("res://data/Fonts/monogatari.ttf")
	hp_label.add_theme_font_override("font", font)
	hp_label.add_theme_font_size_override("font_size", 36)
	air_label.add_theme_font_override("font", font)
	air_label.add_theme_font_size_override("font_size", 36)
	jet_label.add_theme_font_override("font", font)
	jet_label.add_theme_font_size_override("font_size", 36)



func _on_node_added(node: Node) -> void:
	# cada vez que se añade un nodo al árbol verificar si es el jugador
	# node_added dispara para CADA nodo añadido, por eso filtramos por grupo
	if node.is_in_group("player"):
		_find_player()


func _find_player() -> void:
	# buscar al jugador en el árbol completo
	# call_deferred da un frame de margen para que el jugador termine su _ready()
	# y tenga todas sus variables inicializadas antes de que el HUD las lea
	call_deferred("_init_with_player")


func _init_with_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		push_error("HUD: no se encontró ningún nodo en el grupo 'player'")
		return

	# ── Configurar barra de vida ───────────────────────────────────────
	hp_bar.max_value     = _player.PLAYER_MAX_LIFE
	hp_bar.value         = _player.currentLife
	#hp_bar.tint_progress = Color(0.85, 0.1, 0.1)
	#hp_bar.tint_under    = Color(0.2,  0.2, 0.2)

	# ── Configurar barra de aire ───────────────────────────────────────
	air_bar.max_value     = _player.AIR_MAX
	air_bar.value         = _player.airSupply
	#air_bar.tint_progress = Color(0.2, 0.5, 0.9)
	#air_bar.tint_under    = Color(0.2, 0.2, 0.2)

	# ── Configurar barra de jetpack ───────────────────────────────────
	# jetpack_gas es el combustible actual
	# jetpack_equipped es la flag que controla visibilidad
	# si el jugador no tiene esas variables aún, get() devuelve null sin error
	var jet_max = _player.get("jetpack_gas_max")
	if jet_max != null:
		jet_bar.max_value = jet_max
	else:
		jet_bar.max_value = 100.0  # fallback si no existe jetpack_gas_max

	#jet_bar.tint_progress = Color(0.9, 0.7, 0.1)  # amarillo/naranja
	#jet_bar.tint_under    = Color(0.2, 0.2, 0.2)

	# ── Ocultar barras opcionales al inicio ───────────────────────────
	air_bar.visible = false
	air_label.visible = false
	jet_bar.visible = false
	jet_label.visible = false

	# forzar actualización visual inmediata para evitar flash de valores viejos
	_update_hp()
	_update_air()
	_update_jetpack()
	_update_backgrounds()


func _process(_delta):
	if _player == null:
		return

	_update_hp()
	_update_air()
	_update_jetpack()
	_update_backgrounds()


func _update_hp() -> void:
	hp_bar.value  = _player.currentLife
	hp_label.text = str(_player.currentLife)

	#if _player.currentLife <= 3:
		#hp_bar.tint_progress = Color(1.0, 0.3, 0.3)  # rojo alerta
	#else:
		#hp_bar.tint_progress = Color(0.85, 0.1, 0.1) # rojo normal


func _update_air() -> void:
	if _player.wamder != _air_visible:
		_air_visible      = _player.wamder
		air_bar.visible   = _air_visible
		air_label.visible = _air_visible

	if not _air_visible:
		return

	air_bar.value  = _player.airSupply
	air_label.text = "Air:  " + str(int(_player.airSupply))

	#if _player.airSupply <= 20:
		#air_bar.tint_progress = Color(1.0, 0.2, 0.2)
	#else:
		#air_bar.tint_progress = Color(0.2, 0.5, 0.9)


func _update_jetpack() -> void:
	# leer las variables del jugador con get() para no crashear si no existen
	var equipped : bool  = _player.get("jetpack_equipped") if _player.get("jetpack_equipped") != null else false
	var gas      : float = _player.get("jetpack_gas")      if _player.get("jetpack_gas")      != null else 0.0

	# mostrar u ocultar según la flag jetpack_equipped
	if equipped != _jet_visible:
		_jet_visible      = equipped
		jet_bar.visible   = _jet_visible
		jet_label.visible = _jet_visible

	if not _jet_visible:
		return

	jet_bar.value  = gas
	jet_label.text = str(int(gas))

	# color de alerta cuando el combustible es bajo
	#if gas <= jet_bar.max_value * 0.2:
		#jet_bar.tint_progress = Color(1.0, 0.3, 0.1)  # naranja alerta
	#else:
		#jet_bar.tint_progress = Color(0.9, 0.7, 0.1)  # amarillo normal


func _update_backgrounds() -> void:
	# NUEVO: cambiar el fondo del HUD según si el jetpack está equipado
	# hud_bg  → fondo normal (sin jetpack)
	# hud_bg2 → fondo alternativo (con jetpack, tiene espacio para la barra extra)
	var equipped : bool = _player.get("jetpack_equipped") if _player.get("jetpack_equipped") != null else false
	hud_bg.visible  = not equipped
	hud_bg2.visible = equipped
