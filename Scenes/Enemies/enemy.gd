extends CharacterBody2D

signal died

const GRAVITY = 800.0
const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var speed := 40.0
@export var hp := 2
@export var walk_range := 80.0  # Distance to walk before turning
@export var is_warden := false  # Set true in warden.tscn for sound variation

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox
@onready var edge_ray: RayCast2D = $EdgeDetector

var _start_x: float
var _direction := 1.0
var _is_dead := false
var _sprite_base_x: float


func _ready() -> void:
	_start_x = global_position.x
	_sprite_base_x = sprite.position.x
	# Collision layers: body on 4, only mask world (1) — not player
	collision_layer = 4
	collision_mask = 1
	# Hitbox/StompArea detect player on layer 2
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# Patrol: walk back and forth within walk_range
	velocity.x = _direction * speed
	move_and_slide()

	# Turn around AFTER move_and_slide so is_on_wall() reflects the new state
	# and the next frame starts with the corrected direction (no jitter).
	var at_edge := is_on_floor() and not edge_ray.is_colliding()
	if is_on_wall() or at_edge:
		_direction *= -1

	# Point edge detector ahead of current direction
	edge_ray.position.x = _direction * 10.0

	# Flip sprite and compensate X offset so it doesn't "teleport"
	if _direction < 0:
		sprite.flip_h = true
		sprite.position.x = -_sprite_base_x
	else:
		sprite.flip_h = false
		sprite.position.x = _sprite_base_x

	if not _is_dead:
		sprite.play("Walk")


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		sprite.play("Hurt")
		# Brief knockback flash
		modulate = Color(2, 2, 2, 1)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	sprite.play("Death")
	if is_warden:
		SFX.play_death_warden()
	else:
		SFX.play_death_prisoner()
	_spawn_death_explosion("explosion")
	_spawn_money(2 if is_warden else 1)
	# Disable all collision
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	stomp_area.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	died.emit()
	# Remove after death animation
	await sprite.animation_finished
	queue_free()


func _spawn_death_explosion(type: String) -> void:
	var fx := DEATH_EXPLOSION.instantiate()
	fx.explosion_type = type
	fx.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", fx)


func _spawn_money(value: int) -> void:
	var money := MONEY_SCENE.instantiate()
	money.value = value
	money.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", money)


## Stomped by player falling on top
func _on_stomp_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("refill_ammo"):
		# Only stomp if player is falling
		if body.velocity.y > 0:
			take_damage(6)
			if not _is_dead:
				return  # Enemy survived — don't refill/bounce
			var world := get_tree().current_scene
			if world.has_method("screen_shake"):
				world.screen_shake(3.0)
			if world.has_method("hitstop"):
				world.hitstop(0.05)
			SFX.play_stomp_bones()
			body.refill_ammo()
			# Bounce the player upward
			body.velocity.y = -250.0


## Player touches enemy body → damage player
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		# Don't damage player if they're stomping from above
		if body.velocity.y > 0 and body.global_position.y < global_position.y:
			return
		body.take_damage(1)
