extends Node2D
## Floating text popup that drifts upward and fades out, then auto-frees.
## Set `popup_text` and optionally `popup_color` before adding to the tree.

@export var popup_text := "SOLD!"
@export var popup_color := Color(0.9, 0.8, 0.2, 1.0)  # Gold
@export var float_speed := 30.0
@export var duration := 0.8

var _font: Font
var _elapsed := 0.0


func _ready() -> void:
	_font = load("res://Sprites/Scraper/Cyberpunk_Assets/Game_UI/UI_Main/10 Font/CyberpunkCraftpixPixel.otf")


func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= float_speed * delta
	if _elapsed >= duration:
		queue_free()


func _draw() -> void:
	var alpha := clampf(1.0 - _elapsed / duration, 0.0, 1.0)
	var color := Color(popup_color.r, popup_color.g, popup_color.b, alpha)
	var shadow := Color(0, 0, 0, alpha * 0.7)
	var font_size := 10
	var text_size := _font.get_string_size(popup_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var x := -text_size.x / 2.0
	# Shadow
	draw_string(_font, Vector2(x + 1, 1), popup_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
	# Text
	draw_string(_font, Vector2(x, 0), popup_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
