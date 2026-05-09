extends CanvasLayer

# ─── Referencias a los nodos del HUD ─────────────────────────────────
@onready var hp_bar            : ProgressBar        = $Control/hp_bar
@onready var hp_label          : Label              = $Control/hp_label
@onready var air_bar           : ProgressBar        = $Control/air_bar
@onready var air_label         : Label              = $Control/air_label
@onready var jet_bar           : ProgressBar        = $Control/jet_bar
@onready var jet_label         : Label              = $Control/jet_label
@onready var hud_bg            : TextureRect        = $Control/hud_bg
@onready var hud_bg2           : TextureRect        = $Control/hud_bg2
@onready var ammo_total_label  : Label              = $Control/ammo_total_label
@onready var ammo_rest_label   : Label              = $Control/ammo_rest_label
@onready var xp_bar            : ProgressBar        = $Control/xp_bar
@onready var xp_label          : Label              = $Control/xp_label
@onready var xp_max_label      : Label              = $Control/xp_max_label
@onready var weapon_icon       : TextureRect        = $Control/weapon_icon

var _air_visible     := false
var _jet_visible     := false
var _player          : CharacterBody2D = null
var _current_weapon  : Node2D          = null


func _ready():
	# Escuchar cuando el árbol de escena cambia para re-obtener al jugador
	get_tree().node_added.connect(_on_node_added)
	_find_player()

	# ── Configurar fuente pixel art ────────────────────────────────────
	var font = load("res://data/Fonts/monogatari.ttf")
	xp_label.add_theme_font_override("font", font)
	xp_label.add_theme_font_size_override("font_size", 36)
	ammo_rest_label.add_theme_font_override("font", font)
	ammo_rest_label.add_theme_font_size_override("font_size", 36)
	ammo_total_label.add_theme_font_override("font", font)
	ammo_total_label.add_theme_font_size_override("font_size", 36)
	hp_label.add_theme_font_override("font", font)
	hp_label.add_theme_font_size_override("font_size", 36)
	air_label.add_theme_font_override("font", font)
	air_label.add_theme_font_size_override("font_size", 36)
	jet_label.add_theme_font_override("font", font)
	jet_label.add_theme_font_size_override("font_size", 36)
	xp_max_label.add_theme_font_override("font", font)
	xp_max_label.add_theme_font_size_override("font_size", 36)

	# ── Conectar al WeaponManager ─────────────────────────────────────
	# Se hace con call_deferred para dar un frame al jugador a que esté listo
	call_deferred("_connect_weapon_manager")


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_find_player()
		# Reconectar WeaponManager si el jugador se recargó (cambio de escena)
		call_deferred("_connect_weapon_manager")


func _find_player() -> void:
	call_deferred("_init_with_player")


func _init_with_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		push_error("HUD: no se encontró ningún nodo en el grupo 'player'")
		return

	# ── Configurar barra de vida ───────────────────────────────────────
	hp_bar.max_value = _player.PLAYER_MAX_LIFE
	hp_bar.value     = _player.currentLife

	# ── Configurar barra de aire ───────────────────────────────────────
	air_bar.max_value = _player.AIR_MAX
	air_bar.value     = _player.airSupply

	# ── Configurar barra de jetpack ───────────────────────────────────
	var jet_max = _player.get("jetpack_gas_max")
	if jet_max != null:
		jet_bar.max_value = jet_max
	else:
		jet_bar.max_value = 100.0

	# ── Ocultar barras opcionales al inicio ───────────────────────────
	air_bar.visible   = false
	air_label.visible = false
	jet_bar.visible   = false
	jet_label.visible = false

	# Forzar actualización visual inmediata
	_update_hp()
	_update_air()
	_update_jetpack()
	_update_backgrounds()


# ─── Conexión con WeaponManager ───────────────────────────────────────

func _connect_weapon_manager() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("HUD: no se encontró el jugador al conectar WeaponManager")
		return

	# Ajusta "WeaponManager" si el nodo tiene otro nombre en tu escena
	var wm : Node = player.get_node_or_null("WeaponManager")
	if wm == null:
		push_error("HUD: no se encontró WeaponManager como hijo del jugador")
		return

	# Evitar conectar la señal más de una vez (por cambios de escena)
	if not wm.weapon_changed.is_connected(_on_weapon_changed):
		wm.weapon_changed.connect(_on_weapon_changed)

	# Mostrar el icono del arma que ya está equipada al iniciar
	_on_weapon_changed(wm.get_current_weapon())


func _on_weapon_changed(weapon: Node2D) -> void:
	_current_weapon = weapon

	if weapon == null:
		weapon_icon.texture = load("res://data/Sprites/Weapons/None.png")
		weapon_icon.visible = false
		xp_bar.max_value = 1
		xp_bar.value     = 0
		xp_label.text    = "Lv.-"
		return

	# ── Ícono del arma ────────────────────────────────────────────────
	var tex : Texture2D = weapon.get("icon")
	if tex != null:
		weapon_icon.texture = tex
		weapon_icon.visible = true
		print("HUD: icono cargado -> ", weapon.name)
	else:
		weapon_icon.texture = load("res://data/Sprites/Weapons/None.png")
		weapon_icon.visible = false
		print("HUD: arma sin icono -> ", weapon.name)

	# ── Inicializar barra de XP con los valores del arma equipada ─────
	_update_xp()


# ─── Proceso ──────────────────────────────────────────────────────────

func _process(_delta):
	if _player == null:
		return

	_update_hp()
	_update_air()
	_update_jetpack()
	_update_backgrounds()
	_update_xp()


func _update_hp() -> void:
	hp_bar.value  = _player.currentLife
	hp_label.text = str(_player.currentLife)


func _update_air() -> void:
	if _player.wamder != _air_visible:
		_air_visible      = _player.wamder
		air_bar.visible   = _air_visible
		air_label.visible = _air_visible

	if not _air_visible:
		return

	air_bar.value  = _player.airSupply
	air_label.text = "Air:  " + str(int(_player.airSupply))


func _update_jetpack() -> void:
	var equipped : bool  = _player.get("jetpack_equipped") if _player.get("jetpack_equipped") != null else false
	var gas      : float = _player.get("jetpack_gas")      if _player.get("jetpack_gas")      != null else 0.0

	if equipped != _jet_visible:
		_jet_visible      = equipped
		jet_bar.visible   = _jet_visible
		jet_label.visible = _jet_visible

	if not _jet_visible:
		return

	jet_bar.value  = gas
	jet_label.text = str(int(gas))


func _update_xp() -> void:
	# Valores por defecto: sin arma
	if _current_weapon == null:
		xp_bar.max_value    = 1
		xp_bar.value        = 0
		xp_label.text       = "-"
		xp_label.visible    = true
		xp_max_label.visible = false
		return

	# ── Spur cargando: la barra muestra progreso de carga ─────────────
	if _current_weapon is Spur:
		var spur := _current_weapon as Spur
		if spur._is_charging:
			xp_bar.max_value = Spur.CHARGE_TIME_LV3
			xp_bar.value     = clamp(spur._charge_timer, 0.0, Spur.CHARGE_TIME_LV3)
			# Siempre muestra un número: mínimo 1, máximo 3
			xp_label.text        = str(clampi(max(1, spur._charge_level), 1, 3))
			xp_label.visible     = true
			xp_max_label.visible = spur._charge_level >= 3
			return

	# ── XP normal: cualquier arma (o Spur cuando no carga) ────────────
	var lvl        : int   = _current_weapon.get("current_level")
	var xp         : int   = _current_weapon.get("current_xp")
	var max_lvl    : int   = _current_weapon.get("max_level")
	var thresholds : Array = _current_weapon.get("xp_to_level")

	if lvl >= max_lvl:
		xp_bar.max_value     = 1
		xp_bar.value         = 1
		xp_label.visible     = false
		xp_max_label.visible = true
		return

	var needed : int     = thresholds[lvl] if lvl < thresholds.size() else 1
	xp_bar.max_value     = needed
	xp_bar.value         = xp
	xp_label.text        = str(lvl)
	xp_label.visible     = true
	xp_max_label.visible = false


func _update_backgrounds() -> void:
	var equipped : bool = _player.get("jetpack_equipped") if _player.get("jetpack_equipped") != null else false
	hud_bg.visible  = not equipped
	hud_bg2.visible = equipped
