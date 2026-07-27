class_name RTLShake
extends RichTextEffect

# ══════════════════════════════════════════════════════════════════════
# [shake] — sacude cada letra en un jitter aleatorio (look "nervioso" o
# "con miedo", clásico de textos de diálogo con tensión).
#
# Uso en BBCode dentro del "text" de una página de diálogo:
#
#   [shake]Este texto tiembla[/shake]
#
# Parámetros opcionales:
#
#   intensity : radio (en píxeles) del jitter — qué tanto se desplaza
#               cada letra respecto de su posición normal. Default 4.0.
#               Más alto = sacudida más violenta.
#   rate      : velocidad (aprox. "cambios por segundo") a la que se
#               recalcula el jitter de cada letra. Default 20.0. Más
#               alto = tiembla más rápido/nervioso; más bajo = tiembla
#               más lento/pesado.
#
#   [shake intensity=10]Terremoto![/shake]
#   [shake intensity=2 rate=8]Tiembla suave y lento[/shake]
#
# Nota: hay que instalarlo una vez sobre el RichTextLabel, igual que los
# demás efectos custom:
#   text_lbl.install_effect(RTLShakeScript.new())
# ══════════════════════════════════════════════════════════════════════

var bbcode := "shake"


## Genera un valor pseudo-aleatorio determinístico en [-1, 1] a partir de
## un entero semilla. Determinístico = mismo "seed" siempre da el mismo
## resultado, lo cual es necesario acá: sin esto, cada letra "saltaría" a
## un valor distinto en cada frame de forma inconsistente en vez de tener
## un jitter estable dentro de cada paso discreto de tiempo.
static func _noise(seed_value: int) -> float:
	var s : int = seed_value
	s = (s << 13) ^ s
	var n : int = (s * (s * s * 15731 + 789221) + 1376312589) & 0x7fffffff
	return 1.0 - float(n) / 1073741824.0


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var intensity : float = char_fx.env.get("intensity", 4.0)
	var rate      : float = char_fx.env.get("rate", 20.0)

	if intensity <= 0.0 or rate <= 0.0:
		return true

	# "Tick" discreto de jitter (no cambia cada frame, cambia "rate" veces
	# por segundo), igual criterio que el efecto [glitch].
	var tick : int = int(char_fx.elapsed_time * rate)
	var base_seed : int = char_fx.relative_index * 928371 + tick * 57

	var offset_x : float = _noise(base_seed)
	var offset_y : float = _noise(base_seed + 1)

	char_fx.offset += Vector2(offset_x, offset_y) * intensity
	return true
