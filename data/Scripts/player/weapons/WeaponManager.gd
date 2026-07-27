extends Node2D

# ─── Señal ────────────────────────────────────────────────────────────
signal weapon_changed(weapon: Node2D)

# ─── Armas de inicio (opcional, puede quedar vacío) ───────────────────
@export var weapon_scenes : Array[PackedScene] = []

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var switch_sfx : AudioStreamPlayer = $switch_sfx

# ─── Variables ────────────────────────────────────────────────────────
var _weapons        : Array  = []   # instancias de arma
var _owned_scenes   : Array  = []   # PackedScene de cada arma obtenida
var _current_index  : int    = 0
var _current_weapon : Node2D = null
var _player         : Node   = null


# ─── Inicialización ───────────────────────────────────────────────────
func init(player: Node) -> void:
	add_to_group("weapon_manager")
	_player = player
	for scene in weapon_scenes:
		if scene != null:
			_add_weapon(scene, false)


# Añade un arma y la instancia. play_sound controla si suena el switch_sfx.
func _add_weapon(scene: PackedScene, play_sound: bool = true) -> void:
	var weapon : Node2D = scene.instantiate()
	add_child(weapon)
	weapon.init(_player)
	weapon.weapon_id = scene.resource_path   # ← id estable para guardar/cargar
	weapon.visible = false
	_connect_weapon_signals(weapon)
	_weapons.append(weapon)
	_owned_scenes.append(scene)
	_equip(_weapons.size() - 1, play_sound)


## Punto 9/10: conecta las señales de nivel/XP de esta arma a los textos
## flotantes, mostrados sobre el jugador (no sobre el arma, que suele
## estar oculta/rotada). Se llama una sola vez por instancia de arma,
## así que cubre armas de inicio, pickups y armas restauradas al cargar
## partida sin duplicar conexiones.
func _connect_weapon_signals(weapon: Node2D) -> void:
	weapon.leveled_up.connect(_on_weapon_leveled_up)
	weapon.leveled_down.connect(_on_weapon_leveled_down)
	weapon.max_level_reached.connect(_on_weapon_max_level_reached)
	weapon.xp_gained.connect(_on_weapon_xp_gained)


func _on_weapon_leveled_up(_new_level: int) -> void:
	if _player != null:
		FloatingTextManager.show_text(_player, "LEVEL UP", FloatingTextManager.Style.LEVEL_UP)


func _on_weapon_leveled_down(_new_level: int) -> void:
	if _player != null:
		FloatingTextManager.show_text(_player, "LEVEL DOWN", FloatingTextManager.Style.LEVEL_DOWN)


func _on_weapon_max_level_reached() -> void:
	if _player != null:
		FloatingTextManager.show_text(_player, "MAX LEVEL", FloatingTextManager.Style.MAX_LEVEL)


func _on_weapon_xp_gained(amount: int) -> void:
	if _player != null:
		FloatingTextManager.show_xp_gain(_player, amount)


func _equip(index: int, play_sound: bool = true) -> void:
	if _current_weapon != null:
		_current_weapon.visible = false
		_current_weapon.reset_charge()

	_current_index  = index
	_current_weapon = _weapons[index]
	_current_weapon.visible = true

	emit_signal("weapon_changed", _current_weapon)
	if play_sound:
		switch_sfx.play()


# ─── Proceso ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _player == null or _current_weapon == null:
		return
	if _player.playerDead:
		_current_weapon.visible = false
		return

	_handle_weapon_switch()
	_current_weapon.weapon_process(delta)

	# Lógica de fondo (ej. recarga de munición) para las armas que el
	# jugador tiene pero NO tiene equipadas en este momento.
	for w in _weapons:
		if w != _current_weapon:
			w.idle_process(delta)


func _handle_weapon_switch() -> void:
	if _weapons.size() <= 1:
		return

	if Input.is_action_just_pressed("Weapon+"):
		_equip((_current_index + 1) % _weapons.size())

	elif Input.is_action_just_pressed("Weapon-"):
		_equip((_current_index - 1 + _weapons.size()) % _weapons.size())


# ─── API pública ──────────────────────────────────────────────────────
func get_current_weapon() -> Node2D:
	return _current_weapon


func add_xp_to_current(amount: int) -> void:
	if _current_weapon != null:
		_current_weapon.add_xp(amount)


# Llamado por WeaponPickup cuando el jugador toca el objeto.
# Si ya tiene el arma, le da XP a la activa en vez de duplicar.
func give_weapon(scene: PackedScene, xp_if_owned: int = 50) -> void:
	for owned in _owned_scenes:
		if owned == scene:
			add_xp_to_current(xp_if_owned)
			return
	_add_weapon(scene, false)  # sin sonido: el pickup tiene el suyo


# ─── Guardado / Carga ─────────────────────────────────────────────────

## Devuelve el estado de todas las armas para SaveSystem.
## Formato: [ { "id": "res://...", "level": 2, "xp": 30 }, ... ]
func get_save_data() -> Dictionary:
	var arr : Array = []
	for w in _weapons:
		arr.append(w.get_save_data())
	return { "weapons": arr, "weapon_index": _current_index }


## Restaura el inventario de armas desde los datos guardados.
## Llámalo desde SaveSystem._apply_state(), después de que el jugador exista.
func restore_from_save(save_data: Dictionary) -> void:
	# Limpia las armas actuales (excepto las de inicio hardcodeadas en weapon_scenes,
	# que ya se añadieron en init(); las reemplazamos completamente).
	for w in _weapons:
		w.queue_free()
	_weapons.clear()
	_owned_scenes.clear()
	_current_weapon = null

	var entries : Array = save_data.get("weapons", [])
	for entry in entries:
		var path  : String = entry.get("id", "")
		if path.is_empty():
			continue
		var scene := ResourceLoader.load(path) as PackedScene
		if scene == null:
			push_warning("[WeaponManager] No se pudo cargar la escena del arma: %s" % path)
			continue
		_add_weapon(scene, false)
		# Aplica nivel y XP al arma recién instanciada
		_weapons.back().apply_save_data(entry)

	# Restaura el arma activa
	var idx : int = save_data.get("weapon_index", 0)
	if not _weapons.is_empty():
		_equip(clamp(idx, 0, _weapons.size() - 1), false)
