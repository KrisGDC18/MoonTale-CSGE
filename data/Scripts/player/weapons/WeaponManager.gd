extends Node2D

# ─── Señal ────────────────────────────────────────────────────────────
signal weapon_changed(weapon: Node2D)

# ─── Armas disponibles ────────────────────────────────────────────────
@export var weapon_scenes : Array[PackedScene] = []

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var switch_sfx : AudioStreamPlayer = $switch_sfx

# ─── Variables ────────────────────────────────────────────────────────
var _weapons        : Array  = []
var _current_index  : int    = 0
var _current_weapon : Node2D = null
var _player         : Node   = null


# ─── Inicialización ───────────────────────────────────────────────────
func init(player: Node) -> void:
	add_to_group("weapon_manager")
	_player = player
	print("WeaponManager iniciado, weapon_scenes: ", weapon_scenes.size())
	for scene in weapon_scenes:
		_add_weapon(scene)
	print("Armas agregadas: ", _weapons.size())
	print("Arma actual: ", _current_weapon)


func _add_weapon(weapon_scene: PackedScene) -> void:
	var weapon : Node2D = weapon_scene.instantiate()
	add_child(weapon)
	weapon.init(_player)
	weapon.visible = false
	_weapons.append(weapon)
	print("Arma agregada: ", weapon.name, " total: ", _weapons.size())

	if _weapons.size() == 1:
		print("Equipando primera arma...")
		_equip(0)
		print("_current_weapon despues de equip: ", _current_weapon)


func _equip(index: int) -> void:
	if _current_weapon != null:
		_current_weapon.visible = false
		_current_weapon.reset_charge()

	_current_index  = index
	_current_weapon = _weapons[index]
	_current_weapon.visible = true
	print("Equipando arma: ", _current_weapon.name)

	# Notificar al HUD (y cualquier otro listener) que el arma cambió
	emit_signal("weapon_changed", _current_weapon)
	switch_sfx.play()


# ─── Proceso ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _player == null:
		print("ERROR: _player es null")
		return
	if _current_weapon == null:
		print("ERROR: _current_weapon es null")
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
		var next : int = (_current_index + 1) % _weapons.size()
		_equip(next)

	elif Input.is_action_just_pressed("Weapon-"):
		var prev : int = (_current_index - 1 + _weapons.size()) % _weapons.size()
		_equip(prev)


# ─── API pública ──────────────────────────────────────────────────────
func get_current_weapon() -> Node2D:
	return _current_weapon


func add_xp_to_current(amount: int) -> void:
	if _current_weapon != null:
		_current_weapon.add_xp(amount)
