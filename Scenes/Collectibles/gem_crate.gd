extends StaticBody2D
## Breakable crate that spawns money collectibles when destroyed.
## Player shoots or stomps it to break it open.

signal opened(was_mimic: bool)  # Emitted when broken (used by the mimic arena room)

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")

@export var money_count := 12
@export var money_value := 1
@export var hp := 3
@export var is_mimic := false  # Trap chest: bites the opener instead of dropping loot

var _is_broken := false
var _world: Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	collision_layer = 4
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
		call_deferred("_break")


func _break() -> void:
	_is_broken = true
	opened.emit(is_mimic)
	# Mimic: no loot — bite whoever is standing close (stomping is risky; shooting
	# it from range is safe but wastes the gamble).
	if is_mimic:
		SFX.play_mimic_reveal()
		Achievements.notify_mimic_opened()
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("take_damage") and p.global_position.distance_to(global_position) < 42.0:
			p.take_damage(1)
		call_deferred("queue_free")
		return
	SFX.play_chest_open()
	Achievements.notify_chest_opened()
	# Spawn money in a burst
	for i in range(money_count):
		var money := MONEY_SCENE.instantiate()
		money.value = money_value
		money.global_position = global_position + Vector2(0, -8)
		_world.add_child(money)
	# Play open animation if available, otherwise just remove
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("Open"):
		sprite.play("Open")
		await sprite.animation_finished
	call_deferred("queue_free")
