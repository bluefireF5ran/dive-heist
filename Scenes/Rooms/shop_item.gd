extends Area2D
## Buyable shop item. Player walks over it and presses interact to purchase.
## If player can't afford it, nothing happens.

signal purchased(item_id: String)

@export var item_id := "heal"
@export var price := 5
@export var description := ""

var _sold := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var price_label: Label = $PriceLabel


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_price_label()


var _player_in_range := false
var _player_ref: Node2D = null


func _update_price_label() -> void:
	if price_label:
		price_label.text = "$" + str(price)


func _process(_delta: float) -> void:
	if _sold or not _player_in_range:
		return
	if _player_ref and _player_ref.is_on_floor() and Input.is_action_just_pressed("interact"):
		_try_purchase()


func _try_purchase() -> void:
	if _player_ref == null or _sold:
		return
	if not _player_ref.has_method("spend_money"):
		return
	if _player_ref.spend_money(price):
		_sold = true
		_apply_item(_player_ref)
		purchased.emit(item_id)
		SFX.play(SFX.combo_tier_1, -6.0)
		# Sold visual
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)


func _apply_item(player: Node2D) -> void:
	match item_id:
		"heal":
			if player.has_method("heal"):
				player.heal(1)
		"ammo_up":
			if player.has_method("increase_max_ammo"):
				player.increase_max_ammo(1)
		"armor":
			if player.has_method("heal"):
				player.heal(player.MAX_HP)  # Full heal


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player_ref = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player_ref = null
