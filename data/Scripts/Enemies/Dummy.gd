## Dummy.gd
## Enemigo de prueba sin IA.
## - Recibe daño de balas normales y láser
## - HP bar roja que aparece al primer golpe
## - Número de daño acumulativo estilo Cave Story (se actualiza, dura 3s, luego se desvanece)
## - Se regenera a 4000 HP tras 3 segundos sin recibir daño
##
## Estructura del nodo:
##   CharacterBody2D  ← script
##   ├── CollisionShape2D
##   ├── Sprite2D (o AnimatedSprite2D)
##   └── HPBarRoot  (Node2D, posiciónalo encima del sprite en el editor)
##       ├── HPBarBG   (ColorRect, ej. size=(50,4), color oscuro)
##       └── HPBarFill (ColorRect, ej. size=(50,4), color rojo)

class_name Dummy
extends CharacterBody2D

# ── Stats ─────────────────────────────────────────────────────────────
const MAX_HP        : int   = 4000
const REGEN_DELAY   : float = 3.0
const REGEN_RATE    : float = 800.0

# ── Estado ────────────────────────────────────────────────────────────
var _hp             : int   = MAX_HP
var _regen_timer    : float = 0.0
var _regenerating   : bool  = false
var _hp_bar_visible : bool  = false
var _bar_full_width : float = 0.0

# ── Nodos ─────────────────────────────────────────────────────────────
@onready var hp_bar_root : Node2D    = $HPBarRoot
@onready var hp_bar_bg   : ColorRect = $HPBarRoot/HPBarBG
@onready var hp_bar_fill : ColorRect = $HPBarRoot/HPBarFill

# ── Número de daño acumulativo ────────────────────────────────────────
const FONT             := preload("res://data/Fonts/monogatari.ttf")
const DMG_COLOR        := Color(1.0, 0.15, 0.15)
const DMG_DISPLAY_TIME : float = 3.0   # segundos sin daño antes de desvanecerse
const DMG_FADE_TIME    : float = 0.4   # duración del fade al desaparecer

var _dmg_label       : Label = null
var _dmg_accumulated : int   = 0
var _dmg_timer       : float = 0.0
var _dmg_fading      : bool  = false


func _ready() -> void:
	add_to_group("enemies")
	hp_bar_root.hide()
	_bar_full_width   = hp_bar_fill.size.x
	hp_bar_bg.color   = Color(0.1, 0.0, 0.0, 0.8)
	hp_bar_fill.color = Color(0.9, 0.1, 0.1)


# ── Proceso ───────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if Globals.playerStay:
		return

	# ── Regeneración ──────────────────────────────────────────────────
	if _hp < MAX_HP:
		_regen_timer += delta
		if _regen_timer >= REGEN_DELAY:
			_regenerating = true
		if _regenerating:
			_hp = min(_hp + int(REGEN_RATE * delta), MAX_HP)
			_update_hp_bar()
			if _hp >= MAX_HP:
				_hp             = MAX_HP
				_regenerating   = false
				_regen_timer    = 0.0
				_hp_bar_visible = false
				hp_bar_root.hide()

	# ── Número de daño: esperar y desvanecer ──────────────────────────
	if _dmg_label != null and not _dmg_fading:
		_dmg_timer += delta
		if _dmg_timer >= DMG_DISPLAY_TIME:
			_dmg_fading = true
			var tween := _dmg_label.create_tween()
			tween.tween_property(_dmg_label, "modulate:a", 0.0, DMG_FADE_TIME)
			tween.tween_callback(_clear_dmg_label)


func _clear_dmg_label() -> void:
	if is_instance_valid(_dmg_label):
		_dmg_label.queue_free()
	_dmg_label       = null
	_dmg_accumulated = 0
	_dmg_timer       = 0.0
	_dmg_fading      = false


# ── API de daño ───────────────────────────────────────────────────────
func take_damage(amount: int, hit_pos: Vector2) -> void:
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
