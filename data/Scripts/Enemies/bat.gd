class_name Bat
extends Enemy
## Enemigo volador de ejemplo: persigue al jugador en cualquier ángulo
## (no solo horizontal), flota con un balanceo suave mientras patrulla,
## y cae por gravedad al morir para un efecto más natural.
##
## Todo el comportamiento de vuelo ya vive en Enemy (movement_type =
## FLYING activa _move_airborne_towards_player()/_hover() automáticamente) — acá solo van los
## stats propios del murciélago.

const DROP := preload("res://data/Entities/Misc/xp_point.tscn")


func _on_ready() -> void:
	MAX_HP        = 8
	damage        = 2
	cooldown      = 0.9
	movVelx       = 90.0          # también se usa como velocidad de vuelo
	vision_range  = 220.0
	attack_range  = 40.0          # ataque cuerpo a cuerpo: tiene que acercarse

	# ── Vuelo ──────────────────────────────────────────────────────
	movement_type    = MovementType.FLYING
	ai_level         = AILevel.HIGH   # esquiva obstáculos si tiene ObstacleCheck
	hover_amplitude  = 6.0        # sube/baja suave al patrullar
	hover_speed      = 2.5
	falls_on_death   = true       # cae al piso al morir, no queda flotando
	patrol_moves     = true       # también se desplaza de lado a lado al patrullar

	# El ataque melee default de Enemy (el "salto hacia el jugador" del
	# slime) funciona tal cual con movement_type=FLYING: en vez de
	# saltar, vuela un impulso hacia el jugador. No hace falta sobreescribir
	# _perform_attack a menos que quieras una animación de picada distinta.

	var xp_entry := DropEntry.new()
	xp_entry.scene     = DROP
	xp_entry.is_xp     = true
	xp_entry.xp_min    = 1
	xp_entry.xp_max    = 2
	xp_entry.min_count = 1
	xp_entry.max_count = 2
	xp_entry.weight    = 1.0

	drop_table = DropTable.new()
	drop_table.entries = [xp_entry]
