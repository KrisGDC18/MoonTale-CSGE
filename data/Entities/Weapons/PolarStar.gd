class_name PolarStar
extends Weapon

# ─── Configuración ────────────────────────────────────────────────────
const FIRE_RATE   : float = 0.0


# ─── Nodos ────────────────────────────────────────────────────────────
@onready var animator : AnimatedSprite2D = $AnimatedSprite2D

# ─── Variables ────────────────────────────────────────────────────────
var _fire_timer   : float = -1.0



# ─── Inicialización ───────────────────────────────────────────────────
func _ready() -> void:
	weapon_name = "PolarStar"
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

	_fire_timer -= delta

	if Input.is_action_just_pressed("Fire") and _fire_timer <= 0.0 and _bullet_count < MAX_BULLETS:
		_spawn_bullet(current_level)
		_fire_timer = FIRE_RATE


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


# ─── Sobreescritura de _spawn_bullet sin estiramiento ─────────────────
func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	if _bullet_count >= MAX_BULLETS:
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + _shoot_dir * 10.0
	bullet.tree_exiting.connect(func(): _bullet_count -= 1)
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, _shoot_dir, false, true)  # ← force_normal = true
	_bullet_count += 1


# ─── Reset ────────────────────────────────────────────────────────────
func reset_charge() -> void:
	_fire_timer   = -1.0
