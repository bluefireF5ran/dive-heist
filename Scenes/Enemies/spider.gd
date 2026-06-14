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
var _direction := 1.0
var _is_dead := false
var _hurt_timer := 0.0
var _on_left_wall := true
var _world: Node2D


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
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

	_hurt_timer -= _delta

	var move_speed := speed
	# Light tracking: when the player is hugging this spider's wall, drift toward
	# the player's vertical level a bit faster for a more menacing feel.
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		var same_wall := (
			absf(player.global_position.x - global_position.x) < 48.0
		)
		if same_wall:
			_direction = signf(player.global_position.y - global_position.y)
			if _direction == 0.0:
				_direction = 1.0
			move_speed = speed * 1.8

	# Don't crawl off the end of a wall/column: if there's no wall beside the spot
	# just ahead, turn back toward where the wall still is.
	if not _wall_ahead(_direction):
		_direction = -_direction

	# Patrol vertically
	velocity = Vector2(0, _direction * move_speed)
	move_and_slide()

	# Reverse at patrol limits OR when blocked by a platform above/below.
	# Spiders move purely vertically, so a platform below registers as floor and
	# one above as ceiling — reversing here stops them jamming against geometry.
	var blocked := is_on_floor() or is_on_ceiling()
	if global_position.y > _start_y + patrol_range or (blocked and _direction > 0.0):
		_direction = -1.0
	elif global_position.y < _start_y - patrol_range or (blocked and _direction < 0.0):
		_direction = 1.0

	# Play walk animation — reverse speed when going up so legs animate correctly
	if _hurt_timer <= 0.0:
		sprite.play("Walk")
	sprite.speed_scale = 1.0 if _direction > 0 else -1.0

	# Rotation: on left wall face right (90°), on right wall face left (-90°)
	if _on_left_wall:
		sprite.rotation = deg_to_rad(90.0)
	else:
		sprite.rotation = deg_to_rad(-90.0)


func set_wall_side(left: bool) -> void:
	_on_left_wall = left


## True if there's a wall (collision layer 1) beside the point a little ahead of
## the spider in `dir`, i.e. the wall it clings to continues that way.
func _wall_ahead(dir: float) -> bool:
	var ahead := global_position + Vector2(0, dir * 14.0)
	var wall_dir := -1.0 if _on_left_wall else 1.0
	var params := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(wall_dir * 26.0, 0.0), 1)
	params.exclude = [self]
	return not get_world_2d().direct_space_state.intersect_ray(params).is_empty()


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
	_world.call_deferred("add_child", fx)


func _spawn_money(value: int) -> void:
	var money := MONEY_SCENE.instantiate()
	money.value = value
	money.global_position = global_position
	_world.call_deferred("add_child", money)


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
