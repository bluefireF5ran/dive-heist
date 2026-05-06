extends Node2D


const WELL_LEFT := 0.0
const WELL_RIGHT := 256.0
const CHUNK_HEIGHT := 90.0
const SPAWN_AHEAD := 600.0
const DESPAWN_BEHIND := 400.0
const MIN_PLATFORM_W := 48.0
const MAX_PLATFORM_W := 96.0
const PLATFORM_H := 16.0
const LEVEL_LENGTH := 900.0
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
const MOVING_PLATFORM_SCRIPT := preload("res://Scenes/Levels/moving_platform.gd")
const BREAKABLE_PLATFORM_SCRIPT := preload("res://Scenes/Levels/breakable_platform.gd")
const HEATED_PLATFORM_SCRIPT := preload("res://Scenes/Levels/heated_platform.gd")

const STANCE_SCENES: Array[PackedScene] = [
	preload("res://Scenes/Rooms/shop_stance.tscn"),
	preload("res://Scenes/Rooms/money_stance.tscn"),
	preload("res://Scenes/Rooms/weapon_stance.tscn"),
]


const PHASE_CONFIG := {
	"intro":
	{
		"range": [0.0, 0.2],
		"breathing_room_chance": 0.30,
		"max_platforms": 3,
		"min_platform_w": 56.0,
		"max_platform_w": 96.0,
		"squad_chance": 0.15,
		"enemy_chance": 0.55,
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone", "bat", "frog"],
		"squad_tiers": ["easy"],
	},
	"escalation":
	{
		"range": [0.2, 0.7],
		"breathing_room_chance": 0.12,
		"max_platforms": 3,
		"min_platform_w": 44.0,
		"max_platform_w": 88.0,
		"squad_chance": 0.35,
		"enemy_chance": 0.75,
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone", "bat", "frog"],
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
		"enemy_chance": 0.90,
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone", "bat", "frog"],
		"squad_tiers": ["easy", "medium", "hard"],
	},
}

# Each squad: { tier, members: [{type, ox, oy, wall_side?}] }
const SQUAD_DEFS := [
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
			{"type": "bat", "ox": 0.0, "oy": -40.0},
		],
	},
	{
		"tier": "easy",
		"members":
		[
			{"type": "floor_drone", "ox": 0.0, "oy": 0.0},
		],
	},
	{
		"tier": "easy",
		"members":
		[
			{"type": "drone", "ox": 0.0, "oy": -25.0},
			{"type": "frog", "ox": 0.0, "oy": 0.0},
		],
	},
	{
		"tier": "easy",
		"members":
		[
			{"type": "bat", "ox": 0.0, "oy": -45.0},
			{"type": "spider", "ox": 0.0, "oy": 0.0, "wall_side": "right"},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "spider", "ox": 0.0, "oy": -10.0, "wall_side": "left"},
			{"type": "spider", "ox": 0.0, "oy": 10.0, "wall_side": "right"},
			{"type": "bat", "ox": 0.0, "oy": -40.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "frog", "ox": -25.0, "oy": 0.0},
			{"type": "frog", "ox": 25.0, "oy": 0.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "floor_drone", "ox": 0.0, "oy": 0.0},
			{"type": "bat", "ox": 0.0, "oy": -35.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "warden", "ox": -30.0, "oy": 0.0},
			{"type": "frog", "ox": 30.0, "oy": 0.0},
			{"type": "drone", "ox": 0.0, "oy": -35.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "bat", "ox": -35.0, "oy": -25.0},
			{"type": "bat", "ox": 35.0, "oy": -25.0},
			{"type": "drone", "ox": 0.0, "oy": -45.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "spider", "ox": 0.0, "oy": -20.0, "wall_side": "left"},
			{"type": "spider", "ox": 0.0, "oy": 10.0, "wall_side": "right"},
			{"type": "frog", "ox": 0.0, "oy": 0.0},
			{"type": "bat", "ox": 0.0, "oy": -35.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "floor_drone", "ox": 0.0, "oy": 0.0},
			{"type": "bat", "ox": -35.0, "oy": -25.0},
			{"type": "bat", "ox": 35.0, "oy": -25.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "spider", "ox": 0.0, "oy": -10.0, "wall_side": "left"},
			{"type": "spider", "ox": 0.0, "oy": 10.0, "wall_side": "right"},
			{"type": "floor_drone", "ox": 0.0, "oy": 0.0},
			{"type": "frog", "ox": 0.0, "oy": 0.0},
		],
	},
]

const PLATFORM_TYPE_WEIGHTS := {
	"static": {"min_level": 1, "weight": 8},
	"solid": {"min_level": 99, "weight": 3},
	"thin": {"min_level": 99, "weight": 2},
	"moving": {"min_level": 99, "weight": 2},
	"breakable": {"min_level": 1, "weight": 3},
	"heated": {"min_level": 99, "weight": 2},
}

# Each phase = 3 levels. Prison=1-3, Factory=4-6, Lab=7-9, Bank=10-12, Escape=13-15

const _FAC_TILES_DIR := (
	"res://Sprites/Craftpix/2. Escenarios/"
	+ "factory-pixel-art-32x32-tileset-for-cyberpunk/1 Tiles"
)
const _FACTORY_BG_TILES: Array[Texture2D] = [
	preload(_FAC_TILES_DIR + "/BackTile_01.png"),
	preload(_FAC_TILES_DIR + "/BackTile_02.png"),
	preload(_FAC_TILES_DIR + "/BackTile_03.png"),
	preload(_FAC_TILES_DIR + "/BackTile_04.png"),
	preload(_FAC_TILES_DIR + "/BackTile_05.png"),
	preload(_FAC_TILES_DIR + "/BackTile_06.png"),
	preload(_FAC_TILES_DIR + "/BackTile_07.png"),
	preload(_FAC_TILES_DIR + "/BackTile_08.png"),
	preload(_FAC_TILES_DIR + "/BackTile_09.png"),
]
const _FACTORY_PLATFORM: Texture2D = preload(_FAC_TILES_DIR + "/Tile_02.png")
const _FACTORY_ROOM_TILES: Array[Texture2D] = [
	preload(_FAC_TILES_DIR + "/BackTile_01.png"),
	preload(_FAC_TILES_DIR + "/BackTile_02.png"),
	preload(_FAC_TILES_DIR + "/BackTile_03.png"),
	preload(_FAC_TILES_DIR + "/BackTile_04.png"),
	preload(_FAC_TILES_DIR + "/BackTile_05.png"),
	preload(_FAC_TILES_DIR + "/BackTile_06.png"),
	preload(_FAC_TILES_DIR + "/BackTile_07.png"),
]

const ERA_DEFS := {
	"prison":
	{
		"use_exports": true,
		"room_bg_tiles": [],
		"room_tint": Color(0.55, 0.5, 0.7, 1.0),
	},
	"factory":
	{
		"use_exports": false,
		"bg_tiles": _FACTORY_BG_TILES,
		"platform_tile": _FACTORY_PLATFORM,
		"room_bg_tiles": _FACTORY_ROOM_TILES,
		"room_tint": Color(0.45, 0.5, 0.6, 1.0),
	},
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
	"heated":
	{
		"one_way": true,
		"modulate": Color(1.0, 0.2, 0.1, 1.0),
		"damage_interval": 1.0,
		"warmup_time": 0.5,
	},
}

const ZONE_CHANCE := 0.30
const ZONE_MIN_GAP := 5
const ZONE_MAX_GAP := 10
const ZONE_CHUNKS := 3
const ZONE_HEIGHT := CHUNK_HEIGHT * ZONE_CHUNKS

const ZONE_TYPES := ["corridor", "chamber", "staircase", "bottleneck", "cascade", "crossfire"]

@export var prisoner_scene: PackedScene
@export var warden_scene: PackedScene
@export var drone_scene: PackedScene
@export var spider_scene: PackedScene
@export var floor_drone_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var platform_tile: Texture2D
@export var bg_tiles: Array[Texture2D] = []
@export var spike_texture: Texture2D


var current_depth := 0
var current_level := 1
var _next_chunk_y: float = 0.0
var _chunks: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _start_y: float = 0.0
var _level_start_y: float = 0.0
var _next_rest_zone_y: float = 0.0
var _stances_in_level := 0
var _room_count := 0
var _player: CharacterBody2D
var _camera: Camera2D
var _level_end_y := 0.0
var _stance_order: Array[int] = []
var _next_zone_y: float = 0.0
var _zone_blocked_until: float = 0.0


func _ready() -> void:
	_rng.randomize()

func setup(start_y: float) -> void:
	_start_y = start_y
	_level_start_y = start_y
	_next_chunk_y = start_y + CHUNK_HEIGHT
	_next_rest_zone_y = start_y + LEVEL_LENGTH
	_next_zone_y = start_y + LEVEL_LENGTH * 0.3
	_zone_blocked_until = start_y + CHUNK_HEIGHT * 3
	_shuffle_stances()

func reshuffle_stances() -> void:
	_shuffle_stances()

## Remove all spawned chunks for a clean level transition.
func clear_all_chunks() -> void:
	for chunk in _chunks:
		chunk.queue_free()
	_chunks.clear()

func _shuffle_stances() -> void:
	_stance_order.clear()
	for i in range(STANCE_SCENES.size()):
		_stance_order.append(i)
	for i in range(_stance_order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _stance_order[i]
		_stance_order[i] = _stance_order[j]
		_stance_order[j] = tmp

func _physics_process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_2d()
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	var cam_y := _camera.global_position.y if _camera else 0.0

	while _next_chunk_y < cam_y + SPAWN_AHEAD:
		if _next_chunk_y >= _next_rest_zone_y:
			_spawn_rest_zone(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT
			_next_rest_zone_y += LEVEL_LENGTH
			_zone_blocked_until = _next_chunk_y + CHUNK_HEIGHT * 3
		elif _next_chunk_y >= _next_zone_y and _next_chunk_y >= _zone_blocked_until:
			if _rng.randf() < ZONE_CHANCE:
				_spawn_zone(_next_chunk_y)
				_next_chunk_y += ZONE_HEIGHT
				_next_zone_y = _next_chunk_y + _rng.randi_range(ZONE_MIN_GAP, ZONE_MAX_GAP) * CHUNK_HEIGHT
			else:
				_next_zone_y = _next_chunk_y + CHUNK_HEIGHT * 2
		else:
			_spawn_chunk(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT

	var i := 0
	while i < _chunks.size():
		var chunk := _chunks[i]
		if chunk.global_position.y < cam_y - DESPAWN_BEHIND:
			if _player and is_instance_valid(_player) and chunk.is_ancestor_of(_player):
				i += 1
				continue
			chunk.queue_free()
			_chunks.remove_at(i)
		else:
			i += 1


func _get_era() -> String:
	var level_idx := current_level - 1  # 0=Prison, 1=Factory, 2=Lab, ...
	match level_idx:
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

func _get_era_bg_tiles() -> Array[Texture2D]:
	var era: String = _get_era()
	if not ERA_DEFS.has(era):
		return bg_tiles
	var def: Dictionary = ERA_DEFS[era]
	if def.get("use_exports", false):
		return bg_tiles
	return def["bg_tiles"]

func _get_era_platform_tile() -> Texture2D:
	var era: String = _get_era()
	if not ERA_DEFS.has(era):
		return platform_tile
	var def: Dictionary = ERA_DEFS[era]
	if def.get("use_exports", false):
		return platform_tile
	return def["platform_tile"]

func _get_era_room_config() -> Dictionary:
	var era: String = _get_era()
	if not ERA_DEFS.has(era):
		return {"bg_tiles": [], "tint": Color(0.55, 0.5, 0.7, 1.0)}
	var def: Dictionary = ERA_DEFS[era]
	if def.get("use_exports", false):
		return {"bg_tiles": [], "tint": def["room_tint"]}
	return {"bg_tiles": def["room_bg_tiles"], "tint": def["room_tint"]}

func _get_phase(phase_progress: float) -> String:
	if phase_progress < 0.2:
		return "intro"
	if phase_progress < 0.7:
		return "escalation"
	return "climax"

func _is_near_rest_zone(y: float) -> bool:
	var buffer_dist := CHUNK_HEIGHT * REST_ZONE_BUFFER
	var dist_from_start := y - _start_y
	var remainder := fmod(dist_from_start, LEVEL_LENGTH)
	return remainder < buffer_dist or LEVEL_LENGTH - remainder < buffer_dist


func _spawn_chunk(y: float) -> void:
	var chunk := Node2D.new()
	chunk.global_position = Vector2(0, y)
	add_child(chunk)
	_chunks.append(chunk)

	_fill_background(chunk)

	var phase_progress := clampf((y - _level_start_y) / LEVEL_LENGTH, 0.0, 1.0)
	var phase := _get_phase(phase_progress)
	var cfg: Dictionary = PHASE_CONFIG[phase]

	var platforms := _place_platforms(chunk, phase, cfg, phase_progress)

	if _is_near_rest_zone(y):
		return

	if current_level >= 99:
		_maybe_place_spikes(chunk, phase)

	_populate_enemies(chunk, cfg, platforms, phase_progress)


func _place_platforms(
	chunk: Node2D, phase: String, cfg: Dictionary, phase_progress: float
) -> Array[Rect2]:
	var max_plats: int = cfg["max_platforms"]
	var plat_count := _rng.randi_range(1, max_plats)

	var sub_progress := 0.0
	if phase == "escalation":
		sub_progress = (phase_progress - 0.2) / 0.5
	elif phase == "climax":
		sub_progress = (phase_progress - 0.7) / 0.3

	var min_w: float = lerpf(cfg["min_platform_w"], cfg["min_platform_w"] - 8.0, sub_progress)
	var max_w: float = lerpf(cfg["max_platform_w"], cfg["max_platform_w"] - 12.0, sub_progress)

	var well_width := WELL_RIGHT - WELL_LEFT
	var max_total_cover := well_width - MIN_PASSAGE_WIDTH
	max_w = minf(max_w, max_total_cover)
	min_w = minf(min_w, max_w)

	var platforms: Array[Rect2] = []
	var total_covered := 0.0

	for _p in range(plat_count):
		var ptype := _pick_platform_type()
		var pcfg: Dictionary = PLATFORM_TYPE_CONFIG[ptype]

		var w: float
		if ptype == "thin":
			var wr: Array = pcfg["width_range"]
			w = _rng.randf_range(wr[0], wr[1])
		else:
			w = _rng.randf_range(min_w, max_w)

		var remaining := max_total_cover - total_covered
		if remaining < min_w:
			break  # No room for another platform
		w = minf(w, remaining)

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
			"heated":
				_add_heated_platform(chunk, cx, 0.0, w)

	return platforms

func _find_valid_x(w: float, existing: Array[Rect2]) -> float:
	var max_attempts := 10
	for _attempt in range(max_attempts):
		var x := _rng.randf_range(WELL_LEFT, WELL_RIGHT - w)
		var test_rect := Rect2(x, 0, w, PLATFORM_H)
		var valid := true
		for plat in existing:
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
			if x < 16.0:
				x = WELL_LEFT
			elif x + w > WELL_RIGHT - 16.0:
				x = WELL_RIGHT - w
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
	body.set_script(MOVING_PLATFORM_SCRIPT)
	body.move_range = cfg["move_range"]
	body.move_speed = cfg["move_speed"]

func _add_breakable_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["breakable"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "Visual"
	)
	body.collision_layer = 5
	body.set_script(BREAKABLE_PLATFORM_SCRIPT)
	body.collapse_delay = cfg["collapse_delay"]

func _add_heated_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["heated"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "Visual"
	)
	body.set_script(HEATED_PLATFORM_SCRIPT)
	body.damage_interval = cfg["damage_interval"]
	body.warmup_time = cfg["warmup_time"]

func _add_platform_body(
	parent: Node2D,
	cx: float,
	cy: float,
	w: float,
	h: float,
	one_way: bool,
	plat_modulate: Variant,
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

	var era_tile: Texture2D = _get_era_platform_tile()
	if era_tile:
		var visual := Sprite2D.new()
		visual.name = visual_name if visual_name != "" else "Visual"
		visual.texture = era_tile
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual.region_enabled = true
		visual.region_rect = Rect2(0, 0, w, h)
		if plat_modulate != null:
			visual.modulate = plat_modulate
		body.add_child(visual)

	return body


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
	if spike_texture:
		var spr := Sprite2D.new()
		spr.texture = spike_texture
		spr.flip_h = facing_left
		spike.add_child(spr)
	parent.add_child(spike)


# Zone Templates — Multi-chunk structural sections for variety

## Spawn a random zone template at the given Y position.
## Zones replace 3 normal chunks with themed platform layouts.
## No custom wall sprites — we work within the well walls (x=0, x=256).
func _spawn_zone(y: float) -> void:
	var zone_type: String = ZONE_TYPES[_rng.randi() % ZONE_TYPES.size()]
	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)

	var zone_bg := Node2D.new()
	_fill_background_zone(zone_bg, ZONE_CHUNKS)
	zone.add_child(zone_bg)

	match zone_type:
		"corridor":
			_zone_corridor(zone, y)
		"chamber":
			_zone_chamber(zone, y)
		"staircase":
			_zone_staircase(zone, y)
		"bottleneck":
			_zone_bottleneck(zone, y)
		"cascade":
			_zone_cascade(zone, y)
		"crossfire":
			_zone_crossfire(zone, y)


## Create a solid column with prison tile visuals.
## Blocks the player (StaticBody2D collision) and looks like prison architecture.
func _add_column(parent: Node2D, x: float, top_y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x, top_y + h / 2.0)
	parent.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	var tile: Texture2D = _get_era_platform_tile()
	if not tile:
		return
	var cols := maxi(1, ceili(w / TILE_SIZE))
	var rows := maxi(1, ceili(h / TILE_SIZE))
	var x_start := -w / 2.0
	for ry in range(rows):
		for rx in range(cols):
			var spr := Sprite2D.new()
			spr.texture = tile
			spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
			spr.position = Vector2(x_start + rx * TILE_SIZE + TILE_SIZE / 2.0, -h / 2.0 + ry * TILE_SIZE + TILE_SIZE / 2.0)
			spr.modulate = Color(0.45, 0.35, 0.45, 1.0)
			body.add_child(spr)


## Corridor — all platforms in the center 128px, spider-lined walls, visual columns
func _zone_corridor(zone: Node2D, y: float) -> void:
	var gap := 128.0
	var left_edge := (WELL_RIGHT - gap) / 2.0
	var right_edge := left_edge + gap
	var cfg := _zone_get_cfg(y)

	for row in range(ZONE_CHUNKS):
		var row_y := row * CHUNK_HEIGHT
		_add_column(zone, left_edge / 2.0, row_y - CHUNK_HEIGHT / 2.0, left_edge, CHUNK_HEIGHT)
		_add_column(zone, right_edge + (WELL_RIGHT - right_edge) / 2.0, row_y - CHUNK_HEIGHT / 2.0, WELL_RIGHT - right_edge, CHUNK_HEIGHT)

		var plat_w := _rng.randf_range(36.0, 56.0)
		var plat_x := _rng.randf_range(left_edge + plat_w / 2.0 + 4.0, right_edge - plat_w / 2.0 - 4.0)
		_add_platform_body(zone, plat_x, row_y - 16.0, plat_w, PLATFORM_H, true, null, "")

		if _rng.randf() < 0.50:
			_add_spider(zone, left_edge + 8.0, row_y - _rng.randf_range(5.0, 25.0), true)
		if _rng.randf() < 0.50:
			_add_spider(zone, right_edge - 8.0, row_y - _rng.randf_range(5.0, 25.0), false)

		if _rng.randf() < cfg["enemy_chance"] * 0.7:
			_add_enemy(zone, plat_x, row_y - 24.0, "prisoner")


## Chamber — wider platform spread, extra air enemies
func _zone_chamber(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	for row in range(ZONE_CHUNKS):
		var row_y := row * CHUNK_HEIGHT
		for _p in range(_rng.randi_range(3, 5)):
			var w := _rng.randf_range(24.0, 44.0)
			var cx := _rng.randf_range(WELL_LEFT + w / 2.0 + 4.0, WELL_RIGHT - w / 2.0 - 4.0)
			_add_platform_body(zone, cx, row_y - _rng.randf_range(6.0, 22.0), w, PLATFORM_H, true, null, "")

		if _rng.randf() < 0.65:
			_add_drone(zone, _rng.randf_range(20.0, 236.0), row_y - _rng.randf_range(10.0, 35.0))
		if _rng.randf() < 0.40:
			_add_bat(zone, _rng.randf_range(10.0, 246.0), row_y - _rng.randf_range(30.0, 45.0))
		if _rng.randf() < cfg["enemy_chance"] * 0.5:
			_add_spider(zone, 16.0, row_y - _rng.randf_range(5.0, 25.0), true)
			_add_spider(zone, 240.0, row_y - _rng.randf_range(5.0, 25.0), false)


## Staircase — zigzag platforms left to right
func _zone_staircase(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	var side := -1.0
	var margin := 16.0
	var plat_w := 44.0
	var step_h := CHUNK_HEIGHT / 3.0

	for i in range(ZONE_CHUNKS * 2):
		var row_y := i * step_h - CHUNK_HEIGHT * 0.25
		side *= -1.0
		var cx := margin + plat_w / 2.0 if side < 0 else WELL_RIGHT - margin - plat_w / 2.0
		_add_platform_body(zone, cx, row_y - 12.0, plat_w, PLATFORM_H, true, null, "")
		if _rng.randf() < cfg["enemy_chance"] * 0.5:
			_add_enemy(zone, cx, row_y - 24.0, "prisoner")
		if _rng.randf() < 0.30:
			_add_bat(zone, cx + side * 30.0, row_y - 40.0)


## Bottleneck — platforms converge toward center; visual columns widen
func _zone_bottleneck(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	for row in range(ZONE_CHUNKS):
		var row_y := row * CHUNK_HEIGHT
		var t := float(row) / float(ZONE_CHUNKS - 1)
		var gap := lerpf(192.0, 64.0, t)
		var left_edge := (WELL_RIGHT - gap) / 2.0
		var right_edge := left_edge + gap

		_add_column(zone, left_edge / 2.0, row_y - CHUNK_HEIGHT / 2.0, left_edge, CHUNK_HEIGHT)
		_add_column(zone, right_edge + (WELL_RIGHT - right_edge) / 2.0, row_y - CHUNK_HEIGHT / 2.0, WELL_RIGHT - right_edge, CHUNK_HEIGHT)

		if row < ZONE_CHUNKS - 1:
			var plat_w := _rng.randf_range(28.0, gap * 0.5)
			var plat_x := _rng.randf_range(left_edge + plat_w / 2.0 + 4.0, right_edge - plat_w / 2.0 - 4.0)
			_add_platform_body(zone, plat_x, row_y - 16.0, plat_w, PLATFORM_H, true, null, "")

		if _rng.randf() < cfg["enemy_chance"] * 0.6:
			_add_drone(zone, 128.0, row_y - 25.0)


## Cascade — platforms step downward like a waterfall; heavy enemies below
func _zone_cascade(zone: Node2D, y: float) -> void:
	var base_y := -CHUNK_HEIGHT * 0.3
	var step_x := WELL_RIGHT / 4.0
	for i in range(ZONE_CHUNKS * 3):
		var col := i % 3
		var row := i / 3
		var cy := base_y + row * CHUNK_HEIGHT * 0.5 + col * 12.0
		var cx := step_x + col * step_x
		var w := _rng.randf_range(20.0, 36.0)
		_add_platform_body(zone, cx, cy - 12.0, w, PLATFORM_H, true, null, "")
		if _rng.randf() < 0.35:
			_add_frog(zone, cx, cy - 24.0)
		if _rng.randf() < 0.25:
			_add_floor_drone(zone, cx, cy - 20.0)

	_add_column(zone, 8.0, -CHUNK_HEIGHT / 2.0, 16.0, ZONE_CHUNKS * CHUNK_HEIGHT)
	_add_column(zone, 248.0, -CHUNK_HEIGHT / 2.0, 16.0, ZONE_CHUNKS * CHUNK_HEIGHT)


## Crossfire — high-density combat zone, all enemy types
func _zone_crossfire(zone: Node2D, y: float) -> void:
	for row in range(ZONE_CHUNKS):
		var row_y := row * CHUNK_HEIGHT
		var plat_w := _rng.randf_range(20.0, 36.0)
		var plat_x := _rng.randf_range(WELL_LEFT + plat_w / 2.0 + 4.0, WELL_RIGHT - plat_w / 2.0 - 4.0)
		_add_platform_body(zone, plat_x, row_y - 16.0, plat_w, PLATFORM_H, true, null, "")

		var types := ["prisoner", "warden", "drone", "spider", "frog"]
		var etype: String = types[_rng.randi() % types.size()]
		match etype:
			"spider":
				_add_spider(zone, 16.0, row_y - 20.0, true)
				_add_spider(zone, 240.0, row_y - 30.0, false)
			"drone":
				_add_drone(zone, 128.0, row_y - 25.0)
			"frog":
				_add_frog(zone, plat_x, row_y - 24.0)
			_:
				_add_enemy(zone, plat_x, row_y - 24.0, etype)


## Helper: get phase config for zone Y position
func _zone_get_cfg(y: float) -> Dictionary:
	var phase_progress := clampf((y - _level_start_y) / LEVEL_LENGTH, 0.0, 1.0)
	var phase := _get_phase(phase_progress)
	return PHASE_CONFIG[phase]


## Fill background across a zone + extra overlap for seamless transitions.
func _fill_background_zone(parent: Node2D, rows: int) -> void:
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if tiles.is_empty():
		return
	var tile_count := tiles.size()
	var total_h := (rows + 2) * CHUNK_HEIGHT
	var y_off := -rows * CHUNK_HEIGHT / 2.0 - CHUNK_HEIGHT
	var total_rows := ceili(total_h / TILE_SIZE)
	for r in range(total_rows):
		var tex := tiles[_rng.randi() % tile_count]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
		spr.position = Vector2(0, y_off + r * TILE_SIZE)
		spr.z_index = -1
		parent.add_child(spr)


# Enemy Population

func _populate_enemies(
	chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2], phase_progress: float
) -> void:
	if _rng.randf() < cfg["breathing_room_chance"]:
		return

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
				if not platforms.is_empty():
					var plat: Rect2 = platforms[_rng.randi() % platforms.size()]
					var fx := plat.position.x + plat.size.x * 0.5
					_add_floor_drone(chunk, fx, -20.0)
			"bat":
				var bx := clampf(anchor.x + ox, WELL_LEFT + 10.0, WELL_RIGHT - 10.0)
				var by := anchor.y + oy
				_add_bat(chunk, bx, by)
			"frog":
				if not platforms.is_empty():
					var plat: Rect2 = platforms[_rng.randi() % platforms.size()]
					var fx := clampf(plat.position.x + plat.size.x * 0.5, WELL_LEFT + 12.0, WELL_RIGHT - 12.0)
					_add_frog(chunk, fx, -24.0)

func _try_spawn_single(
	chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2], phase_progress: float
) -> void:
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
			if not platforms.is_empty():
				var plat: Rect2 = platforms[_rng.randi() % platforms.size()]
				var fx := plat.position.x + plat.size.x * 0.5
				_add_floor_drone(chunk, fx, -20.0)
		"bat":
			var bx := _rng.randf_range(WELL_LEFT + 10, WELL_RIGHT - 10)
			var by := _rng.randf_range(-45.0, -20.0)
			_add_bat(chunk, bx, by)
		"frog":
			if not platforms.is_empty():
				var plat: Rect2 = platforms[_rng.randi() % platforms.size()]
				var fx := clampf(plat.position.x + plat.size.x * 0.5, WELL_LEFT + 12.0, WELL_RIGHT - 12.0)
				_add_frog(chunk, fx, -24.0)

# Enemy Spawn Helpers

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

func _add_bat(parent: Node2D, x: float, y: float) -> void:
	if bat_scene == null:
		return
	var bat := bat_scene.instantiate()
	bat.position = Vector2(x, y)
	parent.add_child(bat)

func _add_frog(parent: Node2D, x: float, y: float) -> void:
	if frog_scene == null:
		return
	var frog := frog_scene.instantiate()
	frog.position = Vector2(x, y)
	parent.add_child(frog)


func _spawn_rest_zone(y: float) -> void:
	if _stances_in_level >= STANCE_SCENES.size():
		_stances_in_level = 0
		_level_start_y = y + CHUNK_HEIGHT
		_level_end_y = y
		_spawn_level_end_zone(y)
		_room_count += 1
		return

	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)

	_fill_background(zone)

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

	var stance_idx := _stance_order[_stances_in_level] if _stances_in_level < _stance_order.size() else _stances_in_level
	var stance_scene: PackedScene = STANCE_SCENES[stance_idx]
	_stances_in_level += 1

	var room := stance_scene.instantiate()
	room.position = Vector2(ROOM_OFFSET_X, 0.0)
	zone.add_child(room)

	var return_pos := Vector2(plat_x, y - 32.0)
	room.exit_door.target_position = return_pos

	_configure_stance(room)

	var enter_door := ROOM_DOOR_SCENE.instantiate()
	enter_door.position = Vector2(door_x, -24.0)
	var spawn_marker := room.get_node_or_null("SpawnPoint")
	if spawn_marker:
		enter_door.target_position = spawn_marker.global_position
	else:
		enter_door.target_position = Vector2(ROOM_OFFSET_X + 40.0, y - 16.0)
	enter_door.is_exit = false
	zone.add_child(enter_door)

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


func _configure_stance(room: Node2D) -> void:
	var room_cfg: Dictionary = _get_era_room_config()
	if room.has_method("setup_room_tiles"):
		room.setup_room_tiles(room_cfg["bg_tiles"], room_cfg["tint"])
	if room.has_method("setup_weapon_offer"):
		room.setup_weapon_offer(current_level)


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

## Spawn a background-only chunk to fill the void gap between levels.
func spawn_void_chunk(y: float, gap: float) -> void:
	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if tiles.is_empty():
		return
	var rows := ceili(gap / TILE_SIZE)
	var tile_count := tiles.size()
	for row in range(rows):
		var tex: Texture2D
		var roll := _rng.randf()
		if roll < 0.02:
			tex = tiles[tile_count - 1]
		elif roll < 0.17:
			tex = tiles[_rng.randi() % tile_count]
		else:
			tex = tiles[_rng.randi() % tile_count]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
		spr.position = Vector2(0, row * TILE_SIZE)
		spr.z_index = -1
		zone.add_child(spr)

func _fill_background(chunk: Node2D) -> void:
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if tiles.is_empty():
		return
	var rows := ceili(CHUNK_HEIGHT / TILE_SIZE)
	var tile_count := tiles.size()
	for row in range(rows):
		var tex: Texture2D
		var roll := _rng.randf()
		if roll < 0.02:
			tex = tiles[tile_count - 1]
		elif roll < 0.17:
			tex = tiles[_rng.randi() % tile_count]
		else:
			tex = tiles[_rng.randi() % tile_count]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
		spr.position = Vector2(0, row * TILE_SIZE - CHUNK_HEIGHT * 0.5)
		spr.z_index = -1
		chunk.add_child(spr)
