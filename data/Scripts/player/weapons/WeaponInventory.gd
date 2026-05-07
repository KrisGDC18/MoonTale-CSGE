extends CanvasLayer

@onready var panel       : Panel         = $Panel
@onready var weapon_list : HBoxContainer = $Panel/WeaponList
@onready var arrow_left  : Label         = $Panel/ArrowLeft
@onready var arrow_right : Label         = $Panel/ArrowRight
@onready var weapon_name : Label         = $Panel/WeaponName
@onready var exp_bar     : ProgressBar   = $Panel/ExpBar
@onready var level_label : Label         = $Panel/LevelLabel
@onready var item_list   : VBoxContainer = $Panel/ItemList
@onready var slot_head   : TextureRect   = $Panel/EquipPanel/SlotHead
@onready var slot_body   : TextureRect   = $Panel/EquipPanel/SlotBody
@onready var slot_acc    : TextureRect   = $Panel/EquipPanel/SlotAcc

var _open : bool = false


func _ready() -> void:
	panel.hide()
	PlayerInventory.inventory_changed.connect(_refresh)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Menu"):
		if _open:
			_close()
		else:
			_open_inv()

	if _open:
		if Input.is_action_just_pressed("Left"):
			PlayerInventory.prev_weapon()
			_refresh()
		elif Input.is_action_just_pressed("Right"):
			PlayerInventory.next_weapon()
			_refresh()


func _open_inv() -> void:
	_open = true
	panel.show()
	Globals.playerStay = true
	_refresh()


func _close() -> void:
	_open = false
	panel.hide()
	Globals.playerStay = false


func _refresh() -> void:
	_refresh_weapons()
	_refresh_items()
	_refresh_equip()


func _refresh_weapons() -> void:
	for child in weapon_list.get_children():
		child.free()

	for i in PlayerInventory.weapons.size():
		var w    = PlayerInventory.weapons[i]
		var icon := TextureRect.new()
		icon.texture        = w.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# resalta el arma activa
		if i == PlayerInventory.weapon_index:
			icon.modulate = Color(1, 1, 1, 1)
		else:
			icon.modulate = Color(0.4, 0.4, 0.4, 1)
		weapon_list.add_child(icon)

	var current = PlayerInventory.get_current_weapon()
	if current:
		weapon_name.text  = current.name
		level_label.text  = "Lv " + str(current.current_level)
		exp_bar.value     = current.get_exp_progress() * 100.0
		arrow_left.visible  = PlayerInventory.weapons.size() > 1
		arrow_right.visible = PlayerInventory.weapons.size() > 1
	else:
		weapon_name.text    = ""
		level_label.text    = ""
		exp_bar.value       = 0
		arrow_left.visible  = false
		arrow_right.visible = false


func _refresh_items() -> void:
	for child in item_list.get_children():
		child.free()

	for entry in PlayerInventory.items.values():
		var lbl      := Label.new()
		lbl.text      = entry["item"].name + "  x" + str(entry["count"])
		item_list.add_child(lbl)


func _refresh_equip() -> void:
	var head = PlayerInventory.get_equipped("head")
	var body = PlayerInventory.get_equipped("body")
	var acc  = PlayerInventory.get_equipped("acc")
	slot_head.texture = head.icon if head else null
	slot_body.texture = body.icon if body else null
	slot_acc.texture  = acc.icon  if acc  else null
