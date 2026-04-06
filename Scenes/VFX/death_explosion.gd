extends Node2D
## Death explosion VFX. Plays a themed explosion animation and auto-destroys.
## Set explosion_type before adding to the tree: "explosion", "blue_oval", "nuclear", "lightning".

## Configuration for each explosion type: sprite path pattern, frame count, FPS, visual scale.
const CONFIGS := {
	"explosion": {
		path = "res://Sprites/Craftpix/Free Pixel Art Explosions/PNG/Explosion/Explosion%d.png",
		frames = 10,
		fps = 15,
		scale = 1.0,
	},
	"blue_oval": {
		path = "res://Sprites/Craftpix/Free Pixel Art Explosions/PNG/Explosion_blue_oval/Explosion_blue_oval%d.png",
		frames = 10,
		fps = 15,
		scale = 1.0,
	},
	"nuclear": {
		path = "res://Sprites/Craftpix/Free Pixel Art Explosions/PNG/Nuclear_explosion/Nuclear_explosion%d.png",
		frames = 10,
		fps = 12,
		scale = 1.5,
	},
	"lightning": {
		path = "res://Sprites/Craftpix/Free Pixel Art Explosions/PNG/Lightning/Lightning_spot%d.png",
		frames = 4,
		fps = 12,
		scale = 1.2,
	},
}

@export var explosion_type := "explosion"


func _ready() -> void:
	var config: Dictionary = CONFIGS.get(explosion_type, CONFIGS["explosion"])
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()

	# Remove default empty animation
	frames.remove_animation("default")
	frames.add_animation("explode")
	frames.set_animation_speed("explode", config.fps)
	frames.set_animation_loop("explode", false)

	# Load each frame texture dynamically
	for i in range(1, config.frames + 1):
		var tex_path: String = config.path % i
		var tex := load(tex_path) as Texture2D
		if tex:
			frames.add_frame("explode", tex)

	sprite.sprite_frames = frames
	sprite.play("explode")
	sprite.scale = Vector2(config.scale, config.scale)
	# Center the sprite
	sprite.offset = Vector2(0, 0)
	add_child(sprite)

	# Auto-free when animation finishes
	sprite.animation_finished.connect(queue_free)
