## SaveSystem.gd
## Autoload — Sistema de guardado y carga (3 slots).
##
## ─── Registro en Autoload ────────────────────────────────────────────
##   Project > Project Settings > Autoload
##   Nombre: SaveSystem    Ruta: res://ruta/SaveSystem.gd
##
## ─── Archivos guardados ──────────────────────────────────────────────
##   user://save_slot_0.json
##   user://save_slot_1.json
##   user://save_slot_2.json
##
## ─── Estructura del JSON ─────────────────────────────────────────────
##   {
##     "map_path"              : "res://...",
##     "map_name"              : "Cementerio",
##     "spawn_point"           : "Checkpoint_A",
##     "player_hp"             : 8,
##     "player_max_hp"         : 12,
##     "player_max_hp_capsules": 5,
##     "player_pos_x"          : 320.0,
##     "player_pos_y"          : 200.0,
##     "weapons"  : [ { "id": "res://weapons/PolarStar.tscn", "level": 2, "xp": 30 } ],
##     "weapon_index"          : 0,
##     "key_items"             : [ "booster2", "map_system" ],
##     "flags"                 : { "intro_done": true, ... },
##     "timestamp"             : "2025-01-01 12:00:00"
##   }
##
## ─── API pública ─────────────────────────────────────────────────────
##   SaveSystem.save_game(slot)       → guarda el estado actual en el slot
##   SaveSystem.load_game(slot)       → carga y aplica el estado del slot
##   SaveSystem.new_game(slot)        → inicia partida nueva (limpia el slot)
##   SaveSystem.slot_exists(slot)     → bool
##   SaveSystem.get_slot_info(slot)   → Dictionary con info resumida
##   SaveSystem.delete_slot(slot)
##   SaveSystem.current_slot          → int (slot activo, -1 si ninguno)

extends Node

# ── Constantes ─────────────────────────────────────────────────────────
const SLOT_COUNT   : int    = 3
const SAVE_PREFIX  : String = "user://save_slot_"
const SAVE_EXT     : String = ".json"

# ── Estado ─────────────────────────────────────────────────────────────
var current_slot       : int        = -1
var _pending_restore   : Dictionary = {}

signal save_completed(slot: int)
signal load_completed(slot: int)
signal new_game_started(slot: int)


# ═══════════════════════════════════════════════════════════════════════
# ─── RUTAS ────────────────────────────────────────────────────────────

func _slot_path(slot: int) -> String:
	return SAVE_PREFIX + str(slot) + SAVE_EXT


# ═══════════════════════════════════════════════════════════════════════
# ─── VERIFICACIÓN ─────────────────────────────────────────────────────

## Devuelve true si el archivo de guardado del slot existe.
func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## Devuelve info resumida del slot para mostrar en el menú de título.
## Claves: map_name, hp, max_hp, timestamp
## Devuelve {} si el slot no existe.
func get_slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var data := _read_raw(slot)
	return {
		"map_name"  : data.get("map_name",   "???"),
		"hp"        : data.get("player_hp",   0),
		"max_hp"    : data.get("player_max_hp", 0),
		"timestamp" : data.get("timestamp",   ""),
	}


# ═══════════════════════════════════════════════════════════════════════
# ─── NUEVO JUEGO ──────────────────────────────────────────────────────

## Inicia una partida nueva: borra el slot y resetea todo el estado global.
## La carga del mapa inicial la maneja el juego desde game_started en TitleScreen.
func new_game(slot: int) -> void:
	delete_slot(slot)
	current_slot = slot
	GameFlags.reset_all()
	_reset_inventory()
	emit_signal("new_game_started", slot)
	print("[SaveSystem] Nueva partida en slot %d." % slot)


# ═══════════════════════════════════════════════════════════════════════
# ─── GUARDAR ──────────────────────────────────────────────────────────

## Guarda el estado actual del juego en el slot indicado.
## Si slot == -1 usa current_slot.
func save_game(slot: int = -1) -> void:
	if slot < 0:
		slot = current_slot
	if slot < 0:
		push_warning("[SaveSystem] No hay slot activo para guardar.")
		return

	current_slot = slot
	var data     := _collect_state()
	_write_raw(slot, data)
	emit_signal("save_completed", slot)
	print("[SaveSystem] Guardado en slot %d — %s" % [slot, data.get("timestamp", "")])


# ═══════════════════════════════════════════════════════════════════════
# ─── CARGAR ───────────────────────────────────────────────────────────

## Carga el slot y aplica el estado al juego.
func load_game(slot: int) -> void:
	if not slot_exists(slot):
		push_warning("[SaveSystem] El slot %d no existe." % slot)
		return

	current_slot = slot
	var data     := _read_raw(slot)
	_apply_state(data)
	emit_signal("load_completed", slot)
	print("[SaveSystem] Cargado desde slot %d." % slot)


# ═══════════════════════════════════════════════════════════════════════
# ─── BORRAR ───────────────────────────────────────────────────────────

## Elimina el archivo de guardado de un slot.
func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveSystem] Slot %d eliminado." % slot)


# ═══════════════════════════════════════════════════════════════════════
# ─── RECOLECTAR ESTADO ACTUAL ─────────────────────────────────────────

func _collect_state() -> Dictionary:
	var data : Dictionary = {}

	# ── Mapa ──────────────────────────────────────────────────────────
	var level : Node = get_tree().get_first_node_in_group("level")
	if level and level.get("_current_map") and level._current_map:
		var map_node : Node = level._current_map
		data["map_path"]    = map_node.scene_file_path
		data["map_name"]    = map_node.name
		data["spawn_point"] = ""   # extiende para guardar el último checkpoint activo
	else:
		data["map_path"]    = ""
		data["map_name"]    = "Inicio"
		data["spawn_point"] = ""

	# ── Jugador ────────────────────────────────────────────────────────
	var player : Node = get_tree().get_first_node_in_group("player")
	if player:
		data["player_hp"]      = player.currentLife
		data["player_max_hp"]  = player.PLAYER_MAX_LIFE
		data["player_pos_x"]   = player.global_position.x
		data["player_pos_y"]   = player.global_position.y
	else:
		data["player_hp"]      = 3
		data["player_max_hp"]  = 12
		data["player_pos_x"]   = 0.0
		data["player_pos_y"]   = 0.0

	# ── Inventario ─────────────────────────────────────────────────────
	var inv : Node = get_node_or_null("/root/PlayerInventory")
	if inv:
		# Key items: guardamos el resource_path del .tres para poder recargarlos al cargar.
		# Formato: [ "res://items/booster2.tres", ... ]
		var key_item_paths : Array = []
		for item_data : ItemData in inv.key_items.values():
			key_item_paths.append(item_data.resource_path)
		data["key_items"]              = key_item_paths
		data["player_max_hp_capsules"] = inv.max_hp
	else:
		data["key_items"]              = []
		data["player_max_hp_capsules"] = 3

	# ── Armas (desde WeaponManager, que es la fuente de verdad) ────────
	var wm : Node = get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("get_save_data"):
		var wm_data : Dictionary = wm.get_save_data()
		data["weapons"]      = wm_data.get("weapons", [])
		data["weapon_index"] = wm_data.get("weapon_index", 0)
	else:
		data["weapons"]      = []
		data["weapon_index"] = 0

	# ── Flags ──────────────────────────────────────────────────────────
	data["flags"] = GameFlags.get_all()

	# ── Timestamp ──────────────────────────────────────────────────────
	data["timestamp"] = Time.get_datetime_string_from_system()

	return data


# ═══════════════════════════════════════════════════════════════════════
# ─── APLICAR ESTADO GUARDADO ──────────────────────────────────────────

func _apply_state(data: Dictionary) -> void:
	# 1. Flags (primero para que el resto del juego las lea correctamente)
	GameFlags.load_from(data.get("flags", {}))

	# 2. Key items y vida máxima en PlayerInventory
	var inv : Node = get_node_or_null("/root/PlayerInventory")
	if inv:
		inv.key_items.clear()
		inv.max_hp     = data.get("player_max_hp_capsules", 3)
		inv.current_hp = data.get("player_hp", 3)

		# Cada entrada en "key_items" es el resource_path del .tres.
		# Cargamos el ItemData y lo reinsertamos en inv.key_items directamente.
		for res_path : String in data.get("key_items", []):
			var item_data := ResourceLoader.load(res_path) as ItemData
			if item_data != null:
				inv.key_items[item_data.id] = item_data
			else:
				push_warning("[SaveSystem] No se pudo cargar key item: %s" % res_path)

		inv.emit_signal("inventory_changed")

	# 3. Armas: se delega completamente a WeaponManager.
	# La restauración es diferida porque WeaponManager vive en el árbol del jugador,
	# que se carga junto con el mapa en el paso 4.

	# 4. Mapa: cambiamos escena (level.gd mueve al jugador al spawn_point)
	var map_path    : String = data.get("map_path", "")
	var spawn_point : String = data.get("spawn_point", "")

	if map_path != "":
		var level : Node = get_tree().get_first_node_in_group("level")
		if level and level.has_method("change_map"):
			var map_scene := ResourceLoader.load(map_path) as PackedScene
			if map_scene:
				Globals.needs_fade_in = true
				level.change_map(map_scene, spawn_point)
			else:
				push_error("[SaveSystem] No se pudo cargar el mapa: %s" % map_path)

	# 4. Vida del jugador: se aplica diferido (tras la carga del mapa)
	_pending_restore = data
	_restore_player_deferred()


func _restore_player_deferred() -> void:
	# Espera dos frames para que change_map termine y el jugador esté listo
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.currentLife = _pending_restore.get("player_hp", player.PLAYER_MAX_LIFE)
		# Solo restaurar posición si no había spawn_point explícito
		if _pending_restore.get("spawn_point", "") == "":
			player.global_position = Vector2(
				_pending_restore.get("player_pos_x", player.global_position.x),
				_pending_restore.get("player_pos_y", player.global_position.y)
			)

	# Restaurar armas en WeaponManager (necesita que el jugador y el mapa ya existan)
	var wm := get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("restore_from_save"):
		wm.restore_from_save(_pending_restore)
	elif wm == null:
		push_warning("[SaveSystem] WeaponManager no encontrado — las armas no se restauraron.")

	_pending_restore = {}


# ═══════════════════════════════════════════════════════════════════════
# ─── HELPERS INTERNOS ─────────────────────────────────────────────────

func _write_raw(slot: int, data: Dictionary) -> void:
	var json_str : String = JSON.stringify(data, "\t")
	var file     := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
	else:
		push_error("[SaveSystem] No se pudo escribir el slot %d (error %d)."
			% [slot, FileAccess.get_open_error()])


func _read_raw(slot: int) -> Dictionary:
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if not file:
		push_error("[SaveSystem] No se pudo leer el slot %d (error %d)."
			% [slot, FileAccess.get_open_error()])
		return {}
	var content : String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err  := json.parse(content)
	if err != OK:
		push_error("[SaveSystem] Error al parsear slot %d: %s" % [slot, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	push_error("[SaveSystem] El slot %d no contiene un objeto JSON válido." % slot)
	return {}


func _reset_inventory() -> void:
	var inv : Node = get_node_or_null("/root/PlayerInventory")
	if inv:
		inv.weapons.clear()
		inv.key_items.clear()
		inv.max_hp       = 3
		inv.current_hp   = 3
		inv.weapon_index = 0
		inv.emit_signal("inventory_changed")
