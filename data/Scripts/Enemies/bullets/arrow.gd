class_name Arrow
extends Area2D
## Proyectil reutilizable para cualquier enemigo con arco/ballesta.
## Soporta dos modos de disparo:
##
##   1) launch_arc(direccion, ...)     -> disparo parabólico (sube y cae),
##                                         como el Archer básico.
##   2) launch_straight(direction)     -> disparo recto en cualquier ángulo
##                                         (incluye apuntar arriba/abajo),
##                                         útil para un arquero "inteligente"
##                                         que apunta directo al jugador.
##
## La animación se elige sola en cada frame según hacia dónde apunta la
## velocidad actual (no según quién la disparó), así que sirve para
## cualquier tipo de arquero sin tocar este script.
##
## Estructura de nodos esperada en Arrow.tscn:
##   Arrow (Area2D)                    ← este script
##   ├─ AnimatedSprite2D                (animaciones: left, right, up, down,
##   │                                   diagonal_left_up, diagonal_right_up,
##   │                                   diagonal_left_down, diagonal_right_down)
##   ├─ CollisionShape2D
##   └─ VisibleOnScreenNotifier2D       (opcional)
##
## Conectar señales en el editor:
##   Arrow.body_entered                       -> _on_body_entered
##   VisibleOnScreenNotifier2D.screen_exited   -> _on_screen_exited  (si lo usás)

@onready var asprite : AnimatedSprite2D = $AnimatedSprite2D

@export var speed    : float = 260.0
@export var damage   : int   = 5
@export var lifetime : float = 3.0   ## se destruye sola si no golpea nada

## Umbral de |vx| por debajo del cual se considera "disparo vertical puro"
## (usa las animaciones up/down en vez de una diagonal).
const VERTICAL_THRESHOLD : float = 20.0
## Umbral de |vy| por debajo del cual se considera que está "en el ápice"
## del arco (usa left/right en vez de una diagonal).
const APEX_THRESHOLD : float = 40.0

var velocity      : Vector2 = Vector2.ZERO
var _gravity      : float   = 0.0   ## 0 = línea recta, >0 = cae en parábola
var _time_alive   : float   = 0.0
var _current_anim : String  = ""

## Quien disparó esta flecha. Se ignora a sí mismo en _on_body_entered
## para que nunca choque contra su propio dueño (útil con offsets chicos
## o si el jugador queda pegado al enemigo que dispara).
var shooter : Node2D = null


# ── API de disparo ──────────────────────────────────────────────────

## Disparo en arco (parábola), tipo catapulta: sale con impulso hacia
## arriba y la gravedad la va curvando hasta que cae. Es la que usa el
## Archer básico (ver archer_example.gd).
##   direccion       : -1 izquierda, 1 derecha
##   horizontal_speed: velocidad constante en X
##   vertical_speed  : impulso inicial en Y (negativo = hacia arriba)
##   g               : gravedad aplicada sobre la flecha en vuelo
func launch_arc(direccion: float, horizontal_speed: float = speed, vertical_speed: float = -260.0, g: float = 700.0) -> void:
	_gravity = g
	velocity = Vector2(horizontal_speed * sign(direccion), vertical_speed)


## Disparo recto en cualquier ángulo (sin gravedad): sirve para un
## arquero "inteligente" que apunta directo al jugador, incluyendo tiros
## bien verticales hacia arriba o abajo (torres, plataformas, etc).
##   direction: vector hacia el objetivo (no hace falta normalizado).
func launch_straight(direction: Vector2) -> void:
	_gravity = 0.0
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	velocity = direction.normalized() * speed


# ── Movimiento y animación ───────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _gravity > 0.0:
		velocity.y += _gravity * delta

	position += velocity * delta
	_update_animation()

	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


## Elige la animación según hacia dónde apunta la velocidad ACTUAL, no
## según la dirección de disparo original. Esto logra el efecto pedido:
## diagonal_*_up mientras sube, left/right cerca del ápice (vy chico),
## diagonal_*_down mientras cae, y up/down cuando el tiro es
## prácticamente vertical.
func _update_animation() -> void:
	var vx := velocity.x
	var vy := velocity.y
	var going_right := vx >= 0.0

	var anim_name : String

	if absf(vx) < VERTICAL_THRESHOLD:
		anim_name = "up" if vy < 0.0 else "down"
	elif absf(vy) < APEX_THRESHOLD:
		anim_name = "right" if going_right else "left"
	elif vy < 0.0:
		anim_name = "diagonal_right_up" if going_right else "diagonal_left_up"
	else:
		anim_name = "diagonal_right_down" if going_right else "diagonal_left_down"

	if anim_name != _current_anim:
		_current_anim = anim_name
		asprite.play(anim_name)


# ── Colisiones ────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	# --- DEBUG temporal: borrar cuando quede confirmado ---
	var body_layer : int = body.collision_layer if body is CollisionObject2D else -1
	print("[Arrow] body_entered -> ", body.name, " | body.collision_layer=", body_layer, " | arrow.collision_mask=", collision_mask)
	# -------------------------------------------------------

	if body == shooter:
		return   # nunca choca contra quien la disparó

	if body.is_in_group("player"):
		body.take_damage(damage, global_position)
		queue_free()
	else:
		# Cualquier otra cosa que la Mask le permita detectar (escenario,
		# paredes, TileMap/TileMapLayer, etc): se clava y desaparece.
		# No filtramos por tipo de nodo a propósito, porque en Godot 4.3+
		# el TileMap pasó a llamarse TileMapLayer, y filtrar por clase
		# rompe según la versión. El Mask ya se encarga de que solo
		# entren acá cosas contra las que debe chocar.
		queue_free()


func _on_screen_exited() -> void:
	queue_free()
