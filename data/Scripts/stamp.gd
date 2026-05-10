## stamp.gd
## Nodo de estela del Spur. Se añade en código desde bullet.gd.
## Maneja fade y daño por tick respetando Globals.playerStay.
extends Area2D

const TICK_RATE : float = 0.1

var _elapsed   : float    = 0.0
var _tick      : float    = 0.0
var _fade_time : float    = 1.0
var _damage    : int      = 0
var _spr       : Sprite2D = null


func _process(delta: float) -> void:
	if Globals.playerStay:
		return

	_elapsed += delta
	_tick    += delta

	# Daño por tick
	if _tick >= TICK_RATE:
		_tick = 0.0
		for body in get_overlapping_bodies():
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(_damage, global_position)

	# Fade manual — no usa tween para que playerStay lo pueda pausar
	if _spr != null:
		_spr.modulate.a = clamp(1.0 - (_elapsed / _fade_time), 0.0, 1.0)

	if _elapsed >= _fade_time:
		queue_free()
