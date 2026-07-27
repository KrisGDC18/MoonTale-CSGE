class_name DiverBat
extends Enemy
## Murciélago que NO abandona su zona: flota fijo en el aire (igual que
## el Archer pero volando) y solo ataca con una embestida en línea
## recta — hacia ABAJO o hacia ARRIBA, nunca en diagonal ni horizontal —
## cuando el jugador pasa justo por su misma columna. Pensado para
## colgar de un techo (embiste hacia abajo) o esperar bajo una
## plataforma (embiste hacia arriba).
##
## La dirección de embestida y si ataca o no son 100% configurables
## desde el Inspector, sin tocar código.

enum DiveDirection { AUTO, DOWN, UP }

@export_group("Embestida")
## Si es false, el murciélago solo flota decorativamente: nunca ataca
## (útil para versiones "dormidas" o puramente ambientales).
@export var can_dive_attack : bool = true
## AUTO: embiste hacia donde esté el jugador (arriba o abajo, según
## corresponda en cada ocasión). DOWN: siempre embiste hacia abajo,
## sin importar dónde esté el jugador (ideal colgado de un techo).
## UP: siempre embiste hacia arriba (ideal escondido bajo una plataforma).
@export var dive_direction : DiveDirection = DiveDirection.AUTO
## Velocidad de la embestida (independiente de movVelx, que acá solo se
## usa como referencia de otras cosas si hiciera falta).
@export var dive_speed : float = 320.0
## Cuánto dura el impulso de la embestida antes de volver a flotar en
## el lugar. Muy corto = un "tirón" seco; más largo = una pasada larga.
@export var dive_duration : float = 0.4
## Tolerancia horizontal (px) para considerar que el jugador está "en
## la misma columna" y activar la embestida.
@export var dive_align_tolerance : float = 24.0

const DROP := preload("res://data/Entities/Misc/xp_point.tscn")

var _dive_timer : float = 0.0


func _on_ready() -> void:
	MAX_HP        = 8
	damage        = 3
	cooldown      = 1.4
	vision_range  = 240.0
	attack_range  = 220.0   # alcance vertical de la embestida

	movement_type      = MovementType.FLYING
	can_chase          = false   # nunca sale de su zona
	stationary_attack  = true    # flota en el lugar (lo maneja este script)
	hover_amplitude    = 6.0
	hover_speed        = 2.0
	falls_on_death     = true

	var xp_entry := DropEntry.new()
	xp_entry.scene     = DROP
	xp_entry.is_xp     = true
	xp_entry.xp_min    = 1
	xp_entry.xp_max    = 2
	xp_entry.min_count = 1
	xp_entry.max_count = 2
	xp_entry.weight    = 1.0

	drop_table = DropTable.new()
	drop_table.entries = [xp_entry]


## Estado de ataque completo y propio (no usa el _atacar genérico de
## Enemy): flota fijo, y solo embiste cuando el jugador está alineado
## en su misma columna. Mientras dura el impulso de la embestida
## (_dive_timer > 0), no deja que el hover le pise la velocidad.
func _atacar(delta: float) -> void:
	if not playerOnArea:
		estado_enemigo = StatePhase.PATRULLAR
		return

	asprite.play("default")

	if _dive_timer > 0.0:
		_dive_timer -= delta
		return

	# Hover normal mientras espera el próximo ataque.
	velocity.x = 0.0
	if hover_amplitude > 0.0:
		_hover_time += delta * hover_speed
		velocity.y = cos(_hover_time) * hover_amplitude * hover_speed
	else:
		velocity.y = 0.0

	if not can_dive_attack:
		return

	var aligned  : bool = _horizontal_dist_to_player() <= dive_align_tolerance
	var in_reach : bool = _vertical_gap_to_player() <= attack_range

	if not (aligned and in_reach):
		return

	attackcd += delta
	if attackcd >= cooldown:
		attackcd = 0.0
		_perform_attack(0.0)


## Embestida 100% vertical: ignora cualquier componente horizontal.
func _perform_attack(_direccion: float) -> void:
	var dir_y : float

	match dive_direction:
		DiveDirection.DOWN:
			dir_y = 1.0
		DiveDirection.UP:
			dir_y = -1.0
		_:   # AUTO
			dir_y = signf(jugador.global_position.y - global_position.y)
			if dir_y == 0.0:
				dir_y = 1.0

	velocity     = Vector2(0.0, dive_speed * dir_y)
	_dive_timer  = dive_duration
	_play_sfx(sfx_jump if sfx_jump != null else sfx_attack)
