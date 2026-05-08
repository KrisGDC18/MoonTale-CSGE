class_name Spur
extends Weapon

# ─── Configuración de carga ───────────────────────────────────────────
const CHARGE_TIME_LV1 : float = 0.5
const CHARGE_TIME_LV2 : float = 1.0
const CHARGE_TIME_LV3 : float = 2.0

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var animator : AnimatedSprite2D = $AnimatedSprite2D

# ─── Variables ────────────────────────────────────────────────────────
var _charge_timer  : float = 0.0
var _charge_level  : int   = 0
var _is_charging   : bool  = false



# ─── Inicialización ───────────────────────────────────────────────────
func _ready() -> void:
	weapon_name = "Spur"
	max_level   = 3
	xp_to_level = [0, 50, 100]


# ─── Sobreescritura de weapon_process ─────────────────────────────────
func weapon_process(delta: float) -> void:
	if _player == null or not visible:
		return
	if Globals.playerStay:  # ← agrega esta línea en ambos
		return

	var looking_up   : bool = Input.is_action_pressed("Up")
	var looking_down : bool = Input.is_action_pressed("Down") and not _player.is_on_floor()

	_update_aim(_player.lastDirection, looking_up, looking_down)
	_handle_aim(_player.lastDirection, looking_up, looking_down)
	_handle_charge(delta)


# ─── Animación del arma ───────────────────────────────────────────────
func _handle_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	var facing : String = "right" if last_direction == 0 else "left"

	var anim : String
	if looking_up:
		anim = "idle_%s_up" % facing
	elif looking_down:
		anim = "idle_%s_down" % facing
	else:
		anim = "idle_%s" % facing

	animator.play(anim)


# ─── Lógica de carga y disparo ────────────────────────────────────────
func _handle_charge(delta: float) -> void:
	if Input.is_action_pressed("Fire"):
		_is_charging   = true
		_charge_timer += delta

		if _charge_timer >= CHARGE_TIME_LV3:
			_charge_level = 3
		elif _charge_timer >= CHARGE_TIME_LV2:
			_charge_level = 2
		elif _charge_timer >= CHARGE_TIME_LV1:
			_charge_level = 1
		else:
			_charge_level = 0

	elif Input.is_action_just_released("Fire"):
		if _charge_level == 3:
			_spawn_bullet(3)
		elif _charge_level == 2:
			_spawn_bullet(2)
		elif _charge_level == 1:
			_spawn_bullet(1)
		else:
			_spawn_bullet(0)

		reset_charge()


# ─── Sobreescritura de _spawn_bullet con límite ───────────────────────
func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	if _bullet_count >= MAX_BULLETS:
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + _shoot_dir * 10.0
	bullet.tree_exiting.connect(func(): _bullet_count -= 1)
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, _shoot_dir)
	_bullet_count += 1


# ─── Reset de carga ───────────────────────────────────────────────────
func reset_charge() -> void:
	_charge_timer = 0.0
	_charge_level = 0
	_is_charging  = false
