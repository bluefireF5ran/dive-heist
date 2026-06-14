extends Area2D
## Factory wall hazard. A spiked strip mounted on a well wall that damages the
## player periodically while touching it — discourages hugging a wall to fall
## fast. Built procedurally by chunk_generator; visuals are code-drawn spikes.

const DAMAGE_INTERVAL := 0.75

var _cooldown := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1)
			_cooldown = DAMAGE_INTERVAL
			return
