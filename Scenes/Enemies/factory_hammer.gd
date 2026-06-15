extends CharacterBody2D
## Factory HAMMER — a heavy, tanky ground bruiser. Patrols slowly; when the player
## gets close it stops, winds up (telegraph) and SLAMS the hammer in a wide arc
## around it. Armoured: shrugs off weak gunfire, so stomp it or bring a big gun.

signal died

const GRAVITY := 800.0
const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

@export var hp := 3
@export var speed := 28.0
@export var detect_x := 64.0
@export var slam_radius := 54.0
@export var armored := true  # Weak (1-dmg) shots bounce off — must stomp or use a strong gun

enum {PATROL, WINDUP, SLAM, RECOVER}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stomp_area: Area2D = $StompArea
@onready var hitbox: Area2D = $Hitbox
@onready var edge_ray: RayCast2D = $EdgeDetector

var _state := PATROL
var _t := 0.0
var _dir := 1.0
var _turn_cd := 0.0  # Debounce so tiny platforms don't make it spin
var _slam_done := false
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
				if absf(dx) < detect_x and absf(dy) < 26.0:
					if absf(dx) > 1.0:
						_dir = signf(dx)
					_state = WINDUP
					_t = 0.5
					sprite.play("Attack")
		WINDUP:
			velocity.x = 0.0
			_t -= delta
			if _t <= 0.0:
				_state = SLAM
				_t = 0.42
				_slam_done = false
		SLAM:
			velocity.x = 0.0
			_t -= delta
			if not _slam_done and _t <= 0.24:
				_slam_done = true
				_do_slam()
			if _t <= 0.0:
				_state = RECOVER
				_t = 0.45
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


## Wide hammer slam — a shockwave arc around the boss when the head comes down.
func _do_slam() -> void:
	if _world and _world.has_method("screen_shake"):
		_world.screen_shake(3.5)
	SFX.play_stomp_material()
	if not _player:
		return
	var rel: Vector2 = _player.global_position - global_position
	# Big 180° arc: anything within reach that's level with or above the head.
	if rel.length() <= slam_radius and rel.y < 22.0 and _player.has_method("take_damage"):
		_player.take_damage(1)


func take_damage(amount: int = 1, from_stomp: bool = false) -> void:
	if _is_dead:
		return
	# Armoured: weak (1-dmg) gunfire pings off — stomp it or bring a stronger gun.
	if armored and not from_stomp and amount < 2:
		modulate = Color(1.5, 1.5, 1.7, 1)
		var clang := create_tween()
		clang.tween_property(self, "modulate", Color.WHITE, 0.1)
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
	SFX.play_death_prisoner()
	_spawn_explosion()
	_spawn_money(3)
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
		take_damage(6, true)  # stomp bypasses armour
		if not _is_dead:
			return
		if _world and _world.has_method("screen_shake"):
			_world.screen_shake(3.5)
		if _world and _world.has_method("hitstop"):
			_world.hitstop(0.06)
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
