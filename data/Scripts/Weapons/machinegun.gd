class_name MachineGun
extends Weapon
## Machine Gun de Cave Story: disparo rápido y continuo mientras se
## mantiene presionado "Fire", con dispersión vertical aleatoria en cada
## bala, y el empuje hacia arriba clásico al disparar hacia abajo en el
## aire (el truco de "volar" disparando del juego original).
##
## Siempre dispara bala normal (nunca láser, sin importar el nivel) —
## igual que PolarStar, se fuerza force_normal=true en _instantiate_bullet().

@export var fire_rate : float = 0.075   ## segundos entre disparos mientras se mantiene Fire

# ── Dispersión ─────────────────────────────────────────────────────────
## Desplazamiento aleatorio (en píxeles, perpendicular a la dirección de
## disparo) aplicado a la POSICIÓN de origen de cada bala — no a su
## ángulo. Importante: si rotáramos la dirección en vez de desplazar el
## punto de origen, un disparo horizontal con leve ángulo hacia abajo
## iría perdiendo altura a medida que avanza (la bala no tiene gravedad,
## viaja en línea recta), y terminaría clavándose en el piso mucho antes
## de agotar su recorrido si el jugador dispara cerca del suelo. Con
## desplazamiento de posición, la bala sigue siendo perfectamente
## horizontal/vertical — solo cambia un poco DÓNDE arranca.
@export_range(0.0, 12.0) var spread_pixels : float = 6.0

# ── Flote vertical y retroceso horizontal (SOLO nivel 3) ──────────────
## En Cave Story, este efecto es mucho más notorio en el nivel máximo de
## la Machine Gun. A diferencia del intento anterior (empujar solo en el
## instante de cada disparo), esto corre CONTINUAMENTE mientras se
## mantiene Fire — igual que los boosters del jugador — así el efecto no
## depende de qué tan rápido dispares (fire_rate vs. gravedad entre
## disparos), y el ascenso es contínuo y controlable en vez de errático.
@export var level3_lift_speed    : float = -50.0  ## velocidad objetivo al disparar hacia abajo en el aire (negativo = sube)
## Ya NO compite contra la gravedad — player.gd:_apply_gravity() la
## reemplaza por completo ese tick en vez de sumarse a ella (ver
## is_level3_hovering() más abajo). Por eso este valor puede ser bajo:
## controla qué tan rápido se "engancha" el flote al empezar a disparar,
## no si le gana o no a la gravedad.
@export var level3_lift_accel    : float = 500.0  ## qué tan rápido se acerca a level3_lift_speed (px/s²)
@export var level3_recoil_speed  : float = 70.0   ## velocidad objetivo del retroceso horizontal (magnitud, px/s)
@export var level3_recoil_accel  : float = 380.0  ## qué tan rápido se acerca al retroceso (px/s²)
@export var level3_up_recoil_speed : float = 60.0  ## empuje hacia abajo al disparar hacia ARRIBA (positivo = abajo)

# ── Recarga automática gradual ─────────────────────────────────────────
## Balas por segundo que se van recuperando solas mientras no esté al
## tope (infinite_ammo=false, max_ammo=100 seteados en _ready() más abajo).
## No hace falta gatillo/tecla de recarga: se rellena sola con el tiempo.
@export var ammo_regen_rate : float = 8.0

var _fire_timer        : float = 0.0
var _ammo_regen_timer  : float = 0.0


func _ready() -> void:
	weapon_name         = "Machine Gun"
	max_level           = 3
	xp_to_level         = [40, 60, 120]
	infinite_ammo       = false
	max_ammo            = 100
	max_bullets_on_screen = 20   ## la Machine Gun necesita muchas más que el default (3)
	super._ready()  # valida config y prepara munición (current_ammo = max_ammo la primera vez)
	# Asignar todos los AudioStreamPlayer hijos al bus "SFX"
	call_deferred("_assign_sfx_bus")


func _assign_sfx_bus() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.bus = "SFX"


func weapon_process(delta: float) -> void:
	_regen_ammo(delta)  # mientras está equipada

	if _player == null or not visible:
		return
	if Globals.playerStay:
		return

	var looking_up   : bool = Input.is_action_pressed("Up")
	var looking_down : bool = Input.is_action_pressed("Down") and not _player.is_on_floor()

	_update_aim(_player.lastDirection, looking_up, looking_down)
	_handle_aim(_player.lastDirection, looking_up, looking_down)

	var firing : bool = Input.is_action_pressed("Fire")

	_fire_timer -= delta
	# A diferencia del Polar Star (is_action_just_pressed), acá se usa
	# is_action_pressed: mientras se mantenga Fire, sigue disparando solo.
	if firing and _fire_timer <= 0.0:
		_spawn_bullet(current_level)
		_fire_timer = fire_rate

	# El retroceso horizontal y el empuje al disparar hacia arriba siguen
	# resolviéndose acá (no compiten contra una fuerza continua como la
	# gravedad, así que el timing de _process no es un problema). El
	# flote vertical (disparo hacia abajo) se resolvió aparte, ver
	# is_level3_hovering() y player.gd:_apply_gravity().
	if firing and current_level >= 3:
		_apply_level3_recoil(delta, looking_up, looking_down)


## WeaponManager llama esto en vez de weapon_process() mientras la Machine
## Gun NO está equipada — así la munición sigue recargando en segundo
## plano, tengas la Machine Gun seleccionada o no.
func idle_process(delta: float) -> void:
	_regen_ammo(delta)


## Recarga automática gradual: 1 bala cada (1 / ammo_regen_rate) segundos,
## hasta llegar a max_ammo. Usa un acumulador en vez de un Timer para no
## perder fracciones de segundo entre llamadas (importante si ammo_regen_rate
## es alto, ej. > 10 balas/seg).
func _regen_ammo(delta: float) -> void:
	if infinite_ammo or current_ammo >= max_ammo:
		_ammo_regen_timer = 0.0
		return

	_ammo_regen_timer += delta
	var interval : float = 1.0 / max(ammo_regen_rate, 0.01)
	while _ammo_regen_timer >= interval and current_ammo < max_ammo:
		_ammo_regen_timer -= interval
		refill_ammo(1)


func reset_charge() -> void:
	_fire_timer = 0.0


func _spawn_bullet(lvl: int) -> void:
	if _bullet_count >= max_bullets_on_screen:
		return
	if not has_ammo():
		return

	var bullet = _instantiate_bullet(lvl, true)  # force_normal=true: nunca dispara láser
	if bullet == null:
		return

	consume_ammo(1)

	# Dispersión: offset perpendicular en la POSICIÓN de spawn, la
	# dirección (fire_dir) queda intacta y perfectamente recta — ver nota
	# en la declaración de spread_pixels sobre por qué no se rota el ángulo.
	var perp        : Vector2 = Vector2(-_shoot_dir.y, _shoot_dir.x)  # perpendicular a _shoot_dir
	var spread_offset : Vector2 = perp * randf_range(-spread_pixels, spread_pixels)
	var fire_dir    : Vector2 = _shoot_dir

	bullet.global_position = _get_bullet_spawn_pos() + spread_offset
	bullet.tree_exiting.connect(func(): _bullet_count -= 1)
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, fire_dir, true)

	_bullet_count += 1
	_spawn_muzzle_flash(lvl)
	_play_shoot_sound(lvl)


## Retroceso de nivel 3 (horizontal y disparo hacia arriba). El flote
## vertical al disparar hacia abajo NO vive acá — ver is_level3_hovering()
## más abajo y la nota en player.gd:_apply_gravity() sobre por qué.
##
## - Disparando hacia ARRIBA: retroceso hacia abajo (level3_up_recoil_speed).
## - Disparando en HORIZONTAL (ni arriba ni abajo): retroceso horizontal
##   continuo, empujando al jugador levemente en la dirección opuesta a
##   la que dispara.
func _apply_level3_recoil(delta: float, looking_up: bool, looking_down: bool) -> void:
	if _player == null:
		return

	if looking_up:
		_player.velocity.y = move_toward(
			_player.velocity.y, level3_up_recoil_speed, level3_recoil_accel * delta)

	elif not looking_down:
		var back_dir : float = -1.0 if _shoot_dir.x > 0.0 else 1.0
		_player.velocity.x = move_toward(
			_player.velocity.x, back_dir * level3_recoil_speed, level3_recoil_accel * delta)


## Consultado por player.gd:_apply_gravity() en su propio _physics_process,
## para reemplazar la gravedad normal por el flote continuo en vez de
## competir contra ella (ver nota extensa allá sobre el problema de orden
## _process/_physics_process que esto evita). true = está en la condición
## exacta para flotar: nivel 3, disparando, apuntando hacia abajo, en el aire.
func is_level3_hovering() -> bool:
	return current_level >= 3 \
		and Input.is_action_pressed("Fire") \
		and Input.is_action_pressed("Down") \
		and _player != null and not _player.is_on_floor()
