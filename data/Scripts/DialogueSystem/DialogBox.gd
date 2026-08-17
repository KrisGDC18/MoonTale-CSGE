extends CanvasLayer

signal dialog_finished
signal choice_made(index: int)
signal block_changed(name: String)
signal history_toggled(is_open: bool)

@onready var panel       : Control           = $Root/Box
## Referencia al fondo/borde estilo windowskin (ver RMWindowSkinPanel.gd),
## para poder ocultarlo/mostrarlo desde el script de diálogo con la clave
## de página opcional "windowskin_visible". get_node_or_null: si todavía
## no migraste Box a este sistema, esto no rompe nada, solo queda null.
@onready var windowskin_bg : Control          = get_node_or_null("Root/Box/WindowSkinBG")
@onready var portrait    : TextureRect       = $Root/Box/MarginContainer/HBoxContainer/Portrait
# El retrato animado usa un TextureRect (igual que "portrait"), NO un
# AnimatedSprite2D. Un AnimatedSprite2D es un Node2D: los Container de
# Godot (HBoxContainer, etc.) solo miden y posicionan a sus hijos que sean
# Control, así que un Node2D metido ahí queda directamente ignorado por el
# layout (no reserva espacio, y move_child() solo cambia el orden de
# dibujado, no la posición real) — eso era lo que rompía tanto el
# realineado a la derecha como el acomodo del texto. Usando un TextureRect
# como este, el retrato "animado" es un Control real: el HBoxContainer lo
# mide, lo posiciona y le hace lugar exactamente igual que a "portrait",
# sin necesitar ningún nodo intermedio. La animación se reproduce a mano
# (ver _anim_play/_anim_process/_anim_update_texture más abajo), sacando
# cada frame directamente del recurso SpriteFrames y asignándolo a
# ".texture". Configurá en el editor el mismo expand_mode/stretch_mode/
# custom_minimum_size que uses en "portrait", para que ambos ocupen el
# mismo espacio dentro del HBoxContainer.
@onready var portrait_animated  : TextureRect       = $Root/Box/MarginContainer/HBoxContainer/PortraitAnimated
@onready var hbox               : HBoxContainer     = $Root/Box/MarginContainer/HBoxContainer
@onready var speaker     : Label             = $Root/Box/SpeakerName
@onready var text_lbl    : RichTextLabel     = $Root/Box/MarginContainer/HBoxContainer/VBoxContainer/Text
@onready var arrow       : Label             = $Root/Box/Arrow
@onready var choices     : VBoxContainer     = $Root/Box/ChoicesBG/Choices
@onready var choices_bg  : Control           = $Root/Box/ChoicesBG
## Igual que "windowskin_bg" pero para el fondo de ChoicesBG. Ver la nota
## de migración al final del archivo para los pasos de escena necesarios.
@onready var choices_windowskin_bg : Control = get_node_or_null("Root/Box/ChoicesBG/ChoicesWindowSkinBG")
@onready var item_box    : Control           = $Root/ItemBox
@onready var item_icon   : TextureRect       = $Root/ItemBox/Icon
@onready var beep_sfx    : AudioStreamPlayer = $BeepSFX
@onready var cursor_sfx  : AudioStreamPlayer = $CursorSFX
@onready var confirm_sfx : AudioStreamPlayer = $ConfirmSFX

# ── Historial de diálogo (estilo Zelda TotK) ──────────────────────────
# Nodos opcionales: si no existen en la escena, la función de historial
# queda deshabilitada silenciosamente (con un aviso en consola la primera
# vez que se intenta abrir) en vez de romper el resto del diálogo.
# Estructura de escena esperada:
#   Root
#   └── HistoryLog (Control)                     → history_panel
#       └── ScrollContainer (ScrollContainer)     → history_scroll
#           └── HistoryList (VBoxContainer)       → history_list
# Además, un botón SIEMPRE visible mientras el cuadro de diálogo esté
# activo (en cualquier estado: tipeando, esperando Accept, o con choices
# abiertas), en cualquier parte de la escena — no necesita estar dentro
# de "Box". Ejemplo de ruta: Root/HistoryButton.
@onready var history_panel  : Control          = get_node_or_null("Root/HistoryLog")
@onready var history_scroll : ScrollContainer  = get_node_or_null("Root/HistoryLog/ScrollContainer")
@onready var history_list   : VBoxContainer    = get_node_or_null("Root/HistoryLog/ScrollContainer/HistoryList")
@onready var history_button : Button           = get_node_or_null("Root/HistoryButton")

const SKIP_CHARS          := [" ", ".", ",", "!", "?", ":", ";", "-", "—", "\"", "'", "(", ")", "\n"]
const BEEP_EVERY          := 2
const CHOICE_FONT         := preload("res://data/Fonts/monogatari.ttf")
const MAX_CHARS_PER_LINE  := 30
const MAX_LINES_PER_PAGE  := 7
const MAX_CHOICES_PER_PAGE := 4
# Alto base (a resolución 1920x1080) del área de texto del diálogo.
# Debe coincidir con el valor usado en _apply_scaled_props() para
# custom_minimum_size, ya que se usa para calcular cuántas líneas caben
# realmente en el cuadro al aplicar valineación vertical.
const TEXT_BOX_BASE_HEIGHT := 218.0

# Preload de los efectos de texto custom (RichTextEffect).
const RTLShakeScript    := preload("res://data/Scripts/effects/RTLShake.gd")
const RTLWaveScript     := preload("res://data/Scripts/effects/RTLWave.gd")
const RTLBounceInScript := preload("res://data/Scripts/effects/RTLBounceIn.gd")
const RTLTypeWaveScript := preload("res://data/Scripts/effects/RTLTypeWave.gd")
const RTLGlitchScript   := preload("res://data/Scripts/effects/RTLGlitch.gd")
const RTLRainbowScript  := preload("res://data/Scripts/effects/RTLRainbow.gd")

# Fuente y tamaño por defecto del texto del diálogo.
# Se pueden sobreescribir por página con las claves "font" y "font_size".
# _ready() los inicializa con la fuente que tenga el nodo en su tema si no se precargan.
var default_font           : Font           = null
var default_font_size      : int            = 0
# Alineación de texto por defecto. Se puede sobreescribir por página con la clave
# "text_alignment". Valores: HORIZONTAL_ALIGNMENT_LEFT / _CENTER / _RIGHT / _FILL
var default_text_alignment  : HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
# Alineación vertical por defecto. Se puede sobreescribir por página con la clave
# "text_valignment". Valores: VERTICAL_ALIGNMENT_TOP / _CENTER / _BOTTOM
# Nota: con el autoscroll activo, solo tiene efecto visible si el contenido
# entra completo en el cuadro sin necesidad de scroll.
var default_text_valignment : VerticalAlignment   = VERTICAL_ALIGNMENT_TOP

# Espaciado extra entre líneas del texto del diálogo, en píxeles a resolución
# base 1920x1080 (se escala igual que las fuentes). Se puede sobreescribir por
# página con la clave "line_spacing". 0 = usa el espaciado por defecto del tema.
@export var default_line_spacing : int = 18
var _current_line_spacing : int = 0

# Velocidad de tipeo por defecto, en caracteres por segundo. Se puede
# sobreescribir por página con la clave "type_speed" (también en
# caracteres por segundo). Por ejemplo, un narrador lento podría usar
# "type_speed": 15, y un texto urgente/rápido "type_speed": 80.
@export var default_chars_per_second : float = 40.0
var _current_chars_per_second : float = 40.0

# Rangos de velocidad custom por fragmento, definidos con la etiqueta
# [speed=N]...[/speed] dentro del "text" de una página (ver
# _extract_speed_ranges). Cada elemento: { "start": int, "end": int,
# "speed": float }, con "start"/"end" en posiciones de caracteres PLANOS
# (índices dentro de _full_text ignorando el resto del BBCode). Se
# recalcula en cada _show_page().
var _speed_ranges : Array = []

# ── Presets de "voz" por personaje (estilo Undertale/Deltarune) ────────
# En vez de repetir font/font_size/type_speed/beep_stream en cada página
# de un mismo personaje, se registra una vez un preset con nombre y se lo
# referencia desde la página con la clave "voice":
#
#   DialogBox.register_voice("napstablook", {
#       "font"        : preload("res://fonts/wingdings.ttf"),
#       "font_size"   : 36,
#       "type_speed"  : 18,
#       "beep_stream" : preload("res://sfx/voice_low.wav"),
#   })
#
#   { "speaker": "Napstablook", "voice": "napstablook", "text": "..." }
#
# Prioridad de resolución para cada propiedad (font, font_size,
# type_speed, beep_stream): valor explícito en la página > valor del
# preset de "voice" > default global del cuadro de diálogo.
var _voice_presets : Dictionary = {}

# Catálogo de voces (recurso VoiceCatalog, ver VoiceCatalog.gd/VoicePreset.gd)
# asignable desde el editor: arrastrá un archivo .tres de tipo VoiceCatalog
# a este campo en el Inspector y sus voces se registran solas en _ready().
# También se pueden cargar catálogos adicionales en cualquier momento con
# load_voice_catalog(catalog).
@export var voice_catalog : VoiceCatalog = null

# ── Estado interno ─────────────────────────────────────────────────────
var _blocks       : Dictionary = {}
var _current_block: String     = ""
var _page_index   : int        = 0
var _full_text    : String     = ""
var _chars_shown  : int        = 0
var _timer        : float      = 0.0
var _typing       : bool       = false
var _waiting      : bool       = false

# ── Auto-avance de página ──────────────────────────────────────────────
# Si una página define "auto_advance": true, en vez de esperar a que el
# jugador presione Accept, el cuadro pasa solo a la página siguiente al
# terminar de tipearse (o de saltearse con _skip()), tras esperar
# "auto_advance_delay" segundos (o el default de acá si la página no
# especifica uno propio). No aplica a páginas con choices, ya que esas
# necesitan sí o sí una elección del jugador.
@export var default_auto_advance_delay : float = 1.5
var _auto_advance_active : bool  = false
var _auto_advance_timer  : float = 0.0
var _in_choices   : bool       = false

# ── Historial de diálogo ───────────────────────────────────────────────
# Guarda cada página de texto ya mostrada DURANTE ESTA EJECUCIÓN del
# cuadro de diálogo (se reinicia en cada llamada a start()). Cada entrada
# es un Dictionary { "speaker": String, "text": String } con el texto ya
# traducido y completo (sin el efecto de tipeo progresivo ni el padding
# de alineación vertical).
var _history : Array[Dictionary] = []

# Nombre de la acción de Input (definida en Project > Input Map) que
# abre/cierra el panel de historial. Cambiala desde el editor si preferís
# otro nombre de acción o tecla.
@export var history_action_name : String = "DialogHistory"

# Cantidad máxima de entradas a conservar en el historial. 0 = sin límite
# (guarda todo lo visto durante la ejecución actual).
@export var max_history_entries : int = 0

# true mientras el panel de historial está abierto. Mientras esté abierto,
# se pausa el resto de la lógica de diálogo (tipeo, choices, avance).
var _in_history : bool = false

# ColorRect semi-transparente creado en runtime para oscurecer la pantalla
# detrás del panel de historial. No requiere ningún nodo extra en la
# escena: se crea una sola vez, la primera vez que hace falta.
var _history_dim : ColorRect = null

# Color del overlay de oscurecimiento (RGBA). Ajustable desde el editor.
@export var history_dim_color : Color = Color(0, 0, 0, 0.65)

# Se guarda la visibilidad real del cuadro de ítem antes de abrir el
# historial, para restaurarla tal cual estaba (y no mostrarlo de más si
# la página actual no tenía ítem) al cerrar el historial.
var _item_box_was_visible_before_history : bool = false
var _choice_index : int        = 0
var _choice_page  : int        = 0
var _beep_counter : int        = 0
var _release_player_on_close : bool = true
# Animaciones activas del portrait animado para la página actual.
# Se leen de las claves "portrait_anim_typing" y "portrait_anim_idle" de cada página.
var _portrait_anim_typing : String = ""
var _portrait_anim_idle   : String = ""

# ── Reproducción manual de la animación del retrato (TextureRect) ─────
# Como portrait_animated ahora es un TextureRect (no un AnimatedSprite2D),
# no existe un player de animaciones nativo: estas variables llevan a mano
# el estado de reproducción (qué animación, qué frame, cuánto tiempo
# acumulado) y _anim_process() las usa cada frame para decidir cuándo
# avanzar de frame y actualizar la textura mostrada.
var _anim_sprite_frames : SpriteFrames = null
var _anim_current_name  : String       = ""
var _anim_current_frame : int          = 0
var _anim_frame_timer   : float        = 0.0
var _anim_playing       : bool         = false

# ── Emociones del retrato animado + tag de texto [face=NOMBRE] ────────
# "portrait_emotions" (opcional, por página) define variantes de
# animación con nombre, cada una con su propio estado "talk"/"idle":
#
#   "portrait_emotions": {
#       "default": { "talk": "idle_talk", "idle": "idle_idle" },
#       "happy":   { "talk": "happy_talk", "idle": "happy_idle" },
#       "sad":     { "talk": "sad_talk",   "idle": "sad_idle" },
#   },
#   "portrait_emotion": "default",  # emoción base de toda la página
#
# Además, cualquier palabra del "text" puede envolverse en
# [face=NOMBRE]...[/face] para que el retrato cambie a esa emoción SOLO
# mientras esa palabra se está tipeando, y vuelva sola a la emoción base
# de la página apenas se termine de tipear esa palabra — igual que un
# efecto de texto más, pero afectando al retrato en vez de al texto.
# Si no se define "portrait_emotions", todo esto se ignora y el sistema
# sigue funcionando exactamente como antes (con "portrait_anim_typing"/
# "portrait_anim_idle"/"portrait_anim" planos).
var _portrait_emotions     : Dictionary = {}
var _portrait_base_emotion : String     = "default"
var _face_ranges           : Array      = []
var _current_face_applied  : String     = ""

# Audio de typing por defecto. Se captura automáticamente en _ready() desde el nodo
# BeepSFX. Puede sobreescribirse globalmente asignando esta variable, o por página
# con la clave "beep_stream" (AudioStream). null = sin sonido.
var default_beep_stream   : AudioStream = null
# Stream activo para la página actual (se resetea en cada _show_page).
var _current_beep_stream  : AudioStream = null

# ── Efectos de texto custom ────────────────────────────────────────────
var _typewave_effect : RichTextEffect = null

# ── Autoscroll de línea nueva (Cave Story / Pokémon style) ────────────
# Velocidad de suavizado del scroll progresivo. Más alto = alcanza el
# objetivo más rápido. Se puede ajustar libremente desde el editor.
@export var autoscroll_speed : float = 10.0

# Velocidad (en píxeles reales por segundo) a la que se desplaza el texto
# cuando el jugador usa las acciones Up/Down para hacer scroll manual, una
# vez que el texto ya terminó de tipearse y el bloqueo fue liberado.
@export var manual_scroll_speed : float = 500.0

# ── Traducciones ───────────────────────────────────────────────────────
# Si está activado (default), todo texto visible del diálogo (speaker,
# text, choices y los labels de navegación "Opciones anteriores"/"Más
# opciones") pasa por tr() antes de mostrarse, usando el sistema de
# traducción integrado de Godot (archivos .po / .csv cargados como
# Translation en el proyecto). Por defecto, el string original (tal como
# se escribió en el bloque de diálogo) se usa como clave de traducción
# (msgid). Si no existe una traducción cargada para esa clave en el
# locale actual, tr() devuelve el string original sin cambios — así que
# dejar esto en true es seguro incluso en proyectos que todavía no
# tienen traducciones.
#
# Claves opcionales por página, para cuando el texto de autoría no es
# práctico como clave (textos largos, con BBCode, o repetidos):
#   "text_key"     : clave de traducción explícita para "text".
#   "speaker_key"  : clave de traducción explícita para "speaker".
#   "choice_keys"  : Array[String] paralelo a "choices", una clave por opción.
#   "text_args"    : Array de argumentos para interpolar en el texto YA
#                    traducido vía el operador "%" de String (%s, %d, etc.).
@export var use_translations : bool = true


## Traduce un string usando tr() si use_translations está activo. Strings
## vacíos se devuelven tal cual (evita registrar una clave "" en tr()).
## Centralizar la traducción acá asegura que todos los textos visibles
## del diálogo (páginas, choices, labels de navegación) pasen siempre por
## el mismo punto, en vez de tener que acordarse de envolver cada lugar
## donde se asigna texto a un Label/RichTextLabel.
func _tr(text: String) -> String:
	if not use_translations or text == "":
		return text
	return tr(text)


## Traduce con una clave EXPLÍCITA opcional, distinta del texto original.
## Uso: cuando el string en el idioma de autoría no es práctico como clave
## de traducción (textos largos, con BBCode, o que se repiten con variantes
## menores), la página puede definir una clave corta aparte, p. ej.:
##   { "text": "El texto largo en español...", "text_key": "npc_guardia_01" }
## Si "key" no está presente en los archivos de traducción cargados, tr()
## devuelve la clave tal cual — en ese caso hacemos fallback al texto
## original ("raw") para no mostrarle al jugador la clave cruda por error.
## Si no se definió una clave separada (key == raw), el comportamiento es
## idéntico a _tr(): se usa el propio texto como clave.
func _translate_with_key(raw: String, key: String) -> String:
	if not use_translations or raw == "":
		return raw
	var translated : String = tr(key)
	if translated == key and key != raw:
		translated = raw
	return translated


## Traduce el texto principal de una página, con soporte opcional de:
##   - "text_key"  : clave de traducción explícita (ver _translate_with_key).
##   - "text_args" : Array de argumentos para interpolar en el texto YA
##                   traducido, vía el operador "%" de String (placeholders
##                   %s, %d, etc.). Útil para nombres de ítems, del jugador,
##                   cantidades, etc. que no deben traducirse por separado.
## Ejemplo:
##   { "text": "Recibiste %d de oro.", "text_args": [50] }
func _translate_page_text(page: Dictionary) -> String:
	var raw   : String = page.get("text", "")
	var key   : String = page.get("text_key", raw)
	var result: String = _translate_with_key(raw, key)
	var args  : Array   = page.get("text_args", [])
	if args.size() > 0:
		result = result % args
	return result


## Traduce el nombre del hablante de una página, con soporte opcional de
## "speaker_key" para usar una clave distinta al nombre mostrado (por
## ejemplo, si el mismo NPC aparece con el nombre repetido en muchas
## páginas y se prefiere una clave única y estable para el traductor).
func _translate_speaker(page: Dictionary) -> String:
	var raw : String = page.get("speaker", "")
	if raw == "":
		return ""
	var key : String = page.get("speaker_key", raw)
	return _translate_with_key(raw, key)


## Traduce la opción de choice en el índice global "i" del array "opts".
## Soporta la clave opcional de página "choice_keys" (Array[String], en el
## mismo orden que "choices") para usar claves de traducción distintas del
## texto de la opción tal como fue escrito. Si "choice_keys" no está
## definida, o es más corta que "opts", se usa el propio texto de la opción
## como clave (comportamiento por defecto, igual a _tr()).
func _translate_choice(opts: Array, i: int) -> String:
	var raw : String = opts[i]
	if not use_translations or raw == "":
		return raw
	var block : Array = _blocks[_current_block]
	var page          = block[_page_index]
	var keys  : Array = page.get("choice_keys", [])
	var key   : String = keys[i] if i < keys.size() else raw
	return _translate_with_key(raw, key)

# Mientras es true, se bloquea el scroll manual (rueda del mouse / drag de la
# scrollbar) sobre el cuadro de texto. Se activa al mostrar cada página nueva
# y se libera automáticamente recién cuando el texto terminó de tipearse Y el
# autoscroll alcanzó su posición objetivo (o no hace falta scroll en absoluto).
var _scroll_locked : bool = true


func _ready() -> void:
	panel.hide()
	choices_bg.hide()
	portrait_animated.hide()
	item_box.hide()
	if history_panel != null:
		history_panel.hide()
		_ensure_history_dim()
	if history_button != null:
		history_button.hide()
		history_button.pressed.connect(_toggle_history)

	# Registrar automáticamente las voces del catálogo asignado en el
	# editor (si se asignó alguno). Se pueden cargar catálogos adicionales
	# después en cualquier momento con load_voice_catalog(...).
	load_voice_catalog(voice_catalog)

	# Habilitar BBCode para soporte de colores y efectos de texto
	text_lbl.bbcode_enabled = true

	# Activar scroll interno (para el autoscroll de línea nueva) y clip
	# para que el contenido que sobra quede oculto en vez de desbordar el cuadro.
	text_lbl.scroll_active = true
	text_lbl.clip_contents = true

	# Registrar efectos de texto custom (BBCode: shake, wave, bouncein, typewave)
	text_lbl.install_effect(RTLShakeScript.new())
	text_lbl.install_effect(RTLWaveScript.new())
	text_lbl.install_effect(RTLBounceInScript.new())
	text_lbl.install_effect(RTLGlitchScript.new())
	text_lbl.install_effect(RTLRainbowScript.new())
	_typewave_effect = RTLTypeWaveScript.new()
	text_lbl.install_effect(_typewave_effect)

	# Capturar la fuente y tamaño del tema del nodo como predeterminados.
	if default_font == null:
		default_font = text_lbl.get_theme_font("normal_font")
	if default_font_size <= 0:
		default_font_size = 42
	# Asignar todos los SFX del diálogo al bus "SFX"
	for sfx in [beep_sfx, cursor_sfx, confirm_sfx]:
		if sfx != null:
			sfx.bus = "SFX"
	# Capturar el stream del nodo BeepSFX como predeterminado.
	if default_beep_stream == null and beep_sfx != null:
		default_beep_stream = beep_sfx.stream
	# Conectar cambio de resolución con call_deferred para evitar re-entradas.
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# Aplicar escala inicial diferida para que los nodos estén listos
	_sync_canvas_scale.call_deferred()



## Punto único y determinístico donde el scroll hace su "catch-up" final y
## se libera el bloqueo manual. Se llama siempre vía call_deferred, nunca de
## forma sincrónica justo después de asignar texto al RichTextLabel: Godot
## recalcula el VScrollBar (max_value/page) de forma perezosa, no en el mismo
## call que cambia .text, así que leerlo inmediatamente da valores viejos.
## Esperar al próximo frame idle (call_deferred) garantiza que el catch-up
## salte a la posición real y que el desbloqueo no dependa de comparar contra
## una métrica desactualizada (lo que podía dejar el scroll bloqueado para
## siempre si esa comparación nunca llegaba a coincidir).
func _finish_scroll_catchup() -> void:
	_update_autoscroll(0.0, true)
	_set_scroll_locked(false)


## Activa o libera el bloqueo de scroll manual sobre el cuadro de texto.
## Se implementa cambiando el mouse_filter del RichTextLabel y de su
## VScrollBar interna: con MOUSE_FILTER_IGNORE dejan de recibir eventos de
## mouse (rueda / arrastre de la barra), por lo que el usuario no puede
## desplazar el texto mientras está bloqueado. El autoscroll programático
## (que mueve vscroll.value directamente por código) sigue funcionando
## igual, ya que no depende de eventos de input.
func _set_scroll_locked(locked: bool) -> void:
	if _scroll_locked == locked:
		return
	_scroll_locked = locked
	var mf : int = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	text_lbl.mouse_filter = mf
	var vscroll : VScrollBar = text_lbl.get_v_scroll_bar()
	if vscroll != null:
		vscroll.mouse_filter = mf


## Último tamaño de viewport procesado — evita recalcular si no cambió.
var _last_vp_size : Vector2 = Vector2.ZERO

## Llamado cuando la ventana cambia de tamaño. Usa call_deferred para que
## el layout de Godot termine su ciclo antes de que modifiquemos propiedades,
## evitando la recursión que crashea el editor.
func _on_viewport_size_changed() -> void:
	_sync_canvas_scale.call_deferred()

func _sync_canvas_scale() -> void:
	var win : Vector2 = get_viewport().get_visible_rect().size
	if win == _last_vp_size:
		return
	_last_vp_size        = win
	_last_applied_scale  = -1.0   # forzar recálculo aunque la escala sea la misma
	var s : float = min(win.x / 1920.0, win.y / 1080.0)
	_apply_scaled_props(s)


var _last_applied_scale : float = -1.0

func _apply_scaled_props(s: float) -> void:
	# Ignorar escala inválida — puede ocurrir durante la inicialización
	# cuando el viewport aún no tiene tamaño.
	s = clampf(s, 0.1, 10.0)

	# Evitar recalcular si la escala no cambió significativamente
	if abs(s - _last_applied_scale) < 0.001:
		return
	_last_applied_scale = s

	# ── Fuentes ───────────────────────────────────────────────────────
	var base_text : int = max(default_font_size, 42)
	var fs_text   : int = maxi(1, roundi(base_text * s))
	var fs_speak  : int = maxi(1, roundi(42 * s))
	text_lbl.add_theme_font_size_override("normal_font_size", fs_text)
	speaker.add_theme_font_size_override("font_size", fs_speak)
	# Forzar minimum size para que el RichTextLabel no colapse a tamaño 0
	text_lbl.custom_minimum_size = Vector2(0, maxi(1, roundi(TEXT_BOX_BASE_HEIGHT * s)))

	# ── Espaciado entre líneas ──────────────────────────────────────────
	if _current_line_spacing > 0:
		text_lbl.add_theme_constant_override("line_separation", maxi(0, roundi(_current_line_spacing * s)))
	else:
		text_lbl.remove_theme_constant_override("line_separation")

	# ── Fuentes de opciones (si están visibles) ───────────────────────
	if choices_bg.visible:
		var choice_fs : int = maxi(1, roundi(29 * s))
		for lbl in choices.get_children():
			if lbl is RichTextLabel:
				lbl.add_theme_font_size_override("normal_font_size", choice_fs)

	# ── Portrait animado ──────────────────────────────────────────────
	# Nada que hacer acá: portrait_animated es un TextureRect normal, así
	# que el HBoxContainer ya lo mide y escala solo con el mismo criterio
	# (expand_mode/stretch_mode/custom_minimum_size) que configuraste en el
	# editor para "portrait" — exactamente como funciona el retrato
	# estático, sin ningún cálculo manual de tamaño ni posición.


## Reproduce, a mano, la animación "anim_name" del SpriteFrames asignado
## en _anim_sprite_frames sobre portrait_animated (un TextureRect). No usa
## AnimatedSprite2D.play() porque portrait_animated no es un
## AnimatedSprite2D — ver el comentario junto a su declaración @onready.
func _anim_play(anim_name: String) -> void:
	if _anim_sprite_frames == null or not _anim_sprite_frames.has_animation(anim_name):
		return
	_anim_current_name  = anim_name
	_anim_current_frame = 0
	_anim_frame_timer   = 0.0
	_anim_playing       = true
	_anim_update_texture()


## Detiene la reproducción manual (no borra la textura actual, para que el
## último frame mostrado quede congelado en pantalla, igual que
## AnimatedSprite2D.stop()).
func _anim_stop() -> void:
	_anim_playing = false


## Avanza, si corresponde, el frame de la animación actual según su
## velocidad (fps) y la duración individual de cada frame definida en el
## SpriteFrames, respetando el loop de esa animación. Se llama una vez por
## frame desde _process().
func _anim_process(delta: float) -> void:
	if not _anim_playing or _anim_sprite_frames == null or _anim_current_name == "":
		return
	if not _anim_sprite_frames.has_animation(_anim_current_name):
		return

	var frame_count : int = _anim_sprite_frames.get_frame_count(_anim_current_name)
	if frame_count <= 1:
		return

	var fps : float = _anim_sprite_frames.get_animation_speed(_anim_current_name)
	if fps <= 0.0:
		return

	_anim_frame_timer += delta * fps
	var frame_duration : float = _anim_sprite_frames.get_frame_duration(_anim_current_name, _anim_current_frame)
	if frame_duration <= 0.0:
		frame_duration = 1.0

	var advanced : bool = false
	while _anim_frame_timer >= frame_duration:
		_anim_frame_timer -= frame_duration
		_anim_current_frame += 1
		advanced = true
		if _anim_current_frame >= frame_count:
			if _anim_sprite_frames.get_animation_loop(_anim_current_name):
				_anim_current_frame = 0
			else:
				_anim_current_frame = frame_count - 1
				_anim_playing = false
				break
		frame_duration = _anim_sprite_frames.get_frame_duration(_anim_current_name, _anim_current_frame)
		if frame_duration <= 0.0:
			frame_duration = 1.0

	if advanced:
		_anim_update_texture()


## Asigna al TextureRect la textura del frame actual de la animación
## actual. Se llama al arrancar una animación (_anim_play) y cada vez que
## _anim_process avanza de frame.
func _anim_update_texture() -> void:
	if _anim_sprite_frames == null or _anim_current_name == "":
		return
	if not _anim_sprite_frames.has_animation(_anim_current_name):
		return
	portrait_animated.texture = _anim_sprite_frames.get_frame_texture(_anim_current_name, _anim_current_frame)


# ══════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════

# Reproduce una pista de música mientras el diálogo esté abierto y restaura
# la música anterior al cerrarse. Asigna antes de llamar start():
#   DialogBox.dialog_music = preload("res://music/tema_dialogo.ogg")
# null = no cambia la música.
var dialog_music        : AudioStream = null
var _prev_music_stream  : AudioStream = null
var _prev_music_pos     : float       = 0.0
var _music_player       : AudioStreamPlayer = null  # se asigna en start()

func start(bloques: Dictionary, bloque_inicial: String,
		   release_player_on_close: bool = true,
		   music_player: AudioStreamPlayer = null) -> void:
	_blocks                  = bloques
	_release_player_on_close = release_player_on_close
	_in_choices              = false
	_choice_index            = 0
	_choice_page             = 0
	_typing                  = false
	_waiting                 = false
	_in_history              = false
	# El historial se reinicia en cada ejecución del cuadro de diálogo: solo
	# guarda lo visto durante ESTA llamada a start(), no entre diálogos.
	_history.clear()
	if history_panel != null:
		history_panel.hide()
	panel.show()
	if history_button != null:
		history_button.show()
	Globals.playerStay = true
	# Forzar rescalado al abrir por si la resolución cambió mientras estaba cerrado
	_last_vp_size       = Vector2.ZERO
	_last_applied_scale = -1.0
	_sync_canvas_scale()

	# Música de diálogo
	_music_player = music_player
	if dialog_music != null and _music_player != null:
		_prev_music_stream = _music_player.stream
		_prev_music_pos    = _music_player.get_playback_position()
		_music_player.stream = dialog_music
		_music_player.play()

	_jump_to_block(bloque_inicial)


## Vuelve a renderizar la página actual, re-evaluando todas las traducciones
## (speaker, texto, choices visibles). Pensado para el caso poco común de
## que el jugador cambie el idioma del juego (TranslationServer.set_locale)
## mientras el diálogo sigue abierto: por defecto la traducción solo se
## resuelve una vez, al mostrar cada página, así que sin esta llamada el
## texto ya mostrado no se actualizaría solo. Nota: esto reinicia el efecto
## de tipeo de la página actual desde cero (vuelve a llamar _show_page).
func refresh_translations() -> void:
	if panel.visible:
		_show_page(_page_index)


## Registra todas las voces de un catálogo (recurso VoiceCatalog) de una
## sola vez. Se puede llamar varias veces con distintos catálogos (por
## ejemplo, uno por zona/capítulo del juego); las voces se van sumando al
## diccionario interno, y un "voice_name" repetido simplemente sobreescribe
## el preset anterior con ese nombre. No hace nada si "catalog" es null o
## no tiene ninguna voz cargada.
func load_voice_catalog(catalog: VoiceCatalog) -> void:
	if catalog == null:
		return
	for preset in catalog.voices:
		if preset != null and preset.voice_name != "":
			register_voice(preset.voice_name, preset.to_dict())


## Registra (o sobreescribe) un preset de "voz" con nombre. "preset" puede
## incluir cualquiera de estas claves, todas opcionales: "font" (Font),
## "font_size" (int), "type_speed" (float, caracteres/seg) y "beep_stream"
## (AudioStream, o null para silenciar el typing de ese personaje).
## Se puede llamar en cualquier momento (típicamente al arrancar el juego,
## una vez por personaje), incluso antes del primer start().
func register_voice(voice_name: String, preset: Dictionary) -> void:
	_voice_presets[voice_name] = preset


## Registra varios presets de voz de una sola vez. "presets" es un
## Dictionary de { nombre_de_voz: Dictionary_con_el_preset }.
func register_voices(presets: Dictionary) -> void:
	for key in presets.keys():
		_voice_presets[key] = presets[key]


## Quita un preset de voz previamente registrado. No falla si no existía.
func unregister_voice(voice_name: String) -> void:
	_voice_presets.erase(voice_name)


## Devuelve una copia del preset registrado bajo ese nombre, o un
## Dictionary vacío si no existe ninguno con ese nombre.
func get_voice(voice_name: String) -> Dictionary:
	return _voice_presets.get(voice_name, {}).duplicate(true)


## Muestra/oculta el gráfico del windowskin (fondo+borde+cursor) por
## código, en cualquier momento — no hace falta que sea parte de una
## página del script de diálogo. No falla si Box todavía no usa este
## sistema (windowskin_bg == null).
func set_windowskin_visible(value: bool) -> void:
	if windowskin_bg != null:
		windowskin_bg.visible = value


## Consulta el estado actual. Devuelve true también si Box no usa
## windowskin (nada que ocultar = "visible" por convención).
func is_windowskin_visible() -> bool:
	return windowskin_bg == null or windowskin_bg.visible


## Resuelve el valor efectivo de una propiedad "de voz" (font, font_size,
## type_speed, beep_stream) para la página actual, con esta prioridad:
##   1. Valor explícito definido en la propia página (page[key]).
##   2. Valor definido en el preset de voz de la página ("voice"), si
##      la página define esa clave y el preset la tiene.
##   3. "fallback_value", el default global del cuadro de diálogo.
## Nota: se usa page.has(key) (no page.get(key, null)) para que un valor
## explícito "null" en la página (p. ej. "beep_stream": null para
## silenciar el typing) cuente como definido y no caiga al preset/default.
func _resolve_voice_value(page: Dictionary, key: String, fallback_value):
	if page.has(key):
		return page[key]
	var voice_name : String = page.get("voice", "")
	if voice_name != "" and _voice_presets.has(voice_name):
		var preset : Dictionary = _voice_presets[voice_name]
		if preset.has(key):
			return preset[key]
	return fallback_value


# ══════════════════════════════════════════════════════════════════════
# NAVEGACIÓN ENTRE BLOQUES
# ══════════════════════════════════════════════════════════════════════

func _jump_to_block(block_name: String) -> void:
	if block_name == "":
		_close()
		return

	if not _blocks.has(block_name):
		push_error("[DialogBox] Bloque no encontrado: '%s'" % block_name)
		_close()
		return

	_current_block = block_name
	_page_index    = 0
	_choice_page   = 0
	emit_signal("block_changed", block_name)
	_show_page(0)


# ══════════════════════════════════════════════════════════════════════
# MOSTRAR PÁGINA
# ══════════════════════════════════════════════════════════════════════

func _show_page(index: int) -> void:
	var block : Array = _blocks[_current_block]

	if index >= block.size():
		_close()
		return

	var page = block[index]

	# Posición dinámica del panel
	if page.has("position"):
		var vp : Vector2 = get_viewport().get_visible_rect().size
		match page["position"]:
			"top":
				panel.position = Vector2(panel.position.x, vp.y * 0.05)
			"center":
				panel.position = Vector2(panel.position.x, vp.y * 0.5 - panel.size.y * 0.5)
			"bottom":
				panel.position = Vector2(panel.position.x, vp.y * 0.85)

	# Mostrar/ocultar el gráfico del windowskin (fondo+borde+cursor) para
	# esta página en particular. Por defecto siempre visible; el script de
	# diálogo puede pedir "windowskin_visible": false para un texto sin
	# panel de fondo (por ejemplo, narración flotante sobre la escena).
	if windowskin_bg != null:
		windowskin_bg.visible = page.get("windowskin_visible", true)

	# Portrait — soporta tres modos según el valor de "portrait":
	#   • Texture2D    → imagen estática (TextureRect)
	#   • SpriteFrames → animado, con soporte de animaciones por estado:
	#       "portrait_anim_typing" : animación mientras se escribe el texto
	#       "portrait_anim_idle"   : animación al terminar de escribir
	#       "portrait_anim"        : fallback si no se definen typing/idle
	#     ...o, si se definió "portrait_emotions", esas claves planas pasan
	#     a ser el fallback de la emoción "portrait_emotion" (ver arriba).
	#   • null / ausente → oculta ambos nodos
	_portrait_anim_typing  = ""
	_portrait_anim_idle    = ""
	_portrait_emotions     = page.get("portrait_emotions", {})
	_portrait_base_emotion = page.get("portrait_emotion", "default")
	_current_face_applied  = _portrait_base_emotion

	var portrait_value = page.get("portrait", null)
	var portrait_flip  : bool = page.get("portrait_flip_h", false)

	if portrait_value is SpriteFrames:
		portrait.hide()
		_anim_sprite_frames     = portrait_value
		portrait_animated.flip_h = portrait_flip

		# Resolver nombres de animación con fallbacks en cascada
		var fallback : String = page.get("portrait_anim", "")
		if fallback == "" or not portrait_value.has_animation(fallback):
			fallback = portrait_value.get_animation_names()[0]

		var anim_typing : String = _resolve_face_anim("talk", _portrait_base_emotion, portrait_value, page, fallback)
		var anim_idle   : String = _resolve_face_anim("idle", _portrait_base_emotion, portrait_value, page, fallback)

		_portrait_anim_typing = anim_typing
		_portrait_anim_idle   = anim_idle

		# Arrancar con la animación de typing
		_anim_play(_portrait_anim_typing)
		portrait_animated.show()
	elif portrait_value is Texture2D:
		_anim_stop()
		portrait_animated.hide()
		portrait.texture  = portrait_value
		portrait.flip_h   = portrait_flip
		portrait.show()
	else:
		portrait.hide()
		_anim_stop()
		portrait_animated.hide()

	# Lado del portrait — "portrait_side": "left" (default) o "right"
	# Mueve tanto el TextureRect estático como el TextureRect animado al
	# índice correcto del HBoxContainer. Ambos son Control, así que el
	# HBoxContainer los reordena y les asigna un rect real de verdad,
	# empujando al VBoxContainer del texto en consecuencia — exactamente
	# el mismo mecanismo que ya usaba "portrait", sin ningún cálculo manual
	# de posición en píxeles.
	var portrait_side : String = page.get("portrait_side", "left")
	var portrait_index : int   = 0 if portrait_side == "left" else hbox.get_child_count() - 1
	hbox.move_child(portrait,          portrait_index)
	hbox.move_child(portrait_animated, portrait_index)

	# Cuadro de item sobre el textbox
	# Clave: "item_texture" (Texture2D). Si no está presente el cuadro se oculta.
	var item_tex : Texture2D = page.get("item_texture", null)

	if item_tex != null:
		item_icon.texture = item_tex
		item_box.show()
	else:
		item_box.hide()

	# Speaker
	speaker.text    = _translate_speaker(page)
	speaker.visible = speaker.text != ""

	# Fuente dinámica por página — solo la familia de fuente, el tamaño
	# lo gestiona _apply_scaled_props para respetar la escala de resolución.
	# Prioridad: página > preset de "voice" > default_font (ver _resolve_voice_value).
	var page_font : Font = _resolve_voice_value(page, "font", default_font)
	if page_font != null:
		text_lbl.add_theme_font_override("normal_font", page_font)
	else:
		text_lbl.remove_theme_font_override("normal_font")

	# Si la página (o su preset de voz) define un tamaño de fuente
	# explícito, guardarlo para que _apply_scaled_props lo use escalado.
	var page_font_size : int = _resolve_voice_value(page, "font_size", 0)
	if page_font_size > 0:
		default_font_size = page_font_size
	else:
		default_font_size = 42

	# Audio de typing por página. Acepta "beep_stream" (AudioStream o null)
	# en la página o en su preset de voz; null = sin sonido para esta
	# página. Si ninguno de los dos define la clave, usa default_beep_stream.
	_current_beep_stream = _resolve_voice_value(page, "beep_stream", default_beep_stream)

	# Alineación de texto por página
	# Acepta "text_alignment" (HorizontalAlignment). Si no se define usa default_text_alignment.
	text_lbl.horizontal_alignment = page.get("text_alignment", default_text_alignment)

	# Espaciado entre líneas por página. Acepta "line_spacing" (int, píxeles a
	# resolución base). Si no se define usa default_line_spacing.
	_current_line_spacing = page.get("line_spacing", default_line_spacing)

	# Velocidad de tipeo de esta página (caracteres por segundo). Prioridad:
	# página > preset de "voice" > default_chars_per_second. Valores <= 0
	# se ignoran (velocidad inválida/infinita), cayendo al default.
	var page_speed : float = _resolve_voice_value(page, "type_speed", default_chars_per_second)
	_current_chars_per_second = page_speed if page_speed > 0.0 else default_chars_per_second

	# Texto de la página. Ya NO se recorta por líneas (MAX_LINES_PER_PAGE):
	# ahora el overflow dentro de una misma página se resuelve con el
	# autoscroll de línea nueva (_update_autoscroll), estilo Cave Story / Pokémon.
	# "text_page" se mantiene por compatibilidad para textos que el propio
	# autor quiera cortar manualmente en distintas entradas del array del bloque.
	# La traducción (y la interpolación de "text_args", si se definieron) se
	# aplica sobre el texto COMPLETO de la página, antes de cortar por
	# "text_page" — traducir un fragmento ya cortado rompería la búsqueda de
	# la clave y el formateo de argumentos.
	var raw_text : String = _translate_page_text(page)
	if page.has("text_page"):
		raw_text = _get_text_page(raw_text, page.get("text_page", 0))

	# Extraer las etiquetas custom [speed=N]...[/speed] del texto. NO son
	# BBCode real (el RichTextLabel no las reconoce, así que si las
	# dejáramos se verían literalmente como texto) — se sacan del texto
	# que se muestra, y se guarda aparte en qué rango de posiciones
	# "planas" (ignorando el resto del BBCode, mismo criterio que
	# _get_plain_length/_bbcode_substr) aplica cada velocidad custom.
	var extracted : Dictionary = _extract_speed_ranges(raw_text)
	raw_text      = extracted["text"]
	_speed_ranges = extracted["ranges"]

	# Igual que con [speed=N], pero para [face=NOMBRE]...[/face]: le indica
	# al retrato animado que cambie de emoción SOLO mientras se tipea la
	# palabra/tramo envuelto, y encadenado sobre el texto YA sin los tags
	# de [speed], para que los índices de ambos sistemas queden
	# consistentes entre sí (ninguno de los dos tags es BBCode real, así
	# que ambos se sacan del texto final).
	var extracted_face : Dictionary = _extract_face_ranges(raw_text)
	raw_text     = extracted_face["text"]
	_face_ranges = extracted_face["ranges"]

	_full_text = raw_text

	# Registrar esta página en el historial de diálogo, con el texto ya
	# completo y traducido (sin el padding de valineación que se agrega
	# recién abajo, y sin esperar a que termine el efecto de tipeo: la
	# página ya está "vista" en cuanto se muestra, se la tipee entera o se
	# la saltee con Accept).
	_record_history_entry(speaker.text, raw_text)

	# Aplicar valineación solo si el contenido cabe sin necesitar scroll
	# (si hace falta scroll, el autoscroll ya deja el texto pegado abajo).
	var text_before_valign : String = _full_text
	_full_text = _apply_valignment_if_fits(_full_text, page.get("text_valignment", default_text_valignment))

	# La valineación puede agregar "\n" al principio (padding). Como los
	# rangos de _speed_ranges se calcularon sobre el texto SIN ese
	# padding, hay que correrlos la misma cantidad de caracteres, o
	# quedarían aplicados a las letras equivocadas.
	var padding_len : int = _full_text.length() - text_before_valign.length()
	if padding_len > 0 and _speed_ranges.size() > 0:
		for i in _speed_ranges.size():
			_speed_ranges[i]["start"] += padding_len
			_speed_ranges[i]["end"]   += padding_len
	if padding_len > 0 and _face_ranges.size() > 0:
		for i in _face_ranges.size():
			_face_ranges[i]["start"] += padding_len
			_face_ranges[i]["end"]   += padding_len

	_chars_shown  = 0
	_timer        = 0.0
	_typing       = true
	_waiting      = false
	_in_choices   = false
	_beep_counter = 0

	# El auto-avance se reactiva recién en _on_end() si la página lo pide;
	# acá se resetea para que no quede arrastrado de la página anterior.
	_auto_advance_active = false
	_auto_advance_timer  = 0.0

	# Bloquear el scroll manual al iniciar la página: se libera recién cuando
	# el texto termine de tipearse y el autoscroll alcance su posición final.
	_set_scroll_locked(true)

	# Reiniciar estado del efecto typewave para esta página
	if _typewave_effect != null:
		_typewave_effect.reveal_times.clear()
		_typewave_effect.current_time = Time.get_ticks_msec() / 1000.0

	text_lbl.bbcode_enabled = true
	# IMPORTANTE: el label empieza vacío y se va llenando progresivamente en
	# _tick() según se revelan caracteres. Así el alto real del contenido
	# (y por lo tanto el scroll) solo crece cuando el texto ya escrito lo
	# necesita, en vez de calcularse de una vez con el párrafo completo.
	text_lbl.text = ""
	text_lbl.show()

	# Reiniciar scroll al tope de la página nueva
	text_lbl.scroll_to_line(0)
	var vscroll_reset : VScrollBar = text_lbl.get_v_scroll_bar()
	if vscroll_reset != null:
		vscroll_reset.value = 0.0

	# Bloquear el scroll manual: se libera recién cuando el texto termine
	# de tipearse Y el autoscroll haya alcanzado su posición objetivo.
	_set_scroll_locked(true)

	# Forzar aplicación de escala para la página actual (incluye el
	# line_separation, que depende de _current_line_spacing recién asignado).
	# Se llama _apply_scaled_props() directamente en vez de _sync_canvas_scale(),
	# porque esta última se salta el recálculo si el tamaño de ventana no
	# cambió desde la página anterior — y el espaciado sí puede haber cambiado
	# aunque la ventana siga igual.
	var vp_size : Vector2 = get_viewport().get_visible_rect().size
	var scale_s : float   = min(vp_size.x / 1920.0, vp_size.y / 1080.0)
	_last_applied_scale = -1.0   # forzar que _apply_scaled_props no corte por "sin cambios"
	_apply_scaled_props(scale_s)
	arrow.hide()
	choices.hide()
	choices_bg.hide()
	_clear_choices()


# ══════════════════════════════════════════════════════════════════════
# PAGINACIÓN DE TEXTO (uso opcional vía "text_page")
# Nota: la paginación opera sobre el texto plano (sin tags BBCode) para
# calcular líneas correctamente, pero conserva los tags en el resultado.
# ══════════════════════════════════════════════════════════════════════

func _get_text_page(full: String, sub_page: int) -> String:
	# Trabajamos con el texto plano para calcular el ajuste de líneas,
	# pero devolvemos el texto BBCode original recortado por líneas.
	var plain  : String = _strip_bbcode(full)
	var words          := plain.split(" ")
	var lines  : Array[String] = []
	var current: String = ""

	for word in words:
		var parts := word.split("\n")
		for p in range(parts.size()):
			var w : String = parts[p]
			if current == "":
				current = w
			elif current.length() + 1 + w.length() <= MAX_CHARS_PER_LINE:
				current += " " + w
			else:
				lines.append(current)
				current = w
			if p < parts.size() - 1:
				lines.append(current)
				current = ""

	if current != "":
		lines.append(current)

	# Calcular cuántos caracteres planos corresponden al rango de líneas
	var start      : int = sub_page * MAX_LINES_PER_PAGE
	var end_line   : int = mini(start + MAX_LINES_PER_PAGE, lines.size())

	if start >= lines.size():
		return ""

	# Contar caracteres planos hasta el inicio y fin de la página
	var plain_start : int = 0
	var plain_end   : int = 0
	var char_count  : int = 0

	for i in lines.size():
		if i == start:
			plain_start = char_count
		char_count += lines[i].length()
		if i < lines.size() - 1:
			char_count += 1  # espacio o \n entre líneas
		if i == end_line - 1:
			plain_end = char_count
			break

	# Extraer el trozo equivalente del texto BBCode original
	return _bbcode_substr(full, plain_start, plain_end - plain_start)


# ══════════════════════════════════════════════════════════════════════
# PROCESS
# ══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	# Seguimos procesando si el panel principal está visible, O si estamos
	# con el historial abierto (que oculta "panel" a propósito mientras
	# dura). Si solo chequeáramos panel.visible, abrir el historial dejaría
	# _process() sin ejecutarse nunca más — incluida la detección de la
	# tecla/acción para cerrarlo — dejando el diálogo en un softlock
	# permanente con "panel" oculto para siempre.
	if not panel.visible and not _in_history:
		return

	# Mantener el reloj del efecto typewave corriendo siempre que el
	# panel esté visible, incluso si no se está agregando texto nuevo
	# este frame (para que el decay de la animación no se congele).
	if _typewave_effect != null:
		_typewave_effect.current_time = Time.get_ticks_msec() / 1000.0

	# Avanzar la animación manual del retrato (ver _anim_process). Se llama
	# siempre que _process sigue corriendo (panel visible o historial
	# abierto), igual criterio que el resto de la lógica de arriba.
	_anim_process(delta)

	# Autoscroll progresivo: SOLO se actualiza mientras el scroll sigue
	# bloqueado (es decir, mientras se está tipeando). Si se llamara siempre,
	# cada frame arrastraría el scroll de vuelta hacia abajo y el jugador
	# nunca podría desplazarse manualmente hacia arriba una vez liberado.
	if _scroll_locked:
		_update_autoscroll(delta)

	# Desplazamiento manual con Up/Down una vez que el texto ya terminó de
	# tipearse y el scroll quedó liberado (la rueda del mouse ya funciona
	# sola gracias al mouse_filter = STOP que deja _set_scroll_locked(false)).
	if not _scroll_locked and _waiting and not _in_history:
		_handle_manual_scroll(delta)

	# Historial de diálogo: se puede abrir/cerrar en cualquier momento
	# (tipeando, esperando Accept, o incluso con choices abiertas), y
	# mientras esté abierto pausa el resto de la lógica de diálogo.
	if Input.is_action_just_pressed(history_action_name):
		_toggle_history()

	if _in_history:
		_handle_history_scroll(delta)
		return

	if _in_choices:
		_handle_choices()
		return

	if _typing:
		_tick(delta)
		if Input.is_action_just_pressed("Accept"):
			_skip()
		return

	if _waiting:
		# Auto-avance: si la página lo pidió (ver _on_end), cuenta regresiva
		# hasta pasar sola a la siguiente página, sin esperar a que el
		# jugador presione Accept. Presionar Accept igual adelanta de
		# inmediato, sin esperar a que el timer termine.
		if _auto_advance_active:
			_auto_advance_timer -= delta
			if _auto_advance_timer <= 0.0:
				_auto_advance_active = false
				_advance()
				return

		if Input.is_action_just_pressed("Accept"):
			_auto_advance_active = false
			_advance()


func _tick(delta: float) -> void:
	_timer += delta

	var plain_len : int = _get_plain_length(_full_text)
	var now       : float = Time.get_ticks_msec() / 1000.0
	var revealed_any : bool = false

	# En vez de calcular un lote fijo de caracteres por frame con una
	# única velocidad global ("add = timer * speed"), se revela de a un
	# caracter por vez, cada uno consumiendo su propio costo en segundos
	# (1 / velocidad_de_ese_caracter) del acumulador _timer. Esto es lo
	# que permite que un rango marcado con [speed=N] tipee más rápido o
	# más lento que el resto de la misma página, sin afectar al resto del
	# texto. Con una sola velocidad para toda la página, el resultado es
	# matemáticamente equivalente al esquema anterior (mismo frame-rate
	# independence), así que no cambia el comportamiento por defecto.
	while _chars_shown < plain_len:
		var speed : float = _get_speed_for_index(_chars_shown)
		if speed <= 0.0:
			speed = _current_chars_per_second
		var cost : float = 1.0 / speed
		if _timer < cost:
			break
		_timer -= cost

		var ch : String = _get_plain_char(_full_text, _chars_shown)
		# Registrar el momento exacto en que este caracter se reveló,
		# usado por el efecto [typewave] para animar solo letras recién escritas.
		if _typewave_effect != null:
			_typewave_effect.reveal_times[_chars_shown] = now
		_chars_shown += 1
		revealed_any = true

		# Reflejar en el retrato animado la emoción marcada con
		# [face=NOMBRE] (si la hay) para el caracter recién revelado —
		# se resuelve por caracter (no una vez por _tick) para que el
		# cambio de cara ocurra justo cuando arranca la palabra marcada,
		# incluso si varios caracteres se revelan en el mismo frame.
		_apply_word_face(_get_face_for_index(_chars_shown - 1))

		if ch not in SKIP_CHARS:
			_beep_counter += 1
			if _beep_counter >= BEEP_EVERY:
				_beep_counter = 0
				if beep_sfx and _current_beep_stream != null and not beep_sfx.playing:
					beep_sfx.stream = _current_beep_stream
					beep_sfx.play()

	# Revelar el texto de forma progresiva REAL (no solo visualmente con
	# visible_ratio): así el RichTextLabel solo calcula el alto del contenido
	# ya escrito, y el scroll únicamente reacciona cuando una línea nueva
	# efectivamente se sale del cuadro — no desde el primer frame de la página.
	if revealed_any:
		text_lbl.text = _bbcode_substr(_full_text, 0, _chars_shown)

	if _chars_shown >= plain_len:
		_typing       = false
		_waiting      = true
		_beep_counter = 0
		_portrait_play_idle()
		# Diferido: recién en el próximo frame idle el RichTextLabel habrá
		# recalculado su VScrollBar (max_value/page) para el texto completo
		# que se acaba de asignar arriba. Si hiciéramos el catch-up y el
		# desbloqueo de forma sincrónica aquí mismo, usarían valores viejos
		# de la barra de scroll (el recálculo de Godot no es inmediato al
		# cambiar .text), dejando el scroll mal posicionado o el bloqueo
		# colgado para siempre si la comparación nunca llega a coincidir.
		call_deferred("_finish_scroll_catchup")
		_on_end()


func _skip() -> void:
	_chars_shown  = _get_plain_length(_full_text)
	text_lbl.text = _full_text

	# Marcar todos los caracteres restantes como revelados "ahora" para
	# que el typewave no intente animar letras sin timestamp.
	if _typewave_effect != null:
		var now : float = Time.get_ticks_msec() / 1000.0
		for i in _chars_shown:
			if not _typewave_effect.reveal_times.has(i):
				_typewave_effect.reveal_times[i] = now

	_typing  = false
	_waiting = true
	_portrait_play_idle()
	# Igual que en el final normal del tipeo: diferir el catch-up hasta que
	# el RichTextLabel recalcule su VScrollBar con el texto completo recién
	# asignado. Hacerlo de forma sincrónica aquí usaría el max_value/page
	# viejos (previos al salto), dejando el texto sin scrollear del todo,
	# como si hubiera terminado de tipear normalmente sin necesitar catch-up.
	call_deferred("_finish_scroll_catchup")
	_on_end()


func _on_end() -> void:
	var block : Array = _blocks[_current_block]
	var page          = block[_page_index]

	# Ejecutar "action" de página si existe (sin choices)
	if page.has("action") and page["action"] is Callable:
		if page["action"].is_valid():
			page["action"].call()

	if page.get("choices", []).size() > 0:
		_choice_page = 0
		_show_choices(page["choices"])
	else:
		var is_auto : bool = page.get("auto_advance", false)
		if is_auto:
			_auto_advance_active = true
			_auto_advance_timer  = page.get("auto_advance_delay", default_auto_advance_delay)
			# La flecha de "continuar" normalmente le indica al jugador que
			# tiene que presionar Accept para seguir. En una página que va a
			# avanzar sola, mostrarla igual sería engañoso — por defecto se
			# oculta. Si de todos modos se la quiere visible (por ejemplo,
			# para reforzar que "algo va a pasar"), se puede forzar con la
			# clave opcional "auto_advance_show_arrow": true.
			if page.get("auto_advance_show_arrow", false):
				arrow.show()
			else:
				arrow.hide()
		else:
			arrow.show()


## Cambia el portrait animado a la animación idle si está activo. Al
## terminar de tipear, el retrato siempre vuelve a la emoción BASE de la
## página (nunca se queda "trabado" en la emoción de la última palabra
## marcada con [face=...] — ese tag solo afecta mientras esa palabra en
## particular se está tipeando).
func _portrait_play_idle() -> void:
	_current_face_applied = _portrait_base_emotion
	if portrait_animated.visible and _portrait_anim_idle != "":
		if _anim_current_name != _portrait_anim_idle:
			_anim_play(_portrait_anim_idle)


## Resuelve el nombre de animación a usar para una emoción + estado
## ("talk" o "idle") puntuales, con esta prioridad:
##   1. "portrait_emotions"[emotion][state], si la página definió ese
##      diccionario, esa emoción existe en él, y la animación existe de
##      verdad en el SpriteFrames del retrato.
##   2. El otro estado de esa MISMA emoción (talk<->idle), por si solo se
##      definió uno de los dos — mejor mostrar algo de esa emoción que
##      nada.
##   3. Las claves planas "legacy" ("portrait_anim_typing"/"_idle"), pero
##      SOLO si "emotion" es la emoción base de la página (no tendría
##      sentido que una palabra con [face=triste] cayera en la animación
##      de typing genérica de la página en vez de directamente al
##      fallback general).
##   4. "fallback_anim" (el fallback general ya resuelto en _show_page,
##      típicamente "portrait_anim" o la primera animación del SpriteFrames).
func _resolve_face_anim(state: String, emotion: String, sprite_frames: SpriteFrames, page: Dictionary, fallback_anim: String) -> String:
	var emotions : Dictionary = page.get("portrait_emotions", {})

	if emotions.has(emotion):
		var entry : Dictionary = emotions[emotion]
		if entry.has(state) and sprite_frames.has_animation(entry[state]):
			return entry[state]
		var other_state : String = "idle" if state == "talk" else "talk"
		if entry.has(other_state) and sprite_frames.has_animation(entry[other_state]):
			return entry[other_state]

	if emotion == _portrait_base_emotion or emotion == "":
		var legacy_key  : String = "portrait_anim_typing" if state == "talk" else "portrait_anim_idle"
		var legacy_anim : String = page.get(legacy_key, "")
		if legacy_anim != "" and sprite_frames.has_animation(legacy_anim):
			return legacy_anim

	return fallback_anim


## Aplica, si corresponde, la animación de "talk" de una emoción puntual
## sobre el retrato animado — usado por _tick() para reflejar los tags
## [face=NOMBRE] a medida que se van tipeando. No hace nada si el retrato
## actual no es animado, o si "emotion" ya es la que está aplicada (evita
## reiniciar la animación en cada frame sin necesidad).
func _apply_word_face(emotion: String) -> void:
	if not portrait_animated.visible:
		return
	if emotion == _current_face_applied:
		return

	var block : Array      = _blocks[_current_block]
	var page  : Dictionary = block[_page_index]
	var sprite_frames : SpriteFrames = _anim_sprite_frames
	if sprite_frames == null:
		return

	var anim : String = _resolve_face_anim("talk", emotion, sprite_frames, page, _portrait_anim_typing)
	_current_face_applied = emotion
	if anim != "" and _anim_current_name != anim:
		_anim_play(anim)


## Devuelve el nombre de la emoción que corresponde al caracter plano en
## la posición "idx" de _full_text, según _face_ranges. Si "idx" no cae
## dentro de ningún [face=...] activo, devuelve _portrait_base_emotion
## (la emoción normal de la página).
func _get_face_for_index(idx: int) -> String:
	for r in _face_ranges:
		if idx >= r["start"] and idx < r["end"]:
			return r["face"]
	return _portrait_base_emotion


func _advance() -> void:
	_waiting = false

	# Si la página actual define "target_block", se salta a ese bloque en
	# vez de simplemente pasar a la página siguiente del bloque actual.
	# Esto aplica tanto al avance manual (Accept) como al auto_advance —
	# es lo que permite indicarle a una página auto_advance a qué bloque
	# debe saltar sola, no solo que "salte automáticamente".
	var block  : Array      = _blocks[_current_block]
	var page   : Dictionary = block[_page_index]
	var target : String     = page.get("target_block", "")

	if target != "":
		_jump_to_block(target)
	else:
		_page_index += 1
		_show_page(_page_index)


func _close() -> void:
	panel.hide()
	choices_bg.hide()
	item_box.hide()
	if history_button != null:
		history_button.hide()
	if _in_history:
		_close_history()
	# Restaurar música anterior al cerrar el diálogo
	if dialog_music != null and _music_player != null and _prev_music_stream != null:
		_music_player.stream = _prev_music_stream
		_music_player.play(_prev_music_pos)
		_prev_music_stream = null
	if _release_player_on_close:
		Globals.playerStay = false
	emit_signal("dialog_finished")


# ══════════════════════════════════════════════════════════════════════
# AUTOSCROLL DE LÍNEA NUEVA (Cave Story / Pokémon style)
# Cuando el texto ya escrito no cabe en el alto del cuadro, desplaza el
# scroll interno del RichTextLabel para "subir" el párrafo y dejar ver la
# línea nueva, dentro de la misma página (sin pasar a la siguiente).
# ══════════════════════════════════════════════════════════════════════

## Desplaza manualmente el scroll del cuadro de texto usando las acciones
## Up/Down, mientras el texto ya terminó de tipearse y el bloqueo de scroll
## fue liberado (ver _set_scroll_locked). Se mueve de forma continua
## (píxeles por segundo) mientras la acción se mantenga presionada, y se
## clampa entre 0 y el máximo desplazable para no salirse del contenido.
## La rueda del mouse no necesita código propio: al liberar el bloqueo,
## _set_scroll_locked() deja mouse_filter = STOP, que reactiva el scroll
## por rueda nativo del RichTextLabel.
func _handle_manual_scroll(delta: float) -> void:
	var vscroll : VScrollBar = text_lbl.get_v_scroll_bar()
	if vscroll == null or vscroll.max_value <= vscroll.page:
		return

	var dir : float = 0.0
	if Input.is_action_pressed("Up"):
		dir -= 1.0
	if Input.is_action_pressed("Down"):
		dir += 1.0
	if dir == 0.0:
		return

	var max_scroll : float = vscroll.max_value - vscroll.page
	vscroll.value = clampf(vscroll.value + dir * manual_scroll_speed * delta, 0.0, max_scroll)


## Duración de la animación de scroll al aparecer una línea nueva.
## Duración/velocidad de suavizado del scroll. No es un tiempo fijo:
## cada frame el scroll avanza una fracción de la distancia restante hacia
## el objetivo, proporcional a autoscroll_speed * delta, dando un desplazamiento
## progresivo y continuo (no un salto instantáneo ni pasos discretos por línea).
func _update_autoscroll(delta: float, instant: bool = false) -> void:
	var vscroll : VScrollBar = text_lbl.get_v_scroll_bar()
	if vscroll == null:
		return

	# Si todo el contenido entra en el cuadro, no hay nada que scrollear.
	if vscroll.max_value <= vscroll.page:
		return

	var target : float = vscroll.max_value - vscroll.page

	if instant:
		vscroll.value = target
		return

	if is_equal_approx(vscroll.value, target):
		return

	# Interpolación exponencial (frame-rate independiente): converge suave
	# y progresivamente hacia el objetivo a medida que el texto va creciendo.
	var weight : float = 1.0 - exp(-autoscroll_speed * delta)
	vscroll.value = lerp(vscroll.value, target, weight)


## Aplica padding vertical (para centrar/alinear abajo) SOLO si el contenido
## entra sin necesidad de scroll. Si hace falta scroll, el autoscroll ya deja
## el texto pegado al fondo del cuadro, así que el padding no es necesario
## y solo desperdiciaría espacio.
func _apply_valignment_if_fits(text: String, valign: VerticalAlignment) -> String:
	if valign == VERTICAL_ALIGNMENT_TOP:
		return text

	# Medir cuántas líneas del texto (ya con wrap automático) caben visualmente
	# es costoso de saber antes de asignar el texto al label; usamos el conteo
	# de líneas explícitas ("\n") como aproximación igual que el sistema original.
	var line_count  : int = text.count("\n") + 1

	# Cuántas líneas caben REALMENTE en el cuadro, calculado a partir de la
	# altura de línea actual (fuente + espaciado), no de un número fijo.
	# Esto evita que un line_spacing distinto al predeterminado genere
	# demasiado padding y empuje el texto más abajo de lo debido.
	var fit_lines   : int = _get_lines_that_fit()
	var empty_lines : int = fit_lines - line_count

	if empty_lines <= 0:
		return text

	var pad_lines : int = empty_lines / 2 if valign == VERTICAL_ALIGNMENT_CENTER else empty_lines
	var padding   : String = "\n".repeat(pad_lines)

	match valign:
		VERTICAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM:
			return padding + text
		_:
			return text


## Calcula cuántas líneas de texto caben verticalmente en el cuadro de
## diálogo, midiendo el alto REAL del RichTextLabel en tiempo de ejecución
## (text_lbl.size.y) en vez de asumir un valor fijo. Esto es importante
## porque custom_minimum_size solo define un mínimo: el contenedor padre
## (HBoxContainer/VBoxContainer) puede expandir el label a un alto mayor,
## y usar un valor fijo subestimaba la capacidad real, generando muy poco
## padding y dejando el texto pegado arriba en vez de centrado/abajo.
##
## FIX: el espaciado entre líneas (line_separation) solo se aplica ENTRE
## líneas consecutivas (N-1 veces para N líneas), no después de la última.
## La versión anterior sumaba el spacing a line_height y dividía
## directamente (box_height / line_height), lo cual infla el alto por
## línea de más y subestima cuántas líneas caben cuando line_spacing != 0,
## generando muy poco padding y desalineando el texto hacia arriba.
## La fórmula correcta despeja N de:
##     box_height = N * line_height + (N - 1) * spacing
## => N = (box_height + spacing) / (line_height + spacing)
func _get_lines_that_fit() -> int:
	# Alto real disponible. Si el layout todavía no corrió (primer frame),
	# usamos custom_minimum_size como aproximación de respaldo.
	var box_height : float = text_lbl.size.y
	if box_height <= 0.0:
		box_height = text_lbl.custom_minimum_size.y
	if box_height <= 0.0:
		return 1

	# Escala actual de pantalla, para convertir el tamaño de fuente base y
	# el line_spacing (definidos en unidades a 1920x1080) a píxeles reales,
	# ya que box_height ya viene en píxeles reales de pantalla.
	var vp : Vector2 = get_viewport().get_visible_rect().size
	var s  : float    = clampf(min(vp.x / 1920.0, vp.y / 1080.0), 0.1, 10.0)

	var font : Font = text_lbl.get_theme_font("normal_font")
	if font == null:
		font = default_font
	var base_font_size   : int = default_font_size if default_font_size > 0 else 42
	var font_size_scaled : int = maxi(1, roundi(base_font_size * s))

	var line_height : float = 0.0
	if font != null:
		line_height = font.get_height(font_size_scaled)
	if line_height <= 0.0:
		# Fallback aproximado si no se pudo obtener la métrica de la fuente.
		line_height = font_size_scaled * 1.2

	var spacing : float = _current_line_spacing * s

	# N = (box_height + spacing) / (line_height + spacing)
	# El "+spacing" del numerador compensa que la última línea no necesita
	# separación después de sí misma, evitando subestimar N cuando
	# line_spacing != 0.
	var denom : float = line_height + spacing
	if denom <= 0.0:
		return 1

	return maxi(1, floori((box_height + spacing) / denom))


# ══════════════════════════════════════════════════════════════════════
# HISTORIAL DE DIÁLOGO (estilo Zelda TotK)
# ══════════════════════════════════════════════════════════════════════

## Agrega una entrada al historial de esta ejecución. No hace nada si el
## texto está vacío (p. ej. una página sin "text", solo con "action").
func _record_history_entry(speaker_text: String, page_text: String) -> void:
	if page_text == "":
		return
	_history.append({ "speaker": speaker_text, "text": page_text })
	if max_history_entries > 0 and _history.size() > max_history_entries:
		_history.pop_front()


## Devuelve una copia del historial acumulado durante la ejecución actual
## del cuadro de diálogo. Cada entrada es { "speaker": String, "text": String }.
## Útil si se quiere armar una UI de historial completamente custom en vez
## de usar el panel HistoryLog integrado.
func get_history() -> Array:
	return _history.duplicate(true)


## Abre o cierra el panel de historial, según su estado actual.
func _toggle_history() -> void:
	if _in_history:
		_close_history()
	else:
		_open_history()


## Crea (una sola vez) el ColorRect que oscurece la pantalla detrás del
## panel de historial. Se inserta como hijo de este CanvasLayer en el
## índice 0 (se dibuja primero), de modo que quede detrás de "Root" —y por
## lo tanto detrás de history_panel y de cualquier otro contenido del
## diálogo— sin depender de cómo esté armada la jerarquía interna de Root.
## Cubre toda la pantalla (anchors full rect) y bloquea el mouse
## (MOUSE_FILTER_STOP) para que no se puedan hacer clicks al juego debajo
## mientras el historial está abierto.
func _ensure_history_dim() -> void:
	if _history_dim != null:
		return
	_history_dim = ColorRect.new()
	_history_dim.name = "HistoryDim"
	_history_dim.color = history_dim_color
	_history_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_history_dim.hide()
	add_child(_history_dim)
	move_child(_history_dim, 0)


## Centra horizontalmente history_panel dentro de su padre, sin tocar su
## anclaje/posición vertical (la vertical queda tal como esté configurada
## en la escena). Se llama vía call_deferred desde _open_history(), para
## asegurarse de que el tamaño real del panel (history_panel.size) ya esté
## calculado por el layout antes de centrar en base a él.
## Centra horizontalmente history_panel dentro de su padre, sin tocar su
## anclaje/posición vertical (la vertical queda tal como esté configurada
## en la escena).
##
## El ancho a usar se resuelve con esta prioridad, para no depender de
## history_panel.size — que puede seguir siendo 0 en este punto, ya que el
## panel todavía está oculto (o recién se mostró) y Godot no garantiza
## haber recalculado su layout todavía:
##   1. custom_minimum_size.x, si el panel tiene un ancho mínimo definido
##      en el editor (la fuente más confiable, no depende de layout).
##   2. history_panel.size.x, si ya quedó resuelto (> 0).
##   3. 70% del ancho del viewport, como último fallback razonable.
func _center_history_horizontally() -> void:
	if history_panel == null:
		return

	var w : float = history_panel.custom_minimum_size.x
	if w <= 0.0:
		w = history_panel.size.x
	if w <= 0.0:
		w = get_viewport().get_visible_rect().size.x * 0.7

	history_panel.anchor_left   = 0.5
	history_panel.anchor_right  = 0.5
	history_panel.offset_left   = -w / 2.0
	history_panel.offset_right  = w / 2.0


func _open_history() -> void:
	if history_panel == null or history_list == null:
		push_warning("[DialogBox] No se pudo abrir el historial: falta el nodo 'HistoryLog' en la escena (ver comentario junto a los @onready de history_panel).")
		return

	_in_history = true

	# Ocultar temporalmente el cuadro de diálogo real (y el ítem, si estaba
	# visible) mientras el historial está abierto. Se restauran ambos al
	# cerrar el historial, en _close_history().
	_item_box_was_visible_before_history = item_box.visible
	panel.hide()
	item_box.hide()

	# Oscurecer la pantalla detrás del panel de historial.
	_ensure_history_dim()
	_history_dim.color = history_dim_color
	_history_dim.show()

	_rebuild_history_ui()
	history_panel.show()
	# Centrar ya mismo (usa custom_minimum_size o el fallback si el tamaño
	# real todavía no está resuelto) y una vez más diferido, por si el
	# tamaño real queda disponible recién en el próximo frame idle.
	_center_history_horizontally()
	call_deferred("_center_history_horizontally")

	emit_signal("history_toggled", true)


func _close_history() -> void:
	_in_history = false

	if history_panel != null:
		history_panel.hide()
	if _history_dim != null:
		_history_dim.hide()

	# Restaurar el cuadro de diálogo real y el estado previo del ítem.
	panel.show()
	item_box.visible = _item_box_was_visible_before_history

	emit_signal("history_toggled", false)


## Reconstruye la lista visible del historial a partir de _history.
## Se llama cada vez que se abre el panel, para reflejar las páginas
## vistas hasta ese momento (incluida la que esté abierta en ese instante).
func _rebuild_history_ui() -> void:
	for child in history_list.get_children():
		child.free()

	for entry in _history:
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled       = true
		lbl.fit_content          = true
		lbl.scroll_active        = false
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# fit_content por sí solo deja el RichTextLabel del ancho exacto de
		# su texto (shrink-wrap), y en ese caso "horizontal_alignment"
		# centrado no tiene ningún efecto visible porque no sobra espacio
		# horizontal dentro del label. Forzamos a que ocupe todo el ancho
		# disponible del VBoxContainer padre (SIZE_EXPAND_FILL) para que el
		# centrado del texto se note realmente.
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var speaker_txt : String = entry.get("speaker", "")
		var prefix      : String = ("[b]%s:[/b] " % speaker_txt) if speaker_txt != "" else ""
		lbl.text = prefix + entry.get("text", "")
		history_list.add_child(lbl)

	# Igual que con el catch-up de scroll del cuadro principal (ver
	# _finish_scroll_catchup): hay que esperar a que el ScrollContainer
	# recalcule su alto de contenido después de agregar los labels, antes
	# de poder bajar el scroll hasta el final de forma confiable.
	call_deferred("_scroll_history_to_bottom")


func _scroll_history_to_bottom() -> void:
	if history_scroll == null:
		return
	var vscroll : VScrollBar = history_scroll.get_v_scroll_bar()
	if vscroll != null:
		vscroll.value = vscroll.max_value


## Scroll manual del panel de historial con Up/Down mientras está abierto.
## La rueda del mouse funciona sola (comportamiento nativo de ScrollContainer).
func _handle_history_scroll(delta: float) -> void:
	if history_scroll == null:
		return
	var vscroll : VScrollBar = history_scroll.get_v_scroll_bar()
	if vscroll == null:
		return

	var dir : float = 0.0
	if Input.is_action_pressed("Up"):
		dir -= 1.0
	if Input.is_action_pressed("Down"):
		dir += 1.0
	if dir == 0.0:
		return

	vscroll.value = clampf(vscroll.value + dir * manual_scroll_speed * delta, 0.0, vscroll.max_value)


# ══════════════════════════════════════════════════════════════════════
# OPCIONES
# ══════════════════════════════════════════════════════════════════════

func _show_choices(opts: Array) -> void:
	_waiting      = false
	_in_choices   = true
	_choice_index = 0
	choices.show()
	choices_bg.show()
	_clear_choices()

	var start    : int  = _choice_page * MAX_CHOICES_PER_PAGE
	var has_more : bool = (start + MAX_CHOICES_PER_PAGE) < opts.size()
	var end      : int  = mini(start + MAX_CHOICES_PER_PAGE, opts.size())
	var vp             : Vector2 = get_viewport().get_visible_rect().size
	var s              : float   = min(vp.x / 1920.0, vp.y / 1080.0)
	var choice_fs      : int     = roundi(29 * s)

	for i in range(start, end):
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled        = true
		lbl.fit_content           = true
		lbl.scroll_active         = false
		lbl.text                  = _translate_choice(opts, i)
		lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("default_color", Color.WHITE)
		lbl.add_theme_font_override("normal_font", CHOICE_FONT)
		lbl.add_theme_font_size_override("normal_font_size", choice_fs)
		choices.add_child(lbl)

	if _choice_page > 0:
		var back_lbl := RichTextLabel.new()
		back_lbl.bbcode_enabled       = true
		back_lbl.fit_content          = true
		back_lbl.scroll_active        = false
		back_lbl.text                 = _tr("← Opciones anteriores")
		back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		back_lbl.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
		back_lbl.add_theme_font_override("normal_font", CHOICE_FONT)
		back_lbl.add_theme_font_size_override("normal_font_size", choice_fs)
		choices.add_child(back_lbl)

	if has_more:
		var more_lbl := RichTextLabel.new()
		more_lbl.bbcode_enabled       = true
		more_lbl.fit_content          = true
		more_lbl.scroll_active        = false
		more_lbl.text                 = _tr("Más opciones →")
		more_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more_lbl.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
		more_lbl.add_theme_font_override("normal_font", CHOICE_FONT)
		more_lbl.add_theme_font_size_override("normal_font_size", choice_fs)
		choices.add_child(more_lbl)

	_refresh_cursor()


func _handle_choices() -> void:
	var block : Array = _blocks[_current_block]
	var page          = block[_page_index]
	var opts  : Array = page.get("choices", [])

	var start         : int  = _choice_page * MAX_CHOICES_PER_PAGE
	var has_more      : bool = (start + MAX_CHOICES_PER_PAGE) < opts.size()
	var has_back      : bool = _choice_page > 0
	var real_count    : int  = mini(MAX_CHOICES_PER_PAGE, opts.size() - start)
	var visible_count : int  = real_count + (1 if has_back else 0) + (1 if has_more else 0)

	if Input.is_action_just_pressed("Up"):
		_choice_index = (_choice_index - 1 + visible_count) % visible_count
		_refresh_cursor()
		cursor_sfx.play()

	elif Input.is_action_just_pressed("Down"):
		_choice_index = (_choice_index + 1) % visible_count
		_refresh_cursor()
		cursor_sfx.play()

	elif Input.is_action_just_pressed("Accept"):
		var back_idx : int = real_count
		var more_idx : int = real_count + (1 if has_back else 0)

		if has_back and _choice_index == back_idx:
			cursor_sfx.play()
			_choice_page -= 1
			_show_choices(opts)
			return

		if has_more and _choice_index == more_idx:
			cursor_sfx.play()
			_choice_page += 1
			_show_choices(opts)
			return

		confirm_sfx.play()
		var global_index  : int   = start + _choice_index
		var target_blocks : Array = page.get("target_blocks", [])
		var actions       : Array = page.get("actions", [])

		emit_signal("choice_made", global_index)

		# Ejecutar acción si existe
		if global_index < actions.size():
			var action = actions[global_index]
			if action is Callable and action.is_valid():
				action.call()

		_in_choices  = false
		_choice_page = 0
		_clear_choices()
		choices.hide()
		choices_bg.hide()

		# Determinar destino
		if global_index < target_blocks.size():
			var target = target_blocks[global_index]
			if target == null:
				_page_index += 1
				_show_page(_page_index)
			else:
				_jump_to_block(target)
		else:
			_page_index += 1
			_show_page(_page_index)


func _refresh_cursor() -> void:
	var block : Array = _blocks[_current_block]
	var page          = block[_page_index]
	var opts  : Array = page.get("choices", [])
	var start      : int  = _choice_page * MAX_CHOICES_PER_PAGE
	var has_more   : bool = (start + MAX_CHOICES_PER_PAGE) < opts.size()
	var has_back   : bool = _choice_page > 0
	var real_count : int  = mini(MAX_CHOICES_PER_PAGE, opts.size() - start)
	var back_idx   : int  = real_count
	var more_idx   : int  = real_count + (1 if has_back else 0)
	var labels     := choices.get_children()

	for i in labels.size():
		var prefix := "▶ " if i == _choice_index else "  "
		if i < real_count:
			labels[i].text = prefix + _translate_choice(opts, start + i)
		elif has_back and i == back_idx:
			labels[i].text = prefix + _tr("← Opciones anteriores")
		elif has_more and i == more_idx:
			labels[i].text = prefix + _tr("Más opciones →")


func _clear_choices() -> void:
	for child in choices.get_children():
		child.free()


# ══════════════════════════════════════════════════════════════════════
# HELPERS BBCODE
# ══════════════════════════════════════════════════════════════════════

## Recorre "raw" y saca las etiquetas custom [speed=N]...[/speed] (no son
## BBCode real: el RichTextLabel no las reconoce, así que hay que
## quitarlas del texto que se termina mostrando). Devuelve un Dictionary:
##   { "text": <texto sin las etiquetas [speed]>, "ranges": Array }
## donde "ranges" es un Array de { "start": int, "end": int, "speed": float},
## con "start"/"end" en posiciones de caracteres PLANOS del texto de
## salida ("text"), es decir, ignorando cualquier OTRO tag BBCode que
## haya quedado (mismo criterio de conteo que _get_plain_length).
## Cualquier otro tag ([color], [wave], [shake], etc.) se deja intacto en
## el texto de salida — solo se procesan específicamente "[speed=...]" y
## "[/speed]". Soporta anidado simple vía una pila, aunque el uso típico
## es un solo nivel por fragmento.
func _extract_speed_ranges(raw: String) -> Dictionary:
	var cleaned     : String = ""
	var ranges      : Array  = []
	var speed_stack : Array  = []
	var plain_index : int    = 0
	var i           : int    = 0
	var n           : int    = raw.length()

	while i < n:
		var ch : String = raw[i]

		if ch == "[":
			var close_idx : int = raw.find("]", i)
			if close_idx == -1:
				# "[" suelto sin cierre: se trata como texto plano normal.
				cleaned += ch
				plain_index += 1
				i += 1
				continue

			var tag_content : String = raw.substr(i + 1, close_idx - i - 1)
			var tag_lower   : String = tag_content.to_lower()

			if tag_lower.begins_with("speed="):
				var speed_val : float = tag_content.substr(6).to_float()
				speed_stack.append({ "speed": speed_val, "start": plain_index })
				i = close_idx + 1
				continue

			if tag_lower == "/speed":
				if speed_stack.size() > 0:
					var entry : Dictionary = speed_stack.pop_back()
					if plain_index > entry["start"]:
						ranges.append({ "start": entry["start"], "end": plain_index, "speed": entry["speed"] })
				i = close_idx + 1
				continue

			# Cualquier otro tag BBCode se conserva tal cual en la salida,
			# y no cuenta para plain_index (mismo criterio que el resto de
			# los helpers BBCode de más abajo).
			cleaned += raw.substr(i, close_idx - i + 1)
			i = close_idx + 1
			continue

		cleaned += ch
		plain_index += 1
		i += 1

	# Si quedó algún [speed=...] sin su [/speed] de cierre, se cierra
	# igual al final del texto, en vez de perder silenciosamente el rango.
	while speed_stack.size() > 0:
		var entry : Dictionary = speed_stack.pop_back()
		if plain_index > entry["start"]:
			ranges.append({ "start": entry["start"], "end": plain_index, "speed": entry["speed"] })

	return { "text": cleaned, "ranges": ranges }


## Análogo a _extract_speed_ranges, pero para el tag [face=NOMBRE]...[/face]
## (usado por el sistema de emociones del retrato animado, ver arriba).
## Saca esos tags del texto (no son BBCode real) y devuelve, además del
## texto limpio, los rangos { "start", "end", "face" } donde cada uno
## indica qué emoción debe mostrar el retrato mientras se tipea ese tramo.
func _extract_face_ranges(raw: String) -> Dictionary:
	var cleaned     : String  = ""
	var ranges      : Array   = []
	var face_stack  : Array   = []
	var plain_index : int     = 0
	var i           : int     = 0
	var n           : int     = raw.length()

	while i < n:
		var ch : String = raw[i]

		if ch == "[":
			var close_idx : int = raw.find("]", i)
			if close_idx == -1:
				cleaned += ch
				plain_index += 1
				i += 1
				continue

			var tag_content : String = raw.substr(i + 1, close_idx - i - 1)
			var tag_lower   : String = tag_content.to_lower()

			if tag_lower.begins_with("face="):
				var face_name : String = tag_content.substr(5)
				face_stack.append({ "face": face_name, "start": plain_index })
				i = close_idx + 1
				continue

			if tag_lower == "/face":
				if face_stack.size() > 0:
					var entry : Dictionary = face_stack.pop_back()
					if plain_index > entry["start"]:
						ranges.append({ "start": entry["start"], "end": plain_index, "face": entry["face"] })
				i = close_idx + 1
				continue

			cleaned += raw.substr(i, close_idx - i + 1)
			i = close_idx + 1
			continue

		cleaned += ch
		plain_index += 1
		i += 1

	while face_stack.size() > 0:
		var entry : Dictionary = face_stack.pop_back()
		if plain_index > entry["start"]:
			ranges.append({ "start": entry["start"], "end": plain_index, "face": entry["face"] })

	return { "text": cleaned, "ranges": ranges }


## Devuelve la velocidad de tipeo (caracteres/seg) que corresponde al
## caracter plano en la posición "idx" de _full_text, según _speed_ranges.
## Si "idx" no cae dentro de ningún rango custom, devuelve
## _current_chars_per_second (la velocidad normal de la página/voz).
func _get_speed_for_index(idx: int) -> float:
	for r in _speed_ranges:
		if idx >= r["start"] and idx < r["end"]:
			var s : float = r["speed"]
			return s if s > 0.0 else _current_chars_per_second
	return _current_chars_per_second


## Elimina todos los tags BBCode y devuelve el texto plano.
func _strip_bbcode(text: String) -> String:
	var result : String = ""
	var in_tag : bool   = false
	for ch in text:
		if ch == "[":
			in_tag = true
		elif ch == "]":
			in_tag = false
		elif not in_tag:
			result += ch
	return result


## Devuelve la cantidad de caracteres visibles (ignorando tags BBCode).
func _get_plain_length(bbtext: String) -> int:
	var count  : int  = 0
	var in_tag : bool = false
	for ch in bbtext:
		if ch == "[":
			in_tag = true
		elif ch == "]":
			in_tag = false
		elif not in_tag:
			count += 1
	return count


## Devuelve el carácter N del texto ignorando tags BBCode.
func _get_plain_char(bbtext: String, n: int) -> String:
	var count  : int  = 0
	var in_tag : bool = false
	for ch in bbtext:
		if ch == "[":
			in_tag = true
		elif ch == "]":
			in_tag = false
		elif not in_tag:
			if count == n:
				return ch
			count += 1
	return ""


## Extrae una subcadena del texto BBCode basándose en posiciones del texto plano.
## Preserva intactos todos los tags BBCode que queden dentro del rango.
func _bbcode_substr(bbtext: String, plain_start: int, plain_length: int) -> String:
	var result      : String = ""
	var plain_count : int    = 0
	var in_tag      : bool   = false
	var tag_buf     : String = ""

	for ch in bbtext:
		if ch == "[":
			in_tag  = true
			tag_buf = "["
		elif ch == "]":
			in_tag   = false
			tag_buf += "]"
			# Incluir el tag si estamos dentro del rango o es un tag de cierre
			# que puede afectar el texto ya incluido
			if plain_count > plain_start:
				result += tag_buf
			elif plain_count == plain_start and plain_length > 0:
				result += tag_buf
			tag_buf = ""
		elif in_tag:
			tag_buf += ch
		else:
			if plain_count >= plain_start and plain_count < plain_start + plain_length:
				result += ch
			plain_count += 1
			if plain_count >= plain_start + plain_length:
				break

	return result


## Envuelve el texto con saltos de línea vacíos para simular alineación vertical
## dentro del RichTextLabel, que no expone vertical_alignment de forma funcional.
## Usa MAX_LINES_PER_PAGE para calcular el padding necesario.
## NOTA: se mantiene por compatibilidad; el flujo normal usa ahora
## _apply_valignment_if_fits(), que solo aplica el padding cuando el
## contenido no necesita autoscroll.
func _apply_valignment(text: String, valign: VerticalAlignment) -> String:
	if valign == VERTICAL_ALIGNMENT_TOP:
		return text  # sin cambios

	# Contar líneas reales del texto (incluyendo wraps ya resueltos por _get_text_page)
	var line_count  : int = text.count("\n") + 1
	var empty_lines : int = MAX_LINES_PER_PAGE - line_count

	if empty_lines <= 0:
		return text

	var pad_lines : int = empty_lines / 2 if valign == VERTICAL_ALIGNMENT_CENTER else empty_lines
	var padding   : String = "\n".repeat(pad_lines)

	match valign:
		VERTICAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM:
			return padding + text
		_:
			return text


# ══════════════════════════════════════════════════════════════════════
# Nota de migración: ChoicesBG con windowskin (mismo patrón que Box)
#
# 1. Seleccionar "ChoicesBG" en el árbol → Change Type... → Control.
#    (Pierde su textura propia de TextureRect, que de todos modos se
#    reemplaza por el sistema de windowskin.)
# 2. Agregar un hijo nuevo dentro de "ChoicesBG", PRIMERO en la lista
#    (para que quede detrás de "Choices"), tipo Control, con el script
#    RMWindowSkinPanel.gd. Nombrarlo "ChoicesWindowSkinBG" — el
#    @onready de arriba ya apunta a esa ruta exacta.
# 3. Anclarlo en Full Rect dentro de ChoicesBG (Layout → Anchors Preset).
# 4. Asignarle un recurso RMWindowSkin en su campo "Skin" (puede ser el
#    mismo .tres que ya usa WindowSkinBG, o uno distinto).
# 5. No hace falta ningún cambio de código más: choices_bg.show()/hide()
#    ya siguen funcionando igual (son de Control), y como
#    ChoicesWindowSkinBG es su hijo, se muestra/oculta solo junto con
#    ChoicesBG — sin necesidad de tocarlo aparte.
# ══════════════════════════════════════════════════════════════════════
