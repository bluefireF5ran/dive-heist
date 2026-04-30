extends Node2D

const CAMERA_X := 128.0
const CAMERA_SMOOTH := 4.0
const START_PLATFORM_W := 120.0
const START_PLATFORM_H := 16.0
const VOID_GAP := 100.0
const TRANSITION_FADE := 0.35

var _start_y: float
var _max_camera_y: float
var _is_game_over := false
var _is_level_complete := false
var _shake_intensity := 0.0
var _shake_decay := 8.0
var _music_player: AudioStreamPlayer
var _start_platform: StaticBody2D
var _fade_overlay: ColorRect

var _current_level := 1
var _level_kills := 0
var _level_max_combo := 0
var _level_money_earned := 0
var _last_money := 0

var _total_kills := 0
var _total_money_earned := 0
var _overall_max_combo := 0

var _level_end_y := 0.0

@onready var player: CharacterBody2D = $Player
@onready var ammo_hud: CanvasLayer = $AmmoHUD
@onready var camera: Camera2D = $Camera2D
@onready var chunk_gen: Node2D = $ChunkGenerator
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var parallax: ParallaxBackground = $ParallaxBackground


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color(0.08, 0.07, 0.1))
	_start_y = player.position.y
	_max_camera_y = player.position.y
	player.ammo_changed.connect(_on_ammo_changed)
	player.hp_changed.connect(_on_hp_changed)
	player.player_died.connect(_on_player_died)
	player.combo_changed.connect(_on_combo_changed)
	player.combo_reward.connect(_on_combo_reward)
	player.money_changed.connect(_on_money_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	ammo_hud.set_max_ammo(player.MAX_AIR_AMMO)
	ammo_hud.set_ammo(player.MAX_AIR_AMMO)
	ammo_hud.set_max_hp(player.MAX_HP)
	ammo_hud.set_hp(player.MAX_HP)
	camera.position = Vector2(CAMERA_X, _start_y)
	chunk_gen.setup(_start_y)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load("res://Audio/Soundrack/Prison1.5.mp3")
	_music_player.bus = "Music"
	_music_player.autoplay = true
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 100
	_fade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_overlay)


func _update_era_clear_color(era: String) -> void:
	match era:
		"prison":
			RenderingServer.set_default_clear_color(Color(0.08, 0.07, 0.1))
		"factory":
			RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.07))
		"lab":
			RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.1))
		_:
			RenderingServer.set_default_clear_color(Color(0.08, 0.07, 0.1))


func _physics_process(delta: float) -> void:
	if _is_game_over:
		return

	if _is_level_complete:
		_max_camera_y = _level_end_y
		var end_y := lerpf(camera.position.y, _max_camera_y, CAMERA_SMOOTH * delta)
		camera.position = Vector2(CAMERA_X, end_y)
		return

	_max_camera_y = maxf(_max_camera_y, player.position.y)

	var target_y := lerpf(camera.position.y, _max_camera_y, CAMERA_SMOOTH * delta)

	var target_x := CAMERA_X
	if player.position.x > 400.0:
		target_x = player.position.x
	var cam_x := lerpf(camera.position.x, target_x, CAMERA_SMOOTH * 2.0 * delta)

	_shake_intensity = maxf(_shake_intensity - _shake_decay * delta, 0.0)
	var shake_offset := Vector2.ZERO
	if _shake_intensity > 0.1:
		var sx := randf_range(-_shake_intensity, _shake_intensity)
		var sy := randf_range(-_shake_intensity, _shake_intensity)
		shake_offset = Vector2(sx, sy)
	camera.position = Vector2(cam_x, target_y) + shake_offset

	if player.position.x < 400.0:
		left_wall.position.y = camera.position.y
		right_wall.position.y = camera.position.y

	var depth := int(maxf(0, player.position.y - _start_y))
	ammo_hud.set_depth(depth)
	chunk_gen.current_depth = depth
	chunk_gen.current_level = _current_level


func _on_ammo_changed(current: int, _max_val: int) -> void:
	ammo_hud.set_max_ammo(_max_val)
	ammo_hud.set_ammo(current)


func _on_hp_changed(current: int, _max_val: int) -> void:
	ammo_hud.set_hp(current)


func _on_combo_changed(combo: int) -> void:
	ammo_hud.set_combo(combo)
	if combo > _level_max_combo:
		_level_max_combo = combo
	if combo > _overall_max_combo:
		_overall_max_combo = combo
	if combo > 0:
		_level_kills += 1
		_total_kills += 1


func _on_combo_reward(tier: int, combo: int) -> void:
	ammo_hud.show_combo_reward(tier, combo)
	if tier >= 2:
		screen_shake(4.0)


func _on_money_changed(current: int) -> void:
	ammo_hud.set_money(current)
	if current > _last_money:
		_level_money_earned += current - _last_money
		_total_money_earned += current - _last_money
	_last_money = current


func _on_weapon_changed(weapon_name: String, color: Color) -> void:
	ammo_hud.set_weapon(weapon_name, color)


func screen_shake(intensity: float = 2.5) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _reset_camera_to(pos: Vector2) -> void:
	camera.position = Vector2(pos.x, pos.y)
	_max_camera_y = pos.y


func hitstop(duration: float = 0.04) -> void:
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false


func _on_player_died() -> void:
	_is_game_over = true
	_music_player.stop()
	SFX.play(SFX.game_over, -5.0)
	var depth := int(maxf(0, player.position.y - _start_y))
	ammo_hud.show_death_screen(depth, _total_kills, _total_money_earned, _overall_max_combo)
	set_process_input(true)


func _on_level_complete() -> void:
	if _is_level_complete or _is_game_over:
		return
	_is_level_complete = true

	_level_end_y = chunk_gen._level_end_y
	_max_camera_y = _level_end_y

	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player._in_safe_zone = true
	player._invincible_timer = 0.5

	_freeze_enemies()

	var depth := int(maxf(0, _level_end_y - _start_y))
	ammo_hud.show_level_complete(_current_level, _level_kills, _level_money_earned, _level_max_combo, depth)
	SFX.play(SFX.combo_increase, -4.0)
	screen_shake(3.0)

	_fade_out(TRANSITION_FADE)


func _freeze_enemies() -> void:
	for chunk in chunk_gen._chunks:
		for child in chunk.get_children():
			if child.has_method("set_physics_process"):
				child.set_physics_process(false)
			if child.has_method("set_process"):
				child.set_process(false)


func _get_era(level: int) -> String:
	var era_idx := level - 1
	match era_idx:
		0:
			return "prison"
		1:
			return "factory"
		2:
			return "lab"
		3:
			return "bank"
		_:
			return "escape"


func _fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.6, duration)

func _fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, duration)

func _continue_to_next_level() -> void:
	_is_level_complete = false
	var old_era := _get_era(_current_level)
	_current_level += 1
	_level_kills = 0
	_level_max_combo = 0
	_level_money_earned = 0
	ammo_hud.hide_level_complete()

	chunk_gen.clear_all_chunks()
	chunk_gen._next_chunk_y += VOID_GAP
	chunk_gen.reshuffle_stances()
	var spawn_y: float = chunk_gen._next_chunk_y - 400.0
	player.global_position = Vector2(CAMERA_X, spawn_y)
	player.velocity = Vector2.ZERO
	_max_camera_y = spawn_y
	camera.position = Vector2(CAMERA_X, spawn_y)

	_spawn_start_platform(chunk_gen._next_chunk_y)

	player._invincible_timer = 2.0
	player._stomp_invincible = 0.5
	player._in_safe_zone = true
	player.set_physics_process(true)

	var new_era := _get_era(_current_level)
	chunk_gen.spawn_void_chunk(chunk_gen._next_chunk_y - VOID_GAP, VOID_GAP)
	if new_era != old_era:
		parallax.set_era_smooth(new_era, TRANSITION_FADE)
		_update_era_clear_color(new_era)

	_fade_in(TRANSITION_FADE)
	get_tree().create_timer(1.5).timeout.connect(
		func(): player._in_safe_zone = false
	)


func _spawn_start_platform(y: float) -> void:
	if _start_platform:
		_start_platform.queue_free()
	_start_platform = StaticBody2D.new()
	_start_platform.position = Vector2(CAMERA_X, y)
	var visual := Sprite2D.new()
	visual.texture = chunk_gen.platform_tile
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.region_enabled = true
	visual.region_rect = Rect2(0, 0, START_PLATFORM_W, START_PLATFORM_H)
	_start_platform.add_child(visual)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(START_PLATFORM_W, START_PLATFORM_H)
	var col := CollisionShape2D.new()
	col.shape = shape
	_start_platform.add_child(col)
	add_child(_start_platform)


func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("jump"):
		SFX.play(SFX.restart_menu, -10.0)
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
	elif _is_level_complete and event.is_action_pressed("jump"):
		SFX.play(SFX.landing, -8.0)
		_continue_to_next_level()
