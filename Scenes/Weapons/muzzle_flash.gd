extends AnimatedSprite2D

func _ready() -> void:
	play("flash")
	animation_finished.connect(queue_free)
