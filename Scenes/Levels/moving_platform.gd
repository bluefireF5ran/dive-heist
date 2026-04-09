extends StaticBody2D
## Moving platform — oscillates horizontally between two boundaries.
## Assigned at runtime by chunk_generator, not via a .tscn scene.

@export var move_range := 60.0
@export var move_speed := 40.0

var _start_x: float
var _direction := 1.0


func _ready() -> void:
	_start_x = global_position.x


func _physics_process(delta: float) -> void:
	position.x += _direction * move_speed * delta
	if global_position.x > _start_x + move_range:
		_direction = -1.0
	elif global_position.x < _start_x - move_range:
		_direction = 1.0
