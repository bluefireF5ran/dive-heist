extends CharacterBody2D

signal ammo_changed(current: int, max_val: int)
signal hp_changed(current: int, max_val: int)
signal player_died
signal combo_changed(combo: int)
signal combo_reward(tier: int, combo: int)  # Emitted on landing with rewards
signal money_changed(current: int)

const SPEED = 130.0
const JUMP_VELOCITY = -280.0
const GRAVITY = 800.0
const SHOOT_HANG_VELOCITY = -160.0  # Upward push when shooting (air retention)
const SHOOT_MAX_UPWARD = -180.0  # Max upward speed from shooting (prevents flying)
const SHOOT_COOLDOWN = 0.15  # Seconds between shots
var MAX_AIR_AMMO := 8  # Shots before needing to land (can increase)
const MAX_HP = 3
const INVINCIBLE_TIME = 1.0  # Seconds of invincibility after taking damage

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
var _was_on_floor := true
var _last_kill_was_stomp := false  # For style bonus tracking
var _money := 0

# Weapon system — tracks current weapon type for future weapon swapping (US-19).
# Available types: "pistol" (default), "blaster", "laser", "machinegun"
var current_weapon := "pistol"

# Per-animation shoulder offset adjustments relative to Idle base position.
# Tweak these in-game if the arm doesn't sit right on a specific animation.
var _anim_offsets := {
	"Idle": Vector2(0, 0),
	"Run": Vector2(1, 1),
	"Jump": Vector2(0, -3),
}


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2  # Player on layer 2 (separate from world)
	collision_mask = 1   # Collide with world (layer 1)
	_gun_pivot_base = gun_pivot.position
	_sprite_base_x = sprite.position.x


func _physics_process(delta: float) -> void:
	_shoot_timer -= delta
	_invincible_timer -= delta
	_stomp_invincible -= delta

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
				_cash_in_combo()
		# Normal refill (won't overwrite bonus ammo if already above max)
		if _air_ammo < MAX_AIR_AMMO:
			_air_ammo = MAX_AIR_AMMO
			ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
	_was_on_floor = is_on_floor()

	# Jump (on ground) / Shoot (in air)
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			SFX.play_jump()
		elif _air_ammo > 0 and _shoot_timer <= 0.0:
			_shoot()
		elif _air_ammo <= 0:
			SFX.play(SFX.empty_click, -7.0)

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
	_air_ammo -= 1
	_shoot_timer = SHOOT_COOLDOWN
	ammo_changed.emit(_air_ammo, MAX_AIR_AMMO)
	SFX.play_shoot()

	# Air retention — counteract gravity so sustained fire keeps you airborne
	# but cap upward speed to prevent flying away
	velocity.y = max(min(velocity.y, 0.0) + SHOOT_HANG_VELOCITY, SHOOT_MAX_UPWARD)

	# Spawn bullet at muzzle position (downward)
	if bullet_scene:
		var bullet := bullet_scene.instantiate()
		bullet.global_position = muzzle_point.global_position
		get_tree().current_scene.add_child(bullet)

	# Spawn muzzle flash (rotated 90° to point downward, offset 2px down)
	if muzzle_flash_scene:
		var flash := muzzle_flash_scene.instantiate()
		flash.global_position = muzzle_point.global_position + Vector2(0, 2)
		flash.rotation = deg_to_rad(90.0)
		get_tree().current_scene.add_child(flash)


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
## Tier 0: 1-7 kills  → just score
## Tier 1: 8-14 kills → heal 1 HP
## Tier 2: 15-24 kills → heal 1 HP + 3 bonus ammo (above max)
## Tier 3: 25+ kills   → heal 1 HP + 3 bonus ammo + 2s invincibility
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
