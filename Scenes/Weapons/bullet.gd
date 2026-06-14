extends Area2D

const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")
const BULLET_SCENE := preload("res://Scenes/Weapons/bullet.tscn")

var speed := 400.0
var direction := Vector2.DOWN
var damage := 1
var lifetime := 2.0

var is_piercer := false
var is_ricochet := false
var max_bounces := 0

# Extended behaviors (default off → straight-line bullet, identical to before)
var is_homing := false
var homing_turn := 3.0  # radians/sec steering toward nearest enemy
var bullet_gravity := 0.0  # downward accel for arcing shots
var is_explosive := false
var explosion_radius := 26.0
var explosion_damage := 1
var split_count := 0  # fragments spawned when the bullet is consumed
var is_fragment := false  # split fragments never split again

var _world: Node2D
var _player: CharacterBody2D
var _bounce_count := 0
var _hit_enemies: Array[Node2D] = []
var _velocity := Vector2.ZERO
var _homing_target: Node2D = null
var _retarget_timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	_world = get_tree().current_scene as Node2D
	_velocity = direction * speed


func _physics_process(delta: float) -> void:
	if is_homing:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0 or not is_instance_valid(_homing_target):
			_homing_target = _nearest_enemy()
			_retarget_timer = 0.12
		if is_instance_valid(_homing_target):
			var desired := (_homing_target.global_position - global_position).normalized()
			var ang := _velocity.angle_to(desired)
			ang = clampf(ang, -homing_turn * delta, homing_turn * delta)
			_velocity = _velocity.rotated(ang)

	if bullet_gravity != 0.0:
		_velocity.y += bullet_gravity * delta

	position += _velocity * delta


## Find the closest enemy (collision layer 4) within range for homing.
func _nearest_enemy() -> Node2D:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 130.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	params.collide_with_bodies = true
	var hits := space.intersect_shape(params, 8)
	var best: Node2D = null
	var best_d := INF
	for h in hits:
		var c: Object = h.get("collider")
		if c and c is Node2D and c.has_method("take_damage"):
			var d := global_position.distance_squared_to(c.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best


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

		if is_explosive:
			_explode()
		# Piercer keeps going through enemies
		if is_piercer:
			return
		_consume()
		return

	# World collision — bounce (ricochet) or die
	if body is StaticBody2D or body is TileMapLayer:
		if is_ricochet and _bounce_count < max_bounces:
			_bounce()
			return
		if is_explosive:
			_explode()
		_consume()
		return

	_consume()


## End-of-life: spawn split fragments (if any), then free.
func _consume() -> void:
	if split_count > 0 and not is_fragment:
		_split()
	queue_free()


## Spawn `split_count` fragment bullets in a fan around the travel direction.
func _split() -> void:
	if not _world:
		return
	var base := _velocity.angle() if _velocity.length() > 0.1 else direction.angle()
	var spread := deg_to_rad(70.0)
	var tex: Texture2D = null
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		tex = spr.texture
	for i in range(split_count):
		var frag := BULLET_SCENE.instantiate()
		var t := 0.0 if split_count == 1 else float(i) / float(split_count - 1)
		var ang := base - spread * 0.5 + spread * t
		frag.direction = Vector2.from_angle(ang)
		frag.speed = maxf(speed * 0.8, 260.0)
		frag.damage = 1
		frag.lifetime = 0.5
		frag.is_fragment = true
		frag.global_position = global_position
		_world.add_child(frag)
		var frag_spr := frag.get_node_or_null("Sprite2D") as Sprite2D
		if frag_spr and tex:
			frag_spr.texture = tex


## Deal area damage to all enemies within explosion_radius and spawn VFX.
func _explode() -> void:
	if not _world:
		return
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	params.collide_with_bodies = true
	var hits := space.intersect_shape(params, 16)
	for h in hits:
		var c: Object = h.get("collider")
		if c and c is Node2D and c.has_method("take_damage") and not (c in _hit_enemies):
			c.take_damage(explosion_damage)
	# VFX + feedback
	var fx := DEATH_EXPLOSION.instantiate()
	fx.explosion_type = "explosion"
	fx.global_position = global_position
	_world.call_deferred("add_child", fx)
	if _world.has_method("screen_shake"):
		_world.screen_shake(2.5)


func _bounce() -> void:
	_bounce_count += 1
	# Reflect: primarily reverse Y for downward-firing bullets hitting floors/ceilings
	_velocity.y = -_velocity.y
	# Slight random horizontal deflection for visual interest
	_velocity.x += randf_range(-0.3, 0.3) * speed
	_velocity = _velocity.normalized() * speed  # keep constant speed after bounce
	SFX.play(SFX.bullet_ricochet, -8.0, randf_range(1.1, 1.4))
