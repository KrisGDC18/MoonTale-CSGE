class_name DropEntry
extends Resource
## Una entrada dentro de un DropTable: qué escena tirar, con qué peso
## relativo respecto a las demás entradas de la tabla, y cuántas copias.
##
## Se arma como recurso (.tres) desde el editor, o por código con
## DropEntry.new() (ver ejemplos en slime.gd / destructible_example.gd).

@export var scene : PackedScene

## Peso relativo dentro de la tabla (no hace falta que sumen 1.0/100).
## Si tenés 3 entradas con weight 3, 1, 1 → la primera sale ~60% de las
## veces que la tabla decide tirar algo.
@export var weight : float = 1.0

## Cuántas copias de esta escena tira de una vez (se sortea un valor
## entre min_count y max_count, inclusive).
@export var min_count : int = 1
@export var max_count : int = 1

## Si es true, a cada copia instanciada se le asigna una propiedad
## `xp_value` aleatoria entre xp_min/xp_max (pensado para el drop de
## experiencia, pero sirve para cualquier escena que tenga esa propiedad).
@export var is_xp  : bool = false
@export var xp_min : int  = 1
@export var xp_max : int  = 3
