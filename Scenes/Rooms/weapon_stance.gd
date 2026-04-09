extends "res://Scenes/Rooms/base_room.gd"
## Weapon stance room. Offers a choice of 3 weapons via selection cards.

const WEAPON_CARD_SCENE := preload("res://Scenes/Rooms/weapon_card.tscn")

## Weapons available at each level tier (progressive unlock)
const WEAPONS_BY_LEVEL := {
	1: ["pistol", "spread", "machinegun"],
	2: ["pistol", "spread", "machinegun", "laser", "shotgun"],
	3: ["pistol", "spread", "machinegun", "laser", "shotgun", "piercer", "ricochet"],
}

var _current_level := 1


func _ready() -> void:
	super._ready()
	# _offer_weapons() is called via call_deferred from setup_weapon_offer(),
	# which is invoked by chunk_generator AFTER setting the correct level.


## Called by chunk_generator to pass level data for progressive unlocks.
func setup_weapon_offer(level: int) -> void:
	_current_level = level
	call_deferred("_offer_weapons")


func _offer_weapons() -> void:
	# Get available weapons for current level
	var available: Array = WEAPONS_BY_LEVEL.get(_current_level, WEAPONS_BY_LEVEL[3]).duplicate()

	# Exclude currently equipped weapon
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		available.erase(player.current_weapon)

	# Shuffle and pick 3
	available.shuffle()
	var offered := available.slice(0, mini(3, available.size()))

	# Position 3 cards evenly across the room
	var spacing := 90.0
	var start_x := (ROOM_WIDTH - spacing * 2.0) / 2.0
	var card_y := -28.0

	for i in range(offered.size()):
		var card := WEAPON_CARD_SCENE.instantiate()
		card.weapon_name = offered[i]
		card.position = Vector2(start_x + i * spacing, card_y)
		card.weapon_selected.connect(_on_weapon_selected)
		add_child(card)


func _on_weapon_selected(_weapon_name: String) -> void:
	# Fade out remaining cards
	for child in get_children():
		if child.has_signal("weapon_selected") and not child._selected:
			var tween := child.create_tween()
			tween.tween_property(child, "modulate:a", 0.0, 0.3)
			tween.tween_callback(child.queue_free)
