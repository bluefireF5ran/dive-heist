extends CharacterBody2D

signal died

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var hp := 2
@export var dive_speed_h := 130.0
@export var dive_speed_v := 80.0
@export var detection_range := 180.0
@export var return_speed := 60.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox

var _is_dead := false
var _world: Node2D
var _player: CharacterBody2D
var _start_pos: Vector2
var _diving := false
var _dive_timer := 0.0


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	_start_pos = global_position
	collision_layer = 4
	collision_mask = 1
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	sprite.play("Idle")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not _player:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not _player:
		return

	var dy := _player.global_position.y - global_position.y
	var dx := _player.global_position.x - global_position.x

	if not _diving and dy > 0 and absf(dy) < detection_range:
		_diving = true
		_dive_timer = 1.5
		sprite.play("Forward")

	if _diving:
		_dive_timer -= delta
		var dir := (_player.global_position - global_position).normalized()
		velocity.x = dir.x * dive_speed_h
		velocity.y = dir.y * dive_speed_v
		if _dive_timer <= 0.0 or (dy < 30.0 and dy > -30.0 and absf(dx) < 30.0):
			_diving = false
			sprite.play("Idle")
	else:
		var return_dir := (_start_pos - global_position).normalized()
		velocity = return_dir * return_speed
		if global_position.distance_squared_to(_start_pos) < 400.0:
			velocity = Vector2.ZERO

	move_and_slide()
	if _diving and get_last_slide_collision():
		_diving = false
		_dive_timer = 0.0
		sprite.play("Idle")
	_flip_toward_player()


func _flip_toward_player() -> void:
	if _player:
		sprite.flip_h = _player.global_position.x < global_position.x


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount
	if hp <= 0:
		_die()
	else:
		sprite.play("Hurt")
		modulate = Color(2, 2, 2, 1)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	sprite.play("Death")
	SFX.play_death_drone()
	_spawn_death_explosion("explosion")
	_spawn_money(2)
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
