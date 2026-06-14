extends StaticBody2D
## One-way platform that rises while the player stands on it (and sinks back when
## empty), carrying the player up. Used in the boss arena to gain height and
## shoot/stomp the boss from above (we can only attack downward).

@export var rise_speed := 55.0
@export var max_rise := 140.0
@export var plat_width := 64.0

var _start_y: float
var _player: CharacterBody2D = null


func _ready() -> void:
	_start_y = position.y
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Detect the player
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(plat_width, 12.0)
	cs.shape = rect
	cs.position = Vector2(0, -12.0)  # just above the platform surface
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		_player = body


func _on_exit(body: Node2D) -> void:
	if body == _player:
		_player = null


func _physics_process(delta: float) -> void:
	# Only rise when the player is actually standing ON the platform (grounded and
	# above it), not merely brushing the detect area while jumping up to it — that
	# made the elevator escape upward as you tried to climb on.
	var riding := (
		is_instance_valid(_player)
		and _player.is_on_floor()
		and _player.global_position.y < global_position.y
	)
	var target := _start_y - max_rise if riding else _start_y
	var new_y := move_toward(position.y, target, rise_speed * delta)
	var dy := new_y - position.y
	position.y = new_y
	# Carry the player while rising so they ride the elevator up.
	if riding and dy < 0.0:
		_player.global_position.y += dy
