class_name RTLRainbow
extends RichTextEffect

# ══════════════════════════════════════════════════════════════════════
# [rainbow] — texto con colores de arcoíris animados, estilo Minecraft,
# en DEGRADADO a lo largo de todo el tramo envuelto por el tag (no un
# color plano por letra suelta): la primera letra y la última letra de
# lo que esté entre [rainbow]...[/rainbow] quedan en extremos distintos
# del círculo de color, con todas las letras del medio interpolando
# suavemente entre ambas — y encima todo el degradado rota con el tiempo.
#
# Dos modos, controlados con el parámetro "mode":
#
#   mode=letter (default) — el degradado se estira a lo largo de TODO
#   el texto envuelto por este tag:
#
#     [rainbow]Esto tiene un degradado completo[/rainbow]
#
#   mode=word — pensado para envolver CADA PALABRA en su propio tag por
#   separado: cada palabra tiene su propio degradado interno, pero
#   además cada palabra arranca en un punto distinto del círculo de
#   color (usando su posición dentro del texto completo como semilla),
#   para que no todas las palabras empiecen en el mismo color:
#
#     [rainbow mode=word]Esta[/rainbow] [rainbow mode=word]frase[/rainbow]
#     [rainbow mode=word]es[/rainbow] [rainbow mode=word]arcoiris[/rainbow]
#
# Parámetros opcionales:
#
#   speed      : velocidad a la que rota el degradado en el tiempo.
#                Default 1.0. 0 = degradado fijo, sin animar.
#   spread     : cuánto círculo de color (en fracción de 0 a 1) se
#                recorre a lo largo de todo el tramo envuelto por el tag.
#                Default 0.7 (un degradado bien notorio, pero sin llegar
#                a repetir el mismo color al principio y al final). Con
#                spread=1.0 se recorre el círculo completo.
#   freq       : (solo en mode=word) qué tan distinto es el punto de
#                partida del degradado de una palabra a la siguiente.
#                Default 0.15.
#   saturation : saturación del color HSV — más alto = colores más
#                intensos/vívidos. Default 1.0 (máxima intensidad).
#   value      : brillo del color HSV. Default 1.0.
#
#   [rainbow speed=2 spread=1.0]Degradado completo y rápido[/rainbow]
#   [rainbow speed=0]Degradado fijo, sin animar[/rainbow]
#
# Se combina sin problema con [speed=N] y con otros efectos custom
# (no hay conflicto de nombres: el "speed" acá es un PARÁMETRO del tag
# [rainbow ...], mientras que [speed=N] es un tag BBCode completamente
# distinto que ya se extrae aparte antes de llegar a RichTextLabel).
#
# Nota: hay que instalarlo una vez sobre el RichTextLabel, igual que los
# demás efectos custom:
#   text_lbl.install_effect(RTLRainbowScript.new())
# ══════════════════════════════════════════════════════════════════════

var bbcode := "rainbow"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var mode   : String = char_fx.env.get("mode", "letter")
	var speed  : float  = char_fx.env.get("speed", 1.0)
	var spread : float  = char_fx.env.get("spread", 0.7)
	var freq   : float  = char_fx.env.get("freq", 0.15)
	var sat    : float  = char_fx.env.get("saturation", 1.0)
	var val    : float  = char_fx.env.get("value", 1.0)

	# Largo del tramo envuelto por ESTE tag (en caracteres planos), para
	# poder ubicar a cada letra en un punto de 0.0 (primera letra) a 1.0
	# (última letra) dentro de ese tramo, sin importar si el tramo es una
	# sola palabra corta o una oración larga — el degradado siempre
	# recorre "spread" del círculo de color a lo largo de TODO el tramo.
	var span_length : int = char_fx.range.y - char_fx.range.x
	var t : float = 0.0
	if span_length > 1:
		t = float(char_fx.relative_index) / float(span_length - 1)

	# Punto de partida del degradado: en mode=word, cada palabra (cada
	# instancia separada del tag) arranca en un punto distinto del
	# círculo de color, usando su posición dentro del texto completo
	# (char_fx.range.x, constante para todas las letras de esa palabra
	# pero distinta entre palabras) como semilla.
	var base_hue : float = 0.0
	if mode == "word":
		base_hue = float(char_fx.range.x) * freq

	var hue : float = fmod(char_fx.elapsed_time * speed + base_hue + t * spread, 1.0)
	if hue < 0.0:
		hue += 1.0

	char_fx.color = Color.from_hsv(hue, sat, val, char_fx.color.a)
	return true
