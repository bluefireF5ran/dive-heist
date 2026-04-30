extends CharacterBody2D

signal died

const GRAVITY = 800.0
const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var hp := 3
@export var jump_velocity := -280.0
@export var jump_horizontal := 70.0
@export var windup_min := 1.5
@export var windup_max := 3.0
@export var patrol_speed := 25.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox
@onready var edge_ray: RayCast2D = $EdgeDetector

var _is_dead := false
var _hurt_timer := 0.0
var _world: Node2D
var _direction := 1.0
var _windup_timer := 0.0
var _winding_up := false
var _jumping := false
var _sprite_base_x: float
var _start_x: float


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	_start_x = global_position.x
	_sprite_base_x = sprite.position.x
	collision_layer = 4
	collision_mask = 1
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	edge_ray.position.x = _direction * 10.0
	_reset_windup()


func _reset_windup() -> void:
	_windup_timer = randf_range(windup_min, windup_max)
	_winding_up = false
	_jumping = false
	sprite.play("Idle")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_hurt_timer -= delta
	if _hurt_timer > 0.0:
		if _jumping:
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	if _jumping:
		velocity.y += GRAVITY * delta
	else:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0

	if is_on_floor() and not _jumping:
		if not _winding_up:
			_windup_timer -= delta
			if _windup_timer <= 0.0:
				_start_windup()

		if not _winding_up:
			velocity.x = _direction * patrol_speed * 0.3
			move_and_slide()
			var at_edge := is_on_floor() and not edge_ray.is_colliding()
			if is_on_wall() or at_edge:
				_direction *= -1
				edge_ray.position.x = _direction * 10.0
			_flip_sprite()
		else:
			velocity.x = 0
			move_and_slide()
	else:
		move_and_slide()
		if _jumping and is_on_floor():
			_reset_windup()
		_flip_to_player()


func _start_windup() -> void:
	_winding_up = true
	sprite.play("Attack")
	await sprite.animation_finished
	if _is_dead:
		return
	_do_jump()


func _do_jump() -> void:
	if not is_on_floor():
		return
	_jumping = true
	_winding_up = false
	_direction = -1.0 if sprite.flip_h else 1.0
	velocity.y = jump_velocity
	velocity.x = _direction * jump_horizontal
	sprite.play("Run")


func _flip_sprite() -> void:
	sprite.flip_h = _direction < 0
	sprite.position.x = -_sprite_base_x if _direction < 0 else _sprite_base_x


func _flip_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		var facing_left := player.global_position.x < global_position.x
		sprite.flip_h = facing_left
		sprite.position.x = -_sprite_base_x if facing_left else _sprite_base_x


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		_reset_windup()
		sprite.play("Hurt")
		_hurt_timer = 0.2
		modulate = Color(2, 2, 2, 1)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	sprite.play("Death")
	SFX.play_death_prisoner()
	_spawn_death_explosion("explosion")
	_spawn_money(3)
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	stomp_area.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	died.emit()
	await sprite.animation_finished
	queue_free()


func _spawn_death_explosion(type: String) -> void:
	var fx := DEATH_EXPLOSION.instantiate()
	fx.explosion_type = type
	fx.global_position = global_position
	_world.call_deferred("add_child", fx)


func _spawn_money(value: int) -> void:
	var money := MONEY_SCENE.instantiate()
	money.value = value
	money.global_position = global_position
	_world.call_deferred("add_child", money)


func _on_stomp_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("refill_ammo"):
		if body.velocity.y > 0:
			take_damage(6)
			if not _is_dead:
				return
			if _world and _world.has_method("screen_shake"):
				_world.screen_shake(2.0)
			if _world and _world.has_method("hitstop"):
				_world.hitstop(0.03)
			SFX.play_stomp_bones()
			body.refill_ammo()
			body.velocity.y = -250.0


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.velocity.y > 0 and body.global_position.y < global_position.y:
			return
		body.take_damage(1)
