extends CanvasLayer
## Brief "ACHIEVEMENT UNLOCKED" banner that slides in from the top, holds, then
## slides out and frees itself. Spawned by the Achievements autoload.

const FONT := preload(
	"res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf"
)

var pending_title := ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var w := 240.0
	var h := 38.0
	var panel := Panel.new()
	panel.size = Vector2(w, h)
	panel.position = Vector2((320.0 - w) / 2.0, -h - 4.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.13, 0.96)
	sb.border_color = Color(0.95, 0.8, 0.2, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var l1 := Label.new()
	l1.text = "ACHIEVEMENT UNLOCKED"
	l1.add_theme_font_override("font", FONT)
	l1.add_theme_font_size_override("font_size", 7)
	l1.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	l1.position = Vector2(8, 4)
	panel.add_child(l1)

	var l2 := Label.new()
	l2.text = pending_title
	l2.add_theme_font_override("font", FONT)
	l2.add_theme_font_size_override("font_size", 10)
	l2.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	l2.position = Vector2(8, 18)
	panel.add_child(l2)

	SFX.play_achievement()

	var tw := create_tween()
	tw.tween_property(panel, "position:y", 8.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(panel, "position:y", -h - 4.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
