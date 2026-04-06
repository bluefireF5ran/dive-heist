extends "res://Scenes/Rooms/base_room.gd"
## Shop stance room. Contains an NPC vendor (Arms Dealer) and 3 shop items.
## The NPC plays a trade animation when the player purchases an item.

## Reference to the NPC sprite node (AnimatedSprite2D with Arms Dealer frames)
@onready var npc_sprite: AnimatedSprite2D = $NPC/AnimatedSprite2D
## References to the 3 shop item slots
@onready var shop_items: Array[Node] = [
	$ShopSlot1,
	$ShopSlot2,
	$ShopSlot3,
]


func _ready() -> void:
	super._ready()
	# Connect purchase signals to animate the NPC
	for item in shop_items:
		if item and item.has_signal("purchased"):
			item.purchased.connect(_on_item_purchased)
	# Start with idle animation
	if npc_sprite:
		npc_sprite.play("idle")


func _on_item_purchased(_item_id: String) -> void:
	if npc_sprite:
		npc_sprite.play("trade")
		# Return to idle after a brief delay
		var tween := create_tween()
		tween.tween_interval(0.5)
		tween.tween_callback(npc_sprite.play.bind("idle"))
