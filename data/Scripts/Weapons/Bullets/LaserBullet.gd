class_name LaserBullet
extends Bullet
## Bala tipo láser: viaja hasta una distancia fija (o hasta chocar con
## una pared), entra en "hold" haciendo daño por tick durante un tiempo,
## y desaparece. Opcionalmente redimensiona su colisión para cubrir todo
## el trayecto recorrido durante el hold (el Spur, por ejemplo, no lo
## hace y se queda donde está).

enum LaserPhase { TRAVEL, HOLD }

## Distancia desde el origen donde arranca visualmente el láser. En 0.0
## arranca EXACTAMENTE en el mismo punto que una bala normal (el mismo
## BulletOrigin/offset resuelto por Weapon._get_bullet_spawn_pos()).
## Si algún día necesitás que el láser empiece un poco más adelante del
## cañón (por estética), subí este valor — pero por defecto debe coincidir
## con el disparo normal.
const LASER_START_DIST : float = 0.0
const LASER_END_DIST   : float = 384.0
const LASER_LENGTH     : float = LASER_END_DIST - LASER_START_DIST
const LASER_HOLD_TIME  : float = 1.0
const LASER_DMG_RATE   : float = 0.5
const LASER_STAMP_FADE : float = LASER_HOLD_TIME

var resize_collision_on_hold : bool = true

var _laser_phase     : LaserPhase = LaserPhase.TRAVEL
var _laser_timer     : float = 0.0
var _laser_dmg_timer : float = 0.0


func setup(lvl: int, dir: Vector2, p_resize_collision: bool = true) -> void:
	resize_collision_on_hold = p_resize_collision
	super.setup(lvl, dir)


func _on_setup() -> void:
	_pierce             = true
	_laser_phase        = LaserPhase.TRAVEL
	_stamp_active       = true
	collision.disabled  = false
	animator.scale      = Vector2.ONE
	# Empezar en el borde cercano y viajar hacia adelante
	global_position     = _origin + direction * LASER_START_DIST


## El láser dura por tiempo (LASER_HOLD_TIME), no por visibilidad.
func _on_screen_exited() -> void:
	pass


## El láser (Spur) NUNCA debe destruirse ni reproducir el efecto de
## despawn por el chequeo de rango genérico de Bullet._process(). Su
## ciclo de vida es 100% propio (TRAVEL → HOLD → queue_free directo,
## sin pasar por _despawn()), así que acá se anula por completo ese
## chequeo, sin importar qué distancia tenga configurada el arma.
func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if Globals.playerStay:
		return

	match _laser_phase:

		LaserPhase.TRAVEL:
			global_position += direction * speed * delta

			_stamp_timer += delta
			if _stamp_timer >= STAMP_INTERVAL:
				_stamp_timer = 0.0
				_stamp_trail(LASER_STAMP_FADE)

			var traveled : float = (global_position - (_origin + direction * LASER_START_DIST)
				).dot(direction)
			if traveled >= LASER_LENGTH:
				global_position = _origin + direction * LASER_END_DIST
				_enter_hold()

		LaserPhase.HOLD:
			_laser_timer     += delta
			_laser_dmg_timer += delta

			if _laser_dmg_timer >= LASER_DMG_RATE:
				_laser_dmg_timer = 0.0
				_deal_laser_damage()

			if _laser_timer >= LASER_HOLD_TIME:
				queue_free()   # fin de vida por tiempo, sin pasar por _despawn(): sin VFX de despawn


## Centra el nodo en el área recorrida y expande la colisión para cubrirla.
func _enter_hold() -> void:
	_laser_phase     = LaserPhase.HOLD
	_laser_timer     = 0.0
	_laser_dmg_timer = 0.0
	_stamp_active    = false

	var start_pos     := _origin + direction * LASER_START_DIST
	var actual_length := clampf(
		(global_position - start_pos).dot(direction), 1.0, LASER_LENGTH)

	if resize_collision_on_hold:
		global_position = start_pos + direction * (actual_length * 0.5)
		if collision.shape is RectangleShape2D:
			var shape := collision.shape as RectangleShape2D
			if _is_vertical:
				shape.size = Vector2(_original_collision_size.x, actual_length)
			else:
				shape.size = Vector2(actual_length, _original_collision_size.y)


func _deal_laser_damage() -> void:
	var bodies := get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		elif body.is_in_group("destructible") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)


## El jugador no cuenta como colisión real para esta bala.
func _should_ignore_hit(body: Node2D) -> bool:
	return body.is_in_group("player")


## Lógica de colisión propia. El láser nunca se destruye por una colisión
## directa (devuelve false siempre) — su fin de vida lo maneja
## _physics_process (fase HOLD por tiempo). El hit VFX se reproduce
## igual en cada golpe real gracias al orquestador de Bullet.gd.
func _handle_hit(body: Node2D) -> bool:
	if body.is_in_group("enemies"):
		if _laser_phase == LaserPhase.TRAVEL and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
	else:
		# Pared: detener el recorrido y entrar en hold
		if _laser_phase == LaserPhase.TRAVEL:
			_enter_hold()
			_play_wall_hit()

	return false
