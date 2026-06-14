extends Area2D
## Boss projectile — travels in `velocity` (usually upward) and damages the
## player on contact. Code-drawn glowing orb (no texture dependency).

var velocity := Vector2(0, -160)
var life := 4.5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect the player
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(life).timeout.connect(queue_free)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.4, 0.1, 0.35))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.6, 0.15, 0.9))
	draw_circle(Vector2.ZERO, 1.5, Color(1.0, 1.0, 0.8, 1.0))


func _physics_process(delta: float) -> void:
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()
