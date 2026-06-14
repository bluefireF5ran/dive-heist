extends Node2D
## Boss detection-cone attack (Attack1): a 90°-wide wedge from the head covering
## elevations e_min..e_max toward the player's side. Telegraphs as a faint wedge,
## then flashes and damages anyone inside. You dodge by being outside it (e.g.
## directly above the boss, or on the far side).

var facing := 1.0
var range_r := 150.0
var e_min := -30.0  # degrees, + = up
var e_max := 60.0
var telegraph := 0.6
var active := 0.3

var _t := 0.0
var _hit := false
var _player: Node2D


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= telegraph and _t < telegraph + active and not _hit:
		_check_hit()
	if _t >= telegraph + active:
		queue_free()
		return
	queue_redraw()


func _check_hit() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	var rel: Vector2 = _player.global_position - global_position
	var forward := facing * rel.x
	if forward <= 4.0 or rel.length() > range_r:
		return
	var elev := rad_to_deg(atan2(-rel.y, forward))
	if elev >= e_min and elev <= e_max and _player.has_method("take_damage"):
		_player.take_damage(1)
		_hit = true


func _draw() -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps := 8
	for i in range(steps + 1):
		var e := deg_to_rad(lerpf(e_min, e_max, float(i) / float(steps)))
		pts.append(Vector2(facing * cos(e), -sin(e)) * range_r)
	var col := Color(1.0, 0.35, 0.2, 0.16)
	if _t >= telegraph:
		col = Color(1.0, 0.4, 0.2, 0.42)
	draw_colored_polygon(pts, col)
