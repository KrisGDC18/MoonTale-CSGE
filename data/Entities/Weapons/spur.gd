class_name Spur
extends Weapon

const CHARGE_TIME_LV1 : float = 0.5
const CHARGE_TIME_LV2 : float = 1.0
const CHARGE_TIME_LV3 : float = 2.0

var _charge_timer      : float = 0.0
var _charge_level      : int   = 0
var _prev_charge_level : int   = -1
var _is_charging       : bool  = false
var _max_charge_pinged : bool  = false

# La dirección se puede cambiar mientras se carga
# _shoot_dir viene de Weapon y se actualiza cada frame con _update_aim()

# Cache nodos de audio
var _charge_audio_nodes : Array[AudioStreamPlayer2D] = [null, null, null]
var _max_charge_audio   : AudioStreamPlayer2D = null
var _simple_shoot_audio : AudioStreamPlayer2D = null  # ShootAudio0 → disparo simple


func _ready() -> void:
	weapon_name = "Spur"
	max_level   = 3
	xp_to_level = [0, 50, 100]


func weapon_process(delta: float) -> void:
	if _player == null or not visible:
		return
	if Globals.playerStay:
		return

	var looking_up   : bool = Input.is_action_pressed("Up")
	var looking_down : bool = Input.is_action_pressed("Down") and not _player.is_on_floor()

	# La dirección se actualiza SIEMPRE, incluso mientras carga
	_update_aim(_player.lastDirection, looking_up, looking_down)
	_handle_aim(_player.lastDirection, looking_up, looking_down)
	_handle_fire(delta)


func _handle_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	var facing : String = "right" if last_direction == 0 else "left"
	var anim   : String

	if _is_charging:
		var suffix : String
		if looking_up:
			suffix = "_%s_up" % facing
		elif looking_down:
			suffix = "_%s_down" % facing
		else:
			suffix = "_%s" % facing
		# Usar max(1, _charge_level) → mientras carga pero aún en nivel 0 muestra charge1
		anim = "idle" + suffix
	else:
		if looking_up:
			anim = "idle_%s_up" % facing
		elif looking_down:
			anim = "idle_%s_down" % facing
		else:
			anim = "idle_%s" % facing

	# Solo cambiar animación si es diferente a la actual → evita reinicio cada frame
	if animator.animation != anim:
		animator.play(anim)


func _handle_fire(delta: float) -> void:
	# ── Presión inicial: disparo normal inmediato + empezar carga ────────
	if Input.is_action_just_pressed("Fire"):
		_spawn_bullet(0)        # bala nivel 0 = disparo normal sin carga
		_play_simple_shoot_sound()
		_is_charging   = true   # empieza la carga desde este frame

	# ── Mientras se mantiene: acumular carga ─────────────────────────────
	if Input.is_action_pressed("Fire") and _is_charging:
		_charge_timer += delta

		var new_level : int
		if _charge_timer >= CHARGE_TIME_LV3:
			new_level = 3
		elif _charge_timer >= CHARGE_TIME_LV2:
			new_level = 2
		elif _charge_timer >= CHARGE_TIME_LV1:
			new_level = 1
		else:
			new_level = 0

		# Cambió de nivel → cambiar sonido de carga
		if new_level != _prev_charge_level:
			_stop_all_charge_sounds()
			_charge_level = new_level

			if _charge_level > 0 and _charge_level < 3:
				_play_charge_sound(_charge_level)
			elif _charge_level == 3 and not _max_charge_pinged:
				_play_max_charge_sound()
				_max_charge_pinged = true

			_prev_charge_level = _charge_level

	# ── Al soltar: disparar bala cargada (solo si había carga) ────────────
	elif Input.is_action_just_released("Fire"):
		_stop_all_charge_sounds()
		if _charge_level > 0:
			# _shoot_dir ya tiene la dirección actual del jugador al momento de soltar
			_spawn_bullet(_charge_level)
		reset_charge()


func _spawn_bullet(lvl: int) -> void:
	if bullet_scene == null:
		return
	if _bullet_count >= MAX_BULLETS:
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = _get_bullet_spawn_pos()
	bullet.tree_exiting.connect(func(): _bullet_count -= 1)
	get_tree().root.add_child(bullet)
	bullet.setup(lvl, _shoot_dir)
	_bullet_count += 1

	if lvl > 0:
		_play_shoot_sound(lvl)


func reset_charge() -> void:
	_charge_timer      = 0.0
	_charge_level      = 0
	_prev_charge_level = -1
	_is_charging       = false
	_max_charge_pinged = false


# ── Sonidos de carga (loop) ───────────────────────────────────────────
# Nodos: ChargeAudio1, ChargeAudio2  (Loop ON en su stream)

func _get_charge_audio(lvl: int) -> AudioStreamPlayer2D:
	var index : int = clamp(lvl - 1, 0, 1)

	if _charge_audio_nodes[index] == null:
		_charge_audio_nodes[index] = get_node_or_null("ChargeAudio%d" % (index + 1))

	if _charge_audio_nodes[index] == null and index > 0:
		if _charge_audio_nodes[0] == null:
			_charge_audio_nodes[0] = get_node_or_null("ChargeAudio1")
		_charge_audio_nodes[index] = _charge_audio_nodes[0]

	return _charge_audio_nodes[index]


func _play_charge_sound(lvl: int) -> void:
	var audio : AudioStreamPlayer2D = _get_charge_audio(lvl)
	if audio == null:
		push_error("Spur: no se encontró ChargeAudio%d como hijo" % lvl)
		return
	if not audio.playing:
		audio.play()


func _stop_all_charge_sounds() -> void:
	for i in range(2):
		var audio : AudioStreamPlayer2D = _get_charge_audio(i + 1)
		if audio != null and audio.playing:
			audio.stop()


# ── Sonido de carga máxima ────────────────────────────────────────────
# Nodo: MaxChargeAudio (sin loop, suena una sola vez al llegar al nivel 3)

func _play_max_charge_sound() -> void:
	if _max_charge_audio == null:
		_max_charge_audio = get_node_or_null("MaxChargeAudio")
	if _max_charge_audio == null:
		push_error("Spur: no se encontró MaxChargeAudio como hijo")
		return
	_max_charge_audio.play()


# ── Sonido disparo simple (al presionar Fire por primera vez) ─────────
# Nodo: ShootAudio0  (sin loop, se reproduce una sola vez)

func _play_simple_shoot_sound() -> void:
	if _simple_shoot_audio == null:
		_simple_shoot_audio = get_node_or_null("ShootAudio0")
	if _simple_shoot_audio == null:
		push_error("Spur: no se encontró ShootAudio0 como hijo")
		return
	_simple_shoot_audio.play()
