extends Node

# ─── Variables de volumen ─────────────────────────────────────────────
@export_range(0.0, 1.0) var volume        : float = 1.0   # volumen actual (0.0 – 1.0)
const VOLUME_STEP                         : float = 0.1   # cuánto sube/baja cada pulsación
var _muted                                : bool  = false  # estado mute
var _volume_before_mute                   : float = 1.0   # guarda el volumen antes de mutear

# ─── Nodos de audio ───────────────────────────────────────────────────
var _intro_player : AudioStreamPlayer
var _loop_player  : AudioStreamPlayer

# ─── Estado interno ───────────────────────────────────────────────────
var _current_intro : AudioStream = null
var _current_loop  : AudioStream = null
var _intro_done    : bool = false
var _is_playing    : bool = false


func _ready():
	_intro_player = AudioStreamPlayer.new()
	_loop_player  = AudioStreamPlayer.new()
	add_child(_intro_player)
	add_child(_loop_player)

	_intro_player.finished.connect(_on_intro_finished)
	_loop_player.finished.connect(_on_loop_finished)

	# Aplicar volumen inicial
	_apply_volume()


func _process(_delta):
	if not _is_playing:
		return

	# ── Sincronizar pausa con Globals ─────────────────────────────────
	var should_pause : bool = Globals.get("music_paused") if Globals.get("music_paused") != null else false

	if should_pause:
		if _intro_player.playing:
			_intro_player.stream_paused = true
		if _loop_player.playing:
			_loop_player.stream_paused = true
	else:
		if _intro_player.stream_paused:
			_intro_player.stream_paused = false
		if _loop_player.stream_paused:
			_loop_player.stream_paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Vol+"):
		set_volume(volume + VOLUME_STEP)

	elif event.is_action_pressed("Vol-"):
		set_volume(volume - VOLUME_STEP)

	elif event.is_action_pressed("Mute"):
		toggle_mute()


# ─── API pública ──────────────────────────────────────────────────────

func set_volume(new_volume: float) -> void:
	volume  = clamp(new_volume, 0.0, 1.0)
	_muted  = false   # subir/bajar volumen cancela el mute
	_apply_volume()
	print("MusicManager: volumen → %.0f%%" % (volume * 100))


func toggle_mute() -> void:
	if _muted:
		# Desmutear: recuperar volumen anterior
		_muted  = false
		volume  = _volume_before_mute
	else:
		# Mutear: guardar volumen actual y silenciar
		_volume_before_mute = volume
		_muted              = true
	_apply_volume()
	print("MusicManager: mute → %s" % str(_muted))


func play(intro_player, loop_player) -> void:
	var intro : AudioStream = null
	var loop  : AudioStream = null

	if intro_player is AudioStreamPlayer:
		intro = intro_player.stream
	elif intro_player is AudioStream:
		intro = intro_player

	if loop_player is AudioStreamPlayer:
		loop = loop_player.stream
	elif loop_player is AudioStream:
		loop = loop_player

	if _current_loop == loop and _is_playing:
		return

	_current_intro = intro
	_current_loop  = loop
	_intro_done    = false
	_is_playing    = true

	_intro_player.stop()
	_loop_player.stop()

	if intro != null:
		_intro_player.stream = intro
		_intro_player.play()
	else:
		_intro_done = true
		_start_loop()

	_apply_volume()


func play_loop_only(loop: AudioStream) -> void:
	play(null, loop)


func stop() -> void:
	_intro_player.stop()
	_loop_player.stop()
	_is_playing    = false
	_intro_done    = false
	_current_intro = null
	_current_loop  = null


func is_playing_track(loop: AudioStream) -> bool:
	return _current_loop == loop and _is_playing


# ─── Internos ─────────────────────────────────────────────────────────

func _apply_volume() -> void:
	var effective_volume : float = 0.0 if _muted else volume
	var db               : float = linear_to_db(effective_volume)
	_intro_player.volume_db = db
	_loop_player.volume_db  = db

	# Mantener Globals sincronizado si otros sistemas lo leen
	if Globals.get("music_volume") != null:
		Globals.music_volume = effective_volume


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
