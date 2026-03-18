extends Area2D

const SPEED = 400.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Destroy bullet after leaving screen
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += Vector2.DOWN * SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		SFX.play_bullet_hit()
		# Screen shake + hitstop on kill
		var world := get_tree().current_scene
		if body.hp <= 0:
			if world.has_method("screen_shake"):
				world.screen_shake(2.0)
			if world.has_method("hitstop"):
				world.hitstop(0.03)
		# Increment player combo for bullet kills while airborne
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player and not player.is_on_floor() and body.hp <= 0:
			player.add_combo()
	queue_free()
