extends CharacterBody2D

signal ammo_changed(current: int, max_val: int)
signal hp_changed(current: int, max_val: int)
signal shield_changed(value: int)
signal player_died
signal combo_changed(combo: int)
signal combo_reward(tier: int, combo: int)
signal money_changed(current: int)
signal weapon_changed(weapon_name: String, color: Color)
signal score_changed(score: int)

const SPEED = 130.0
const JUMP_VELOCITY = -280.0
const GRAVITY = 800.0
const MAX_FALL_SPEED = 540.0  # Terminal velocity — high, but stops you rushing past everything
const SHOOT_MAX_UPWARD = -180.0
var MAX_AIR_AMMO := 8
var MAX_HP := 4  # Mutable so end-of-level perks can raise it
const INVINCIBLE_TIME = 1.0

# Run-wide perk modifiers (set via apply_perk on level transitions)
var _fire_rate_mult := 1.0  # <1.0 = faster firing
var money_magnet_mult := 1.0  # Read by money.gd to widen coin magnet range
var _coin_bonus := 0  # Extra money per coin collected
var _move_speed_mult := 1.0  # Horizontal movement multiplier
var _jump_mult := 1.0  # Jump strength multiplier
var _damage_bonus := 0  # Flat bonus added to damaging bullets
var _adrenaline_iframes := 0.0  # Extra invincibility seconds after a hit
var _lifesteal := 0  # HP healed each combo cash-in
var _blast_on_stomp := false  # Blast Module: stomps cause an AoE explosion
var _gem_power := false  # Gem Powered: collecting money refills ammo
var _popping := false  # Popping Gems: collecting money fires a shot upward
var _jetpack := false  # Safety Jetpack: hover (slow fall) when out of ammo
var perk_choices := 3  # Youth: number of perk cards offered at level end
var perks: Array[String] = []  # Acquired perk ids (run history)

const STOMP_BLAST_VFX := preload("res://Scenes/VFX/death_explosion.tscn")

# Weapon sprite source folders. Pistols (small, low firepower, early game) come
# from Weapons_Guns_1; rifles (large, high firepower) are reserved for the big
# weapons expected at harder/later levels.
const PISTOL_GUN := (
	"res://Sprites/Active_Sprites/weapons/pistol_guns/"
)
const PISTOL_BUL := (
	"res://Sprites/Active_Sprites/weapons/pistol_bullets/"
)
const RIFLE_GUN := "res://Sprites/Active_Sprites/weapons/rifle_guns/"
const RIFLE_BUL := (
	"res://Sprites/Active_Sprites/weapons/rifle_bullets/"
)

## Baseline weapon stats. Each weapon in WEAPONS only specifies what differs.
## Keys: fire_cooldown, ammo_cost, bullet_speed, damage, bullet_count,
##   spread_angle (deg), bullet_lifetime, collision_radius, air_retention,
##   gun_texture, bullet_texture, gun_scale, hud_color, sfx_pitch_min/max,
##   is_laser, is_burst, is_shotgun, is_piercer, is_ricochet,
##   burst_count, burst_interval, laser_damage_interval, laser_ammo_interval, max_bounces
const WEAPON_DEFAULTS := {
	"fire_cooldown": 0.15,
	"ammo_cost": 1,
	"bullet_speed": 400.0,
	"damage": 1,
	"bullet_count": 1,
	"spread_angle": 0.0,
	"bullet_lifetime": 0.8,
	"collision_radius": 5.0,
	"air_retention": -140.0,
	"hud_color": Color(0.9, 0.8, 0.2, 1.0),
	"sfx_pitch_min": 0.9,
	"sfx_pitch_max": 1.1,
	"is_laser": false,
	"is_burst": false,
	"is_shotgun": false,
	"is_piercer": false,
	"is_ricochet": false,
	"burst_count": 1,
	"burst_interval": 0.0,
	"laser_damage_interval": 1,
	"laser_ammo_interval": 1,
	"max_bounces": 0,
	"gun_scale": 1.0,
	"is_homing": false,
	"homing_turn": 3.0,
	"gravity": 0.0,
	"is_explosive": false,
	"explosion_radius": 26.0,
	"explosion_damage": 1,
	"split_count": 0,
}

## Per-weapon overrides. Pistols = early/low-firepower; rifles = late/big guns.
const WEAPONS := {
	# --- Pistols (Weapons_Guns_1, small sprites → gun_scale 1.8) ---
	"pistol":
	{
		"gun_texture": PISTOL_GUN + "1_1.png",
		"bullet_texture": PISTOL_BUL + "1.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.9, 0.85, 0.5, 1.0),
	},
	# Hand cannon — each slow, heavy shot detonates in a small blast.
	"revolver":
	{
		"fire_cooldown": 0.42,
		"damage": 2,
		"bullet_speed": 460.0,
		"air_retention": -210.0,
		"is_explosive": true,
		"pierces_armor": true,
		"explosion_radius": 26.0,
		"explosion_damage": 1,
		"sfx_pitch_min": 0.6,
		"sfx_pitch_max": 0.75,
		"gun_texture": PISTOL_GUN + "5_1.png",
		"bullet_texture": PISTOL_BUL + "5_1.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.95, 0.55, 0.2, 1.0),
	},
	# Smart SMG — rapid weak rounds that gently curve toward enemies.
	"smg":
	{
		"fire_cooldown": 0.085,
		"bullet_speed": 380.0,
		"bullet_lifetime": 0.9,
		"air_retention": -95.0,
		"collision_radius": 4.0,
		"is_homing": true,
		"homing_turn": 3.2,
		"sfx_pitch_min": 1.1,
		"sfx_pitch_max": 1.4,
		"gun_texture": PISTOL_GUN + "4_1.png",
		"bullet_texture": PISTOL_BUL + "4_1.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.6, 0.9, 0.4, 1.0),
	},
	"scatter":
	{
		"fire_cooldown": 0.30,
		"ammo_cost": 2,
		"bullet_count": 3,
		"spread_angle": 14.0,
		"bullet_speed": 340.0,
		"bullet_lifetime": 0.6,
		"air_retention": -170.0,
		"collision_radius": 4.0,
		"sfx_pitch_min": 0.85,
		"sfx_pitch_max": 1.0,
		"gun_texture": PISTOL_GUN + "3_1.png",
		"bullet_texture": PISTOL_BUL + "3.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.9, 0.4, 0.3, 1.0),
	},
	# Flak — a single shell that bursts into a fan of fragments on impact.
	"flak":
	{
		"fire_cooldown": 0.30,
		"bullet_speed": 360.0,
		"bullet_lifetime": 0.85,
		"split_count": 7,
		"collision_radius": 5.0,
		"sfx_pitch_min": 0.85,
		"sfx_pitch_max": 1.05,
		"gun_texture": PISTOL_GUN + "2_1.png",
		"bullet_texture": PISTOL_BUL + "2.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.7, 0.9, 0.3, 1.0),
	},
	# Pinball — bounces off walls many times AND punches through enemies.
	"ricochet":
	{
		"is_ricochet": true,
		"is_piercer": true,
		"max_bounces": 5,
		"fire_cooldown": 0.26,
		"bullet_speed": 430.0,
		"bullet_lifetime": 2.0,
		"collision_radius": 4.0,
		"sfx_pitch_min": 1.1,
		"sfx_pitch_max": 1.4,
		"gun_texture": PISTOL_GUN + "9_1.png",
		"bullet_texture": PISTOL_BUL + "9.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.3, 0.95, 0.7, 1.0),
	},
	# Railgun — a fast, high-velocity slug that pierces a whole line of enemies.
	"railgun":
	{
		"is_piercer": true,
		"pierces_armor": true,
		"damage": 2,
		"fire_cooldown": 0.34,
		"bullet_speed": 640.0,
		"bullet_lifetime": 1.0,
		"collision_radius": 5.0,
		"air_retention": -160.0,
		"sfx_pitch_min": 0.9,
		"sfx_pitch_max": 1.05,
		"gun_texture": PISTOL_GUN + "6_1.png",
		"bullet_texture": PISTOL_BUL + "6.png",
		"gun_scale": 1.8,
		"hud_color": Color(0.85, 0.4, 0.9, 1.0),
	},
	# --- Rifles / big weapons (free-guns-pack-2, gun_scale 1.0) ---
	# Assault rifle — rapid 3-round bursts that drill through enemies AND floors,
	# so you can shoot foes through the platforms below you (nothing's wasted).
	"assault_rifle":
	{
		"is_burst": true,
		"is_piercer": true,
		"pierces_platforms": true,
		"pierces_armor": true,
		"burst_count": 3,
		"burst_interval": 0.06,
		"fire_cooldown": 0.34,
		"ammo_cost": 1,
		"spread_angle": 6.0,
		"bullet_speed": 540.0,
		"bullet_lifetime": 1.1,
		"sfx_pitch_min": 1.0,
		"sfx_pitch_max": 1.25,
		"gun_texture": RIFLE_GUN + "6_1.png",
		"bullet_texture": RIFLE_BUL + "3.png",
		"hud_color": Color(0.6, 0.9, 0.3, 1.0),
	},
	# Boomstick — a wide wall of 7 piercing pellets with heavy launch kickback.
	"shotgun":
	{
		"is_shotgun": true,
		"is_piercer": true,
		"pierces_armor": true,
		"bullet_count": 7,
		"spread_angle": 28.0,
		"fire_cooldown": 0.5,
		"ammo_cost": 3,
		"bullet_speed": 320.0,
		"bullet_lifetime": 0.42,
		"air_retention": -245.0,
		"sfx_pitch_min": 0.55,
		"sfx_pitch_max": 0.75,
		"gun_texture": RIFLE_GUN + "8_1.png",
		"bullet_texture": RIFLE_BUL + "4.png",
		"hud_color": Color(0.95, 0.5, 0.15, 1.0),
	},
	"laser":
	{
		"is_laser": true,
		"fire_cooldown": 0.04,
		"bullet_speed": 600.0,
		"bullet_lifetime": 0.3,
		"collision_radius": 3.0,
		"air_retention": -90.0,
		"laser_damage_interval": 3,
		"laser_ammo_interval": 4,
		"sfx_pitch_min": 1.3,
		"sfx_pitch_max": 1.6,
		"gun_texture": RIFLE_GUN + "7_1.png",
		"bullet_texture": RIFLE_BUL + "5.png",
		"hud_color": Color(0.2, 0.8, 1.0, 1.0),
	},
	# Cannon — a heavy slug that pierces a line AND detonates in a big blast.
	"cannon":
	{
		"is_piercer": true,
		"is_explosive": true,
		"pierces_armor": true,
		"explosion_radius": 42.0,
		"explosion_damage": 2,
		"damage": 3,
		"fire_cooldown": 0.55,
		"ammo_cost": 3,
		"bullet_speed": 540.0,
		"bullet_lifetime": 1.2,
		"collision_radius": 7.0,
		"air_retention": -210.0,
		"sfx_pitch_min": 0.5,
		"sfx_pitch_max": 0.65,
		"gun_texture": RIFLE_GUN + "3_1.png",
		"bullet_texture": RIFLE_BUL + "6.png",
		"hud_color": Color(0.85, 0.2, 0.85, 1.0),
	},
}


## Build the full per-weapon stat table by merging each override over the defaults.
static func _build_weapon_data() -> Dictionary:
	var out := {}
	for id: String in WEAPONS:
		var d: Dictionary = WEAPON_DEFAULTS.duplicate()
		var ov: Dictionary = WEAPONS[id]
		for k: String in ov:
			d[k] = ov[k]
		out[id] = d
	return out


static var WEAPON_DATA: Dictionary = _build_weapon_data()

@export var bullet_scene: PackedScene
@export var muzzle_flash_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $Protagonista
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_sprite: Sprite2D = $GunPivot/GunSprite
@onready var muzzle_point: Marker2D = $GunPivot/MuzzlePoint

var _gun_pivot_base: Vector2
var _sprite_base_x: float
var _facing_right := true
var _shoot_timer := 0.0
var _air_ammo: int = MAX_AIR_AMMO
var _hp: int = MAX_HP
var _shield := 0  # Blue armour pips: absorb a hit each, never regenerated by heals
var _invincible_timer := 0.0
var _stomp_invincible := 0.0  # Brief stomp i-frames (no visual)
var _combo := 0
var _in_safe_zone := false  # Preserves combo through rest zones and rooms
var _was_on_floor := true
var _last_kill_was_stomp := false  # For style bonus tracking
var _money := 0
var _score := 0

# Weapon state
var current_weapon := "pistol"
var _laser_tick := 0  # Tick counter for laser damage/ammo intervals
var _burst_queue := 0  # Remaining bullets in a machinegun burst
var _burst_timer := 0.0  # Timer between burst bullets
var _burst_angle_offsets: Array[float] = []  # Pre-rolled angles for current burst
var _world: Node2D

# Per-animation shoulder offset adjustments relative to Idle base position.
var _anim_offsets := {
	"Idle": Vector2(0, 0),
	"Run": Vector2(1, 1),
	"Jump": Vector2(0, -3),
}


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 8  # 1 = world platforms, 8 = soft/elevator platforms (bullets pass through)
	_gun_pivot_base = gun_pivot.position
	_sprite_base_x = sprite.position.x
	_world = get_tree().current_scene as Node2D
	_apply_gun_visual()


func _physics_process(delta: float) -> void:
	_shoot_timer -= delta
	_invincible_timer -= delta
	_stomp_invincible -= delta

	# Process machinegun burst queue
	if _burst_queue > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0 and _burst_queue > 0:
			_spawn_burst_bullet()
			_burst_queue -= 1
			_burst_timer = WEAPON_DATA[current_weapon]["burst_interval"]

	# Blink while invincible (only damage i-frames, not stomp)
	if _invincible_timer > 0:
		sprite.modulate.a = 0.3 if fmod(_invincible_timer, 0.2) < 0.1 else 1.0
	elif sprite.modulate.a != 1.0:
		sprite.modulate.a = 1.0

	# Gravity (capped at terminal velocity so you can't rush past the whole level)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	# Refill ammo on landing + cash in combo rewards
	if is_on_floor():
		if not _was_on_floor:
			SFX.play(SFX.landing, -14.0)
			if _combo > 0:
				if not _in_safe_zone and position.x <= 400.0:
					_cash_in_combo()
			_laser_tick = 0
			_burst_queue = 0
		# Normal refill (won't overwrite bonus ammo if already above max)
		if _air_ammo < MAX_AIR_AMMO:
			_air_ammo = MAX_AIR_AMMO
			ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
	_was_on_floor = is_on_floor()

	# Jump (on ground) / Shoot (in air)
	var wd: Dictionary = WEAPON_DATA[current_weapon]
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY * _jump_mult
			SFX.play_jump()
			_laser_tick = 0
		elif _air_ammo >= wd["ammo_cost"] and _shoot_timer <= 0.0:
			_shoot()
		elif _air_ammo < wd["ammo_cost"]:
			SFX.play(SFX.empty_click, -7.0)
	# Laser hold-to-fire: continuous shooting while jump is held
	elif (
		not is_on_floor()
		and wd["is_laser"]
		and Input.is_action_pressed("jump")
		and _air_ammo >= wd["ammo_cost"]
		and _shoot_timer <= 0.0
	):
		_shoot()

	# Safety Jetpack: out of ammo + holding jump in the air → slow, controlled fall.
	if (
		_jetpack
		and not is_on_floor()
		and _air_ammo < wd["ammo_cost"]
		and Input.is_action_pressed("jump")
		and velocity.y > 50.0
	):
		velocity.y = 50.0

	# Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED * _move_speed_mult

	# Flip sprite and gun arm
	if direction > 0:
		_set_facing_right(true)
	elif direction < 0:
		_set_facing_right(false)

	move_and_slide()
	_update_animation(direction)


func _set_facing_right(facing_right: bool) -> void:
	_facing_right = facing_right
	sprite.flip_h = not facing_right
	# Mirror the sprite's X offset so the body stays aligned with the arm
	if facing_right:
		sprite.position.x = _sprite_base_x
	else:
		sprite.position.x = -_sprite_base_x


func _apply_gun_position(anim_name: String) -> void:
	var offset: Vector2 = _anim_offsets.get(anim_name, Vector2.ZERO)
	if _facing_right:
		gun_pivot.position = _gun_pivot_base + offset
		gun_pivot.scale.y = 1
	else:
		gun_pivot.position = Vector2(-_gun_pivot_base.x - offset.x, _gun_pivot_base.y + offset.y)
		gun_pivot.scale.y = -1


func _update_animation(direction: float) -> void:
	var anim: String
	if not is_on_floor():
		anim = "Jump"
	elif direction != 0:
		anim = "Run"
	else:
		anim = "Idle"
	sprite.play(anim)
	_apply_gun_position(anim)


func _shoot() -> void:
	var wd: Dictionary = WEAPON_DATA[current_weapon]

	# Laser: tick-based ammo/damage gating
	if wd["is_laser"]:
		_laser_tick += 1
		# Only consume ammo on ammo interval ticks
		if _laser_tick % int(wd["laser_ammo_interval"]) == 0:
			_air_ammo -= 1
			ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
		# Damage is handled per-bullet (0 on non-damage ticks)
		var bullet_damage: int = (
			wd["damage"] if _laser_tick % int(wd["laser_damage_interval"]) == 0 else 0
		)
		_spawn_bullet(wd, 0.0, bullet_damage)
		_shoot_timer = wd["fire_cooldown"] * _fire_rate_mult
		# Air retention (gentle per tick)
		velocity.y = max(min(velocity.y, 0.0) + wd["air_retention"] * 0.3, SHOOT_MAX_UPWARD)
		# Laser SFX only on damage ticks to avoid spam
		if bullet_damage > 0:
			SFX.play_shoot(wd["sfx_pitch_min"], wd["sfx_pitch_max"])
		return

	# Standard weapons: consume ammo cost
	_air_ammo -= int(wd["ammo_cost"])
	_shoot_timer = wd["fire_cooldown"] * _fire_rate_mult
	ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
	SFX.play_shoot(wd["sfx_pitch_min"], wd["sfx_pitch_max"])

	# Air retention
	velocity.y = max(min(velocity.y, 0.0) + wd["air_retention"], SHOOT_MAX_UPWARD)

	# Spawn pattern
	if wd["is_burst"]:
		# Machinegun: start burst, first bullet immediately
		_burst_queue = int(wd["burst_count"]) - 1
		_burst_timer = wd["burst_interval"]
		_burst_angle_offsets.clear()
		for i in range(int(wd["burst_count"])):
			_burst_angle_offsets.append(randf_range(-wd["spread_angle"], wd["spread_angle"]))
		_spawn_bullet(wd, _burst_angle_offsets[0], wd["damage"])
	elif wd["is_shotgun"]:
		# Shotgun: wide spread with per-pellet random jitter
		var count := int(wd["bullet_count"])
		var spread: float = wd["spread_angle"]
		for i in range(count):
			var angle := -spread + (spread * 2.0 * i / float(count - 1))
			angle += randf_range(-3.0, 3.0)
			_spawn_bullet(wd, angle, wd["damage"])
	else:
		# Pistol / Spread / Piercer / Ricochet: standard spawn
		var count := int(wd["bullet_count"])
		var spread: float = wd["spread_angle"]
		for i in range(count):
			var angle := 0.0
			if count > 1:
				angle = -spread + (spread * 2.0 * i / float(count - 1))
			_spawn_bullet(wd, angle, wd["damage"])

	# Muzzle flash
	_spawn_muzzle_flash()


func _spawn_bullet(wd: Dictionary, angle_deg: float, bullet_damage: int) -> void:
	if not bullet_scene:
		return
	var bullet := bullet_scene.instantiate()
	bullet.speed = wd["bullet_speed"]
	bullet.direction = Vector2.DOWN.rotated(deg_to_rad(angle_deg))
	# Apply the flat damage bonus only to bullets that already deal damage, so a
	# laser's non-damage ticks stay at 0.
	bullet.damage = bullet_damage + (_damage_bonus if bullet_damage > 0 else 0)
	bullet.lifetime = wd["bullet_lifetime"]
	bullet.global_position = muzzle_point.global_position
	# Weapon behavior flags
	bullet.is_piercer = bool(wd.get("is_piercer", false))
	bullet.pierces_platforms = bool(wd.get("pierces_platforms", false))
	bullet.pierces_armor = bool(wd.get("pierces_armor", false))
	bullet.is_ricochet = bool(wd.get("is_ricochet", false))
	bullet.max_bounces = int(wd.get("max_bounces", 0))
	bullet.is_homing = bool(wd.get("is_homing", false))
	bullet.homing_turn = float(wd.get("homing_turn", 3.0))
	bullet.bullet_gravity = float(wd.get("gravity", 0.0))
	bullet.is_explosive = bool(wd.get("is_explosive", false))
	bullet.explosion_radius = float(wd.get("explosion_radius", 26.0))
	bullet.explosion_damage = int(wd.get("explosion_damage", 1))
	bullet.split_count = int(wd.get("split_count", 0))
	var bullet_sprite: Sprite2D = bullet.get_node_or_null("Sprite2D")
	if bullet_sprite:
		bullet_sprite.texture = load(wd["bullet_texture"])
	# Adjust collision radius
	var col: CollisionShape2D = bullet.get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		col.shape.radius = wd["collision_radius"]
	_world.add_child(bullet)


func _spawn_burst_bullet() -> void:
	var wd: Dictionary = WEAPON_DATA[current_weapon]
	var idx := int(wd["burst_count"]) - _burst_queue
	if idx < 0 or idx >= _burst_angle_offsets.size():
		idx = 0
	_spawn_bullet(wd, _burst_angle_offsets[idx], wd["damage"])
	# Mini muzzle flash per burst bullet
	if muzzle_flash_scene:
		var flash := muzzle_flash_scene.instantiate()
		flash.global_position = muzzle_point.global_position + Vector2(0, 2)
		flash.rotation = deg_to_rad(90.0)
		_world.add_child(flash)


func _spawn_muzzle_flash() -> void:
	if muzzle_flash_scene:
		var flash := muzzle_flash_scene.instantiate()
		flash.global_position = muzzle_point.global_position + Vector2(0, 2)
		flash.rotation = deg_to_rad(90.0)
		_world.add_child(flash)


## Update the held gun sprite + scale to match the current weapon.
func _apply_gun_visual() -> void:
	var wd: Dictionary = WEAPON_DATA[current_weapon]
	gun_sprite.texture = load(wd["gun_texture"])
	var s: float = wd.get("gun_scale", 1.0)
	gun_sprite.scale = Vector2(s, s)


## Equip a new weapon, swapping gun sprite and emitting HUD update.
func equip_weapon(weapon_name: String) -> void:
	if not WEAPON_DATA.has(weapon_name):
		return
	current_weapon = weapon_name
	_apply_gun_visual()
	weapon_changed.emit(weapon_name, WEAPON_DATA[weapon_name]["hud_color"])
	# Reset weapon-specific state
	_laser_tick = 0
	_burst_queue = 0


## Called when stomping an enemy — refills ammo and increments combo.
func refill_ammo(amount: int = MAX_AIR_AMMO) -> void:
	# Don't overwrite bonus ammo (above max) from combo rewards
	_air_ammo = maxi(_air_ammo, mini(amount, MAX_AIR_AMMO))
	ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
	_add_combo_kill(true)
	# Brief stomp invincibility (no visual blink)
	_stomp_invincible = 0.15
	if _blast_on_stomp:
		_do_stomp_blast()


## Blast Module: damage all nearby enemies when stomping.
func _do_stomp_blast() -> void:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	params.collide_with_bodies = true
	for h in space.intersect_shape(params, 12):
		var c: Object = h.get("collider")
		if c and c is Node2D and c.has_method("take_damage"):
			c.take_damage(3)
	var fx := STOMP_BLAST_VFX.instantiate()
	fx.explosion_type = "explosion"
	fx.global_position = global_position
	_world.call_deferred("add_child", fx)
	if _world and _world.has_method("screen_shake"):
		_world.screen_shake(3.0)


## Popping Gems: fire a quick shot straight up.
func _spawn_upward_bullet() -> void:
	if not bullet_scene:
		return
	var b := bullet_scene.instantiate()
	b.speed = 380.0
	b.direction = Vector2.UP
	b.damage = 1 + _damage_bonus
	b.lifetime = 0.7
	b.global_position = global_position + Vector2(0, -10)
	var spr: Sprite2D = b.get_node_or_null("Sprite2D")
	if spr:
		spr.texture = load(WEAPON_DATA[current_weapon]["bullet_texture"])
	_world.add_child(b)


## Increment combo (called externally by bullet kills).
func add_combo() -> void:
	_add_combo_kill(false)


## Internal: add a kill to the combo chain with style bonus tracking.
func _add_combo_kill(is_stomp: bool) -> void:
	if _combo > 0 and is_stomp != _last_kill_was_stomp:
		_combo += 2
	else:
		_combo += 1
	_last_kill_was_stomp = is_stomp
	_score += 10 * maxi(_combo, 1)
	score_changed.emit(_score)
	combo_changed.emit(_combo)


## Cash in combo rewards on landing. Higher combo = better rewards.
func _cash_in_combo() -> void:
	var tier := 0
	if _combo >= 35:
		tier = 3
	elif _combo >= 20:
		tier = 2
	elif _combo >= 10:
		tier = 1

	if tier == 0 and _combo > 0:
		SFX.play_combo_lost()

	_score += _combo * 50
	score_changed.emit(_score)

	# Vampire perk: only heals on long-combo cash-ins (tier 2+), not every landing.
	if _lifesteal > 0 and tier >= 2 and _hp < MAX_HP:
		_hp = mini(_hp + _lifesteal, MAX_HP)
		hp_changed.emit(_hp, MAX_HP)

	if tier >= 1 and _hp < MAX_HP:
		_hp += 1
		hp_changed.emit(_hp, MAX_HP)

	if tier >= 2:
		_air_ammo = MAX_AIR_AMMO + 3
		ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)

	if tier >= 3:
		_air_ammo = MAX_AIR_AMMO + 3
		ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
		_invincible_timer = 2.0
		SFX.play(SFX.invincibility, -10.0)

	SFX.play_combo_reward(tier)

	combo_reward.emit(tier, _combo)
	_combo = 0
	combo_changed.emit(_combo)


## Called when an enemy damages the player.
func take_damage(amount: int = 1) -> void:
	if _invincible_timer > 0 or _stomp_invincible > 0:
		return
	# Blue armour absorbs the hit first (one pip per hit) and is not regenerated.
	if _shield > 0:
		_shield -= 1
		shield_changed.emit(_shield)
		_invincible_timer = INVINCIBLE_TIME + _adrenaline_iframes
		SFX.play_shield_break()
		velocity.y = -200.0
		return
	_hp -= amount
	_invincible_timer = INVINCIBLE_TIME + _adrenaline_iframes
	hp_changed.emit(_hp, MAX_HP)
	if _hp <= 0:
		SFX.play(SFX.player_death, -4.0)
		player_died.emit()
		# Simple death: freeze for now
		set_physics_process(false)
		sprite.play("Death")
	else:
		SFX.play(SFX.damage_taken, -11.0)
		# Knockback upward
		velocity.y = -200.0


## Called when picking up a money collectible.
func collect_money(value: int) -> void:
	_money += value + _coin_bonus
	money_changed.emit(_money)
	SFX.play_coin_pickup()
	if _gem_power and _air_ammo < MAX_AIR_AMMO:
		_air_ammo = mini(_air_ammo + 2, MAX_AIR_AMMO)
		ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
	if _popping:
		_spawn_upward_bullet()


## Apply an end-of-level perk. See Scenes/UI/perk_select.gd for definitions.
func apply_perk(perk_id: String) -> void:
	perks.append(perk_id)
	match perk_id:
		"max_hp":
			MAX_HP += 1
			_hp = MAX_HP
			hp_changed.emit(_hp, MAX_HP)
		"max_ammo":
			increase_max_ammo(2)
		"fire_rate":
			_fire_rate_mult = maxf(_fire_rate_mult * 0.8, 0.4)
		"magnet":
			money_magnet_mult += 1.0
		"profiteer":
			_coin_bonus += 1
		"swift":
			_move_speed_mult += 0.18
		"high_jump":
			_jump_mult += 0.15
		"sharpshooter":
			_damage_bonus += 1
		"glass_cannon":
			_damage_bonus += 2
			MAX_HP = maxi(MAX_HP - 1, 1)
			_hp = mini(_hp, MAX_HP)
			hp_changed.emit(_hp, MAX_HP)
		"adrenaline":
			# Tougher to interrupt: longer i-frames when hit.
			_adrenaline_iframes += 0.4
		"vampire":
			_lifesteal += 1
		"blast":
			_blast_on_stomp = true
		"gem_power":
			_gem_power = true
		"popping":
			_popping = true
		"jetpack":
			_jetpack = true
		"youth":
			perk_choices += 1
			heal(1)


## Heal HP (clamped to max).
func heal(amount: int) -> void:
	var before := _hp
	_hp = mini(_hp + amount, MAX_HP)
	hp_changed.emit(_hp, MAX_HP)
	if _hp > before:
		SFX.play_heal()


## Add blue armour pips (absorb a hit each, never regenerated). Capped so the HUD
## doesn't overflow.
func add_shield(amount: int) -> void:
	var before := _shield
	_shield = mini(_shield + amount, 4)
	shield_changed.emit(_shield)
	if _shield > before:
		SFX.play_shield_up()


## Permanently increase max ammo and refill.
func increase_max_ammo(amount: int) -> void:
	MAX_AIR_AMMO += amount
	_air_ammo = MAX_AIR_AMMO
	ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)


## Try to spend money. Returns true if successful.
func spend_money(amount: int) -> bool:
	if _money < amount:
		return false
	_money -= amount
	money_changed.emit(_money)
	return true
