## InventoryMenu.gd
## Menú de inventario estilo Cave Story.
##
## Sección ARMS  → lee instancias Weapon del WeaponManager (weapon_name, icon,
##                  current_level, current_xp, xp_to_level, max_level)
## Sección ITEMS → lee key_items del PlayerInventory
##
## Al seleccionar un ítem se consulta ItemDialogRegistry por su id.
## El inventario se mantiene de fondo mientras el DialogBox está activo.
## Tecla "Menu" abre y cierra el menú.
extends CanvasLayer

# ── Referencias externas ────────────────────────────────────────────────
var dialog_box : CanvasLayer = null
@onready var _item_dialog_reg : Node        = get_node_or_null("/root/ItemDialogRegistry")

# ── Nodos propios ───────────────────────────────────────────────────────
@onready var panel       : Control        = $Panel
@onready var arms_list   : VBoxContainer  = $Panel/MarginContainer/HSplit/ArmsSection/ArmsList
@onready var items_list  : VBoxContainer  = $Panel/MarginContainer/HSplit/ItemsSection/ItemsList
@onready var cursor_sfx  : AudioStreamPlayer = $CursorSFX
@onready var confirm_sfx : AudioStreamPlayer = $ConfirmSFX
@onready var close_sfx   : AudioStreamPlayer = $CloseSFX

# ── Estado ──────────────────────────────────────────────────────────────
var _open           : bool = false
var _dialog_active  : bool = false
var _section        : int  = 0
var _row            : int  = 0

var _weapon_manager : Node = null
var _inventory      : Node = null

# ── Paleta estilo Cave Story ────────────────────────────────────────────
const COLOR_SELECTED  := Color(1.0,  0.85, 0.2)
const COLOR_NORMAL    := Color(1.0,  1.0,  1.0)
const COLOR_DIM       := Color(0.6,  0.6,  0.6)
const COLOR_EXP_FILL  := Color(0.2,  0.8,  1.0)
const COLOR_EXP_EMPTY := Color(0.15, 0.15, 0.3)
const COLOR_LV1       := Color(0.6,  0.6,  1.0)
const COLOR_LV2       := Color(0.4,  1.0,  0.4)
const COLOR_LV3       := Color(1.0,  0.5,  0.2)

const FONT := preload("res://data/Fonts/monogatari.ttf")


# ── Init ────────────────────────────────────────────────────────────────

func _ready() -> void:
	panel.hide()
	layer = 20
	print("[InventoryMenu] _ready — dialog_box: ", dialog_box)
	print("[InventoryMenu] _ready — _item_dialog_reg: ", _item_dialog_reg)


func _resolve_refs() -> void:
	if dialog_box == null:
		dialog_box = get_tree().get_first_node_in_group("dialog_box")
		if dialog_box == null:
			dialog_box = get_node_or_null("/root/DialogBox")
		print("[InventoryMenu] dialog_box resuelto: ", dialog_box)
	if _weapon_manager == null:
		_weapon_manager = get_tree().get_first_node_in_group("weapon_manager")

	if _inventory == null:
		_inventory = get_tree().get_first_node_in_group("player_inventory")
		if _inventory == null:
			_inventory = get_node_or_null("/root/PlayerInventory")
		if _inventory and not _inventory.inventory_changed.is_connected(_refresh):
			_inventory.inventory_changed.connect(_refresh)


# ── Helpers: listas activas ─────────────────────────────────────────────

func _weapons_list() -> Array:
	if _weapon_manager == null:
		return []
	return _weapon_manager._weapons

func _key_items_list() -> Array:
	if _inventory == null:
		return []
	return _inventory.key_items.values()

func _current_list() -> Array:
	return _weapons_list() if _section == 0 else _key_items_list()


# ── Process ─────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Menu") and not _dialog_active:
		if Globals.playerStay:
			return
		if _open: _close_menu()
		else:     _open_menu()
		return

	if not _open or _dialog_active:
		return

	_handle_input()


# ── Abrir / Cerrar ──────────────────────────────────────────────────────

func _open_menu() -> void:
	_resolve_refs()
	_open           = true
	_dialog_active  = false
	_section        = 0
	_row            = 0
	Globals.playerStay = true
	_refresh()
	panel.show()


func _close_menu() -> void:
	_open          = false
	_dialog_active = false
	panel.hide()
	Globals.playerStay = false
	if close_sfx: close_sfx.play()


# ── Input ───────────────────────────────────────────────────────────────

func _handle_input() -> void:
	var list := _current_list()

	if Input.is_action_just_pressed("Left") or Input.is_action_just_pressed("Right"):
		_section = 1 - _section
		_row     = 0
		if cursor_sfx: cursor_sfx.play()
		_highlight()

	elif Input.is_action_just_pressed("Up"):
		if list.size() > 0:
			_row = (_row - 1 + list.size()) % list.size()
			if cursor_sfx: cursor_sfx.play()
			_highlight()

	elif Input.is_action_just_pressed("Down"):
		if list.size() > 0:
			_row = (_row + 1) % list.size()
			if cursor_sfx: cursor_sfx.play()
			_highlight()

	elif Input.is_action_just_pressed("Accept"):
		_select_current()

	elif Input.is_action_just_pressed("Back"):
		_close_menu()


# ── Render ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _open:
		return
	_build_arms()
	_build_items()


func _highlight() -> void:
	_build_arms()
	_build_items()


func _build_arms() -> void:
	for c in arms_list.get_children():
		c.queue_free()

	var weapons := _weapons_list()
	for i in weapons.size():
		var weapon : Node2D = weapons[i]
		var selected : bool = (i == _row and _section == 0)
		arms_list.add_child(_make_arm_row(weapon, selected))


func _build_items() -> void:
	for c in items_list.get_children():
		c.queue_free()

	var keys := _key_items_list()
	for i in keys.size():
		var selected : bool = (i == _row and _section == 1)
		items_list.add_child(_make_item_row(keys[i], selected))


# ── Constructores de filas ──────────────────────────────────────────────

func _make_arm_row(weapon: Node2D, selected: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	hbox.add_child(_label("▶ " if selected else "  ", 18,
			COLOR_SELECTED if selected else COLOR_NORMAL))

	if weapon.icon:
		var icon := TextureRect.new()
		icon.texture = weapon.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)

	var name_lbl := _label(weapon.weapon_name, 18,
			COLOR_SELECTED if selected else COLOR_NORMAL)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var lv        : int          = weapon.current_level
	var lv_colors : Array[Color] = [COLOR_LV1, COLOR_LV2, COLOR_LV3]
	var lv_color  : Color        = lv_colors[clamp(lv - 1, 0, 2)]
	hbox.add_child(_label("Lv%d" % lv, 16, lv_color))

	if lv < weapon.max_level:
		vbox.add_child(_make_exp_bar(weapon))

	return vbox


func _make_exp_bar(weapon: Node2D) -> ProgressBar:
	var lv     : int = weapon.current_level
	var xp_max : int = weapon.xp_to_level[lv] if lv < weapon.xp_to_level.size() else 1
	var xp_cur : int = weapon.current_xp

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(xp_max, 1)
	bar.value     = xp_cur
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false

	var style_bg   := StyleBoxFlat.new()
	style_bg.bg_color = COLOR_EXP_EMPTY
	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = COLOR_EXP_FILL
	bar.add_theme_stylebox_override("background", style_bg)
	bar.add_theme_stylebox_override("fill", style_fill)

	return bar


func _make_item_row(item_data, selected: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	hbox.add_child(_label("▶ " if selected else "  ", 18,
			COLOR_SELECTED if selected else COLOR_NORMAL))

	if item_data.icon:
		var icon := TextureRect.new()
		icon.texture = item_data.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)

	hbox.add_child(_label(item_data.name, 18,
			COLOR_SELECTED if selected else COLOR_NORMAL))

	if selected and not item_data.description.is_empty():
		var desc := _label(item_data.description, 14, COLOR_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc)

	return vbox


func _label(txt: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# ── Selección ───────────────────────────────────────────────────────────

func _select_current() -> void:
	print("[InventoryMenu] _select_current — section: ", _section, "  row: ", _row)
	if confirm_sfx: confirm_sfx.play()

	if _section == 0:
		var weapons := _weapons_list()
		if _row >= weapons.size():
			return
		# Equipar el arma seleccionada y cerrar el inventario
		if _weapon_manager != null:
			_weapon_manager._equip(_row)
		_close_menu()

	else:
		var keys := _key_items_list()
		print("[InventoryMenu] key_items_list size: ", keys.size())
		if _row < keys.size():
			_use_item(keys[_row])
		else:
			print("[InventoryMenu] _row fuera de rango: ", _row)


func _use_item(item) -> void:
	if _dialog_active:
		return
	print("[InventoryMenu] _use_item — item.id: '", item.id, "'  item.name: '", item.name, "'")
	print("[InventoryMenu] _item_dialog_reg: ", _item_dialog_reg)
	print("[InventoryMenu] dialog_box: ", dialog_box)

	var pages  : Array    = []
	var on_use : Callable = Callable()

	if _item_dialog_reg != null:
		var tiene : bool = _item_dialog_reg.has(item.id)
		print("[InventoryMenu] registry.has('", item.id, "'): ", tiene)
		if tiene:
			pages  = _item_dialog_reg.get_pages(item.id)
			on_use = _item_dialog_reg.get_on_use(item.id)
			print("[InventoryMenu] pages del registry: ", pages.size(), " páginas")
	else:
		print("[InventoryMenu] ERROR: _item_dialog_reg es null — ¿está registrado el Autoload?")

	if pages.is_empty():
		pages = [{"speaker": item.name, "text": item.description}]
		print("[InventoryMenu] usando fallback — description: '", item.description, "'")

	if not on_use.is_valid() and item.on_use.is_valid():
		on_use = item.on_use

	var db_ok : bool = dialog_box != null and dialog_box.has_method("start")
	print("[InventoryMenu] dialog_box disponible: ", db_ok)

	if db_ok:
		_dialog_active = true
		# Desconectar cualquier conexión previa para evitar doble disparo
		if dialog_box.dialog_finished.is_connected(_on_dialog_closed):
			dialog_box.dialog_finished.disconnect(_on_dialog_closed)

		var captured_item   = item
		var captured_on_use = on_use
		var conn : Callable = func():
			print("[InventoryMenu] dialog_finished recibido")
			if captured_on_use.is_valid():
				captured_on_use.call()
			if captured_item.type == ItemData.Type.MISC:
				PlayerInventory.remove_key_item(captured_item.id)
				_row = clamp(_row, 0, max(0, _key_items_list().size() - 1))
			_on_dialog_closed()
		dialog_box.dialog_finished.connect(conn, CONNECT_ONE_SHOT)
		# El nuevo DialogBox espera un Dictionary de bloques y un bloque inicial.
		# Convertimos el Array de páginas plano al formato { "main": [...] }.
		var blocks : Dictionary = { "main": pages }
		dialog_box.start(blocks, "main", false)
		print("[InventoryMenu] dialog_box.start() llamado")
	else:
		print("[InventoryMenu] sin dialog_box — ejecutando on_use directo")
		if on_use.is_valid():
			on_use.call()
		if item.type == ItemData.Type.MISC:
			PlayerInventory.remove_key_item(item.id)
			_row = clamp(_row, 0, max(0, _key_items_list().size() - 1))
			_refresh()


func _on_dialog_closed() -> void:
	print("[InventoryMenu] _on_dialog_closed — volviendo al inventario")
	print("[InventoryMenu] _on_dialog_closed — _dialog_active era: ", _dialog_active)
	await get_tree().process_frame
	_dialog_active     = false
	Globals.playerStay = true
	_refresh()
