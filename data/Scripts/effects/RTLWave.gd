class_name RTLWave
extends RichTextEffect

# ══════════════════════════════════════════════════════════════════════
# [wave] — hace que el texto suba y baje en una onda continua, letra por
# letra (look "flotante" o "cantarín"), clásico de textos alegres/mágicos.
#
# Uso en BBCode dentro del "text" de una página de diálogo:
#
#   [wave]Este texto flota[/wave]
#
# Parámetros opcionales:
#
#   intensity : amplitud (en píxeles) del movimiento vertical — qué tan
#               alto/bajo se mueve cada letra respecto de su posición
#               normal. Default 6.0. Más alto = ondulación más exagerada.
#   speed     : velocidad de la oscilación en el tiempo. Default 5.0.
#               Más alto = ondula más rápido.
#   freq      : qué tan "apretada" es la onda a lo largo del texto (a
#               mayor valor, más letras entran en un mismo ciclo de la
#               onda, dándole un aspecto más suave/estirado; a menor
#               valor, la onda se ve más comprimida entre letras
#               consecutivas). Default 3.0.
#
#   [wave intensity=14]Muy exagerado[/wave]
#   [wave intensity=3 speed=2]Suave y lento[/wave]
#
# Nota: hay que instalarlo una vez sobre el RichTextLabel, igual que los
# demás efectos custom:
#   text_lbl.install_effect(RTLWaveScript.new())
# ══════════════════════════════════════════════════════════════════════

var bbcode := "wave"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	print("RTLWave.gd fue cargado")
	print("env recibido: ", char_fx.env)   # <- línea temporal de diagnóstico
	var intensity : float = char_fx.env.get("intensity", 6.0)
	var speed     : float = char_fx.env.get("speed", 5.0)
	var freq      : float = char_fx.env.get("freq", 3.0)

	if intensity == 0.0:
		return true
	if freq == 0.0:
		freq = 3.0

	var time  : float = char_fx.elapsed_time
	var phase : float = float(char_fx.relative_index) / freq
	var value : float = sin(time * speed + phase) * intensity

	char_fx.offset += Vector2(0, value)
	return true
