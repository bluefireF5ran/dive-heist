extends ParallaxBackground
## Parallax background for the well. Uses 3 layers from futuristic city backgrounds.
## Layers scroll at different speeds as the camera descends, creating depth.
## Dark tinting is applied to match the prison atmosphere.

# City 4 layers — darkest, most industrial looking
# Layer 1 = far background (sky/deep), Layer 5 = mid buildings, Layer 8 = near structures
const FAR_TEXTURE := preload("res://Sprites/Craftpix/3. Backgrounds/craftpix-net-219100-free-futuristic-city-pixel-art-backgrounds/city 4/1.png")
const MID_TEXTURE := preload("res://Sprites/Craftpix/3. Backgrounds/craftpix-net-219100-free-futuristic-city-pixel-art-backgrounds/city 4/5.png")
const NEAR_TEXTURE := preload("res://Sprites/Craftpix/3. Backgrounds/craftpix-net-219100-free-futuristic-city-pixel-art-backgrounds/city 4/8.png")

# Parallax scroll speeds (0 = no movement, 1 = camera speed)
const FAR_SPEED := 0.05
const MID_SPEED := 0.15
const NEAR_SPEED := 0.35

# Dark tinting to match prison atmosphere
const FAR_TINT := Color(0.15, 0.12, 0.2, 0.6)
const MID_TINT := Color(0.2, 0.18, 0.25, 0.5)
const NEAR_TINT := Color(0.25, 0.22, 0.3, 0.4)


func _ready() -> void:
	# Create layers from back to front
	_add_layer(FAR_TEXTURE, FAR_SPEED, FAR_TINT)
	_add_layer(MID_TEXTURE, MID_SPEED, MID_TINT)
	_add_layer(NEAR_TEXTURE, NEAR_SPEED, NEAR_TINT)


func _add_layer(texture: Texture2D, scroll_scale: float, tint: Color) -> void:
	var layer := ParallaxLayer.new()
	var sprite := TextureRect.new()

	sprite.texture = texture
	sprite.stretch_mode = TextureRect.STRETCH_TILE
	# Fit width to viewport, preserve aspect for height
	sprite.size = Vector2(320, texture.get_height())
	sprite.modulate = tint

	# Center the sprite horizontally
	sprite.position = Vector2(0, -texture.get_height())

	layer.add_child(sprite)
	layer.motion_scale = Vector2(0, scroll_scale)
	# Mirror vertically for infinite scrolling
	layer.motion_mirroring = Vector2(0, texture.get_height())

	add_child(layer)
