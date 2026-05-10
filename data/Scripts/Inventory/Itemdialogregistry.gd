## ItemDialogRegistry.gd
## Autoload — Registro centralizado de diálogos de inventario por ítem.
##
## Cada ítem se registra con su id y recibe:
##   - pages     : Array de páginas para el DialogBox (texto, choices, actions, etc.)
##   - on_use    : Callable opcional que se ejecuta al cerrar el diálogo
##
## Cómo añadir al proyecto:
##   Project > Project Settings > Autoload
##   Nombre: ItemDialogRegistry   Ruta: res://ruta/ItemDialogRegistry.gd
##
## Uso desde un pickup o NPC al entregar el ítem:
##   PlayerInventory.add_key_item(item)
##   # El registry ya tiene el diálogo registrado con el mismo id.
##
## Uso desde InventoryMenu (automático si llamas a get_pages):
##   var pages = ItemDialogRegistry.get_pages(item.id)
extends Node


# ── Estructura interna ─────────────────────────────────────────────────
class ItemDialog:
	var pages  : Array    = []
	var on_use : Callable = Callable()

	func _init(p: Array, u: Callable = Callable()) -> void:
		pages  = p
		on_use = u


# ── Registro ───────────────────────────────────────────────────────────
var _registry : Dictionary = {}   # { item_id : ItemDialog }


func _ready() -> void:
	_register_all()


# ══════════════════════════════════════════════════════════════════════
# REGISTRO DE ÍTEMS
# Añade aquí cada ítem con su id, páginas de diálogo y acción opcional.
# ══════════════════════════════════════════════════════════════════════

func _register_all() -> void:

	# ── Booster 2.0 ───────────────────────────────────────────────────
	register("Jet2",
		[
			{
				"text": "Motor de propulsión a chorro. ¿Qué deseas hacer?",
				"choices": ["Activar", "Desactivar", "Cancelar"],
				"actions": [
					func():
						player.jetpack_equipped = true
						player.jetpack_upgrade  = true,
					func():
						player.jetpack_equipped = false
						player.jetpack_upgrade  = false,
					Callable(),
				]
			}
		]
	)

	# ── Map System ────────────────────────────────────────────────────
	register("map_system",
		[
			{
				"speaker": "Map System",
				"text": "Muestra el mapa de la zona actual en el HUD.",
			}
		]
	)

	# ── Blade ─────────────────────────────────────────────────────────
	# Ejemplo con múltiples páginas
	register("blade",
		[
			{
				"speaker": "Blade",
				"text": "Una hoja que absorbe las almas de los enemigos.",
			},
			{
				"speaker": "Blade",
				"text": "Nivel 3: dispara hojas en abanico. Nivel MAX: invocación.",
			}
		]
	)

	# ── Agrega más ítems aquí ─────────────────────────────────────────
	# register("id_del_item", [ { "speaker": ..., "text": ... } ])


# ══════════════════════════════════════════════════════════════════════
# API pública
# ══════════════════════════════════════════════════════════════════════

## Registra o sobreescribe el diálogo de un ítem.
## Puede llamarse también desde pickups o NPCs para registros dinámicos.
func register(item_id: String, pages: Array, on_use: Callable = Callable()) -> void:
	_registry[item_id] = ItemDialog.new(pages, on_use)


## Devuelve las páginas del diálogo de un ítem, o [] si no está registrado.
func get_pages(item_id: String) -> Array:
	if _registry.has(item_id):
		return _registry[item_id].pages
	return []


## Devuelve el Callable on_use de un ítem, o Callable() si no tiene.
func get_on_use(item_id: String) -> Callable:
	if _registry.has(item_id):
		return _registry[item_id].on_use
	return Callable()


## True si el ítem tiene diálogo registrado.
func has(item_id: String) -> bool:
	return _registry.has(item_id)
