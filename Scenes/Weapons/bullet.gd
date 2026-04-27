extends Area2D

var speed := 400.0
var direction := Vector2.DOWN
var damage := 1
var lifetime := 2.0

var is_piercer := false
var is_ricochet := false
var max_bounces := 0

var _world: Node2D
var _player: CharacterBody2D
var _bounce_count := 0
var _hit_enemies: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	_world = get_tree().current_scene as Node2D


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	# Damageable objects (enemies, crates, etc.) — check before wall logic
	if body.has_method("take_damage"):
		# Piercer: skip already-hit enemies
		if is_piercer and body in _hit_enemies:
			return
		if is_piercer:
			_hit_enemies.append(body)

		body.take_damage(damage)
		if damage > 0:
			SFX.play_bullet_hit()
		if "hp" in body and body.hp <= 0:
			if _world and _world.has_method("screen_shake"):
				_world.screen_shake(2.0)
			if _world and _world.has_method("hitstop"):
				_world.hitstop(0.03)
		if not _player:
			_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player and not _player.is_on_floor() and "hp" in body and body.hp <= 0:
			_player.add_combo()

		# Piercer: don't die, keep going
		if is_piercer:
			return
		queue_free()
		return

	# World collision — bounce (ricochet) or die
	if body is StaticBody2D or body is TileMapLayer:
		if is_ricochet and _bounce_count < max_bounces:
			_bounce()
			return
		queue_free()
		return

	queue_free()


func _bounce() -> void:
	_bounce_count += 1
	# Reflect: primarily reverse Y for downward-firing bullets hitting floors/ceilings
	direction.y = -direction.y
	# Slight random horizontal deflection for visual interest
	direction.x += randf_range(-0.3, 0.3)
	direction = direction.normalized()
	SFX.play(SFX.bullet_ricochet, -8.0, randf_range(1.1, 1.4))
