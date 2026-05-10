class_name NpcBase
extends CharacterBody2D

# ─── Estado base ──────────────────────────────────────────────────────
var interactable : bool = false


# ─── Entrega de armas ─────────────────────────────────────────────────
func _give_weapon(weapon_scene: PackedScene, xp_if_owned: int = 50) -> void:
	var wm = get_tree().get_first_node_in_group("weapon_manager")
	if wm == null:
		push_warning("NpcBase: no se encontró 'weapon_manager' en el árbol.")
		return
	wm.give_weapon(weapon_scene, xp_if_owned)


# ─── Entrega de ítems ────────────────────────────────────────────────
func _give_item(item: Resource) -> void:
	if item == null:
		push_warning("NpcBase: _give_item recibió un item nulo.")
		return
	PlayerInventory.add_key_item(item)


# ─── Detección de zona de interacción ─────────────────────────────────
func _on_area_2d_body_entered(_body) -> void:
	interactable = true

func _on_area_2d_body_exited(_body) -> void:
	interactable = false

func _on_area_2d_area_entered(_area: Area2D) -> void:
	interactable = true

func _on_area_2d_area_exited(_area: Area2D) -> void:
	interactable = false
