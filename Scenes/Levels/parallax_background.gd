extends ParallaxBackground
## Parallax background for the well. Uses 3 layers that swap per era (phase).
## Layers scroll at different speeds as the camera descends, creating depth.


# =============================================================================
# Era layer definitions — 3 layers per era: far, mid, near
# =============================================================================

# Prison layers — city 4 (dark, industrial)
const _CITY4_DIR := (
	"res://Sprites/Craftpix/3. Backgrounds/"
	+ "craftpix-net-219100-free-futuristic-city-pixel-art-backgrounds/city 4"
)
const _PRISON_FAR: Texture2D = preload(_CITY4_DIR + "/1.png")
const _PRISON_MID: Texture2D = preload(_CITY4_DIR + "/5.png")
const _PRISON_NEAR: Texture2D = preload(_CITY4_DIR + "/8.png")

# Factory layers — robot factory background 2
const _FAC_DIR := (
	"res://Sprites/Craftpix/3. Backgrounds/"
	+ "craftpix-net-619885-robot-factory-pixel-game-backgrounds-unity/"
	+ "Robot Factory Backgrounds Pixel Art/PNG/Background_2"
)
const _FACTORY_FAR: Texture2D = preload(_FAC_DIR + "/Layer_1.png")
const _FACTORY_MID: Texture2D = preload(_FAC_DIR + "/Layer_4.png")
const _FACTORY_NEAR: Texture2D = preload(_FAC_DIR + "/Layer_7.png")

const ERA_LAYERS := {
	"prison":
	{
		"far": _PRISON_FAR,
		"mid": _PRISON_MID,
		"near": _PRISON_NEAR,
		"far_tint": Color(0.15, 0.12, 0.2, 0.6),
		"mid_tint": Color(0.2, 0.18, 0.25, 0.5),
		"near_tint": Color(0.25, 0.22, 0.3, 0.4),
	},
	"factory":
	{
		"far": _FACTORY_FAR,
		"mid": _FACTORY_MID,
		"near": _FACTORY_NEAR,
		"far_tint": Color(0.2, 0.18, 0.15, 0.6),
		"mid_tint": Color(0.25, 0.22, 0.18, 0.5),
		"near_tint": Color(0.3, 0.25, 0.2, 0.4),
	},
}

# Parallax scroll speeds (0 = no movement, 1 = camera speed)
const FAR_SPEED := 0.05
const MID_SPEED := 0.15
const NEAR_SPEED := 0.35


func _ready() -> void:
	_build_layers("prison")


## Swap parallax layers for a new era. Clears existing layers and rebuilds.
func set_era(era: String) -> void:
	for child in get_children():
		child.queue_free()
	_build_layers(era)

## Smooth era transition with crossfade.
func set_era_smooth(era: String, fade_duration: float) -> void:
	var old_layers: Array[Node] = get_children()
	_build_layers(era)
	for child in old_layers:
		var tween := create_tween()
		tween.tween_property(child, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(child.queue_free)
	for child in get_children():
		if child in old_layers:
			continue
		child.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(child, "modulate:a", 1.0, fade_duration)


func _build_layers(era: String) -> void:
	var cfg: Dictionary = ERA_LAYERS.get(era, ERA_LAYERS["prison"])
	_add_layer(cfg["far"], FAR_SPEED, cfg["far_tint"])
	_add_layer(cfg["mid"], MID_SPEED, cfg["mid_tint"])
	_add_layer(cfg["near"], NEAR_SPEED, cfg["near_tint"])


func _add_layer(texture: Texture2D, scroll_scale: float, tint: Color) -> void:
	var p_layer := ParallaxLayer.new()
	var sprite := TextureRect.new()

	sprite.texture = texture
	sprite.stretch_mode = TextureRect.STRETCH_TILE
	sprite.size = Vector2(320, texture.get_height())
	sprite.modulate = tint
	sprite.position = Vector2(0, -texture.get_height())

	p_layer.add_child(sprite)
	p_layer.motion_scale = Vector2(0, scroll_scale)
	p_layer.motion_mirroring = Vector2(0, texture.get_height())

	add_child(p_layer)
