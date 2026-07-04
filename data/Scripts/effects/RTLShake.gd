class_name RTLShake
extends RichTextEffect

# Uso: [shake level=5 speed=20]texto[/shake]
var bbcode := "shake"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var strength: float = char_fx.env.get("level", 5.0)
	var offset := Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * strength
	char_fx.offset = offset
	return true
