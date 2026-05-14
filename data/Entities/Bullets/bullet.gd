extends Area2D

# ─── Configuración por nivel ──────────────────────────────────────────
const BULLET_DATA = {
	0: { "speed": 400.0, "damage": 1,  "life": 0.6,  "anim": "lv3", "is_laser": false },
	1: { "speed": 470.0, "damage": 2,  "life": 99.0, "anim": "lv1", "is_laser": true  },
	2: { "speed": 470.0, "damage": 4,  "life": 99.0, "anim": "lv2", "is_laser": true  },
	3: { "speed": 470.0, "damage": 8,  "life": 99.0, "anim": "lv3", "is_laser": true  }
}

# ─── Láser ────────────────────────────────────────────────────────────
const LASER_START_DIST : float = 48.0
const LASER_END_DIST   : float = 384.0
const LASER_LENGTH     : float = LASER_END_DIST - LASER_START_DIST
const LASER_HOLD_TIME  : float = 1.0
const LASER_DMG_RATE   : float = 0.5

# ─── Estela de sprites ────────────────────────────────────────────────
const STAMP_INTERVAL   : float = 0.03   # segundos entre cada sello
const STAMP_FADE_TIME  : float = 0.35   # fade para disparo rápido (lvl 0)
# Fade proporcional al nivel del tiro cargado
const STAMP_FADE_BY_LEVEL : Array[float] = [0.35, 0.6, 1.0, 1.5]
# Los sellos del láser duran todo el hold para que la trayectoria
# siga visible; los primeros en crearse se irán apagando primero,
# dando efecto de rayo que se desvanece desde el origen.
const LASER_STAMP_FADE : float = LASER_HOLD_TIME

# ─── Fases del láser ──────────────────────────────────────────────────
enum LaserPhase { NONE, TRAVEL, HOLD }

# ─── Nodos ────────────────────────────────────────────────────────────
@onready var animator       : AnimatedSprite2D          = $AnimatedSprite2D
@onready var notifier       : VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var collision      : CollisionShape2D          = $CollisionShape2D
@onready var wall_hit_sound : AudioStreamPlayer2D       = $WallHitSound

# ─── Variables generales ──────────────────────────────────────────────
var level        : int     = 0
var direction    : Vector2 = Vector2.RIGHT
var speed        : float   = 0.0
var damage       : int     = 0
var _is_laser    : bool    = false
var _pierce      : bool    = false
var _lifetime    : float   = 0.0
var _is_vertical : bool    = false
var _origin      : Vector2 = Vector2.ZERO

# ─── Variables del láser ──────────────────────────────────────────────
var _laser_phase             : LaserPhase = LaserPhase.NONE
var _laser_timer             : float      = 0.0
var _laser_dmg_timer         : float      = 0.0
var _original_collision_size : Vector2    = Vector2.ZERO

# ─── Variables de estela ──────────────────────────────────────────────
var _stamp_timer  : float = 0.0
var _stamp_active : bool  = false

# ─── Comportamiento de colisión ───────────────────────────────────────
var _resize_collision_on_hold : bool = true


# ─── Inicialización ───────────────────────────────────────────────────
func setup(lvl: int, dir: Vector2, force_normal: bool = false, resize_collision: bool = true) -> void:
	level     = lvl
	direction = dir
	damage    = BULLET_DATA[lvl]["damage"]
	_lifetime = BULLET_DATA[lvl]["life"]
	_is_laser                 = BULLET_DATA[lvl]["is_laser"] and not force_normal
	_resize_collision_on_hold = resize_collision
	_origin                   = global_position

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
		_pierce            = true
		_stamp_active      = true
		collision.disabled = false
		animator.scale     = Vector2.ONE
		# Empezar en el borde cercano y viajar hacia adelante
		global_position    = _origin + direction * LASER_START_DIST
	else:
		speed         = BULLET_DATA[lvl]["speed"]
		_pierce       = false
		# Estela solo en lvl 0 y si no se forzó bala normal desde afuera
		_stamp_active = (lvl == 0) and not force_normal


func _ready() -> void:
	notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask  = 0b10001  # layer 1 (escenario) y layer 5 (enemigos)
	# Asignar al bus "SFX" antes de que _play_wall_hit() lo mueva al root
	if wall_hit_sound != null:
		wall_hit_sound.bus = "SFX"
	if collision.shape is RectangleShape2D:
		_original_collision_size = (collision.shape as RectangleShape2D).size

	# Destruirse inmediatamente cuando el LevelManager cambie de mapa
	var level_node = get_tree().get_first_node_in_group("level")
	if level_node != null:
		level_node.map_changed.connect(func(_map_name: String) -> void:
			queue_free()
		)


func _on_screen_exited() -> void:
	if not _is_laser:
		queue_free()


# ─── Proceso ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if Globals.playerStay:
		return

	if _is_laser:
		_update_laser(delta)
		return

	# ─── Bala normal ──────────────────────────────────────────────────
	position += direction * speed * delta

	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if _stamp_active:
		_stamp_timer += delta
		if _stamp_timer >= STAMP_INTERVAL:
			_stamp_timer = 0.0
			var fade : float = STAMP_FADE_BY_LEVEL[clamp(level, 0, STAMP_FADE_BY_LEVEL.size() - 1)]
			_stamp_trail(fade)


# ─── Estela de sprites ────────────────────────────────────────────────
# Crea un Area2D con stamp.gd que maneja fade y daño por tick
# manualmente, respetando Globals.playerStay.
const StampScript := preload("res://data/Scripts/stamp.gd")  # ajusta la ruta si es necesario

func _stamp_trail(fade_time: float) -> void:
	if animator.sprite_frames == null:
		return
	var texture : Texture2D = animator.sprite_frames.get_frame_texture(
		animator.animation, animator.frame)
	if texture == null:
		return

	# Nodo raiz: Area2D con stamp.gd
	var stamp_area             := Area2D.new()
	stamp_area.set_script(StampScript)
	stamp_area.collision_layer  = 0
	stamp_area.collision_mask   = 0b10000  # layer 5 (enemigos)
	get_tree().root.add_child(stamp_area)
	stamp_area.global_position  = global_position

	# Sprite visual
	var spr      := Sprite2D.new()
	spr.texture  = texture
	spr.scale    = animator.scale
	spr.flip_h   = animator.flip_h
	spr.flip_v   = animator.flip_v
	spr.offset   = animator.offset
	spr.modulate = Color(1.0, 1.0, 1.0, 1.0)
	stamp_area.add_child(spr)

	# Colision
	var col   := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size  = _original_collision_size
	col.shape  = rect
	stamp_area.add_child(col)

	# Configurar el stamp
	stamp_area._fade_time = fade_time
	stamp_area._damage    = damage
	stamp_area._spr       = spr


# ─── Lógica del láser ─────────────────────────────────────────────────
func _update_laser(delta: float) -> void:
	match _laser_phase:

		LaserPhase.TRAVEL:
			global_position += direction * speed * delta

			# Sellar sprite a lo largo del recorrido
			_stamp_timer += delta
			if _stamp_timer >= STAMP_INTERVAL:
				_stamp_timer = 0.0
				_stamp_trail(LASER_STAMP_FADE)

			# ¿Llegó al destino?
			var traveled : float = (global_position - (_origin + direction * LASER_START_DIST)
				).dot(direction)
			if traveled >= LASER_LENGTH:
				global_position = _origin + direction * LASER_END_DIST
				_enter_hold()

		LaserPhase.HOLD:
			_laser_timer     += delta
			_laser_dmg_timer += delta

			if _laser_dmg_timer >= LASER_DMG_RATE:
				_laser_dmg_timer = 0.0
				_deal_laser_damage()

			if _laser_timer >= LASER_HOLD_TIME:
				queue_free()


# Centra el nodo en el área recorrida y expande la colisión para cubrirla.
func _enter_hold() -> void:
	_laser_phase     = LaserPhase.HOLD
	_laser_timer     = 0.0
	_laser_dmg_timer = 0.0
	_stamp_active    = false

	# Longitud real recorrida (por si chocó con una pared antes del final)
	var start_pos     := _origin + direction * LASER_START_DIST
	var actual_length := clampf(
		(global_position - start_pos).dot(direction), 1.0, LASER_LENGTH)

	# Solo reposicionar al punto medio si también se redimensiona la colisión
	# (el Spur no lo hace, así que la bala se queda donde está)
	if _resize_collision_on_hold:
		global_position = start_pos + direction * (actual_length * 0.5)
		if collision.shape is RectangleShape2D:
			var shape := collision.shape as RectangleShape2D
			if _is_vertical:
				shape.size = Vector2(_original_collision_size.x, actual_length)
			else:
				shape.size = Vector2(actual_length, _original_collision_size.y)


func _deal_laser_damage() -> void:
	var bodies := get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		elif body.is_in_group("destructible") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)


# ─── Colisión ─────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	print("[bullet] body_entered: ", body.name, "  groups: ", body.get_groups())
	if _is_laser:
		if body.is_in_group("enemies"):
			# Daño de contacto mientras el láser viaja
			if _laser_phase == LaserPhase.TRAVEL and body.has_method("take_damage"):
				body.take_damage(damage, global_position)
		else:
			# Pared: detener el recorrido y entrar en hold
			if _laser_phase == LaserPhase.TRAVEL:
				_enter_hold()
				_play_wall_hit()
	else:
		print("[bullet] es bala normal — en grupo enemies: ", body.is_in_group("enemies"))
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		elif body.is_in_group("destructible") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		else:
			_play_wall_hit()
		queue_free()


# ─── Sonido de impacto en pared ───────────────────────────────────────
func _play_wall_hit() -> void:
	if wall_hit_sound == null or wall_hit_sound.stream == null:
		return
	remove_child(wall_hit_sound)
	get_tree().root.add_child(wall_hit_sound)
	wall_hit_sound.global_position = global_position
	wall_hit_sound.play()
	wall_hit_sound.finished.connect(wall_hit_sound.queue_free)
