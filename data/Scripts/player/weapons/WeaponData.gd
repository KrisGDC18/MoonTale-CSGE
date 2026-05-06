extends Resource
class_name WeaponData

# ─── Identidad ────────────────────────────────────────────────────────
@export var id           : String    = "laser"     # identificador único del arma
@export var display_name : String    = "Polar Star"     # nombre visible en el HUD
@export var icon         : Texture2D = null   # icono para el HUD

# ─── Niveles ──────────────────────────────────────────────────────────
@export var max_level    : int       = 3      # nivel máximo del arma
@export var exp_to_level : Array     = [10, 30]  # EXP para subir a lvl2 y lvl3
											   # si max_level=1 dejar vacío

# ─── Estadísticas por nivel ───────────────────────────────────────────
# cada Array tiene un valor por nivel [lvl1, lvl2, lvl3]
@export var damage       : Array     = [1, 2, 3]   # daño por disparo
@export var cooldown     : Array     = [0.3, 0.25, 0.2]  # segundos entre disparos
@export var recoil       : Array     = [0.0, 0.0, 0.0]   # retroceso horizontal

# ─── Bala ─────────────────────────────────────────────────────────────
# puede ser una escena diferente por nivel (bala más grande, etc.)
@export var bullet_scene : Array     = []  # [PackedScene lvl1, lvl2, lvl3]

# ─── Munición ─────────────────────────────────────────────────────────
@export var max_ammo     : int       = -1  # -1 = infinita, >0 = limitada

# ─── Sonido ───────────────────────────────────────────────────────────
@export var sound        : AudioStream = null  # sonido al disparar
