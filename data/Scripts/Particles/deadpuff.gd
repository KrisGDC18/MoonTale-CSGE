extends Node2D

@onready var puff: AnimatedSprite2D = $DeadPuff
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	puff.play("puff")
	await puff.animation_finished
	queue_free()
