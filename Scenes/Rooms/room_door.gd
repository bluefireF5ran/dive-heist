extends Area2D
## Door that teleports the player to a target position.
## Used for entering/exiting rest zone rooms.
## Enter with Down/S key while standing on the platform.

const DOOR1_TEX := preload(
	"res://Sprites/Active_Sprites/objects/animated/Door1.png"
)
const DOOR_FRAMES := 6
const DOOR_FRAME_SIZE := 48

@export var target_position := Vector2.ZERO
@export var is_exit := false  # Exit doors look different

var _player_in_range := false
var _player_ref: CharacterBody2D = null
var _used := false
var _world: Node2D
var _door_anim: AnimatedSprite2D


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	add_to_group("room_door")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_door_animation()


## Replace the static door sprite with an animated one that opens on approach.
func _build_door_animation() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("open")
	frames.set_animation_loop("open", false)
	frames.set_animation_speed("open", 14.0)
	for i in range(DOOR_FRAMES):
		var at := AtlasTexture.new()
		at.atlas = DOOR1_TEX
		at.region = Rect2(i * DOOR_FRAME_SIZE, 0, DOOR_FRAME_SIZE, DOOR_FRAME_SIZE)
		frames.add_frame("open", at)
	_door_anim = AnimatedSprite2D.new()
	_door_anim.sprite_frames = frames
	_door_anim.animation = "open"
	_door_anim.frame = 0
	_door_anim.z_index = -1  # Sit behind the player, not over them
	var static_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if static_sprite:
		_door_anim.position = static_sprite.position
		static_sprite.visible = false
	add_child(_door_anim)


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
	if _world and _world.has_node("Camera2D"):
		var cam: Camera2D = _world.get_node("Camera2D")
		cam.position.x = target_position.x
		cam.position.y = target_position.y
		if _world.has_method("_reset_camera_to"):
			_world._reset_camera_to(target_position)
	# Brief visual feedback
	SFX.play_descend()
	# Re-enable after a short delay to prevent double-triggering
	await get_tree().create_timer(0.5).timeout
	_used = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		_player_in_range = true
		_player_ref = body
		if _door_anim:
			_door_anim.play("open")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player_ref = null
		if _door_anim:
			_door_anim.play_backwards("open")
