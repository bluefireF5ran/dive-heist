extends Node2D
## Spawns platform chunks below the camera as the player descends.
## Each chunk is a horizontal slice of the well with platforms and enemies.
## Every LEVEL_LENGTH, a rest zone appears with shop/weapon/gem rooms.

const WELL_LEFT := 0.0
const WELL_RIGHT := 256.0
const CHUNK_HEIGHT := 90.0       # Vertical spacing between chunks (tight = more action)
const SPAWN_AHEAD := 600.0       # How far below camera to pre-generate
const DESPAWN_BEHIND := 400.0    # How far above camera to delete old chunks
const MIN_PLATFORM_W := 48.0
const MAX_PLATFORM_W := 96.0
const PLATFORM_H := 16.0
const LEVEL_LENGTH := 600.0      # Distance between rest zones

@export var prisoner_scene: PackedScene
@export var warden_scene: PackedScene
@export var drone_scene: PackedScene
@export var spider_scene: PackedScene
@export var floor_drone_scene: PackedScene
@export var platform_tile: Texture2D
@export var bg_tiles: Array[Texture2D] = []

const ROOM_DOOR_SCENE := preload("res://Scenes/Rooms/room_door.tscn")
const REST_ROOM_SCENE := preload("res://Scenes/Rooms/rest_room.tscn")
const ROOM_PLATFORM_TEX := preload("res://Sprites/Scraper/Cyberpunk_Assets/Tilesets/Prison/1 Tiles/room_platform.png")

const TILE_SIZE := 32.0

var _next_chunk_y: float = 0.0
var _chunks: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var current_depth := 0  # Set by world.gd for difficulty scaling
var _start_y: float = 0.0
var _next_rest_zone_y: float = 0.0  # Y position of next rest zone


func _ready() -> void:
	_rng.randomize()


func setup(start_y: float) -> void:
	_start_y = start_y
	_next_chunk_y = start_y + CHUNK_HEIGHT
	_next_rest_zone_y = start_y + LEVEL_LENGTH


func _physics_process(_delta: float) -> void:
	var cam_y := get_viewport().get_camera_2d().global_position.y if get_viewport().get_camera_2d() else 0.0

	# Spawn new chunks ahead of camera
	while _next_chunk_y < cam_y + SPAWN_AHEAD:
		# Check if we should insert a rest zone
		if _next_chunk_y >= _next_rest_zone_y:
			_spawn_rest_zone(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT
			_next_rest_zone_y += LEVEL_LENGTH
		else:
			_spawn_chunk(_next_chunk_y)
			_next_chunk_y += CHUNK_HEIGHT

	# Despawn old chunks far above camera
	var i := 0
	while i < _chunks.size():
		if _chunks[i].global_position.y < cam_y - DESPAWN_BEHIND:
			_chunks[i].queue_free()
			_chunks.remove_at(i)
		else:
			i += 1


func _spawn_chunk(y: float) -> void:
	var chunk := Node2D.new()
	chunk.global_position = Vector2(0, y)
	add_child(chunk)
	_chunks.append(chunk)

	# Background tiles
	_fill_background(chunk)

	# Difficulty scales with depth
	var difficulty := clampf(current_depth / 3000.0, 0.0, 1.0)  # 0..1 over 3000m

	# Fewer platforms as difficulty rises (1-3 → 1-2)
	var max_plats := 3 if difficulty < 0.5 else 2
	var plat_count := _rng.randi_range(1, max_plats)

	# Platforms get narrower with depth
	var depth_min_w := lerpf(MIN_PLATFORM_W, 36.0, difficulty)
	var depth_max_w := lerpf(MAX_PLATFORM_W, 64.0, difficulty)

	var platforms: Array[Rect2] = []
	for _p in range(plat_count):
		var w := _rng.randf_range(depth_min_w, depth_max_w)
		var x := _rng.randf_range(WELL_LEFT, WELL_RIGHT - w)
		var plat_rect := Rect2(x, 0, w, PLATFORM_H)
		platforms.append(plat_rect)
		_add_platform(chunk, x + w / 2.0, 0.0, w)

	# Enemy spawn chance increases with depth (60% → 90%)
	var enemy_chance := lerpf(0.60, 0.90, difficulty)
	for plat in platforms:
		if _rng.randf() < enemy_chance:
			var enemy_x := _rng.randf_range(plat.position.x + 12, plat.position.x + plat.size.x - 12)
			var enemy_y := -16.0
			_add_enemy(chunk, enemy_x, enemy_y)

	# Drone: chance to spawn a floating drone in open air (20% → 50% with depth)
	var drone_chance := lerpf(0.20, 0.50, difficulty)
	if _rng.randf() < drone_chance:
		var drone_x := _rng.randf_range(WELL_LEFT + 20, WELL_RIGHT - 20)
		var drone_y := _rng.randf_range(-30.0, 30.0)
		_add_drone(chunk, drone_x, drone_y)

	# Spider: chance to spawn on a wall (15% → 35% with depth)
	var spider_chance := lerpf(0.15, 0.35, difficulty)
	if _rng.randf() < spider_chance:
		var on_left := _rng.randf() < 0.5
		var spider_x := 20.0 if on_left else WELL_RIGHT - 20.0
		var spider_y := _rng.randf_range(-40.0, 40.0)
		_add_spider(chunk, spider_x, spider_y, on_left)

	# Floor drone: chance to spawn on wide platforms (10% → 25% with depth)
	var fdrone_chance := lerpf(0.10, 0.25, difficulty)
	for plat in platforms:
		if plat.size.x >= 64.0 and _rng.randf() < fdrone_chance:
			var fdrone_x := plat.position.x + plat.size.x * 0.5
			_add_floor_drone(chunk, fdrone_x, -20.0)
			break  # Max one per chunk


func _add_platform(parent: Node2D, cx: float, cy: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)
	parent.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, PLATFORM_H)

	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	body.add_child(col)

	# Visual — tiled platform tile
	if platform_tile:
		var visual := Sprite2D.new()
		visual.texture = platform_tile
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		visual.region_enabled = true
		visual.region_rect = Rect2(0, 0, w, PLATFORM_H)
		body.add_child(visual)


func _add_enemy(parent: Node2D, x: float, y: float) -> void:
	var difficulty := clampf(current_depth / 3000.0, 0.0, 1.0)
	# More wardens at depth (30% → 55%)
	var warden_chance := lerpf(0.3, 0.55, difficulty)
	var scene: PackedScene
	if _rng.randf() > warden_chance:
		scene = prisoner_scene
	else:
		scene = warden_scene

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
# REST ZONE — Green platform with door on one wall
# =============================================================================
# Instead of generating inline rooms, we place a special green platform
# touching one wall with a door. The door teleports the player to a
# side-room built off-screen, and an exit door brings them back.

const ROOM_OFFSET_X := 600.0  # X offset where rooms are built (off-screen right)

var _room_count := 0


func _spawn_rest_zone(y: float) -> void:
	var zone := Node2D.new()
	zone.global_position = Vector2(0, y)
	add_child(zone)
	_chunks.append(zone)

	# Background (same as normal chunk)
	_fill_background(zone)

	# Choose which wall side the platform goes on
	var on_left := _rng.randf() < 0.5
	var plat_w := 80.0

	# Green platform touching the wall
	var plat_x: float
	if on_left:
		plat_x = plat_w / 2.0
	else:
		plat_x = WELL_RIGHT - plat_w / 2.0

	_add_room_platform(zone, plat_x, 0.0, plat_w)

	# Door on the wall side of the platform
	var door_x: float
	if on_left:
		door_x = 8.0
	else:
		door_x = WELL_RIGHT - 8.0

	# Instantiate rest room scene off-screen
	var room := REST_ROOM_SCENE.instantiate()
	room.position = Vector2(ROOM_OFFSET_X, 0.0)
	zone.add_child(room)

	# Configure exit door target (back to well platform)
	var return_pos := Vector2(plat_x, y - 20.0)
	room.exit_door.target_position = return_pos

	# Randomize weapon pickup type
	room.weapon_pickup.pickup_type = 0 if _rng.randf() < 0.5 else 1

	# Entrance door in the well
	var room_enter_pos := Vector2(ROOM_OFFSET_X + 40.0, y - 16.0)
	var enter_door := ROOM_DOOR_SCENE.instantiate()
	enter_door.position = Vector2(door_x, -24.0)
	enter_door.target_position = room_enter_pos
	enter_door.is_exit = false
	zone.add_child(enter_door)

	_room_count += 1


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
	# Green platform visual
	var visual := Sprite2D.new()
	visual.texture = ROOM_PLATFORM_TEX
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.region_enabled = true
	visual.region_rect = Rect2(0, 0, w, PLATFORM_H)
	body.add_child(visual)





func _fill_background(chunk: Node2D) -> void:
	if bg_tiles.is_empty():
		return
	var rows := ceili(CHUNK_HEIGHT / TILE_SIZE)
	var cols := ceili(WELL_RIGHT / TILE_SIZE)  # 8 columns
	# Pick one base tile per row — exclude last tile (window grate) from base selection
	var base_count := bg_tiles.size() - 1  # Tiles 50-55 for base, Tile_56 only as accent
	for row in range(rows):
		var base_idx := _rng.randi() % base_count
		for col in range(cols):
			var spr := Sprite2D.new()
			# Mostly use the row's base tile, occasionally swap for variety
			if _rng.randf() < 0.02:
				# Rare window grate
				spr.texture = bg_tiles[bg_tiles.size() - 1]
			elif _rng.randf() < 0.15:
				spr.texture = bg_tiles[_rng.randi() % base_count]
			else:
				spr.texture = bg_tiles[base_idx]
			spr.centered = false
			spr.position = Vector2(col * TILE_SIZE, row * TILE_SIZE - CHUNK_HEIGHT * 0.5)
			spr.z_index = -1
			chunk.add_child(spr)
