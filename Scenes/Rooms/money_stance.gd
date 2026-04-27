extends "res://Scenes/Rooms/base_room.gd"

@onready var gem_crate: StaticBody2D = $GemCrate
@onready var spike_floor: Area2D = $SpikeFloor


func _ready() -> void:
	super()
	spike_floor.body_entered.connect(_on_spike_entered)


func _on_spike_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
