extends Node2D
## Spawns platform chunks below the camera as the player descends.
## Each chunk is a horizontal slice of the well with platforms and enemies.
##
## Generation pipeline per chunk:
##   1. Resolve phase (intro / escalation / climax) from position within level
##   2. Place platforms (type selected by level number + phase)
##   3. Decide enemy content (breathing room / single / squad)
##   4. Populate enemies from phase-appropriate pools
##
## Every LEVEL_LENGTH, a rest zone appears. A level has 3 stances that cycle:
##   Stance 0 → Shop (NPC + 3 items)
##   Stance 1 → Money (breakable crate with money)
##   Stance 2 → Weapon (weapon pickup)

# =============================================================================
# Constants — all constants must precede variables per GDScript lint rules
# =============================================================================

const WELL_LEFT := 0.0
const WELL_RIGHT := 256.0
const CHUNK_HEIGHT := 90.0
const SPAWN_AHEAD := 600.0
const DESPAWN_BEHIND := 400.0
const MIN_PLATFORM_W := 48.0
const MAX_PLATFORM_W := 96.0
const PLATFORM_H := 16.0
const LEVEL_LENGTH := 600.0
const TILE_SIZE := 32.0
const ROOM_OFFSET_X := 600.0
const LEVEL_END_GAP_WIDTH := 64.0
const LEVEL_END_TRIGGER_HEIGHT := 200.0
const MIN_PLATFORM_GAP := 20.0  # Min horizontal gap between platforms in a chunk
const MIN_PASSAGE_WIDTH := 48.0  # Guaranteed vertical drop-through gap per chunk
const REST_ZONE_BUFFER := 2  # Chunks before/after rest zones that are enemy-free

const ROOM_DOOR_SCENE := preload("res://Scenes/Rooms/room_door.tscn")
const ROOM_PLATFORM_TEX := preload(
	"res://Sprites/Scraper/Cyberpunk_Assets/Tilesets/Prison/1 Tiles/room_platform.png"
)
const LEVEL_END_TRIGGER_SCRIPT := preload("res://Scenes/Levels/level_end_trigger.gd")

# Stance scenes — cycled in order: shop → money → weapon → shop → …
const STANCE_SCENES: Array[PackedScene] = [
	preload("res://Scenes/Rooms/shop_stance.tscn"),
	preload("res://Scenes/Rooms/money_stance.tscn"),
	preload("res://Scenes/Rooms/weapon_stance.tscn"),
]

# =============================================================================
# Phase Configuration — controls pacing within each 600m level
# =============================================================================

const PHASE_CONFIG := {
	"intro":
	{
		"range": [0.0, 0.2],
		"breathing_room_chance": 0.35,
		"max_platforms": 3,
		"min_platform_w": 56.0,
		"max_platform_w": 96.0,
		"squad_chance": 0.0,
		"enemy_chance": 0.50,
		"enemy_types": ["prisoner"],
		"squad_tiers": [],
	},
	"escalation":
	{
		"range": [0.2, 0.7],
		"breathing_room_chance": 0.15,
		"max_platforms": 3,
		"min_platform_w": 44.0,
		"max_platform_w": 88.0,
		"squad_chance": 0.35,
		"enemy_chance": 0.70,
		"enemy_types": ["prisoner", "warden", "drone", "spider"],
		"squad_tiers": ["easy", "medium"],
	},
	"climax":
	{
		"range": [0.7, 1.0],
		"breathing_room_chance": 0.05,
		"max_platforms": 2,
		"min_platform_w": 36.0,
		"max_platform_w": 72.0,
		"squad_chance": 0.55,
		"enemy_chance": 0.85,
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone"],
		"squad_tiers": ["medium", "hard"],
	},
}

# =============================================================================
# Squad Definitions — curated enemy combinations
# =============================================================================

# Each squad: { tier, members: [{type, ox, oy, wall_side?}] }
# Offsets are relative to an anchor point (center of widest platform).
const SQUAD_DEFS := [
	# --- EASY ---
	{
		"tier": "easy",
		"members":
		[
			{"type": "prisoner", "ox": -30.0, "oy": 0.0},
			{"type": "prisoner", "ox": 30.0, "oy": 0.0},
		],
	},
	{
		"tier": "easy",
		"members":
		[
			{"type": "prisoner", "ox": 0.0, "oy": 0.0},
			{"type": "drone", "ox": 0.0, "oy": -35.0},
		],
	},
	# --- MEDIUM ---
	{
		"tier": "medium",
		"members":
		[
			{"type": "spider", "ox": 0.0, "oy": -10.0, "wall_side": "left"},
			{"type": "spider", "ox": 0.0, "oy": 10.0, "wall_side": "right"},
			{"type": "drone", "ox": 0.0, "oy": -30.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "warden", "ox": -25.0, "oy": 0.0},
			{"type": "warden", "ox": 25.0, "oy": 0.0},
			{"type": "drone", "ox": 0.0, "oy": -30.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "floor_drone", "ox": 0.0, "oy": 0.0},
			{"type": "warden", "ox": -40.0, "oy": 0.0},
			{"type": "warden", "ox": 40.0, "oy": 0.0},
		],
	},
	# --- HARD ---
	{
		"tier": "hard",
		"members":
		[
			{"type": "drone", "ox": -40.0, "oy": -20.0},
			{"type": "drone", "ox": 40.0, "oy": -20.0},
			{"type": "drone", "ox": 0.0, "oy": -45.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "spider", "ox": 0.0, "oy": -20.0, "wall_side": "left"},
			{"type": "spider", "ox": 0.0, "oy": 10.0, "wall_side": "right"},
			{"type": "warden", "ox": 0.0, "oy": 0.0},
			{"type": "drone", "ox": 0.0, "oy": -35.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "floor_drone", "ox": 0.0, "oy": 0.0},
			{"type": "drone", "ox": -35.0, "oy": -25.0},
			{"type": "drone", "ox": 35.0, "oy": -25.0},
		],
	},
]

# =============================================================================
# Platform Types — unlocked by level number
# =============================================================================

const PLATFORM_TYPE_WEIGHTS := {
	"static": {"min_level": 1, "weight": 10},
	"solid": {"min_level": 1, "weight": 3},
	"thin": {"min_level": 3, "weight": 2},
	"moving": {"min_level": 4, "weight": 2},
	"breakable": {"min_level": 4, "weight": 2},
}

const PLATFORM_TYPE_CONFIG := {
	"static": {"one_way": true, "modulate": null},
	"solid": {"one_way": false, "modulate": Color(0.7, 0.65, 0.6, 1.0)},
	"thin": {"one_way": true, "modulate": null, "width_range": [24.0, 32.0], "height": 12.0},
	"moving":
	{
		"one_way": true,
		"modulate": Color(0.4, 0.7, 1.0, 1.0),
		"move_range": 60.0,
		"move_speed": 40.0,
	},
	"breakable":
	{
		"one_way": true,
		"modulate": Color(1.0, 0.6, 0.3, 1.0),
		"collapse_delay": 0.5,
	},
}

# =============================================================================
# Exports
# =============================================================================

@export var prisoner_scene: PackedScene
@export var warden_scene: PackedScene
@export var drone_scene: PackedScene
@export var spider_scene: PackedScene
@export var floor_drone_scene: PackedScene
@export var platform_tile: Texture2D
@export var bg_tiles: Array[Texture2D] = []
@export var spike_texture: Texture2D
@export var moving_platform_script: GDScript
@export var breakable_platform_script: GDScript

# =============================================================================
# Variables
# =============================================================================

var current_depth := 0  # Set by world.gd
var current_level := 1  # Set by world.gd
var _next_chunk_y: float = 0.0
var _chunks: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _start_y: float = 0.0
var _level_start_y: float = 0.0  # Y where current level began (for phase calc)
var _next_rest_zone_y: float = 0.0
var _stances_in_level := 0
var _room_count := 0

# =============================================================================
# Lifecycle
# =============================================================================


func _ready() -> void:
	_rng.randomize()


func setup(start_y: float) -> void:
	_start_y = start_y
	_level_start_y = start_y
	_next_chunk_y = start_y + CHUNK_HEIGHT
	_next_rest_zone_y = start_y + LEVEL_LENGTH


func _physics_process(_delta: float) -> void:
	var cam_y := (
		get_viewport().get_camera_2d().global_position.y if get_viewport().get_camera_2d() else 0.0
	)

	# Spawn new chunks ahead of camera
	while _next_chunk_y < cam_y + SPAWN_AHEAD:
		if _next_chunk_y >= _next_rest_zone_y:
			_spawn_rest_zone(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT
			_next_rest_zone_y += LEVEL_LENGTH
		else:
			_spawn_chunk(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT

	# Despawn old chunks far above camera
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var i := 0
	while i < _chunks.size():
		var chunk := _chunks[i]
		if chunk.global_position.y < cam_y - DESPAWN_BEHIND:
			if player and is_instance_valid(player) and chunk.is_ancestor_of(player):
				i += 1
				continue
			chunk.queue_free()
			_chunks.remove_at(i)
		else:
			i += 1


# =============================================================================
# Phase Resolution
# =============================================================================


func _get_phase(phase_progress: float) -> String:
	if phase_progress < 0.2:
		return "intro"
	if phase_progress < 0.7:
		return "escalation"
	return "climax"


## Check if this chunk Y is within REST_ZONE_BUFFER chunks of any rest zone / level end.
func _is_near_rest_zone(y: float) -> bool:
	var buffer_dist := CHUNK_HEIGHT * REST_ZONE_BUFFER
	# Check distance to every rest zone boundary (past and future)
	# Rest zones occur at: _start_y + LEVEL_LENGTH, _start_y + 2*LEVEL_LENGTH, etc.
	var zone_y := _start_y + LEVEL_LENGTH
	while zone_y < y + buffer_dist:
		if absf(y - zone_y) < buffer_dist:
			return true
		zone_y += LEVEL_LENGTH
	return false


# =============================================================================
# Chunk Generation Pipeline
# =============================================================================


func _spawn_chunk(y: float) -> void:
	var chunk := Node2D.new()
	chunk.global_position = Vector2(0, y)
	add_child(chunk)
	_chunks.append(chunk)

	_fill_background(chunk)

	# 1. Resolve phase
	var phase_progress := clampf((y - _level_start_y) / LEVEL_LENGTH, 0.0, 1.0)
	var phase := _get_phase(phase_progress)
	var cfg: Dictionary = PHASE_CONFIG[phase]

	# 2. Place platforms
	var platforms := _place_platforms(chunk, phase, cfg, phase_progress)

	# 3. Check if near a rest zone or level end — skip enemies and hazards
	if _is_near_rest_zone(y):
		return

	# 4. Place hazards (spikes for level 5+)
	if current_level >= 5:
		_maybe_place_spikes(chunk, phase)

	# 5. Populate enemies
	_populate_enemies(chunk, cfg, platforms, phase_progress)


# =============================================================================
# Platform Placement
# =============================================================================


func _place_platforms(
	chunk: Node2D, phase: String, cfg: Dictionary, phase_progress: float
) -> Array[Rect2]:
	var max_plats: int = cfg["max_platforms"]
	var plat_count := _rng.randi_range(1, max_plats)

	# Narrow platforms further within each phase
	var sub_progress := 0.0
	if phase == "escalation":
		sub_progress = (phase_progress - 0.2) / 0.5
	elif phase == "climax":
		sub_progress = (phase_progress - 0.7) / 0.3

	var min_w: float = lerpf(cfg["min_platform_w"], cfg["min_platform_w"] - 8.0, sub_progress)
	var max_w: float = lerpf(cfg["max_platform_w"], cfg["max_platform_w"] - 12.0, sub_progress)

	# Cap max platform width so total coverage can never seal the well
	var well_width := WELL_RIGHT - WELL_LEFT
	var max_total_cover := well_width - MIN_PASSAGE_WIDTH
	max_w = minf(max_w, max_total_cover)
	min_w = minf(min_w, max_w)

	var platforms: Array[Rect2] = []
	var total_covered := 0.0

	for _p in range(plat_count):
		var ptype := _pick_platform_type()
		var pcfg: Dictionary = PLATFORM_TYPE_CONFIG[ptype]

		# Width
		var w: float
		if ptype == "thin":
			var wr: Array = pcfg["width_range"]
			w = _rng.randf_range(wr[0], wr[1])
		else:
			w = _rng.randf_range(min_w, max_w)

		# Would this exceed the max coverage? Clamp width to fit
		var remaining := max_total_cover - total_covered
		if remaining < min_w:
			break  # No room for another platform
		w = minf(w, remaining)

		# Try to find a valid X position (no overlap with existing platforms)
		var x := _find_valid_x(w, platforms)
		if x < 0.0:
			continue  # Couldn't place without overlap

		var plat_rect := Rect2(x, 0, w, PLATFORM_H)
		platforms.append(plat_rect)
		total_covered += w

		var cx := x + w / 2.0
		match ptype:
			"static":
				_add_static_platform(chunk, cx, 0.0, w)
			"solid":
				_add_solid_platform(chunk, cx, 0.0, w)
			"thin":
				_add_thin_platform(chunk, cx, 0.0, w)
			"moving":
				_add_moving_platform(chunk, cx, 0.0, w)
			"breakable":
				_add_breakable_platform(chunk, cx, 0.0, w)

	return platforms


## Find a valid X for a platform of width w that doesn't overlap existing platforms.
## Returns -1.0 if no valid position found after several attempts.
func _find_valid_x(w: float, existing: Array[Rect2]) -> float:
	var max_attempts := 10
	for _attempt in range(max_attempts):
		var x := _rng.randf_range(WELL_LEFT, WELL_RIGHT - w)
		var test_rect := Rect2(x, 0, w, PLATFORM_H)
		var valid := true
		for plat in existing:
			# Check horizontal overlap with MIN_PLATFORM_GAP padding
			var padded := Rect2(
				plat.position.x - MIN_PLATFORM_GAP,
				0,
				plat.size.x + MIN_PLATFORM_GAP * 2.0,
				PLATFORM_H
			)
			if test_rect.intersects(padded):
				valid = false
				break
		if valid:
			return x
	return -1.0


func _pick_platform_type() -> String:
	var pool: Array[String] = []
	for type: String in PLATFORM_TYPE_WEIGHTS:
		var info: Dictionary = PLATFORM_TYPE_WEIGHTS[type]
		if current_level >= info["min_level"]:
			for _w in range(int(info["weight"])):
				pool.append(type)
	if pool.is_empty():
		return "static"
	return pool[_rng.randi() % pool.size()]


func _add_static_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	_add_platform_body(parent, cx, cy, w, PLATFORM_H, true, null, "")


func _add_solid_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["solid"]
	_add_platform_body(parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "")


func _add_thin_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["thin"]
	_add_platform_body(parent, cx, cy, w, cfg["height"], cfg["one_way"], cfg["modulate"], "")


func _add_moving_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["moving"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], ""
	)
	if moving_platform_script:
		body.set_script(moving_platform_script)
		body.move_range = cfg["move_range"]
		body.move_speed = cfg["move_speed"]


func _add_breakable_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["breakable"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "Visual"
	)
	if breakable_platform_script:
		body.set_script(breakable_platform_script)
		body.collapse_delay = cfg["collapse_delay"]


func _add_platform_body(
	parent: Node2D,
	cx: float,
	cy: float,
	w: float,
	h: float,
	one_way: bool,
	modulate: Variant,
	visual_name: String
) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)
	parent.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)

	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = one_way
	body.add_child(col)

	# Visual — tiled platform tile
	if platform_tile:
		var visual := Sprite2D.new()
		visual.name = visual_name if visual_name != "" else "Visual"
		visual.texture = platform_tile
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual.region_enabled = true
		visual.region_rect = Rect2(0, 0, w, h)
		if modulate != null:
			visual.modulate = modulate
		body.add_child(visual)

	return body


# =============================================================================
# Spike Hazards (Level 5+)
# =============================================================================


func _maybe_place_spikes(chunk: Node2D, phase: String) -> void:
	var chance := 0.10
	if phase == "escalation":
		chance = 0.20
	elif phase == "climax":
		chance = 0.35
	if _rng.randf() >= chance:
		return

	var on_left := _rng.randf() < 0.5
	var spike_x := 16.0 if on_left else WELL_RIGHT - 16.0
	var spike_y := _rng.randf_range(-35.0, 35.0)
	_add_spike_hazard(chunk, spike_x, spike_y, on_left)


func _add_spike_hazard(parent: Node2D, x: float, y: float, facing_left: bool) -> void:
	var spike := Area2D.new()
	spike.collision_layer = 0
	spike.collision_mask = 2  # Detect player
	spike.position = Vector2(x, y)
	spike.body_entered.connect(
		func(body: Node2D) -> void:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(1)
	)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 8.0)
	shape.shape = rect
	spike.add_child(shape)
	# Visual
	if spike_texture:
		var spr := Sprite2D.new()
		spr.texture = spike_texture
		spr.flip_h = facing_left
		spike.add_child(spr)
	parent.add_child(spike)


# =============================================================================
# Enemy Population
# =============================================================================


func _populate_enemies(
	chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2], phase_progress: float
) -> void:
	# 1. Breathing room check
	if _rng.randf() < cfg["breathing_room_chance"]:
		return

	# 2. Decide: squad vs single
	var squad_chance: float = cfg["squad_chance"]
	if _rng.randf() < squad_chance:
		_try_spawn_squad(chunk, cfg, platforms)
		return

	_try_spawn_single(chunk, cfg, platforms, phase_progress)


func _try_spawn_squad(chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2]) -> void:
	var tiers: Array = cfg["squad_tiers"]
	var eligible: Array[Dictionary] = []
	for squad: Dictionary in SQUAD_DEFS:
		if tiers.has(squad["tier"]):
			eligible.append(squad)
	if eligible.is_empty():
		return

	var squad: Dictionary = eligible[_rng.randi() % eligible.size()]
	_place_squad(chunk, squad, platforms)


func _place_squad(chunk: Node2D, squad_def: Dictionary, platforms: Array[Rect2]) -> void:
	# Anchor: center of widest platform, or well center
	var anchor := Vector2((WELL_LEFT + WELL_RIGHT) / 2.0, 0.0)
	if not platforms.is_empty():
		var widest := platforms[0]
		for plat in platforms:
			if plat.size.x > widest.size.x:
				widest = plat
		anchor = Vector2(widest.position.x + widest.size.x / 2.0, 0.0)

	var members: Array = squad_def["members"]
	for member: Dictionary in members:
		var mtype: String = member["type"]
		var ox: float = member["ox"]
		var oy: float = member["oy"]

		match mtype:
			"spider":
				var wall_side: String = member.get("wall_side", "left")
				var on_left := wall_side == "left"
				var sx := 20.0 if on_left else WELL_RIGHT - 20.0
				var sy := clampf(anchor.y + oy, -CHUNK_HEIGHT * 0.4, CHUNK_HEIGHT * 0.4)
				_add_spider(chunk, sx, sy, on_left)
			"drone":
				var dx := clampf(anchor.x + ox, WELL_LEFT + 20.0, WELL_RIGHT - 20.0)
				var dy := anchor.y + oy
				_add_drone(chunk, dx, dy)
			"prisoner", "warden":
				var ex := clampf(anchor.x + ox, WELL_LEFT + 12.0, WELL_RIGHT - 12.0)
				_add_enemy(chunk, ex, -16.0, mtype)
			"floor_drone":
				# Needs a wide platform — find one
				for plat in platforms:
					if plat.size.x >= 64.0:
						var fx := plat.position.x + plat.size.x * 0.5
						_add_floor_drone(chunk, fx, -20.0)
						break


func _try_spawn_single(
	chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2], phase_progress: float
) -> void:
	# Scale enemy chance with sub-progress within the phase
	var base_chance: float = cfg["enemy_chance"]
	var chance := lerpf(base_chance - 0.1, base_chance, phase_progress)
	chance = clampf(chance, 0.0, 1.0)
	if _rng.randf() >= chance:
		return

	var types: Array = cfg["enemy_types"]
	var etype: String = types[_rng.randi() % types.size()]

	match etype:
		"prisoner", "warden":
			if platforms.is_empty():
				return
			var plat: Rect2 = platforms[_rng.randi() % platforms.size()]
			var ex := _rng.randf_range(plat.position.x + 12, plat.position.x + plat.size.x - 12)
			_add_enemy(chunk, ex, -16.0, etype)
		"drone":
			var dx := _rng.randf_range(WELL_LEFT + 20, WELL_RIGHT - 20)
			var dy := _rng.randf_range(-30.0, 30.0)
			_add_drone(chunk, dx, dy)
		"spider":
			var on_left := _rng.randf() < 0.5
			var sx := 20.0 if on_left else WELL_RIGHT - 20.0
			var sy := _rng.randf_range(-40.0, 40.0)
			_add_spider(chunk, sx, sy, on_left)
		"floor_drone":
			for plat in platforms:
				if plat.size.x >= 64.0:
					var fx := plat.position.x + plat.size.x * 0.5
					_add_floor_drone(chunk, fx, -20.0)
					break


# =============================================================================
# Enemy Spawn Helpers
# =============================================================================


func _add_enemy(parent: Node2D, x: float, y: float, enemy_type: String = "") -> void:
	var scene: PackedScene
	if enemy_type == "warden":
		scene = warden_scene
	elif (
		enemy_type == "" and _rng.randf() < lerpf(0.3, 0.55, clampf(current_level / 10.0, 0.0, 1.0))
	):
		scene = warden_scene
	else:
		scene = prisoner_scene

	if scene == null:
		return
	var enemy := scene.instantiate()
	enemy.position = Vector2(x, y)
	parent.add_child(enemy)


func _add_drone(parent: Node2D, x: float, y: float) -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	drone.position = Vector2(x, y)
	parent.add_child(drone)


func _add_spider(parent: Node2D, x: float, y: float, on_left: bool) -> void:
	if spider_scene == null:
		return
	var spider := spider_scene.instantiate()
	spider.position = Vector2(x, y)
	parent.add_child(spider)
	spider.set_wall_side(on_left)


func _add_floor_drone(parent: Node2D, x: float, y: float) -> void:
	if floor_drone_scene == null:
		return
	var fdrone := floor_drone_scene.instantiate()
	fdrone.position = Vector2(x, y)
	parent.add_child(fdrone)


# =============================================================================
# Rest Zone — Green platform with door on one wall
# =============================================================================


func _spawn_rest_zone(y: float) -> void:
	# After 3 stances, spawn end-of-level zone instead of another stance room
	if _stances_in_level >= STANCE_SCENES.size():
		_stances_in_level = 0
		_level_start_y = y + CHUNK_HEIGHT  # New level starts after this zone
		_spawn_level_end_zone(y)
		_room_count += 1
		return

	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)

	_fill_background(zone)

	# Choose which wall side the platform goes on
	var on_left := _rng.randf() < 0.5
	var plat_w := 80.0
	var plat_x: float
	if on_left:
		plat_x = plat_w / 2.0
	else:
		plat_x = WELL_RIGHT - plat_w / 2.0

	_add_room_platform(zone, plat_x, 0.0, plat_w)

	var door_x: float
	if on_left:
		door_x = 8.0
	else:
		door_x = WELL_RIGHT - 8.0

	var stance_scene: PackedScene = STANCE_SCENES[_stances_in_level]
	_stances_in_level += 1

	var room := stance_scene.instantiate()
	room.position = Vector2(ROOM_OFFSET_X, 0.0)
	zone.add_child(room)

	var return_pos := Vector2(plat_x, y - 32.0)
	room.exit_door.target_position = return_pos

	_configure_stance(room)

	var room_enter_pos := Vector2(ROOM_OFFSET_X + 40.0, y - 16.0)
	var enter_door := ROOM_DOOR_SCENE.instantiate()
	enter_door.position = Vector2(door_x, -24.0)
	enter_door.target_position = room_enter_pos
	enter_door.is_exit = false
	zone.add_child(enter_door)

	# Safe zone: preserve player combo while in this rest area
	var safe_area := Area2D.new()
	safe_area.collision_layer = 0
	safe_area.collision_mask = 2  # Detect player (layer 2)
	safe_area.position = Vector2(WELL_RIGHT / 2.0, 0.0)
	var safe_shape := CollisionShape2D.new()
	var safe_rect := RectangleShape2D.new()
	safe_rect.size = Vector2(WELL_RIGHT, CHUNK_HEIGHT)
	safe_shape.shape = safe_rect
	safe_area.add_child(safe_shape)
	safe_area.body_entered.connect(
		func(body: Node2D) -> void:
			if body.is_in_group("player"):
				body._in_safe_zone = true
	)
	safe_area.body_exited.connect(
		func(body: Node2D) -> void:
			if body.is_in_group("player"):
				body._in_safe_zone = false
	)
	zone.add_child(safe_area)

	_room_count += 1


# =============================================================================
# Level End Zone — Full-width platform with center gap, no enemies
# =============================================================================


func _spawn_level_end_zone(y: float) -> void:
	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)

	_fill_background(zone)

	var well_center := (WELL_LEFT + WELL_RIGHT) / 2.0
	var half_gap := LEVEL_END_GAP_WIDTH / 2.0

	var left_w := well_center - half_gap - WELL_LEFT
	var left_cx := WELL_LEFT + left_w / 2.0
	_add_room_platform(zone, left_cx, 0.0, left_w)

	var right_w := WELL_RIGHT - (well_center + half_gap)
	var right_cx := well_center + half_gap + right_w / 2.0
	_add_room_platform(zone, right_cx, 0.0, right_w)

	var trigger := Area2D.new()
	trigger.set_script(LEVEL_END_TRIGGER_SCRIPT)
	trigger.position = Vector2(well_center, LEVEL_END_TRIGGER_HEIGHT / 2.0 + PLATFORM_H)
	zone.add_child(trigger)

	var trigger_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(LEVEL_END_GAP_WIDTH, LEVEL_END_TRIGGER_HEIGHT)
	trigger_shape.shape = shape
	trigger.add_child(trigger_shape)


# =============================================================================
# Stance Configuration
# =============================================================================


func _configure_stance(room: Node2D) -> void:
	if room.has_method("setup_weapon_offer"):
		room.setup_weapon_offer(current_level)


# =============================================================================
# Room Platform (green one-way, for rest zones and level end)
# =============================================================================


func _add_room_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)
	parent.add_child(body)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, PLATFORM_H)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	body.add_child(col)
	var visual := Sprite2D.new()
	visual.texture = ROOM_PLATFORM_TEX
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.region_enabled = true
	visual.region_rect = Rect2(0, 0, w, PLATFORM_H)
	body.add_child(visual)


# =============================================================================
# Background Tiles
# =============================================================================


func _fill_background(chunk: Node2D) -> void:
	if bg_tiles.is_empty():
		return
	var rows := ceili(CHUNK_HEIGHT / TILE_SIZE)
	var cols := ceili(WELL_RIGHT / TILE_SIZE)
	var base_count := bg_tiles.size() - 1
	for row in range(rows):
		var base_idx := _rng.randi() % base_count
		for col in range(cols):
			var spr := Sprite2D.new()
			if _rng.randf() < 0.02:
				spr.texture = bg_tiles[bg_tiles.size() - 1]
			elif _rng.randf() < 0.15:
				spr.texture = bg_tiles[_rng.randi() % base_count]
			else:
				spr.texture = bg_tiles[base_idx]
			spr.centered = false
			spr.position = Vector2(col * TILE_SIZE, row * TILE_SIZE - CHUNK_HEIGHT * 0.5)
			spr.z_index = -1
			chunk.add_child(spr)
