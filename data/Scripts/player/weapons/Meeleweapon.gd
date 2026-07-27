class_name MeleeWeapon
extends Weapon
## Punto 7: arma cuerpo a cuerpo (ej. "Aguijón" estilo Hollow Knight Nail).
##
## Requiere en la escena un hijo Area2D llamado "MeleeHitbox" con su
## CollisionShape2D ya dimensionado/posicionado para el swing (normalmente
## apuntando a la derecha por defecto; este script lo rota según _shoot_dir).

@export var active_window   : float = 0.12   ## segundos que el hitbox está "caliente"
@export var swing_cooldown  : float = 0.25   ## tiempo mínimo entre golpes
@export var damage_by_level : Array[int] = [2, 3, 4]  ## debe tener max_level elementos

var _hitbox        : Area2D = null
var _hit_this_swing : Array[Node] = []   ## evita pegar 2 veces al mismo enemigo en un swing
var _cooldown_timer : float = 0.0
var _active_timer   : float = 0.0
var _swinging        : bool = false


func _ready() -> void:
	super._ready()
	_hitbox = get_node_or_null("MeleeHitbox")
	if _hitbox == null:
		push_error("MeleeWeapon [%s]: falta el nodo hijo 'MeleeHitbox' (Area2D)" % weapon_name)
		return
	_hitbox.monitoring = false
	_hitbox.area_entered.connect(_on_hitbox_area_entered)
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


func weapon_process(delta: float) -> void:
	super.weapon_process(delta)  # respeta el early-return de Globals.playerStay

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _swinging:
		_active_timer -= delta
		if _active_timer <= 0.0:
			_end_swing()


## Llamar desde el input del jugador, igual que se llamaría try_shoot() en un arma a distancia.
func try_swing() -> void:
	if _swinging or _cooldown_timer > 0.0 or _hitbox == null:
		return
	if not has_ammo():   # por si alguna variante de melee gasta "munición" (ej. cargas de energía)
		return

	consume_ammo(1)
	_spawn_muzzle_flash(current_level)   # reutilizado como "efecto de swing" (punto 2)
	_play_shoot_sound(current_level)

	_swinging = true
	_hit_this_swing.clear()
	_active_timer = active_window
	_cooldown_timer = active_window + swing_cooldown

	_hitbox.rotation = _shoot_dir.angle()
	_hitbox.position = _shoot_dir * bullet_spawn_offset
	_hitbox.monitoring = true


func _end_swing() -> void:
	_swinging = false
	_hitbox.monitoring = false


func _current_damage() -> int:
	var idx : int = clamp(current_level - 1, 0, damage_by_level.size() - 1)
	return damage_by_level[idx]


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	if area in _hit_this_swing:
		return
	_hit_this_swing.append(area)

	if area.has_method("take_damage"):
		area.call("take_damage", _current_damage())

	# Punto 4: reutilizamos el "hit vfx" configurado para el nivel actual.
	var hit_scene : PackedScene = _pick_vfx(bullet_hit_by_level, bullet_hit_default, current_level)
	if hit_scene != null:
		var fx := hit_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		(fx as Node2D).global_position = area.global_position


func _on_hitbox_body_entered(body: Node) -> void:
	# Por si quieres que el melee también rompa bloques, tipo Nail contra objetos rompibles.
	if body.is_in_group("breakable_tile") and body.has_method("break_tile"):
		body.call("break_tile")


# Un arma melee no dispara balas ni tiene sentido "range de despawn de bala":
# sobreescribimos para dejar claro que _spawn_bullet no aplica aquí.
func _spawn_bullet(lvl: int) -> void:
	pass
