extends CanvasLayer

signal dialog_finished
signal choice_made(index: int)
signal block_changed(name: String)

@onready var panel       : NinePatchRect     = $Box
@onready var portrait    : TextureRect       = $Box/HBoxContainer/Portrait
@onready var speaker     : Label             = $Box/SpeakerName
@onready var text_lbl    : RichTextLabel     = $Box/HBoxContainer/VBoxContainer/Text
@onready var arrow       : Label             = $Box/Arrow
@onready var choices     : VBoxContainer     = $Box/ChoicesBG/Choices
@onready var choices_bg  : TextureRect       = $Box/ChoicesBG
@onready var beep_sfx    : AudioStreamPlayer = $BeepSFX
@onready var cursor_sfx  : AudioStreamPlayer = $CursorSFX
@onready var confirm_sfx : AudioStreamPlayer = $ConfirmSFX

const SKIP_CHARS          := [" ", ".", ",", "!", "?", ":", ";", "-", "—", "\"", "'", "(", ")", "\n"]
const BEEP_EVERY          := 2
const CHARS_PER_SEC       := 40.0
const CHOICE_FONT         := preload("res://data/Fonts/monogatari.ttf")
const MAX_CHARS_PER_LINE  := 30
const MAX_LINES_PER_PAGE  := 4
const MAX_CHOICES_PER_PAGE := 4

# ── Estado interno ─────────────────────────────────────────────────────
var _blocks       : Dictionary = {}
var _current_block: String     = ""
var _page_index   : int        = 0
var _full_text    : String     = ""
var _chars_shown  : int        = 0
var _timer        : float      = 0.0
var _typing       : bool       = false
var _waiting      : bool       = false
var _in_choices   : bool       = false
var _choice_index : int        = 0
var _choice_page  : int        = 0
var _beep_counter : int        = 0
var _release_player_on_close : bool = true


func _ready() -> void:
	panel.hide()
	choices_bg.hide()
	$Box/HBoxContainer.resized.connect(_sync_portrait_size)

func _sync_portrait_size() -> void:
	var h : float = $Box/HBoxContainer.size.y
	portrait.custom_minimum_size = Vector2(h, h)


# ══════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════

func start(bloques: Dictionary, bloque_inicial: String,
		   release_player_on_close: bool = true) -> void:
	_blocks                  = bloques
	_release_player_on_close = release_player_on_close
	_in_choices              = false
	_choice_index            = 0
	_choice_page             = 0
	_typing                  = false
	_waiting                 = false
	panel.show()
	Globals.playerStay = true
	_jump_to_block(bloque_inicial)


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

	# Portrait
	if page.get("portrait"):
		portrait.texture = page["portrait"]
		portrait.show()
	else:
		portrait.hide()

	# Speaker
	speaker.text    = page.get("speaker", "")
	speaker.visible = speaker.text != ""

	# Texto paginado
	var raw_text : String = page.get("text", "")
	_full_text = _get_text_page(raw_text, page.get("text_page", 0))

	_chars_shown  = 0
	_timer        = 0.0
	_typing       = true
	_waiting      = false
	_in_choices   = false
	_beep_counter = 0

	text_lbl.text               = _full_text
	text_lbl.visible_characters = 0
	arrow.hide()
	choices.hide()
	choices_bg.hide()
	_clear_choices()


# ══════════════════════════════════════════════════════════════════════
# PAGINACIÓN DE TEXTO
# ══════════════════════════════════════════════════════════════════════

func _get_text_page(full: String, sub_page: int) -> String:
	var words   := full.split(" ")
	var lines   : Array[String] = []
	var current : String = ""

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

	var start : int = sub_page * MAX_LINES_PER_PAGE
	var end   : int = mini(start + MAX_LINES_PER_PAGE, lines.size())
	var slice : Array[String] = []
	for i in range(start, end):
		slice.append(lines[i])
	return "\n".join(slice)


# ══════════════════════════════════════════════════════════════════════
# PROCESS
# ══════════════════════════════════════════════════════════════════════

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
		var ch := _full_text[_chars_shown]
		_chars_shown += 1
		if ch not in SKIP_CHARS:
			_beep_counter += 1
			if _beep_counter >= BEEP_EVERY:
				_beep_counter = 0
				if beep_sfx and not beep_sfx.playing:
					beep_sfx.play()

	text_lbl.visible_characters = _chars_shown

	if _chars_shown >= _full_text.length():
		_typing       = false
		_waiting      = true
		_beep_counter = 0
		_on_end()


func _skip() -> void:
	_chars_shown                = _full_text.length()
	text_lbl.visible_characters = _chars_shown
	_typing  = false
	_waiting = true
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
		arrow.show()


func _advance() -> void:
	_waiting     = false
	_page_index += 1
	_show_page(_page_index)


func _close() -> void:
	panel.hide()
	choices_bg.hide()
	if _release_player_on_close:
		Globals.playerStay = false
	emit_signal("dialog_finished")


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

	for i in range(start, end):
		var lbl := Label.new()
		lbl.text = opts[i]
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_override("font", CHOICE_FONT)
		lbl.add_theme_font_size_override("font_size", 29)
		choices.add_child(lbl)

	if _choice_page > 0:
		var back_lbl := Label.new()
		back_lbl.text = "← Opciones anteriores"
		back_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		back_lbl.add_theme_font_override("font", CHOICE_FONT)
		back_lbl.add_theme_font_size_override("font_size", 29)
		choices.add_child(back_lbl)

	if has_more:
		var more_lbl := Label.new()
		more_lbl.text = "Más opciones →"
		more_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		more_lbl.add_theme_font_override("font", CHOICE_FONT)
		more_lbl.add_theme_font_size_override("font_size", 29)
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
			labels[i].text = prefix + opts[start + i]
		elif has_back and i == back_idx:
			labels[i].text = prefix + "← Opciones anteriores"
		elif has_more and i == more_idx:
			labels[i].text = prefix + "Más opciones →"


func _clear_choices() -> void:
	for child in choices.get_children():
		child.free()
