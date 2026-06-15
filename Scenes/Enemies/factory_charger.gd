extends CharacterBody2D
## Factory ALARMOBOT — a patrol robot. When it spots the player it raises the alarm
## (brief telegraph) and then charges at high speed in the player's direction until
## it hits a wall or ledge. Fast and aggressive, but commits to the charge.

signal died

const GRAVITY := 800.0
const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var hp := 3
@export var speed := 24.0
@export var charge_speed := 115.0
@export var detection_range := 130.0

enum {PATROL, ALARM, CHARGE, RECOVER}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox
@onready var edge_ray: RayCast2D = $EdgeDetector

var _state := PATROL
var _t := 0.0
var _dir := 1.0
var _turn_cd := 0.0  # Debounce so tiny platforms don't make it spin
var _is_dead := false
var _hurt_timer := 0.0
var _sprite_base_x: float
var _world: Node2D
var _player: CharacterBody2D


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	_sprite_base_x = sprite.position.x
	collision_layer = 4
	collision_mask = 1
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp)
	hitbox.body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_hurt_timer -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	match _state:
		PATROL:
			_turn_cd -= delta
			var at_edge := is_on_floor() and not edge_ray.is_colliding()
			if is_on_wall() or at_edge:
				velocity.x = 0.0  # hold at the edge so it never spins or walks off
				if _turn_cd <= 0.0:
					_dir *= -1.0
					_turn_cd = 0.3
			else:
				velocity.x = _dir * speed
			edge_ray.position.x = _dir * 10.0
			if _hurt_timer <= 0.0:
				sprite.play("Run")
			if _player and is_on_floor():
				var dx := _player.global_position.x - global_position.x
				var dy := _player.global_position.y - global_position.y
				if absf(dx) < detection_range and absf(dy) < 40.0:
					if absf(dx) > 1.0:
						_dir = signf(dx)
					_state = ALARM
					_t = 0.55
					velocity.x = 0.0
					sprite.play("Alarm")
		ALARM:
			velocity.x = 0.0
			_t -= delta
			if _t <= 0.0:
				_state = CHARGE
				_t = 2.2
				sprite.play("Run")
		CHARGE:
			velocity.x = _dir * charge_speed
			edge_ray.position.x = _dir * 10.0
			var at_edge := is_on_floor() and not edge_ray.is_colliding()
			_t -= delta
			if is_on_wall() or at_edge or _t <= 0.0:
				velocity.x = 0.0
				_state = RECOVER
				_t = 0.6
				sprite.play("Idle")
		RECOVER:
			velocity.x = 0.0
			_t -= delta
			if _t <= 0.0:
				_state = PATROL

	move_and_slide()
	if _dir < 0:
		sprite.flip_h = true
		sprite.position.x = -_sprite_base_x
	else:
		sprite.flip_h = false
		sprite.position.x = _sprite_base_x


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		sprite.play("Hurt")
		_hurt_timer = 0.2
		modulate = Color(2, 2, 2, 1)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	sprite.play("Death")
	SFX.play_death_drone()
	_spawn_explosion()
	_spawn_money(2)
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	stomp_area.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	died.emit()
	await sprite.animation_finished
	queue_free()


func _spawn_explosion() -> void:
	var fx := DEATH_EXPLOSION.instantiate()
	fx.explosion_type = "explosion"
	fx.global_position = global_position
	_world.call_deferred("add_child", fx)


func _spawn_money(value: int) -> void:
	var money := MONEY_SCENE.instantiate()
	money.value = value
	money.global_position = global_position
	_world.call_deferred("add_child", money)


func _on_stomp(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("refill_ammo") and body.velocity.y > 0:
		take_damage(6)
		if not _is_dead:
			return
		if _world and _world.has_method("screen_shake"):
			_world.screen_shake(2.5)
		if _world and _world.has_method("hitstop"):
			_world.hitstop(0.04)
		SFX.play_stomp_bones()
		body.refill_ammo()
		body.velocity.y = -250.0


func _on_hit(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.velocity.y > 0 and body.global_position.y < global_position.y:
			return
		body.take_damage(1)
