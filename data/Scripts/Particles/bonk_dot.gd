extends Node2D

# Chispa de 4 puntas (estilo Cave Story) que aparece al golpear el techo.
# Se dibuja por código: dos rombos superpuestos (uno vertical más largo,
# uno horizontal más corto) forman la estrella de 4 puntas. Aparece con
# un pequeño flash de escala y se desvanece rápido.

const COLOR      := Color(1.0, 1.0, 1.0)  # blanco
const SIZE       := 5.0     # tamaño de la punta larga (vertical)
const LIFETIME   := 0.22    # segundos que dura visible
const POP_TIME   := 0.05    # tiempo del "pop" inicial (crece rápido y luego se achica)
const TRAVEL_DISTANCE := 16.0  # píxeles que recorre horizontalmente antes de desaparecer

var travel_dir : float = 0.0  # -1 = hacia la izquierda, 1 = hacia la derecha (lo fija quien la instancia)
var _time : float = 0.0

func _draw() -> void:
	var v : float = SIZE
	var h : float = SIZE * 0.35
	# Rombo vertical (punta arriba/abajo)
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, -v), Vector2(h, 0), Vector2(0, v), Vector2(-h, 0)]),
		COLOR
	)
	# Rombo horizontal (punta izquierda/derecha), más corto, formando la estrella
	var v2 : float = SIZE * 0.35
	var h2 : float = SIZE
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, -v2), Vector2(h2, 0), Vector2(0, v2), Vector2(-h2, 0)]),
		COLOR
	)

func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return

	if travel_dir != 0.0:
		global_position.x += travel_dir * (TRAVEL_DISTANCE / LIFETIME) * delta

	if _time < POP_TIME:
		# Crece rápido al aparecer (efecto "pop")
		var t : float = _time / POP_TIME
		scale = Vector2.ONE * lerp(0.3, 1.15, t)
	else:
		# Se encoge y desvanece el resto del tiempo
		var t : float = (_time - POP_TIME) / (LIFETIME - POP_TIME)
		scale = Vector2.ONE * lerp(1.15, 0.7, t)
		modulate.a = 1.0 - t
