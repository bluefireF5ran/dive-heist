extends Area2D
## Collectible money drop. Spawned by enemies on death.
## Falls with gravity, lands on platforms, collected on player contact.

const GRAVITY := 400.0
const MAGNET_RANGE := 36.0
const MAGNET_RANGE_H := 70.0    # Wide horizontal magnet (~1/4 of well)
const MAGNET_RANGE_V := 36.0    # Tight vertical magnet (close proximity)
const MAGNET_SPEED := 120.0
const DESPAWN_TIME := 8.0
const FLOOR_CHECK_DIST := 6.0  # Raycast length to detect platforms below

@export var value := 1

var _velocity := Vector2.ZERO
var _magnetized := false
var _on_floor := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	body_entered.connect(_on_body_entered)
	# Initial pop upward with random spread
	_velocity = Vector2(randf_range(-40, 40), randf_range(-120, -60))
	# Auto despawn
	var timer := get_tree().create_timer(DESPAWN_TIME)
	timer.timeout.connect(_despawn)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D

	if _magnetized:
		if player:
			var dir := (player.global_position - global_position).normalized()
			_velocity = dir * MAGNET_SPEED
		global_position += _velocity * delta
		return

	# Gravity (only if not resting on a platform)
	if not _on_floor:
		_velocity.y += GRAVITY * delta
		global_position += _velocity * delta
		# Check if we landed on a platform (world = layer 1)
		_on_floor = _check_floor()
		if _on_floor:
			_velocity = Vector2.ZERO
	else:
		# Already resting — re-check in case platform despawns
		if not _check_floor():
			_on_floor = false

	# Check magnet range to player — wide horizontal, tight vertical
	if player:
		var diff := player.global_position - global_position
		var close := absf(diff.x) < MAGNET_RANGE_H and absf(diff.y) < MAGNET_RANGE_V
		var very_close := global_position.distance_to(player.global_position) < MAGNET_RANGE
		if close or very_close:
			_magnetized = true
			_on_floor = false


## Raycast downward to detect world geometry (collision layer 1).
func _check_floor() -> bool:
	var space := get_world_2d().direct_space_state
	# Start ray from slightly above to ensure detection when already snapped to surface
	var origin := global_position + Vector2(0, -4)
	var query := PhysicsRayQueryParameters2D.create(
		origin,
		origin + Vector2(0, FLOOR_CHECK_DIST + 4),
		1  # Mask: layer 1 = World
	)
	var result := space.intersect_ray(query)
	if result:
		# Snap to surface
		global_position.y = result.position.y
		return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("collect_money"):
		body.collect_money(value)
		queue_free()


func _despawn() -> void:
	# Fade out then remove
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
