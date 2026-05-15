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
signal closed()              # cerrar → volver al origen (inventario o título)
signal closed_to_game()      # Back desde settings con origen inventario → cerrar todo

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
	{ "action": "Up",          "label": "Arriba"        },
	{ "action": "Down",        "label": "Abajo"         },
	{ "action": "Left",        "label": "Izquierda"     },
	{ "action": "Right",       "label": "Derecha"       },
	{ "action": "Jump",        "label": "Saltar"        },
	{ "action": "Fire",        "label": "Disparar"      },
	{ "action": "Weapon-", "label": "Arma -"        },
	{ "action": "Weapon+",  "label": "Arma +"        },
	{ "action": "Map",         "label": "Mapa"          },
	{ "action": "Accept",      "label": "Aceptar"       },
	{ "action": "Back",        "label": "Cancelar"      },
	{ "action": "Menu",        "label": "Menú"          },
	{ "action": "MenuC-",      "label": "Opciones ←"    },
	{ "action": "MenuC+",      "label": "Opciones →"    },
]

# ── Secciones ─────────────────────────────────────────────────────────
enum Section { AUDIO, SCREEN, CONTROLS }
const SECTION_NAMES := ["AUDIO", "PANTALLA", "CONTROLES"]

# ── Filas por sección ─────────────────────────────────────────────────
# AUDIO:   0=Música  1=SFX
# SCREEN:  0=Brillo
# CONTROLS:0-N según REMAPPABLE

# ── Estado ────────────────────────────────────────────────────────────
var _open             : bool    = false
var _section          : Section = Section.AUDIO
var _row              : int     = 0
var _waiting_remap    : bool    = false   # esperando input para remap
var _confirm_reset    : bool    = false   # mostrando diálogo de confirmación
var _origin           : String  = ""      # "inventory", "title" u ""

# Tecla de emergencia — nunca remapeable, siempre activa en controles
const RESET_KEY := KEY_DELETE

# ── Valores ───────────────────────────────────────────────────────────
var _vol_music  : float = 100.0   # 0–100
var _vol_sfx    : float = 100.0
var _brightness : float = 100.0   # 0–100

# ── Font ──────────────────────────────────────────────────────────────
var _font : Font = null

# ── Referencia al AudioManager ────────────────────────────────────────
var _audio_manager : Node = null

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
	_load_settings()         # carga valores en variables (buses aún no disponibles)
	_build_ui()
	_build_brightness_overlay()  # crea el overlay ANTES de aplicar brillo
	_apply_brightness()          # ahora sí existe _brightness_overlay
	hide()
	call_deferred("_connect_audio_manager")  # empuja valores al AudioManager cuando esté listo


func _connect_audio_manager() -> void:
	_audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if _audio_manager == null:
		push_warning("[SettingsMenu] AudioManager no encontrado.")
		return
	# Empujar los valores cargados desde settings.cfg al AudioManager.
	# NO leer del manager (siempre arranca en 1.0 y sobreescribiría las prefs guardadas).
	_audio_manager.set_music_volume(_vol_music / 100.0)
	_audio_manager.set_sfx_volume(_vol_sfx   / 100.0)


# ═══════════════════════════════════════════════════════════════════════
# ─── API PÚBLICA ──────────────────────────────────────────────────────

func open(origin: String = "") -> void:
	_open          = true
	_origin        = origin
	_section       = Section.AUDIO
	_row           = 0
	_waiting_remap = false
	_confirm_reset = false
	Globals.playerStay = true
	# Cuando se abre desde la pantalla de título, el fondo debe ser
	# completamente opaco para tapar el mapa del juego que hay detrás.
	# Desde el inventario en partida, se mantiene semitransparente.
	if _origin == "title":
		_full_bg.color = Color(C_BG.r, C_BG.g, C_BG.b, 1.0)
	else:
		_full_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	show()
	_refresh()


func close() -> void:
	_open = false
	_save_settings()
	hide()
	# Si el origen es inventario, playerStay lo gestiona el InventoryMenu
	if _origin == "":
		Globals.playerStay = false
	emit_signal("closed")


# Cierra el settings y además indica que hay que cerrar el inventario.
func close_to_game() -> void:
	_open   = false
	_origin = ""
	_save_settings()
	hide()
	# El InventoryMenu llamará _close_menu() que libera playerStay
	emit_signal("closed_to_game")


# ═══════════════════════════════════════════════════════════════════════
# ─── INPUT ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _open:
		return

	# ── Tecla de emergencia: Delete siempre intercepta ────────────────
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == RESET_KEY:
			if not _confirm_reset:
				_confirm_reset = true
				_waiting_remap = false
				_refresh()
			get_viewport().set_input_as_handled()
			return

	# ── Diálogo de confirmación — navegación hardcodeada ─────────────
	if _confirm_reset:
		if event is InputEventKey and event.pressed and not event.is_echo():
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_Y:
					_do_reset()
					get_viewport().set_input_as_handled()
				KEY_ESCAPE, KEY_BACKSPACE, KEY_N:
					_confirm_reset = false
					_refresh()
					get_viewport().set_input_as_handled()
		return

	# ── Modo remapeo: detecta automáticamente el tipo de entrada ──────
	if _waiting_remap:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == RESET_KEY:
				return   # Delete bloqueado como remapeo
			_assign_remap(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			_assign_remap(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
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
	elif event.is_action_pressed("MenuC-") and _origin == "inventory":
		# Volver al inventario
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Back"):
		if _origin == "inventory":
			# Cerrar settings + inventario → volver al juego
			close_to_game()
		else:
			close()
		get_viewport().set_input_as_handled()
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
					_save_settings()
				1:
					_vol_sfx = clamp(_vol_sfx + dir * step, 0.0, 100.0)
					_apply_audio()
					_save_settings()
		Section.SCREEN:
			_brightness = clamp(_brightness + dir * step, 0.0, 100.0)
			_apply_brightness()
	_refresh()


# ── Confirmar fila ────────────────────────────────────────────────────

func _confirm_row() -> void:
	if _section == Section.CONTROLS:
		_waiting_remap = true
		_refresh()


# ── Asignar remap ─────────────────────────────────────────────────────

func _assign_remap(event: InputEvent) -> void:
	var action : String = REMAPPABLE[_row]["action"]
	var old_events := InputMap.action_get_events(action)

	if event is InputEventKey:
		# Solo limpiar eventos de teclado anteriores
		for e in old_events:
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Solo limpiar eventos de mando anteriores
		for e in old_events:
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(action, e)

	InputMap.action_add_event(action, event)
	_waiting_remap = false
	_save_settings()
	_refresh()


# ── Reset al mapping por defecto ──────────────────────────────────────

func _do_reset() -> void:
	InputMap.load_from_project_settings()
	_confirm_reset = false
	_save_settings()
	_refresh()


# ═══════════════════════════════════════════════════════════════════════
# ─── APLICAR VALORES ──────────────────────────────────────────────────

func _apply_audio() -> void:
	if _audio_manager != null:
		_audio_manager.set_music_volume(_vol_music / 100.0)
		_audio_manager.set_sfx_volume(_vol_sfx   / 100.0)
	else:
		# Fallback directo al bus si AudioManager no está disponible
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

	for entry in REMAPPABLE:
		var action : String = entry["action"]
		var events := InputMap.action_get_events(action)
		var keys   : Array  = []
		var pad_btns : Array = []
		var pad_axes : Array = []

		for e in events:
			if e is InputEventKey:
				var kc : int = e.keycode if e.keycode != 0 else e.physical_keycode
				keys.append(kc)
			elif e is InputEventJoypadButton:
				pad_btns.append(e.button_index)
			elif e is InputEventJoypadMotion:
				pad_axes.append({ "axis": e.axis, "value": e.axis_value })

		cfg.set_value("controls_kbd", action, keys)
		cfg.set_value("controls_pad", action + "_btn",  pad_btns)
		cfg.set_value("controls_pad", action + "_axis", pad_axes)

	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	_vol_music  = cfg.get_value("audio",  "vol_music",  100.0)
	_vol_sfx    = cfg.get_value("audio",  "vol_sfx",    100.0)
	_brightness = cfg.get_value("screen", "brightness", 100.0)

	# Aplicar al bus directamente (el AudioManager aún no está listo en _ready).
	# _connect_audio_manager() lo reenviará al manager en el siguiente frame.
	_set_bus_volume(BUS_MUSIC, _vol_music)
	_set_bus_volume(BUS_SFX,   _vol_sfx)

	for entry in REMAPPABLE:
		var action : String = entry["action"]

		# ── Teclado ───────────────────────────────────────────────────
		if cfg.has_section_key("controls_kbd", action):
			var keys : Array = cfg.get_value("controls_kbd", action, [])
			if not keys.is_empty():
				var old := InputMap.action_get_events(action)
				for e in old:
					if e is InputEventKey:
						InputMap.action_erase_event(action, e)
				for kc in keys:
					var ev      := InputEventKey.new()
					ev.keycode   = kc
					InputMap.action_add_event(action, ev)

		# ── Mando — botones ───────────────────────────────────────────
		if cfg.has_section_key("controls_pad", action + "_btn"):
			var btns : Array = cfg.get_value("controls_pad", action + "_btn", [])
			if not btns.is_empty():
				var old := InputMap.action_get_events(action)
				for e in old:
					if e is InputEventJoypadButton:
						InputMap.action_erase_event(action, e)
				for idx in btns:
					var ev           := InputEventJoypadButton.new()
					ev.button_index   = idx
					InputMap.action_add_event(action, ev)

		# ── Mando — ejes ──────────────────────────────────────────────
		if cfg.has_section_key("controls_pad", action + "_axis"):
			var axes : Array = cfg.get_value("controls_pad", action + "_axis", [])
			if not axes.is_empty():
				var old := InputMap.action_get_events(action)
				for e in old:
					if e is InputEventJoypadMotion:
						InputMap.action_erase_event(action, e)
				for ax in axes:
					var ev        := InputEventJoypadMotion.new()
					ev.axis        = ax["axis"]
					ev.axis_value  = ax["value"]
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
	# ── Diálogo de confirmación de reset ──────────────────────────────
	if _confirm_reset:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		box.alignment             = BoxContainer.ALIGNMENT_CENTER

		var warn := _lbl("⚠ RESETEAR CONTROLES ⚠", 17, C_REMAP_W)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(warn)

		var msg1 := _lbl("Todos los controles volverán", 14, C_NORMAL)
		msg1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(msg1)

		var msg2 := _lbl("a sus valores originales.", 14, C_NORMAL)
		msg2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(msg2)

		var sep := HSeparator.new()
		sep.add_theme_color_override("color", C_SEP)
		box.add_child(sep)

		var confirm_lbl := _lbl("[ Enter / Y ]  Confirmar reset", 14, C_REMAP_OK)
		confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(confirm_lbl)

		var cancel_lbl := _lbl("[ Esc / N ]  Cancelar", 14, C_DIM)
		cancel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cancel_lbl)

		var sep2 := HSeparator.new()
		sep2.add_theme_color_override("color", C_SEP)
		box.add_child(sep2)

		var note := _lbl("(Teclas hardcodeadas — siempre funcionan)", 11, C_DIM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)

		_content_box.add_child(box)
		return

	if _waiting_remap:
		var hint := _lbl("Presiona una tecla o botón del mando…", 15, C_REMAP_W)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_box.add_child(hint)

	# Cabecera de columnas
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var h1 := _lbl("   ACCIÓN", 12, C_SUBTITLE)
	h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h2 := _lbl("TECLADO", 12, C_SUBTITLE)
	h2.custom_minimum_size = Vector2(70, 0)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h3 := _lbl("MANDO", 12, C_SUBTITLE)
	h3.custom_minimum_size = Vector2(70, 0)
	h3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(h1)
	header.add_child(h2)
	header.add_child(h3)
	_content_box.add_child(header)

	for i in REMAPPABLE.size():
		var entry  : Dictionary = REMAPPABLE[i]
		var action : String     = entry["action"]
		var label  : String     = entry["label"]
		var sel    : bool       = (i == _row)

		var kbd_name : String = _get_kbd_name(action)
		var pad_name : String = _get_pad_name(action)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var cursor_lbl := _lbl("▶ " if sel else "  ", 14, C_SELECTED)
		row.add_child(cursor_lbl)

		var action_lbl := _lbl(label, 14, C_SELECTED if sel else C_NORMAL)
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_lbl)

		# Columna teclado
		var kbd_color : Color = C_REMAP_W if (sel and _waiting_remap) else (C_REMAP_OK if sel else C_DIM)
		var kbd_lbl := _lbl(kbd_name, 13, kbd_color)
		kbd_lbl.custom_minimum_size  = Vector2(70, 0)
		kbd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(kbd_lbl)

		# Columna mando
		var pad_color : Color = C_REMAP_W if (sel and _waiting_remap) else (C_REMAP_OK if sel else C_DIM)
		var pad_lbl := _lbl(pad_name, 13, pad_color)
		pad_lbl.custom_minimum_size  = Vector2(70, 0)
		pad_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(pad_lbl)

		_content_box.add_child(row)

	# Hint de controles
	var hint2 := _lbl("[Accept] Remap   tecla=teclado   botón=mando      [Delete] Reset", 11, C_DIM)
	hint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_box.add_child(hint2)


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
	# Usar anchor_right proporcional: así el fill se escala con el contenedor
	# sin depender del tamaño real del nodo (que aún no existe al construirlo).
	bar_fill.anchor_left   = 0.0
	bar_fill.anchor_top    = 0.0
	bar_fill.anchor_right  = value / 100.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.offset_right  = 0.0
	bar_container.add_child(bar_fill)
	row.add_child(bar_container)

	var val_lbl := _lbl("%d%%" % int(value), 16, C_SELECTED if sel else C_DIM)
	val_lbl.custom_minimum_size = Vector2(45, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	_content_box.add_child(row)


# ═══════════════════════════════════════════════════════════════════════
# ─── HELPERS ──────────────────────────────────────────────────────────

func _get_kbd_name(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var kc : int = e.keycode if e.keycode != 0 else e.physical_keycode
			if kc != 0:
				return OS.get_keycode_string(kc)
	return "---"


func _get_pad_name(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return "Btn %d" % e.button_index
		elif e is InputEventJoypadMotion:
			var dir : String = "+" if e.axis_value > 0 else "-"
			return "Axis%d%s" % [e.axis, dir]
	return "---"


func _lbl(txt: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
