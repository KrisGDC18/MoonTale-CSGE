extends CanvasLayer

signal dialog_finished
signal choice_made(index: int)

@onready var panel     : Panel          = $Panel
@onready var portrait  : TextureRect    = $Panel/Portrait
@onready var speaker   : Label          = $Panel/SpeakerName
@onready var text_lbl  : RichTextLabel  = $Panel/Text
@onready var arrow     : Label          = $Panel/Arrow
@onready var choices   : VBoxContainer  = $Panel/Choices
@onready var beep_sfx : AudioStreamPlayer = $BeepSFX
@onready var cursor_sfx : AudioStreamPlayer = $CursorSFX
@onready var confirm_sfx : AudioStreamPlayer = $ConfirmSFX

const SKIP_CHARS := [" ", ".", ",", "!", "?", ":", ";", "-", "—", "\"", "'", "(", ")", "\n"]
const BEEP_EVERY := 2  # suena cada N letras válidas
var _beep_counter := 0

const CHARS_PER_SEC := 40.0

var _pages        : Array = []
var _page_index   : int   = 0
var _full_text    : String = ""
var _chars_shown  : int   = 0
var _timer        : float = 0.0
var _typing       : bool  = false
var _waiting      : bool  = false
var _in_choices   : bool  = false
var _choice_index : int   = 0


func _ready() -> void:
	panel.hide()


# ── API pública ────────────────────────────────────────────────────────
# Formato de cada página:
# {
#   "text"     : "Hola mundo",
#   "speaker"  : "Kris",          # opcional
#   "portrait" : <Texture2D>,      # opcional
#   "choices"  : ["Sí", "No"],    # opcional
#   "targets"  : [1, 2],          # índice de página destino por opción
# }
func start(pages: Array) -> void:
	_pages      = pages
	_page_index = 0
	panel.show()
	Globals.playerStay = true   # ← bloquea al jugador
	_show_page(0)


# ── Lógica interna ─────────────────────────────────────────────────────
func _show_page(index: int) -> void:
	if index >= _pages.size():
		_close()
		return

	var page = _pages[index]

	# Portrait
	if page.get("portrait"):
		portrait.texture = page["portrait"]
		portrait.show()
	else:
		portrait.hide()

	# Speaker
	speaker.text    = page.get("speaker", "")
	speaker.visible = speaker.text != ""

	# Texto
	_full_text   = page.get("text", "")
	_chars_shown = 0
	_timer       = 0.0
	_typing      = true
	_waiting     = false
	_in_choices  = false
	_beep_counter = 0

	text_lbl.text               = _full_text
	text_lbl.visible_characters = 0
	arrow.hide()
	choices.hide()
	_clear_choices()


func _process(delta: float) -> void:
	if not panel.visible:
		return

	if _in_choices:
		_handle_choices()
		return

	if _typing:
		_tick(delta)
		if Input.is_action_just_pressed("Accept"):
			_skip()
		return

	if _waiting and Input.is_action_just_pressed("Accept"):
		_advance()


func _tick(delta: float) -> void:
	_timer += delta
	var add := int(_timer * CHARS_PER_SEC)
	if add < 1:
		return
	_timer = 0.0

	for i in add:
		if _chars_shown >= _full_text.length():
			break

		var current_char := _full_text[_chars_shown]
		_chars_shown += 1

		if current_char not in SKIP_CHARS:
			_beep_counter += 1
			if _beep_counter >= BEEP_EVERY:
				_beep_counter = 0
				if beep_sfx and not beep_sfx.playing:
					beep_sfx.play()

	text_lbl.visible_characters = _chars_shown

	if _chars_shown >= _full_text.length():
		_typing  = false
		_waiting = true
		_beep_counter = 0
		_on_end()


func _skip() -> void:
	_chars_shown                = _full_text.length()
	text_lbl.visible_characters = _chars_shown
	_typing  = false
	_waiting = true
	_on_end()


func _on_end() -> void:
	var page = _pages[_page_index]
	if page.get("choices", []).size() > 0:
		_show_choices(page["choices"])
	else:
		arrow.show()


func _advance() -> void:
	_waiting     = false
	_page_index += 1
	_show_page(_page_index)


func _close() -> void:
	panel.hide()
	Globals.playerStay = false  #
	emit_signal("dialog_finished")


# ── Opciones ───────────────────────────────────────────────────────────
func _show_choices(opts: Array) -> void:
	_waiting      = false
	_in_choices   = true
	_choice_index = 0
	choices.show()

	for i in opts.size():
		var lbl       := Label.new()
		lbl.text       = opts[i]
		lbl.add_theme_color_override("font_color", Color.WHITE)
		choices.add_child(lbl)

	_refresh_cursor()


func _handle_choices() -> void:
	var page = _pages[_page_index]
	var opts = page.get("choices", [])

	if Input.is_action_just_pressed("Up"):
		_choice_index = max(_choice_index - 1, 0)
		_refresh_cursor()
		cursor_sfx.play()  # ← sonido al mover cursor
	elif Input.is_action_just_pressed("Down"):
		_choice_index = min(_choice_index + 1, opts.size() - 1)
		_refresh_cursor()
		cursor_sfx.play()  # ← sonido al mover cursor

	elif Input.is_action_just_pressed("Accept"):
		confirm_sfx.play()  # ← sonido al confirmar
		var targets = page.get("targets", [])
		var next    = targets[_choice_index] if _choice_index < targets.size() \
					  else _page_index + 1
		emit_signal("choice_made", _choice_index)
		_in_choices = false
		_clear_choices()
		choices.hide()
		_page_index = next
		_show_page(_page_index)


func _refresh_cursor() -> void:
	var labels = choices.get_children()
	for i in labels.size():
		labels[i].text = ("▶ " if i == _choice_index else "  ") \
						  + _pages[_page_index]["choices"][i]


func _clear_choices() -> void:
	for child in choices.get_children():
		child.queue_free()
