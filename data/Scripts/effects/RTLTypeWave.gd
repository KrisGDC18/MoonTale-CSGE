class_name RTLTypeWave
extends RichTextEffect

# Uso: [typewave amp=6 dur=0.25]texto[/typewave]
# Solo anima cada letra durante los primeros "dur" segundos desde que fue
# revelada por el efecto de tipeo. DialogBox.gd es responsable de llenar
# reveal_times y mantener current_time actualizado cada frame.
var bbcode := "typewave"

# { char_index: time_revealed } — lo llena DialogBox._tick() / _skip()
var reveal_times: Dictionary = {}
# Reloj externo, actualizado por DialogBox cada frame en _process()
var current_time: float = 0.0

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var idx: int = char_fx.range.x
	if not reveal_times.has(idx):
		# Todavía no fue revelado por el typing -> sin efecto
		return true

	var elapsed: float = current_time - reveal_times[idx]
	var duration: float = char_fx.env.get("dur", 0.25)

	if elapsed >= 0.0 and elapsed < duration:
		var amp: float = char_fx.env.get("amp", 6.0)
		var progress := elapsed / duration
		char_fx.offset = Vector2(0, -sin(progress * PI) * amp)

	return true
