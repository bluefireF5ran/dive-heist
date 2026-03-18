extends StaticBody2D
## Breakable crate that spawns money collectibles when destroyed.
## Player shoots or stomps it to break it open.

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")

@export var money_count := 12
@export var money_value := 1
@export var hp := 3

var _is_broken := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	collision_layer = 4  # Same as enemies so bullets hit it
	collision_mask = 0


func take_damage(_amount: int = 1) -> void:
	if _is_broken:
		return
	hp -= 1
	# Flash white
	modulate = Color(2, 2, 2, 1)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		_break()


func _break() -> void:
	_is_broken = true
	SFX.play(SFX.stomp_material, -5.0, randf_range(0.8, 1.0))
	# Spawn money in a burst
	for i in range(money_count):
		var money := MONEY_SCENE.instantiate()
		money.value = money_value
		money.global_position = global_position + Vector2(0, -8)
		get_tree().current_scene.add_child(money)
	# Play open animation if available, otherwise just remove
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("Open"):
		sprite.play("Open")
		await sprite.animation_finished
	queue_free()
