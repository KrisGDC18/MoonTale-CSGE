extends Resource
class_name ScreenEntry
## Una pantalla del overworld. A diferencia de un sistema de rejilla fija,
## el tamaño de cada pantalla se mide automáticamente de su propio
## TileMapLayer (no hay que declararlo a mano), pero la POSICIÓN en el
## mundo sí la decides tú, posicionándola a mano — como las pantallas
## pueden tener tamaños distintos, no hay forma de inferir esto solo.

@export var scene: PackedScene

## Esquina superior izquierda de esta pantalla en coordenadas de mundo.
@export var world_position: Vector2 = Vector2.ZERO

## Nombres de nodos de spawn (Marker2D u otro Node2D) que existen DENTRO
## de esta escena, para poder resolverlos aunque la pantalla todavía no
## esté cargada (ver Overworld.get_spawn_point()).
@export var spawn_names: Array[String] = []
