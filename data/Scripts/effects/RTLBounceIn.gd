class_name RTLBounceIn
extends RichTextEffect

# Uso: [bouncein dur=0.4]texto que rebota al aparecer[/bouncein]
var bbcode := "bouncein"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# elapsed_time viene en segundos desde que la letra se hizo visible
	var t: float = char_fx.elapsed_time
	var duration: float = char_fx.env.get("dur", 0.3)
	if t < duration:
		var progress := t / duration
		var bounce := absf(sin(progress * PI * 2.5)) * (1.0 - progress)
		char_fx.offset = Vector2(0, -bounce * 20.0)
	return true
