# ═══════════════════════════════════════════════════════════════════════
# player_water.gd — Componente de agua
#
# Responsabilidades:
#   • Consumo de suministro de aire bajo el agua
#   • Daño por ahogamiento cuando el aire se agota
#   • Señales de área: entrar/salir del agua, interactuables
# ═══════════════════════════════════════════════════════════════════════
extends PlayerAnimation
class_name PlayerWater


# ═══════════════════════════════════════════════════════════════════════
# ─── Suministro de aire ───────────────────────────────────────────────

func _update_air_supply(delta: float) -> void:
	if not inWater or infiniteAir:
		airSupply       = AIR_MAX
		_air_tick_timer = 0.0
		_air_dmg_timer  = 0.0
		return

	if airSupply > 0:
		_air_tick_timer += delta
		if _air_tick_timer >= AIR_TICK:
			_air_tick_timer = 0.0
			airSupply       = maxf(airSupply - 1, 0.0)
	else:
		_air_dmg_timer += delta
		if _air_dmg_timer >= AIR_DMG_INTERVAL:
			_air_dmg_timer = 0.0
			take_damage(3, global_position, true, false, true)


# ═══════════════════════════════════════════════════════════════════════
# ─── Señales de área ──────────────────────────────────────────────────

func _on_water_detect_area_entered(_area) -> void:
	inWater = true


func _on_water_detect_area_exited(_area) -> void:
	inWater           = false
	_iframes_drowning = false


func _on_interactable_area_entered(_area) -> void:
	able_to_interact = true


func _on_interactable_area_exited(_area) -> void:
	able_to_interact = false
