extends Area2D
var health: int = 3
@onready var anim: AnimatedSprite2D = $heart


func _ready() -> void:
	anim.play("small")




func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player.health(health)
		queue_free()
