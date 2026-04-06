extends "res://Scenes/Rooms/base_room.gd"
## Money stance room. Contains a breakable crate that drops money.
## Uses the existing gem_crate scene for the money box.

## Reference to the gem crate (set in scene)
@onready var gem_crate: StaticBody2D = $GemCrate
