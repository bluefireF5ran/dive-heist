extends Area2D
## Weapon pickup in rest zone. Walking over it equips the weapon.
## Type: "life" = change weapon + heal 1 HP, "energy" = change weapon + max ammo +1

enum PickupType { LIFE, ENERGY }

@export var pickup_type: PickupType = PickupType.LIFE

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
	if label:
		if pickup_type == PickupType.LIFE:
			label.text = "+HP"
			label.modulate = Color(0.85, 0.2, 0.2)
		else:
			label.text = "+AMMO"
			label.modulate = Color(0.2, 0.6, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true

	if pickup_type == PickupType.LIFE:
		# Heal 1 HP
		if body.has_method("heal"):
			body.heal(1)
	else:
		# Increase max ammo by 1
		if body.has_method("increase_max_ammo"):
			body.increase_max_ammo(1)

	SFX.play(SFX.combo_tier_2, -6.0)

	# Flash and disappear
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
