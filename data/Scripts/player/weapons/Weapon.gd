class_name Weapon
extends Node2D

@export var weapon_name    : String    = "Weapon"
@export var max_level      : int       = 3
@export var bullet_scene   : PackedScene
@export var icon           : Texture2D

# ── Sonido de disparo ─────────────────────────────────────────────────
@export_range(0.0, 0.5) var shoot_pitch_variance : float = 0.05

var current_level  : int     = 1
var current_xp     : int     = 0

## Identificador único = ruta de la PackedScene (ej: "res://weapons/PolarStar.tscn").
## WeaponManager lo asigna al instanciar. Úsalo para guardar/cargar sin ningún registro externo.
var weapon_id      : String  = ""

## Devuelve el estado mínimo para SaveSystem.
func get_save_data() -> Dictionary:
	return { "id": weapon_id, "level": current_level, "xp": current_xp }

## Aplica el estado deserializado desde SaveSystem.
func apply_save_data(d: Dictionary) -> void:
	current_level = clamp(d.get("level", 1), 1, max_level)
	current_xp    = d.get("xp", 0)

var _shoot_dir     : Vector2 = Vector2.RIGHT
var _player        : Node    = null
const MAX_BULLETS  : int     = 3
var _bullet_count  : int     = 0

var xp_to_level    : Array[int] = [0, 50, 100]

@onready var animator : AnimatedSprite2D = $AnimatedSprite2D

# Cache de nodos de audio por nivel (ShootAudio1, ShootAudio2, ShootAudio3)
var _audio_nodes : Array[AudioStreamPlayer2D] = [null, null, null]

# Origen de la bala — si existe el nodo BulletOrigin se usa su posición,
# si no existe se usa bullet_spawn_offset como fallback
@export var bullet_spawn_offset : float = 10.0  # distancia en píxeles como fallback
var _bullet_origin : Marker2D = null


func init(player: Node) -> void:
	_player = player


func add_xp(amount: int) -> void:
	if current_level >= max_level:
		return
	current_xp += amount
	if current_xp >= xp_to_level[current_level]:
		current_xp    = 0
		current_level = min(current_level + 1, max_level)
		_on_level_up()


func _on_level_up() -> void:
	print("%s subio a nivel %d" % [weapon_name, current_level])


func weapon_process(delta: float) -> void:
	if Globals.playerStay:
		return


func reset_charge() -> void:
	pass


func _update_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	var facing_x : float = 1.0 if last_direction == 0 else -1.0
	if looking_up:
		_shoot_dir = Vector2.UP
	elif looking_down:
		_shoot_dir = Vector2.DOWN
	else:
		_shoot_dir = Vector2(facing_x, 0.0)


func _handle_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	var facing : String = "right" if last_direction == 0 else "left"
	var anim : String
	if looking_up:
		anim = "idle_%s_up" % facing
	elif looking_down:
		anim = "idle_%s_down" % facing
	else:
		anim = "idle_%s" % facing

	if animator.animation != anim:
		animator.play(anim)


# ── Obtener posición de origen de la bala ─────────────────────────────
func _get_bullet_spawn_pos() -> Vector2:
	# Buscar BulletOrigin lazy la primera vez
	if _bullet_origin == null:
		_bullet_origin = get_node_or_null("BulletOrigin")

	if _bullet_origin != null:
		# Usar la posición global del Marker2D — se ajusta desde el editor
		return _bullet_origin.global_position
	else:
		# Fallback: offset desde el centro del arma en la dirección de disparo
		return global_position + _shoot_dir * bullet_spawn_offset


# ── Reproducir sonido según nivel (1, 2 o 3) ─────────────────────────
func _play_shoot_sound(lvl: int = 1) -> void:
	var index : int = clamp(lvl - 1, 0, 2)

	if _audio_nodes[index] == null:
		_audio_nodes[index] = get_node_or_null("ShootAudio%d" % (index + 1))

	if _audio_nodes[index] == null and index > 0:
		if _audio_nodes[0] == null:
			_audio_nodes[0] = get_node_or_null("ShootAudio1")
		_audio_nodes[index] = _audio_nodes[0]

	var audio : AudioStreamPlayer2D = _audio_nodes[index]
	if audio == null:
		push_error("Weapon [%s]: no se encontró ShootAudio1" % weapon_name)
		return

	audio.pitch_scale = 1.0 + randf_range(-shoot_pitch_variance, shoot_pitch_variance)
	audio.play()


func _spawn_bullet(lvl: int) -> void:
	push_error("Weapon._spawn_bullet() debe sobreescribirse en: %s" % weapon_name)
