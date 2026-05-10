## SettingsMenu.gd
## Menú de configuración estilo Cave Story.
##
## ─── Secciones ────────────────────────────────────────────────────────
##   AUDIO    → Volumen Música / Volumen SFX  (sliders 0–100)
##   PANTALLA → Brillo                        (slider 0–100)
##   CONTROLES→ Remapping de acciones         (reasignar teclas)
##
## ─── Integración ──────────────────────────────────────────────────────
##   Añadir como hijo del CanvasLayer de TitleScreen en Game.tscn.
##   TitleScreen llama open() / close() según corresponda.
##
## ─── Guardado ─────────────────────────────────────────────────────────
##   user://settings.cfg  (ConfigFile)
##   Se aplica automáticamente al iniciar (_ready) y al cambiar valores.

extends CanvasLayer

# ── Señal ─────────────────────────────────────────────────────────────
signal closed()

# ── Recursos ──────────────────────────────────────────────────────────
const FONT_PATH    := "res://data/Fonts/monogatari.ttf"
const SETTINGS_PATH := "user://settings.cfg"

# ── Paleta (igual que TitleScreen) ────────────────────────────────────
const C_BG       := Color(0.04, 0.04, 0.09, 1.0)
const C_PANEL    := Color(0.06, 0.06, 0.14, 0.98)
const C_BORDER   := Color(0.25, 0.25, 0.55, 1.0)
const C_SELECTED := Color(1.00, 0.85, 0.20, 1.0)
const C_NORMAL   := Color(1.00, 1.00, 1.00, 1.0)
const C_DIM      := Color(0.45, 0.45, 0.45, 1.0)
const C_SUBTITLE := Color(0.65, 0.70, 1.00, 1.0)
const C_SEP      := Color(0.20, 0.20, 0.40, 1.0)
const C_BAR_FILL := Color(0.30, 0.60, 1.00, 1.0)
const C_BAR_EMPTY:= Color(0.15, 0.15, 0.30, 1.0)
const C_REMAP_OK := Color(0.40, 1.00, 0.50, 1.0)
const C_REMAP_W  := Color(1.00, 0.60, 0.10, 1.0)

# ── Buses de audio ────────────────────────────────────────────────────
const BUS_MUSIC := "Music"
const BUS_SFX   := "SFX"

# ── Acciones remapeables ──────────────────────────────────────────────
const REMAPPABLE := [
	{ "action": "Up",     "label": "Arriba"    },
	{ "action": "Down",   "label": "Abajo"     },
	{ "action": "Left",   "label": "Izquierda" },
	{ "action": "Right",  "label": "Derecha"   },
	{ "action": "Jump",   "label": "Saltar"    },
	{ "action": "Accept", "label": "Aceptar"   },
	{ "action": "Back",   "label": "Cancelar"  },
	{ "action": "Menu",   "label": "Menú"      },
]

# ── Secciones ─────────────────────────────────────────────────────────
enum Section { AUDIO, SCREEN, CONTROLS }
const SECTION_NAMES := ["AUDIO", "PANTALLA", "CONTROLES"]

# ── Filas por sección ─────────────────────────────────────────────────
# AUDIO:   0=Música  1=SFX
# SCREEN:  0=Brillo
# CONTROLS:0-N según REMAPPABLE

# ── Estado ────────────────────────────────────────────────────────────
var _open          : bool    = false
var _section       : Section = Section.AUDIO
var _row           : int     = 0
var _waiting_remap : bool    = false   # esperando tecla para remap

# ── Valores ───────────────────────────────────────────────────────────
var _vol_music  : float = 100.0   # 0–100
var _vol_sfx    : float = 100.0
var _brightness : float = 100.0   # 0–100

# ── Font ──────────────────────────────────────────────────────────────
var _font : Font = null

# ── Nodos UI ──────────────────────────────────────────────────────────
var _full_bg     : ColorRect
var _panel       : PanelContainer
var _tab_row     : HBoxContainer
var _content_box : VBoxContainer
var _brightness_overlay : ColorRect   # overlay negro para brillo


# ═══════════════════════════════════════════════════════════════════════
# ─── INIT ─────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 60   # sobre TitleScreen (layer 50)
	add_to_group("settings_menu")
	_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	_load_settings()
	_apply_audio()
	_build_ui()
	_build_brightness_overlay()
	_apply_brightness()
	hide()


# ═══════════════════════════════════════════════════════════════════════
# ─── API PÚBLICA ──────────────────────────────────────────────────────

func open() -> void:
	_open     = true
	_section  = Section.AUDIO
	_row      = 0
	_waiting_remap = false
	show()
	_refresh()


func close() -> void:
	_open = false
	_save_settings()
	hide()
	emit_signal("closed")


# ═══════════════════════════════════════════════════════════════════════
# ─── INPUT ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _open:
		return

	# ── Modo remapeo: espera cualquier tecla ──────────────────────────
	if _waiting_remap:
		if event is InputEventKey and event.pressed and not event.is_echo():
			_assign_remap(event)
			get_viewport().set_input_as_handled()
		return

	# ── Navegación normal ─────────────────────────────────────────────
	if event.is_action_pressed("Left"):
		_change_value(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Right"):
		_change_value(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Up"):
		_move_row(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Down"):
		_move_row(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Accept") or event.is_action_pressed("Jump"):
		_confirm_row()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Back"):
		close()
		get_viewport().set_input_as_handled()
	# Cambiar sección con Q/E (usar Left/Right en la fila de tabs)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			_change_section(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			_change_section(1)
			get_viewport().set_input_as_handled()


# ── Navegación ────────────────────────────────────────────────────────

func _move_row(dir: int) -> void:
	var max_rows := _row_count()
	_row = (_row + dir + max_rows) % max_rows
	_refresh()


func _change_section(dir: int) -> void:
	_section = (_section + dir + SECTION_NAMES.size()) % SECTION_NAMES.size() as Section
	_row     = 0
	_refresh()


func _row_count() -> int:
	match _section:
		Section.AUDIO:    return 2
		Section.SCREEN:   return 1
		Section.CONTROLS: return REMAPPABLE.size()
	return 0


# ── Cambiar valor (Left/Right) ────────────────────────────────────────

func _change_value(dir: int) -> void:
	var step := 5.0
	match _section:
		Section.AUDIO:
			match _row:
				0:
					_vol_music = clamp(_vol_music + dir * step, 0.0, 100.0)
					_apply_audio()
				1:
					_vol_sfx = clamp(_vol_sfx + dir * step, 0.0, 100.0)
					_apply_audio()
		Section.SCREEN:
			_brightness = clamp(_brightness + dir * step, 0.0, 100.0)
			_apply_brightness()
	_refresh()


# ── Confirmar fila (Accept en controles = iniciar remap) ──────────────

func _confirm_row() -> void:
	if _section == Section.CONTROLS:
		_waiting_remap = true
		_refresh()


# ── Asignar remap ─────────────────────────────────────────────────────

func _assign_remap(event: InputEventKey) -> void:
	var action : String = REMAPPABLE[_row]["action"]
	# Limpiar eventos de teclado anteriores
	var old_events := InputMap.action_get_events(action)
	for e in old_events:
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	_waiting_remap = false
	_save_settings()
	_refresh()


# ═══════════════════════════════════════════════════════════════════════
# ─── APLICAR VALORES ──────────────────────────────────────────────────

func _apply_audio() -> void:
	_set_bus_volume(BUS_MUSIC, _vol_music)
	_set_bus_volume(BUS_SFX,   _vol_sfx)


func _set_bus_volume(bus_name: String, pct: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if pct <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(pct / 100.0))


func _apply_brightness() -> void:
	if _brightness_overlay == null:
		return
	# 100 = transparente (sin oscurecer), 0 = negro total
	var alpha := 1.0 - (_brightness / 100.0)
	_brightness_overlay.color = Color(0.0, 0.0, 0.0, alpha)


# ═══════════════════════════════════════════════════════════════════════
# ─── GUARDAR / CARGAR ─────────────────────────────────────────────────

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio",  "vol_music",  _vol_music)
	cfg.set_value("audio",  "vol_sfx",    _vol_sfx)
	cfg.set_value("screen", "brightness", _brightness)

	# Guardar remapping
	for entry in REMAPPABLE:
		var action : String = entry["action"]
		var events := InputMap.action_get_events(action)
		var keys   : Array  = []
		for e in events:
			if e is InputEventKey:
				keys.append(e.keycode)
		cfg.set_value("controls", action, keys)

	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	_vol_music  = cfg.get_value("audio",  "vol_music",  100.0)
	_vol_sfx    = cfg.get_value("audio",  "vol_sfx",    100.0)
	_brightness = cfg.get_value("screen", "brightness", 100.0)

	# Restaurar remapping
	for entry in REMAPPABLE:
		var action : String = entry["action"]
		if not cfg.has_section_key("controls", action):
			continue
		var keys : Array = cfg.get_value("controls", action, [])
		if keys.is_empty():
			continue
		# Limpiar teclas actuales
		var old_events := InputMap.action_get_events(action)
		for e in old_events:
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		# Aplicar guardadas
		for kc in keys:
			var ev       := InputEventKey.new()
			ev.keycode    = kc
			InputMap.action_add_event(action, ev)


# ═══════════════════════════════════════════════════════════════════════
# ─── CONSTRUCCIÓN DE UI ───────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro semitransparente
	_full_bg              = ColorRect.new()
	_full_bg.color        = Color(0.0, 0.0, 0.0, 0.75)
	_full_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_full_bg)

	# Panel centrado
	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_top    = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left   = -220
	_panel.offset_top    = -200
	_panel.offset_right  =  220
	_panel.offset_bottom =  200
	_panel.custom_minimum_size = Vector2(440, 400)

	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(root_vbox)

	# Título del menú
	var title := _lbl("— CONFIGURACIÓN —", 18, C_NORMAL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	# Fila de tabs de sección
	_tab_row = HBoxContainer.new()
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row.add_theme_constant_override("separation", 24)
	root_vbox.add_child(_tab_row)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEP)
	root_vbox.add_child(sep)

	# Contenido dinámico
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 14)
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_box)

	# Hint inferior
	var hint := _lbl("[ ← → ] Cambiar valor    [ Q / E ] Sección    [ Back ] Cerrar", 11, C_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(hint)


func _build_brightness_overlay() -> void:
	# Overlay global de brillo — vive en el árbol raíz, no en este CanvasLayer
	_brightness_overlay        = ColorRect.new()
	_brightness_overlay.color  = Color(0.0, 0.0, 0.0, 0.0)
	_brightness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bl := CanvasLayer.new()
	bl.layer = 200   # encima de todo
	bl.add_child(_brightness_overlay)
	# Añadir al root para que persista fuera del menú
	get_tree().root.call_deferred("add_child", bl)


# ═══════════════════════════════════════════════════════════════════════
# ─── RENDER ───────────────────────────────────────────────────────────

func _refresh() -> void:
	_build_tabs()
	_build_content()


func _build_tabs() -> void:
	for c in _tab_row.get_children():
		c.queue_free()
	for i in SECTION_NAMES.size():
		var sel   : bool   = (i == _section)
		var color : Color  = C_SELECTED if sel else C_DIM
		var txt   : String = ("▶ " if sel else "") + SECTION_NAMES[i]
		_tab_row.add_child(_lbl(txt, 14, color))


func _build_content() -> void:
	for c in _content_box.get_children():
		c.queue_free()

	match _section:
		Section.AUDIO:    _build_audio()
		Section.SCREEN:   _build_screen()
		Section.CONTROLS: _build_controls()


func _build_audio() -> void:
	_add_slider_row("Música",   _vol_music, 0)
	_add_slider_row("Efectos",  _vol_sfx,   1)


func _build_screen() -> void:
	_add_slider_row("Brillo",   _brightness, 0)


func _build_controls() -> void:
	if _waiting_remap:
		var hint := _lbl("Presiona una tecla…", 16, C_REMAP_W)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_box.add_child(hint)

	for i in REMAPPABLE.size():
		var entry  : Dictionary = REMAPPABLE[i]
		var action : String     = entry["action"]
		var label  : String     = entry["label"]
		var sel    : bool       = (i == _row)

		# Obtener tecla actual
		var key_name := _get_key_name(action)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var cursor_lbl := _lbl("▶ " if sel else "  ", 15, C_SELECTED)
		row.add_child(cursor_lbl)

		var action_lbl := _lbl(label, 15, C_SELECTED if sel else C_NORMAL)
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_lbl)

		var key_color := C_REMAP_W if (sel and _waiting_remap) else (C_REMAP_OK if sel else C_DIM)
		var key_lbl   := _lbl(key_name, 15, key_color)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(key_lbl)

		_content_box.add_child(row)


func _add_slider_row(label: String, value: float, row_idx: int) -> void:
	var sel := (_row == row_idx)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var cursor_lbl := _lbl("▶ " if sel else "  ", 16, C_SELECTED)
	row.add_child(cursor_lbl)

	var name_lbl := _lbl(label, 16, C_SELECTED if sel else C_NORMAL)
	name_lbl.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_lbl)

	# Barra visual
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(160, 16)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar_bg := ColorRect.new()
	bar_bg.color = C_BAR_EMPTY
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.color = C_BAR_FILL if sel else C_BAR_FILL.darkened(0.3)
	bar_fill.anchor_left   = 0.0
	bar_fill.anchor_top    = 0.0
	bar_fill.anchor_right  = 0.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.offset_right  = (value / 100.0) * 160.0
	bar_container.add_child(bar_fill)
	row.add_child(bar_container)

	var val_lbl := _lbl("%d%%" % int(value), 16, C_SELECTED if sel else C_DIM)
	val_lbl.custom_minimum_size = Vector2(45, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	_content_box.add_child(row)


# ═══════════════════════════════════════════════════════════════════════
# ─── HELPERS ──────────────────────────────────────────────────────────

func _get_key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey:
			return OS.get_keycode_string(e.keycode)
	return "---"


func _lbl(txt: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
