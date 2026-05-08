class_name Weapon
extends Node2D

# ─── Configuración base ───────────────────────────────────────────────
@export var weapon_name    : String = "Weapon"
@export var max_level      : int    = 3
@export var bullet_scene   : PackedScene

# ─── Variables ────────────────────────────────────────────────────────
var current_level  : int     = 1
var current_xp     : int     = 0
var _shoot_dir     : Vector2 = Vector2.RIGHT
var _player        : Node    = null
const MAX_BULLETS : int   = 3
var _bullet_count : int   = 0

# ─── XP por nivel ─────────────────────────────────────────────────────
var xp_to_level    : Array[int] = [0, 50, 100]


# ─── Inicialización ───────────────────────────────────────────────────
func init(player: Node) -> void:
	_player = player


# ─── Ganar XP ─────────────────────────────────────────────────────────
func add_xp(amount: int) -> void:
	if current_level >= max_level:
		return

	current_xp += amount
	if current_xp >= xp_to_level[current_level]:
		current_xp    = 0
		current_level = min(current_level + 1, max_level)
		_on_level_up()


func _on_level_up() -> void:
	print("%s subio a nivel %d" % [weapon_name, current_level])


# ─── Métodos a sobreescribir ──────────────────────────────────────────
func weapon_process(delta: float) -> void:
	if Globals.playerStay:
		return



func reset_charge() -> void:
	pass


# ─── Dirección de apuntado ────────────────────────────────────────────
func _update_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	var facing_x : float = 1.0 if last_direction == 0 else -1.0

	if looking_up:
		_shoot_dir = Vector2.UP
	elif looking_down:
		_shoot_dir = Vector2.DOWN
	else:
		_shoot_dir = Vector2(facing_x, 0.0)


# ─── Instanciar bala ──────────────────────────────────────────────────
func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + _shoot_dir * 100.0
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, _shoot_dir)
