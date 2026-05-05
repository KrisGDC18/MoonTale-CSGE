extends Camera2D

# ─── Suavizado ────────────────────────────────────────────────────────
# Cave Story tiene un seguimiento rápido pero no instantáneo
const FOLLOW_SPEED_X  := 8.0   # qué tan rápido sigue horizontalmente
const FOLLOW_SPEED_Y  := 6.0   # vertical un poco más lento

# ─── Offset horizontal (look-ahead) ──────────────────────────────────
# La cámara se adelanta en la dirección que mira el jugador
# igual que Cave Story — revela más terreno al frente
const LOOK_AHEAD_X    := 40.0  # píxeles de adelanto horizontal
const LOOK_AHEAD_SPEED := 4.0  # qué tan rápido se desplaza el adelanto

# ─── Offset vertical ─────────────────────────────────────────────────
# Cave Story baja la cámara cuando el jugador cae
# para revelar más terreno debajo
const FALL_OFFSET_Y   := 30.0  # píxeles que baja la cámara al caer
const FALL_OFFSET_SPEED := 3.0 # qué tan rápido baja/sube el offset

var _target_offset    := Vector2.ZERO  # offset objetivo hacia el que se mueve
var _current_offset   := Vector2.ZERO  # offset actual interpolado

@onready var player = get_parent()  # el jugador es el padre de la cámara


func _ready():
	# desanclar la cámara del jugador para moverla de forma independiente
	top_level = true
	# posición inicial = posición del jugador
	global_position = player.global_position


func _physics_process(delta: float) -> void:
	_update_target_offset()
	_follow_player(delta)


func _update_target_offset() -> void:
	# ── Offset horizontal (look-ahead) ──────────────────────────────
	# adelantarse en la dirección que mira el jugador
	# lastDirection: 0 = derecha, 1 = izquierda
	if player.lastDirection == 0:
		_target_offset.x = LOOK_AHEAD_X   # adelantar a la derecha
	else:
		_target_offset.x = -LOOK_AHEAD_X  # adelantar a la izquierda

	# ── Offset vertical (caída) ──────────────────────────────────────
	# bajar la cámara solo cuando el jugador está cayendo
	if not player.is_on_floor() and player.velocity.y > 0:
		_target_offset.y = FALL_OFFSET_Y   # cayendo → bajar cámara
	else:
		_target_offset.y = 0.0             # en suelo o subiendo → centrar


func _follow_player(delta: float) -> void:
	# interpolar el offset actual hacia el objetivo
	# da el efecto suave de adelanto sin saltos bruscos
	_current_offset.x = lerp(_current_offset.x, _target_offset.x, LOOK_AHEAD_SPEED * delta)
	_current_offset.y = lerp(_current_offset.y, _target_offset.y, FALL_OFFSET_SPEED * delta)
	var target_pos: Vector2 = player.global_position + _current_offset
	# posición objetivo de la cámara = jugador + offset interpolado

	# seguir al jugador con suavizado distinto en X e Y
	global_position.x = lerp(global_position.x, target_pos.x, FOLLOW_SPEED_X * delta)
	global_position.y = lerp(global_position.y, target_pos.y, FOLLOW_SPEED_Y * delta)
