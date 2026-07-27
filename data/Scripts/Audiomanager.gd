## AudioManager.gd
## Gestiona música (intro+loop) y volumen de los buses Music y SFX.
##
## ─── Integración ──────────────────────────────────────────────────────
##   Añadir como AutoLoad o nodo hijo de Game.tscn.
##   SettingsMenu lo busca por grupo "audio_manager" para sincronizar
##   los sliders con los valores reales de los buses.
##
## ─── Buses requeridos en Project → Audio ──────────────────────────────
##   Master → Music
##           → SFX

extends Node

# ── Grupo ─────────────────────────────────────────────────────────────
const GROUP := "audio_manager"

# ── Buses ─────────────────────────────────────────────────────────────
const BUS_MUSIC := "Music"
const BUS_SFX   := "SFX"

# ── Volumen por defecto ────────────────────────────────────────────────
const DEFAULT_MUSIC : float = 1.0   # 0.0 – 1.0
const DEFAULT_SFX   : float = 1.0

# ── Paso de volumen por tecla ──────────────────────────────────────────
const VOLUME_STEP : float = 0.1

# ── Estado ────────────────────────────────────────────────────────────
var _vol_music          : float = DEFAULT_MUSIC
var _vol_sfx            : float = DEFAULT_SFX
var _muted_music        : bool  = false
var _muted_sfx          : bool  = false
var _vol_music_pre_mute : float = DEFAULT_MUSIC
var _vol_sfx_pre_mute   : float = DEFAULT_SFX

# ── Reproductores de música ────────────────────────────────────────────
var _intro_player : AudioStreamPlayer
var _loop_player  : AudioStreamPlayer

# ── Estado de reproducción ─────────────────────────────────────────────
var _current_intro : AudioStream = null
var _current_loop  : AudioStream = null
var _intro_done    : bool        = false
var _is_playing    : bool        = false


# ═══════════════════════════════════════════════════════════════════════
# ─── INIT ─────────────────────────────────────────────════════════════

func _ready() -> void:
	add_to_group(GROUP)
	_ensure_buses()

	_intro_player      = AudioStreamPlayer.new()
	_loop_player       = AudioStreamPlayer.new()
	_intro_player.bus  = BUS_MUSIC
	_loop_player.bus   = BUS_MUSIC
	add_child(_intro_player)
	add_child(_loop_player)

	_intro_player.finished.connect(_on_intro_finished)
	_loop_player.finished.connect(_on_loop_finished)

	_apply_music_volume()
	_apply_sfx_volume()


# ── Crea los buses Music y SFX si no existen en el proyecto ──────────
func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			# Enviar al Master (bus 0) para que salga audio
			AudioServer.set_bus_send(idx, "Master")
			print("[AudioManager] Bus '%s' creado automáticamente." % bus_name)


# ═══════════════════════════════════════════════════════════════════════
# ─── PROCESS ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _is_playing:
		return
	var paused : bool = Globals.get("music_paused") if Globals.get("music_paused") != null else false
	_intro_player.stream_paused = paused and _intro_player.playing
	_loop_player.stream_paused  = paused and _loop_player.playing


# ═══════════════════════════════════════════════════════════════════════
# ─── INPUT (teclas de volumen rápido) ─────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Vol+"):
		set_music_volume(_vol_music + VOLUME_STEP)
	elif event.is_action_pressed("Vol-"):
		set_music_volume(_vol_music - VOLUME_STEP)
	elif event.is_action_pressed("Mute"):
		toggle_mute_music()


# ═══════════════════════════════════════════════════════════════════════
# ─── API PÚBLICA — VOLUMEN ────────────────────────────────────────────

func get_music_volume() -> float:
	return _vol_music

func get_sfx_volume() -> float:
	return _vol_sfx

func set_music_volume(v: float) -> void:
	_vol_music   = clampf(v, 0.0, 1.0)
	_muted_music = false
	_apply_music_volume()

func set_sfx_volume(v: float) -> void:
	_vol_sfx   = clampf(v, 0.0, 1.0)
	_muted_sfx = false
	_apply_sfx_volume()

func toggle_mute_music() -> void:
	if _muted_music:
		_muted_music = false
		_vol_music   = _vol_music_pre_mute
	else:
		_vol_music_pre_mute = _vol_music
		_muted_music        = true
	_apply_music_volume()

func toggle_mute_sfx() -> void:
	if _muted_sfx:
		_muted_sfx = false
		_vol_sfx   = _vol_sfx_pre_mute
	else:
		_vol_sfx_pre_mute = _vol_sfx
		_muted_sfx        = true
	_apply_sfx_volume()


# ═══════════════════════════════════════════════════════════════════════
# ─── API PÚBLICA — REPRODUCCIÓN ───────────────────────────────────────

var _fade_tween : Tween = null


func play(intro_src, loop_src, fade_time: float = 0.0) -> void:
	var intro : AudioStream = _to_stream(intro_src)
	var loop  : AudioStream = _to_stream(loop_src)

	if _current_loop == loop and _is_playing:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null

	# sin fundido, o no había nada sonando todavía: comportamiento de
	# siempre, cambio inmediato
	if fade_time <= 0.0 or not _is_playing:
		_play_immediate(intro, loop)
		return

	# con fundido: bajar el volumen de lo que está sonando ahora mismo,
	# y recién cuando termine de desvanecerse arrancar la nueva pista
	# (intro, y de ahí al loop, como siempre)
	var active_player := _loop_player if _loop_player.playing else _intro_player
	_fade_tween = create_tween()
	_fade_tween.tween_property(active_player, "volume_db", -80.0, fade_time)
	_fade_tween.tween_callback(func():
		_play_immediate(intro, loop)
	)


func _play_immediate(intro: AudioStream, loop: AudioStream) -> void:
	_current_intro = intro
	_current_loop  = loop
	_intro_done    = false
	_is_playing    = true

	_intro_player.stop()
	_loop_player.stop()
	_intro_player.volume_db = 0.0
	_loop_player.volume_db  = 0.0

	if intro != null:
		_intro_player.stream = intro
		_intro_player.play()
	else:
		_intro_done = true
		_start_loop()

func play_loop_only(loop: AudioStream, fade_time: float = 0.0) -> void:
	play(null, loop, fade_time)

func stop() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
	_intro_player.stop()
	_loop_player.stop()
	_intro_player.volume_db = 0.0
	_loop_player.volume_db  = 0.0
	_is_playing    = false
	_intro_done    = false
	_current_intro = null
	_current_loop  = null

func is_playing_track(loop: AudioStream) -> bool:
	return _current_loop == loop and _is_playing


# ═══════════════════════════════════════════════════════════════════════
# ─── API PÚBLICA — SFX POSICIONAL (ataque, salto, daño, pisadas, etc) ──
# Pensado para usarse desde Enemy (enemy_base.gd) y cualquier otro
# script que necesite un sonido puntual en un punto del mundo, sin tener
# que manejar sus propios AudioStreamPlayer2D para cada evento.
#
##   AudioManager.play_sfx(mi_stream, global_position)
#
# Crea un AudioStreamPlayer2D temporal en el bus SFX, lo reproduce en la
# posición indicada, y se autodestruye solo al terminar. No hace falta
# guardarlo ni liberarlo a mano.
func play_sfx(stream: AudioStream, global_pos: Vector2 = Vector2.ZERO, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream       = stream
	player.bus          = BUS_SFX
	player.volume_db    = volume_db
	player.global_position = global_pos
	if pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)

	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# ═══════════════════════════════════════════════════════════════════════
# ─── PRIVADO ──────────────────────────────────────────────────────────

func _apply_music_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx < 0:
		return
	var effective := 0.0 if _muted_music else _vol_music
	AudioServer.set_bus_mute(idx, effective <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(effective, 0.0001)))
	if Globals.get("music_volume") != null:
		Globals.music_volume = effective

func _apply_sfx_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx < 0:
		return
	var effective := 0.0 if _muted_sfx else _vol_sfx
	AudioServer.set_bus_mute(idx, effective <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(effective, 0.0001)))

func _to_stream(src) -> AudioStream:
	if src is AudioStreamPlayer:
		return src.stream
	if src is AudioStream:
		return src
	return null

func _on_intro_finished() -> void:
	_intro_done = true
	_start_loop()

func _on_loop_finished() -> void:
	_loop_player.play()

func _start_loop() -> void:
	if _current_loop == null:
		return
	_loop_player.stream = _current_loop
	_loop_player.play()
