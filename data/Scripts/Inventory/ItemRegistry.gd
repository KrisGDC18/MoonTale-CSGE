## ItemRegistry.gd
## Autoload — Registro central de recursos de ítems y armas.
##
## ─── Registro en Autoload ────────────────────────────────────────────
##   Project > Project Settings > Autoload
##   Nombre: ItemRegistry    Ruta: res://ruta/ItemRegistry.gd
##   (Debe cargarse ANTES que SaveSystem en la lista de autoloads)
##
## ─── Uso ─────────────────────────────────────────────────────────────
##   En el _ready() de cada arma / pickup, llama a:
##
##     ItemRegistry.register_weapon("polar_star",
##         preload("res://items/polar_star.tres"),   # ItemData
##         preload("res://weapons/PolarStar.tscn"))  # PackedScene del arma
##
##     ItemRegistry.register_key_item("booster2",
##         preload("res://items/booster2.tres"))     # ItemData
##
##   SaveSystem llama a:
##     ItemRegistry.get_item_data("polar_star")   → ItemData  (o null)
##     ItemRegistry.get_weapon_scene("polar_star") → PackedScene (o null)
##
## ─── Registro alternativo (por lote, desde un script inicializador) ──
##   ItemRegistry.register_weapon_batch([
##       { "id": "polar_star",
##         "data" : preload("res://items/polar_star.tres"),
##         "scene": preload("res://weapons/PolarStar.tscn") },
##       ...
##   ])

extends Node

# ── Tablas internas ────────────────────────────────────────────────────
# id → ItemData
var _item_data   : Dictionary = {
}
# id → PackedScene  (solo armas)
var _weapon_scenes : Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════
# ─── REGISTRO ─────────────────────────────────────────────────────────

## Registra un arma con su ItemData y su PackedScene.
func register_weapon(id: String, data: ItemData, scene: PackedScene) -> void:
	if id.is_empty():
		push_warning("[ItemRegistry] register_weapon: id vacío, ignorado.")
		return
	_item_data[id]      = data
	_weapon_scenes[id]  = scene


## Registra un key item (solo necesita ItemData, no tiene escena propia).
func register_key_item(id: String, data: ItemData) -> void:
	if id.is_empty():
		push_warning("[ItemRegistry] register_key_item: id vacío, ignorado.")
		return
	_item_data[id] = data


## Registra varios ítems de tipo WEAPON en un solo batch.
## Cada elemento del array debe ser: { "id", "data", "scene" }
func register_weapon_batch(entries: Array) -> void:
	for e in entries:
		register_weapon(e["id"], e["data"], e["scene"])


## Registra varios key items en un solo batch.
## Cada elemento del array debe ser: { "id", "data" }
func register_key_item_batch(entries: Array) -> void:
	for e in entries:
		register_key_item(e["id"], e["data"])


# ═══════════════════════════════════════════════════════════════════════
# ─── CONSULTA ─────────────────────────────────────────────────────────

## Devuelve el ItemData asociado al id, o null si no está registrado.
func get_item_data(id: String) -> ItemData:
	return _item_data.get(id, null)


## Devuelve la PackedScene del arma, o null si no está registrada.
func get_weapon_scene(id: String) -> PackedScene:
	return _weapon_scenes.get(id, null)


## Devuelve true si el id está registrado como arma.
func has_weapon(id: String) -> bool:
	return _weapon_scenes.has(id)


## Devuelve true si el id está registrado (arma o key item).
func has_item(id: String) -> bool:
	return _item_data.has(id)


## Lista todos los ids de armas registradas (útil para depuración).
func get_all_weapon_ids() -> Array:
	return _weapon_scenes.keys()


## Lista todos los ids registrados.
func get_all_item_ids() -> Array:
	return _item_data.keys()
