class_name Enemy
extends CharacterBody2D
## Clase base para todos los enemigos del juego.
##
## Cada enemigo nuevo (slime, esqueleto, murciélago, etc.) hereda de esta
## clase ("extends Enemy") en vez de "extends CharacterBody2D", y solo
## sobreescribe lo que necesita cambiar: stats desde el Inspector, y/o
## los métodos "hook" marcados más abajo (_on_ready, _perform_attack,
## _spawn_death_effects, etc). Toda la maquinaria de estados, vida,
## barra de HP y número de daño ya viene resuelta acá.
##
## Requisito de escena: cada enemigo hijo debe tener estos nodos con
## el mismo nombre (podés armar una escena base .tscn con todos ellos
## y luego heredar escenas de ahí, para no repetir tampoco la parte visual):
##   HPBarRoot (Node2D)
##     ├─ HPBarBG   (ColorRect)
##     └─ HPBarFill (ColorRect)
##   AnimatedSprite2D
##   VisionArea (Area2D)
##   AttackArea (Area2D)
##   DamageArea (Area2D)
##   MoveSFXPlayer (AudioStreamPlayer2D)  ← OPCIONAL: sonido de movimiento en loop.
##   Si el enemigo no tiene este nodo, simplemente no suena sonido de
##   movimiento (no hace falta agregarlo si no lo vas a usar).
##   LedgeCheck    (RayCast2D)  ← OPCIONAL: solo para ai_level = HIGH en
##   tierra. Apunta hacia abajo y un poco adelante, desde el borde del
##   enemigo. Si no detecta piso, evita seguir caminando en esa dirección.
##   ObstacleCheck (RayCast2D) ← OPCIONAL: solo para ai_level = HIGH en
##   Vuelo/Nado. Apunta en la dirección de movimiento; si detecta algo,
##   el enemigo esquiva hacia arriba en vez de chocar de frente.
##
## Los sonidos de una sola vez (ataque, salto, daño) NO necesitan nodo
## propio: se reproducen a través de AudioManager.play_sfx(), que crea
## y destruye su propio AudioStreamPlayer2D temporal por cada sonido.

enum MovementType { GROUND, FLYING, SWIMMING }
enum AILevel { LOW, MEDIUM, HIGH }


# ── Nodos ─────────────────────────────────────────────────────────────
@onready var hp_bar_root : Node2D    = $HPBarRoot
@onready var hp_bar_bg   : ColorRect = $HPBarRoot/HPBarBG
@onready var hp_bar_fill : ColorRect = $HPBarRoot/HPBarFill
@onready var asprite     : AnimatedSprite2D = $AnimatedSprite2D
@onready var areavision  : Area2D = $VisionArea
@onready var attackarea  : Area2D = $AttackArea
@onready var damarea     : Area2D = $DamageArea
@onready var move_sfx_player : AudioStreamPlayer2D = get_node_or_null("MoveSFXPlayer")
## OPCIONALES, solo usados con ai_level = HIGH (ver export más abajo).
@onready var ledge_check    : RayCast2D = get_node_or_null("LedgeCheck")
@onready var obstacle_check : RayCast2D = get_node_or_null("ObstacleCheck")

# ── Stats (cada enemigo hijo ajusta esto desde el Inspector, o
#    sobreescribiendo la variable dentro de su propio _on_ready()) ─────
@export_group("Stats")
## Vida máxima por defecto (20 = la del Slime original). Si un enemigo
## hijo no declara/sobreescribe MAX_HP, usa este valor como fallback.
@export var MAX_HP   : int   = 20
@export var damage   : int   = 3
@export var cooldown : float = 0.75

@export_group("Movimiento")
@export var movVelx      : float = 60.0
@export var movVely      : float = -260.0
@export var grav         : float = 980.0
@export var vision_range : float = 200.0
@export var attack_range : float = 80.0
## Velocidad máxima de caída. Sin esto, un enemigo que cae desde muy
## alto puede acumular tanta velocidad que atraviese el suelo en un
## solo frame (tunneling). 900 ≈ cae una pantalla completa en <1s.
@export var max_fall_speed : float = 900.0
## Diferencia de altura (en píxels) que se tolera para considerar al
## jugador "alcanzable" al perseguir/atacar. Evita que un enemigo trate
## de perseguir a un jugador que está en otro piso/plataforma, aunque
## la distancia en línea recta (diagonal) parezca corta.
@export var max_vertical_reach : float = 60.0
## Cooldown entre saltos por pared, para que no se dispare en ráfaga si
## el enemigo queda trabado contra una pared varios frames seguidos.
@export var wall_jump_cooldown : float = 0.6

## Distancia (px) del vaivén cuando el enemigo está en la misma columna
## que el jugador pero no lo puede alcanzar verticalmente (ver _perseguir).
@export var shuffle_step : float = 32.0
## Tolerancia (px) para considerar que está "en la misma columna" que
## el jugador (diferencia horizontal casi nula).
@export var shuffle_align_tolerance : float = 4.0

@export_group("Patrulla")
## Si es true, el enemigo camina de un lado a otro mientras patrulla
## (en vez de quedarse quieto girando el sprite, que es el default).
@export var patrol_moves       : bool  = false
## Velocidad de caminata en patrulla, como fracción de movVelx.
@export var patrol_speed_scale : float = 0.5
## Cada cuánto cambia de dirección al patrullar (si patrol_moves=false,
## esto solo hace que gire el sprite en el lugar, como antes).
@export var patrol_turn_time   : float = 1.5

@export_group("Movimiento — Tipo")
## Tierra: gravedad normal, se mueve solo en X, salta/shufflea como
## siempre. Vuelo: sin gravedad, se mueve en X e Y directo al jugador,
## flota con hover al patrullar. Nado: como Vuelo pero más lento y con
## "arrastre" (drag) para que se sienta pesado en el agua — pensado para
## cuando agregues niveles acuáticos, ya viene funcional.
@export var movement_type : MovementType = MovementType.GROUND

## Mientras patrulla/ataca en reposo (sin perseguir), sube y baja
## suavemente en vez de quedarse clavado en el aire/agua. Aplica a
## Vuelo y Nado. 0 = sin balanceo.
@export var hover_amplitude : float = 6.0
@export var hover_speed     : float = 2.0
## Si true (default), al morir un enemigo de Vuelo/Nado deja de flotar
## y cae por gravedad para un efecto de muerte más natural (ej:
## murciélago cayendo al piso). Si false, se queda flotando en su lugar
## hasta que termina la animación.
@export var falls_on_death : bool = true

## Solo aplica a Nado: qué tan "pesado" se siente moverse en el agua.
## 1.0 = para en seco al instante (como Vuelo). Valores más chicos =
## más inercia/arrastre antes de frenar o girar.
@export_range(0.05, 1.0) var swim_drag : float = 0.15
## Solo aplica a Nado: velocidad como fracción de movVelx (nada más
## lento que vuela, por default).
@export var swim_speed_scale : float = 0.6

@export_group("Inteligencia")
## LOW: se mueve directo y sin fijarse en nada extra — puede caminar
## fuera de una plataforma, quedarse "clavado" jugando la animación de
## caminar sin avanzar si está en la misma columna que un jugador
## inalcanzable (sin shuffle), y salta contra paredes sin cooldown.
## Pensado para enemigos simples/decorativos donde no importa que se
## comporten un poco torpes.
##
## MEDIUM (default): el comportamiento normal de toda la clase — usa
## shuffle si queda trabado en la misma columna, cooldown en el salto
## por pared, patrulla configurable. Es el nivel con el que se probó
## todo lo demás en este script.
##
## HIGH: MEDIUM + evita caminar fuera del borde de una plataforma al
## patrullar (necesita el nodo opcional LedgeCheck, un RayCast2D
## apuntando hacia abajo-adelante — si no existe, HIGH se comporta
## igual que MEDIUM en tierra). En Vuelo/Nado, esquiva obstáculos con
## el nodo opcional ObstacleCheck (RayCast2D apuntando en la dirección
## de movimiento).
@export var ai_level : AILevel = AILevel.MEDIUM

@export_group("Drops / Muerte")
@export var deadpuff_scene : PackedScene
## Tabla de drops que se tira al morir, vía DropSystem. Se puede armar
## como recurso .tres desde el Inspector, o por código en _on_ready()
## (ver ejemplo en slime.gd). Si se deja vacío, no tira ningún drop.
@export var drop_table : DropTable

@export_group("Comportamiento")
## Si es true (default), el enemigo camina hacia el jugador al verlo
## (ALERTA/PERSEGUIR) y vuelve a perseguir si se aleja durante el ataque.
## Si es false, nunca camina: pasa directo de "ver al jugador" a ATAQUE,
## y de "perderlo de vista" directo a PATRULLAR (quieto). Pensado para
## enemigos a distancia que se quedan fijos, tipo Archer.
@export var can_chase : bool = true

## Si es true (default), recibir daño lo pone en modo persecución/ataque
## de inmediato (aunque no tuviera al jugador en su visión). Si es false,
## que le peguen no cambia su estado actual.
@export var chase_on_hit : bool = true

## Si es true, se queda quieto mientras ataca (velocity.x = 0), en vez de
## acercarse/alejarse como el cuerpo a cuerpo. Pensado para enemigos a
## distancia. Además, con esto en true no se exige is_on_floor() para
## poder atacar (útil para arqueros en plataformas, torretas, etc).
@export var stationary_attack : bool = false

## Solo aplica a enemigos con can_chase=false (como el Archer). Por
## defecto (0.0), atacan SOLO mientras el jugador esté dentro de su
## visión: apenas lo pierde de vista, dejan de disparar al instante.
## Si le ponés un valor > 0, siguen atacando esa cantidad de segundos
## extra después de perderlo de vista, como si "lo recordaran" un rato
## antes de volver a reposo.
@export var remember_player_time : float = 0.0

@export_group("Huir")
## Habilita el SISTEMA de huida en este enemigo. Con esto en true, se
## puede activar de dos formas:
##   1) Automática (opcional): ver flee_on_low_hp más abajo.
##   2) Manual/reactiva: cualquier otro script, señal, trampa, evento de
##      guion, etc. puede llamar start_fleeing() en cualquier momento,
##      sin importar la vida del enemigo. Ej:
##        $Slime.start_fleeing()                # huye hasta reponerse/alejarse
##        $Slime.start_fleeing(3.0)              # huye 3 segundos y vuelve sola
##        $Slime.stop_fleeing()                  # corta la huida a mano
## Si can_flee=false, start_fleeing() no hace nada (el enemigo ignora el
## llamado por completo).
@export var can_flee : bool = false
## Si es true (default), además dispara la huida automáticamente en
## take_damage() apenas la vida cae por debajo de flee_hp_threshold. Si
## es false, la huida solo se activa cuando algo externo llama
## start_fleeing() a mano (huida 100% reactiva/manual).
@export var flee_on_low_hp : bool = true
## Fracción de MAX_HP (0.0–1.0) por debajo de la cual arranca a huir
## automáticamente (solo aplica si flee_on_low_hp = true).
@export_range(0.0, 1.0) var flee_hp_threshold : float = 0.25
## Velocidad al huir, como múltiplo de movVelx (por default huye más
## rápido de lo que camina/persigue normalmente).
@export var flee_speed_scale : float = 1.3
## Distancia a la que se considera "a salvo" del jugador. Solo importa
## en huidas automáticas por vida baja con flee_until_hp_recovers=false
## (las huidas forzadas por start_fleeing() no usan esto, ver abajo).
@export var flee_safe_distance : float = 250.0
## Si true (default), una huida automática por vida baja sigue mientras
## la vida siga baja, sin importar qué tan lejos llegue del jugador. Si
## false, alcanzar flee_safe_distance alcanza para dejar de huir aunque
## la vida siga baja.
@export var flee_until_hp_recovers : bool = true
## Sonido opcional propio para cuando huye (ej: un grito distinto al de
## caminar normal). Si se deja vacío, usa sfx_move.
@export var sfx_flee : AudioStream

@export_group("Sonidos")
## Cada uno es opcional: si se deja vacío, simplemente no suena nada
## para ese evento. Asignalos desde el Inspector de cada enemigo, o
## desde código en su _on_ready() (preload de un .ogg/.wav propio).
@export var sfx_move   : AudioStream   ## en loop mientras camina (PERSEGUIR)
@export var sfx_attack : AudioStream   ## al concretar el ataque
@export var sfx_jump   : AudioStream   ## al saltar (ataque tipo slime, o esquivar pared)
@export var sfx_hit    : AudioStream   ## al recibir daño
@export var sfx_volume_db : float = 0.0

# ── Estado ────────────────────────────────────────────────────────────
enum StatePhase { PATRULLAR, ALERTA, PERSEGUIR, ATAQUE, HUIR, MUERTO }
var estado_enemigo : StatePhase = StatePhase.PATRULLAR

var _hp             : int   = 0
var _hp_bar_visible : bool  = false
var _bar_full_width : float = 0.0
var dead            : bool  = false
var playerOnArea    : bool  = false
var tiempo_vigia    : float = 0.0
var jugador         : Node2D = null
var dir_vista       : int   = 1
var attackcd        : float = 0.0
var _wall_jump_cd   : float = 0.0
var _remember_timer : float = 0.0
## > 0 mientras una huida forzada por start_fleeing(duration) tenga
## tiempo restante; 0 = sin límite de tiempo (huye hasta que se cumplan
## las condiciones normales de salida).
var _flee_forced_timer : float = 0.0
## true si la huida actual la disparó flee_on_low_hp (vida baja). Si es
## false, la huida es manual/reactiva (start_fleeing() externo) y no
## tiene sentido usar "la vida se recuperó" como condición de salida.
var _flee_hp_triggered : bool = false

# Estado del "shuffle" (vaivén cuando está en la misma columna que el
# jugador pero no lo alcanza verticalmente).
var _shuffling         : bool    = false
var _shuffle_dir       : int     = 1
var _shuffle_target_x  : float   = 0.0
var _shuffle_start_y   : float   = 0.0
var _shuffle_player_pos: Vector2 = Vector2.ZERO
var _hover_time : float = 0.0


func _ready() -> void:
	jugador = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	hp_bar_root.hide()
	_bar_full_width   = hp_bar_fill.size.x
	hp_bar_bg.color   = Color(0.1, 0.0, 0.0, 0.8)
	hp_bar_fill.color = Color(0.9, 0.1, 0.1)

	# _on_ready() corre ANTES de fijar _hp: así, si el enemigo hijo declara
	# su propio MAX_HP (ej: Archer poniendo MAX_HP = 12), _hp arranca con
	# ese valor. Si el hijo no toca MAX_HP, se usa el default de la clase
	# base (20, la vida original del Slime) como fallback.
	_on_ready()
	_hp = MAX_HP
	if move_sfx_player:
		move_sfx_player.bus = AudioManager.BUS_SFX


## HOOK: inicialización propia de cada enemigo (ej: llenar drop_scenes,
## ajustar animaciones iniciales, etc). No hace falta tocar _ready().
func _on_ready() -> void:
	pass


# ── Helpers de distancia ────────────────────────────────────────────
## Distancia horizontal pura al jugador (ignora diferencia de altura).
## Es lo que se usa para decidir "¿me acerco/ataco?" en un plataformero,
## en vez de distance_to() que mide en diagonal y confunde un jugador
## que está cerca en X pero en otro piso con uno realmente alcanzable.
func _horizontal_dist_to_player() -> float:
	return absf(jugador.global_position.x - global_position.x)


## True para Vuelo o Nado (cualquier tipo que no toca el piso ni le
## afecta la gravedad normal). Reemplaza al viejo `flies: bool`.
func _is_airborne() -> bool:
	return movement_type != MovementType.GROUND


func _is_swimming() -> bool:
	return movement_type == MovementType.SWIMMING


## Diferencia de altura absoluta con el jugador.
func _vertical_gap_to_player() -> float:
	return absf(jugador.global_position.y - global_position.y)


## True si el jugador está lo bastante cerca como para perseguir/atacar.
## Enemigos terrestres: distancia horizontal + tolerancia vertical (para
## no perseguir a través de pisos/plataformas). Enemigos voladores: como
## pueden llegar a cualquier altura, usan la distancia real en línea recta.
func _player_within(range_x: float) -> bool:
	if _is_airborne():
		return global_position.distance_to(jugador.global_position) <= range_x
	return _horizontal_dist_to_player() <= range_x and _vertical_gap_to_player() <= max_vertical_reach


# ── Shuffle (vaivén cuando está "trabado" en la misma columna que el
#    jugador sin poder alcanzarlo verticalmente) ───────────────────────
func _start_shuffle() -> void:
	_shuffling          = true
	_shuffle_dir         = -1 if asprite.flip_h else 1
	_shuffle_target_x    = global_position.x + shuffle_step * _shuffle_dir
	_shuffle_start_y     = global_position.y
	_shuffle_player_pos  = jugador.global_position


func _stop_shuffle() -> void:
	_shuffling = false


## Devuelve true mientras sigue en modo shuffle. Sale solo (y deja que
## _perseguir() vuelva a calcular todo normal) en dos casos:
##  1) El propio enemigo cambió de altura (se cayó, subió, dejó de estar
##     "atascado" al mismo nivel).
##  2) El jugador se movió de donde estaba cuando arrancó el shuffle.
func _update_shuffle() -> bool:
	if not _shuffling:
		return false

	if absf(global_position.y - _shuffle_start_y) > 4.0:
		_stop_shuffle()
		return false

	if jugador.global_position.distance_to(_shuffle_player_pos) > 4.0:
		_stop_shuffle()
		return false

	var to_target : float = _shuffle_target_x - global_position.x
	var dir : float = signf(to_target)
	velocity.x = movVelx * dir
	asprite.flip_h = (dir < 0.0)

	if absf(to_target) <= 2.0:
		# Llegó a la punta del vaivén: da la vuelta hacia el otro lado.
		_shuffle_dir *= -1
		_shuffle_target_x = global_position.x + shuffle_step * _shuffle_dir

	return true


# ── Vuelo / Nado ────────────────────────────────────────────────────
## Se acerca al jugador en línea recta (X e Y a la vez), a diferencia de
## un enemigo terrestre que solo controla X y depende de la gravedad/
## saltos para el eje Y. No necesita shuffle: como puede moverse en
## cualquier ángulo, nunca queda "trabado" en la misma columna.
##
## Vuelo: velocidad instantánea, snappy. Nado: se interpola con
## swim_drag (velocity.lerp) para que se sienta con inercia/pesadez en
## el agua, en vez de frenar/girar en seco como un pájaro.
func _move_airborne_towards_player(delta: float) -> void:
	var to_player : Vector2 = jugador.global_position - global_position
	var desired : Vector2 = Vector2.ZERO

	if to_player.length() > 2.0:
		var dir : Vector2 = to_player.normalized()
		var speed : float = movVelx * (swim_speed_scale if _is_swimming() else 1.0)
		desired = dir * speed
		asprite.flip_h = (dir.x < 0.0)

	# HIGH: esquiva un obstáculo directo adelante desviándose hacia
	# arriba, en vez de chocar de frente contra una pared/piso.
	if ai_level == AILevel.HIGH and obstacle_check and obstacle_check.is_colliding():
		desired.y -= absf(desired.x) if desired.x != 0.0 else movVelx

	if _is_swimming():
		velocity = velocity.lerp(desired, swim_drag)
	else:
		velocity = desired


## Sube y baja suavemente en el lugar mientras patrulla/está en reposo,
## en vez de flotar clavado en el aire/agua. Con patrol_moves=true,
## además se desplaza horizontalmente de un lado a otro (igual que un
## enemigo terrestre en patrulla, pero sin tocar nunca el suelo).
func _hover(delta: float) -> void:
	tiempo_vigia += delta
	if tiempo_vigia >= patrol_turn_time:
		tiempo_vigia = 0.0
		dir_vista *= -1
		asprite.flip_h = (dir_vista == -1)

	var target_vx : float = movVelx * patrol_speed_scale * dir_vista if patrol_moves else 0.0
	var target_vy : float = 0.0
	if hover_amplitude > 0.0:
		_hover_time += delta * hover_speed
		target_vy = cos(_hover_time) * hover_amplitude * hover_speed

	if _is_swimming():
		velocity = velocity.lerp(Vector2(target_vx, target_vy), swim_drag)
	else:
		velocity = Vector2(target_vx, target_vy)

	asprite.play("default")


func _physics_process(delta: float) -> void:
	if Globals.playerStay:
		return
	if player.playerDead:
		return

	if _is_airborne() and not (falls_on_death and estado_enemigo == StatePhase.MUERTO):
		# Sin gravedad: la Y la maneja _perseguir()/_hover() a mano.
		pass
	elif is_on_floor():
		# Evita que quede un resto de velocidad de caída "guardado" que
		# después se sume raro al próximo salto/ataque.
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + grav * delta, max_fall_speed)

	if _wall_jump_cd > 0.0:
		_wall_jump_cd -= delta

	if _hp <= 0 and estado_enemigo != StatePhase.MUERTO:
		estado_enemigo = StatePhase.MUERTO
	move_and_slide()

	if estado_enemigo != StatePhase.PERSEGUIR and estado_enemigo != StatePhase.HUIR:
		_stop_move_sfx()
		_stop_shuffle()

	match estado_enemigo:
		StatePhase.PATRULLAR:
			_patrullar(delta)
		StatePhase.ALERTA:
			_alerta()
		StatePhase.PERSEGUIR:
			_perseguir(delta)
		StatePhase.ATAQUE:
			_atacar(delta)
		StatePhase.HUIR:
			_huir(delta)
		StatePhase.MUERTO:
			_muerto()


# ── Estados (comportamiento por defecto; sobreescribibles si un enemigo
#    necesita algo distinto, ej. un enemigo con proyectiles a distancia) ──
func _patrullar(delta: float) -> void:
	if _is_airborne():
		_hover(delta)
		return

	tiempo_vigia += delta
	if tiempo_vigia >= patrol_turn_time:
		tiempo_vigia = 0.0
		dir_vista *= -1
		asprite.flip_h = (dir_vista == -1)

	if patrol_moves:
		velocity.x = movVelx * patrol_speed_scale * dir_vista
		# Si se topa con una pared o el borde de una plataforma, da la
		# vuelta antes en vez de esperar al timer (evita que quede
		# empujando contra la pared hasta que se cumpla patrol_turn_time).
		if is_on_wall():
			tiempo_vigia = patrol_turn_time
		elif ai_level == AILevel.HIGH and ledge_check and not ledge_check.is_colliding():
			# HIGH: no se tira al vacío por el borde de una plataforma.
			tiempo_vigia = patrol_turn_time
		asprite.play("default")
	else:
		velocity.x = 0.0


func _alerta() -> void:
	if playerOnArea:
		estado_enemigo = StatePhase.PERSEGUIR
	elif not _player_within(vision_range):
		estado_enemigo = StatePhase.PATRULLAR


@warning_ignore("unused_parameter")
func _perseguir(delta: float) -> void:
	asprite.play("default")

	if _is_airborne():
		_move_airborne_towards_player(delta)
		_play_move_sfx()
		if _player_within(attack_range):
			estado_enemigo = StatePhase.ATAQUE
		elif not _player_within(vision_range):
			estado_enemigo = StatePhase.ALERTA
		return

	var horizontal_gap : float = jugador.global_position.x - global_position.x
	var same_column     : bool = absf(horizontal_gap) <= shuffle_align_tolerance
	var out_of_reach     : bool = _vertical_gap_to_player() > max_vertical_reach

	# LOW no usa shuffle: se queda quieto trabado como cualquier lógica
	# simple sin pulir (a propósito, para enemigos "torpes").
	if ai_level != AILevel.LOW and same_column and out_of_reach:
		# Está justo debajo/arriba del jugador pero no lo puede alcanzar
		# verticalmente: en vez de quedarse quieto con velocity.x=0
		# reproduciendo la animación de caminar sin moverse, hace un
		# vaivén de shuffle_step píxels para un lado y para el otro.
		if not _shuffling:
			_start_shuffle()
		_update_shuffle()
	else:
		if _shuffling:
			_stop_shuffle()
		var direccion : float = signf(horizontal_gap)
		velocity.x = movVelx * direccion
		asprite.flip_h = (direccion == -1)

	_play_move_sfx()

	if _player_within(attack_range):
		estado_enemigo = StatePhase.ATAQUE
	elif not _player_within(vision_range):
		estado_enemigo = StatePhase.ALERTA

	# LOW salta contra la pared sin cooldown (más torpe/spamea el salto).
	var wall_jump_ready : bool = _wall_jump_cd <= 0.0 or ai_level == AILevel.LOW
	if is_on_wall() and is_on_floor() and wall_jump_ready:
		velocity.y = -280
		if ai_level != AILevel.LOW:
			_wall_jump_cd = wall_jump_cooldown
		_play_sfx(sfx_jump)


## Fuerza al enemigo a huir AHORA, sin importar la causa — esto es lo
## que hace que "huir" sea reaccionario a lo que vos quieras, no solo a
## la vida: cualquier script, señal, área, o evento de guion puede
## llamar esto directamente:
##   $Slime.start_fleeing()          # huye hasta reponerse/alejarse lo suficiente
##   $Slime.start_fleeing(3.0)       # huye exactamente 3 segundos y vuelve sola
## No hace nada si can_flee=false o si ya está muerto. Si se llama sin
## que la vida esté baja (ej: reaccionando a que un aliado murió, una
## alarma, que caiga la noche, etc), la condición de salida pasa a ser
## "se alejó lo suficiente" en vez de "se curó" (ver _huir()).
func start_fleeing(duration: float = 0.0) -> void:
	if not can_flee or _hp <= 0:
		return
	_flee_hp_triggered = false   # las llamadas manuales nunca usan "se curó" como salida
	_flee_forced_timer = duration
	estado_enemigo = StatePhase.HUIR


## Corta la huida a mano (por si algo externo la disparó y querés
## cancelarla antes de que se cumplan las condiciones de salida
## normales). Vuelve a ALERTA si el jugador sigue en su visión, o a
## PATRULLAR si no. No hace nada si no estaba huyendo.
func stop_fleeing() -> void:
	if estado_enemigo != StatePhase.HUIR:
		return
	_flee_forced_timer  = 0.0
	_flee_hp_triggered  = false
	estado_enemigo = StatePhase.ALERTA if playerOnArea else StatePhase.PATRULLAR


func is_fleeing() -> bool:
	return estado_enemigo == StatePhase.HUIR


## Huye del jugador en dirección opuesta, a flee_speed_scale de
## velocidad. Tiene prioridad sobre todo lo demás (ver take_damage() y
## las señales de área, que no pisan este estado). Sale solo cuando la
## vida se recupera por encima de flee_hp_threshold, o (si
## flee_until_hp_recovers=false) al alcanzar flee_safe_distance.
func _huir(delta: float) -> void:
	asprite.play("default")

	if _is_airborne():
		_move_away_from_player()
	else:
		var horizontal_gap : float = jugador.global_position.x - global_position.x
		var direccion    : float = signf(horizontal_gap)     # hacia el jugador
		var movement_dir : float = -direccion                # se aleja

		velocity.x = movVelx * flee_speed_scale * movement_dir
		asprite.flip_h = (movement_dir < 0.0)

		var wall_jump_ready : bool = _wall_jump_cd <= 0.0 or ai_level == AILevel.LOW
		if is_on_wall() and is_on_floor() and wall_jump_ready:
			velocity.y = -280
			if ai_level != AILevel.LOW:
				_wall_jump_cd = wall_jump_cooldown
			_play_sfx(sfx_jump)

	_play_flee_sfx()

	# Huida con duración fija (start_fleeing(3.0)): cuenta regresiva y
	# corta apenas se cumple, sin importar vida/distancia.
	if _flee_forced_timer > 0.0:
		_flee_forced_timer -= delta
		if _flee_forced_timer <= 0.0:
			stop_fleeing()
		return

	var hp_recovered : bool = float(_hp) / float(maxi(MAX_HP, 1)) > flee_hp_threshold
	var far_enough    : bool = _distance_to_player() >= flee_safe_distance

	if _flee_hp_triggered:
		# Huida automática por vida baja: sale al recuperarse, o (según
		# flee_until_hp_recovers) al alejarse lo suficiente.
		if hp_recovered or (far_enough and not flee_until_hp_recovers):
			estado_enemigo = StatePhase.ALERTA if playerOnArea else StatePhase.PATRULLAR
	else:
		# Huida manual/reactiva (start_fleeing() externo, sin duración):
		# la vida no tiene nada que ver acá, así que solo sale al
		# alejarse lo suficiente del jugador.
		if far_enough:
			estado_enemigo = StatePhase.ALERTA if playerOnArea else StatePhase.PATRULLAR


## Igual que _move_airborne_towards_player() pero en dirección opuesta.
## Usado por _huir() cuando el enemigo vuela/nada.
func _move_away_from_player() -> void:
	var away : Vector2 = global_position - jugador.global_position
	if away.length() <= 1.0:
		return

	var dir   : Vector2 = away.normalized()
	var speed : float = movVelx * flee_speed_scale * (swim_speed_scale if _is_swimming() else 1.0)
	var desired : Vector2 = dir * speed

	if _is_swimming():
		velocity = velocity.lerp(desired, swim_drag)
	else:
		velocity = desired

	asprite.flip_h = (dir.x < 0.0)


func _distance_to_player() -> float:
	return global_position.distance_to(jugador.global_position)


func _atacar(delta: float) -> void:
	# Con can_chase=false, si el jugador ya no está en la visión, no hay
	# a quién atacar de inmediato... salvo que remember_player_time le dé
	# unos segundos extra de "memoria" antes de volver a reposo.
	if not can_chase and not playerOnArea:
		if _remember_timer > 0.0:
			_remember_timer -= delta
		else:
			estado_enemigo = StatePhase.PATRULLAR
			return

	var direccion : float = signf(jugador.global_position.x - global_position.x)
	asprite.flip_h = (direccion == -1)

	if stationary_attack:
		velocity.x = 0.0
		if _is_airborne() and hover_amplitude > 0.0:
			_hover_time += delta * hover_speed
			velocity.y = cos(_hover_time) * hover_amplitude * hover_speed
		attackcd += delta
		if attackcd >= cooldown:
			attackcd = 0.0
			_perform_attack(direccion)
		asprite.play("default")
	else:
		if _is_airborne():
			_move_airborne_towards_player(delta)
		if is_on_floor() or _is_airborne():
			attackcd += delta
			if attackcd >= cooldown:
				attackcd = 0.0
				_perform_attack(direccion)
			asprite.play("default")
		else:
			asprite.play("jump")

	# Solo vuelve a perseguir si este enemigo persigue; si no, se queda
	# atacando mientras el jugador siga dentro de su visión.
	if can_chase and not _player_within(attack_range):
		estado_enemigo = StatePhase.PERSEGUIR


## HOOK: qué hace el enemigo al concretar su ataque. Por defecto replica
## el "salto hacia el jugador" del slime. Un enemigo con espada, o con
## proyectil a distancia, sobreescribe esto solamente.
##
## Nota de audio: como este ataque default ES un salto, solo suena UNO
## de los dos sonidos (sfx_player reproduce un solo stream a la vez):
## prioriza sfx_jump, y si el enemigo no tiene sfx_jump asignado, usa
## sfx_attack como fallback. Un enemigo que ataque sin saltar (espada,
## flecha) puede sobreescribir _perform_attack y llamar solo
## _play_sfx(sfx_attack) sin ningún conflicto.
func _perform_attack(direccion: float) -> void:
	velocity = Vector2((movVelx * 3) * direccion, movVely)
	_play_sfx(sfx_jump if sfx_jump != null else sfx_attack)


func _muerto() -> void:
	if dead:
		return
	dead = true
	velocity.x = 0
	move_and_slide()
	asprite.play("dead")
	await asprite.animation_finished
	damarea.monitoring = false
	FloatingTextManager.clear_damage_for(self)
	_spawn_death_effects()
	queue_free()


## HOOK: efectos y drops al morir. Sobreescribible si un enemigo necesita
## un drop especial (ej: boss que suelta un ítem único).
func _spawn_death_effects() -> void:
	if deadpuff_scene:
		var puff = deadpuff_scene.instantiate()
		get_parent().add_child(puff)
		puff.global_position = global_position

	DropSystem.spawn_table(drop_table, global_position, get_parent())


# ── Señales de áreas (conectar en cada escena hija a estas mismas funciones) ──
func _on_vision_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		playerOnArea = true
		_remember_timer = remember_player_time   # se resetea con cada avistamiento
		if estado_enemigo != StatePhase.HUIR:
			estado_enemigo = StatePhase.PERSEGUIR if can_chase else StatePhase.ATAQUE


func _on_vison_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		playerOnArea = false
		if estado_enemigo == StatePhase.HUIR:
			return
		if not can_chase and remember_player_time <= 0.0:
			# Sin memoria configurada: corta al instante, como antes.
			estado_enemigo = StatePhase.PATRULLAR
		# Si remember_player_time > 0, no se toca el estado acá: lo va
		# a resolver _atacar() contando el timer hacia abajo.


func _on_attack_area_body_entered(body: Node2D) -> void:
	if estado_enemigo != StatePhase.HUIR:
		estado_enemigo = StatePhase.ATAQUE


func _on_damage_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		jugador.take_damage(damage, global_position)
		if estado_enemigo != StatePhase.HUIR:
			estado_enemigo = StatePhase.PERSEGUIR


# ── API de daño (idéntica para todos los enemigos) ─────────────────────
@warning_ignore("unused_parameter")
func take_damage(amount: int, hit_pos: Vector2) -> void:
	if _hp <= 0:
		return
	_hp = max(_hp - amount, 0)
	_play_sfx(sfx_hit)

	# Huir tiene PRIORIDAD sobre chase_on_hit: si la vida quedó por
	# debajo del umbral (y flee_on_low_hp está activo), pisa cualquier
	# otro estado (menos MUERTO, que ya se resuelve aparte en
	# _physics_process).
	if can_flee and flee_on_low_hp and _hp > 0 and float(_hp) / float(maxi(MAX_HP, 1)) <= flee_hp_threshold:
		start_fleeing()
		_flee_hp_triggered = true
	elif estado_enemigo == StatePhase.HUIR:
		pass   # ya está huyendo (ej: por start_fleeing() manual) — no lo saca chase_on_hit
	elif chase_on_hit:
		estado_enemigo = StatePhase.PERSEGUIR if can_chase else StatePhase.ATAQUE

	if not _hp_bar_visible:
		hp_bar_root.show()
		_hp_bar_visible = true

	_update_hp_bar()

	# El número de daño ya no lo maneja cada enemigo: se delega a
	# FloatingTextManager, que acumula/desvanece igual que antes.
	FloatingTextManager.show_damage(
		self,
		amount,
		FloatingTextManager.Style.DAMAGE_ENEMY,
		Vector2(0.0, hp_bar_root.position.y - 14.0)
	)


func _update_hp_bar() -> void:
	var ratio: float = float(_hp) / float(MAX_HP)
	hp_bar_fill.size.x = _bar_full_width * ratio


func is_dead() -> bool:
	return _hp <= 0


func get_hp() -> int:
	return _hp


# ── Audio ────────────────────────────────────────────────────────────
## Reproduce un sonido "de una vez" (ataque, salto, daño) posicionado en
## este enemigo, a través de AudioManager (bus SFX). Si `stream` es
## null, no hace nada — así cada enemigo puede dejar sin asignar los
## sonidos que no le interesen sin romper nada.
func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	AudioManager.play_sfx(stream, global_position, sfx_volume_db)


## Sonido de movimiento en loop: arranca solo si no está sonando ya
## (para no reiniciarlo en cada frame mientras camina). Este SÍ usa un
## nodo propio por enemigo (move_sfx_player), porque a diferencia de los
## sonidos de una vez, puede haber varios enemigos caminando al mismo
## tiempo y cada uno necesita su propio loop independiente.
## Es TOTALMENTE OPCIONAL: si el enemigo no tiene el nodo MoveSFXPlayer
## en su escena, esta función simplemente no hace nada.
func _play_move_sfx() -> void:
	if sfx_move == null or move_sfx_player == null:
		return
	if move_sfx_player.stream != sfx_move:
		move_sfx_player.stream = sfx_move
	move_sfx_player.volume_db = sfx_volume_db
	if not move_sfx_player.playing:
		move_sfx_player.play()


func _stop_move_sfx() -> void:
	if move_sfx_player == null:
		return
	if move_sfx_player.playing:
		move_sfx_player.stop()


## Variante de _play_move_sfx() para cuando está huyendo: usa sfx_flee
## si está asignado, o cae de vuelta a sfx_move si no. Comparte el mismo
## move_sfx_player (opcional) que el sonido de movimiento normal.
func _play_flee_sfx() -> void:
	var stream : AudioStream = sfx_flee if sfx_flee != null else sfx_move
	if stream == null or move_sfx_player == null:
		return
	if move_sfx_player.stream != stream:
		move_sfx_player.stream = stream
	move_sfx_player.volume_db = sfx_volume_db
	if not move_sfx_player.playing:
		move_sfx_player.play()
