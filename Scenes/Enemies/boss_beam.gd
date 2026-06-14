extends Area2D
## Directional boss laser with a clear telegraph: first a thin pulsing warning
## line along its path (no damage), then a thick damaging beam. Used for the
## boss's aimed arm laser (Attack4: horizontal / up-diagonal / down). You dodge
## by getting off the line. `dir` is the beam direction (set by the boss).

var dir := Vector2.RIGHT
var length := 300.0
var thickness := 12.0
var telegraph := 0.5
var active := 0.32

var _t := 0.0
var _hit := false
var _col: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect the player
	rotation = dir.angle()
	_col = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	_col.shape = rect
	_col.position = Vector2(length / 2.0, 0)  # beam extends forward (+x) from origin
	_col.disabled = true  # no damage during the telegraph
	add_child(_col)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= telegraph and _col.disabled:
		_col.disabled = false
	if _t >= telegraph and _t < telegraph + active and not _hit:
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(1)
				_hit = true
				break
	if _t >= telegraph + active:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _t < telegraph:
		var a := 0.35 + 0.4 * absf(sin(_t * 26.0))
		draw_line(Vector2.ZERO, Vector2(length, 0), Color(1.0, 0.4, 0.2, a), 2.0)
	else:
		var h := thickness / 2.0
		draw_rect(Rect2(0, -h, length, thickness), Color(1.0, 0.3, 0.2, 0.5))
		draw_rect(Rect2(0, -2.0, length, 4.0), Color(1.0, 0.9, 0.5, 0.95))
