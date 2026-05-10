extends Area2D

# ─── Inspector ────────────────────────────────────────────────────────
@export var weapon_scene  : PackedScene  ## Arma que otorga este pickup
@export var xp_if_owned   : int = 50    ## XP extra si el jugador ya la tiene
@export var bob_amplitude : float = 3.0 ## Cuánto flota arriba/abajo (px)
@export var bob_speed     : float = 2.0 ## Velocidad del flotado

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var pickup_sfx : AudioStreamPlayer2D = $pickup_sfx
@onready var sprite     : Sprite2D            = $Sprite2D

# ─── Estado ───────────────────────────────────────────────────────────
var _origin_y  : float = 0.0
var _time      : float = 0.0
var _collected : bool  = false


func _ready() -> void:
	_origin_y = position.y


func _process(delta: float) -> void:
	if _collected:
		return
	# Animación de flotado vertical
	_time      += delta
	position.y  = _origin_y + sin(_time * bob_speed) * bob_amplitude


# ─── Colisión con el jugador ──────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true

	# Buscar el WeaponManager en el árbol
	var wm : Node = get_tree().get_first_node_in_group("weapon_manager")
	if wm == null:
		push_error("WeaponPickup: no se encontró ningún nodo en el grupo 'weapon_manager'")
		queue_free()
		return

	wm.give_weapon(weapon_scene, xp_if_owned)

	# Sonido y desaparición
	sprite.visible = false
	set_deferred("monitoring", false)

	if pickup_sfx.stream != null:
		pickup_sfx.reparent(get_tree().root)
		pickup_sfx.global_position = global_position
		pickup_sfx.play()
		pickup_sfx.finished.connect(pickup_sfx.queue_free)

	queue_free()
