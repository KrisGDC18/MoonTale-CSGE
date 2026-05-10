## DestructibleBlock.gd
## Bloque que se destruye al recibir un disparo.
##
## ─── Estructura del nodo ─────────────────────────────────────────────
##   StaticBody2D          ← este script
##     Sprite2D            ← visual del bloque (opcional)
##     CollisionShape2D    ← hitbox (layer 1 = escenario)
##
## ─── Integración con balas ───────────────────────────────────────────
##   El bloque se registra en el grupo "destructible".
##   bullet.gd llama take_damage() al impactar con él.
##
## ─── Inspector ───────────────────────────────────────────────────────
##   hp              : vida del bloque (default 1)
##   drop_scene      : escena opcional que aparece al destruirse

extends StaticBody2D

@export var hp         : int          = 1
@export var drop_scene : PackedScene  = null

func _ready() -> void:
	add_to_group("destructible")


func take_damage(amount: int, _hit_pos: Vector2) -> void:
	hp -= amount
	if hp <= 0:
		_destroy()


func _destroy() -> void:
	# Soltar ítem si hay uno configurado
	if drop_scene != null:
		var drop := drop_scene.instantiate()
		drop.global_position = global_position
		get_parent().add_child(drop)

	queue_free()
