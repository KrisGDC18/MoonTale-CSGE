class_name Bullet
extends Area2D
## Clase base de las balas. No se instancia directo — usá NormalBullet
## o LaserBullet, que heredan de acá. Contiene todo lo que ambas
## comparten: nodos, configuración por nivel, estela de sprites, sonido
## de impacto en pared, limpieza al cambiar de mapa, y ahora también
## distancia de desaparición + VFX de despawn/hit configurables por arma.

const BULLET_DATA = {
	0: { "speed": 400.0, "damage": 1,  "life": 0.6,  "anim": "lv3", "is_laser": false },
	1: { "speed": 470.0, "damage": 2,  "life": 99.0, "anim": "lv1", "is_laser": true  },
	2: { "speed": 470.0, "damage": 4,  "life": 99.0, "anim": "lv2", "is_laser": true  },
	3: { "speed": 470.0, "damage": 8,  "life": 99.0, "anim": "lv3", "is_laser": true  }
}

const STAMP_INTERVAL : float = 0.03  # segundos entre cada sello de estela

@onready var animator       : AnimatedSprite2D          = $AnimatedSprite2D
@onready var notifier       : VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var collision      : CollisionShape2D          = $CollisionShape2D
@onready var wall_hit_sound : AudioStreamPlayer2D       = $WallHitSound

var level        : int     = 0
var direction    : Vector2 = Vector2.RIGHT
var speed        : float   = 0.0
var damage       : int     = 0
var _pierce      : bool    = false
var _lifetime    : float   = 0.0
var _is_vertical : bool    = false
var _origin      : Vector2 = Vector2.ZERO

var _original_collision_size : Vector2 = Vector2.ZERO
var _stamp_timer    : float = 0.0
var _stamp_active   : bool  = false
var _wall_hit_played : bool = false

# ── Punto 8: distancia de desaparición configurable por arma/nivel ────
## 0 o negativo = sin límite (se destruye por lifetime / pantalla / colisión, como antes).
var _despawn_range   : float = 0.0
var _range_exceeded  : bool  = false  # guard para no disparar el despawn dos veces

# ── Punto 3/4: escenas de VFX configurables por arma/nivel ────────────
var _despawn_vfx_scene : PackedScene = null   ## al agotar el recorrido (sin golpear nada)
var _hit_vfx_scene     : PackedScene = null   ## al colisionar (pared o enemigo)

# ── Daño y velocidad ajustables por arma ───────────────────────────────
## -1 (damage) / -1.0 (speed) = sin override, se usa el valor de BULLET_DATA
## tal como lo pone setup(). Se guardan acá y se aplican en _ready() para
## que el override SIEMPRE gane, sin importar si el arma llama a setup()
## antes o después de configure().
var _damage_override : int   = -1
var _speed_override   : float = -1.0


## Inicialización compartida: nivel, dirección, animación según dirección.
## Las subclases llaman a esto con super.setup(lvl, dir) y después hacen
## su propia configuración específica en _on_setup().
func setup(lvl: int, dir: Vector2) -> void:
	level     = lvl
	direction = dir
	damage    = BULLET_DATA[lvl]["damage"]
	_lifetime = BULLET_DATA[lvl]["life"]
	_origin   = global_position

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
	speed = BULLET_DATA[lvl]["speed"]

	_apply_stat_overrides()  # por si configure() ya corrió antes que setup()
	_on_setup()


## Llamado por Weapon._instantiate_bullet() justo tras crear la instancia
## (antes o después de setup(), no importa el orden — ver nota sobre
## _damage_override/_speed_override más abajo). Es el puente entre la
## configuración del arma (Weapon.gd) y esta bala.
func configure(despawn_range: float, despawn_vfx: PackedScene, hit_vfx: PackedScene,
		damage_override: int = -1, speed_override: float = -1.0) -> void:
	_despawn_range     = despawn_range
	_despawn_vfx_scene = despawn_vfx
	_hit_vfx_scene      = hit_vfx
	_damage_override    = damage_override
	_speed_override      = speed_override
	_apply_stat_overrides()  # por si setup() ya corrió antes que configure()


## Aplica _damage_override/_speed_override sobre damage/speed si están
## seteados (>= 0). Se llama desde 3 lugares (setup(), configure(), _ready())
## para garantizar que el override gane sin importar en qué orden el arma
## termine llamando a cada uno — ver el bug que esto resuelve en el
## historial: antes se aplicaba SOLO en _ready(), y si setup() o configure()
## corrían después de _ready() (como pasa en Spur.gd), el override se perdía.
func _apply_stat_overrides() -> void:
	if _damage_override >= 0:
		damage = _damage_override
	if _speed_override >= 0.0:
		speed = _speed_override


## Hook para inicialización específica de cada subclase.
func _on_setup() -> void:
	pass


func _ready() -> void:
	notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask  = 0b10001  # layer 1 (escenario) y layer 5 (enemigos)
	if wall_hit_sound != null:
		wall_hit_sound.bus = "SFX"
	if collision.shape is RectangleShape2D:
		_original_collision_size = (collision.shape as RectangleShape2D).size

	_apply_stat_overrides()  # red de seguridad final, por si ninguno de los dos arriba corrió a tiempo

	# Destruirse inmediatamente cuando el LevelManager cambie de mapa
	var level_node = get_tree().get_first_node_in_group("level")
	if level_node != null:
		level_node.map_changed.connect(func(_map_name: String) -> void:
			queue_free()
		)


## Chequeo de rango, independiente del movimiento (que vive en el _physics_process
## de cada subclase). Al usar _process en vez de _physics_process no hace falta
## tocar ni sobreescribir el movimiento existente de NormalBullet/LaserBullet.
func _process(_delta: float) -> void:
	if _despawn_range <= 0.0 or _range_exceeded:
		return
	if global_position.distance_to(_origin) >= _despawn_range:
		_range_exceeded = true
		_despawn()


## Punto 3: la bala terminó su recorrido sin golpear nada — ya sea porque
## llegó al límite configurado (_despawn_range) o porque salió de pantalla.
## Siempre reproduce el VFX de despawn antes de destruirse.
func _despawn() -> void:
	_spawn_vfx(_despawn_vfx_scene)
	queue_free()


## Punto 4: helper para que las subclases lo llamen desde su propio
## _on_body_entered() cuando la bala impacta algo (enemigo o pared),
## en el mismo punto donde ya se llama a _play_wall_hit() o se aplica daño.
func _spawn_hit_vfx() -> void:
	_spawn_vfx(_hit_vfx_scene)


func _spawn_vfx(scene: PackedScene) -> void:
	if scene == null:
		return
	var fx := scene.instantiate()
	get_tree().root.add_child(fx)
	if fx is Node2D:
		(fx as Node2D).global_position = global_position


## Comportamiento por defecto al salir de pantalla: desaparecer (con VFX).
## LaserBullet lo sobreescribe (dura por tiempo, no por visibilidad).
func _on_screen_exited() -> void:
	_despawn()


## ORQUESTADOR — NO sobreescribir esto en las subclases. Se encarga de que
## el hit VFX se reproduzca SIEMPRE que haya un golpe real, automáticamente,
## para cualquier bala que herede de Bullet, sin que cada subclase tenga
## que acordarse de llamar a _spawn_hit_vfx() por su cuenta.
##
## Las subclases (NormalBullet, LaserBullet, etc.) implementan su lógica
## de colisión específica sobreescribiendo _handle_hit(body) y, si necesitan
## ignorar ciertos cuerpos por completo (ej. el jugador), _should_ignore_hit(body).
func _on_body_entered(body: Node2D) -> void:
	if _should_ignore_hit(body):
		return

	var should_destroy : bool = _handle_hit(body)
	_spawn_hit_vfx()
	if should_destroy:
		queue_free()


## Hook: cuerpos que no deben contar como golpe en absoluto (ni VFX, ni
## destrucción, ni lógica). Por defecto no ignora nada.
func _should_ignore_hit(_body: Node2D) -> bool:
	return false


## Hook para lógica de colisión específica de cada subclase: aplicar daño,
## reproducir _play_wall_hit(), chequear si la bala perfora (_pierce), etc.
## Devolvé true si la bala debe destruirse tras este golpe (caso normal),
## o false si debe seguir viva (ej. una bala perforante, o un láser cuyo
## ciclo de vida se maneja aparte en su propio _physics_process). El hit
## VFX se reproduce en AMBOS casos, siempre que _should_ignore_hit sea false.
func _handle_hit(_body: Node2D) -> bool:
	return true


# ─── Estela de sprites (compartida) ────────────────────────────────────
const StampScript := preload("res://data/Scripts/Weapons/stamp.gd")  # ajusta la ruta si es necesario

func _stamp_trail(fade_time: float) -> void:
	if animator.sprite_frames == null:
		return
	var texture : Texture2D = animator.sprite_frames.get_frame_texture(
		animator.animation, animator.frame)
	if texture == null:
		return

	var stamp_area              := Area2D.new()
	stamp_area.set_script(StampScript)
	stamp_area.collision_layer   = 0
	stamp_area.collision_mask    = 0b10000  # layer 5 (enemigos)
	get_tree().root.add_child(stamp_area)
	stamp_area.global_position   = global_position

	var spr      := Sprite2D.new()
	spr.texture  = texture
	spr.scale    = animator.scale
	spr.flip_h   = animator.flip_h
	spr.flip_v   = animator.flip_v
	spr.offset   = animator.offset
	spr.modulate = Color(1.0, 1.0, 1.0, 1.0)
	stamp_area.add_child(spr)

	var col   := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size  = _original_collision_size
	col.shape  = rect
	stamp_area.add_child(col)

	stamp_area._fade_time = fade_time
	stamp_area._damage    = damage
	stamp_area._spr       = spr


# ─── Sonido de impacto en pared (compartido) ──────────────────────────
# Guard contra body_entered disparándose más de una vez en el mismo
# frame sobre la misma bala (ver bug anterior).
func _play_wall_hit() -> void:
	if _wall_hit_played:
		return
	if wall_hit_sound == null or wall_hit_sound.stream == null:
		return
	_wall_hit_played = true

	remove_child(wall_hit_sound)
	get_tree().root.add_child(wall_hit_sound)
	wall_hit_sound.global_position = global_position
	wall_hit_sound.play()
	wall_hit_sound.finished.connect(wall_hit_sound.queue_free)
