extends CharacterBody2D
## Heavy floor drone. Stomp-only enemy — bullets deal no damage.
## Slow, walks on platforms. Only stomping kills it.

signal died

const GRAVITY = 800.0
const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var speed := 15.0
@export var hp := 6
@export var walk_range := 60.0

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
	collision_layer = 4
	collision_mask = 1
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	velocity.x = _direction * speed
	move_and_slide()

	var at_edge := is_on_floor() and not edge_ray.is_colliding()
	if is_on_wall() or at_edge:
		_direction *= -1

	edge_ray.position.x = _direction * 14.0

	if _direction < 0:
		sprite.flip_h = true
		sprite.position.x = -_sprite_base_x
	else:
		sprite.flip_h = false
		sprite.position.x = _sprite_base_x

	sprite.play("Walk")


## Bullets do nothing — stomp-only enemy
func take_damage(_amount: int = 1) -> void:
	SFX.play_ricochet()


## Only stomps can kill this enemy
func stomp_damage(amount: int = 6) -> void:
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
	SFX.play_death_floor_drone()
	_spawn_death_explosion("nuclear")
	_spawn_money(5)
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


## Stomped — the only way to kill it
func _on_stomp_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("refill_ammo"):
		if body.velocity.y > 0:
			stomp_damage(6)
			if not _is_dead:
				return
			var world := get_tree().current_scene
			if world.has_method("screen_shake"):
				world.screen_shake(4.0)
			if world.has_method("hitstop"):
				world.hitstop(0.06)
			SFX.play_stomp_material()
			body.refill_ammo()
			body.velocity.y = -250.0


## Body contact damages player
func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.velocity.y > 0 and body.global_position.y < global_position.y:
			return
		body.take_damage(1)
