extends CharacterBody2D
## Factory COPTER — an aerial bomber. Hovers, tries to stay above the player, and
## periodically drops a bomb that explodes on impact. A ranged aerial threat you
## must dodge while descending; stomp or shoot it down.

signal died

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")
const BOMB_SCRIPT := preload("res://Scenes/Enemies/factory_bomb.gd")

@export var hp := 2
@export var hover_speed := 48.0
@export var target_height := 72.0
@export var bomb_interval := 2.8

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox

var _is_dead := false
var _hurt_timer := 0.0
var _bomb_cd := 1.2
var _world: Node2D
var _player: CharacterBody2D


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	collision_layer = 4
	collision_mask = 1
	stomp_area.collision_layer = 0
	stomp_area.collision_mask = 2
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	stomp_area.body_entered.connect(_on_stomp)
	hitbox.body_entered.connect(_on_hit)
	sprite.play("Run")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_hurt_timer -= delta
	_bomb_cd -= delta

	if not _player:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not _player:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var desired := Vector2(_player.global_position.x, _player.global_position.y - target_height)
	var to := desired - global_position
	if to.length() > 4.0:
		velocity = to.normalized() * hover_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var dx := _player.global_position.x - global_position.x
	var dy := _player.global_position.y - global_position.y
	if _bomb_cd <= 0.0 and absf(dx) < 28.0 and dy > 20.0 and _hurt_timer <= 0.0:
		_drop_bomb()
		_bomb_cd = bomb_interval

	if _hurt_timer <= 0.0 and sprite.animation != "Attack":
		sprite.play("Run")
	sprite.flip_h = _player.global_position.x < global_position.x


func _drop_bomb() -> void:
	sprite.play("Attack")
	var bomb := Area2D.new()
	bomb.set_script(BOMB_SCRIPT)
	_world.add_child(bomb)
	bomb.global_position = global_position + Vector2(0.0, 6.0)


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
			_world.screen_shake(2.0)
		if _world and _world.has_method("hitstop"):
			_world.hitstop(0.03)
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
