class_name SniperArcher
extends Enemy
## Variante "inteligente" del arquero: no dispara en arco, apunta DIRECTO
## al jugador (arriba, abajo, en diagonal, lo que sea) usando la misma
## escena de flecha (arrow.tscn) que el Archer básico — solo cambia el
## método de disparo que se usa: launch_straight() en vez de launch_arc().
##
## Útil para torretas, arqueros en plataformas elevadas, o enemigos que
## disparan hacia abajo/arriba a un jugador en otro nivel de altura.

@export var arrow_scene : PackedScene = preload("res://data/Entities/enemies/bullets/arrow.tscn")

const DROP := preload("res://data/Entities/Misc/xp_point.tscn")


func _on_ready() -> void:
	MAX_HP        = 10
	damage        = 4
	cooldown      = 1.5
	vision_range  = 320.0
	attack_range  = 300.0   # rango largo y le apunta al jugador en cualquier ángulo

	var xp_entry := DropEntry.new()
	xp_entry.scene     = DROP
	xp_entry.is_xp     = true
	xp_entry.xp_min    = 1
	xp_entry.xp_max    = 3
	xp_entry.min_count = 2
	xp_entry.max_count = 3
	xp_entry.weight    = 1.0

	drop_table = DropTable.new()
	drop_table.entries = [xp_entry]


## Sobreescribe también _perseguir/_atacar sería una opción, pero alcanza
## con cambiar CÓMO dispara: apunta directo al jugador en vez de tirar
## siempre horizontal.
func _perform_attack(_direccion: float) -> void:
	if not arrow_scene or not is_instance_valid(jugador):
		return

	var arrow : Arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position
	arrow.shooter = self

	var direction_to_player : Vector2 = jugador.global_position - global_position
	arrow.launch_straight(direction_to_player)
