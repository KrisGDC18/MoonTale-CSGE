class_name OneShotVFX
extends AnimatedSprite2D
## Pegar este script en la raíz de CADA mini-escena de efecto de un solo uso:
## un fogonazo, un despawn, un hit — una escena .tscn POR ARMA (o compartida
## entre varias si el efecto se ve igual, a tu criterio), asignada directo
## desde el Inspector del arma en los campos "Muzzle Flash Default",
## "Bullet Hit Default", etc. (ver Weapon.gd).
##
## Reproduce la animación por defecto del SpriteFrames de ESTA escena y se
## destruye sola al terminar. No necesita configuración adicional: Weapon.gd
## y Bullet.gd solo hacen scene.instantiate() y setean global_position —
## el resto lo maneja este script.

@export var random_rotation : bool = false   ## útil para variar el "hit" visualmente
@export var random_flip     : bool = true    ## voltea aleatoriamente en horizontal
@export var fallback_duration : float = 0.6  ## red de seguridad, ver más abajo


func _ready() -> void:
	if random_flip:
		flip_h = randf() < 0.5
	if random_rotation:
		rotation = randf_range(0.0, TAU)

	# Fuerza loop=false en runtime, sin importar cómo haya quedado guardado
	# el SpriteFrames en el .tscn (evita tener que acordarse de desmarcar
	# "Loop" a mano en cada animación de cada efecto que crees).
	if sprite_frames != null and sprite_frames.has_animation(animation):
		sprite_frames.set_animation_loop(animation, false)

	animation_finished.connect(queue_free)
	play()  # reproduce la animación activa de esta escena

	# Red de seguridad: si por lo que sea animation_finished nunca dispara
	# (SpriteFrames vacío, animación mal configurada, etc.), esto igual
	# destruye el efecto para que nunca quede un sprite fantasma en pantalla.
	get_tree().create_timer(fallback_duration).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
