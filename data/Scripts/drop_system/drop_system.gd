extends Node
## Autoload: DropSystem
## Registrar en Project Settings > Autoload como "DropSystem".
##
## Sistema de drops centralizado e independiente de quién lo llama:
## enemigos al morir, objetos destructibles (barriles, cajas, arbustos),
## cofres, o cualquier otro lugar del código que necesite "tirar cosas
## al piso" en una posición dada.
##
## ── Uso típico (con una tabla armada en el Inspector o por código) ────
##   DropSystem.spawn_table(mi_drop_table, global_position, get_parent())
##
## ── Uso puntual, sin tabla, para algo que siempre tira lo mismo ───────
##   DropSystem.spawn_scene(cofre_oro_scene, global_position, get_parent())
##
## ── Atajo para XP (o cualquier drop con propiedad xp_value) ──────────
##   DropSystem.spawn_xp(xp_scene, global_position, get_parent(), 3, 1, 2)
##   # 3 instancias, cada una con xp_value entre 1 y 2


## Tira una tabla completa (DropTable) en `at_position`, agregando los
## nodos instanciados como hijos de `parent`. Es el método que usa Enemy
## en su _spawn_death_effects(), pero sirve para cualquier otra cosa.
func spawn_table(table: DropTable, at_position: Vector2, parent: Node) -> void:
	if table == null or parent == null or table.entries.is_empty():
		return

	for i in range(maxi(table.rolls, 1)):
		if randf() > table.drop_chance:
			continue
		var entry : DropEntry = _pick_weighted(table.entries)
		if entry == null:
			continue
		_spawn_entry(entry, at_position, parent)


## Instancia una sola escena en una posición, sin pasar por ninguna
## tabla — para llamados puntuales ("por un llamado", como pediste).
func spawn_scene(scene: PackedScene, at_position: Vector2, parent: Node, is_xp: bool = false, xp_min: int = 1, xp_max: int = 3) -> Node:
	if scene == null or parent == null:
		return null

	var drop := scene.instantiate()
	parent.add_child(drop)
	drop.global_position = at_position

	if is_xp and "xp_value" in drop:
		drop.xp_value = randi_range(xp_min, xp_max)

	return drop


## Atajo para tirar N instancias de un drop de experiencia (o cualquier
## escena con propiedad xp_value), sin necesidad de armar un DropTable.
func spawn_xp(xp_scene: PackedScene, at_position: Vector2, parent: Node, count: int = 1, xp_min: int = 1, xp_max: int = 3) -> void:
	for i in range(count):
		spawn_scene(xp_scene, at_position, parent, true, xp_min, xp_max)


# ── Privado ──────────────────────────────────────────────────────────
func _pick_weighted(entries: Array[DropEntry]) -> DropEntry:
	var total := 0.0
	for e in entries:
		total += maxf(e.weight, 0.0)
	if total <= 0.0:
		return null

	var roll := randf() * total
	var acc := 0.0
	for e in entries:
		acc += maxf(e.weight, 0.0)
		if roll <= acc:
			return e
	return entries[entries.size() - 1]


func _spawn_entry(entry: DropEntry, at_position: Vector2, parent: Node) -> void:
	if entry.scene == null:
		return
	var count := randi_range(entry.min_count, entry.max_count)
	for i in range(count):
		spawn_scene(entry.scene, at_position, parent, entry.is_xp, entry.xp_min, entry.xp_max)
