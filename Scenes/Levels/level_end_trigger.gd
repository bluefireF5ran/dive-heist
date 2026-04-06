extends Area2D
## Trigger zone at the end of a level. When the player falls through the
## center gap in the end-of-level platform, this fires and notifies world.gd.

var _triggered := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("player"):
		_triggered = true
		# Notify world.gd
		var world := get_tree().current_scene
		if world.has_method("_on_level_complete"):
			world._on_level_complete()
