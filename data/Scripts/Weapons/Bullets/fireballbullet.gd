class_name FireballBullet
extends Bullet
## Bala de la Fireball (Cave Story): en vez de viajar en línea recta como
## NormalBullet, cae por gravedad y rebota contra el piso un número de
## veces (_bounces_left, seteado desde Fireball.gd vía set_bounces()).
## Un golpe directo a un enemigo la revienta al toque (no rebota sobre
## enemigos); un golpe contra piso/pared consume un rebote, y recién
## cuando se quedan sin rebotes se apaga con el hit VFX + sonido normal.
##
## Hereda de Bullet TODO lo compartido: BULLET_DATA, configure() (rango
## de despawn + VFX + overrides de daño/velocidad), el chequeo de rango
## (_process en la clase base), el sonido de pared (_play_wall_hit) y el
## orquestador de colisión (_on_body_entered). Acá solo se sobreescribe
## el movimiento (gravedad en vez de línea recta) y qué significa "golpe".

@export var fall_gravity              : float = 1600.0
@export var floor_bounce_speed        : float = 260.0  ## velocidad vertical FIJA de cada rebote de piso (no depende de la velocidad de llegada, así todos los botes son iguales). Bajado de 500 a algo más "Cave Story" — subilo si querés que rebote más alto.
@export var max_fall_speed            : float = 700.0
@export var bounce_cooldown           : float = 0.05   ## segundos de "inmunidad" tras rebotar, solo para evitar doble rebote por tunneling en el mismo instante
@export var horizontal_speed_scale    : float = 0.5    ## el fireball no debe viajar tan lejos como una bala recta (BULLET_DATA.speed es para balas rápidas)
@export var horizontal_bounce_retention : float = 1.0  ## cuánta velocidad horizontal conserva en cada rebote de piso (1.0 = distancia constante, sin decaer)
@export var wall_bounce_damping         : float = 1.0  ## velocidad horizontal que conserva al rebotar contra una pared (1.0 = sin perder velocidad)
@export var floor_collision_layer_bit   : int   = 1    ## bit de collision_layer que usa tu escenario/piso (1 = layer 1, igual que collision_mask de Bullet). Ajustá si tu piso está en otra capa.
@export var vertical_shot_horizontal_speed : float = 150.0 ## si el disparo fue vertical (arriba/abajo), velocidad horizontal que le da al primer rebote, hacia donde miraba el jugador

var _velocity        : Vector2 = Vector2.ZERO
var _bounces_left    : int     = 1
var _bounce_lockout  : float   = 0.0
var _floor_ray        : RayCast2D
var _facing_x          : float = 1.0   ## 1.0 = derecha, -1.0 = izquierda (seteado por Fireball.gd vía set_facing())
var _is_vertical_shot  : bool  = false ## true si el tiro original fue arriba/abajo (dir.x ~ 0)


## Creamos el RayCast2D por código para no depender de que la escena
## (copiada de NormalBullet.tscn) tenga uno — así funciona apenas
## reemplaces el script, sin tocar el .tscn. Llama a super._ready()
## PRIMERO para no perder la inicialización de Bullet (conexión de
## señales, collision_layer/mask, etc.).
func _ready() -> void:
	super._ready()
	_floor_ray = RayCast2D.new()
	_floor_ray.target_position = Vector2(0, 10)  # apunta 10px hacia abajo
	_floor_ray.collision_mask   = 1 << (floor_collision_layer_bit - 1)
	_floor_ray.enabled          = true
	add_child(_floor_ray)


## Mismo patrón que NormalBullet: agrega el parámetro force_normal para
## que Fireball._spawn_bullet() pueda llamar bullet.setup(lvl, dir, true)
## sin que truene por cantidad de argumentos.
func setup(lvl: int, dir: Vector2, _p_force_normal: bool = true) -> void:
	super.setup(lvl, dir)  # dispara _on_setup() al final


func _on_setup() -> void:
	_pierce = false

	# Empuje inicial: horizontal según dir * speed * horizontal_speed_scale
	# (bajamos la velocidad de BULLET_DATA porque está pensada para balas
	# rectas rápidas, no para un fireball que debe quedarse cerca), con un
	# empujón hacia arriba si el disparo es casi horizontal, para que se
	# vea la parábola desde el primer instante.
	var effective_speed : float = speed * horizontal_speed_scale
	_velocity = direction.normalized() * effective_speed
	if abs(direction.y) < 0.01:
		_velocity.y -= effective_speed * 0.25

	# Si el tiro fue vertical (arriba/abajo), acá _velocity.x queda en 0
	# — lo marcamos para que, en el primer rebote de piso, arranque
	# horizontalmente hacia donde miraba el jugador (ver set_facing()).
	_is_vertical_shot = abs(direction.x) < 0.01


## Llamado por Fireball._spawn_bullet() para saber hacia qué lado miraba
## el jugador al disparar (0=derecha → 1.0, 1=izquierda → -1.0). Solo
## importa si el tiro fue vertical (ver _is_vertical_shot arriba).
func set_facing(facing_x: float) -> void:
	_facing_x = facing_x


## Llamado por Fireball._spawn_bullet() (ver bounces_by_level en Fireball.gd).
func set_bounces(amount: int) -> void:
	_bounces_left = max(amount, 0)


func _physics_process(delta: float) -> void:
	if Globals.playerStay:
		return

	if _bounce_lockout > 0.0:
		_bounce_lockout -= delta

	_velocity.y = min(_velocity.y + fall_gravity * delta, max_fall_speed)
	position += _velocity * delta

	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()  # fin por tiempo, no por golpe: sin hit VFX (igual que NormalBullet)


## El Fireball no usa límite de distancia (bullet_range_by_level /
## _despawn_range): su ciclo de vida lo marcan los rebotes agotados
## (_bounces_left) y el _lifetime, no cuánto recorrió. Por eso pisamos
## el _process() de Bullet (que es justo el que chequea _despawn_range)
## con un no-op — así ese límite simplemente no aplica acá, sin tener
## que tocar Bullet.gd ni Fireball.gd.
func _process(_delta: float) -> void:
	pass


## El jugador no cuenta como colisión (igual que NormalBullet).
func _should_ignore_hit(body: Node2D) -> bool:
	return body.is_in_group("player")


## Golpe directo a enemigo/destructible → daño y se destruye, sin rebotar
## (como en el original: si le pega de lleno a un enemigo, explota ahí).
## Cualquier otra cosa (piso/pared) → rebota si le quedan rebotes;
## si no le quedan, se apaga con sonido de pared normal.
func _handle_hit(body: Node2D) -> bool:
	if (body.is_in_group("enemies") or body.is_in_group("destructible")) \
			and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		return true

	# Sin rebotes disponibles: se apaga siempre, sin importar el cooldown
	# (si esto quedara atrás del chequeo de lockout, un golpe final que
	# coincida con la ventana de cooldown del rebote anterior se ignoraría
	# por completo y la bala seguiría cayendo "atravesando" el piso).
	if _bounces_left <= 0:
		_play_wall_hit()
		return true

	# Todavía en cooldown del rebote anterior: esto es un re-trigger por
	# tunneling (la bala sigue solapada con el mismo piso), no un rebote
	# nuevo. Lo ignoramos sin gastar otro rebote ni volver a invertir la
	# velocidad (si no, se cancela el rebote anterior a mitad de camino).
	if _bounce_lockout > 0.0:
		return false

	_bounces_left -= 1
	_bounce_lockout = bounce_cooldown

	# ¿Hay piso justo debajo? Chequeo real con raycast en vez de adivinar
	# por la velocidad (eso fallaba cuando la bala nace pegada al piso
	# con poca velocidad vertical acumulada, ej. al disparar parado).
	_floor_ray.force_raycast_update()
	var on_floor : bool = _floor_ray.is_colliding()

	if on_floor:
		_velocity.y = -floor_bounce_speed  # fijo: mismo impulso siempre, sin importar con qué velocidad llegó
		if _is_vertical_shot:
			# Primer rebote de un tiro vertical: no tenía velocidad
			# horizontal (nació apuntando arriba/abajo), así que le damos
			# un arranque hacia donde miraba el jugador al disparar.
			_velocity.x = _facing_x * vertical_shot_horizontal_speed
			_is_vertical_shot = false  # de acá en más, rebota como uno normal
		else:
			_velocity.x *= horizontal_bounce_retention  # cuánto conserva del empuje horizontal en cada rebote
		position.y -= 6.0  # empuja fuera del piso
	else:
		_velocity.x = -_velocity.x * wall_bounce_damping
		position.x += sign(_velocity.x) * 6.0  # empuja fuera de la pared

	return false  # sigue viva — el hit VFX ya lo dispara _on_body_entered()
