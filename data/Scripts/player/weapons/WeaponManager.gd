extends Node

# ─── Estructura de un arma ────────────────────────────────────────────
# cada arma es un Resource personalizado con estas propiedades:
#   id          : String  → identificador único ("polar_star", "fireball", etc.)
#   display_name: String  → nombre visible en el HUD
#   icon        : Texture2D → icono del arma para el HUD
#   max_level   : int     → nivel máximo (1-3 en Cave Story)
#   exp_to_level: Array   → EXP necesaria para subir a cada nivel [lvl2, lvl3]
#                           ejemplo: [10, 30] → 10 EXP para lvl2, 30 para lvl3
#   damage      : Array   → daño por nivel [lvl1, lvl2, lvl3]
#   cooldown    : Array   → segundos entre disparos por nivel
#   recoil      : Array   → retroceso horizontal al disparar por nivel
#   bullet_scene: Array   → escena de la bala por nivel (puede cambiar con el nivel)
#   max_ammo    : int     → -1 = infinita (como Polar Star), >0 = limitada
#   sound       : AudioStream → sonido al disparar

# ─── Inventario ───────────────────────────────────────────────────────
# el inventario es un Array de diccionarios con el estado de cada arma
# máximo 8 armas simultáneas como en Cave Story original
const MAX_WEAPONS   : int = 8

var inventory       : Array  = []  # lista de armas que tiene el jugador
									# cada entrada: {"weapon": WeaponData, "level": int,
									#                "exp": int, "ammo": int}
var active_index    : int    = 0   # índice del arma actualmente equipada
var _cooldown_timer : float  = 0.0 # tiempo restante antes de poder disparar de nuevo

# referencia al jugador — se obtiene automáticamente
var _player : CharacterBody2D = null

signal weapon_changed(weapon_data, level, ammo)   # al cambiar de arma
signal weapon_leveled_up(weapon_data, new_level)  # al subir de nivel
signal ammo_changed(ammo)                          # al gastar munición


func _ready():
	get_tree().node_added.connect(_on_node_added)
	_find_player()


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_find_player()


func _find_player() -> void:
	call_deferred("_init_player")


func _init_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(delta):
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


# ─── API pública ──────────────────────────────────────────────────────

func give_weapon(weapon_data: Resource) -> void:
	# dar un arma al jugador
	# si ya la tiene, no duplicar — solo notificar
	# para llamar desde otro script:
	#   WeaponManager.give_weapon(preload("res://Weapons/PolarStar.tres"))
	if inventory.size() >= MAX_WEAPONS:
		push_warning("WeaponManager: inventario lleno")
		return

	for entry in inventory:
		if entry["weapon"].id == weapon_data.id:
			return  # ya la tiene

	inventory.append({
		"weapon": weapon_data,
		"level":  1,
		"exp":    0,
		"ammo":   weapon_data.max_ammo  # -1 = infinita
	})

	# si es la primera arma equiparla automáticamente
	if inventory.size() == 1:
		active_index = 0
		_emit_weapon_changed()


func remove_weapon(weapon_id: String) -> void:
	# quitar un arma del inventario por su id
	# para llamar: WeaponManager.remove_weapon("polar_star")
	for i in inventory.size():
		if inventory[i]["weapon"].id == weapon_id:
			inventory.remove_at(i)
			active_index = clamp(active_index, 0, inventory.size() - 1)
			_emit_weapon_changed()
			return


func switch_next() -> void:
	# cambiar al siguiente arma del inventario (ciclo)
	# para llamar: WeaponManager.switch_next()
	if inventory.is_empty():
		return
	active_index = (active_index + 1) % inventory.size()
	_emit_weapon_changed()


func switch_prev() -> void:
	# cambiar al arma anterior del inventario (ciclo)
	if inventory.is_empty():
		return
	active_index = (active_index - 1 + inventory.size()) % inventory.size()
	_emit_weapon_changed()


func switch_to(index: int) -> void:
	# equipar arma por índice directo
	# para llamar: WeaponManager.switch_to(2)
	if index < 0 or index >= inventory.size():
		return
	active_index = index
	_emit_weapon_changed()


func shoot(direction: Vector2) -> void:
	# intentar disparar el arma activa en la dirección dada
	# direction: Vector2 normalizado (-1,0)=izq, (1,0)=der, (0,-1)=arr, etc.
	# para llamar desde el jugador:
	#   WeaponManager.shoot(Vector2(1, 0))  # disparo a la derecha
	if inventory.is_empty() or _cooldown_timer > 0.0 or _player == null:
		return

	var entry  : Dictionary = inventory[active_index]
	var weapon : Resource   = entry["weapon"]
	var level  : int        = entry["level"]

	# verificar munición (max_ammo == -1 significa infinita)
	if weapon.max_ammo != -1 and entry["ammo"] <= 0:
		return

	# instanciar la bala en la posición del jugador
	var bullet_scene : PackedScene = weapon.bullet_scene[level - 1]
	var bullet                     = bullet_scene.instantiate()

	# configurar la bala con el daño del nivel actual
	bullet.damage    = weapon.damage[level - 1]
	bullet.direction = direction
	bullet.global_position = _player.global_position

	# añadir al árbol — se añade al root para que no dependa del jugador
	_player.get_tree().root.add_child(bullet)

	# reproducir sonido del arma
	if weapon.sound != null:
		# crear un AudioStreamPlayer temporal para no cortar disparos rápidos
		var sfx := AudioStreamPlayer.new()
		sfx.stream = weapon.sound
		sfx.autoplay = true
		# auto-destruir al terminar
		sfx.finished.connect(sfx.queue_free)
		_player.add_child(sfx)

	# aplicar retroceso al jugador
	var recoil : float = weapon.recoil[level - 1]
	_player.velocity.x -= direction.x * recoil

	# gastar munición
	if weapon.max_ammo != -1:
		entry["ammo"] = max(entry["ammo"] - 1, 0)
		emit_signal("ammo_changed", entry["ammo"])

	# activar cooldown del nivel actual
	_cooldown_timer = weapon.cooldown[level - 1]


func add_exp(weapon_id: String, amount: int) -> void:
	# añadir EXP a un arma específica
	# los enemigos llaman esto al morir:
	#   WeaponManager.add_exp("polar_star", 3)
	for entry in inventory:
		if entry["weapon"].id != weapon_id:
			continue

		var weapon : Resource = entry["weapon"]
		var level  : int      = entry["level"]

		# si ya está al nivel máximo no acumular EXP
		if level >= weapon.max_level:
			entry["exp"] = weapon.exp_to_level[weapon.max_level - 2]
			return

		entry["exp"] += amount

		# verificar si sube de nivel
		var exp_needed : int = weapon.exp_to_level[level - 1]
		if entry["exp"] >= exp_needed:
			entry["exp"]   = 0
			entry["level"] = min(level + 1, weapon.max_level)
			emit_signal("weapon_leveled_up", weapon, entry["level"])
		return


func lose_exp(weapon_id: String, amount: int) -> void:
	# perder EXP al recibir daño (Cave Story baja el nivel al golpear)
	# para llamar desde take_damage del jugador:
	#   WeaponManager.lose_exp(WeaponManager.get_active_weapon_id(), 10)
	for entry in inventory:
		if entry["weapon"].id != weapon_id:
			continue

		var weapon : Resource = entry["weapon"]
		entry["exp"] = max(entry["exp"] - amount, 0)

		# si la EXP llega a 0 y está en nivel > 1 → bajar de nivel
		if entry["exp"] <= 0 and entry["level"] > 1:
			entry["level"] -= 1
			entry["exp"]    = 0
			emit_signal("weapon_leveled_up", weapon, entry["level"])
		return


func get_active_entry() -> Dictionary:
	# obtener el diccionario completo del arma activa
	# para leer desde el HUD: WeaponManager.get_active_entry()
	if inventory.is_empty():
		return {}
	return inventory[active_index]


func get_active_weapon_id() -> String:
	# obtener solo el id del arma activa
	if inventory.is_empty():
		return ""
	return inventory[active_index]["weapon"].id


func _emit_weapon_changed() -> void:
	if inventory.is_empty():
		return
	#var entry := inventory[active_index]
	#emit_signal("weapon_changed", entry["weapon"], entry["level"], entry["ammo"])
