extends StaticBody2D
## Breakable platform — crumbles shortly after the player lands on it.
## Assigned at runtime by chunk_generator, not via a .tscn scene.

@export var collapse_delay := 0.5

var _triggered := false


func _ready() -> void:
	# Detect player landing via a thin Area2D just above the platform surface
	var detect := Area2D.new()
	detect.collision_mask = 2  # Player layer
	detect.collision_layer = 0
	var shape := CollisionShape2D.new()
	var detect_rect := RectangleShape2D.new()
	# Reuse the body's collision shape size (set before this script is assigned)
	var body_col := get_child(0) as CollisionShape2D
	if body_col and body_col.shape:
		detect_rect.size = Vector2(body_col.shape.size.x, 6.0)
	else:
		detect_rect.size = Vector2(48.0, 6.0)
	shape.shape = detect_rect
	shape.position = Vector2(0, -6.0)  # Slightly above surface
	detect.add_child(shape)
	add_child(detect)
	detect.body_entered.connect(_on_body_landed)


func _on_body_landed(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_start_collapse()


func _start_collapse() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	# Flash warning: 2 rapid blinks
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.3, 0.1)
		tween.tween_property(visual, "modulate:a", 1.0, 0.1)
		tween.tween_property(visual, "modulate:a", 0.3, 0.1)
		tween.tween_property(visual, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(collapse_delay).timeout
	# Disable collision and fade out
	var col := get_child(0) as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	if visual:
		var tween2 := create_tween()
		tween2.tween_property(visual, "modulate:a", 0.0, 0.2)
	await get_tree().create_timer(0.25).timeout
	queue_free()
