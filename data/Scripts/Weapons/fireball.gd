class_name Fireball
extends Weapon

# ── Fireball (Cave Story) ─────────────────────────────────────────────
## Comportamiento original: la bola de fuego cae por gravedad y rebota
## contra el suelo un par de veces antes de apagarse. Ese comportamiento
## (gravedad + rebote) vive en la ESCENA/SCRIPT de la bala en sí
## (ver nota FireballBullet más abajo), no acá — este script solo se
## encarga de CUÁNTAS balas salen, en qué ángulo y con qué cadencia,
## igual que PolarStar.gd se encarga de lo suyo.
##
## Progresión por nivel (fiel al original):
##   Nivel 1: 1 sola bola, rebota poco, daño bajo.
##   Nivel 2: 2 bolas en abanico (una más alta, una más baja).
##   Nivel 3: 3 bolas en abanico más amplio, rebotan más veces, más daño.

const FIRE_RATE : float = 0.35   ## Fireball es más lento que PolarStar
var _fire_timer : float = -1.0

## Cuántas bolas salen por disparo, según nivel (índice 0 = nivel 1).
@export var shots_by_level : Array[int] = [2, 3, 4]

## Apertura del abanico en grados por nivel — el disparo extra se reparte
## simétricamente arriba/abajo de _shoot_dir. En nivel 1 no aplica (1 sola bala).
@export var spread_degrees_by_level : Array[float] = [0.0, 20.0, 35.0]

## Rebotes que aguanta la bola antes de apagarse, por nivel.
## FireballBullet.gd debe leer esto en su configure()/setup() para
## decrementar un contador propio en cada colisión con el suelo.
@export var bounces_by_level : Array[int] = [1, 2, 3]


func _ready() -> void:
	weapon_name = "Fireball"
	max_level   = 3
	xp_to_level = [30, 50, 100]
	super._ready()
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


## Dispara `shots_by_level[lvl-1]` bolas en abanico alrededor de _shoot_dir.
## Cada bola es una bala independiente (mismo _bullet_count/max_bullets_on_screen
## que las demás armas), así que en niveles altos "gastás" más cupo de golpe.
func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	if not has_ammo():
		return

	var shots  : int   = 1
	var index  : int   = lvl - 1
	if index >= 0 and index < shots_by_level.size():
		shots = max(shots_by_level[index], 1)

	var spread : float = 0.0
	if index >= 0 and index < spread_degrees_by_level.size():
		spread = spread_degrees_by_level[index]

	# No dispares más balas de las que el cupo (max_bullets_on_screen)
	# permite; si no entran todas, recorta la tanda en vez de crashear
	# o tirar de más.
	shots = min(shots, max_bullets_on_screen - _bullet_count)
	if shots <= 0:
		return

	if not has_ammo():
		return
	consume_ammo(1)  # 1 disparo = 1 munición, aunque salgan varias bolas

	for i in shots:
		# Reparte los ángulos simétricamente: con 3 balas y spread=35°,
		# quedan en -35°, 0°, +35°. Con 2 balas, en -spread/2 y +spread/2
		# (no hay bola central).
		var t : float
		if shots == 1:
			t = 0.0
		elif shots % 2 == 1:
			t = float(i - shots / 2) / float(shots / 2)
		else:
			t = (float(i) / float(shots - 1)) * 2.0 - 1.0

		var angle_offset : float = deg_to_rad(spread) * t
		var dir : Vector2 = _shoot_dir.rotated(angle_offset)

		var bullet = bullet_scene.instantiate()
		bullet.global_position = _get_bullet_spawn_pos()
		bullet.tree_exiting.connect(func(): _bullet_count -= 1)
		get_tree().root.add_child(bullet)
		bullet.setup(lvl, dir, true)  # force_normal=true: Fireball no usa láser

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

		# Rebotes: si la bala del Fireball expone esta propiedad/método,
		# le pasamos cuántos rebotes aguanta en este nivel. Si no existe
		# todavía en tu FireballBullet.gd, esta línea simplemente no hace nada.
		if bullet.has_method("set_bounces"):
			var bounces : int = 1
			if index >= 0 and index < bounces_by_level.size():
				bounces = bounces_by_level[index]
			bullet.call("set_bounces", bounces)

		# Facing: si el tiro fue vertical (mirando arriba/abajo), la bala
		# no tiene por sí sola hacia dónde arrancar horizontalmente al
		# rebotar — le pasamos el facing del jugador (_last_facing viene
		# de Weapon.gd: 0=derecha, 1=izquierda) para que lo use en su
		# primer rebote. Si tu FireballBullet.gd no tiene set_facing()
		# todavía, esta línea no hace nada.
		if bullet.has_method("set_facing"):
			var facing_x : float = 1.0 if _last_facing == 0 else -1.0
			bullet.call("set_facing", facing_x)

		_bullet_count += 1

	_spawn_muzzle_flash(lvl)
	_play_shoot_sound(lvl)


func reset_charge() -> void:
	_fire_timer = -1.0
