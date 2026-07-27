## SaveSystem.gd
## Autoload — Sistema de guardado y carga (3 slots).
##
## ─── Registro en Autoload ────────────────────────────────────────────
##   Project > Project Settings > Autoload
##   Nombre: SaveSystem    Ruta: res://ruta/SaveSystem.gd
##
## ─── Archivos guardados ──────────────────────────────────────────────
##   user://save_slot_0.json              <- guardado activo
##   user://save_slot_0.backup_0.json     <- respaldo mas reciente
##   user://save_slot_0.backup_1.json     <- respaldo anterior
##   user://save_slot_0.backup_2.json     <- respaldo mas antiguo
##   (idem para slots 1 y 2)
##
## ─── Sistema de respaldo ──────────────────────────────────────────────
##   Antes de cada guardado se rotan los respaldos: backup_1->backup_2,
##   backup_0->backup_1, save activo->backup_0. Se conservan los ultimos 3.
##   Si el save activo esta corrupto, load_game() intenta los backups en
##   orden (0->1->2) y avisa con push_warning cual uso.
##
## ─── Checkpoints ──────────────────────────────────────────────────────
##   El proyecto aun no tiene checkpoints, pero el sistema ya soporta
##   registrarlos para no tener que tocar el formato de save despues.
##   Cuando exista un nodo Checkpoint, solo hay que llamar:
##
##       SaveSystem.set_checkpoint("Checkpoint_A")
##
##   al activarse. Si nunca se llama, spawn_point queda "" y el sistema
##   cae de vuelta a restaurar player_pos_x/y (comportamiento actual).
##
## ─── Milestones (puntos pre-boss / post-boss / extra) ────────────────
##   Ademas de los 3 slots normales, el sistema puede guardar "fotos"
##   independientes del estado del juego, ligadas a flags de progreso.
##   Sirven para que el jugador vuelva a un punto clave (ej. justo antes
##   de un boss, justo despues, o un boss extra desbloqueado) SIN tener
##   que iniciar una partida nueva ni perder su slot principal.
##
##   Se definen en MILESTONE_TRIGGERS (mas abajo), mapeando:
##       id_del_milestone  ->  flag que lo desbloquea
##
##   Ejemplo:
##       const MILESTONE_TRIGGERS := {
##           "pre_boss1"   : "boss1_room_entered",
##           "post_boss1"  : "boss1_defeated",
##           "extra_boss1" : "boss1_extra_unlocked",
##       }
##
##   Cada vez que se llama a save_game() o check_milestones(), el sistema
##   revisa esas flags contra GameFlags. La primera vez que una flag esta
##   en true, se captura una copia del estado actual bajo ese id — y esa
##   copia ya no se vuelve a sobreescribir automaticamente (para no perder
##   el punto exacto en que ocurrio). No usan slots ni rotan backups.
##
##   Archivos: user://milestone_<id>.json
##
## ─── Estructura del JSON ─────────────────────────────────────────────
##   {
##     "save_version"          : 1,
##     "map_path"              : "res://...",
##     "map_name"              : "Cementerio",
##     "spawn_point"           : "Checkpoint_A",
##     "player_hp"             : 8,
##     "player_max_hp"         : 12,
##     "player_max_hp_capsules": 5,
##     "player_pos_x"          : 320.0,
##     "player_pos_y"          : 200.0,
##     "jetpack_equipped"      : true,
##     "jetpack_upgrade"       : false,
##     "weapons"  : [ { "id": "res://weapons/PolarStar.tscn", "level": 2, "xp": 30 } ],
##     "weapon_index"          : 0,
##     "key_items"             : [ "res://items/booster2.tres" ],
##     "flags"                 : { "intro_done": true },
##     "timestamp"             : "2025-01-01 12:00:00"
##   }
##
## ─── API pública ─────────────────────────────────────────────────────
##   SaveSystem.save_game(slot)         → guarda el estado actual en el slot
##   SaveSystem.load_game(slot)         → carga y aplica el estado del slot
##   SaveSystem.new_game(slot)          → inicia partida nueva (limpia el slot)
##   SaveSystem.slot_exists(slot)       → bool
##   SaveSystem.get_slot_info(slot)     → Dictionary con info resumida
##   SaveSystem.delete_slot(slot)
##   SaveSystem.restore_backup(slot, i) → restaura backup 0, 1 o 2
##   SaveSystem.set_checkpoint(name)    → registra el ultimo checkpoint activo
##   SaveSystem.current_slot            → int (slot activo, -1 si ninguno)
##
##   SaveSystem.check_milestones()          → captura milestones nuevos segun flags
##   SaveSystem.milestone_exists(id)        → bool
##   SaveSystem.get_milestone_info(id)      → Dictionary resumida (o {})
##   SaveSystem.list_unlocked_milestones()  → Array[String] de ids ya capturados
##   SaveSystem.load_milestone(id)          → carga ese milestone en el juego
##   SaveSystem.delete_milestone(id)        → borra el archivo del milestone

extends Node

# ── Constantes ─────────────────────────────────────────────────────────
const SLOT_COUNT   : int    = 3
const SAVE_PREFIX  : String = "user://save_slot_"
const SAVE_EXT     : String = ".json"
const BACKUP_COUNT : int    = 3
const SAVE_VERSION : int    = 1

const MILESTONE_PREFIX : String = "user://milestone_"

## Mapa id_del_milestone -> flag que lo desbloquea.
## Editar/ampliar esta tabla es la unica forma de agregar nuevos puntos
## (pre-boss, post-boss, boss extra, finales alternativos, etc.).
## El id se usa tal cual para nombrar el archivo y para mostrarlo en UI,
## asi que conviene mantenerlo legible (se puede mapear a un titulo bonito
## en la pantalla de seleccion, este id es solo la clave interna).
const MILESTONE_TRIGGERS : Dictionary = {
	"pre_boss1"   : "boss1_room_entered",
	"post_boss1"  : "boss1_defeated",
	"extra_boss1" : "boss1_extra_unlocked",
}

# ── Estado ─────────────────────────────────────────────────────────────
var current_slot       : int    = -1
var _current_checkpoint : String = ""  # ver set_checkpoint()

signal save_completed(slot: int)
signal load_completed(slot: int)
signal new_game_started(slot: int)


# ═══════════════════════════════════════════════════════════════════════
# ─── RUTAS ─────────────────────────────────────────────────────────────

func _slot_path(slot: int) -> String:
	return SAVE_PREFIX + str(slot) + SAVE_EXT

func _backup_path(slot: int, index: int) -> String:
	return SAVE_PREFIX + str(slot) + ".backup_" + str(index) + SAVE_EXT


# ═══════════════════════════════════════════════════════════════════════
# ─── VERIFICACIÓN ──────────────────────────────────────────────────────

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
	if data.is_empty():
		return {}
	return {
		"map_name"  : data.get("map_name",   "???"),
		"hp"        : data.get("player_hp",   0),
		"max_hp"    : data.get("player_max_hp", 0),
		"timestamp" : data.get("timestamp",   ""),
	}


# ═══════════════════════════════════════════════════════════════════════
# ─── CHECKPOINTS ───────────────────────────────────────────────────────

## Registra el ultimo checkpoint activado. Llamar esto desde el nodo
## Checkpoint cuando el jugador lo activa (aun no implementado en el juego).
## No hace nada mas por si solo: el valor se usa recien al guardar.
func set_checkpoint(checkpoint_name: String) -> void:
	_current_checkpoint = checkpoint_name


## Limpia el checkpoint activo (por ejemplo, al cambiar de mapa sin
## checkpoint propio, o al iniciar partida nueva).
func clear_checkpoint() -> void:
	_current_checkpoint = ""


# ═══════════════════════════════════════════════════════════════════════
# ─── NUEVO JUEGO ───────────────────────────────────────────────────────

## Inicia una partida nueva: borra el slot y resetea todo el estado global.
## La carga del mapa inicial la maneja el juego desde game_started en TitleScreen.
func new_game(slot: int) -> void:
	delete_slot(slot)
	current_slot = slot
	clear_checkpoint()
	GameFlags.reset_all()
	_reset_inventory()
	emit_signal("new_game_started", slot)
	print("[SaveSystem] Nueva partida en slot %d." % slot)


# ═══════════════════════════════════════════════════════════════════════
# ─── GUARDAR ───────────────────────────────────────────────────────────

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

	# Cada guardado normal es tambien una oportunidad de capturar milestones
	# nuevos (si alguna flag relevante ya esta en true y aun no se guardo
	# su punto). No hace falta llamar esto a mano en el flujo normal.
	check_milestones(data)


# ═══════════════════════════════════════════════════════════════════════
# ─── CARGAR ────────────────────────────────────────────────────────────

## Carga el slot y aplica el estado al juego.
func load_game(slot: int) -> void:
	if not slot_exists(slot):
		push_warning("[SaveSystem] El slot %d no existe." % slot)
		return

	current_slot = slot
	var data     := _read_raw(slot)
	if data.is_empty():
		push_error("[SaveSystem] Slot %d no se pudo cargar (vacio o corrupto)." % slot)
		return
	_apply_state(data)
	emit_signal("load_completed", slot)
	print("[SaveSystem] Cargado desde slot %d." % slot)


# ═══════════════════════════════════════════════════════════════════════
# ─── BORRAR ────────────────────────────────────────────────────────────

## Elimina el archivo de guardado de un slot.
func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveSystem] Slot %d eliminado." % slot)


# ═══════════════════════════════════════════════════════════════════════
# ─── RECOLECTAR ESTADO ACTUAL ──────────────────────────────────────────

func _collect_state() -> Dictionary:
	var data : Dictionary = {}

	data["save_version"] = SAVE_VERSION

	# ── Mapa ────────────────────────────────────────────────────────────
	var level : Node = get_tree().get_first_node_in_group("level")
	if level and level.get("_current_map") and level._current_map:
		var map_node : Node = level._current_map
		data["map_path"]    = map_node.scene_file_path
		data["map_name"]    = map_node.name
		# Si hay un checkpoint activo registrado via set_checkpoint(), se usa.
		# Si no, queda vacio y load_game restaura por posicion (player_pos_x/y).
		data["spawn_point"] = _current_checkpoint
	else:
		data["map_path"]    = ""
		data["map_name"]    = "Inicio"
		data["spawn_point"] = ""

	# ── Jugador ─────────────────────────────────────────────────────────
	var player : Node = get_tree().get_first_node_in_group("player")
	if player:
		data["player_hp"]        = player.currentLife
		data["player_max_hp"]    = player.PLAYER_MAX_LIFE
		data["player_pos_x"]     = player.global_position.x
		data["player_pos_y"]     = player.global_position.y
		data["jetpack_equipped"] = player.jetpack_equipped
		data["jetpack_upgrade"]  = player.jetpack_upgrade
	else:
		data["player_hp"]        = 3
		data["player_max_hp"]    = 12
		data["player_pos_x"]     = 0.0
		data["player_pos_y"]     = 0.0
		data["jetpack_equipped"] = false
		data["jetpack_upgrade"]  = false

	# ── Inventario ──────────────────────────────────────────────────────
	var inv : Node = get_node_or_null("/root/PlayerInventory")
	if inv:
		# Key items: guardamos el resource_path del .tres para poder recargarlos al cargar.
		var key_item_paths : Array = []
		for item_data : ItemData in inv.key_items.values():
			key_item_paths.append(item_data.resource_path)
		data["key_items"]              = key_item_paths
		data["player_max_hp_capsules"] = inv.max_hp
	else:
		data["key_items"]              = []
		data["player_max_hp_capsules"] = 3

	# ── Armas (desde WeaponManager, que es la fuente de verdad) ──────────
	var wm : Node = get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("get_save_data"):
		var wm_data : Dictionary = wm.get_save_data()
		data["weapons"]      = wm_data.get("weapons", [])
		data["weapon_index"] = wm_data.get("weapon_index", 0)
	else:
		data["weapons"]      = []
		data["weapon_index"] = 0

	# ── Flags ───────────────────────────────────────────────────────────
	data["flags"] = GameFlags.get_all()

	# ── Timestamp ───────────────────────────────────────────────────────
	data["timestamp"] = Time.get_datetime_string_from_system()

	return data


# ═══════════════════════════════════════════════════════════════════════
# ─── APLICAR ESTADO GUARDADO ───────────────────────────────────────────

func _apply_state(data: Dictionary) -> void:
	# 1. Flags (primero para que el resto del juego las lea correctamente
	#    al inicializarse: mapas, NPCs, puertas, etc.)
	GameFlags.load_from(data.get("flags", {}))

	# 2. Key items y vida máxima en PlayerInventory
	var inv : Node = get_node_or_null("/root/PlayerInventory")
	if inv:
		inv.key_items.clear()
		inv.max_hp     = data.get("player_max_hp_capsules", 3)
		inv.current_hp = data.get("player_hp", 3)

		var missing_items : int = 0
		for res_path : String in data.get("key_items", []):
			var item_data := ResourceLoader.load(res_path) as ItemData
			if item_data != null:
				inv.key_items[item_data.id] = item_data
			else:
				missing_items += 1
				push_warning("[SaveSystem] No se pudo cargar key item: %s" % res_path)

		if missing_items > 0:
			push_warning("[SaveSystem] %d objeto(s) clave no se pudieron restaurar." % missing_items)

		inv.emit_signal("inventory_changed")

	# 3. Armas: se delega completamente a WeaponManager (paso 5, diferido),
	#    porque vive en el arbol del jugador, que se crea junto con el mapa.

	# 4. Checkpoint activo: se restaura el registro interno para que, si el
	#    jugador guarda de nuevo sin pasar por otro checkpoint, no se pierda.
	_current_checkpoint = data.get("spawn_point", "")

	# 5. Mapa: cambiamos escena (level.gd mueve al jugador al spawn_point)
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

	# 6. Vida, jetpack y armas del jugador: diferido hasta que el mapa
	#    termine de cargar y el jugador exista en el arbol.
	_restore_player_deferred(data)


func _restore_player_deferred(data: Dictionary) -> void:
	await _wait_for_map_ready()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.currentLife      = data.get("player_hp", player.PLAYER_MAX_LIFE)
		player.jetpack_equipped = data.get("jetpack_equipped", false)
		player.jetpack_upgrade  = data.get("jetpack_upgrade", false)
		# Solo restaurar posición si no había spawn_point explícito
		# (con checkpoint, el propio level.change_map ya posiciono al jugador).
		if data.get("spawn_point", "") == "":
			player.global_position = Vector2(
				data.get("player_pos_x", player.global_position.x),
				data.get("player_pos_y", player.global_position.y)
			)
	else:
		push_warning("[SaveSystem] No se encontro al jugador tras cargar el mapa.")

	# Restaurar armas en WeaponManager (necesita que el jugador y el mapa ya existan)
	var wm := get_tree().get_first_node_in_group("weapon_manager")
	if wm and wm.has_method("restore_from_save"):
		wm.restore_from_save(data)
	elif wm == null:
		push_warning("[SaveSystem] WeaponManager no encontrado — las armas no se restauraron.")


## Espera a que el mapa termine de cambiar antes de tocar al jugador.
## Preferimos una señal de "level" si existe (mas confiable que contar
## frames), y caemos de vuelta a 2 process_frame si no esta disponible,
## para no romper compatibilidad con versiones previas de level.gd.
func _wait_for_map_ready() -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_signal("map_changed"):
		await level.map_changed
	else:
		await get_tree().process_frame
		await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════
# ─── MILESTONES ────────────────────────────────────────────────────────

func _milestone_path(id: String) -> String:
	return MILESTONE_PREFIX + id + SAVE_EXT


## Devuelve true si ya existe un archivo capturado para ese milestone.
func milestone_exists(id: String) -> bool:
	return FileAccess.file_exists(_milestone_path(id))


## Revisa MILESTONE_TRIGGERS contra las flags actuales y captura una copia
## del estado para cada milestone recien desbloqueado que aun no exista.
## Un milestone, una vez capturado, NO se vuelve a sobreescribir aqui — asi
## se preserva el punto exacto donde ocurrio (ej. el HP con el que el
## jugador llego al boss), aunque el jugador siga jugando y suba de nivel.
##
## `state_override`: opcional, para reusar un Dictionary ya calculado
## (save_game() se lo pasa para no recolectar el estado dos veces).
## Si se llama sin argumento, recolecta el estado actual en el momento.
func check_milestones(state_override: Dictionary = {}) -> void:
	var flags : Dictionary = GameFlags.get_all()
	var data  : Dictionary = {}

	for id : String in MILESTONE_TRIGGERS.keys():
		var flag_name : String = MILESTONE_TRIGGERS[id]
		if not flags.get(flag_name, false):
			continue
		if milestone_exists(id):
			continue

		if data.is_empty():
			data = state_override if not state_override.is_empty() else _collect_state()

		if _write_json_file(_milestone_path(id), data, "milestone %s" % id):
			print("[SaveSystem] Milestone capturado: %s (flag '%s')." % [id, flag_name])


## Info resumida de un milestone para mostrar en un menu de seleccion.
## Devuelve {} si no existe. Mismas claves que get_slot_info().
func get_milestone_info(id: String) -> Dictionary:
	var data := _read_json_file(_milestone_path(id), "milestone %s" % id)
	if data.is_empty():
		return {}
	return {
		"map_name"  : data.get("map_name",   "???"),
		"hp"        : data.get("player_hp",   0),
		"max_hp"    : data.get("player_max_hp", 0),
		"timestamp" : data.get("timestamp",   ""),
	}


## Lista los ids de milestones definidos en MILESTONE_TRIGGERS que ya
## fueron capturados (es decir, disponibles para cargar ahora mismo).
func list_unlocked_milestones() -> Array[String]:
	var result : Array[String] = []
	for id : String in MILESTONE_TRIGGERS.keys():
		if milestone_exists(id):
			result.append(id)
	return result


## Carga un milestone y lo aplica al juego, igual que load_game() pero
## sin depender de un slot. No modifica current_slot: si el jugador guarda
## despues de esto, se le debe pedir explicitamente en que slot (para no
## sobreescribir su progreso principal por accidente).
func load_milestone(id: String) -> void:
	var path := _milestone_path(id)
	if not FileAccess.file_exists(path):
		push_warning("[SaveSystem] El milestone '%s' no existe." % id)
		return

	var data := _read_json_file(path, "milestone %s" % id)
	if data.is_empty():
		push_error("[SaveSystem] El milestone '%s' esta corrupto." % id)
		return

	_apply_state(data)
	print("[SaveSystem] Cargado milestone '%s'." % id)


## Elimina el archivo de un milestone (por ejemplo, para permitir que se
## vuelva a capturar desde cero, o para liberar espacio).
func delete_milestone(id: String) -> void:
	var path := _milestone_path(id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveSystem] Milestone '%s' eliminado." % id)


# ═══════════════════════════════════════════════════════════════════════
# ─── RESPALDOS ─────────────────────────────────────────────────────────

## Rota los backups y copia el save activo como backup_0.
## backup_2 (el mas viejo) se sobreescribe, los demas avanzan un lugar.
func _rotate_backups(slot: int) -> void:
	for i in range(BACKUP_COUNT - 1, 0, -1):
		var src  := _backup_path(slot, i - 1)
		var dest := _backup_path(slot, i)
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, dest)
	var active := _slot_path(slot)
	if FileAccess.file_exists(active):
		DirAccess.copy_absolute(active, _backup_path(slot, 0))


## Restaura un backup concreto (index 0-2) como save activo.
## NOTA: si vuelves a guardar despues de restaurar un backup, la rotacion
## normal de _write_raw hara que ese mismo backup avance de posicion (esto
## es el comportamiento esperado: el backup restaurado pasa a ser el save
## activo y sigue el ciclo de rotacion normal desde ahi).
## Devuelve true si tuvo exito.
func restore_backup(slot: int, index: int) -> bool:
	var path := _backup_path(slot, index)
	if not FileAccess.file_exists(path):
		push_warning("[SaveSystem] Backup %d del slot %d no existe." % [index, slot])
		return false
	DirAccess.copy_absolute(path, _slot_path(slot))
	push_warning("[SaveSystem] Slot %d restaurado desde backup_%d." % [slot, index])
	return true


# ═══════════════════════════════════════════════════════════════════════
# ─── HELPERS INTERNOS: LECTURA / ESCRITURA ─────────────────────────────

func _write_raw(slot: int, data: Dictionary) -> void:
	_rotate_backups(slot)
	_write_json_file(_slot_path(slot), data, "slot %d" % slot)


func _read_raw(slot: int) -> Dictionary:
	var path  := _slot_path(slot)
	var label := "slot %d" % slot
	if not FileAccess.file_exists(path):
		# Slot vacio: no es un error, simplemente no hay nada que leer.
		return {}

	var result := _read_json_file(path, label)
	if result.is_empty():
		return _read_raw_fallback(slot)
	return result


## Escribe un Dictionary como JSON en una ruta arbitraria. `label` es solo
## para los mensajes de error/warning (ej. "slot 0", "milestone post_boss1").
func _write_json_file(path: String, data: Dictionary, label: String) -> bool:
	var json_str : String = JSON.stringify(data, "\t")
	var file     := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		return true
	push_error("[SaveSystem] No se pudo escribir %s (error %d)."
		% [label, FileAccess.get_open_error()])
	return false


## Lee y parsea un JSON desde una ruta arbitraria. Devuelve {} si no existe,
## no se pudo abrir, o el contenido no es un objeto JSON valido.
func _read_json_file(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] No se pudo leer %s (error %d)."
			% [label, FileAccess.get_open_error()])
		return {}

	var content : String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err  := json.parse(content)
	if err != OK:
		push_error("[SaveSystem] Error al parsear %s: %s" % [label, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data

	push_error("[SaveSystem] %s no contiene un objeto JSON valido." % label)
	return {}


## Intenta leer los backups en orden cuando el save activo es invalido.
func _read_raw_fallback(slot: int) -> Dictionary:
	for i in range(BACKUP_COUNT):
		var path := _backup_path(slot, i)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			continue
		var text : String = file.get_as_text()
		file.close()
		var json2 := JSON.new()
		if json2.parse(text) == OK and json2.data is Dictionary:
			push_warning("[SaveSystem] Slot %d corrupto, usando backup_%d." % [slot, i])
			return json2.data
	push_error("[SaveSystem] Slot %d y todos sus backups estan corruptos." % slot)
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
