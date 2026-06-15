extends "res://Scenes/Rooms/base_room.gd"
## Weapon stance room. Offers a choice of 3 weapons via selection cards.

const WEAPON_CARD_SCENE := preload("res://Scenes/Rooms/weapon_card.tscn")

## Weapons offered at each level tier. Early levels = pistols (low firepower);
## bigger rifle-class weapons unlock at later levels.
const WEAPONS_BY_LEVEL := {
	1: ["pistol", "revolver", "smg", "scatter", "flak", "ricochet", "railgun"],
	2:
	[
		"pistol", "revolver", "smg", "scatter", "flak", "ricochet", "railgun",
		"assault_rifle", "shotgun",
	],
	3:
	[
		"pistol", "revolver", "smg", "scatter", "flak", "ricochet", "railgun",
		"assault_rifle", "shotgun", "laser", "cannon",
	],
}

## Price per weapon — basic pistols are a free swap; stronger pistols and the
## big rifle-class weapons cost money.
const WEAPON_PRICES := {
	"pistol": 0,
	"smg": 16,
	"scatter": 0,
	"revolver": 12,
	"flak": 0,
	"ricochet": 16,
	"railgun": 20,
	"assault_rifle": 22,
	"shotgun": 24,
	"laser": 30,
	"cannon": 34,
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

	# Guarantee at least one free weapon so the "free swap" always exists.
	var has_free := false
	for w: String in offered:
		if int(WEAPON_PRICES.get(w, 0)) == 0:
			has_free = true
			break
	if not has_free:
		for w: String in available:
			if int(WEAPON_PRICES.get(w, 0)) == 0:
				offered[offered.size() - 1] = w
				break

	# Position 3 cards across the room with a random layout for variety.
	var spacing := 90.0
	var start_x := (ROOM_WIDTH - spacing * 2.0) / 2.0
	var base_y := -28.0
	var ys := [base_y, base_y, base_y]
	match _rng.randi() % 3:
		1:  # center raised (peak)
			ys = [base_y, base_y - 42.0, base_y]
		2:  # sides raised (valley)
			ys = [base_y - 38.0, base_y, base_y - 38.0]
		_:
			pass  # flat row

	for i in range(offered.size()):
		var cx := start_x + i * spacing
		var cy: float = ys[i]
		# A small step platform under raised cards so they're easy to reach.
		if cy < base_y - 4.0:
			_add_card_platform(cx, cy + 30.0, 44.0)
		var card := WEAPON_CARD_SCENE.instantiate()
		card.weapon_name = offered[i]
		card.price = int(WEAPON_PRICES.get(offered[i], 0))
		card.position = Vector2(cx, cy)
		card.weapon_selected.connect(_on_weapon_selected)
		add_child(card)


const CARD_PLAT_TEX := preload(
	"res://Sprites/Active_Sprites/tiles/prison_ground/Tile_02.png"
)


## A small one-way step platform under a raised weapon card.
func _add_card_platform(cx: float, cy: float, w: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 12.0)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	body.add_child(col)
	var vis := Sprite2D.new()
	vis.texture = CARD_PLAT_TEX
	vis.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	vis.region_enabled = true
	vis.region_rect = Rect2(0, 0, w, 12.0)
	body.add_child(vis)
	add_child(body)


func _on_weapon_selected(_weapon_name: String) -> void:
	# Fade out remaining cards
	for child in get_children():
		if child.has_signal("weapon_selected") and not child._selected:
			var tween := child.create_tween()
			tween.tween_property(child, "modulate:a", 0.0, 0.3)
			tween.tween_callback(child.queue_free)
