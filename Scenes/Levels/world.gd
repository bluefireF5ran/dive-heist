extends Node2D

const CAMERA_X := 128.0
const CAMERA_SMOOTH := 4.0
const START_PLATFORM_W := 120.0
const START_PLATFORM_H := 16.0
const VOID_GAP := 100.0
const TRANSITION_FADE := 0.35
## When the end-of-level platforms come into view, stop the camera this far above
## them so they sit near the bottom of the screen with the void visible below.
## Viewport is 448 tall (half = 224); 175 places the platforms near the bottom
## with a generous strip of void below for the jump-into-the-void moment.
const LEVEL_END_CAM_OFFSET := 175.0
const PERK_SELECT_SCRIPT := preload("res://Scenes/UI/perk_select.gd")
const URGE_HAZARD_SCRIPT := preload("res://Scenes/Levels/urge_hazard.gd")

# Urge mechanic — a rising hazard from the top that pressures the player to keep
# diving. It pauses on safe floors and while a combo is active.
const VIEWPORT_HALF_H := 224.0
const HAZARD_REST_MARGIN := 70.0  # How far above the view top the hazard idles
const URGE_GRACE := 2.5  # Seconds of stalling before the hazard starts descending
const HAZARD_BASE_SPEED := 28.0
const HAZARD_MAX_SPEED := 170.0
const HAZARD_ACCEL := 22.0  # Descent speed ramp per second past the grace period
const HAZARD_RECEDE_SPEED := 450.0  # How fast it pulls back when you progress

var _start_y: float
var _max_camera_y: float
var _is_game_over := false
var _is_level_complete := false
var _perk_pending := false  # Waiting for the player to pick an end-of-level perk
var _hud_perk_ids: Array = []  # Perks shown in the HUD (perk-screen picks only, not shop)
var _debug_room_active := false  # Debug chest-room test mode: lock camera on the room
var _shake_intensity := 0.0
var _shake_decay := 8.0
var _music_player: AudioStreamPlayer
var _start_platform: StaticBody2D
var _fade_overlay: ColorRect

## Debug: level to start at when launched from the main-menu debug panel (1 = normal).
static var debug_start_level := 1
## Debug: when true, drop the player straight into a chest room to test its variants.
static var debug_chest_room := false
const WEAPON_STANCE_SCRIPT := preload("res://Scenes/Rooms/weapon_stance.gd")
const CHEST_ROOM_SCENE := preload("res://Scenes/Rooms/money_stance.tscn")
const DEBUG_ROOM_X := 600.0

var _current_level := 1
var _level_kills := 0
var _level_max_combo := 0
var _level_money_earned := 0
var _last_money := 0

var _total_kills := 0
var _total_money_earned := 0
var _overall_max_combo := 0
var _total_score := 0

var _level_end_y := 0.0

# Urge mechanic state
var _hazard_visual: Node2D
var _hazard_y := 0.0
var _hazard_speed := HAZARD_BASE_SPEED
var _urge_idle := 0.0
var _urge_last_max_y := 0.0
var _was_safe := false
var _took_damage_level := false  # For the "Untouchable" achievement
var _boss_active := false  # Set by the boss; pauses the urge hazard during the fight

@onready var player: CharacterBody2D = $Player
@onready var ammo_hud: CanvasLayer = $AmmoHUD
@onready var camera: Camera2D = $Camera2D
@onready var chunk_gen: Node2D = $ChunkGenerator
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var parallax: ParallaxBackground = $ParallaxBackground


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debug: optionally start at a later level (set from the main-menu debug panel).
	_current_level = maxi(debug_start_level, 1)
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
	player.score_changed.connect(_on_score_changed)
	ammo_hud.set_max_ammo(player.MAX_AIR_AMMO)
	ammo_hud.set_ammo(player.MAX_AIR_AMMO)
	ammo_hud.set_max_hp(player.MAX_HP)
	ammo_hud.set_hp(player.MAX_HP)
	Achievements.notify_weapon(player.current_weapon)
	camera.position = Vector2(CAMERA_X, _start_y)
	chunk_gen.current_level = _current_level
	chunk_gen.setup(_start_y)
	_fill_entry_background(_start_y, _start_y)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_set_era_music(_get_era(_current_level))

	# Debug start at an advanced level: switch era visuals and give a balanced build.
	if _current_level > 1:
		var era := _get_era(_current_level)
		parallax.set_era(era)
		_update_era_clear_color(era)
		_apply_debug_build(_current_level)
		_hud_perk_ids = player.perks.duplicate()  # show the debug build's perks
		refresh_hud_perks()
	debug_start_level = 1  # reset so a normal restart begins at level 1

	if debug_chest_room:
		debug_chest_room = false
		_spawn_debug_chest_room()

	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 100
	_fade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_overlay)

	_hazard_visual = Node2D.new()
	_hazard_visual.set_script(URGE_HAZARD_SCRIPT)
	add_child(_hazard_visual)
	_hazard_y = _start_y - 2000.0  # Start far off-screen above
	_hazard_visual.position = Vector2(0, _hazard_y)
	_urge_last_max_y = _max_camera_y


const ERA_MUSIC := {
	"prison": "res://Audio/Soundrack/Prison1.5.mp3",
	"factory": "res://Audio/Soundrack/Factory.mp3",
}
var _current_music_path := ""


## Play (and loop) the soundtrack for the given era, swapping tracks if needed.
func _set_era_music(era: String) -> void:
	var path: String = ERA_MUSIC.get(era, ERA_MUSIC["factory"])
	if path == _current_music_path and _music_player.playing:
		return
	_current_music_path = path
	var stream := load(path)
	# MP3/OGG don't loop by default — the import has loop=false — so force it here.
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	_music_player.stream = stream
	_music_player.play()


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
		_max_camera_y = _level_end_y - LEVEL_END_CAM_OFFSET
		var end_y := lerpf(camera.position.y, _max_camera_y, CAMERA_SMOOTH * delta)
		camera.position = Vector2(CAMERA_X, end_y)
		return

	# Debug chest-room test: keep the camera centred on the room (no descent/urge).
	if _debug_room_active:
		camera.position = Vector2(DEBUG_ROOM_X + 160.0, _start_y - 100.0)
		return

	_max_camera_y = maxf(_max_camera_y, player.position.y)

	# Halt the descent once the end-of-level platforms are in view so the player
	# sees them near the bottom with the void below (jump-into-the-void feel).
	if chunk_gen.level_end_cam_target > 0.0:
		_max_camera_y = minf(_max_camera_y, chunk_gen.level_end_cam_target - LEVEL_END_CAM_OFFSET)

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

	_update_safe_zone()
	_update_urge(delta)
	Achievements.notify_depth(depth)


func _on_ammo_changed(current: int, _max_val: int) -> void:
	ammo_hud.set_max_ammo(_max_val)
	ammo_hud.set_ammo(current)


var _last_hp := 4

func _on_hp_changed(current: int, _max_val: int) -> void:
	ammo_hud.set_max_hp(_max_val)
	ammo_hud.set_hp(current)
	if current < _last_hp:
		_do_damage_flash()
		_took_damage_level = true
	_last_hp = current


func _do_damage_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 90
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)


func _on_combo_changed(combo: int) -> void:
	ammo_hud.set_combo(combo)
	Achievements.notify_combo(combo)
	if combo > _level_max_combo:
		_level_max_combo = combo
	if combo > _overall_max_combo:
		_overall_max_combo = combo
	if combo > 0:
		_level_kills += 1
		_total_kills += 1


func _on_score_changed(score: int) -> void:
	ammo_hud.set_score(score)
	_total_score = score


func _on_combo_reward(tier: int, combo: int) -> void:
	ammo_hud.show_combo_reward(tier, combo)
	if tier >= 2:
		screen_shake(4.0)


func _on_money_changed(current: int) -> void:
	ammo_hud.set_money(current)
	Achievements.notify_money_held(current)
	if current > _last_money:
		_level_money_earned += current - _last_money
		_total_money_earned += current - _last_money
	_last_money = current


func _on_weapon_changed(weapon_name: String, color: Color) -> void:
	ammo_hud.set_weapon(weapon_name, color)
	Achievements.notify_weapon(weapon_name)


func screen_shake(intensity: float = 2.5) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _reset_camera_to(pos: Vector2) -> void:
	camera.position = Vector2(pos.x, pos.y)
	_max_camera_y = pos.y


func hitstop(duration: float = 0.08) -> void:
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false


func _on_player_died() -> void:
	_is_game_over = true
	_music_player.stop()
	SFX.play(SFX.game_over, -5.0)
	Achievements.notify_death(_total_kills, _total_money_earned)
	var depth := int(maxf(0, player.position.y - _start_y))
	ammo_hud.show_death_screen(depth, _total_kills, _total_money_earned, _overall_max_combo)
	set_process_input(true)


func _on_level_complete() -> void:
	if _is_level_complete or _is_game_over:
		return
	_is_level_complete = true

	_level_end_y = chunk_gen._level_end_y
	_max_camera_y = _level_end_y - LEVEL_END_CAM_OFFSET

	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player._in_safe_zone = true
	player._invincible_timer = 0.5

	_freeze_enemies()

	Achievements.notify_level_complete(_current_level)
	if not _took_damage_level:
		Achievements.notify_untouchable()

	var depth := int(maxf(0, _level_end_y - _start_y))
	ammo_hud.show_level_complete(_current_level, _level_kills, _level_money_earned, _level_max_combo, depth)
	SFX.play(SFX.combo_increase, -4.0)
	screen_shake(3.0)

	_fade_out(TRANSITION_FADE)
	_show_perk_select()


func _show_perk_select() -> void:
	_perk_pending = true
	ammo_hud.lc_perk_pending = true
	var ps := PERK_SELECT_SCRIPT.new()
	ps.perk_chosen.connect(_on_perk_chosen)
	add_child(ps)


## Refresh the HUD's perk-icon row. Only perks chosen from the end-of-level perk
## screen (and debug builds) are shown — `_hud_perk_ids`. Shop purchases also add
## to player.perks (for gameplay + no-repeat) but are intentionally NOT shown here.
func refresh_hud_perks() -> void:
	var icons: Array = []
	for id: String in _hud_perk_ids:
		icons.append(PERK_SELECT_SCRIPT.PERK_ICONS.get(id, ""))
	ammo_hud.set_perks(icons)


## Debug: instantiate a chest room and drop the player inside to test its variants.
## Camera locks on the room; the exit door loops back to the spawn for repeat tries.
func _spawn_debug_chest_room() -> void:
	_debug_room_active = true
	var room := CHEST_ROOM_SCENE.instantiate()
	room.position = Vector2(DEBUG_ROOM_X, _start_y)
	add_child(room)
	var spawn_pos := Vector2(DEBUG_ROOM_X + 36.0, _start_y - 45.0)
	var spawn_marker := room.get_node_or_null("SpawnPoint")
	if spawn_marker:
		spawn_pos = spawn_marker.global_position
	var exit_door := room.get_node_or_null("ExitDoor")
	if exit_door:
		exit_door.target_position = spawn_pos
	player.global_position = spawn_pos
	player.velocity = Vector2.ZERO
	player._in_safe_zone = true
	camera.position = Vector2(DEBUG_ROOM_X + 160.0, _start_y - 100.0)


func _on_perk_chosen(perk_id: String) -> void:
	if player.has_method("apply_perk"):
		player.apply_perk(perk_id)
		Achievements.notify_perks(player.perks.size())
		_hud_perk_ids.append(perk_id)
		refresh_hud_perks()
	_perk_pending = false
	ammo_hud.lc_perk_pending = false
	_continue_to_next_level()


func _freeze_enemies() -> void:
	for chunk in chunk_gen._chunks:
		for child in chunk.get_children():
			if child.has_method("set_physics_process"):
				child.set_physics_process(false)
			if child.has_method("set_process"):
				child.set_process(false)


## Freeze/unfreeze enemies (CharacterBody2D in chunks) — used while the player is
## on a rest-zone safe floor so they aren't pressured. Leaves platforms alone.
func _set_enemies_frozen(frozen: bool) -> void:
	for chunk in chunk_gen._chunks:
		for child in chunk.get_children():
			if child is CharacterBody2D and child.has_method("take_damage"):
				child.set_physics_process(not frozen)
				child.set_process(not frozen)


## Detect safe-zone transitions and stop/restart enemies accordingly.
func _update_safe_zone() -> void:
	var safe: bool = player._in_safe_zone
	if safe and not _was_safe:
		_set_enemies_frozen(true)
	elif not safe and _was_safe:
		_set_enemies_frozen(false)
	_was_safe = safe


## Drive the rising "urge" hazard. It descends (accelerating) while the player
## stalls, but recedes off-screen when the player dives or holds a combo, and is
## fully paused on safe floors and during the level-end approach.
func _update_urge(delta: float) -> void:
	if not _hazard_visual:
		return
	var rest_y := camera.position.y - VIEWPORT_HALF_H - HAZARD_REST_MARGIN
	# Treat being off in a stance room (x > 400) as safe — the hazard must never
	# pressure or kill the player while shopping/picking weapons.
	var in_room: bool = player.position.x > 400.0
	var safe: bool = player._in_safe_zone or in_room or _boss_active
	var near_level_end: bool = chunk_gen.level_end_cam_target > 0.0
	var progressing := (_max_camera_y - _urge_last_max_y) > 0.1
	var combo_active: bool = player._combo > 0
	_urge_last_max_y = _max_camera_y

	if safe or near_level_end or progressing or combo_active:
		_urge_idle = 0.0
		_hazard_speed = HAZARD_BASE_SPEED
		_hazard_y = move_toward(_hazard_y, rest_y, HAZARD_RECEDE_SPEED * delta)
	else:
		_urge_idle += delta
		if _urge_idle > URGE_GRACE:
			_hazard_speed = minf(_hazard_speed + HAZARD_ACCEL * delta, HAZARD_MAX_SPEED)
			_hazard_y += _hazard_speed * delta
		elif _hazard_y < rest_y:
			_hazard_y = move_toward(_hazard_y, rest_y, HAZARD_RECEDE_SPEED * delta)

	_hazard_visual.position.y = _hazard_y

	# Catch the player: damage + shove down. Player i-frames gate repeat hits.
	if not safe and not near_level_end and _hazard_y >= player.position.y - 6.0:
		player.take_damage(1)
		player.velocity.y = maxf(player.velocity.y, 200.0)
		screen_shake(2.0)
		_hazard_y = player.position.y - 30.0
		_hazard_visual.position.y = _hazard_y


func _get_era(level: int) -> String:
	var era_idx := (level - 1) / 3  # 3 levels per era (Prison = 1-3, Factory = 4-6, ...)
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


## Give the player a balanced random loadout scaled to the (debug) start level.
func _apply_debug_build(level: int) -> void:
	var extra_hp := (level - 1) / 2
	for i in range(extra_hp):
		player.apply_perk("max_hp")  # +1 Max HP each (and full heal)
	player.increase_max_ammo(level - 1)

	# Random weapon from the level's unlock pool.
	var lvl_key: int = clampi(level, 1, 3)
	var pool: Array = WEAPON_STANCE_SCRIPT.WEAPONS_BY_LEVEL.get(lvl_key, [])
	if not pool.is_empty():
		player.equip_weapon(pool[randi() % pool.size()])

	# A handful of random perks (~one per level already passed).
	var perk_ids: Array = []
	for d: Dictionary in PERK_SELECT_SCRIPT.CATALOG:
		perk_ids.append(d["id"])
	perk_ids.shuffle()
	for i in range(mini(level - 1, perk_ids.size())):
		player.apply_perk(perk_ids[i])

	player.heal(player.MAX_HP)


## Fill the well background across the whole entry view: from above what the
## camera sees down to where procedural generation begins, so the spawn area
## (start platform + the gap before generation) is never left blank.
func _fill_entry_background(cam_y: float, start_plat_y: float) -> void:
	var top := cam_y - VIEWPORT_HALF_H - 32.0
	var gen_start: float = start_plat_y + chunk_gen.START_CLEARANCE
	var bottom: float = gen_start + chunk_gen.CHUNK_HEIGHT
	chunk_gen.fill_entry_background(top, bottom)


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
	_took_damage_level = false
	_boss_active = false
	Achievements.notify_level_reached(_current_level)
	ammo_hud.hide_level_complete()

	# Sync the generator's level NOW so the void chunk + start platform use the new
	# era's tiles instead of the previous level's (avoids a mixed-background flash).
	chunk_gen.current_level = _current_level

	chunk_gen.clear_all_chunks()
	chunk_gen._next_chunk_y += VOID_GAP
	chunk_gen.reshuffle_stances()
	var start_plat_y: float = chunk_gen._next_chunk_y
	# Spawn just above the start platform for a clean drop-in entrance instead of a
	# long fall through empty space.
	var spawn_y: float = start_plat_y - 120.0
	player.global_position = Vector2(CAMERA_X, spawn_y)
	player.velocity = Vector2.ZERO
	_max_camera_y = spawn_y
	camera.position = Vector2(CAMERA_X, spawn_y)

	_spawn_start_platform(start_plat_y)
	# Restart phase progression here, and begin level generation below the start
	# platform so the first chunk doesn't spawn on top of it.
	chunk_gen._level_start_y = start_plat_y
	chunk_gen._next_chunk_y = start_plat_y + chunk_gen.START_CLEARANCE

	player._invincible_timer = 2.0
	player._stomp_invincible = 0.5
	player._in_safe_zone = true
	player.set_physics_process(true)
	player.heal(1)

	# Reset the urge hazard for the new level.
	_urge_idle = 0.0
	_hazard_speed = HAZARD_BASE_SPEED
	_hazard_y = spawn_y - 2000.0
	_urge_last_max_y = _max_camera_y
	if _hazard_visual:
		_hazard_visual.position.y = _hazard_y

	var new_era := _get_era(_current_level)
	_fill_entry_background(spawn_y, start_plat_y)
	if new_era != old_era:
		parallax.set_era_smooth(new_era, TRANSITION_FADE)
		_update_era_clear_color(new_era)
		_set_era_music(new_era)

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
	visual.texture = chunk_gen._get_era_platform_tile()
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.region_enabled = true
	visual.region_rect = Rect2(0, 0, START_PLATFORM_W, START_PLATFORM_H)
	_start_platform.add_child(visual)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(START_PLATFORM_W, START_PLATFORM_H)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true  # Match gameplay platforms (jump up through it)
	_start_platform.add_child(col)
	add_child(_start_platform)


func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("jump"):
		SFX.play(SFX.restart_menu, -10.0)
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
	elif _is_level_complete and not _perk_pending and event.is_action_pressed("jump"):
		SFX.play(SFX.landing, -8.0)
		_continue_to_next_level()
