extends CharacterBody2D
## Floating drone that drifts toward the player, like Downwell's white jelly.
## Ignores gravity, bobs up and down, and slowly homes in on the player.

signal died

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var hp := 2
@export var chase_speed := 45.0
@export var bob_amplitude := 3.0
@export var bob_speed := 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox

var _is_dead := false
var _time := 0.0
var _sprite_base_x: float


func _ready() -> void:
	_sprite_base_x = sprite.position.x
	# Collision: body on layer 4, only mask world (1) for wall bouncing
	collision_layer = 4
	collision_mask = 1
	# Areas detect player on layer 2
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_time += delta

	# Find player
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * chase_speed
	else:
		velocity = Vector2.ZERO

	# Add vertical bob
	velocity.y += sin(_time * bob_speed) * bob_amplitude * 60.0 * delta

	move_and_slide()

	# Flip sprite toward player
	if velocity.x < -5:
		sprite.flip_h = true
		sprite.position.x = -_sprite_base_x
	elif velocity.x > 5:
		sprite.flip_h = false
		sprite.position.x = _sprite_base_x

	sprite.play("Walk")


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
	_spawn_death_explosion("blue_oval")
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
	get_tree().current_scene.call_deferred("add_child", fx)


func _spawn_money(value: int) -> void:
	var money := MONEY_SCENE.instantiate()
	money.value = value
	money.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", money)


func _on_stomp_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("refill_ammo"):
		take_damage(6)
		if not _is_dead:
			return  # Enemy survived — don't refill/bounce
		var world := get_tree().current_scene
		if world.has_method("screen_shake"):
			world.screen_shake(3.0)
		if world.has_method("hitstop"):
			world.hitstop(0.05)
		SFX.play_stomp_material()
		body.refill_ammo()
		body.velocity.y = -250.0


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		# Don't damage player if they're above (stomping)
		if body.global_position.y < global_position.y:
			return
		body.take_damage(1)
