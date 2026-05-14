extends CharacterBody2D


# ── Nodos ─────────────────────────────────────────────────────────────
@onready var hp_bar_root : Node2D    = $HPBarRoot
@onready var hp_bar_bg   : ColorRect = $HPBarRoot/HPBarBG
@onready var hp_bar_fill : ColorRect = $HPBarRoot/HPBarFill
@onready var asprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var areavision: Area2D = $VisionArea
@onready var attackarea: Area2D = $AttackArea
@onready var damarea: Area2D = $DamageArea


enum StatePhase { PATRULLAR, ALERTA, PERSEGUIR, ATAQUE, MUERTO }


# ── Stats ─────────────────────────────────────────────────────────────
const MAX_HP        : int   = 20
const REGEN_DELAY   : float = 3.0
const REGEN_RATE    : float = 800.0

# ── Estado ────────────────────────────────────────────────────────────
var _hp             : int   = MAX_HP
var _regen_timer    : float = 0.0
var _regenerating   : bool  = false
var _hp_bar_visible : bool  = false
var _bar_full_width : float = 0.0
var dead: bool = false

var estado_enemigo: StatePhase = StatePhase.PATRULLAR
var playerOnArea: bool = false
var tiempo_vigia: float = 0.0
var jugador: Node2D = null
var dir_vista: int = 1
var movVelx: float = 60.0
var movVely: float = -260.0
var grav: float = 980.0
var damage: int = 3
var _dmg_label       : Label = null
var _dmg_accumulated : int   = 0
var _dmg_timer       : float = 0.0
var _dmg_fading      : bool  = false
var attackcd: float = 0.0
var cooldown: float = 0.75

# ── Número de daño acumulativo ────────────────────────────────────────
const FONT             := preload("res://data/Fonts/monogatari.ttf")
const DMG_COLOR        := Color(1.0, 0.15, 0.15)
const DMG_DISPLAY_TIME : float = 3.0   # segundos sin daño antes de desvanecerse
const DMG_FADE_TIME    : float = 0.4   # duración del fade al desaparecer

func _ready():
	jugador = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	hp_bar_root.hide()
	_bar_full_width   = hp_bar_fill.size.x
	hp_bar_bg.color   = Color(0.1, 0.0, 0.0, 0.8)
	hp_bar_fill.color = Color(0.9, 0.1, 0.1)

func _physics_process(delta: float):
	if Globals.playerStay:
		return
	if player.playerDead:
		return
	if !is_on_floor():
		velocity.y += grav * delta
		
	move_and_slide()
	# ── Número de daño: esperar y desvanecer ──────────────────────────
	if _dmg_label != null and not _dmg_fading:
		_dmg_timer += delta
		if _dmg_timer >= DMG_DISPLAY_TIME:
			_dmg_fading = true
			var tween := _dmg_label.create_tween()
			tween.tween_property(_dmg_label, "modulate:a", 0.0, DMG_FADE_TIME)
			tween.tween_callback(_clear_dmg_label)
			
	match estado_enemigo:
		StatePhase.PATRULLAR:
			_patrullar(delta)
		StatePhase.ALERTA:
			_alerta()
		StatePhase.PERSEGUIR:
			_perseguir()
		StatePhase.ATAQUE:
			_atacar(delta)
		StatePhase.MUERTO:
			_muerto()
	if _hp <= 0:
		estado_enemigo = StatePhase.MUERTO
		

func _patrullar(delta: float):
	tiempo_vigia += delta
	if tiempo_vigia >= 1.5:
		tiempo_vigia = 0.0
		dir_vista *= -1
		asprite.flip_h = (dir_vista == -1)
		

func _alerta():
	if playerOnArea == true:
		estado_enemigo = StatePhase.PERSEGUIR
	
func _perseguir():
	asprite.play("default")
	var direccion = sign(jugador.global_position.x - global_position.x)
	velocity.x = movVelx * direccion
	asprite.flip_h = (direccion == -1)
	if global_position.distance_to(jugador.global_position) <= 80.0:
		estado_enemigo = StatePhase.ATAQUE
		

func _atacar(delta):
	var direccion = sign(jugador.global_position.x - global_position.x)
	asprite.flip_h = (direccion == -1)
	if is_on_floor():
		attackcd += delta
		if attackcd >= cooldown:
			attackcd = 0.0
			velocity = Vector2 ((movVelx * 3) * direccion, movVely)
		asprite.play("default")
	else:
		asprite.play("jump")
	if global_position.distance_to(jugador.global_position) >= 80.0:
		estado_enemigo = StatePhase.PERSEGUIR

func _muerto():
	
	if !dead:
		print("slimemuerto")
		velocity.x = 0
		move_and_slide()
		dead = true
		asprite.play("dead")
		await asprite.animation_finished
		damarea.monitoring = false
		_clear_dmg_label()
		queue_free()
		

func _on_vision_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		playerOnArea = true
		print("jugador entro al area")
		estado_enemigo = StatePhase.PERSEGUIR

func _on_vison_area_body_exited(body: Node2D):
	if body.is_in_group("player"):
		playerOnArea = false
		print("jugador salio de la area")


func _clear_dmg_label() -> void:
	if is_instance_valid(_dmg_label):
		_dmg_label.queue_free()
	_dmg_label       = null
	_dmg_accumulated = 0
	_dmg_timer       = 0.0
	_dmg_fading      = false


# ── API de daño ───────────────────────────────────────────────────────
func take_damage(amount: int, hit_pos: Vector2) -> void:
	estado_enemigo = StatePhase.PERSEGUIR
	if _hp <= 0:
		return

	
	_regen_timer  = 0.0
	_regenerating = false
	_hp           = max(_hp - amount, 0)


	if not _hp_bar_visible:
		hp_bar_root.show()
		_hp_bar_visible = true

	_update_hp_bar()
	_update_damage_number(amount)



func _update_hp_bar() -> void:
	var ratio : float = float(_hp) / float(MAX_HP)
	hp_bar_fill.size.x = _bar_full_width * ratio


# ── Número acumulativo estilo Cave Story ──────────────────────────────
func _update_damage_number(amount: int) -> void:
	_dmg_accumulated += amount
	_dmg_timer        = 0.0   # reiniciar el timer cada vez que llega daño

	# Si estaba desvaneciéndose, cancelar y reutilizar o recrear
	if _dmg_fading:
		_clear_dmg_label()

	if _dmg_label == null:
		_dmg_label = Label.new()
		_dmg_label.add_theme_font_override("font",           FONT)
		_dmg_label.add_theme_font_size_override("font_size", 14)
		_dmg_label.add_theme_color_override("font_color",    DMG_COLOR)
		_dmg_label.z_index = 10
		get_parent().add_child(_dmg_label)
		_dmg_label.global_position = global_position + Vector2(0.0, hp_bar_root.position.y - 14.0)

	_dmg_label.modulate = Color(1, 1, 1, 1)
	_dmg_label.text     = "-%d" % _dmg_accumulated


func _on_attack_area_body_entered(body: Node2D) -> void:
	estado_enemigo = StatePhase.ATAQUE


func _on_damage_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("jugador ha sido herido")
		estado_enemigo = StatePhase.PERSEGUIR
		jugador.take_damage(damage, global_position)
