extends RigidBody2D
@onready var asprite: AnimatedSprite2D = $orb
@onready var area: Area2D = $Area2D
var xp_value: int = 1

func _ready():
	asprite.play("small")
	randomize()
	apply_impulse(Vector2(randf_range(-1.05, 1.05), -1.0) * 80.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player.add_weapon_xp(xp_value)
		queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player.add_weapon_xp(xp_value)
		queue_free()
