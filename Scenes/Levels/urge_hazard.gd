extends Node2D
## Visual for the "urge" rising hazard. Drawn in world space: a menacing band
## that fills everything ABOVE this node's origin (the hazard line). world.gd
## moves this node to the hazard's Y each frame, so the band scrolls naturally
## and only becomes visible when the hazard descends into the camera view.

const SPAN_LEFT := -60.0
const SPAN_RIGHT := 316.0  # well is 0..256; overshoot to cover screen edges
const TALL := 4000.0  # how far up the band is painted

var _t := 0.0


func _ready() -> void:
	z_index = 60  # Above platforms/enemies, below the HUD CanvasLayer
	set_process(true)


func _process(delta: float) -> void:
	# Animate the warning edge so it reads as dangerous.
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := SPAN_RIGHT - SPAN_LEFT
	# Main hazard fill (semi-transparent red), painted upward from the line.
	draw_rect(Rect2(SPAN_LEFT, -TALL, w, TALL), Color(0.55, 0.04, 0.09, 0.45))
	# Darker core near the edge.
	draw_rect(Rect2(SPAN_LEFT, -24.0, w, 24.0), Color(0.7, 0.06, 0.12, 0.55))
	# Bright pulsing leading edge.
	var pulse := 0.7 + 0.3 * sin(_t * 8.0)
	draw_rect(Rect2(SPAN_LEFT, -3.0, w, 5.0), Color(1.0, 0.35, 0.25, pulse))
	# Drips / teeth along the edge for menace.
	var teeth := 16
	var step := w / float(teeth)
	for i in range(teeth):
		var tx := SPAN_LEFT + i * step + step * 0.5
		var drip := 6.0 + 5.0 * sin(_t * 6.0 + i * 1.3)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(tx - step * 0.35, 2.0),
					Vector2(tx + step * 0.35, 2.0),
					Vector2(tx, 2.0 + drip),
				]
			),
			Color(0.85, 0.15, 0.18, 0.7)
		)
