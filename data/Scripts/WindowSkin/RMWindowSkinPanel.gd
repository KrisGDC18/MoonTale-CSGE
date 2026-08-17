class_name RMWindowSkinPanel
extends Control

# ══════════════════════════════════════════════════════════════════════
# Panel de fondo estilo RPG Maker XP, reutilizable para el fondo de
# CUALQUIER ventana o menú — y, si se quiere, también para el propio
# DialogBox (ver nota de integración al final de este archivo).
#
# Uso:
#   1. Agregar este script a un Control (o instanciar una escena que lo
#      use) con el tamaño/posición que tenga que ocupar la ventana.
#   2. Asignarle un recurso RMWindowSkin en el campo exportado "skin"
#      (con su textura de 128x128 ya cargada — ver RMWindowSkin.gd).
#   3. Listo: arma automáticamente el fondo (estirado) + el borde
#      (9-slice tileado, estilo RPG Maker) y los mantiene actualizados
#      si el panel cambia de tamaño en cualquier momento.
#
# También expone show_cursor_at()/hide_cursor() para remarcar una
# selección (p. ej. un ítem de menú) con el mismo estilo del windowskin,
# útil si este panel se usa como fondo de un menú de opciones.
# ══════════════════════════════════════════════════════════════════════

@export var skin : RMWindowSkin = null :
	set(value):
		skin = value
		_rebuild()

## Margen (en píxeles, sin escalar por resolución) entre el borde exterior
## de la ventana y el fondo interior — imita el padding clásico de RPG
## Maker, donde el fondo estirado no llega hasta el filo externo del borde.
@export var background_inset : int = 4

## Transparencia del FONDO del windowskin (0 = invisible, 1 = opaco). Afecta
## solo al fondo, no al borde ni al cursor — pensado para diálogos o menús
## semitransparentes sin perder la nitidez del marco. Ajustable en vivo
## desde el Inspector o por código con set_background_alpha().
@export_range(0.0, 1.0, 0.01) var background_alpha : float = 1.0 :
	set(value):
		background_alpha = clampf(value, 0.0, 1.0)
		_apply_background_alpha()

var _bg     : TextureRect   = null
var _border : NinePatchRect = null
var _cursor : NinePatchRect = null


func _ready() -> void:
	_rebuild()
	resized.connect(_layout_children)


## Reconstruye los nodos internos desde cero. Se llama automáticamente al
## asignar "skin" (incluso en tiempo de ejecución, para cambiar de piel).
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_bg     = null
	_border = null
	_cursor = null

	if skin == null or skin.texture == null:
		return

	_bg = TextureRect.new()
	_bg.name              = "Background"
	_bg.texture           = skin.get_background_texture()
	_bg.stretch_mode      = TextureRect.STRETCH_SCALE
	_bg.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_apply_background_alpha()

	_border = NinePatchRect.new()
	_border.name                     = "Border"
	_border.texture                  = skin.get_border_texture()
	# FIX: NinePatchRect no siempre respeta la región de un AtlasTexture al
	# tilear los bordes (bug conocido de Godot) — sin esto, el 9-slice usa
	# como referencia la textura COMPLETA (128x128) en vez del recorte real
	# (64x64), y el marco se ve comprimido/mal ubicado sin importar el
	# tamaño del panel. Fijar region_rect explícitamente lo soluciona.
	if _border.texture != null:
		_border.region_rect = Rect2(Vector2.ZERO, _border.texture.get_size())
	_border.patch_margin_left        = RMWindowSkin.NINE_SLICE_MARGIN
	_border.patch_margin_right       = RMWindowSkin.NINE_SLICE_MARGIN
	_border.patch_margin_top         = RMWindowSkin.NINE_SLICE_MARGIN
	_border.patch_margin_bottom      = RMWindowSkin.NINE_SLICE_MARGIN
	# STRETCH en vez de TILE: es el modo más simple y confiable de 9-slice
	# en Godot. TILE es el que más problemas viene dando — lo sacamos de
	# la ecuación para garantizar que el marco se expanda correctamente.
	# Si querés volver al look "punteado" clásico de RPG Maker más
	# adelante, cambiá estas dos líneas de vuelta a
	# NinePatchRect.AXIS_STRETCH_MODE_TILE una vez confirmado que esto
	# funciona.
	_border.axis_stretch_horizontal  = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.axis_stretch_vertical    = NinePatchRect.AXIS_STRETCH_MODE_TILE
	# El centro (32x32) de tu textura de borde tiene contenido propio (no
	# transparente), y en modo TILE ese centro también se dibuja/repite
	# para rellenar el interior — tapando todo con ese patrón. Como el
	# fondo real ya lo pinta _bg por debajo, directamente no dibujamos el
	# centro del borde.
	_border.draw_center              = false
	_border.mouse_filter             = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	# Cursor de selección: nace oculto y con anclas libres (no full-rect),
	# porque se posiciona manualmente vía show_cursor_at() sobre un ítem de
	# menú puntual, no para cubrir todo el panel.
	_cursor = NinePatchRect.new()
	_cursor.name                     = "Cursor"
	_cursor.texture                  = skin.get_cursor_texture()
	# Mismo fix que en _border: forzar region_rect para que el 9-slice use
	# el recorte real del cursor (64x64) y no la textura completa.
	if _cursor.texture != null:
		_cursor.region_rect = Rect2(Vector2.ZERO, _cursor.texture.get_size())
	_cursor.patch_margin_left        = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.patch_margin_right       = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.patch_margin_top         = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.patch_margin_bottom      = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.axis_stretch_horizontal  = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_cursor.axis_stretch_vertical    = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_cursor.draw_center              = false
	_cursor.mouse_filter             = Control.MOUSE_FILTER_IGNORE
	_cursor.hide()
	add_child(_cursor)

	_layout_children()


## Reajusta fondo y borde para que cubran el panel completo (con el
## "background_inset" aplicado al fondo). Se llama cada vez que el panel
## cambia de tamaño (señal "resized"). El cursor NO se re-ancla acá a
## propósito: su posición/tamaño los controla show_cursor_at().
func _layout_children() -> void:
	if _border != null:
		# Seteo manual y explícito en vez de set_anchors_preset(): así no
		# depende de cómo esa función decida (o no) resetear los offsets.
		_border.anchor_left   = 0.0
		_border.anchor_top    = 0.0
		_border.anchor_right  = 1.0
		_border.anchor_bottom = 1.0
		_border.offset_left   = 0.0
		_border.offset_top    = 0.0
		_border.offset_right  = 0.0
		_border.offset_bottom = 0.0

	if _bg != null:
		_bg.anchor_left   = 0.0
		_bg.anchor_top    = 0.0
		_bg.anchor_right  = 1.0
		_bg.anchor_bottom = 1.0
		_bg.offset_left   = background_inset
		_bg.offset_top    = background_inset
		_bg.offset_right  = -background_inset
		_bg.offset_bottom = -background_inset


## Muestra el marco de "cursor" (mismo aspecto del windowskin) sobre el
## rect indicado, en coordenadas LOCALES a este panel. Pensado para
## remarcar un ítem de menú seleccionado — llamalo de nuevo cada vez que
## cambie la selección o el layout del menú.
func show_cursor_at(local_rect: Rect2) -> void:
	if _cursor == null:
		return
	_cursor.position = local_rect.position
	_cursor.size     = local_rect.size
	_cursor.show()


func hide_cursor() -> void:
	if _cursor != null:
		_cursor.hide()


## Aplica "background_alpha" al color de modulación del fondo (solo el
## fondo — el borde y el cursor quedan siempre 100% opacos).
func _apply_background_alpha() -> void:
	if _bg != null:
		_bg.modulate.a = background_alpha


## Cambia la transparencia del fondo en tiempo real (0.0 a 1.0). Útil para
## fades por código, por ejemplo:
##   var t := create_tween()
##   t.tween_method(set_background_alpha, 1.0, 0.3, 0.4)
func set_background_alpha(value: float) -> void:
	background_alpha = value  # dispara el setter -> _apply_background_alpha()


# ══════════════════════════════════════════════════════════════════════
# Nota de integración con DialogBox (opcional, no aplicada automáticamente
# — este sistema es independiente a propósito):
#
# Para que el cuadro de diálogo use un windowskin en vez de (o además de)
# su NinePatchRect "panel" actual, alcanza con agregar una instancia de
# este script como fondo DETRÁS del contenido de "Box" (Speaker/HBoxContainer/
# Arrow/etc.), del mismo tamaño que el NinePatchRect "panel", y ocultar o
# quitar el NinePatchRect original. DialogBox.gd no necesita ningún cambio
# para esto: el windowskin es puramente visual, por debajo del resto de
# los nodos que ya maneja el script.
# ══════════════════════════════════════════════════════════════════════
