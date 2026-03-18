extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var ammo_hud: CanvasLayer = $AmmoHUD
@onready var camera: Camera2D = $Camera2D
@onready var chunk_gen: Node2D = $ChunkGenerator
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall

const CAMERA_X := 128.0
const CAMERA_SMOOTH := 4.0  # How fast camera catches up when player falls

var _start_y: float
var _max_camera_y: float  # Camera only moves DOWN, never up
var _is_game_over := false
var _shake_intensity := 0.0
var _shake_decay := 8.0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	# Allow this node to run hitstop timers while tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Dark prison background
	RenderingServer.set_default_clear_color(Color(0.08, 0.07, 0.1))
	_start_y = player.position.y
	_max_camera_y = player.position.y
	player.ammo_changed.connect(_on_ammo_changed)
	player.hp_changed.connect(_on_hp_changed)
	player.player_died.connect(_on_player_died)
	player.combo_changed.connect(_on_combo_changed)
	player.combo_reward.connect(_on_combo_reward)
	player.money_changed.connect(_on_money_changed)
	ammo_hud.set_max_ammo(player.MAX_AIR_AMMO)
	ammo_hud.set_ammo(player.MAX_AIR_AMMO)
	ammo_hud.set_max_hp(player.MAX_HP)
	ammo_hud.set_hp(player.MAX_HP)
	camera.position = Vector2(CAMERA_X, _start_y)
	chunk_gen.setup(_start_y)
	# Background music
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load("res://Audio/Soundrack/Prison1.5.mp3")
	_music_player.bus = "Music"
	_music_player.autoplay = true
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)


func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	# Camera only scrolls down — never follows player upward (Downwell style)
	_max_camera_y = maxf(_max_camera_y, player.position.y)
	var target_y := lerpf(camera.position.y, _max_camera_y, CAMERA_SMOOTH * delta)

	# Camera X: centered in well normally, follows player in rooms
	var target_x := CAMERA_X
	if player.position.x > 400.0:
		# Player is in a side room — center camera on room
		target_x = player.position.x
	var cam_x := lerpf(camera.position.x, target_x, CAMERA_SMOOTH * 2.0 * delta)

	# Screen shake
	_shake_intensity = maxf(_shake_intensity - _shake_decay * delta, 0.0)
	var shake_offset := Vector2.ZERO
	if _shake_intensity > 0.1:
		shake_offset = Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity))
	camera.position = Vector2(cam_x, target_y) + shake_offset

	# Keep walls centered on camera (only when in the well)
	if player.position.x < 400.0:
		left_wall.position.y = camera.position.y
		right_wall.position.y = camera.position.y

	# Depth score (positive = how far down)
	var depth := int(maxf(0, player.position.y - _start_y))
	ammo_hud.set_depth(depth)

	# Pass depth to chunk generator for difficulty scaling
	chunk_gen.current_depth = depth


func _on_ammo_changed(current: int, _max_val: int) -> void:
	ammo_hud.set_ammo(current)


func _on_hp_changed(current: int, _max_val: int) -> void:
	ammo_hud.set_hp(current)


func _on_combo_changed(combo: int) -> void:
	ammo_hud.set_combo(combo)


func _on_combo_reward(tier: int, combo: int) -> void:
	ammo_hud.show_combo_reward(tier, combo)
	if tier >= 2:
		screen_shake(4.0)


func _on_money_changed(current: int) -> void:
	ammo_hud.set_money(current)


## Screen shake — call from anywhere via get_tree().current_scene.screen_shake()
func screen_shake(intensity: float = 2.5) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


## Reset camera to follow player at a new position (used by room doors).
func _reset_camera_to(pos: Vector2) -> void:
	camera.position = Vector2(pos.x, pos.y)
	_max_camera_y = pos.y


## Brief hitstop freeze for impactful kills
func hitstop(duration: float = 0.04) -> void:
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false


func _on_player_died() -> void:
	_is_game_over = true
	_music_player.stop()
	SFX.play(SFX.game_over, -5.0)
	ammo_hud.show_game_over()
	# Wait for restart input
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("jump"):
		SFX.play(SFX.restart_menu, -10.0)
		get_tree().reload_current_scene()
