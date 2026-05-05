extends Sprite2D

var interactable     = false
var _transitioning   = false  # evita que se llame change_scene dos veces seguidas
							   # mientras el sonido y el fade están en curso

@export var next_scene_path: String
@export var pos_Change: Array

@onready var door_sfx = $door_sfx  # sonido de la puerta al teletransportar


func _ready():
	pass


@warning_ignore("unused_parameter")
func _process(delta):
	# Si el jugador presiona "Down" estando en el área de este objeto,
	# se ejecuta el cambio de escena.
	# _transitioning evita que el input se procese mientras ya está en curso
	if Input.is_action_just_pressed("Down") and interactable and not _transitioning:
		_transitioning = true
		change_scene()


@warning_ignore("unused_parameter")
func _on_area_2d_area_entered(area):
	interactable = true


@warning_ignore("unused_parameter")
func _on_area_2d_area_exited(area):
	interactable = false


func change_scene():
	# ── 1. Reproducir sonido ──────────────────────────────────────────
	door_sfx.play()

	# ── 2. Crear overlay de fade en el root ───────────────────────────
	# se añade al root y no a la puerta para que sobreviva al cambio de escena
	# CanvasLayer con layer alto garantiza que tape todo lo demás en pantalla
	var canvas  := CanvasLayer.new()
	canvas.layer = 100
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)  # negro transparente al inicio
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	# ── 3. Esperar a que termine el sonido ────────────────────────────
	

	# ── 4. Fade a negro ───────────────────────────────────────────────
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.4)
	await tween.finished

	# ── 5. Avisar a la nueva escena que debe hacer fade-in ────────────
	# la nueva escena lee este flag en su _ready y lanza el fade-in
	Globals.needs_fade_in = true

	
	# ── 6. Cambiar escena y reposicionar al jugador ───────────────────
	# el overlay en root sobrevive al cambio porque está fuera del árbol
	# de la escena actual
	get_tree().change_scene_to_file(next_scene_path)
	player.position = Vector2(pos_Change[0], pos_Change[1])
