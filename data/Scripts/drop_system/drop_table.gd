class_name DropTable
extends Resource
## Tabla de drops: un conjunto de DropEntry con pesos relativos entre sí.
## Se arma como recurso (.tres) reutilizable — el mismo DropTable se
## puede asignar a varios enemigos u objetos distintos, o cada uno puede
## tener el suyo. También se puede armar 100% por código (ver ejemplos).

@export var entries : Array[DropEntry] = []

## Probabilidad (0.0–1.0) de que CADA tirada realmente suelte algo.
## 1.0 = siempre suelta algo (si hay entradas). 0.3 = 30% de las veces.
@export_range(0.0, 1.0) var drop_chance : float = 1.0

## Cuántas veces se "rollea" la tabla por cada llamado a DropSystem.
## Con rolls=2 podés sacar, por ejemplo, dos entradas distintas (o la
## misma dos veces) en una sola muerte/destrucción.
@export var rolls : int = 1
