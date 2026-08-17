class_name RMWindowSkin
extends Resource

# ══════════════════════════════════════════════════════════════════════
# Representa un "windowskin" al estilo RPG Maker XP: una única textura de
# 128x128 píxeles dividida en 4 cuadrantes de 64x64, cada uno con un rol
# fijo (este layout NO es configurable, es el estándar de RPG Maker XP):
#
#   ┌──────────────┬──────────────┐
#   │  Fondo (BG)  │    Borde     │   fila superior (y: 0-64)
#   ├──────────────┼──────────────┤
#   │  Cursor      │ Pausa/Flechas│   fila inferior (y: 64-128)
#   └──────────────┴──────────────┘
#     x: 0-64          x: 64-128
#
# - Fondo:  (0,0,64,64)  — se ESTIRA (no se tilea) para llenar el interior
#   de la ventana, igual que el motor original de RPG Maker.
# - Borde:  (64,0,64,64) — se usa como un "9-slice" con margen de 16px en
#   cada lado (16 / 32 / 16 = 64), con los bordes TILEADOS (repetidos en
#   vez de estirados), que es el aspecto clásico de patrón/línea
#   punteada de las ventanas de RPG Maker.
# - Cursor: (0,64,64,64) — mismo esquema de 9-slice que el borde, pensado
#   para remarcar una opción seleccionada en un menú con el mismo estilo.
# - Pausa/Flechas: (64,64,64,64) — subdividido en el ícono de "pausa" (el
#   indicador que aparece cuando un mensaje espera input) y 4 flechas
#   direccionales chicas para indicar scroll en menús. La sub-división
#   exacta de este cuadrante varía un poco entre versiones/variantes de
#   windowskin que circulan por la comunidad — los valores de acá son los
#   más comúnmente citados; ajustalos desde el Inspector si tu textura no
#   calza exactamente.
# ══════════════════════════════════════════════════════════════════════

const QUADRANT_SIZE      := 64
const NINE_SLICE_MARGIN  := 16

## La textura del windowskin completo (128x128 píxeles, formato clásico
## de RPG Maker XP). Importarla con filtro "Nearest" en Godot para
## conservar el aspecto pixel-art original.
@export var texture : Texture2D = null

## Rects (en píxeles, dentro de la textura completa) de los íconos de
## pausa y flechas, dentro del cuadrante D. Ajustables por si tu
## windowskin no sigue la disposición más citada.
@export var pause_rect       : Rect2 = Rect2(96, 64, 16, 16)
@export var arrow_up_rect    : Rect2 = Rect2(72, 72, 8, 8)
@export var arrow_down_rect  : Rect2 = Rect2(72, 88, 8, 8)
@export var arrow_left_rect  : Rect2 = Rect2(64, 80, 8, 8)
@export var arrow_right_rect : Rect2 = Rect2(88, 80, 8, 8)


func _make_atlas(region: Rect2) -> Texture2D:
	if texture == null:
		return null

	# NOTA: antes esto devolvía un AtlasTexture (un recorte "virtual" que
	# sigue apuntando a la imagen grande). NinePatchRect puede calcular mal
	# el 9-slice/tileado con AtlasTexture, usando como referencia el
	# tamaño de la imagen COMPLETA en vez del recorte. Para evitarlo del
	# todo, generamos acá un recorte REAL e independiente (una imagen
	# nueva de exactamente el tamaño del cuadrante).
	var src_img := texture.get_image()
	if src_img == null:
		return null
	src_img = src_img.duplicate()
	if src_img.is_compressed():
		src_img.decompress()

	var w := int(region.size.x)
	var h := int(region.size.y)
	var cropped := Image.create(w, h, false, src_img.get_format())
	cropped.blit_rect(src_img, region, Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)


## Sub-textura del fondo (0,0,64,64), pensada para estirarse dentro del
## panel (ver RMWindowSkinPanel.gd).
func get_background_texture() -> Texture2D:
	return _make_atlas(Rect2(0, 0, QUADRANT_SIZE, QUADRANT_SIZE))


## Sub-textura del borde (64,0,64,64). Pensada para un NinePatchRect con
## patch_margin_* = NINE_SLICE_MARGIN (16) en los cuatro lados, y
## axis_stretch en modo TILE para el look clásico de RPG Maker.
func get_border_texture() -> Texture2D:
	return _make_atlas(Rect2(QUADRANT_SIZE, 0, QUADRANT_SIZE, QUADRANT_SIZE))


## Sub-textura del cursor de selección (0,64,64,64), mismo esquema de
## 9-slice tileado que el borde.
func get_cursor_texture() -> Texture2D:
	return _make_atlas(Rect2(0, QUADRANT_SIZE, QUADRANT_SIZE, QUADRANT_SIZE))


## Ícono de "pausa" (el indicador de espera de input, similar al Arrow
## que ya usa DialogBox — este es el equivalente "estilo RPG Maker").
func get_pause_texture() -> Texture2D:
	return _make_atlas(pause_rect)


## Ícono de flecha direccional. direction: "up" | "down" | "left" | "right".
## Devuelve null si "direction" no es uno de esos cuatro valores.
func get_arrow_texture(direction: String) -> Texture2D:
	match direction:
		"up":
			return _make_atlas(arrow_up_rect)
		"down":
			return _make_atlas(arrow_down_rect)
		"left":
			return _make_atlas(arrow_left_rect)
		"right":
			return _make_atlas(arrow_right_rect)
		_:
			return null
