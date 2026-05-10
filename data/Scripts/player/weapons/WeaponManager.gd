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
	weapon.visible = false
	_weapons.append(weapon)
	_owned_scenes.append(scene)
	_equip(_weapons.size() - 1, play_sound)


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
