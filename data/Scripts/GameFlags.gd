## GameFlags.gd
## Autoload — Sistema de flags/variables de historia al estilo Cave Story.
##
## Las flags son pares String:Variant guardados globalmente.
## Se integran con SaveSystem automáticamente (serializa/deserializa).
##
## ─── Registro en Autoload ────────────────────────────────────────────
##   Project > Project Settings > Autoload
##   Nombre: GameFlags    Ruta: res://ruta/GameFlags.gd
##
## ─── Uso básico ──────────────────────────────────────────────────────
##   GameFlags.set_flag("intro_done", true)
##   if GameFlags.is_true("boss1_defeated"): ...
##   GameFlags.toggle("door_open")
##   GameFlags.increment("kill_count", 1)
##   GameFlags.get_flag("hp_capsules_collected", 0)

extends Node

# ── Estado interno ─────────────────────────────────────────────────────
var _flags : Dictionary = {}

signal flag_changed(key: String, value: Variant)


# ═══════════════════════════════════════════════════════════════════════
# ─── ESCRITURA ────────────────────────────────────────────────────────

## Establece el valor de una flag.
func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value
	emit_signal("flag_changed", key, value)


## Invierte el valor booleano de una flag (false si no existía).
func toggle(key: String) -> void:
	_flags[key] = not _flags.get(key, false)
	emit_signal("flag_changed", key, _flags[key])


## Incrementa un contador numérico. Lo crea en 0 si no existía.
func increment(key: String, amount: int = 1) -> void:
	_flags[key] = _flags.get(key, 0) + amount
	emit_signal("flag_changed", key, _flags[key])


## Decrementa un contador (nunca baja de 0 si clamp_zero = true).
func decrement(key: String, amount: int = 1, clamp_zero: bool = true) -> void:
	var current : int = _flags.get(key, 0)
	_flags[key]       = max(current - amount, 0) if clamp_zero else current - amount
	emit_signal("flag_changed", key, _flags[key])


## Borra una flag específica del registro.
func clear_flag(key: String) -> void:
	if _flags.has(key):
		_flags.erase(key)
		emit_signal("flag_changed", key, null)


# ═══════════════════════════════════════════════════════════════════════
# ─── LECTURA ──────────────────────────────────────────────────────────

## Devuelve el valor de la flag o `default` si no existe.
func get_flag(key: String, default: Variant = null) -> Variant:
	return _flags.get(key, default)


## Devuelve true si la flag existe en el registro.
func has_flag(key: String) -> bool:
	return _flags.has(key)


## Devuelve la flag interpretada como booleano (false si no existe).
func is_true(key: String) -> bool:
	return bool(_flags.get(key, false))


## Devuelve la flag interpretada como entero (0 si no existe).
func get_int(key: String) -> int:
	return int(_flags.get(key, 0))


## Devuelve la flag interpretada como String ("" si no existe).
func get_str(key: String) -> String:
	return str(_flags.get(key, ""))


# ═══════════════════════════════════════════════════════════════════════
# ─── BULK / SERIALIZACIÓN ─────────────────────────────────────────────

## Devuelve una copia de todo el diccionario de flags (para guardado).
func get_all() -> Dictionary:
	return _flags.duplicate(true)


## Reemplaza todas las flags con el diccionario dado (al cargar).
func load_from(source: Dictionary) -> void:
	_flags = source.duplicate(true)


## Elimina todas las flags (al empezar partida nueva).
func reset_all() -> void:
	_flags.clear()


# ═══════════════════════════════════════════════════════════════════════
# ─── GRUPOS DE FLAGS ──────────────────────────────────────────────────
## Útil para comprobar si se cumplieron varias condiciones de una vez.

## Devuelve true si TODAS las flags del array son verdaderas.
func all_true(keys: Array[String]) -> bool:
	for k in keys:
		if not is_true(k):
			return false
	return true


## Devuelve true si AL MENOS UNA de las flags del array es verdadera.
func any_true(keys: Array[String]) -> bool:
	for k in keys:
		if is_true(k):
			return true
	return false
