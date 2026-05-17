extends Camera2D

# ─── Constantes ───────────────────────────────────────────────────────
const CAM_H_LEAD        := 48.0
const CAM_V_LOOK_UP     := 64.0
const CAM_H_LERP        := 4.0
const CAM_V_LERP        := 3.0
const CAM_LOOK_LERP     := 2.5
const CAM_OVERRIDE_LERP := 5.0

# ─── Estado interno ───────────────────────────────────────────────────
var _cam_offset          := Vector2.ZERO
var _cam_target          := Vector2.ZERO
var _cam_small_room      := false
var _cam_override_active := false
var _cam_override_target := Vector2.ZERO
var _cam_override_speed  := CAM_OVERRIDE_LERP
var _cam_focus_node      : Node2D = null

# ─── Quake ────────────────────────────────────────────────────────────
var cam_quake            := false
var cam_quake_intensity  := 4.0
var cam_quake_speed      := 22.0
var _quake_offset        := Vector2.ZERO
var _quake_time          := 0.0

# ─── Fade ─────────────────────────────────────────────────────────────
var _fade_rect           : ColorRect = null

# ─── Referencia al jugador (asignar en el Inspector) ──────────────────
@export var _player : CharacterBody2D = null


# ═══════════════════════════════════════════════════════════════════════
func _ready() -> void:
	anchor_mode                = Camera2D.ANCHOR_MODE_DRAG_CENTER
	offset                     = Vector2.ZERO
	position                   = Vector2.ZERO
	position_smoothing_enabled = false

	_fade_rect              = ColorRect.new()
	_fade_rect.color        = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.z_index      = 100
	add_child(_fade_rect)


# ═══════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if not is_instance_valid(_player):
			return
	if not Globals.playerPlayable:
		return
	if _player.playerDead:
		return
	_update(delta)


# ═══════════════════════════════════════════════════════════════════════
# ─── Lógica principal (estilo Cave Story) ─────────────────────────────

func _update(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_cam_small_room = Globals.small_room

	if _cam_small_room:
		_cam_target          = Vector2.ZERO
		_cam_offset          = Vector2.ZERO
		var fixed_offset     := -_player.global_position

		if cam_quake:
			_quake_time    += delta * cam_quake_speed
			_quake_offset.x = sin(_quake_time * 1.1) * cam_quake_intensity
			_quake_offset.y = sin(_quake_time * 1.7) * cam_quake_intensity
		else:
			_quake_offset   = _quake_offset.lerp(Vector2.ZERO, 10.0 * delta)

		offset = fixed_offset + _quake_offset
		return

	if _cam_override_active or _cam_focus_node != null:
		_cam_target  = Vector2.ZERO
		var dest     := Vector2.ZERO
		if _cam_focus_node != null:
			dest = _player.to_local(_cam_focus_node.global_position)
		else:
			dest = _cam_override_target
		_cam_offset  = _cam_offset.lerp(dest, _cam_override_speed * delta)

	else:
		if not _player._is_stayed():
			var lead_x := CAM_H_LEAD if _player.lastDirection == 0 else -CAM_H_LEAD
			var lead_y := 0.0
			if Input.is_action_pressed("Up"):
				lead_y = -CAM_V_LOOK_UP
			elif Input.is_action_pressed("Down"):
				lead_y = CAM_V_LOOK_UP

			_cam_target.x = lead_x
			_cam_target.y = lerp(_cam_target.y, lead_y, CAM_LOOK_LERP * delta)

		_cam_offset.x = lerp(_cam_offset.x, _cam_target.x, CAM_H_LERP * delta)
		_cam_offset.y = lerp(_cam_offset.y, _cam_target.y, CAM_V_LERP * delta)

	if cam_quake:
		_quake_time    += delta * cam_quake_speed
		_quake_offset.x = sin(_quake_time * 1.1) * cam_quake_intensity
		_quake_offset.y = sin(_quake_time * 1.7) * cam_quake_intensity
	else:
		_quake_offset   = _quake_offset.lerp(Vector2.ZERO, 10.0 * delta)

	offset = _cam_offset + _quake_offset


# ═══════════════════════════════════════════════════════════════════════
# ─── API pública ──────────────────────────────────────────────────────

func focus_on(target: Node2D, speed: float = CAM_OVERRIDE_LERP) -> void:
	_cam_focus_node      = target
	_cam_override_active = true
	_cam_override_speed  = speed


func move_to(target_offset: Vector2, speed: float = CAM_OVERRIDE_LERP) -> void:
	_cam_focus_node      = null
	_cam_override_active = true
	_cam_override_target = target_offset
	_cam_override_speed  = speed


func release() -> void:
	_cam_focus_node      = null
	_cam_override_active = false


# ─── Fade ─────────────────────────────────────────────────────────────

func _ensure_fade_rect() -> void:
	if not is_instance_valid(_fade_rect):
		_fade_rect              = ColorRect.new()
		_fade_rect.color        = Color(0.0, 0.0, 0.0, 1.0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.z_index      = 100
		add_child(_fade_rect)


func _resize_fade_rect() -> void:
	var vp              : Vector2 = get_viewport().get_visible_rect().size
	_fade_rect.size     = vp
	_fade_rect.position = -vp * 0.5


## Fade a negro. Devuelve el Tween para encadenar callbacks.
func fade_to_black(duration: float) -> Tween:
	_ensure_fade_rect()
	_resize_fade_rect()
	var t := create_tween()
	t.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), duration) \
		.set_trans(Tween.TRANS_LINEAR)
	return t


## Fuerza el negro y hace fade a transparente.
func fade_from_black(duration: float) -> void:
	_ensure_fade_rect()
	_resize_fade_rect()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	var t := create_tween()
	t.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 0.0), duration) \
		.set_trans(Tween.TRANS_LINEAR)
