extends Node
## Autoload: FloatingTextManager
## Registrar en Project Settings > Autoload como "FloatingTextManager".
##
## Uso (texto genérico):
##   FloatingTextManager.show_text(player, "LEVEL UP", FloatingTextManager.Style.LEVEL_UP)
##   FloatingTextManager.show_xp_gain(player, 15)
##
## Uso (números de daño acumulativos, estilo Cave Story):
##   FloatingTextManager.show_damage(enemy, amount, FloatingTextManager.Style.DAMAGE_ENEMY, offset)
##   FloatingTextManager.show_damage(player, amount, FloatingTextManager.Style.DAMAGE_PLAYER, offset)
## `offset` es un Vector2 opcional (ej: para que el número salga arriba de
## la barra de vida en vez de sobre la cabeza del target).
##
## Si el target muere/se libera a mitad de la animación, o si te vas de
## escena, llamá FloatingTextManager.clear_damage_for(target) para limpiar
## a mano (los enemigos ya lo hacen en su _muerto()).

enum Style { LEVEL_UP, MAX_LEVEL, LEVEL_DOWN, XP_GAIN, DAMAGE_ENEMY, DAMAGE_PLAYER, DAMAGE_CRITICAL, HEAL }

## Colores y tamaños por estilo. Ajustables desde el editor si conviertes esto en @export,
## o simplemente edita el diccionario aquí.
const STYLE_CONFIG := {
	Style.LEVEL_UP:       { "color": Color(0.4, 1.0, 0.4),   "font_size": 18, "prefix": "" },
	Style.MAX_LEVEL:      { "color": Color(1.0, 0.85, 0.2),  "font_size": 20, "prefix": "" },
	Style.LEVEL_DOWN:     { "color": Color(1.0, 0.35, 0.35), "font_size": 18, "prefix": "" },
	Style.XP_GAIN:        { "color": Color(0.6, 0.85, 1.0),  "font_size": 14, "prefix": "+" },
	Style.DAMAGE_ENEMY:   { "color": Color(1.0, 0.15, 0.15), "font_size": 14, "prefix": "-" },
	Style.DAMAGE_PLAYER:  { "color": Color(1.0, 0.6, 0.1),   "font_size": 15, "prefix": "-" },
	Style.DAMAGE_CRITICAL:{ "color": Color(1.0, 0.9, 0.1),   "font_size": 18, "prefix": "-" },
	Style.HEAL:           { "color": Color(0.3, 1.0, 0.5),   "font_size": 14, "prefix": "+" },
}

@export var rise_distance   : float = 56.0   ## antes: 32.0
@export var duration        : float = 1.3    ## antes: 0.9
@export var vertical_offset : float = -12.0  ## por encima de la cabeza del nodo objetivo

## Fuente por defecto para TODOS los textos flotantes, salvo que quien
## llame a show_text()/show_xp_gain() pase una fuente puntual en `font`.
## Asignala desde el Inspector del autoload (Project Settings > Autoload).
@export var default_font : Font = null

## Tamaño extra opcional aplicado sobre el font_size de cada Style — útil
## si tu fuente custom se ve más chica/grande que la fuente por defecto
## de Godot y necesitás compensar globalmente sin tocar cada Style.
@export var font_size_offset : int = 0

@export_group("Números de daño acumulativos")
@export var dmg_display_time : float = 3.0  ## segundos sin recibir daño antes de desvanecerse
@export var dmg_fade_time    : float = 0.4  ## duración del fade al desaparecer


## Muestra un texto flotante arbitrario sobre `target` (Node2D).
## `font`: fuente puntual para ESTE texto. Si se deja null, usa default_font
## (o la fuente por defecto de Godot si tampoco hay default_font asignada).
func show_text(target: Node2D, text: String, style: Style, font: Font = null) -> void:
	if not is_instance_valid(target):
		return
	_spawn_label(target, text, style, font)


## Atajo para el número de XP ganada.
func show_xp_gain(target: Node2D, amount: int, font: Font = null) -> void:
	if amount <= 0:
		return
	_spawn_label(target, str(amount), Style.XP_GAIN, font)


func _spawn_label(target: Node2D, text: String, style: Style, font: Font = null) -> void:
	var cfg : Dictionary = STYLE_CONFIG[style]

	var label := Label.new()
	label.text = String(cfg["prefix"]) + text
	label.add_theme_color_override("font_color", cfg["color"])
	label.add_theme_font_size_override("font_size", int(cfg["font_size"]) + font_size_offset)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

	var chosen_font : Font = font if font != null else default_font
	if chosen_font != null:
		label.add_theme_font_override("font", chosen_font)

	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	get_tree().current_scene.add_child(label)
	label.global_position = target.global_position + Vector2(0, vertical_offset)
	label.pivot_offset = label.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - rise_distance, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration * 0.4)
	tween.chain().tween_callback(label.queue_free)


# ════════════════════════════════════════════════════════════════════
# ── Números de daño ACUMULATIVOS (uno por target, estilo Cave Story) ──
# ════════════════════════════════════════════════════════════════════
# Cada target (enemigo, jugador, NPC, lo que sea) tiene a lo sumo UNA
# etiqueta de daño activa. Si le pega daño de nuevo antes de que se
# desvanezca, el número se suma y el timer se reinicia. Todo esto antes
# vivía duplicado dentro de cada script de enemigo; ahora es un solo
# lugar para todos.

var _dmg_entries : Dictionary = {}   # instance_id (int) -> Dictionary

## Muestra/acumula un número de daño sobre `target`.
## `offset`: desplazamiento extra sobre la posición del target (ej: para
## ubicarlo encima de una barra de vida en vez de sobre la cabeza).
func show_damage(target: Node2D, amount: int, style: Style = Style.DAMAGE_ENEMY, offset: Vector2 = Vector2.ZERO, font: Font = null) -> void:
	if not is_instance_valid(target) or amount <= 0:
		return

	var id := target.get_instance_id()
	var entry : Dictionary

	if _dmg_entries.has(id) and is_instance_valid(_dmg_entries[id]["label"]):
		entry = _dmg_entries[id]
		if entry["fading"]:
			# Estaba desvaneciéndose: se descarta y se crea una nueva.
			entry["label"].queue_free()
			entry = _create_dmg_entry(target, style, offset, font)
	else:
		entry = _create_dmg_entry(target, style, offset, font)

	var cfg : Dictionary = STYLE_CONFIG[style]
	entry["accumulated"] += amount
	entry["timer"]   = 0.0
	entry["fading"]  = false
	entry["offset"]  = offset
	entry["label"].modulate = Color(1, 1, 1, 1)
	entry["label"].text = String(cfg["prefix"]) + str(entry["accumulated"])

	_dmg_entries[id] = entry


## Limpia a mano el número de daño de un target (ej: al morir, para que
## no quede flotando solo en el aire tras queue_free()).
func clear_damage_for(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	_clear_dmg_entry(target.get_instance_id())


func _create_dmg_entry(target: Node2D, style: Style, offset: Vector2, font: Font) -> Dictionary:
	var cfg : Dictionary = STYLE_CONFIG[style]

	var label := Label.new()
	label.add_theme_color_override("font_color", cfg["color"])
	label.add_theme_font_size_override("font_size", int(cfg["font_size"]) + font_size_offset)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100

	var chosen_font : Font = font if font != null else default_font
	if chosen_font != null:
		label.add_theme_font_override("font", chosen_font)

	get_tree().current_scene.add_child(label)
	label.global_position = target.global_position + offset

	return {
		"label": label,
		"accumulated": 0,
		"timer": 0.0,
		"fading": false,
		"target": target,
		"offset": offset,
	}


func _process(delta: float) -> void:
	if _dmg_entries.is_empty():
		return

	for id in _dmg_entries.keys():
		var entry : Dictionary = _dmg_entries[id]

		if not is_instance_valid(entry["label"]) or not is_instance_valid(entry["target"]):
			_dmg_entries.erase(id)
			continue

		if entry["fading"]:
			continue

		# Seguir al target por si se mueve (enemigo caminando, jugador, etc).
		entry["label"].global_position = entry["target"].global_position + entry["offset"]

		entry["timer"] += delta
		if entry["timer"] >= dmg_display_time:
			entry["fading"] = true
			var tween := create_tween()
			tween.tween_property(entry["label"], "modulate:a", 0.0, dmg_fade_time)
			tween.tween_callback(_clear_dmg_entry.bind(id))


func _clear_dmg_entry(id: int) -> void:
	if not _dmg_entries.has(id):
		return
	var entry : Dictionary = _dmg_entries[id]
	if is_instance_valid(entry["label"]):
		entry["label"].queue_free()
	_dmg_entries.erase(id)
