class_name RTLWave
extends RichTextEffect

# Uso: [wave amp=10 freq=5]texto[/wave]
var bbcode := "wave"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var amplitude: float = char_fx.env.get("amp", 10.0)
	var freq: float = char_fx.env.get("freq", 5.0)
	var time := Time.get_ticks_msec() / 1000.0
	char_fx.offset = Vector2(0, sin(time * freq + char_fx.range.x * 0.5) * amplitude)
	return true
