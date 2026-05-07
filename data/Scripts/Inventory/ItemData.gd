class_name ItemData
extends Resource

enum Type { CONSUMABLE, KEY, MISC }

@export var id          : String    = ""
@export var name        : String    = ""
@export var description : String    = ""
@export var icon        : Texture2D = null
@export var type        : Type      = Type.MISC
@export var max_stack   : int       = 9

var on_use : Callable = Callable()
