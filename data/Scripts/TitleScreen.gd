## TitleScreen.gd
## Pantalla de inicio estilo Cave Story.
##
## ─── Integración ─────────────────────────────────────────────────────
##   Añadir como hijo del nodo raíz, o como Autoload de tipo CanvasLayer.
##   Se activa automáticamente en _ready().
##
## ─── Menú principal ──────────────────────────────────────────────────
##   ▶  Nuevo Juego  →  Selector de slot  →  new_game(slot)
##      Continuar    →  Selector de slot  →  load_game(slot)
##      Salir        →  get_tree().quit()
##
## ─── Comportamiento del jugador ──────────────────────────────────────
##   Al abrir  : Globals.playerStay = true  /  player.visible = false
##   Al cerrar : Globals.playerStay = false /  player.visible = true
##
## ─── Señales de audio opcionales ─────────────────────────────────────
##   Agrega hijos AudioStreamPlayer llamados:
##     CursorSFX, ConfirmSFX, CancelSFX
##   Si no existen, el menú funciona igualmente sin audio.
##
## ─── Señal de inicio ─────────────────────────────────────────────────
##   game_started(slot: int, is_new: bool)
##   Conecta esta señal para cargar el mapa inicial en nuevo juego.

extends CanvasLayer

signal game_started(slot: int, is_new: bool)

# ── Recursos ───────────────────────────────────────────────────────────
const FONT_PATH := "res://data/Fonts/monogatari.ttf"

# ── Paleta estilo Cave Story ───────────────────────────────────────────
const C_BG          := Color(0.04, 0.04, 0.09, 1.0)
const C_PANEL       := Color(0.06, 0.06, 0.14, 0.98)
const C_BORDER      := Color(0.25, 0.25, 0.55, 1.0)
const C_SELECTED    := Color(1.00, 0.85, 0.20, 1.0)   # amarillo Cave Story
const C_NORMAL      := Color(1.00, 1.00, 1.00, 1.0)
const C_DIM         := Color(0.45, 0.45, 0.45, 1.0)
const C_SUBTITLE    := Color(0.65, 0.70, 1.00, 1.0)
const C_SLOT_EMPTY  := Color(0.35, 0.35, 0.35, 1.0)
const C_SLOT_ACTIVE := Color(0.55, 1.00, 0.60, 1.0)   # verde para slot ocupado
const C_SEP         := Color(0.20, 0.20, 0.40, 1.0)

# ── Estado del menú ────────────────────────────────────────────────────
enum MenuState { MAIN, SLOTS }

var _state       : MenuState = MenuState.MAIN
var _cursor      : int       = 0
var _is_new_game : bool      = false
var _open        : bool      = false

# ── Fuente ────────────────────────────────────────────────────────────
var _font : Font = null

# ── Nodos UI (generados por código) ───────────────────────────────────
var _full_bg      : ColorRect
var _panel        : PanelContainer
var _title_lbl    : Label
var _main_vbox    : VBoxContainer
var _slots_vbox   : VBoxContainer

# ── Audio ─────────────────────────────────────────────────────────────
var _sfx_cursor  : AudioStreamPlayer = null
var _sfx_confirm : AudioStreamPlayer = null
var _sfx_cancel  : AudioStreamPlayer = null

# ── Opciones ──────────────────────────────────────────────────────────
const MAIN_OPTIONS := ["Nuevo Juego", "Continuar", "Salir"]
const SLOT_COUNT   := 3


# ═══════════════════════════════════════════════════════════════════════
# ─── INICIALIZACIÓN ───────────────────────────────────────────────────

func _ready() -> void:
	layer = 50   # por encima del inventario (layer 20)
	_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	_build_ui()
	_find_sfx()
	show_menu()


func _find_sfx() -> void:
	_sfx_cursor  = get_node_or_null("CursorSFX")
	_sfx_confirm = get_node_or_null("ConfirmSFX")
	_sfx_cancel  = get_node_or_null("CancelSFX")


# ═══════════════════════════════════════════════════════════════════════
# ─── MOSTRAR / OCULTAR ────────────────────────────────────────────────

## Abre la pantalla de título.
func show_menu() -> void:
	_open   = true
	_state  = MenuState.MAIN
	_cursor = 0
	_lock_player(true)
	_full_bg.show()
	_panel.show()
	_refresh()


## Cierra la pantalla de título y libera al jugador.
func hide_menu() -> void:
	_open = false
	_full_bg.hide()
	_panel.hide()
	_lock_player(false)


# Inmoviliza/libera al jugador y lo hace visible/invisible
func _lock_player(locked: bool) -> void:
	Globals.playerStay = locked

	# También bloquear playerPlayable para que no se procese nada del jugador
	if "playerPlayable" in Globals:
		Globals.playerPlayable = not locked

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.visible = not locked


# ═══════════════════════════════════════════════════════════════════════
# ─── INPUT ────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _open:
		return
	_handle_input()


func _handle_input() -> void:
	var list_size : int = MAIN_OPTIONS.size() if _state == MenuState.MAIN else SLOT_COUNT

	# ── Navegación vertical ────────────────────────────────────────────
	if Input.is_action_just_pressed("Up"):
		_cursor = (_cursor - 1 + list_size) % list_size
		_play(_sfx_cursor)
		_refresh()

	elif Input.is_action_just_pressed("Down"):
		_cursor = (_cursor + 1) % list_size
		_play(_sfx_cursor)
		_refresh()

	# ── Confirmar ──────────────────────────────────────────────────────
	elif Input.is_action_just_pressed("Accept") \
		or Input.is_action_just_pressed("Jump"):
		_play(_sfx_confirm)
		_confirm()

	# ── Cancelar / Volver ──────────────────────────────────────────────
	elif Input.is_action_just_pressed("Back") \
		or (Input.is_action_just_pressed("Menu") and _state == MenuState.SLOTS):
		if _state == MenuState.SLOTS:
			_play(_sfx_cancel)
			_go_to_main()


func _confirm() -> void:
	match _state:
		MenuState.MAIN:
			match _cursor:
				0:   # ── Nuevo Juego ─────────────────────────────────
					_is_new_game = true
					_state       = MenuState.SLOTS
					_cursor      = _best_empty_slot()
					_refresh()

				1:   # ── Continuar ───────────────────────────────────
					if _any_save_exists():
						_is_new_game = false
						_state       = MenuState.SLOTS
						_cursor      = _best_used_slot()
						_refresh()
					# Si no hay guardados, no hace nada (opción gris)

				2:   # ── Salir ───────────────────────────────────────
					get_tree().quit()

		MenuState.SLOTS:
			var slot := _cursor

			if _is_new_game:
				_start_new_game(slot)
			else:
				# Solo cargar si el slot tiene datos
				if SaveSystem.slot_exists(slot):
					_load_game(slot)
				# Si el slot está vacío, no hacemos nada


func _go_to_main() -> void:
	_state  = MenuState.MAIN
	_cursor = 0
	_refresh()


# ═══════════════════════════════════════════════════════════════════════
# ─── LÓGICA DE SLOTS ──────────────────────────────────────────────────

func _any_save_exists() -> bool:
	for i in SLOT_COUNT:
		if SaveSystem.slot_exists(i):
			return true
	return false


func _best_empty_slot() -> int:
	for i in SLOT_COUNT:
		if not SaveSystem.slot_exists(i):
			return i
	return 0   # todos ocupados → slot 0 (para sobreescribir)


func _best_used_slot() -> int:
	for i in SLOT_COUNT:
		if SaveSystem.slot_exists(i):
			return i
	return 0


func _start_new_game(slot: int) -> void:
	SaveSystem.new_game(slot)
	emit_signal("game_started", slot, true)
	hide_menu()


func _load_game(slot: int) -> void:
	SaveSystem.load_game(slot)
	emit_signal("game_started", slot, false)
	hide_menu()


# ═══════════════════════════════════════════════════════════════════════
# ─── CONSTRUCCIÓN DE UI ───────────────────────────────────────────────

func _build_ui() -> void:
	# ── Fondo negro pantalla completa ─────────────────────────────────
	_full_bg           = ColorRect.new()
	_full_bg.color     = C_BG
	_full_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_full_bg)

	# ── Panel centrado ─────────────────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 290)

	# Offset manual para centrar (ancla = centro, offset desde el centro)
	_panel.anchor_left   = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -180
	_panel.offset_top    = -145
	_panel.offset_right  = 180
	_panel.offset_bottom = 145

	var style_panel := StyleBoxFlat.new()
	style_panel.bg_color    = C_PANEL
	style_panel.border_color = C_BORDER
	style_panel.set_border_width_all(2)
	style_panel.set_corner_radius_all(4)
	style_panel.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style_panel)
	add_child(_panel)

	# ── Layout interno ─────────────────────────────────────────────────
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(root_vbox)

	# Título
	_title_lbl = _lbl("— MOONTALE —", 22, C_NORMAL)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_title_lbl)

	# Línea separadora
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEP)
	root_vbox.add_child(sep)

	# ── Contenedor menú principal ───────────────────────────────────────
	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_main_vbox)

	# ── Contenedor selector de slots ───────────────────────────────────
	_slots_vbox = VBoxContainer.new()
	_slots_vbox.add_theme_constant_override("separation", 8)
	_slots_vbox.hide()
	root_vbox.add_child(_slots_vbox)


# ═══════════════════════════════════════════════════════════════════════
# ─── RENDER ───────────────────────────────────────────────────────────

func _refresh() -> void:
	_build_main_menu()
	_build_slot_menu()

	if _state == MenuState.MAIN:
		_main_vbox.show()
		_slots_vbox.hide()
	else:
		_main_vbox.hide()
		_slots_vbox.show()


func _build_main_menu() -> void:
	for c in _main_vbox.get_children():
		c.queue_free()

	var continue_disabled : bool = not _any_save_exists()

	for i in MAIN_OPTIONS.size():
		var sel      : bool  = (i == _cursor and _state == MenuState.MAIN)
		var disabled : bool  = (i == 1 and continue_disabled)
		var txt      : String = MAIN_OPTIONS[i]

		var color : Color
		if sel and not disabled:
			color = C_SELECTED
		elif disabled:
			color = C_DIM
		else:
			color = C_NORMAL

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_lbl("▶ " if sel else "  ", 20, C_SELECTED))
		row.add_child(_lbl(txt, 20, color))
		_main_vbox.add_child(row)


func _build_slot_menu() -> void:
	for c in _slots_vbox.get_children():
		c.queue_free()

	var header : String = "Nuevo Juego — Elige slot" if _is_new_game else "Continuar — Elige archivo"
	var header_lbl := _lbl(header, 14, C_SUBTITLE)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots_vbox.add_child(header_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEP)
	_slots_vbox.add_child(sep)

	for i in SLOT_COUNT:
		var sel    : bool = (i == _cursor and _state == MenuState.SLOTS)
		var exists : bool = SaveSystem.slot_exists(i)
		var info   : Dictionary = SaveSystem.get_slot_info(i)

		# Agrupar en una columna por slot
		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)

		# Fila principal del slot
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 6)
		slot_vbox.add_child(top_row)

		# Cursor
		top_row.add_child(_lbl("▶ " if sel else "  ", 18, C_SELECTED))

		# Etiqueta del slot
		var slot_color : Color
		if not _is_new_game and not exists:
			slot_color = C_DIM
		elif sel:
			slot_color = C_SELECTED
		elif exists:
			slot_color = C_SLOT_ACTIVE
		else:
			slot_color = C_SLOT_EMPTY

		top_row.add_child(_lbl("ARCHIVO %d" % (i + 1), 18, slot_color))

		# Información del guardado (si existe)
		if exists and info.size() > 0:
			var ts_txt  : String = info.get("timestamp", "").left(16)
			var map_txt : String = info.get("map_name", "???")
			var hp_txt  : String = "HP %d/%d" % [info.get("hp", 0), info.get("max_hp", 0)]
			var meta    : String = "   %s  %s  %s" % [map_txt, hp_txt, ts_txt]
			top_row.add_child(_lbl(meta, 12, C_DIM if not sel else C_SUBTITLE))

		elif not exists:
			top_row.add_child(_lbl("   — vacío —", 14, C_DIM))

		# Línea separadora delgada entre slots
		var slot_sep := HSeparator.new()
		slot_sep.add_theme_color_override("color", Color(C_SEP, 0.5))
		slot_vbox.add_child(slot_sep)

		_slots_vbox.add_child(slot_vbox)

	# Instrucción de cancelar
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 4)
	hint_row.add_child(_lbl("[ Back ] Volver", 12, C_DIM))
	_slots_vbox.add_child(hint_row)


# ═══════════════════════════════════════════════════════════════════════
# ─── HELPERS ──────────────────────────────────────────────────────────

func _lbl(txt: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _play(sfx: AudioStreamPlayer) -> void:
	if sfx != null and sfx.stream != null and not sfx.playing:
		sfx.play()
