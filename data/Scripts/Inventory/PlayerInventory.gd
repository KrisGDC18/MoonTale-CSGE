## PlayerInventory — Sistema de inventario estilo Cave Story
##
## Cave Story NO tiene un inventario de items apilados ni slots de equipo.
## Lo que el jugador acumula es:
##   1. Armas  (máx. ~7, con nivel y EXP individual por arma)
##   2. Key items permanentes  (Map System, Booster 2.0, etc.)
##   3. Vida máxima (HP max se extiende con Life Capsules)
##
## Las armas tienen 3 niveles. La EXP de cada arma baja al recibir daño.
## Al morir el jugador pierde todos los niveles de todas las armas.
extends Node

signal inventory_changed
signal weapon_changed(weapon : WeaponState)
signal weapon_leveled_up(weapon : WeaponState)
signal weapon_leveled_down(weapon : WeaponState)

# ──────────────────────────────────────────────────────────────────────
# Clase interna: estado de un arma en el inventario
# ──────────────────────────────────────────────────────────────────────
class WeaponState:
	var data        : ItemData  ## recurso ItemData con tipo WEAPON
	var level       : int = 1   ## nivel actual (1–3)
	var current_exp : int = 0   ## EXP acumulada en el nivel actual
	var ammo        : int = 0   ## munición actual (0 si infinita)

	func _init(item_data: ItemData) -> void:
		data  = item_data
		level = 1
		current_exp = 0
		ammo  = item_data.max_ammo   # 0 = infinita

	## EXP necesaria para el siguiente nivel desde el nivel actual
	func exp_needed() -> int:
		match level:
			1: return data.exp_to_level2
			2: return data.exp_to_level3 - data.exp_to_level2
			_: return 0  # nivel 3 es el máximo

	## EXP total acumulada desde nivel 1
	func total_exp() -> int:
		var base := 0
		if level >= 2: base += data.exp_to_level2
		if level >= 3: base += data.exp_to_level3 - data.exp_to_level2
		return base + current_exp

	func is_max_level() -> bool:
		return level >= 3

	func get_damage() -> int:
		return data.damage[level - 1]

	func get_fire_rate() -> float:
		return data.fire_rate[level - 1]

# ──────────────────────────────────────────────────────────────────────
# Estado del inventario
# ──────────────────────────────────────────────────────────────────────

## Lista ordenada de WeaponState (el jugador cicla entre ellas)
var weapons      : Array[WeaponState] = []
var weapon_index : int = 0

## Key items permanentes: { id : ItemData }
var key_items    : Dictionary = {}

## Vida máxima del jugador (aumenta con Life Capsules)
var max_hp       : int = 3
var current_hp   : int = 3

# ──────────────────────────────────────────────────────────────────────
# API — Armas
# ──────────────────────────────────────────────────────────────────────

## Añade un arma si no la tiene ya. Devuelve el WeaponState creado o el existente.
func add_weapon(item_data: ItemData) -> WeaponState:
	for ws in weapons:
		if ws.data.id == item_data.id:
			return ws  # ya la tiene
	var ws := WeaponState.new(item_data)
	weapons.append(ws)
	emit_signal("inventory_changed")
	return ws


func remove_weapon(weapon_id: String) -> void:
	for i in weapons.size():
		if weapons[i].data.id == weapon_id:
			weapons.remove_at(i)
			weapon_index = clamp(weapon_index, 0, max(weapons.size() - 1, 0))
			emit_signal("inventory_changed")
			return


func get_current_weapon() -> WeaponState:
	if weapons.is_empty():
		return null
	return weapons[weapon_index]


func next_weapon() -> void:
	if weapons.size() < 2:
		return
	weapon_index = (weapon_index + 1) % weapons.size()
	emit_signal("weapon_changed", get_current_weapon())


func prev_weapon() -> void:
	if weapons.size() < 2:
		return
	weapon_index = (weapon_index - 1 + weapons.size()) % weapons.size()
	emit_signal("weapon_changed", get_current_weapon())


## Añade EXP al arma actualmente equipada.
## Sube de nivel automáticamente y emite weapon_leveled_up si corresponde.
func add_exp_to_current_weapon(amount: int) -> void:
	var ws := get_current_weapon()
	if ws == null or ws.is_max_level():
		return
	ws.current_exp += amount
	var leveled := false
	while not ws.is_max_level() and ws.current_exp >= ws.exp_needed():
		ws.current_exp -= ws.exp_needed()
		ws.level += 1
		leveled = true
		emit_signal("weapon_leveled_up", ws)
	emit_signal("inventory_changed")


## Quita EXP de TODAS las armas al recibir daño (comportamiento Cave Story).
## Si una arma baja de nivel emite weapon_leveled_down.
func penalize_exp_on_damage(amount: int) -> void:
	for ws in weapons:
		_subtract_exp(ws, amount)
	emit_signal("inventory_changed")


## Resetea todas las armas a nivel 1 con 0 EXP (al morir).
func reset_all_weapons() -> void:
	for ws in weapons:
		ws.level = 1
		ws.current_exp = 0
	emit_signal("inventory_changed")


# ── privado ────────────────────────────────────────────────────────────
func _subtract_exp(ws: WeaponState, amount: int) -> void:
	# Convertimos todo a EXP total, restamos y recalculamos nivel
	var total := ws.total_exp() - amount
	total = max(total, 0)

	# Recalcular nivel y EXP parcial a partir de la EXP total
	if total >= ws.data.exp_to_level3:
		if ws.level < 3:
			pass  # nunca debería subir aquí
		ws.level = 3
		ws.current_exp = total - ws.data.exp_to_level3  # no debería sobrar
	elif total >= ws.data.exp_to_level2:
		if ws.level > 2:
			emit_signal("weapon_leveled_down", ws)
		ws.level = 2
		ws.current_exp = total - ws.data.exp_to_level2
	else:
		if ws.level > 1:
			emit_signal("weapon_leveled_down", ws)
		ws.level = 1
		ws.current_exp = total

# ──────────────────────────────────────────────────────────────────────
# API — Munición
# ──────────────────────────────────────────────────────────────────────

## Intenta gastar 1 de munición del arma actual.
## Devuelve true si pudo disparar (o si la munición es infinita).
func spend_ammo() -> bool:
	var ws := get_current_weapon()
	if ws == null:
		return false
	if ws.ammo == 0:   # infinita
		return true
	if ws.ammo <= 0:
		return false
	ws.ammo -= 1
	emit_signal("inventory_changed")
	return true


func refill_ammo(weapon_id: String, amount: int) -> void:
	for ws in weapons:
		if ws.data.id == weapon_id:
			if ws.ammo > 0 or ws.data.max_ammo > 0:
				ws.ammo = min(ws.ammo + amount, ws.data.max_ammo)
				emit_signal("inventory_changed")
			return

# ──────────────────────────────────────────────────────────────────────
# API — Key Items
# ──────────────────────────────────────────────────────────────────────

func add_key_item(item_data: ItemData) -> void:
	if not key_items.has(item_data.id):
		key_items[item_data.id] = item_data
		emit_signal("inventory_changed")


func remove_key_item(item_id: String) -> void:
	if key_items.has(item_id):
		key_items.erase(item_id)
		emit_signal("inventory_changed")


func has_key_item(item_id: String) -> bool:
	return key_items.has(item_id)

# ──────────────────────────────────────────────────────────────────────
# API — Vida
# ──────────────────────────────────────────────────────────────────────

## Recoge una Life Capsule y aumenta el HP máximo.
func collect_life_capsule(hp_increase: int) -> void:
	max_hp += hp_increase
	current_hp = min(current_hp + hp_increase, max_hp)
	emit_signal("inventory_changed")


func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)
	emit_signal("inventory_changed")


func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)
	penalize_exp_on_damage(amount * 2)   # Cave Story penaliza ~2× EXP por HP perdido
	if current_hp == 0:
		reset_all_weapons()
	emit_signal("inventory_changed")
