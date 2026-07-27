class_name Archer
extends Enemy
## Arquero que NO se mueve de su lugar: mientras el jugador esté dentro
## de su área de visión, le apunta y dispara en línea recta SOLO en las
## 4 direcciones cardinales (arriba, abajo, izquierda, derecha — nunca
## diagonal). Si el jugador sale de su visión, vuelve a quedar en reposo.
##
## Todo esto ya no requiere sobreescribir estados enteros: se logra con
## las banderas de comportamiento (can_chase, stationary_attack) que
## viven en la clase base Enemy. Lo único propio del Archer es CÓMO
## dispara (_perform_attack), que sigue siendo un hook normal.

@export var arrow_scene : PackedScene = preload("res://data/Entities/enemies/bullets/arrow.tscn")

## Distancia a la que aparece la flecha respecto al centro del arquero,
## para que nazca afuera de su propio sprite/colisión.
@export var muzzle_offset : float = 20.0

const DROP := preload("res://data/Entities/Misc/xp_point.tscn")


func _on_ready() -> void:
	MAX_HP        = 12
	damage        = 5
	cooldown      = 2.2
	vision_range  = 260.0

	# Tabla de drops: solo XP, siempre 2-3 unidades al morir. Alternativa:
	# armar un recurso .tres desde el editor y asignarlo directo al
	# campo `Drop Table` del Inspector de Archer.tscn, sin código.
	var xp_entry := DropEntry.new()
	xp_entry.scene     = DROP
	xp_entry.is_xp     = true
	xp_entry.xp_min    = 1
	xp_entry.xp_max    = 3
	xp_entry.min_count = 2
	xp_entry.max_count = 3
	xp_entry.weight    = 1.0

	drop_table = DropTable.new()
	drop_table.entries = [xp_entry]

	# ── Acá está todo lo que antes exigía sobreescribir 3 métodos enteros ──
	can_chase         = false   # nunca camina hacia el jugador
	stationary_attack = true    # se queda fijo mientras dispara


## direccion no se usa: se recalcula el vector real hacia el jugador y se
## "snapea" a la cardinal más cercana (arriba/abajo/izquierda/derecha).
func _perform_attack(_direccion: float) -> void:
	if not arrow_scene or not is_instance_valid(jugador):
		return

	var raw_direction : Vector2 = jugador.global_position - global_position
	var cardinal : Vector2 = _snap_to_cardinal(raw_direction)

	var arrow : Arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)

	# Nace afuera del propio sprite, del lado donde está el jugador.
	arrow.global_position = global_position + cardinal * muzzle_offset

	# La flecha ignora explícitamente a quien la disparó, para que nunca
	# choque contra sí misma (por si el offset no alcanza).
	arrow.shooter = self

	arrow.launch_straight(cardinal)


## Convierte cualquier vector en una de las 4 direcciones cardinales
## puras: Vector2.UP / DOWN / LEFT / RIGHT, según cuál componente
## (horizontal o vertical) sea mayor en el vector original.
func _snap_to_cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) >= absf(direction.y):
		return Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP
