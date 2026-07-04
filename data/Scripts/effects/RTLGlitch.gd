class_name RTLGlitch
extends RichTextEffect

# ══════════════════════════════════════════════════════════════════════
# [glitch] — texto "glitcheado" con letras cambiando aleatoriamente,
# similar al texto obfuscado de Minecraft (encantamientos / yunque).
#
# Uso en BBCode dentro del "text" de una página de diálogo:
#
#   [glitch]Este texto titila[/glitch]
#
# Parámetros opcionales (todos con valor por defecto razonable):
#
#   freq  : cuántas veces por segundo cambia cada letra (default 8.0).
#           Más alto = titileo más rápido/caótico.
#   charset : set de caracteres candidatos para el glitch. Por defecto
#           usa letras, números y algunos símbolos.
#
#   [glitch freq=12]Texto muy caótico[/glitch]
#   [glitch charset=01]Binario glitcheado[/glitch]
#
# Nota: como con los demás efectos custom (RTLShake, RTLWave, etc.), hay
# que instalarlo una vez sobre el RichTextLabel:
#   text_lbl.install_effect(RTLGlitchScript.new())
# ══════════════════════════════════════════════════════════════════════

var bbcode := "glitch"

# Set de caracteres por defecto para el glitch. Se puede sobreescribir
# por instancia del tag con el parámetro "charset".
const DEFAULT_CHARSET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%&*+=?/\\"

# Tamaño de fuente nominal usado solo para resolver el índice de glyph del
# caracter aleatorio dentro de la fuente (font_get_glyph_index necesita un
# tamaño, pero para fuentes escalables el índice de glyph no cambia según
# el tamaño, así que cualquier valor razonable sirve).
const GLYPH_LOOKUP_SIZE := 32


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var freq    : float  = char_fx.env.get("freq", 8.0)
	var charset : String = char_fx.env.get("charset", DEFAULT_CHARSET)

	if charset.length() == 0 or freq <= 0.0:
		return true

	# "Tick" discreto: el caracter cambia freq veces por segundo, no cada
	# frame. Usamos elapsed_time (tiempo desde que el RichTextLabel mostró
	# este texto) para calcular en qué "paso" de glitch estamos.
	var tick : int = int(char_fx.elapsed_time * freq)

	# Semilla determinística por caracter + tick: así cada letra tiene su
	# propia secuencia de glitch (no todas cambian al mismo símbolo a la
	# vez), pero el resultado es estable dentro de un mismo tick (no
	# recalcula un valor distinto cada frame mientras dura el mismo tick).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(char_fx.relative_index) + "_" + str(tick))

	var random_char : String = charset[rng.randi_range(0, charset.length() - 1)]
	var char_code   : int    = random_char.unicode_at(0)

	# Buscar el índice de glyph correspondiente a ese caracter DENTRO de la
	# misma fuente que ya se está usando para este texto, y reemplazar el
	# glyph que se va a dibujar. Esto no cambia el string real (el layout,
	# el ancho reservado, el autoscroll, etc. siguen basados en el texto
	# original) — solo cambia qué símbolo se dibuja encima.
	var ts := TextServerManager.get_primary_interface()
	var glyph_idx : int = ts.font_get_glyph_index(char_fx.font, GLYPH_LOOKUP_SIZE, char_code, 0)
	if glyph_idx != 0:
		char_fx.glyph_index = glyph_idx

	return true
