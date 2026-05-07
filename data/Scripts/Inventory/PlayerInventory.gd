extends Node

signal inventory_changed
signal weapon_changed(weapon)

# ── Armas ──────────────────────────────────────────────────────────────
var weapons         : Array  = []   # lista de WeaponData
var weapon_index    : int    = 0    # arma actualmente equipada

# ── Items ──────────────────────────────────────────────────────────────
# { "id": { "item": ItemData, "count": int } }
var items           : Dictionary = {}

# ── Equipo ─────────────────────────────────────────────────────────────
var equipped        : Dictionary = {}  # { "slot": ItemData }


# ── API Armas ──────────────────────────────────────────────────────────
func add_weapon(weapon) -> void:
	for w in weapons:
		if w.id == weapon.id:
			return  # ya la tiene
	weapons.append(weapon)
	emit_signal("inventory_changed")


func remove_weapon(weapon_id: String) -> void:
	for i in weapons.size():
		if weapons[i].id == weapon_id:
			weapons.remove_at(i)
			weapon_index = clamp(weapon_index, 0, weapons.size() - 1)
			emit_signal("inventory_changed")
			return


func next_weapon() -> void:
	if weapons.is_empty():
		return
	weapon_index = (weapon_index + 1) % weapons.size()
	emit_signal("weapon_changed", get_current_weapon())


func prev_weapon() -> void:
	if weapons.is_empty():
		return
	weapon_index = (weapon_index - 1 + weapons.size()) % weapons.size()
	emit_signal("weapon_changed", get_current_weapon())


func get_current_weapon():
	if weapons.is_empty():
		return null
	return weapons[weapon_index]


func add_weapon_exp(weapon_id: String, amount: int) -> void:
	for w in weapons:
		if w.id == weapon_id:
			w.add_exp(amount)
			emit_signal("inventory_changed")
			return


# ── API Items ──────────────────────────────────────────────────────────
func add_item(item, amount: int = 1) -> void:
	if items.has(item.id):
		items[item.id]["count"] = min(items[item.id]["count"] + amount, item.max_stack)
	else:
		items[item.id] = { "item": item, "count": amount }
	emit_signal("inventory_changed")


func remove_item(item_id: String, amount: int = 1) -> void:
	if not items.has(item_id):
		return
	items[item_id]["count"] -= amount
	if items[item_id]["count"] <= 0:
		items.erase(item_id)
	emit_signal("inventory_changed")


func use_item(item_id: String) -> void:
	if not items.has(item_id):
		return
	var item = items[item_id]["item"]
	if item.on_use.is_valid():
		item.on_use.call()
	if item.type == 0:  # CONSUMABLE
		remove_item(item_id)


# ── API Equipo ─────────────────────────────────────────────────────────
func equip(slot: String, item) -> void:
	equipped[slot] = item
	emit_signal("inventory_changed")


func unequip(slot: String) -> void:
	equipped.erase(slot)
	emit_signal("inventory_changed")


func get_equipped(slot: String):
	return equipped.get(slot, null)
