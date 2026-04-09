extends Node2D
## Base script for all stance rooms in the level system.
## Provides shared background tiling and decoration logic.
## Each stance room script extends this script.

const ROOM_WIDTH := 320.0
const ROOM_HEIGHT := 200.0
const TILE_SIZE := 32.0

var _bg_tiles: Array[Texture2D] = [
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_50.png"),
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_51.png"),
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_52.png"),
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_53.png"),
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_54.png"),
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_55.png"),
	preload("res://Sprites/Craftpix/2. Escenarios/prison-tileset-pixel-art-assets/1 Tiles/Tile_56.png"),
]

var _deco_textures: Array[Texture2D] = []

@onready var exit_door: Area2D = $ExitDoor

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_fill_background()
	_add_decorations()


func _fill_background() -> void:
	var cols := ceili(ROOM_WIDTH / TILE_SIZE)
	var rows := ceili(ROOM_HEIGHT / TILE_SIZE)
	var base_count := maxi(_bg_tiles.size() - 1, 1)
	for row in range(rows):
		var base_idx := _rng.randi() % base_count
		for col in range(cols):
			var spr := Sprite2D.new()
			if _rng.randf() < 0.04:
				spr.texture = _bg_tiles[_bg_tiles.size() - 1]
			elif _rng.randf() < 0.15:
				spr.texture = _bg_tiles[_rng.randi() % base_count]
			else:
				spr.texture = _bg_tiles[base_idx]
			spr.centered = false
			spr.position = Vector2(col * TILE_SIZE, -ROOM_HEIGHT + row * TILE_SIZE)
			spr.z_index = -1
			spr.modulate = Color(0.55, 0.5, 0.7, 1.0)
			add_child(spr)


func _add_decorations() -> void:
	if _deco_textures.is_empty():
		return
	var shuffled: Array = _deco_textures.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var floor_y := -8.0
	var spots: Array[Vector2] = [
		Vector2(24.0, floor_y),
		Vector2(ROOM_WIDTH - 50.0, -110.0),
		Vector2(ROOM_WIDTH * 0.5, -ROOM_HEIGHT + 34.0),
	]
	var count := _rng.randi_range(2, mini(3, shuffled.size()))
	for i in range(count):
		var tex: Texture2D = shuffled[i]
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = spots[i]
		if i == 0:
			spr.position.y -= tex.get_height() / 2.0
		add_child(spr)
