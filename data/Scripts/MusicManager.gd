extends Node

# ─── Variables de control ─────────────────────────────────────────────
# estas se leen desde Globals para control externo
# Globals.music_paused  → true  = música en pausa
# Globals.music_volume  → 0.0 a 1.0 = volumen (0 = silencio, 1 = máximo)

# ─── Nodos de audio ───────────────────────────────────────────────────
var _intro_player : AudioStreamPlayer  # reproduce el intro UNA sola vez
var _loop_player  : AudioStreamPlayer  # reproduce el loop indefinidamente

# ─── Estado interno ───────────────────────────────────────────────────
var _current_intro : AudioStream = null  # stream del intro cargado
var _current_loop  : AudioStream = null  # stream del loop cargado
var _intro_done    : bool = false         # true cuando el intro ya terminó
var _is_playing    : bool = false         # true si hay música activa


func _ready():
	# crear los dos reproductores como hijos de este Autoload
	# al ser Autoload sobreviven a cualquier cambio de escena
	_intro_player = AudioStreamPlayer.new()
	_loop_player  = AudioStreamPlayer.new()
	add_child(_intro_player)
	add_child(_loop_player)

	# cuando el intro termine, arrancar el loop automáticamente
	_intro_player.finished.connect(_on_intro_finished)

	# el loop siempre en loop
	# AudioStreamPlayer no tiene loop directo — se hace reconectando finished
	_loop_player.finished.connect(_on_loop_finished)


func _process(_delta):
	# sincronizar pausa con la variable global cada frame
	# así cualquier sistema externo puede pausar/reanudar con solo
	# cambiar Globals.music_paused sin llamar funciones aquí
	if not _is_playing:
		return

	var should_pause : bool  = Globals.get("music_paused") if Globals.get("music_paused") != null else false
	var volume_value : float = Globals.get("music_volume")  if Globals.get("music_volume")  != null else 1.0

	# convertir volumen lineal (0.0-1.0) a decibeles para AudioStreamPlayer
	# linear_to_db(0) = -inf (silencio), linear_to_db(1) = 0db (máximo)
	var db := linear_to_db(clamp(volume_value, 0.0, 1.0))
	_intro_player.volume_db = db
	_loop_player.volume_db  = db

	# pausar o reanudar según la flag global
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


# ─── API pública ──────────────────────────────────────────────────────

# CAMBIO: los parámetros ahora aceptan AudioStreamPlayer en lugar de AudioStream
# así puedes pasar el nodo directamente sin cambiar nada en tus escenas
func play(intro_player, loop_player) -> void:
	# extraer el AudioStream del nodo si se pasó un AudioStreamPlayer
	# si se pasó null o un AudioStream directo, manejarlo también
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

	# si ya está sonando la misma pista no reiniciar
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


func play_loop_only(loop: AudioStream) -> void:
	# atajo para pistas sin intro
	play(null, loop)


func stop() -> void:
	# detener toda la música y limpiar el estado
	_intro_player.stop()
	_loop_player.stop()
	_is_playing    = false
	_intro_done    = false
	_current_intro = null
	_current_loop  = null


func is_playing_track(loop: AudioStream) -> bool:
	# permite que las escenas verifiquen si ya está sonando su pista
	# útil para no reiniciar música al volver a una escena
	return _current_loop == loop and _is_playing


# ─── Callbacks internos ───────────────────────────────────────────────

func _on_intro_finished() -> void:
	# el intro terminó → arrancar el loop
	_intro_done = true
	_start_loop()


func _on_loop_finished() -> void:
	# el loop terminó → repetirlo desde el inicio
	# esto es el sistema de loop manual ya que AudioStreamPlayer
	# no tiene propiedad loop directa en todas las versiones
	_loop_player.play()


func _start_loop() -> void:
	if _current_loop == null:
		return
	_loop_player.stream = _current_loop
	_loop_player.play()
