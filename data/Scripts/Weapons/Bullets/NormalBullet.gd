class_name NormalBullet
extends Bullet
## Bala "normal": viaja en línea recta a velocidad constante. Se destruye
## al salir de pantalla, al chocar con algo, o al acabarse su tiempo de
## vida. Deja estela de sprites solo en nivel 0 (disparo rápido), salvo
## que force_normal esté activo.

const STAMP_FADE_BY_LEVEL : Array[float] = [0.35, 0.6, 1.0, 1.5]

## true si viene de un arma que "fuerza bala normal" aunque el nivel
## sería de láser (ej. un enemigo que siempre dispara balas simples).
## Solo afecta si deja estela o no.
var force_normal : bool = false


func setup(lvl: int, dir: Vector2, p_force_normal: bool = false) -> void:
	force_normal = p_force_normal
	super.setup(lvl, dir)


func _on_setup() -> void:
	_pierce       = false
	_stamp_active = (level == 0) and not force_normal


func _physics_process(delta: float) -> void:
	if Globals.playerStay:
		return

	position += direction * speed * delta

	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()   # fin de vida por tiempo, no por golpe: sin hit VFX
		return

	if _stamp_active:
		_stamp_timer += delta
		if _stamp_timer >= STAMP_INTERVAL:
			_stamp_timer = 0.0
			var fade : float = STAMP_FADE_BY_LEVEL[clamp(level, 0, STAMP_FADE_BY_LEVEL.size() - 1)]
			_stamp_trail(fade)


## El jugador no cuenta como colisión real para esta bala: se ignora
## por completo (sin hit VFX, sin destruir, sin lógica de daño).
func _should_ignore_hit(body: Node2D) -> bool:
	return body.is_in_group("player")


## Lógica de colisión propia: aplicar daño o sonido de pared. El hit VFX
## y la destrucción de la bala ahora las maneja Bullet._on_body_entered()
## automáticamente — solo hace falta devolver true (siempre se destruye
## al primer golpe, esta bala no perfora).
func _handle_hit(body: Node2D) -> bool:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	elif body.is_in_group("destructible") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	else:
		_play_wall_hit()

	return true
