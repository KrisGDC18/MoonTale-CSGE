class_name Slime
extends Enemy
## El slime ya no necesita reimplementar estados, barra de HP, número de
## daño ni la lógica de muerte/drops genérica: todo eso vive en Enemy.
## Acá solo queda lo que lo hace "un slime" en particular.

const XPDROP    := preload("res://data/Entities/Misc/xp_point.tscn")
const HEALTHDROP:= preload("res://data/Entities/Misc/health.tscn")
const DEADPUFF  := preload("res://data/Entities/particles/deadpuff.tscn")


func _on_ready() -> void:
	# Stats propias del slime. Si preferís, podés en vez de esto simplemente
	# dejar estos valores cargados desde el Inspector de la escena Slime.tscn
	# (export vars ya definidas en Enemy) y borrar este bloque entero.
	MAX_HP   = 6
	damage   = 3
	cooldown = 0.75
	movVelx  = 60.0
	movVely  = -260.0
	grav     = 980.0

	deadpuff_scene = DEADPUFF

	# Tabla de drops armada por código (alternativa: crear un recurso
	# .tres desde el editor y asignarlo directo en el Inspector de
	# Slime.tscn al campo `drop_table`, sin tocar una línea de código).
	var xp_entry := DropEntry.new()
	xp_entry.scene      = XPDROP
	xp_entry.is_xp      = true
	xp_entry.xp_min     = 1
	xp_entry.xp_max     = 3
	xp_entry.min_count  = 3
	xp_entry.max_count  = 4
	xp_entry.weight     = 1.0   # 50/50 con health_entry, igual que el pick_random() original

	var health_entry := DropEntry.new()
	health_entry.scene = HEALTHDROP
	health_entry.weight = 1.0   # 50/50 con xp_entry

	drop_table = DropTable.new()
	drop_table.entries      = [xp_entry, health_entry]
	drop_table.drop_chance  = 1.0
	drop_table.rolls        = 1
