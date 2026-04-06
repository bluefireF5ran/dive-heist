extends "res://Scenes/Rooms/base_room.gd"
## Change weapon stance room. Contains a weapon pickup.
## For now this is just the stance itself with a weapon pickup.

## Reference to the weapon pickup (set in scene)
@onready var weapon_pickup: Area2D = $WeaponPickup
