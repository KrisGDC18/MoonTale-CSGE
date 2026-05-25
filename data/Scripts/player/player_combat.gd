# ═══════════════════════════════════════════════════════════════════════
# player_combat.gd — Componente de combate
#
# Responsabilidades:
#   • Recibir daño (take_damage)
#   • Muerte y secuencia de flash de muerte
#   • Diálogo de muerte (continuar / reiniciar)
#   • I-frames y flash de invencibilidad
#   • Knockback
#   • Label flotante de daño
# ═══════════════════════════════════════════════════════════════════════
extends PlayerMovement
class_name PlayerCombat


# ═══════════════════════════════════════════════════════════════════════
# ─── Motor de daño ────────────────────────────────────────────────────

func take_damage(amount: int, source_global_pos: Vector2,
				 ignore_iframes: bool = false, apply_knockback: bool = true,
				 is_drowning: bool = false) -> void:
	if (not ignore_iframes and _is_invincible) or playerDead:
		return

	currentLife = max(currentLife - amount, 0)
	hurt_sfx.play()
	_spawn_damage_label(amount)

	if currentLife <= 0:
		_die(is_drowning)
	else:
		if apply_knockback:
			_apply_knockback(source_global_pos)
		if is_drowning:
			_is_invincible    = true
			_iframes_timer    = AIR_DMG_INTERVAL
			_flash_timer      = 0.0
			_iframes_drowning = true
		else:
			remove_weapon_xp(amount)


# ═══════════════════════════════════════════════════════════════════════
# ─── Muerte ───────────────────────────────────────────────────────────

func _die(is_drowning: bool = false) -> void:
	if playerDead:
		return

	playerDead           = true
	_is_invincible       = true
	velocity             = Vector2.ZERO
	_knockback_timer     = 0.0
	_reset_booster_state()
	_death_phase         = 0
	_death_flash_timer   = 0.0
	_death_respawn_timer = 0.0
	if booster_sfx.playing:  booster_sfx.stop()
	if booster2_sfx.playing: booster2_sfx.stop()

	var idle_anim := "IdleLeft" if lastDirection == 1 else "IdleRight"
	animator.play(idle_anim)

	if is_drowning:
		animator.modulate = Color(0.55, 0.78, 1.0, 1.0)
		death_drown_sfx.play()
	else:
		_death_phase       = 1
		_death_flash_timer = 0.0
		animator.modulate  = Color(1.0, 0.0, 0.0, 1.0)
		death_sfx.play()


func _update_death_flash(delta: float) -> void:
	if _death_phase == 0:
		return

	_death_flash_timer += delta

	if _death_phase == 1:
		var t := minf(_death_flash_timer / 0.3, 1.0)
		animator.modulate = Color(1.0, t, t, 1.0)
		if t >= 1.0:
			_death_phase       = 2
			_death_flash_timer = 0.0

	elif _death_phase == 2:
		if _death_flash_timer >= 0.5:
			_death_phase       = 3
			_death_flash_timer = 0.0
			animator.modulate  = Color(1.0, 1.0, 1.0, 0.0)

	elif _death_phase == 3:
		if _death_flash_timer >= 0.3:
			_death_phase = 4
			_show_death_dialog()


func _show_death_dialog() -> void:
	var action_positive := func():
		if death_dialog_positive_action.is_valid():
			death_dialog_positive_action.call()
			canContinue = true
		else:
			_load_save_with_fade()

	var action_negative := func():
		var am := get_tree().get_first_node_in_group("audio_manager")
		if am:
			am.stop()
		global_position   = Vector2(-99999.0, -99999.0)
		velocity          = Vector2.ZERO
		visible           = false
		playerDead        = false
		_death_phase      = 0
		_is_invincible    = false
		animator.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var title := get_tree().get_first_node_in_group("title_screen")
		if title and title.has_method("show_menu"):
			title.call_deferred("show_menu")

	var bloques := {
		"muerte": [
			{
				"text":          "¿Qué deseas hacer?",
				"choices":       ["Continuar", "Reiniciar"],
				"target_blocks": [null, null],
				"actions":       [action_positive, action_negative]
			}
		]
	}
	DialogBox.start(bloques, "muerte", false)


# ═══════════════════════════════════════════════════════════════════════
# ─── Knockback ────────────────────────────────────────────────────────

func _apply_knockback(source_global_pos: Vector2) -> void:
	var knock_dir := signf(global_position.x - source_global_pos.x)
	if knock_dir == 0:
		knock_dir = -1.0 if lastDirection == 1 else 1.0

	velocity.x        = knock_dir * KNOCKBACK_SPEED_X
	velocity.y        = -KNOCKBACK_SPEED_Y
	_knockback_timer  = KNOCKBACK_DURATION
	_is_invincible    = true
	_iframes_timer    = IFRAMES_DURATION
	_flash_timer      = 0.0
	_iframes_drowning = false
	checking          = false
	hasChecked        = false


# ═══════════════════════════════════════════════════════════════════════
# ─── I-frames ─────────────────────────────────────────────────────────

func _update_iframes(delta: float) -> void:
	if not _is_invincible:
		animator.modulate = Color(1, 1, 1, 1)
		return

	_iframes_timer -= delta

	if _iframes_timer <= 0.0:
		_is_invincible    = false
		_iframes_timer    = 0.0
		_flash_timer      = 0.0
		_iframes_drowning = false
		animator.modulate = Color(1, 1, 1, 1)
		return

	_flash_timer += delta
	if _flash_timer >= IFRAMES_FLASH_RATE:
		_flash_timer = 0.0
		if animator.modulate.a > 0.5:
			animator.modulate = Color(1, 1, 1, 0)
		else:
			animator.modulate = Color(0.7, 0.2, 1.0, 1.0) if _iframes_drowning \
								else Color(1.0, 0.3, 0.3, 1.0)


# ═══════════════════════════════════════════════════════════════════════
# ─── Label flotante de daño ───────────────────────────────────────────

func _spawn_damage_label(amount: int) -> void:
	var label               := Label.new()
	label.text               = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12))
	label.add_theme_font_override("font", _damage_font)
	label.add_theme_font_size_override("font_size", 20)
	label.z_index            = 10
	label.global_position    = global_position - Vector2(8.0, 16.0)
	get_tree().root.add_child(label)

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 30.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


# ═══════════════════════════════════════════════════════════════════════
# ─── Señal de daño por cuerpo ─────────────────────────────────────────

func _on_damage_detect_body_entered(body: Node2D) -> void:
	var amount : int = 127
	if body.get("damage") != null:
		amount = body.damage
	take_damage(amount, body.global_position)
