extends Area2D
## Bomb dropped by the factory Copter. Falls under gravity and explodes on hitting
## the world or the player (or after a short fuse), dealing splash damage.

const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")

var velocity := Vector2(0.0, 30.0)
var _life := 2.2
var _exploded := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2  # world + player
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 1
	queue_redraw()


func _physics_process(delta: float) -> void:
	velocity.y += 420.0 * delta
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		_explode()


func _on_body(_b: Node2D) -> void:
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var fx := DEATH_EXPLOSION.instantiate()
	fx.explosion_type = "explosion"
	fx.global_position = global_position
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(fx)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("take_damage") and p.global_position.distance_to(global_position) < 24.0:
		p.take_damage(1)
	SFX.play(SFX.stomp_material, -4.0, 0.7)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(0.13, 0.13, 0.16))
	draw_circle(Vector2(0.0, -5.0), 1.5, Color(1.0, 0.5, 0.1))  # fuse spark
