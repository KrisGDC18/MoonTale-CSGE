class_name ItemData
extends Resource

## Tipos de ítem al estilo Cave Story:
## - WEAPON  : arma con niveles y EXP (Polar Star, Fireball, etc.)
## - KEY     : ítem permanente de historia / habilidad (Booster 2.0, Map System, etc.)
## - MISC    : ítem de un solo uso que desaparece al usarse (Life Capsule, etc.)
enum Type { WEAPON, KEY, MISC }

# ── Datos comunes ──────────────────────────────────────────────────────
@export var id          : String    = ""
@export var name        : String    = ""
@export var description : String    = ""
@export var icon        : Texture2D = null
@export var type        : Type      = Type.MISC

# ── Solo para WEAPON ───────────────────────────────────────────────────
## EXP necesaria para subir al nivel 2 y al nivel 3
@export var exp_to_level2 : int = 10
@export var exp_to_level3 : int = 30

## Daño base por nivel (índice 0 = nivel 1, 1 = nivel 2, 2 = nivel 3)
@export var damage        : Array[int] = [1, 2, 4]

## Cuántos disparos por segundo por nivel
@export var fire_rate     : Array[float] = [1.0, 1.5, 2.0]

## Capacidad máxima de munición (0 = infinita, ej. Blade)
@export var max_ammo      : int = 0

# ── Solo para MISC ─────────────────────────────────────────────────────
## Callback llamado cuando el jugador usa el ítem
var on_use : Callable = Callable()
