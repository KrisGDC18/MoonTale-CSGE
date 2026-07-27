class_name Weapon
extends Node2D

# ── Señales ────────────────────────────────────────────────────────────
## Point 9 y 10: quien escuche esto (normalmente el propio Player) decide
## cuándo llamar a FloatingTextManager, pasándose a sí mismo como target.
signal leveled_up(new_level: int)
signal leveled_down(new_level: int)
signal max_level_reached()
signal xp_gained(amount: int)
signal ammo_changed(current: int, max: int)
signal out_of_ammo()

@export var weapon_name    : String    = "Weapon"
@export var max_level      : int       = 3
@export var bullet_scene   : PackedScene   ## escena de NormalBullet
@export var laser_bullet_scene : PackedScene   ## escena de LaserBullet (opcional)
@export var icon           : Texture2D

# ── Sonido de disparo ─────────────────────────────────────────────────
@export_range(0.0, 0.5) var shoot_pitch_variance : float = 0.05

# ── 1. XP configurable por arma ───────────────────────────────────────
## Tabla de XP necesaria para pasar de "índice" a "índice + 1".
## Debe tener exactamente `max_level` elementos (el último valor no se usa
## para subir de nivel, pero se mantiene por consistencia de índices).
## Ejemplo Polar Star (max_level=3): [30, 40, 10]
@export var xp_to_level : Array[int] = [30, 40, 10]

# ── 6. Munición limitada ──────────────────────────────────────────────
@export var infinite_ammo : bool = true
@export var max_ammo      : int  = 0   ## ignorado si infinite_ammo = true
var current_ammo          : int  = 0

# ── 8. Distancia de desaparición de bala, por nivel ───────────────────
## Distancia en píxeles que recorre la bala antes de autodestruirse.
## Índice 0 = nivel 1, índice 1 = nivel 2, etc. Debe tener `max_level` elementos.
## 0 o negativo = sin límite de distancia (se destruye solo por colisión / salir de cámara).
@export var bullet_range_by_level : Array[float] = [0.0, 0.0, 0.0]

# ── Daño y velocidad ajustables por arma y nivel ───────────────────────
## Overrides opcionales sobre los valores por defecto de Bullet.BULLET_DATA.
## Dejá vacío el array (tamaño 0) para no tocar nada y usar el valor base
## de cada nivel. Si lo llenás, debe tener `max_level` elementos; -1 en
## damage_by_level o -1.0 en speed_by_level en un índice puntual también
## significa "sin override para ESE nivel en particular".
@export var damage_by_level : Array[int]   = []
@export var speed_by_level  : Array[float] = []

# ── 2, 3, 4, 5. VFX configurables por arma y nivel ────────────────────
## Cada arma asigna sus propias escenas de efecto desde el Inspector,
## igual que ya hacés con bullet_scene. Cada escena es un mini .tscn
## propio (AnimatedSprite2D/Sprite2D + script OneShotVFX.gd) con SU
## PROPIA animación/textura — no hay nada compartido entre armas.
##
## Si dejás vacío el array "_by_level", todos los niveles usan "_default".
## Si querés un efecto distinto solo en el nivel 3, llenás el índice 2
## del array y dejás null los índices 0 y 1 (caen al default).
@export_group("VFX")
@export var muzzle_flash_default   : PackedScene
@export var muzzle_flash_by_level  : Array[PackedScene] = []

@export var bullet_despawn_default  : PackedScene
@export var bullet_despawn_by_level : Array[PackedScene] = []

@export var bullet_hit_default  : PackedScene
@export var bullet_hit_by_level : Array[PackedScene] = []
@export_group("")

var current_level  : int     = 1
var current_xp     : int     = 0

## Identificador único = ruta de la PackedScene (ej: "res://weapons/PolarStar.tscn").
## WeaponManager lo asigna al instanciar. Úsalo para guardar/cargar sin ningún registro externo.
var weapon_id      : String  = ""

## Devuelve el estado mínimo para SaveSystem.
func get_save_data() -> Dictionary:
	var data := { "id": weapon_id, "level": current_level, "xp": current_xp }
	if not infinite_ammo:
		data["ammo"] = current_ammo
	return data

## Aplica el estado deserializado desde SaveSystem.
func apply_save_data(d: Dictionary) -> void:
	current_level = int(clamp(d.get("level", 1), 1, max_level))
	current_xp    = int(d.get("xp", 0))
	if not infinite_ammo:
		current_ammo = int(clamp(d.get("ammo", max_ammo), 0, max_ammo))

var _shoot_dir     : Vector2 = Vector2.RIGHT
var _player        : Node    = null
## Antes era una const fija en 3 (pensada para el Polar Star). Ahora es
## exportable para que cada arma defina su propio límite de balas
## simultáneas en pantalla — la Machine Gun, por ejemplo, necesita muchas
## más que 3 para que se note la dispersión y para que el consumo real
## de munición se acerque a fire_rate en vez de quedar cuellos de botella
## por este límite.
@export var max_bullets_on_screen : int = 3
var _bullet_count  : int     = 0

@onready var animator : AnimatedSprite2D = $AnimatedSprite2D

# Cache de nodos de audio por nivel (ShootAudio1, ShootAudio2, ShootAudio3)
var _audio_nodes : Array[AudioStreamPlayer2D] = [null, null, null]

# Origen de la bala — ver _get_bullet_spawn_pos()/_get_bullet_origin_marker()
# más abajo para el sistema de marcadores por dirección.
@export var bullet_spawn_offset : float = 10.0  # distancia en píxeles como fallback final
var _bullet_origin_cache : Dictionary = {}       # nombre de nodo → Marker2D o null (ya resuelto)

# Estado de aim guardado por _update_aim(), usado para resolver qué
# marcador de origen corresponde (ver _get_bullet_origin_marker()).
var _last_facing  : int  = 0       # 0 = derecha, 1 = izquierda (igual que Player.lastDirection)
var _looking_up   : bool = false
var _looking_down : bool = false


func _ready() -> void:
	_validate_config()
	if not infinite_ammo and current_ammo == 0:
		current_ammo = max_ammo


## Comprueba en editor/arranque que los arrays por nivel tengan el tamaño correcto,
## para detectar errores de configuración temprano en vez de crashear en pleno disparo.
func _validate_config() -> void:
	if xp_to_level.size() != max_level:
		push_error("Weapon [%s]: xp_to_level debe tener %d elementos, tiene %d" \
			% [weapon_name, max_level, xp_to_level.size()])
	if bullet_range_by_level.size() != max_level:
		push_warning("Weapon [%s]: bullet_range_by_level debe tener %d elementos, tiene %d" \
			% [weapon_name, max_level, bullet_range_by_level.size()])


func init(player: Node) -> void:
	_player = player


# ── XP / niveles ───────────────────────────────────────────────────────
func add_xp(amount: int) -> void:
	if current_level >= max_level:
		return
	current_xp += amount
	xp_gained.emit(amount)  # punto 10: quien escuche esto muestra el "+N"

	var needed : int = xp_to_level[current_level - 1]
	if current_xp >= needed:
		current_xp = current_xp - needed  # conserva el excedente en vez de tirarlo a 0
		current_level = min(current_level + 1, max_level)
		_on_level_up()


func remove_xp(amount: int) -> void:
	current_xp -= amount
	if current_xp <= 0:
		if current_level > 1:
			current_level -= 1
			current_xp = xp_to_level[current_level - 1] - 1
			leveled_down.emit(current_level)
		elif current_level == 1:
			current_xp = 0


func _on_level_up() -> void:
	print("%s subio a nivel %d" % [weapon_name, current_level])
	if current_level >= max_level:
		current_xp = 0   # en el tope no queda XP "pendiente" que mostrar
		max_level_reached.emit()
	else:
		leveled_up.emit(current_level)


## Punto 9: true cuando el arma está en su nivel máximo (no queda forma
## de seguir ganando XP útil, ver add_xp()).
func is_at_absolute_max() -> bool:
	return current_level >= max_level


# ── 6. Munición ────────────────────────────────────────────────────────
func has_ammo() -> bool:
	return infinite_ammo or current_ammo > 0


func consume_ammo(amount: int = 1) -> void:
	if infinite_ammo:
		return
	current_ammo = max(current_ammo - amount, 0)
	ammo_changed.emit(current_ammo, max_ammo)
	if current_ammo == 0:
		out_of_ammo.emit()


func refill_ammo(amount: int = -1) -> void:
	if infinite_ammo:
		return
	current_ammo = max_ammo if amount < 0 else min(current_ammo + amount, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)


func weapon_process(delta: float) -> void:
	if Globals.playerStay:
		return


## Se llama SOLO en las armas que NO están equipadas actualmente (ver
## WeaponManager._process()). Pensado para lógica que debe seguir
## corriendo en segundo plano aunque el arma no esté activa — por ejemplo
## la recarga automática de munición de la Machine Gun. No hace nada por
## defecto: sobreescribí en la subclase que lo necesite.
func idle_process(_delta: float) -> void:
	pass


func reset_charge() -> void:
	pass


func _update_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	_last_facing  = last_direction
	_looking_up   = looking_up
	_looking_down = looking_down

	var facing_x : float = 1.0 if last_direction == 0 else -1.0
	if looking_up:
		_shoot_dir = Vector2.UP
	elif looking_down:
		_shoot_dir = Vector2.DOWN
	else:
		_shoot_dir = Vector2(facing_x, 0.0)


func _handle_aim(last_direction: int, looking_up: bool, looking_down: bool) -> void:
	var facing : String = "right" if last_direction == 0 else "left"
	var anim : String
	if looking_up:
		anim = "idle_%s_up" % facing
	elif looking_down:
		anim = "idle_%s_down" % facing
	else:
		anim = "idle_%s" % facing

	if animator.animation != anim:
		animator.play(anim)


# ── Obtener posición de origen de la bala ─────────────────────────────
## Busca, en orden de especificidad decreciente, un Marker2D hijo que
## defina el punto de origen para la combinación actual de facing/mirada:
##
##   1. "BulletOrigin_right_up"    (o left/down según corresponda)
##   2. "BulletOrigin_right"       (mismo facing, sin mirar arriba/abajo)
##   3. "BulletOrigin"             (genérico, compat con el sistema viejo)
##   4. fallback calculado: global_position + _shoot_dir * bullet_spawn_offset
##
## No hace falta crear los 6 marcadores — con solo "BulletOrigin" ya
## funciona igual que antes. Agregá los específicos únicamente para las
## direcciones donde el cañón del arma se vea desalineado.
func _get_bullet_spawn_pos() -> Vector2:
	var marker : Marker2D = _get_bullet_origin_marker()
	if marker != null:
		return marker.global_position
	return global_position + _shoot_dir * bullet_spawn_offset


func _get_bullet_origin_marker() -> Marker2D:
	var facing : String = "right" if _last_facing == 0 else "left"
	var suffix : String = ""
	if _looking_up:
		suffix = "_up"
	elif _looking_down:
		suffix = "_down"

	var candidates : Array[String] = [
		"BulletOrigin_%s%s" % [facing, suffix],   # ej: BulletOrigin_right_up
		"BulletOrigin_%s" % facing,                # ej: BulletOrigin_right
		"BulletOrigin",                            # genérico / compat vieja
	]

	for node_name in candidates:
		if _bullet_origin_cache.has(node_name):
			var cached = _bullet_origin_cache[node_name]
			if cached != null:
				return cached
			continue  # ya sabíamos que no existe, seguir al siguiente candidato

		var found := get_node_or_null(node_name) as Marker2D
		_bullet_origin_cache[node_name] = found
		if found != null:
			return found

	return null


# ── Reproducir sonido según nivel (1, 2 o 3) ─────────────────────────
func _play_shoot_sound(lvl: int = 1) -> void:
	var index : int = clamp(lvl - 1, 0, 2)

	if _audio_nodes[index] == null:
		_audio_nodes[index] = get_node_or_null("ShootAudio%d" % (index + 1))

	if _audio_nodes[index] == null and index > 0:
		if _audio_nodes[0] == null:
			_audio_nodes[0] = get_node_or_null("ShootAudio1")
		_audio_nodes[index] = _audio_nodes[0]

	var audio : AudioStreamPlayer2D = _audio_nodes[index]
	if audio == null:
		push_error("Weapon [%s]: no se encontró ShootAudio1" % weapon_name)
		return

	audio.pitch_scale = 1.0 + randf_range(-shoot_pitch_variance, shoot_pitch_variance)
	audio.play()


# ── 2, 5. Fogonazo en el punto de origen ──────────────────────────────
func _spawn_muzzle_flash(lvl: int) -> void:
	var scene : PackedScene = _pick_vfx(muzzle_flash_by_level, muzzle_flash_default, lvl)
	if scene == null:
		return
	var fx := scene.instantiate()
	get_tree().current_scene.add_child(fx)
	(fx as Node2D).global_position = _get_bullet_spawn_pos()
	if fx is Node2D:
		(fx as Node2D).rotation = _shoot_dir.angle()


## Helper compartido: escena específica del nivel si existe, si no, la escena
## por defecto del arma para ese efecto (fogonazo / despawn / hit).
func _pick_vfx(by_level: Array[PackedScene], default_scene: PackedScene, lvl: int) -> PackedScene:
	var index : int = lvl - 1
	if index >= 0 and index < by_level.size() and by_level[index] != null:
		return by_level[index]
	return default_scene


## Helper: valor de daño override para este nivel, o -1 si no hay override
## configurado (array vacío, índice fuera de rango, o -1 explícito en ese índice).
func _get_damage_override(lvl: int) -> int:
	var index : int = lvl - 1
	if index >= 0 and index < damage_by_level.size():
		return damage_by_level[index]
	return -1


## Igual que _get_damage_override() pero para velocidad (-1.0 = sin override).
func _get_speed_override(lvl: int) -> float:
	var index : int = lvl - 1
	if index >= 0 and index < speed_by_level.size():
		return speed_by_level[index]
	return -1.0


## Instancia la escena de bala correcta para este nivel: LaserBullet si
## BULLET_DATA lo marca como láser (y no se está forzando bala normal),
## NormalBullet en cualquier otro caso. Devuelve null (con push_error)
## si al arma le falta asignar la escena que necesita.
func _instantiate_bullet(lvl: int, force_normal: bool = false) -> Node:
	var is_laser : bool = Bullet.BULLET_DATA[lvl]["is_laser"] and not force_normal
	var scene : PackedScene = laser_bullet_scene if is_laser else bullet_scene

	if scene == null:
		var missing : String = "laser_bullet_scene" if is_laser else "bullet_scene"
		push_error("Weapon [%s]: falta asignar %s (nivel %d)" % [weapon_name, missing, lvl])
		return null

	var bullet := scene.instantiate()

	# 3, 4, 5, 8: pasamos la config visual/de rango de este nivel a la bala,
	# más los overrides de daño/velocidad si están configurados.
	# Bullet.gd debe exponer estas propiedades (ver Bullet.gd actualizado).
	if bullet.has_method("configure"):
		var despawn_range : float = 0.0
		if lvl - 1 < bullet_range_by_level.size():
			despawn_range = bullet_range_by_level[lvl - 1]
		bullet.call(
			"configure",
			despawn_range,
			_pick_vfx(bullet_despawn_by_level, bullet_despawn_default, lvl),
			_pick_vfx(bullet_hit_by_level, bullet_hit_default, lvl),
			_get_damage_override(lvl),
			_get_speed_override(lvl)
		)

	return bullet


func _spawn_bullet(lvl: int) -> void:
	push_error("Weapon._spawn_bullet() debe sobreescribirse en: %s" % weapon_name)


## Punto genérico que las armas a distancia deben llamar antes de instanciar la bala.
## Centraliza el chequeo de munición para que ninguna subclase se lo salte por accidente.
func try_shoot(lvl: int) -> void:
	if not has_ammo():
		return
	consume_ammo(1)
	_spawn_muzzle_flash(lvl)
	_play_shoot_sound(lvl)
	_spawn_bullet(lvl)
