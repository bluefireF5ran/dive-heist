extends Area2D
## Weapon pickup in rest zone.
## LIFE: heal 1 HP, ENERGY: +1 max ammo, WEAPON: equip a new weapon.

enum PickupType { LIFE, ENERGY, WEAPON }

@export var pickup_type: PickupType = PickupType.LIFE
@export var weapon_type := ""

var _collected := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	body_entered.connect(_on_body_entered)
	# Bob animation
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 4, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y + 4, 0.6).set_trans(Tween.TRANS_SINE)
	_update_label()


func _update_label() -> void:
	if not label:
		return
	match pickup_type:
		PickupType.LIFE:
			label.text = "+HP"
			label.modulate = Color(0.85, 0.2, 0.2)
		PickupType.ENERGY:
			label.text = "+AMMO"
			label.modulate = Color(0.2, 0.6, 1.0)
		PickupType.WEAPON:
			label.text = weapon_type.to_upper()
			# Color matches the weapon's HUD color
			var colors := {
				"spread": Color(0.9, 0.3, 0.2),
				"laser": Color(0.2, 0.8, 1.0),
				"machinegun": Color(0.6, 0.9, 0.3),
				"shotgun": Color(0.95, 0.5, 0.15),
				"piercer": Color(0.85, 0.2, 0.85),
				"ricochet": Color(0.3, 0.95, 0.7),
			}
			label.modulate = colors.get(weapon_type, Color(1, 1, 1))
	# Show weapon gun sprite for WEAPON pickups
	if pickup_type == PickupType.WEAPON and sprite:
		var gun_path := "res://Sprites/Craftpix/free-guns-pack-2-for-main-characters-pixel-art/2 Guns/"
		var gun_files := {
			"spread": "4_1.png",
			"laser": "7_1.png",
			"machinegun": "6_1.png",
			"shotgun": "8_1.png",
			"piercer": "3_1.png",
			"ricochet": "9_1.png",
		}
		if weapon_type in gun_files:
			sprite.texture = load(gun_path + gun_files[weapon_type])


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true

	match pickup_type:
		PickupType.LIFE:
			if body.has_method("heal"):
				body.heal(1)
		PickupType.ENERGY:
			if body.has_method("increase_max_ammo"):
				body.increase_max_ammo(1)
		PickupType.WEAPON:
			if body.has_method("equip_weapon"):
				body.equip_weapon(weapon_type)

	SFX.play(SFX.combo_tier_2, -6.0)

	# Flash and disappear
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
