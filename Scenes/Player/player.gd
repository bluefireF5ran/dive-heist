extends CharacterBody2D

signal ammo_changed(current: int, max_val: int)
signal hp_changed(current: int, max_val: int)
signal player_died
signal combo_changed(combo: int)
signal combo_reward(tier: int, combo: int)  # Emitted on landing with rewards
signal money_changed(current: int)
signal weapon_changed(weapon_name: String, color: Color)

const SPEED = 130.0
const JUMP_VELOCITY = -280.0
const GRAVITY = 800.0
const SHOOT_MAX_UPWARD = -180.0  # Max upward speed from shooting (prevents flying)
var MAX_AIR_AMMO := 8  # Shots before needing to land (can increase)
const MAX_HP = 3
const INVINCIBLE_TIME = 1.0  # Seconds of invincibility after taking damage

## Weapon definitions: stats per weapon type.
## Keys: fire_cooldown, ammo_cost, bullet_speed, damage, bullet_count,
##   spread_angle (degrees), bullet_lifetime, collision_radius,
##   air_retention, gun_texture, bullet_texture, hud_color,
##   sfx_pitch_min, sfx_pitch_max, is_laser, is_burst, is_shotgun,
##   is_piercer, is_ricochet, burst_count, burst_interval,
##   laser_damage_interval, laser_ammo_interval, max_bounces
const WEAPON_DATA := {
	"pistol":
	{
		"fire_cooldown": 0.15,
		"ammo_cost": 1,
		"bullet_speed": 400.0,
		"damage": 1,
		"bullet_count": 1,
		"spread_angle": 0.0,
		"bullet_lifetime": 0.8,
		"collision_radius": 5.0,
		"air_retention": -140.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/1_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/1.png",
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
	},
	"spread":
	{
		"fire_cooldown": 0.30,
		"ammo_cost": 2,
		"bullet_speed": 320.0,
		"damage": 1,
		"bullet_count": 3,
		"spread_angle": 12.0,
		"bullet_lifetime": 1.0,
		"collision_radius": 4.0,
		"air_retention": -160.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/4_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/2.png",
		"hud_color": Color(0.9, 0.3, 0.2, 1.0),
		"sfx_pitch_min": 0.7,
		"sfx_pitch_max": 0.9,
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
	},
	"laser":
	{
		"fire_cooldown": 0.04,
		"ammo_cost": 1,
		"bullet_speed": 600.0,
		"damage": 1,
		"bullet_count": 1,
		"spread_angle": 0.0,
		"bullet_lifetime": 0.3,
		"collision_radius": 3.0,
		"air_retention": -90.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/7_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/5.png",
		"hud_color": Color(0.2, 0.8, 1.0, 1.0),
		"sfx_pitch_min": 1.3,
		"sfx_pitch_max": 1.6,
		"is_laser": true,
		"is_burst": false,
		"is_shotgun": false,
		"is_piercer": false,
		"is_ricochet": false,
		"burst_count": 1,
		"burst_interval": 0.0,
		"laser_damage_interval": 3,
		"laser_ammo_interval": 4,
		"max_bounces": 0,
	},
	"machinegun":
	{
		"fire_cooldown": 0.22,
		"ammo_cost": 2,
		"bullet_speed": 450.0,
		"damage": 1,
		"bullet_count": 3,
		"spread_angle": 10.0,
		"bullet_lifetime": 0.7,
		"collision_radius": 4.0,
		"air_retention": -140.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/6_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/3.png",
		"hud_color": Color(0.6, 0.9, 0.3, 1.0),
		"sfx_pitch_min": 1.0,
		"sfx_pitch_max": 1.3,
		"is_laser": false,
		"is_burst": true,
		"is_shotgun": false,
		"is_piercer": false,
		"is_ricochet": false,
		"burst_count": 3,
		"burst_interval": 0.08,
		"laser_damage_interval": 1,
		"laser_ammo_interval": 1,
		"max_bounces": 0,
	},
	"shotgun":
	{
		"fire_cooldown": 0.40,
		"ammo_cost": 2,
		"bullet_speed": 280.0,
		"damage": 1,
		"bullet_count": 5,
		"spread_angle": 25.0,
		"bullet_lifetime": 0.35,
		"collision_radius": 5.0,
		"air_retention": -220.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/8_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/4.png",
		"hud_color": Color(0.95, 0.5, 0.15, 1.0),
		"sfx_pitch_min": 0.6,
		"sfx_pitch_max": 0.8,
		"is_laser": false,
		"is_burst": false,
		"is_shotgun": true,
		"is_piercer": false,
		"is_ricochet": false,
		"burst_count": 1,
		"burst_interval": 0.0,
		"laser_damage_interval": 1,
		"laser_ammo_interval": 1,
		"max_bounces": 0,
	},
	"piercer":
	{
		"fire_cooldown": 0.30,
		"ammo_cost": 1,
		"bullet_speed": 500.0,
		"damage": 2,
		"bullet_count": 1,
		"spread_angle": 0.0,
		"bullet_lifetime": 1.2,
		"collision_radius": 6.0,
		"air_retention": -150.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/3_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/6.png",
		"hud_color": Color(0.85, 0.2, 0.85, 1.0),
		"sfx_pitch_min": 0.8,
		"sfx_pitch_max": 1.0,
		"is_laser": false,
		"is_burst": false,
		"is_shotgun": false,
		"is_piercer": true,
		"is_ricochet": false,
		"burst_count": 1,
		"burst_interval": 0.0,
		"laser_damage_interval": 1,
		"laser_ammo_interval": 1,
		"max_bounces": 0,
	},
	"ricochet":
	{
		"fire_cooldown": 0.25,
		"ammo_cost": 1,
		"bullet_speed": 350.0,
		"damage": 1,
		"bullet_count": 1,
		"spread_angle": 0.0,
		"bullet_lifetime": 1.5,
		"collision_radius": 4.0,
		"air_retention": -130.0,
		"gun_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/9_1.png",
		"bullet_texture":
		"res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/5 Bullets/9.png",
		"hud_color": Color(0.3, 0.95, 0.7, 1.0),
		"sfx_pitch_min": 1.1,
		"sfx_pitch_max": 1.4,
		"is_laser": false,
		"is_burst": false,
		"is_shotgun": false,
		"is_piercer": false,
		"is_ricochet": true,
		"burst_count": 1,
		"burst_interval": 0.0,
		"laser_damage_interval": 1,
		"laser_ammo_interval": 1,
		"max_bounces": 3,
	},
}

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
var _invincible_timer := 0.0
var _stomp_invincible := 0.0  # Brief stomp i-frames (no visual)
var _combo := 0
var _in_safe_zone := false  # Preserves combo through rest zones and rooms
var _was_on_floor := true
var _last_kill_was_stomp := false  # For style bonus tracking
var _money := 0

# Weapon state
var current_weapon := "pistol"
var _laser_tick := 0  # Tick counter for laser damage/ammo intervals
var _burst_queue := 0  # Remaining bullets in a machinegun burst
var _burst_timer := 0.0  # Timer between burst bullets
var _burst_angle_offsets: Array[float] = []  # Pre-rolled angles for current burst

# Per-animation shoulder offset adjustments relative to Idle base position.
var _anim_offsets := {
	"Idle": Vector2(0, 0),
	"Run": Vector2(1, 1),
	"Jump": Vector2(0, -3),
}


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2  # Player on layer 2 (separate from world)
	collision_mask = 1  # Collide with world (layer 1)
	_gun_pivot_base = gun_pivot.position
	_sprite_base_x = sprite.position.x


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

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

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
			velocity.y = JUMP_VELOCITY
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

	# Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

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
		_shoot_timer = wd["fire_cooldown"]
		# Air retention (gentle per tick)
		velocity.y = max(min(velocity.y, 0.0) + wd["air_retention"] * 0.3, SHOOT_MAX_UPWARD)
		# Laser SFX only on damage ticks to avoid spam
		if bullet_damage > 0:
			SFX.play_shoot(wd["sfx_pitch_min"], wd["sfx_pitch_max"])
		return

	# Standard weapons: consume ammo cost
	_air_ammo -= int(wd["ammo_cost"])
	_shoot_timer = wd["fire_cooldown"]
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
	bullet.damage = bullet_damage
	bullet.lifetime = wd["bullet_lifetime"]
	bullet.weapon_color = wd["hud_color"]
	bullet.global_position = muzzle_point.global_position
	# Weapon behavior flags
	bullet.is_piercer = bool(wd.get("is_piercer", false))
	bullet.is_ricochet = bool(wd.get("is_ricochet", false))
	bullet.max_bounces = int(wd.get("max_bounces", 0))
	# Ricochet needs to detect world geometry (layer 1)
	if bullet.is_ricochet:
		bullet.collision_mask = 5  # Layers 1 + 4
	# Swap bullet texture
	var bullet_sprite: Sprite2D = bullet.get_node_or_null("Sprite2D")
	if bullet_sprite:
		bullet_sprite.texture = load(wd["bullet_texture"])
	# Adjust collision radius
	var col: CollisionShape2D = bullet.get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		col.shape.radius = wd["collision_radius"]
	get_tree().current_scene.add_child(bullet)


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
		get_tree().current_scene.add_child(flash)


func _spawn_muzzle_flash() -> void:
	if muzzle_flash_scene:
		var flash := muzzle_flash_scene.instantiate()
		flash.global_position = muzzle_point.global_position + Vector2(0, 2)
		flash.rotation = deg_to_rad(90.0)
		get_tree().current_scene.add_child(flash)


## Equip a new weapon, swapping gun sprite and emitting HUD update.
func equip_weapon(weapon_name: String) -> void:
	if not WEAPON_DATA.has(weapon_name):
		return
	current_weapon = weapon_name
	var wd: Dictionary = WEAPON_DATA[weapon_name]
	gun_sprite.texture = load(wd["gun_texture"])
	weapon_changed.emit(weapon_name, wd["hud_color"])
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


## Increment combo (called externally by bullet kills).
func add_combo() -> void:
	_add_combo_kill(false)


## Internal: add a kill to the combo chain with style bonus tracking.
func _add_combo_kill(is_stomp: bool) -> void:
	# Style bonus: alternating stomp/shoot gives +1 extra
	if _combo > 0 and is_stomp != _last_kill_was_stomp:
		_combo += 2  # 1 base + 1 style bonus
	else:
		_combo += 1
	_last_kill_was_stomp = is_stomp
	combo_changed.emit(_combo)


## Cash in combo rewards on landing. Higher combo = better rewards.
func _cash_in_combo() -> void:
	var tier := 0
	if _combo >= 25:
		tier = 3
	elif _combo >= 15:
		tier = 2
	elif _combo >= 8:
		tier = 1

	# Tier 1+: heal 1 HP
	if tier >= 1 and _hp < MAX_HP:
		_hp += 1
		hp_changed.emit(_hp, MAX_HP)

	# Tier 2+: bonus ammo above max (3 extra shots for next jump)
	if tier >= 2:
		_air_ammo = MAX_AIR_AMMO + 3
		ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)

	# Tier 3: brief invincibility
	if tier >= 3:
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
	_hp -= amount
	_invincible_timer = INVINCIBLE_TIME
	hp_changed.emit(_hp, MAX_HP)
	if _hp <= 0:
		SFX.play(SFX.player_death, -4.0)
		player_died.emit()
		# Simple death: freeze for now
		set_physics_process(false)
		sprite.play("Death")
	else:
		SFX.play(SFX.damage_taken, -4.0)
		# Knockback upward
		velocity.y = -200.0


## Called when picking up a money collectible.
func collect_money(value: int) -> void:
	_money += value
	money_changed.emit(_money)
	SFX.play_coin_pickup()


## Heal HP (clamped to max).
func heal(amount: int) -> void:
	_hp = mini(_hp + amount, MAX_HP)
	hp_changed.emit(_hp, MAX_HP)


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
