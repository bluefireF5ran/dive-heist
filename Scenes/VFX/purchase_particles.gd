extends CPUParticles2D
## Gold particle burst for purchase feedback. Auto-frees after emission finishes.


func _ready() -> void:
	# Start emitting immediately
	emitting = true
	# Auto-free once all particles have finished
	finished.connect(queue_free)
