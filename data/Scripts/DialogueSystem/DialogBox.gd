extends CanvasLayer

signal dialog_finished
signal choice_made(index: int)
signal block_changed(name: String)

@onready var panel       : NinePatchRect     = $Root/Box
@onready var portrait    : TextureRect       = $Root/Box/HBoxContainer/Portrait
@onready var portrait_animated : AnimatedSprite2D  = $Root/Box/HBoxContainer/PortraitAnimated
@onready var hbox              : HBoxContainer     = $Root/Box/HBoxContainer
@onready var speaker     : Label             = $Root/Box/SpeakerName
@onready var text_lbl    : RichTextLabel     = $Root/Box/HBoxContainer/VBoxContainer/Text
@onready var arrow       : Label             = $Root/Box/Arrow
@onready var choices     : VBoxContainer     = $Root/Box/ChoicesBG/Choices
@onready var choices_bg  : TextureRect       = $Root/Box/ChoicesBG
@onready var item_box    : Control           = $Root/ItemBox
@onready var item_icon   : TextureRect       = $Root/ItemBox/Icon
@onready var beep_sfx    : AudioStreamPlayer = $BeepSFX
@onready var cursor_sfx  : AudioStreamPlayer = $CursorSFX
@onready var confirm_sfx : AudioStreamPlayer = $ConfirmSFX

const SKIP_CHARS          := [" ", ".", ",", "!", "?", ":", ";", "-", "—", "\"", "'", "(", ")", "\n"]
const BEEP_EVERY          := 2
const CHARS_PER_SEC       := 40.0
const CHOICE_FONT         := preload("res://data/Fonts/monogatari.ttf")
const MAX_CHARS_PER_LINE  := 30
const MAX_LINES_PER_PAGE  := 7
const MAX_CHOICES_PER_PAGE := 4

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
var default_text_valignment : VerticalAlignment   = VERTICAL_ALIGNMENT_TOP

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
# Animaciones activas del portrait animado para la página actual.
# Se leen de las claves "portrait_anim_typing" y "portrait_anim_idle" de cada página.
var _portrait_anim_typing : String = ""
var _portrait_anim_idle   : String = ""

# Audio de typing por defecto. Se captura automáticamente en _ready() desde el nodo
# BeepSFX. Puede sobreescribirse globalmente asignando esta variable, o por página
# con la clave "beep_stream" (AudioStream). null = sin sonido.
var default_beep_stream   : AudioStream = null
# Stream activo para la página actual (se resetea en cada _show_page).
var _current_beep_stream  : AudioStream = null


func _ready() -> void:
	panel.hide()
	choices_bg.hide()
	portrait_animated.hide()
	item_box.hide()
	$Root/Box/HBoxContainer.resized.connect(_sync_portrait_size)
	get_viewport().size_changed.connect(_sync_canvas_scale)
	# Habilitar BBCode para soporte de colores y efectos de texto
	text_lbl.bbcode_enabled = true
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
	# Aplicar escala inicial de fuentes y portrait
	_sync_canvas_scale()

func _sync_portrait_size() -> void:
	var h : float = $Root/Box/HBoxContainer.size.y
	portrait.custom_minimum_size = Vector2(h, h)


## Sincroniza la escala del CanvasLayer con el factor de estiramiento del viewport.
## Con stretch mode canvas_items+expand el CanvasLayer no escala solo.
## Usamos el transform del viewport para obtener el factor real que Godot aplica
## al canvas 2D y replicarlo en el CanvasLayer.
func _sync_canvas_scale() -> void:
	# Con canvas_items+expand el viewport cambia de tamaño junto con la ventana.
	# get_screen_transform() siempre devuelve 1.0 porque no hay escalado interno.
	# El factor real es la relación entre la ventana actual y la resolución base.
	var win : Vector2 = get_viewport().get_visible_rect().size
	var s   : float   = min(win.x / 1920.0, win.y / 1080.0)
	print("[DialogBox] win=%s  scale=%.4f" % [win, s])
	# No tocar self.scale del CanvasLayer — el box ya escala via anchors en Root.
	# Solo aplicar el factor a fuentes y portrait que no escalan con anchors.
	_apply_scaled_props(s)


func _apply_scaled_props(s: float) -> void:
	# ── Fuentes ───────────────────────────────────────────────────────
	var base_text    : int = default_font_size if default_font_size > 0 else 42
	text_lbl.add_theme_font_size_override("normal_font_size", roundi(base_text * s))
	speaker.add_theme_font_size_override("font_size",         roundi(42 * s))

	# ── Minimum size del RichTextLabel ────────────────────────────────
	text_lbl.custom_minimum_size = Vector2(0, roundi(218.0 * s))

	# ── Portrait estático ─────────────────────────────────────────────
	var ps : float = roundi(120.0 * s)
	portrait.custom_minimum_size = Vector2(ps, ps)

	# ── Portrait animado ──────────────────────────────────────────────
	if portrait_animated.visible:
		_sync_animated_portrait_size()

func _sync_animated_portrait_size(side: String = "left") -> void:
	# Escala el AnimatedSprite2D para que ocupe el mismo espacio que el TextureRect estático.
	# Asume que el sprite tiene su origen en el centro (por defecto en Godot).
	var h     : float   = $Root/Box/HBoxContainer.size.y
	var frames          = portrait_animated.sprite_frames
	if frames == null:
		return
	var anim  : String  = portrait_animated.animation
	if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
		return
	var tex   : Texture2D = frames.get_frame_texture(anim, 0)
	if tex == null:
		return
	var tex_size : Vector2 = tex.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		var scale_factor : float = h / tex_size.y
		portrait_animated.scale  = Vector2(scale_factor, scale_factor)
	# Posicionar según el lado: izquierda → x = h*0.5, derecha → x = hbox ancho - h*0.5
	var hbox_w : float = $Root/Box/HBoxContainer.size.x
	var pos_x  : float = h * 0.5 if side == "left" else hbox_w - h * 0.5
	portrait_animated.position = Vector2(pos_x, h * 0.5)


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
	panel.show()
	Globals.playerStay = true

	# Música de diálogo
	_music_player = music_player
	if dialog_music != null and _music_player != null:
		_prev_music_stream = _music_player.stream
		_prev_music_pos    = _music_player.get_playback_position()
		_music_player.stream = dialog_music
		_music_player.play()

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

	# Portrait — soporta tres modos según el valor de "portrait":
	#   • Texture2D    → imagen estática (TextureRect)
	#   • SpriteFrames → animado, con soporte de animaciones por estado:
	#       "portrait_anim_typing" : animación mientras se escribe el texto
	#       "portrait_anim_idle"   : animación al terminar de escribir
	#       "portrait_anim"        : fallback si no se definen typing/idle
	#   • null / ausente → oculta ambos nodos
	_portrait_anim_typing = ""
	_portrait_anim_idle   = ""

	var portrait_value = page.get("portrait", null)
	var portrait_flip  : bool = page.get("portrait_flip_h", false)

	if portrait_value is SpriteFrames:
		portrait.hide()
		portrait_animated.sprite_frames = portrait_value
		portrait_animated.flip_h        = portrait_flip

		# Resolver nombres de animación con fallbacks en cascada
		var fallback : String = page.get("portrait_anim", "")
		if fallback == "" or not portrait_value.has_animation(fallback):
			fallback = portrait_value.get_animation_names()[0]

		var anim_typing : String = page.get("portrait_anim_typing", fallback)
		if not portrait_value.has_animation(anim_typing):
			anim_typing = fallback

		var anim_idle : String = page.get("portrait_anim_idle", fallback)
		if not portrait_value.has_animation(anim_idle):
			anim_idle = fallback

		_portrait_anim_typing = anim_typing
		_portrait_anim_idle   = anim_idle

		# Arrancar con la animación de typing
		portrait_animated.play(_portrait_anim_typing)
		portrait_animated.show()
		_sync_animated_portrait_size(page.get("portrait_side", "left"))
	elif portrait_value is Texture2D:
		portrait_animated.stop()
		portrait_animated.hide()
		portrait.texture  = portrait_value
		portrait.flip_h   = portrait_flip
		portrait.show()
	else:
		portrait.hide()
		portrait_animated.stop()
		portrait_animated.hide()

	# Lado del portrait — "portrait_side": "left" (default) o "right"
	# Mueve tanto el TextureRect como el AnimatedSprite2D al índice correcto del HBoxContainer.
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
	speaker.text    = page.get("speaker", "")
	speaker.visible = speaker.text != ""

	# Fuente dinámica por página
	var page_font      : Font = page.get("font",      default_font)
	var page_font_size : int  = page.get("font_size", default_font_size)

	if page_font != null:
		text_lbl.add_theme_font_override("normal_font", page_font)
	else:
		text_lbl.remove_theme_font_override("normal_font")

	if page_font_size > 0:
		text_lbl.add_theme_font_size_override("normal_font_size", page_font_size)
	else:
		text_lbl.remove_theme_font_size_override("normal_font_size")

	# Audio de typing por página
	# Acepta "beep_stream" (AudioStream o null). null = sin sonido para esta página.
	# Si la clave no existe, usa default_beep_stream.
	if page.has("beep_stream"):
		_current_beep_stream = page["beep_stream"]
	else:
		_current_beep_stream = default_beep_stream

	# Alineación de texto por página
	# Acepta "text_alignment" (HorizontalAlignment). Si no se define usa default_text_alignment.
	text_lbl.horizontal_alignment = page.get("text_alignment", default_text_alignment)

	# Texto paginado — se preservan los tags BBCode del texto original
	var raw_text : String = page.get("text", "")
	_full_text = _apply_valignment(
		_get_text_page(raw_text, page.get("text_page", 0)),
		page.get("text_valignment", default_text_valignment)
	)

	_chars_shown  = 0
	_timer        = 0.0
	_typing       = true
	_waiting      = false
	_in_choices   = false
	_beep_counter = 0

	text_lbl.bbcode_enabled = true
	text_lbl.text           = _full_text
	text_lbl.visible_ratio  = 0.0
	# Aplicar escala de fuentes y portrait para la resolución actual
	var t : Transform2D = get_viewport().get_screen_transform()
	_apply_scaled_props(t.x.length())
	arrow.hide()
	choices.hide()
	choices_bg.hide()
	_clear_choices()


# ══════════════════════════════════════════════════════════════════════
# PAGINACIÓN DE TEXTO
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
	@warning_ignore("shadowed_variable")
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

	var plain_len : int = _get_plain_length(_full_text)

	for i in add:
		if _chars_shown >= plain_len:
			break
		var ch : String = _get_plain_char(_full_text, _chars_shown)
		_chars_shown += 1
		if ch not in SKIP_CHARS:
			_beep_counter += 1
			if _beep_counter >= BEEP_EVERY:
				_beep_counter = 0
				if beep_sfx and _current_beep_stream != null and not beep_sfx.playing:
					beep_sfx.stream = _current_beep_stream
					beep_sfx.play()

	# visible_ratio respeta los tags BBCode automáticamente
	text_lbl.visible_ratio = float(_chars_shown) / float(plain_len) if plain_len > 0 else 1.0

	if _chars_shown >= plain_len:
		_typing       = false
		_waiting      = true
		_beep_counter = 0
		_portrait_play_idle()
		_on_end()


func _skip() -> void:
	_chars_shown           = _get_plain_length(_full_text)
	text_lbl.visible_ratio = 1.0
	_typing  = false
	_waiting = true
	_portrait_play_idle()
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


## Cambia el portrait animado a la animación idle si está activo.
func _portrait_play_idle() -> void:
	if portrait_animated.visible and _portrait_anim_idle != "":
		if portrait_animated.animation != _portrait_anim_idle:
			portrait_animated.play(_portrait_anim_idle)


func _advance() -> void:
	_waiting     = false
	_page_index += 1
	_show_page(_page_index)


func _close() -> void:
	panel.hide()
	choices_bg.hide()
	item_box.hide()
	# Restaurar música anterior al cerrar el diálogo
	if dialog_music != null and _music_player != null and _prev_music_stream != null:
		_music_player.stream = _prev_music_stream
		_music_player.play(_prev_music_pos)
		_prev_music_stream = null
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

	@warning_ignore("shadowed_variable")
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

	@warning_ignore("shadowed_variable")
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
	@warning_ignore("shadowed_variable")
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


# ══════════════════════════════════════════════════════════════════════
# HELPERS BBCODE
# ══════════════════════════════════════════════════════════════════════

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
func _apply_valignment(text: String, valign: VerticalAlignment) -> String:
	if valign == VERTICAL_ALIGNMENT_TOP:
		return text  # sin cambios

	# Contar líneas reales del texto (incluyendo wraps ya resueltos por _get_text_page)
	var line_count  : int = text.count("\n") + 1
	var empty_lines : int = MAX_LINES_PER_PAGE - line_count

	if empty_lines <= 0:
		return text

	@warning_ignore("integer_division")
	var pad_lines : int = empty_lines / 2 if valign == VERTICAL_ALIGNMENT_CENTER else empty_lines
	var padding   : String = "\n".repeat(pad_lines)

	match valign:
		VERTICAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM:
			return padding + text
		_:
			return text
