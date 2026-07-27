extends Node2D

# Escena raíz de la partícula de humo del booster.
# Estructura esperada: este nodo (Node2D) con un AnimatedSprite2D hijo
# llamado "AnimatedSprite2D", con una animación (por ejemplo "puff").
#
# Se autodestruye apenas termina de mostrar el último frame de la
# animación UNA sola vez, sin importar si la animación está configurada
# en loop o no (se detecta el frame directamente, en vez de depender
# de animation_finished o de calcular una duración).

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D

const DRIFT_SPEED := 18.0  # px/s, movimiento leve mientras dura la animación

var drift : Vector2 = Vector2.ZERO  # dirección de deriva, la fija quien instancia el puff
var _freed         : bool = false
var _reached_last  : bool = false

func _ready() -> void:
	sprite.play()

func _process(delta: float) -> void:
	if drift != Vector2.ZERO:
		global_position += drift * DRIFT_SPEED * delta

	if _freed or _reached_last:
		return

	var frames := sprite.sprite_frames
	var anim   := sprite.animation
	if not frames or not frames.has_animation(anim):
		return

	var last_frame := frames.get_frame_count(anim) - 1
	if sprite.frame >= last_frame:
		_reached_last = true
		sprite.pause()  # congela el sprite en el último frame, no lo deja loopear
		# Espera lo que dura ese último frame para que se alcance a ver,
		# y recién ahí destruye el nodo.
		var fps : float = frames.get_animation_speed(anim) * max(sprite.speed_scale, 0.01)
		var hold_time : float = (1.0 / fps) if fps > 0.0 else 0.0
		get_tree().create_timer(hold_time).timeout.connect(_die)

func _die() -> void:
	if _freed:
		return
	_freed = true
	queue_free()
