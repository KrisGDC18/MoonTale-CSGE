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

	_border = NinePatchRect.new()
	_border.name                     = "Border"
	_border.texture                  = skin.get_border_texture()
	_border.patch_margin_left        = RMWindowSkin.NINE_SLICE_MARGIN
	_border.patch_margin_right       = RMWindowSkin.NINE_SLICE_MARGIN
	_border.patch_margin_top         = RMWindowSkin.NINE_SLICE_MARGIN
	_border.patch_margin_bottom      = RMWindowSkin.NINE_SLICE_MARGIN
	_border.axis_stretch_horizontal  = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.axis_stretch_vertical    = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.mouse_filter             = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	# Cursor de selección: nace oculto y con anclas libres (no full-rect),
	# porque se posiciona manualmente vía show_cursor_at() sobre un ítem de
	# menú puntual, no para cubrir todo el panel.
	_cursor = NinePatchRect.new()
	_cursor.name                     = "Cursor"
	_cursor.texture                  = skin.get_cursor_texture()
	_cursor.patch_margin_left        = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.patch_margin_right       = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.patch_margin_top         = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.patch_margin_bottom      = RMWindowSkin.NINE_SLICE_MARGIN
	_cursor.axis_stretch_horizontal  = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_cursor.axis_stretch_vertical    = NinePatchRect.AXIS_STRETCH_MODE_TILE
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
		_border.set_anchors_preset(Control.PRESET_FULL_RECT)

	if _bg != null:
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
