class_name PolarStar
extends Weapon

const FIRE_RATE : float = 0.0

var _fire_timer : float = -1.0


func _ready() -> void:
	weapon_name = "PolarStar"
	max_level   = 3
	xp_to_level = [0, 50, 100]


func weapon_process(delta: float) -> void:
	if _player == null or not visible:
		return
	if Globals.playerStay:
		return

	var looking_up   : bool = Input.is_action_pressed("Up")
	var looking_down : bool = Input.is_action_pressed("Down") and not _player.is_on_floor()

	_update_aim(_player.lastDirection, looking_up, looking_down)
	_handle_aim(_player.lastDirection, looking_up, looking_down)

	_fire_timer -= delta

	if Input.is_action_just_pressed("Fire") and _fire_timer <= 0.0 and _bullet_count < MAX_BULLETS:
		_spawn_bullet(current_level)
		_fire_timer = FIRE_RATE


func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	if _bullet_count >= MAX_BULLETS:
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = _get_bullet_spawn_pos()
	bullet.tree_exiting.connect(func(): _bullet_count -= 1)
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, _shoot_dir, false, true)
	_bullet_count += 1

	_play_shoot_sound(lvl)  # ← pasa el nivel actual


func reset_charge() -> void:
	_fire_timer = -1.0
