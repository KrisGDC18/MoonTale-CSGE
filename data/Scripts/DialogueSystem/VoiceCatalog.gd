class_name VoiceCatalog
extends Resource

# ══════════════════════════════════════════════════════════════════════
# Catálogo de voces reutilizable entre diálogos y entre escenas.
#
# Cómo armarlo (una sola vez, sin código):
#   1. En el panel FileSystem: clic derecho > New Resource... > buscar
#      "VoiceCatalog" > guardarlo, por ejemplo, como
#      res://data/voices/npc_voices.tres
#   2. Abrirlo con el Inspector (doble clic) y agregar elementos al array
#      "voices": cada elemento es un VoicePreset (New Resource > VoicePreset,
#      o simplemente expandirlo inline).
#   3. Completar por cada VoicePreset su "voice_name" y los campos que se
#      quieran sobreescribir (font, font_size, type_speed, beep_stream).
#
# Cómo usarlo en DialogBox:
#   - Arrastrar el archivo .tres al campo exportado "voice_catalog" del
#     nodo DialogBox en el editor (se registran solas en _ready()), y/o
#   - Cargar uno o más catálogos por código en cualquier momento:
#       DialogBox.load_voice_catalog(preload("res://data/voices/npc_voices.tres"))
#
# Una vez registradas, se usan igual que siempre desde una página:
#   { "speaker": "Napstablook", "voice": "napstablook", "text": "oh..." }
# ══════════════════════════════════════════════════════════════════════

@export var voices : Array[VoicePreset] = []
