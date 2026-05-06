extends Node

# ─── Sistema de cura ──────────────────────────────────────────────────
# soporta dos tipos de cura igual que Cave Story:
#   1. Instantánea: corazones pequeños que curan N puntos inmediatamente
#   2. Gradual: corazones grandes que curan lentamente con animación
#
# para curar desde cualquier script:
#   HealSystem.heal_instant(5)        → cura 5 puntos inmediatamente
#   HealSystem.heal_gradual(20, 2.0)  → cura 20 puntos en 2 segundos

const GRADUAL_TICK    : float = 0.08  # segundos entre cada punto de cura gradual
									   # más bajo = cura más rápido

var _player           : CharacterBody2D = null
var _gradual_amount   : int   = 0     # puntos de cura gradual pendientes
var _gradual_timer    : float = 0.0   # acumulador entre ticks de cura gradual
var _is_healing       : bool  = false # true mientras hay cura gradual activa

signal heal_tick(current_life)  # emitido en cada punto curado (para el HUD)
signal heal_finished            # emitido cuando termina la cura gradual


func _ready():
	get_tree().node_added.connect(_on_node_added)
	_find_player()


func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_find_player()


func _find_player() -> void:
	call_deferred("_init_player")


func _init_player() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(delta):
	if not _is_healing or _player == null:
		return

	# ── Cura gradual ──────────────────────────────────────────────────
	# curar un punto cada GRADUAL_TICK segundos hasta agotar _gradual_amount
	_gradual_timer += delta
	if _gradual_timer >= GRADUAL_TICK:
		_gradual_timer = 0.0
		_gradual_amount -= 1

		# curar sin superar la vida máxima
		_player.currentLife = min(
			_player.currentLife + 1,
			_player.PLAYER_MAX_LIFE
		)
		emit_signal("heal_tick", _player.currentLife)

		if _gradual_amount <= 0:
			_is_healing = false
			emit_signal("heal_finished")


# ─── API pública ──────────────────────────────────────────────────────

func heal_instant(amount: int) -> void:
	# cura instantánea — corazón pequeño de Cave Story
	# para llamar desde un item o enemigo al morir:
	#   HealSystem.heal_instant(5)
	if _player == null:
		return
	_player.currentLife = min(
		_player.currentLife + amount,
		_player.PLAYER_MAX_LIFE
	)
	emit_signal("heal_tick", _player.currentLife)


func heal_gradual(amount: int, _duration: float = 0.0) -> void:
	# cura gradual — corazón grande de Cave Story
	# amount: total de puntos a curar
	# _duration: ignorado, la velocidad la controla GRADUAL_TICK
	# para llamar desde un item:
	#   HealSystem.heal_gradual(20)
	if _player == null:
		return
	_gradual_amount += amount  # acumular si ya había cura activa
	_is_healing      = true


func cancel_gradual() -> void:
	# cancelar la cura gradual activa si la hay
	# para llamar si el jugador muere durante la cura:
	#   HealSystem.cancel_gradual()
	_is_healing     = false
	_gradual_amount = 0
	_gradual_timer  = 0.0


func is_healing() -> bool:
	# consultar si hay cura gradual activa
	# útil para el HUD o para animaciones:
	#   if HealSystem.is_healing(): ...
	return _is_healing
