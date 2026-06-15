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
const START_CLEARANCE := CHUNK_HEIGHT * 1.5  # Empty space below the start platform

const ROOM_DOOR_SCENE := preload("res://Scenes/Rooms/room_door.tscn")
const ROOM_PLATFORM_TEX := preload(
	"res://Sprites/Active_Sprites/tiles/prison_walls/room_platform.png"
)
const LEVEL_END_TRIGGER_SCRIPT := preload("res://Scenes/Levels/level_end_trigger.gd")
const MOVING_PLATFORM_SCRIPT := preload("res://Scenes/Levels/moving_platform.gd")
const BREAKABLE_PLATFORM_SCRIPT := preload("res://Scenes/Levels/breakable_platform.gd")
const HEATED_PLATFORM_SCRIPT := preload("res://Scenes/Levels/heated_platform.gd")
const WALL_TRAP_SCRIPT := preload("res://Scenes/Levels/wall_trap.gd")
const BOSS_SCENE := preload("res://Scenes/Enemies/boss_warden.tscn")
const FACTORY_BOSS_SCENE := preload("res://Scenes/Enemies/boss_loader.tscn")
const ELEVATOR_SCRIPT := preload("res://Scenes/Levels/elevator_platform.gd")
const SAW_TEX := preload("res://Sprites/Active_Sprites/objects/animated/Saw.png")

## Spinning-sawblade frames, built once and shared by all wall hazards.
static var _saw_frames_cache: SpriteFrames

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
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone", "bat", "frog", "hammer", "alarmobot", "copter"],
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
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone", "bat", "frog", "hammer", "alarmobot", "copter"],
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
		"enemy_types": ["prisoner", "warden", "drone", "spider", "floor_drone", "bat", "frog", "hammer", "alarmobot", "copter"],
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
	# --- Factory squads (only eligible when the era filter allows these types) ---
	{
		"tier": "easy",
		"members":
		[
			{"type": "hammer", "ox": 0.0, "oy": 0.0},
		],
	},
	{
		"tier": "easy",
		"members":
		[
			{"type": "alarmobot", "ox": -28.0, "oy": 0.0},
			{"type": "drone", "ox": 28.0, "oy": -28.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "hammer", "ox": 0.0, "oy": 0.0},
			{"type": "copter", "ox": 0.0, "oy": -45.0},
		],
	},
	{
		"tier": "medium",
		"members":
		[
			{"type": "alarmobot", "ox": -30.0, "oy": 0.0},
			{"type": "alarmobot", "ox": 30.0, "oy": 0.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "hammer", "ox": -28.0, "oy": 0.0},
			{"type": "alarmobot", "ox": 28.0, "oy": 0.0},
			{"type": "copter", "ox": 0.0, "oy": -50.0},
		],
	},
	{
		"tier": "hard",
		"members":
		[
			{"type": "copter", "ox": -35.0, "oy": -45.0},
			{"type": "copter", "ox": 35.0, "oy": -45.0},
			{"type": "hammer", "ox": 0.0, "oy": 0.0},
		],
	},
]

const PLATFORM_TYPE_WEIGHTS := {
	"static": {"min_level": 1, "weight": 7},
	"thin": {"min_level": 1, "weight": 3},
	"breakable": {"min_level": 1, "weight": 3},
	"solid": {"min_level": 2, "weight": 2},
	"moving": {"min_level": 2, "weight": 3},
	"heated": {"min_level": 2, "weight": 2},
}

# Each phase = 3 levels. Prison=1-3, Factory=4-6, Lab=7-9, Bank=10-12, Escape=13-15

const _FAC_TILES_DIR := "res://Sprites/Active_Sprites/tiles/factory"
# BackTile 01-06 are full dark background tiles (07-09 are triangular/half-height
# and don't tile cleanly with our algorithm, so they're excluded).
const _FACTORY_BG_TILES: Array[Texture2D] = [
	preload(_FAC_TILES_DIR + "/BackTile_01.png"),
	preload(_FAC_TILES_DIR + "/BackTile_02.png"),
	preload(_FAC_TILES_DIR + "/BackTile_03.png"),
	preload(_FAC_TILES_DIR + "/BackTile_04.png"),
	preload(_FAC_TILES_DIR + "/BackTile_05.png"),
	preload(_FAC_TILES_DIR + "/BackTile_06.png"),
]
const _FACTORY_ROOM_TILES: Array[Texture2D] = _FACTORY_BG_TILES

# Per platform-type tiles. Tile_02 standard, Tile_01 brown/destructible,
# Tile_04 thin, Tile_07 light/moving, Tile_38 continuous solid block.
const _FAC_TILE_STANDARD: Texture2D = preload(_FAC_TILES_DIR + "/Tile_02.png")
const _FAC_TILE_BREAKABLE: Texture2D = preload(_FAC_TILES_DIR + "/Tile_01.png")
const _FAC_TILE_THIN: Texture2D = preload(_FAC_TILES_DIR + "/Tile_04.png")
const _FAC_TILE_MOVING: Texture2D = preload(_FAC_TILES_DIR + "/Tile_07.png")
const _FAC_TILE_SOLID: Texture2D = preload(_FAC_TILES_DIR + "/Tile_38.png")
const _FACTORY_PLATFORM: Texture2D = _FAC_TILE_STANDARD

# Prison breakable platforms use the reddish-tinted Tile_43.
const _PRISON_BREAKABLE: Texture2D = preload(
	"res://Sprites/Active_Sprites/tiles/prison_ground/Tile_43.png"
)

# Prison wall/column tiles (Scraper tileset) for width-changing structures — a
# 9-slice: bordered platform-top row on top (Tile_1/2/3, or Tile_4 when 1 wide),
# pillar body below (Tile_9/10/11, or Tile_12 when 1 wide).
const _PRISON_TILES := "res://Sprites/Active_Sprites/tiles/prison_walls/"
const _PW_TOP_L: Texture2D = preload(_PRISON_TILES + "Tile_01.png")
const _PW_TOP_M: Texture2D = preload(_PRISON_TILES + "Tile_02.png")
const _PW_TOP_R: Texture2D = preload(_PRISON_TILES + "Tile_03.png")
const _PW_TOP_1: Texture2D = preload(_PRISON_TILES + "Tile_04.png")
const _PW_BODY_L: Texture2D = preload(_PRISON_TILES + "Tile_09.png")
const _PW_BODY_M: Texture2D = preload(_PRISON_TILES + "Tile_10.png")
const _PW_BODY_R: Texture2D = preload(_PRISON_TILES + "Tile_11.png")
const _PW_BODY_1: Texture2D = preload(_PRISON_TILES + "Tile_12.png")
const _PW_BOT_L: Texture2D = preload(_PRISON_TILES + "Tile_17.png")  # bottom-left
const _PW_BOT_M: Texture2D = preload(_PRISON_TILES + "Tile_18.png")  # bottom edge
const _PW_BOT_R: Texture2D = preload(_PRISON_TILES + "Tile_19.png")  # bottom-right
const _PW_BOT_1: Texture2D = preload(_PRISON_TILES + "Tile_20.png")  # bottom, both sides (1 wide)
const _PW_BLOCK: Texture2D = preload(_PRISON_TILES + "Tile_28.png")  # 1x1, all 4 sides

# Prison decoration props (from "3 Objects/3 Stuff", named 1.png..34.png).
const PROP_DIR := "res://Sprites/Active_Sprites/objects/prison_props/"

## Hand-authored decor per stance room (index into STANCE_SCENES: 0=shop, 1=money,
## 2=weapon). Each entry: id, center x, top-left y, and w/h. Room interior is
## x 0..320, floor top -8, ceiling ~-200; player is ~32px tall (head near -40).
## Cameras/lamps hang from the ceiling; screens sit at head height; floor props
## rest on the floor. All kept inside x 0..320 so nothing clips the walls.
const ROOM_DECOR := {
	# Shop — door@27, spawn@40, NPC@~138, items@175/232/289.
	0:
	[
		{"id": 4, "x": 66.0, "y": -27.0, "w": 19, "h": 19},  # wc  ┐ bathroom
		{"id": 5, "x": 92.0, "y": -24.0, "w": 14, "h": 16},  # washer ┘ corner
		{"id": 31, "x": 300.0, "y": -24.0, "w": 20, "h": 16},  # crate ┐ stack
		{"id": 32, "x": 300.0, "y": -36.0, "w": 16, "h": 12},  # crate ┘ (far right)
		{"id": 8, "x": 160.0, "y": -188.0, "w": 14, "h": 3},  # ceiling lamp
		{"id": 21, "x": 250.0, "y": -186.0, "w": 13, "h": 10},  # ceiling camera
	],
	# Money — vertical hazard climb; dress only the top entry ledge + ceiling.
	1:
	[
		{"id": 30, "x": 30.0, "y": -33.0, "w": 10, "h": 9},  # bucket on entry ledge
		{"id": 8, "x": 160.0, "y": -188.0, "w": 14, "h": 3},  # ceiling lamp
	],
	# Weapon — cards fill the floor; dress the ceiling and a big back-wall screen.
	2:
	[
		{"id": 8, "x": 160.0, "y": -188.0, "w": 14, "h": 3},  # ceiling lamp
		{"id": 21, "x": 60.0, "y": -186.0, "w": 13, "h": 10},  # ceiling camera
		# Screen at ~1/3 across the room (away from the wall), at head height.
		{"id": 25, "x": 107.0, "y": -58.0, "w": 17, "h": 12},
	],
}

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

const ZONE_CHANCE := 0.40
const ZONE_MIN_GAP := 4
const ZONE_MAX_GAP := 9
const ZONE_CHUNKS := 3
const ZONE_HEIGHT := CHUNK_HEIGHT * ZONE_CHUNKS

const ZONE_TYPES := [
	"corridor", "chamber", "staircase", "bottleneck", "cascade", "crossfire", "shaft", "ledges"
]

@export var prisoner_scene: PackedScene
@export var warden_scene: PackedScene
@export var drone_scene: PackedScene
@export var spider_scene: PackedScene
@export var floor_drone_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var hammer_scene: PackedScene
@export var alarmobot_scene: PackedScene
@export var copter_scene: PackedScene
@export var platform_tile: Texture2D
@export var bg_tiles: Array[Texture2D] = []
@export var spike_texture: Texture2D


var current_depth := 0
var current_level := 1
var _next_chunk_y: float = 0.0
var _chunks: Array[Node2D] = []
var _decorable_plats: Array[Rect2] = []  # Static/solid platforms safe to decorate
var _gen_paused := false  # Halts new chunk generation (e.g. during the boss fight)
var _rng := RandomNumberGenerator.new()
var _start_y: float = 0.0
var _level_start_y: float = 0.0
var _next_rest_zone_y: float = 0.0
var _stances_in_level := 0
var _room_count := 0
var _player: CharacterBody2D
var _camera: Camera2D
var _level_end_y := 0.0
## World Y of this level's end platform once its end-zone has spawned (0 = none yet).
## world.gd reads this to halt the camera so the final platforms sit near the
## bottom of the view, selling the "jump into the void" moment.
var level_end_cam_target := 0.0
var _stance_order: Array[int] = []
var _next_zone_y: float = 0.0
var _zone_blocked_until: float = 0.0


func _ready() -> void:
	_rng.randomize()

func setup(start_y: float) -> void:
	_start_y = start_y
	_level_start_y = start_y
	# Begin generation well below the start platform so the first chunk doesn't
	# spawn on top of it.
	_next_chunk_y = start_y + START_CLEARANCE
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
	level_end_cam_target = 0.0
	_gen_paused = false

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

	while not _gen_paused and _next_chunk_y < cam_y + SPAWN_AHEAD:
		if _next_chunk_y >= _next_rest_zone_y:
			_spawn_rest_zone(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT
			_next_rest_zone_y += LEVEL_LENGTH
			_zone_blocked_until = _next_chunk_y + CHUNK_HEIGHT * 3
		elif _next_chunk_y >= _next_zone_y and _next_chunk_y >= _zone_blocked_until:
			# Don't carve a center-path zone if it would finish too close to the
			# upcoming rest zone — the rest platform sits against a side wall and
			# the player needs room (the rest-zone buffer of normal chunks) to
			# reach it after being funneled to the middle.
			var zone_end := _next_chunk_y + ZONE_HEIGHT + CHUNK_HEIGHT * REST_ZONE_BUFFER
			if zone_end > _next_rest_zone_y:
				_next_zone_y = _next_rest_zone_y + CHUNK_HEIGHT  # retry after the rest zone
			elif _rng.randf() < ZONE_CHANCE:
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
	# 3 levels per era: Prison = 1-3, Factory = 4-6, Lab = 7-9, ...
	var level_idx := (current_level - 1) / 3
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

## Pick the platform tile for a given platform type. In the factory era each type
## gets a distinct tile; elsewhere they all use the era's default platform tile.
func _platform_tile_for(ptype: String) -> Texture2D:
	var era := _get_era()
	if era == "factory":
		match ptype:
			"breakable":
				return _FAC_TILE_BREAKABLE
			"moving":
				return _FAC_TILE_MOVING
			"solid":
				return _FAC_TILE_SOLID
			"thin":
				return _FAC_TILE_THIN
			_:
				return _FAC_TILE_STANDARD
	if era == "prison" and ptype == "breakable":
		return _PRISON_BREAKABLE
	return _get_era_platform_tile()

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

	if _is_prison():
		_decorate_prison_chunk(chunk, _decorable_plats)

	if _is_near_rest_zone(y):
		return

	if current_level >= 99:
		_maybe_place_spikes(chunk, phase)

	# Factory walls are lined with spike traps so the player can't just hug a
	# wall to plummet safely.
	if _is_factory():
		_maybe_place_wall_trap(chunk, phase, platforms)

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
	_decorable_plats.clear()
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

		# Only solid, non-collapsing platforms are safe to put props on.
		if ptype == "static" or ptype == "solid":
			_decorable_plats.append(plat_rect)

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

## Mechanical platforms (grey solid, blue moving, hot) are factory machinery — the
## prison only uses plain + the red breakable platform, so it has one clear
## "special" platform instead of several inert coloured ones.
const _FACTORY_ONLY_PLATFORMS := ["solid", "moving", "heated"]


func _pick_platform_type() -> String:
	var pool: Array[String] = []
	var factory := _is_factory()
	for type: String in PLATFORM_TYPE_WEIGHTS:
		var info: Dictionary = PLATFORM_TYPE_WEIGHTS[type]
		if current_level < info["min_level"]:
			continue
		if type in _FACTORY_ONLY_PLATFORMS and not factory:
			continue
		for _w in range(int(info["weight"])):
			pool.append(type)
	if pool.is_empty():
		return "static"
	return pool[_rng.randi() % pool.size()]

func _add_static_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	_add_platform_body(parent, cx, cy, w, PLATFORM_H, true, null, "", "static")

func _add_solid_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["solid"]
	_add_platform_body(parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "", "solid")

func _add_thin_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["thin"]
	_add_platform_body(parent, cx, cy, w, cfg["height"], cfg["one_way"], cfg["modulate"], "", "thin")

func _add_moving_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["moving"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "", "moving",
		MOVING_PLATFORM_SCRIPT
	)
	body.move_range = cfg["move_range"]
	body.move_speed = cfg["move_speed"]

func _add_breakable_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["breakable"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "Visual", "breakable",
		BREAKABLE_PLATFORM_SCRIPT
	)
	body.collision_layer = 5
	body.collapse_delay = cfg["collapse_delay"]

func _add_heated_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var cfg: Dictionary = PLATFORM_TYPE_CONFIG["heated"]
	var body := _add_platform_body(
		parent, cx, cy, w, PLATFORM_H, cfg["one_way"], cfg["modulate"], "Visual", "heated",
		HEATED_PLATFORM_SCRIPT
	)
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
	visual_name: String,
	ptype: String = "static",
	script: Script = null
) -> StaticBody2D:
	# Build the collision + visual as children FIRST, attach the optional behaviour
	# script, and only then enter the tree — so the script's _ready() runs with its
	# children in place (the special platforms build detectors / capture _start_x there).
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)

	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = one_way
	body.add_child(col)

	var era_tile: Texture2D = _platform_tile_for(ptype)
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

	if script:
		body.set_script(script)
	parent.add_child(body)
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


func _is_factory() -> bool:
	return _get_era() == "factory"


func _is_prison() -> bool:
	return _get_era() == "prison"


## Add a non-colliding decoration sprite (top-left anchored) behind the actors.
func _add_prop(parent: Node2D, id: int, pos: Vector2, flip: bool = false) -> void:
	var spr := Sprite2D.new()
	spr.texture = load(PROP_DIR + "%d.png" % id)
	spr.centered = false
	spr.position = pos
	spr.flip_h = flip
	spr.z_index = -1  # Set dressing: above the background, behind platforms/actors
	parent.add_child(spr)


## Dress a prison chunk with a single coherent vignette on its widest LONG
## platform, plus an occasional wall fixture. Kept sparse and grouped so it reads
## as deliberate set dressing.
func _decorate_prison_chunk(chunk: Node2D, platforms: Array[Rect2]) -> void:
	var plat_top := -PLATFORM_H / 2.0
	if not platforms.is_empty():
		var widest := platforms[0]
		for plat in platforms:
			if plat.size.x > widest.size.x:
				widest = plat
		# Only clearly long platforms get a vignette.
		if widest.size.x >= 78.0 and _rng.randf() < 0.55:
			var cx := widest.position.x + widest.size.x / 2.0
			_place_ground_vignette(chunk, cx, plat_top, widest.size.x)

	if _rng.randf() < 0.22:
		_place_wall_fixture(chunk)


## A grouped, coherent set of props sitting on a platform centered at cx.
func _place_ground_vignette(chunk: Node2D, cx: float, top: float, avail: float) -> void:
	var kinds := ["crates", "plate"]
	if avail >= 56.0:
		kinds.append("desk")
	match kinds[_rng.randi() % kinds.size()]:
		"desk":  # chair on the left, then table (with a cup) on the right
			_add_prop(chunk, 20, Vector2(cx - 26.0, top - 22.0))
			_add_prop(chunk, 24, Vector2(cx - 4.0, top - 16.0))
			_add_prop(chunk, 9, Vector2(cx + 8.0, top - 21.0))
		"crates":  # stacked crates
			_add_prop(chunk, 31, Vector2(cx - 18.0, top - 16.0))
			_add_prop(chunk, 32, Vector2(cx - 16.0, top - 28.0))
			_add_prop(chunk, 32, Vector2(cx + 4.0, top - 12.0))
		"plate":  # pressure plate flat on the floor
			_add_prop(chunk, 18, Vector2(cx - 8.0, top - 3.0))


## A single small wall panel (switch). Screens/cameras are reserved for rooms.
func _place_wall_fixture(chunk: Node2D) -> void:
	var on_left := _rng.randf() < 0.5
	var wy := _rng.randf_range(-CHUNK_HEIGHT * 0.2, CHUNK_HEIGHT * 0.2)
	var x := 2.0 if on_left else WELL_RIGHT - 9.0
	_add_prop(chunk, 22, Vector2(x, wy - 3.5), not on_left)


## Furnish a prison stance room from the hand-authored ROOM_DECOR for its type.
func _furnish_prison_room(room: Node2D, stance_idx: int) -> void:
	if not _is_prison():
		return
	var decor: Array = ROOM_DECOR.get(stance_idx, [])
	for d: Dictionary in decor:
		var spr := Sprite2D.new()
		spr.texture = load(PROP_DIR + "%d.png" % d["id"])
		spr.centered = false
		var sc := float(d.get("scale", 1.0))
		spr.scale = Vector2(sc, sc)
		spr.position = Vector2(d["x"] - float(d["w"]) * sc / 2.0, float(d["y"]))
		spr.z_index = int(d.get("z", -1))
		room.add_child(spr)


## Maybe mount a spiked trap on one of the well walls (factory only).
func _maybe_place_wall_trap(chunk: Node2D, phase: String, platforms: Array[Rect2]) -> void:
	var chance := 0.22
	if phase == "escalation":
		chance = 0.32
	elif phase == "climax":
		chance = 0.42
	if _rng.randf() >= chance:
		return
	var h := _rng.randf_range(44.0, 66.0)
	var cy := _rng.randf_range(-CHUNK_HEIGHT * 0.3, CHUNK_HEIGHT * 0.3)
	# Mount it on whichever wall is clear of a flush platform; skip if both blocked
	# (so saws don't end up sitting on a ledge where enemies also stand).
	var sides := [true, false]
	sides.shuffle()
	for on_left: bool in sides:
		if not _wall_trap_blocked(on_left, cy, h, platforms):
			_add_wall_trap(chunk, on_left, cy, h)
			return


## True if a platform flush to that wall overlaps the trap's vertical band.
func _wall_trap_blocked(on_left: bool, cy: float, h: float, platforms: Array[Rect2]) -> bool:
	var top := cy - h * 0.5 - 10.0
	var bot := cy + h * 0.5 + 10.0
	for p in platforms:
		var flush := p.position.x <= 16.0 if on_left else p.position.x + p.size.x >= WELL_RIGHT - 16.0
		if flush and p.position.y <= bot and p.position.y + p.size.y >= top:
			return true
	return false


## Spinning-sawblade frames (6 x 32px), built once and shared by every wall hazard.
func _saw_frames() -> SpriteFrames:
	if _saw_frames_cache == null:
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		sf.add_animation("spin")
		sf.set_animation_loop("spin", true)
		sf.set_animation_speed("spin", 18.0)
		for i in range(6):
			var at := AtlasTexture.new()
			at.atlas = SAW_TEX
			at.region = Rect2(i * 32, 0, 32, 32)
			sf.add_frame("spin", at)
		_saw_frames_cache = sf
	return _saw_frames_cache


## Build a wall hazard: a column of spinning sawblades mounted on a well wall.
func _add_wall_trap(parent: Node2D, on_left: bool, cy: float, height: float) -> void:
	var trap := Area2D.new()
	trap.set_script(WALL_TRAP_SCRIPT)
	var base_x := 4.0 if on_left else WELL_RIGHT - 4.0
	var dir := 1.0 if on_left else -1.0
	trap.position = Vector2(base_x, cy)
	parent.add_child(trap)

	var reach := 16.0  # how far the blades bite into the well
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(reach, height)
	shape.position = Vector2(dir * reach * 0.5, 0.0)
	shape.shape = rect
	trap.add_child(shape)

	# Spinning sawblades distributed along the mounted height.
	var frames := _saw_frames()
	var step := 26.0
	var n := maxi(1, int(round(height / step)))
	for i in range(n):
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		var yy := lerpf(-height * 0.5 + 13.0, height * 0.5 - 13.0, t)
		var saw := AnimatedSprite2D.new()
		saw.sprite_frames = frames
		saw.play("spin")
		saw.position = Vector2(dir * 10.0, yy)
		saw.scale = Vector2(0.9, 0.9)
		saw.flip_h = not on_left
		trap.add_child(saw)


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
		"shaft":
			_zone_shaft(zone, y)
		"ledges":
			_zone_ledges(zone, y)


## Create a solid wall column for width-changing structures. In the prison it uses
## proper wall sprites: a platform-top-with-wall row on top (only when `is_top`)
## and pillar tiles below. `is_top` should be false for stacked segments so a tall
## wall doesn't get a ledge band in its middle.
## open_side: 0 = free-standing (both sides bordered), +1 = only the RIGHT side is
## exposed (column attached to a wall on its left, e.g. a funnel's left block),
## -1 = only the LEFT side is exposed (attached on its right).
func _add_column(
	parent: Node2D,
	x: float,
	top_y: float,
	w: float,
	h: float,
	is_top := true,
	is_bottom := false,
	open_side := 0
) -> void:
	# Snap the width to whole tiles so the 9-slice wall tiles fill the collision
	# exactly (a fractional width makes the corner/edge tiles overflow and misalign).
	# Pin the wall-facing edge (opposite the exposed/open side) so only the inner,
	# gap-facing edge shifts — wall-attached columns stay flush with the well wall.
	var snapped_w := maxf(TILE_SIZE, roundf(w / TILE_SIZE) * TILE_SIZE)
	if open_side > 0:  # exposed on the right -> wall on the left, pin the left edge
		x = (x - w / 2.0) + snapped_w / 2.0
	elif open_side < 0:  # exposed on the left -> wall on the right, pin the right edge
		x = (x + w / 2.0) - snapped_w / 2.0
	w = snapped_w

	var body := StaticBody2D.new()
	body.position = Vector2(x, top_y + h / 2.0)
	parent.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	var prison := _is_prison()
	var fallback: Texture2D = _get_era_platform_tile()
	if not prison and not fallback:
		return
	var cols := maxi(1, ceili(w / TILE_SIZE))
	var rows := maxi(1, ceili(h / TILE_SIZE))
	var x_start := -w / 2.0
	for ry in range(rows):
		for rx in range(cols):
			var spr := Sprite2D.new()
			if prison:
				spr.texture = _prison_wall_tile(rx, ry, cols, rows, is_top, is_bottom, open_side)
			else:
				spr.texture = fallback
				spr.modulate = Color(0.45, 0.35, 0.45, 1.0)
			spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
			spr.position = Vector2(
				x_start + rx * TILE_SIZE + TILE_SIZE / 2.0,
				-h / 2.0 + ry * TILE_SIZE + TILE_SIZE / 2.0
			)
			body.add_child(spr)


## 9-slice tile pick for a prison wall column cell (top edge, bottom floor edge,
## side edges, body fill — and the all-sides block for a lone 1x1 cell).
func _prison_wall_tile(
	cx: int, ry: int, cols: int, rows: int, is_top: bool, is_bottom: bool, open_side := 0
) -> Texture2D:
	var top_row := is_top and ry == 0
	var bot_row := is_bottom and ry == rows - 1
	var left := cx == 0
	var right := cx == cols - 1
	if cols == 1:
		if top_row and bot_row:
			return _PW_BLOCK
		# Wall-attached 1-wide columns use the exposed side's corner/edge; only a
		# truly free-standing one uses the both-sides tiles (4 / 12 / 20).
		if top_row:
			if open_side > 0:
				return _PW_TOP_R  # exposed right -> top-right corner
			if open_side < 0:
				return _PW_TOP_1  # exposed left -> top-left corner (Tile_4)
			return _PW_TOP_1
		if bot_row:
			if open_side > 0:
				return _PW_BOT_R
			if open_side < 0:
				return _PW_BOT_L
			return _PW_BOT_1
		if open_side > 0:
			return _PW_BODY_R
		if open_side < 0:
			return _PW_BODY_L
		return _PW_BODY_1
	if top_row:
		if left:
			return _PW_TOP_L
		if right:
			return _PW_TOP_R
		return _PW_TOP_M
	if bot_row:
		if left:
			return _PW_BOT_L
		if right:
			return _PW_BOT_R
		return _PW_BOT_M
	if left:
		return _PW_BODY_L
	if right:
		return _PW_BODY_R
	return _PW_BODY_M


## Corridor — all platforms in the center 128px, spider-lined walls, visual columns
func _zone_corridor(zone: Node2D, y: float) -> void:
	var gap := 128.0
	var left_edge := (WELL_RIGHT - gap) / 2.0
	var right_edge := left_edge + gap
	var cfg := _zone_get_cfg(y)

	for row in range(ZONE_CHUNKS):
		var row_y := row * CHUNK_HEIGHT
		_add_column(zone, left_edge / 2.0, row_y - CHUNK_HEIGHT / 2.0, left_edge, CHUNK_HEIGHT, row == 0, row == ZONE_CHUNKS - 1)
		_add_column(zone, right_edge + (WELL_RIGHT - right_edge) / 2.0, row_y - CHUNK_HEIGHT / 2.0, WELL_RIGHT - right_edge, CHUNK_HEIGHT, row == 0, row == ZONE_CHUNKS - 1)

		var plat_w := _rng.randf_range(36.0, 56.0)
		var plat_x := _rng.randf_range(left_edge + plat_w / 2.0 + 4.0, right_edge - plat_w / 2.0 - 4.0)
		_add_platform_body(zone, plat_x, row_y - 16.0, plat_w, PLATFORM_H, true, null, "")

		# Seat spiders just inside the tunnel column faces (body radius is 16).
		if _rng.randf() < 0.50:
			_add_spider(zone, left_edge + 18.0, row_y - _rng.randf_range(5.0, 25.0), true)
		if _rng.randf() < 0.50:
			_add_spider(zone, right_edge - 18.0, row_y - _rng.randf_range(5.0, 25.0), false)

		if _rng.randf() < cfg["enemy_chance"] * 0.7:
			_add_enemy(zone, plat_x, row_y - 24.0, "prisoner")


## True if a platform at (cx, cy) of width `w` would overlap any already-placed
## rect (with a gap), used so zone platforms don't stack on top of each other.
func _zone_platform_overlaps(cx: float, cy: float, w: float, placed: Array[Rect2]) -> bool:
	var pad := MIN_PLATFORM_GAP
	var cand := Rect2(
		cx - w / 2.0 - pad, cy - PLATFORM_H / 2.0 - pad, w + pad * 2.0, PLATFORM_H + pad * 2.0
	)
	for r in placed:
		if cand.intersects(r):
			return true
	return false


## Place a zone platform only if it doesn't overlap existing ones. Returns true
## on success and records the rect in `placed`.
func _try_zone_platform(zone: Node2D, cx: float, cy: float, w: float, placed: Array[Rect2]) -> bool:
	if _zone_platform_overlaps(cx, cy, w, placed):
		return false
	_add_platform_body(zone, cx, cy, w, PLATFORM_H, true, null, "")
	placed.append(Rect2(cx - w / 2.0, cy - PLATFORM_H / 2.0, w, PLATFORM_H))
	return true


## Chamber — wider platform spread, extra air enemies. Platforms are placed with
## overlap avoidance so they never stack/step on each other.
func _zone_chamber(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	var placed: Array[Rect2] = []
	for row in range(ZONE_CHUNKS):
		var row_y := row * CHUNK_HEIGHT
		var target := _rng.randi_range(2, 4)
		var made := 0
		var attempts := 0
		while made < target and attempts < 12:
			attempts += 1
			var w := _rng.randf_range(36.0, 56.0)
			var cx := _rng.randf_range(WELL_LEFT + w / 2.0 + 4.0, WELL_RIGHT - w / 2.0 - 4.0)
			var cy := row_y - _rng.randf_range(6.0, 22.0)
			if _try_zone_platform(zone, cx, cy, w, placed):
				made += 1

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


## Bottleneck — two stepped side walls that grow inward as you descend, funnelling
## toward the centre. Built cell-by-cell so every exposed face (including the top
## of each step's protruding part and the inner step corners) gets the correct
## 9-slice tile, instead of stacking rectangular columns that leave step tops uncapped.
const _FUNNEL_WIDTHS: Array[int] = [1, 2, 3]  # tiles per side, per step (top -> bottom)
const _FUNNEL_ROWS_PER_STEP := 3


func _zone_bottleneck(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	var top_y := -CHUNK_HEIGHT / 2.0
	_add_funnel_wall(zone, top_y, true)   # left wall
	_add_funnel_wall(zone, top_y, false)  # right wall

	# No platforms in the throat: the centre stays a clear vertical drop lane all the
	# way down (the funnel narrows to ~64px) so the player can dive straight through
	# and keep a combo.

	if _rng.randf() < cfg["enemy_chance"] * 0.6:
		_add_drone(zone, WELL_RIGHT / 2.0, top_y + 40.0)


## Build one stepped funnel wall (left or right) as a single body with per-step
## collision and per-cell sprites with full 9-slice edge/corner tiling.
func _add_funnel_wall(parent: Node2D, top_y: float, from_left: bool) -> void:
	var prison := _is_prison()
	var fallback: Texture2D = _get_era_platform_tile()
	var cols := int(WELL_RIGHT / TILE_SIZE)
	var total_rows := _FUNNEL_WIDTHS.size() * _FUNNEL_ROWS_PER_STEP

	var body := StaticBody2D.new()
	parent.add_child(body)

	# Collision — one rectangle per step (each step is a wider slab than the one above).
	for s in range(_FUNNEL_WIDTHS.size()):
		var ww := float(_FUNNEL_WIDTHS[s]) * TILE_SIZE
		var hh := float(_FUNNEL_ROWS_PER_STEP) * TILE_SIZE
		var shape := RectangleShape2D.new()
		shape.size = Vector2(ww, hh)
		var cshape := CollisionShape2D.new()
		cshape.shape = shape
		var sx := ww / 2.0 if from_left else WELL_RIGHT - ww / 2.0
		cshape.position = Vector2(sx, top_y + float(s) * hh + hh / 2.0)
		body.add_child(cshape)

	if not prison and not fallback:
		return

	# Sprites — one per occupied cell, with correct edge/corner tile.
	for ty in range(total_rows):
		var step := ty / _FUNNEL_ROWS_PER_STEP
		var w_here: int = _FUNNEL_WIDTHS[step]
		var w_above := 0
		if ty > 0:
			@warning_ignore("integer_division")
			w_above = _FUNNEL_WIDTHS[(ty - 1) / _FUNNEL_ROWS_PER_STEP]
		for k in range(w_here):  # k = distance (in tiles) from the well wall this side
			var top_exposed := ty == 0 or k >= w_above
			var bot_exposed := ty == total_rows - 1
			var wall_edge := k == 0          # touches the outer well boundary
			var gap_edge := k == w_here - 1  # faces the central gap
			var left_e := wall_edge if from_left else gap_edge
			var right_e := gap_edge if from_left else wall_edge

			var spr := Sprite2D.new()
			if prison:
				spr.texture = _slice_tile(top_exposed, bot_exposed, left_e, right_e)
			else:
				spr.texture = fallback
				spr.modulate = Color(0.45, 0.35, 0.45, 1.0)
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, TILE_SIZE, TILE_SIZE)
			var col := k if from_left else cols - 1 - k
			spr.position = Vector2(
				float(col) * TILE_SIZE + TILE_SIZE / 2.0,
				top_y + float(ty) * TILE_SIZE + TILE_SIZE / 2.0
			)
			body.add_child(spr)


## Pick a prison wall tile from explicit edge-exposure flags (general 9-slice).
func _slice_tile(top: bool, bot: bool, left: bool, right: bool) -> Texture2D:
	if top and bot:
		return _PW_BLOCK
	if top:
		if left and right:
			return _PW_TOP_1
		if left:
			return _PW_TOP_L
		if right:
			return _PW_TOP_R
		return _PW_TOP_M
	if bot:
		if left and right:
			return _PW_BOT_1
		if left:
			return _PW_BOT_L
		if right:
			return _PW_BOT_R
		return _PW_BOT_M
	if left and right:
		return _PW_BODY_1
	if left:
		return _PW_BODY_L
	if right:
		return _PW_BODY_R
	return _PW_BODY_M


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

	_add_column(zone, 8.0, -CHUNK_HEIGHT / 2.0, 16.0, ZONE_CHUNKS * CHUNK_HEIGHT, true, true)
	_add_column(zone, 248.0, -CHUNK_HEIGHT / 2.0, 16.0, ZONE_CHUNKS * CHUNK_HEIGHT, true, true)


## Crossfire — high-density combat zone, all enemy types
func _zone_crossfire(zone: Node2D, _y: float) -> void:
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


## Shaft — open side perches alternating left/right with a WIDE clear drop lane on
## the opposite side, so you can free-fall and chain kills (keep your combo)
## instead of weaving through something tight.
func _zone_shaft(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	var step_h := CHUNK_HEIGHT * 0.55
	var steps := ceili(ZONE_CHUNKS * CHUNK_HEIGHT / step_h)
	var perch_w := 70.0
	for i in range(steps):
		var on_left := (i % 2) == 0
		var px := perch_w / 2.0 + 6.0 if on_left else WELL_RIGHT - perch_w / 2.0 - 6.0
		var py := i * step_h - 12.0
		_add_platform_body(zone, px, py, perch_w, PLATFORM_H, true, null, "", "static")
		if _rng.randf() < cfg["enemy_chance"] * 0.7:
			_add_enemy(zone, px, py - 16.0, "")
		# Air enemy out in the open drop lane to chain while falling past.
		var open_x := WELL_RIGHT - 60.0 if on_left else 60.0
		if _rng.randf() < 0.5:
			_add_drone(zone, open_x, py - 20.0)
		elif _rng.randf() < 0.45:
			_add_bat(zone, open_x, py - 30.0)


## Ledges — each floor is one wide side ledge leaving a WIDE drop gap on the
## alternating side: a clear fall lane to dive through and chain enemies.
func _zone_ledges(zone: Node2D, y: float) -> void:
	var cfg := _zone_get_cfg(y)
	var step_h := CHUNK_HEIGHT * 0.85
	var floors := ceili(ZONE_CHUNKS * CHUNK_HEIGHT / step_h)
	var gap_w := 120.0
	var ledge_w := WELL_RIGHT - gap_w
	for i in range(floors):
		var fy := i * step_h - 12.0
		var open_left := (i % 2) == 0
		var lx := gap_w + ledge_w / 2.0 if open_left else ledge_w / 2.0
		_add_platform_body(zone, lx, fy, ledge_w, PLATFORM_H, true, null, "", "static")
		if _rng.randf() < cfg["enemy_chance"] * 0.7:
			_add_enemy(zone, lx, fy - 16.0, "")
		# Enemy in the open drop lane.
		var lane_x := gap_w / 2.0 if open_left else WELL_RIGHT - gap_w / 2.0
		if _rng.randf() < 0.45:
			_add_drone(zone, lane_x, fy - 24.0)
		elif _rng.randf() < 0.35:
			_add_frog(zone, lx, fy - 24.0)


## Helper: get phase config for zone Y position
func _zone_get_cfg(y: float) -> Dictionary:
	var phase_progress := clampf((y - _level_start_y) / LEVEL_LENGTH, 0.0, 1.0)
	var phase := _get_phase(phase_progress)
	return PHASE_CONFIG[phase]


## Fill background across a zone + extra overlap for seamless transitions.
## Pick a background tile for a full row. Excludes the last tile in the set, which
## is a decorative accent (e.g. prison Tile_56) that must never tile a whole row.
func _bg_row_tile(tiles: Array[Texture2D]) -> Texture2D:
	var n := tiles.size()
	if n <= 1:
		return tiles[0]
	return tiles[_rng.randi() % (n - 1)]


func _fill_background_zone(parent: Node2D, rows: int) -> void:
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if tiles.is_empty():
		return
	var total_h := (rows + 2) * CHUNK_HEIGHT
	var y_off := -rows * CHUNK_HEIGHT / 2.0 - CHUNK_HEIGHT
	var total_rows := ceili(total_h / TILE_SIZE)
	for r in range(total_rows):
		var tex := _bg_row_tile(tiles)
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

## Enemy roster per prison level, so enemies ramp up across the 3 prison levels.
const PRISON_ENEMIES_BY_LEVEL := {
	1: ["prisoner", "bat", "drone"],
	2: ["prisoner", "warden", "bat", "drone", "spider", "frog"],
	3: ["prisoner", "warden", "bat", "drone", "spider", "frog", "floor_drone"],
}

## Factory roster: the new industrial enemies (hammer/alarmobot/copter) plus the
## robotic reused ones (drone/floor_drone/bat). No prison humans/animals here.
const FACTORY_ENEMIES_BY_LEVEL := {
	4: ["hammer", "drone", "bat"],
	5: ["hammer", "alarmobot", "copter", "drone", "bat"],
	6: ["hammer", "alarmobot", "copter", "drone", "bat", "floor_drone"],
}


## Allowed enemy types for the current spot. Empty = no restriction.
func _level_enemy_filter() -> Array:
	if _is_prison():
		return PRISON_ENEMIES_BY_LEVEL.get(current_level, PRISON_ENEMIES_BY_LEVEL[3])
	if _is_factory():
		return FACTORY_ENEMIES_BY_LEVEL.get(current_level, FACTORY_ENEMIES_BY_LEVEL[6])
	return []


func _try_spawn_squad(chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2]) -> void:
	var tiers: Array = cfg["squad_tiers"]
	var allowed := _level_enemy_filter()
	var eligible: Array[Dictionary] = []
	for squad: Dictionary in SQUAD_DEFS:
		if not tiers.has(squad["tier"]):
			continue
		# Skip squads containing an enemy type not yet unlocked at this level.
		var ok := true
		if not allowed.is_empty():
			for member: Dictionary in squad["members"]:
				if not allowed.has(member["type"]):
					ok = false
					break
		if ok:
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
				# Keep clear of the platform band so it doesn't spawn inside a ledge.
				if absf(sy) < 16.0:
					sy = -22.0
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
			"hammer":
				var hx := clampf(anchor.x + ox, WELL_LEFT + 14.0, WELL_RIGHT - 14.0)
				_add_hammer(chunk, hx, -16.0)
			"alarmobot":
				var ax := clampf(anchor.x + ox, WELL_LEFT + 12.0, WELL_RIGHT - 12.0)
				_add_alarmobot(chunk, ax, -16.0)
			"copter":
				var cx := clampf(anchor.x + ox, WELL_LEFT + 14.0, WELL_RIGHT - 14.0)
				_add_copter(chunk, cx, anchor.y + oy)

func _try_spawn_single(
	chunk: Node2D, cfg: Dictionary, platforms: Array[Rect2], phase_progress: float
) -> void:
	var base_chance: float = cfg["enemy_chance"]
	var chance := lerpf(base_chance - 0.1, base_chance, phase_progress)
	chance = clampf(chance, 0.0, 1.0)
	if _rng.randf() >= chance:
		return

	var types: Array = cfg["enemy_types"]
	var allowed := _level_enemy_filter()
	if not allowed.is_empty():
		types = types.filter(func(t: String) -> bool: return allowed.has(t))
	if types.is_empty():
		return
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
			# Spawn clear of the platform band (cy=0) so it doesn't start inside a
			# wall-flush ledge.
			var sx := 20.0 if on_left else WELL_RIGHT - 20.0
			var sy := _rng.randf_range(-42.0, -18.0)
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

		"hammer":
			if platforms.is_empty():
				return
			var hplat: Rect2 = platforms[_rng.randi() % platforms.size()]
			var hx := _rng.randf_range(hplat.position.x + 14, hplat.position.x + hplat.size.x - 14)
			_add_hammer(chunk, hx, -16.0)
		"alarmobot":
			if platforms.is_empty():
				return
			var aplat: Rect2 = platforms[_rng.randi() % platforms.size()]
			var ax := _rng.randf_range(aplat.position.x + 12, aplat.position.x + aplat.size.x - 12)
			_add_alarmobot(chunk, ax, -16.0)
		"copter":
			var ccx := _rng.randf_range(WELL_LEFT + 16, WELL_RIGHT - 16)
			var ccy := _rng.randf_range(-48.0, -22.0)
			_add_copter(chunk, ccx, ccy)

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
	_pre_config_enemy(enemy)
	parent.add_child(enemy)
	_post_config_enemy(enemy)

func _add_drone(parent: Node2D, x: float, y: float) -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	drone.position = Vector2(x, y)
	_pre_config_enemy(drone)
	parent.add_child(drone)
	_post_config_enemy(drone)

func _add_spider(parent: Node2D, x: float, y: float, on_left: bool) -> void:
	if spider_scene == null:
		return
	var spider := spider_scene.instantiate()
	spider.position = Vector2(x, y)
	# Tight vertical patrol so spiders stay on their wall/column and don't crawl
	# off the end into open air or onto platforms.
	spider.patrol_range = 30.0
	_pre_config_enemy(spider)
	parent.add_child(spider)
	spider.set_wall_side(on_left)
	_post_config_enemy(spider)

func _add_floor_drone(parent: Node2D, x: float, y: float) -> void:
	if floor_drone_scene == null:
		return
	var fdrone := floor_drone_scene.instantiate()
	fdrone.position = Vector2(x, y)
	_pre_config_enemy(fdrone)
	parent.add_child(fdrone)
	_post_config_enemy(fdrone)

func _add_bat(parent: Node2D, x: float, y: float) -> void:
	if bat_scene == null:
		return
	var bat := bat_scene.instantiate()
	bat.position = Vector2(x, y)
	_pre_config_enemy(bat)
	parent.add_child(bat)
	_post_config_enemy(bat)

func _add_frog(parent: Node2D, x: float, y: float) -> void:
	if frog_scene == null:
		return
	var frog := frog_scene.instantiate()
	frog.position = Vector2(x, y)
	_pre_config_enemy(frog)
	parent.add_child(frog)
	_post_config_enemy(frog)


func _add_hammer(parent: Node2D, x: float, y: float) -> void:
	if hammer_scene == null:
		return
	var e := hammer_scene.instantiate()
	e.position = Vector2(x, y)
	parent.add_child(e)


func _add_alarmobot(parent: Node2D, x: float, y: float) -> void:
	if alarmobot_scene == null:
		return
	var e := alarmobot_scene.instantiate()
	e.position = Vector2(x, y)
	parent.add_child(e)


func _add_copter(parent: Node2D, x: float, y: float) -> void:
	if copter_scene == null:
		return
	var e := copter_scene.instantiate()
	e.position = Vector2(x, y)
	parent.add_child(e)


## Per-era enemy setup hooks (kept for the existing call sites). The factory no
## longer recolors or buffs reused enemies — it fields dedicated, stronger
## industrial enemies (hammer / alarmobot / copter) instead of a tint "filter".
func _pre_config_enemy(_enemy: Node) -> void:
	pass


func _post_config_enemy(_enemy: Node) -> void:
	pass


func _spawn_rest_zone(y: float) -> void:
	if _stances_in_level >= STANCE_SCENES.size():
		_stances_in_level = 0
		_level_start_y = y + CHUNK_HEIGHT
		_level_end_y = y
		# Each era ends in a boss arena: prison L3 = Warden, factory L6 = Loader.
		if _is_prison() and current_level == 3:
			_spawn_boss_arena(y, BOSS_SCENE)
		elif _is_factory() and current_level == 6:
			_spawn_boss_arena(y, FACTORY_BOSS_SCENE)
		else:
			level_end_cam_target = y
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
	_furnish_prison_room(room, stance_idx)

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


## Boss arena: a sealed chamber with a solid floor (no fall-through), a few
## ledges to fight from, and the prison boss on the floor. Defeating the boss
## completes the level (handled in boss_warden.gd). The camera follows the player
## down normally (no level_end_cam_target), and the boss pauses the urge hazard.
func _spawn_boss_arena(y: float, boss_scene: PackedScene) -> void:
	# Stop spawning chunks below — the player must beat the boss to proceed.
	_gen_paused = true

	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)

	var arena_h := 300.0

	# Background across the whole arena (and a bit below the floor so the view is
	# never blank when standing next to the boss).
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if not tiles.is_empty():
		var rows := ceili((arena_h + 280.0) / TILE_SIZE)
		for r in range(rows):
			var spr := Sprite2D.new()
			spr.texture = _bg_row_tile(tiles)
			spr.centered = false
			spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
			spr.position = Vector2(0, -CHUNK_HEIGHT * 0.5 + r * TILE_SIZE)
			spr.z_index = -1
			zone.add_child(spr)

	# Solid floor at the bottom — the player can't pass until the boss is dead.
	_add_platform_body(zone, WELL_RIGHT / 2.0, arena_h, WELL_RIGHT, 16.0, false, null, "", "solid")

	# Side elevators: stand on them to rise and shoot/stomp the boss from above.
	# Start low (near the floor) so they're easy to step onto.
	_add_elevator(zone, 48.0, arena_h - 48.0, 64.0)
	_add_elevator(zone, WELL_RIGHT - 48.0, arena_h - 48.0, 64.0)

	# The boss — its origin is at its feet (see boss_warden.tscn), so place it on
	# the floor top.
	var boss := boss_scene.instantiate()
	boss.position = Vector2(WELL_RIGHT / 2.0, arena_h - 8.0)
	zone.add_child(boss)


## Build a rising elevator platform (one-way, carries the player up while ridden).
func _add_elevator(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.set_script(ELEVATOR_SCRIPT)
	body.position = Vector2(cx, cy)
	# Layer 8 = "soft platform": the player collides/rides it (its mask includes 8)
	# but bullets (mask = world|enemies) pass through, so you can shoot the boss
	# below while standing on it.
	body.collision_layer = 8
	body.plat_width = w
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, PLATFORM_H)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	body.add_child(col)
	var tile := _get_era_platform_tile()
	if tile:
		var visual := Sprite2D.new()
		visual.texture = tile
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual.region_enabled = true
		visual.region_rect = Rect2(0, 0, w, PLATFORM_H)
		visual.modulate = Color(0.5, 0.8, 1.0, 1.0)  # tinted so elevators read as special
		body.add_child(visual)
	parent.add_child(body)


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
	for row in range(rows):
		var spr := Sprite2D.new()
		spr.texture = _bg_row_tile(tiles)
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
		spr.position = Vector2(0, row * TILE_SIZE)
		spr.z_index = -1
		zone.add_child(spr)


## Fill the level-entry background from top_y to bottom_y. The zone is anchored at
## its BOTTOM so the despawn check (which uses the node's Y) keeps it alive until
## the whole strip is well above the camera — by then procedural chunks already
## cover the area, so it never blinks to black as the player descends.
func fill_entry_background(top_y: float, bottom_y: float) -> void:
	var zone := Node2D.new()
	zone.global_position = Vector2(0, bottom_y)
	add_child(zone)
	_chunks.append(zone)
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if tiles.is_empty():
		return
	var rows := ceili((bottom_y - top_y) / TILE_SIZE) + 1
	for row in range(rows):
		var ty := top_y + row * TILE_SIZE  # global Y of this row
		var spr := Sprite2D.new()
		spr.texture = _bg_row_tile(tiles)
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
		spr.position = Vector2(0, ty - bottom_y)  # relative to the bottom anchor
		spr.z_index = -1
		zone.add_child(spr)

func _fill_background(chunk: Node2D) -> void:
	var tiles: Array[Texture2D] = _get_era_bg_tiles()
	if tiles.is_empty():
		return
	var rows := ceili(CHUNK_HEIGHT / TILE_SIZE)
	for row in range(rows):
		var spr := Sprite2D.new()
		spr.texture = _bg_row_tile(tiles)
		spr.centered = false
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, WELL_RIGHT, TILE_SIZE)
		spr.position = Vector2(0, row * TILE_SIZE - CHUNK_HEIGHT * 0.5)
		spr.z_index = -1
		chunk.add_child(spr)
