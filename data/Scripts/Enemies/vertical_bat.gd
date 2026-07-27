class_name VerticalBat
extends Enemy
## Murciélago que se mueve SOLO en el eje vertical: sube y baja entre
## dos puntos fijos alrededor de donde lo coloques en el nivel, sin
## desplazarse nunca en X. No persigue (can_chase queda en false):
## si el jugador entra en su columna y a su alcance, puede atacar con
## una pequeña embestida vertical — sin abandonar su línea de patrulla.
##
## Sobreescribe _patrullar()/_atacar() por completo (en vez de usar el
## hover sine de la clase base) para tener control total del vaivén.

@export_group("Patrulla Vertical")
## Distancia TOTAL que recorre entre el punto más alto y el más bajo
## (la mitad para cada lado desde donde arrancó).
@export var patrol_vertical_range : float = 96.0
## Velocidad del vaivén vertical.
@export var patrol_vertical_speed : float = 40.0

@export_group("Ataque")
## Si es false, este murciélago es puramente decorativo: patrulla
## arriba/abajo pero nunca ataca.
@export var can_dive_attack : bool = true
## Tolerancia horizontal (px) para considerar que el jugador está en su
## misma columna y activar el ataque.
@export var dive_align_tolerance : float = 24.0
@export var dive_speed    : float = 260.0
@export var dive_duration : float = 0.35

const DROP := preload("res://data/Entities/Misc/xp_point.tscn")

var _v_dir         : int   = 1
var _v_origin_y    : float = 0.0
var _v_initialized : bool  = false
var _dive_timer    : float = 0.0


func _on_ready() -> void:
	MAX_HP        = 8
	damage        = 2
	cooldown      = 1.1
	vision_range  = 200.0
	attack_range  = 200.0   # alcance vertical del ataque

	movement_type   = MovementType.FLYING
	can_chase       = false   # nunca se mueve en X para perseguir
	hover_amplitude = 0.0     # el vaivén lo maneja este script, no el hover sine de la base
	falls_on_death  = true

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


## Vaivén vertical puro: sube patrol_vertical_range/2 desde donde
## arrancó, baja lo mismo del otro lado, y repite para siempre.
func _vertical_patrol_step() -> void:
	if not _v_initialized:
		_v_origin_y    = global_position.y
		_v_initialized = true

	velocity.x = 0.0
	velocity.y = patrol_vertical_speed * _v_dir

	var travel     : float = global_position.y - _v_origin_y
	var half_range : float = patrol_vertical_range * 0.5

	if _v_dir > 0 and travel >= half_range:
		_v_dir = -1
	elif _v_dir < 0 and travel <= -half_range:
		_v_dir = 1

	asprite.play("default")


func _patrullar(_delta: float) -> void:
	_vertical_patrol_step()


## Sigue en su vaivén vertical incluso "en ataque": nunca se sale de su
## columna. Ataca solo si el jugador está alineado (dive_align_tolerance)
## y a su alcance (attack_range, en vertical).
func _atacar(delta: float) -> void:
	if not playerOnArea:
		estado_enemigo = StatePhase.PATRULLAR
		return

	if _dive_timer > 0.0:
		_dive_timer -= delta
		asprite.play("default")
		return

	_vertical_patrol_step()

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


## Embestida corta, 100% vertical, hacia donde esté el jugador.
func _perform_attack(_direccion: float) -> void:
	var dir_y : float = signf(jugador.global_position.y - global_position.y)
	if dir_y == 0.0:
		dir_y = 1.0

	velocity    = Vector2(0.0, dive_speed * dir_y)
	_dive_timer = dive_duration
	_play_sfx(sfx_jump if sfx_jump != null else sfx_attack)
