class_name PolarStar
extends Weapon

const FIRE_RATE : float = 0.0
var _fire_timer : float = -1.0


func _ready() -> void:
	weapon_name = "PolarStar"
	max_level   = 3
	xp_to_level = [30, 50, 100]
	super._ready()  # valida config y prepara munición (ver Weapon._ready)
	# Asignar todos los AudioStreamPlayer hijos al bus "SFX"
	call_deferred("_assign_sfx_bus")


func _assign_sfx_bus() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.bus = "SFX"


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
	if Input.is_action_just_pressed("Fire") and _fire_timer <= 0.0 and _bullet_count < max_bullets_on_screen:
		_spawn_bullet(current_level)
		_fire_timer = FIRE_RATE


# PolarStar siempre dispara bala normal (nunca láser, sin importar el
# nivel) — por eso instancia bullet_scene directo en vez de dejar que
# _instantiate_bullet() elija entre normal/láser. Aun así reutiliza el
# resto de la infraestructura de la clase base: munición, fogonazo,
# y la config de despawn/hit/rango que la bala necesita para el VFX.
func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	if _bullet_count >= max_bullets_on_screen:
		return
	if not has_ammo():
		return

	consume_ammo(1)

	var bullet = bullet_scene.instantiate()
	bullet.global_position = _get_bullet_spawn_pos()
	bullet.tree_exiting.connect(func(): _bullet_count -= 1)
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, _shoot_dir, true)  # force_normal=true

	# Conecta despawn range + sprites de despawn/hit configurados en el
	# Inspector de esta arma (ver grupo VFX en Weapon.gd), más los
	# overrides de daño/velocidad si están configurados.
	if bullet.has_method("configure"):
		var despawn_range : float = 0.0
		if lvl - 1 < bullet_range_by_level.size():
			despawn_range = bullet_range_by_level[lvl - 1]
		bullet.call(
			"configure",
			despawn_range,
			_pick_vfx(bullet_despawn_by_level, bullet_despawn_default, lvl),
			_pick_vfx(bullet_hit_by_level, bullet_hit_default, lvl),
			_get_damage_override(lvl),
			_get_speed_override(lvl)
		)

	_bullet_count += 1
	_spawn_muzzle_flash(lvl)
	_play_shoot_sound(lvl)  # ← pasa el nivel actual


func reset_charge() -> void:
	_fire_timer = -1.0
