## InventoryMenu.gd
## Menú de inventario estilo Cave Story.
##
## Sección ARMS  → lee instancias Weapon del WeaponManager (weapon_name, icon,
##                  current_level, current_xp, xp_to_level, max_level)
## Sección ITEMS → lee key_items del PlayerInventory
##
## Al seleccionar se muestra la descripción en el DialogBox existente.
## Tecla "Inventory" abre y cierra el menú.
extends CanvasLayer

# ── Referencias externas ────────────────────────────────────────────────
@onready var dialog_box  : CanvasLayer   = get_tree().get_first_node_in_group("dialog_box")

# ── Nodos propios ───────────────────────────────────────────────────────
@onready var panel       : Control        = $Panel
@onready var arms_list   : VBoxContainer  = $Panel/MarginContainer/HSplit/ArmsSection/ArmsList
@onready var items_list  : VBoxContainer  = $Panel/MarginContainer/HSplit/ItemsSection/ItemsList
@onready var cursor_sfx  : AudioStreamPlayer = $CursorSFX
@onready var confirm_sfx : AudioStreamPlayer = $ConfirmSFX
@onready var close_sfx   : AudioStreamPlayer = $CloseSFX

# ── Estado ──────────────────────────────────────────────────────────────
var _open           : bool = false
var _section        : int  = 0   # 0 = ARMS  |  1 = ITEMS
var _row            : int  = 0

var _weapon_manager : Node = null   # WeaponManager
var _inventory      : Node = null   # PlayerInventory (solo key_items)

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

	# WeaponManager — registrado en grupo "weapon_manager"
	_weapon_manager = get_tree().get_first_node_in_group("weapon_manager")

	# PlayerInventory — para key items
	_inventory = get_tree().get_first_node_in_group("player_inventory")
	if _inventory == null:
		_inventory = get_node_or_null("/root/PlayerInventory")
	if _inventory:
		_inventory.inventory_changed.connect(_refresh)


# ── Helpers: listas activas ─────────────────────────────────────────────

func _weapons_list() -> Array:
	if _weapon_manager == null:
		return []
	return _weapon_manager._weapons   # Array de instancias Weapon (Node2D)


func _key_items_list() -> Array:
	if _inventory == null:
		return []
	return _inventory.key_items.values()


func _current_list() -> Array:
	return _weapons_list() if _section == 0 else _key_items_list()


# ── Process ─────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Menu"):
		if _open: _close_menu()
		else:     _open_menu()
		return

	if not _open:
		return

	_handle_input()


# ── Abrir / Cerrar ──────────────────────────────────────────────────────

func _open_menu() -> void:
	_open    = true
	_section = 0
	_row     = 0
	Globals.playerStay = true
	_refresh()
	panel.show()


func _close_menu() -> void:
	_open = false
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

## Fila de arma — usa los campos de Weapon.gd directamente
func _make_arm_row(weapon: Node2D, selected: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	# ▶ cursor
	hbox.add_child(_label("▶ " if selected else "  ", 18,
			COLOR_SELECTED if selected else COLOR_NORMAL))

	# Ícono (campo icon : Texture2D en Weapon.gd)
	if weapon.icon:
		var icon := TextureRect.new()
		icon.texture = weapon.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)

	# Nombre
	var name_lbl := _label(weapon.weapon_name, 18,
			COLOR_SELECTED if selected else COLOR_NORMAL)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# Nivel con color
	var lv        : int          = weapon.current_level
	var lv_colors : Array[Color] = [COLOR_LV1, COLOR_LV2, COLOR_LV3]
	var lv_color  : Color        = lv_colors[clamp(lv - 1, 0, 2)]
	hbox.add_child(_label("Lv%d" % lv, 16, lv_color))

	# Barra de EXP (solo si no está en nivel máximo)
	if lv < weapon.max_level:
		vbox.add_child(_make_exp_bar(weapon))

	return vbox


## Barra de EXP usando campos de Weapon.gd:
##   current_xp  : int
##   xp_to_level : Array[int]  — xp_to_level[current_level] es el tope del nivel actual
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
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

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

	return hbox


func _label(txt: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# ── Selección → DialogBox ───────────────────────────────────────────────

func _select_current() -> void:
	if confirm_sfx: confirm_sfx.play()

	var title : String = ""
	var desc  : String = ""

	if _section == 0:
		var weapons := _weapons_list()
		if _row < weapons.size():
			var w : Node2D = weapons[_row]
			title = w.weapon_name
			# Si Weapon tiene campo "description" úsalo; si no, lo generamos
			var custom_desc = w.get("description")
			if custom_desc != null and not str(custom_desc).is_empty():
				desc = str(custom_desc)
			else:
				var xp_needed : int = 0
				if w.current_level < w.xp_to_level.size():
					xp_needed = w.xp_to_level[w.current_level]
				if w.current_level >= w.max_level:
					desc = "Nivel MAX"
				else:
					desc = "Nivel %d  |  EXP: %d / %d" % [
						w.current_level, w.current_xp, xp_needed
					]
	else:
		var keys := _key_items_list()
		if _row < keys.size():
			title = keys[_row].name
			desc  = keys[_row].description

	if desc.is_empty():
		return

	if dialog_box and dialog_box.has_method("start"):
		_close_menu()
		dialog_box.start([{
			"speaker": title,
			"text":    desc,
		}])
