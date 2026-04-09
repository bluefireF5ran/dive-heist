extends Area2D
## Door that teleports the player to a target position.
## Used for entering/exiting rest zone rooms.
## Enter with Down/S key while standing on the platform.

@export var target_position := Vector2.ZERO
@export var is_exit := false  # Exit doors look different

var _player_in_range := false
var _player_ref: CharacterBody2D = null
var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _used or not _player_in_range or _player_ref == null:
		return
	if _player_ref.is_on_floor() and Input.is_action_just_pressed("interact"):
		_teleport()


func _teleport() -> void:
	_used = true
	_player_ref.global_position = target_position
	_player_ref.velocity = Vector2.ZERO
	_player_ref._in_safe_zone = true  # Preserve combo through door transitions
	# Move camera immediately
	var world := get_tree().current_scene
	if world.has_node("Camera2D"):
		var cam: Camera2D = world.get_node("Camera2D")
		cam.position.x = target_position.x
		cam.position.y = target_position.y
		# Reset max camera Y so it doesn't jump weirdly
		if world.has_method("_reset_camera_to"):
			world._reset_camera_to(target_position)
	# Brief visual feedback
	SFX.play(SFX.landing, -8.0)
	# Re-enable after a short delay to prevent double-triggering
	await get_tree().create_timer(0.5).timeout
	_used = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		_player_in_range = true
		_player_ref = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player_ref = null
