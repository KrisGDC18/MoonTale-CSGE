class_name WeaponData
extends Resource

@export var id          : String    = ""
@export var name        : String    = ""
@export var icon        : Texture2D = null
@export var max_level   : int       = 3
@export var exp_to_next : Array[int] = [10, 20, 30]  # exp necesaria por nivel

var current_level : int = 1
var current_exp   : int = 0


func add_exp(amount: int) -> void:
	if current_level >= max_level:
		return
	current_exp += amount
	while current_level < max_level and current_exp >= exp_to_next[current_level - 1]:
		current_exp -= exp_to_next[current_level - 1]
		current_level += 1


func get_exp_progress() -> float:
	if current_level >= max_level:
		return 1.0
	return float(current_exp) / float(exp_to_next[current_level - 1])
