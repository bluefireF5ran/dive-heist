extends Area2D

const TRAIL_MAX := 6
const TRAIL_LENGTH := 4.0

var speed := 400.0
var direction := Vector2.DOWN
var damage := 1
var lifetime := 2.0
var weapon_color := Color(1.0, 0.9, 0.3, 1.0)

# Weapon behavior flags (set by player._spawn_bullet)
var is_piercer := false
var is_ricochet := false
var max_bounces := 0

var _trail_points: Array[Vector2] = []
var _bounce_count := 0
var _hit_enemies: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	# Record trail position before moving
	_trail_points.push_front(global_position)
	if _trail_points.size() > TRAIL_MAX:
		_trail_points.pop_back()
	position += direction * speed * delta


func _draw() -> void:
	# Draw glowing trail behind the bullet
	for i in range(_trail_points.size()):
		var local_pos := to_local(_trail_points[i])
		var t := float(i) / TRAIL_MAX
		var alpha := (1.0 - t) * 0.5
		var radius := lerpf(2.5, 0.5, t)
		draw_circle(local_pos, radius, Color(weapon_color.r, weapon_color.g, weapon_color.b, alpha))
	# Core glow around the bullet
	draw_circle(Vector2.ZERO, 3.0, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0.3))


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
		# Screen shake + hitstop on kill
		var world := get_tree().current_scene
		if "hp" in body and body.hp <= 0:
			if world.has_method("screen_shake"):
				world.screen_shake(2.0)
			if world.has_method("hitstop"):
				world.hitstop(0.03)
		# Increment player combo for bullet kills while airborne
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player and not player.is_on_floor() and "hp" in body and body.hp <= 0:
			player.add_combo()

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
