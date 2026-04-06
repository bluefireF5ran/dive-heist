extends CharacterBody2D
## Wall-crawling spider robot. Shoot-only enemy — stomping it HURTS the player.
## Moves vertically along walls, slowly patrolling up and down.

signal died

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var speed := 20.0
@export var hp := 3
@export var patrol_range := 80.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox

var _start_y: float
var _direction := 1.0  # 1 = down, -1 = up
var _is_dead := false
var _on_left_wall := true


func _ready() -> void:
	_start_y = global_position.y
	collision_layer = 4
	collision_mask = 1
	# Stomp area HURTS player (shoot-only enemy)
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	# Patrol vertically
	velocity = Vector2(0, _direction * speed)
	move_and_slide()

	# Reverse at patrol limits
	if global_position.y > _start_y + patrol_range:
		_direction = -1.0
	elif global_position.y < _start_y - patrol_range:
		_direction = 1.0

	# Play walk animation — reverse speed when going up so legs animate correctly
	sprite.play("Walk")
	sprite.speed_scale = 1.0 if _direction > 0 else -1.0

	# Rotation: on left wall face right (90°), on right wall face left (-90°)
	if _on_left_wall:
		sprite.rotation = deg_to_rad(90.0)
	else:
		sprite.rotation = deg_to_rad(-90.0)


func set_wall_side(left: bool) -> void:
	_on_left_wall = left


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
	SFX.play_death_spider()
	_spawn_death_explosion("lightning")
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
	get_tree().current_scene.call_deferred("add_child", fx)


func _spawn_money(value: int) -> void:
	var money := MONEY_SCENE.instantiate()
	money.value = value
	money.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", money)


## Stomping this spider HURTS the player — it's shoot-only!
func _on_stomp_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		body.take_damage(1)


## Body contact also damages
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		body.take_damage(1)
