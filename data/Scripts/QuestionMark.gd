extends Node2D
class_name SpeechBalloon

# Sistema genérico de bocadillos estilo RPG (el clásico "!", "?", notas
# musicales, gota de sudor, "Zzz", corazón, etc. que aparecen sobre la
# cabeza de un personaje). Reemplaza al viejo QuestionMark.gd de un solo
# uso — ahora cualquier NPC o el jugador puede pedir el bocadillo que
# necesite por nombre.
#
# ESTRUCTURA DE LA ESCENA:
#   SpeechBalloon (Node2D, este script)
#   └── AnimationPlayer
#         con una animación por cada entrada de BALLOON_ANIMATIONS.
#         Cada animación debe mostrar/ocultar el sprite correspondiente
#         y, al terminar, dispara animation_finished automáticamente
#         (no hace falta loop; una animación no-loop dispara el evento
#         al llegar al final).
#
# USO BÁSICO (desde cualquier script, NPC o jugador):
#   var balloon := SPEECH_BALLOON_SCENE.instantiate()
#   get_tree().root.add_child(balloon)
#   balloon.global_position = target.global_position + Vector2(0, -20)
#   balloon.show_balloon("exclamation")
#
# O más corto, usando el helper estático:
#   SpeechBalloon.spawn(SPEECH_BALLOON_SCENE, "question", npc.global_position + Vector2(0, -20))

# Mapea un nombre corto y legible al nombre real de la animación dentro
# del AnimationPlayer. Agrega aquí cada bocadillo nuevo que crees.
const BALLOON_ANIMATIONS := {
	"question":    "Huh",         # ?
	"exclamation": "Exclamation", # !
	"music":       "Music",       # ♪
	"sweat":       "Sweat",       # gota de sudor (nerviosismo/esfuerzo)
	"sleep":       "Sleep",       # Zzz
	"heart":       "Heart",       # ♥
	"dots":        "Dots",        # ...
	"anger":       "Anger",       # símbolo de enojo
}

@onready var animation_player : AnimationPlayer = $AnimationPlayer

var _has_started : bool = false

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)


## Muestra el bocadillo del tipo indicado. `type` debe ser una de las
## claves de BALLOON_ANIMATIONS (ej. "question", "exclamation", "music"...).
## Si el tipo o la animación no existen, avisa y se autodestruye sin
## romper el juego.
func show_balloon(type: String) -> void:
	if not BALLOON_ANIMATIONS.has(type):
		push_warning("SpeechBalloon: tipo de bocadillo desconocido: '%s'" % type)
		queue_free()
		return

	var anim_name : String = BALLOON_ANIMATIONS[type]
	if not animation_player.has_animation(anim_name):
		push_warning("SpeechBalloon: falta la animación '%s' en el AnimationPlayer." % anim_name)
		queue_free()
		return

	_has_started = true
	animation_player.play(anim_name)


func _on_animation_finished(_anim_name: StringName) -> void:
	if _has_started:
		call_deferred("queue_free")


## Helper estático: instancia, posiciona y muestra un bocadillo en un
## solo llamado. Devuelve la instancia por si necesitas guardarla.
static func spawn(scene: PackedScene, type: String, at_position: Vector2,
		parent: Node = null) -> Node2D:
	var balloon := scene.instantiate()
	var target_parent : Node = parent if parent else Engine.get_main_loop().current_scene
	target_parent.add_child(balloon)
	balloon.global_position = at_position
	balloon.show_balloon(type)
	return balloon
