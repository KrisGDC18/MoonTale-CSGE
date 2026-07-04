class_name VoicePreset
extends Resource

# ══════════════════════════════════════════════════════════════════════
# Preset de "voz" para un personaje, pensado para armarse desde el
# Inspector de Godot (no por código) y agruparse dentro de un
# VoiceCatalog (ver VoiceCatalog.gd).
#
# Cada campo que se deje "vacío" (según el criterio de abajo) simplemente
# no sobreescribe nada: DialogBox seguirá usando la prioridad normal
# página > voz > default global del cuadro de diálogo.
# ══════════════════════════════════════════════════════════════════════

## Nombre con el que se referencia esta voz desde las páginas de diálogo,
## vía la clave "voice". Debe ser único dentro del catálogo donde se use.
## Ejemplo: "napstablook", "sans", "guardia_01".
@export var voice_name : String = ""

## Fuente de letra para esta voz. Dejar en vacío (null) para no
## sobreescribir la fuente por defecto del cuadro de diálogo.
@export var font : Font = null

## Tamaño de fuente. 0 = no sobreescribir (usa el default del cuadro).
@export var font_size : int = 0

## Velocidad de tipeo, en caracteres por segundo. 0 = no sobreescribir.
@export var type_speed : float = 0.0

## Sonido de typing (el "beep") para esta voz.
@export var beep_stream : AudioStream = null

## Si está activado, esta voz tipea SIEMPRE en silencio (sin sonido),
## incluso si "beep_stream" quedó vacío. Sin marcar esto, dejar
## "beep_stream" en null se interpreta como "no definido" (se usa el
## sonido por defecto del cuadro), no como "silenciar a propósito".
@export var silent_typing : bool = false


## Convierte este preset a un Dictionary compatible con
## DialogBox.register_voice() / DialogBox.register_voices(), incluyendo
## SOLO las claves que realmente se definieron. Esto es clave para que la
## prioridad página > voz > default siga funcionando bien: si acá
## agregáramos "font_size: 0" siempre, por ejemplo, nunca se podría caer
## al default global del cuadro para esa propiedad.
func to_dict() -> Dictionary:
	var d := {}

	if font != null:
		d["font"] = font

	if font_size > 0:
		d["font_size"] = font_size

	if type_speed > 0.0:
		d["type_speed"] = type_speed

	if silent_typing:
		d["beep_stream"] = null
	elif beep_stream != null:
		d["beep_stream"] = beep_stream

	return d
