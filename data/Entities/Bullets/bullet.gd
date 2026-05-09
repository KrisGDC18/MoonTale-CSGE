extends Area2D

# ─── Configuración por nivel ──────────────────────────────────────────
const BULLET_DATA = {
	0: { "speed": 400.0, "damage": 1,  "life": 0.6,  "anim": "lv3", "is_laser": false },
	1: { "speed": 470.0, "damage": 3,  "life": 99.0, "anim": "lv1", "is_laser": true  },
	2: { "speed": 470.0, "damage": 5,  "life": 99.0, "anim": "lv2", "is_laser": true  },
	3: { "speed": 470.0, "damage": 8,  "life": 99.0, "anim": "lv3", "is_laser": true  }
}

# ─── Estiramiento normal ──────────────────────────────────────────────
const STRETCH_DURATION : float   = 0.1
const STRETCH_AMOUNT_H : Vector2 = Vector2(2.2, 0.6)
const STRETCH_AMOUNT_V : Vector2 = Vector2(0.6, 2.2)

# ─── Láser ────────────────────────────────────────────────────────────
const LASER_START_DIST : float = 48.0
const LASER_END_DIST   : float = 384.0
const LASER_LENGTH     : float = LASER_END_DIST - LASER_START_DIST
const LASER_HOLD_TIME  : float = 3.0
const LASER_DMG_RATE   : float = 0.5
const SPRITE_SIZE      : float = 16.0

# ─── Fases del láser ──────────────────────────────────────────────────
enum LaserPhase { NONE, TRAVEL, HOLD, COMPRESS }

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var animator       : AnimatedSprite2D          = $AnimatedSprite2D
@onready var notifier       : VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var collision      : CollisionShape2D          = $CollisionShape2D
@onready var wall_hit_sound : AudioStreamPlayer2D       = $WallHitSound

# ─── Variables generales ──────────────────────────────────────────────
var level          : int     = 0
var direction      : Vector2 = Vector2.RIGHT
var speed          : float   = 0.0
var damage         : int     = 0
var _is_laser      : bool    = false
var _pierce        : bool    = false
var _do_stretch    : bool    = true
var _lifetime      : float   = 0.0
var _stretch_timer : float   = 0.0
var _is_vertical   : bool    = false
var _origin        : Vector2 = Vector2.ZERO

# ─── Variables del láser ──────────────────────────────────────────────
var _laser_phase      : LaserPhase = LaserPhase.NONE
var _laser_timer      : float      = 0.0
var _laser_dmg_timer  : float      = 0.0
var _laser_length_cur : float      = 0.0
var _laser_max_length : float      = LASER_LENGTH
var _laser_end_pos    : float      = 0.0
var _laser_start_cur  : float      = 0.0


# ─── Inicialización ───────────────────────────────────────────────────
func setup(lvl: int, dir: Vector2, do_stretch: bool = true, force_normal: bool = false) -> void:
	level       = lvl
	direction   = dir
	damage      = BULLET_DATA[lvl]["damage"]
	_lifetime   = BULLET_DATA[lvl]["life"]
	_is_laser   = BULLET_DATA[lvl]["is_laser"] and not force_normal
	_do_stretch = do_stretch
	_origin     = global_position

	var anim_base : String = BULLET_DATA[lvl]["anim"]
	var dir_name  : String

	if abs(dir.x) > abs(dir.y):
		dir_name     = "right" if dir.x > 0 else "left"
		_is_vertical = false
	elif dir.y < 0:
		dir_name     = "up"
		_is_vertical = true
	else:
		dir_name     = "down"
		_is_vertical = true

	animator.play("%s_%s" % [anim_base, dir_name])

	if _is_laser:
		speed              = BULLET_DATA[lvl]["speed"]
		_laser_phase       = LaserPhase.TRAVEL
		_laser_length_cur  = 0.0
		_laser_start_cur   = 0.0
		_laser_max_length  = LASER_LENGTH
		_laser_end_pos     = LASER_LENGTH
		collision.disabled = true
		_pierce            = true
		global_position    = _origin + direction * LASER_START_DIST
		animator.scale     = Vector2.ONE
	else:
		speed   = BULLET_DATA[lvl]["speed"]
		_pierce = false
		if _do_stretch:
			if _is_vertical:
				animator.scale = STRETCH_AMOUNT_V
			else:
				animator.scale = STRETCH_AMOUNT_H
			_stretch_timer = STRETCH_DURATION


func _ready() -> void:
	notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 0b10001  # layer 1 (escenario) y layer 5 (enemigos)a


func _on_screen_exited() -> void:
	if not _is_laser:
		queue_free()


# ─── Proceso ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _is_laser:
		_update_laser(delta)
		return

	# ─── Bala normal ──────────────────────────────────────────────────
	position += direction * speed * delta

	if _do_stretch and _stretch_timer > 0.0:
		_stretch_timer -= delta
		var t : float = 1.0 - (_stretch_timer / STRETCH_DURATION)
		if _is_vertical:
			animator.scale = STRETCH_AMOUNT_V.lerp(Vector2.ONE, t)
		else:
			animator.scale = STRETCH_AMOUNT_H.lerp(Vector2.ONE, t)

	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


# ─── Lógica del láser ─────────────────────────────────────────────────
func _update_laser(delta: float) -> void:
	match _laser_phase:

		LaserPhase.TRAVEL:
			_laser_length_cur += speed * delta
			_laser_length_cur  = min(_laser_length_cur, _laser_max_length)
			_apply_laser_scale(_laser_start_cur, _laser_length_cur)

			if _laser_length_cur >= _laser_max_length:
				_laser_end_pos     = _laser_length_cur
				_laser_phase       = LaserPhase.HOLD
				_laser_timer       = 0.0
				_laser_dmg_timer   = 0.0
				collision.disabled = false

		LaserPhase.HOLD:
			_laser_timer     += delta
			_laser_dmg_timer += delta

			if _laser_dmg_timer >= LASER_DMG_RATE:
				_laser_dmg_timer = 0.0
				_deal_laser_damage()

			if _laser_timer >= LASER_HOLD_TIME:
				_laser_phase       = LaserPhase.COMPRESS
				_laser_timer       = 0.0
				_laser_start_cur   = 0.0
				collision.disabled = true

		LaserPhase.COMPRESS:
			_laser_start_cur += speed * delta
			_laser_start_cur  = min(_laser_start_cur, _laser_end_pos)
			var remaining : float = _laser_end_pos - _laser_start_cur
			_apply_laser_scale(_laser_start_cur, _laser_end_pos)

			if remaining <= 0.0:
				queue_free()


func _apply_laser_scale(start: float, end: float) -> void:
	var length       : float = max(end - start, 0.01)
	var scale_factor : float = length / SPRITE_SIZE
	var center       : float = LASER_START_DIST + start + length * 0.5

	if _is_vertical:
		animator.scale  = Vector2(1.0, scale_factor)
		global_position = _origin + direction * center
	else:
		animator.scale  = Vector2(scale_factor, 1.0)
		global_position = _origin + direction * center


func _deal_laser_damage() -> void:
	var bodies := get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)


# ─── Colisión ─────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if _is_laser:
		if not body.is_in_group("enemies"):
			if _laser_phase == LaserPhase.TRAVEL:
				_laser_max_length  = _laser_length_cur
				_laser_end_pos     = _laser_length_cur
				_laser_phase       = LaserPhase.HOLD
				_laser_timer       = 0.0
				_laser_dmg_timer   = 0.0
				collision.disabled = false
				_play_wall_hit()  # Sonido al frenar contra pared
	else:
		if not body.is_in_group("enemies"):
			_play_wall_hit()  # Sonido al chocar con pared
		queue_free()


# ─── Sonido de impacto en pared ───────────────────────────────────────
# Desancla el AudioStreamPlayer2D del bullet antes de liberarlo,
# así el sonido termina de reproducirse aunque el nodo ya no exista.
func _play_wall_hit() -> void:
	if wall_hit_sound == null or wall_hit_sound.stream == null:
		return
	remove_child(wall_hit_sound)
	get_tree().root.add_child(wall_hit_sound)
	wall_hit_sound.global_position = global_position
	wall_hit_sound.play()
	wall_hit_sound.finished.connect(wall_hit_sound.queue_free)
