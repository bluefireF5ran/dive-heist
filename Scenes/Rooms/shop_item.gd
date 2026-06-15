extends Area2D
## Buyable shop item. Player walks over it and presses interact to purchase.
## If player can't afford it, nothing happens. Items are configurable from a
## catalog so the shop can offer a varied, clearly-priced selection each visit.

signal purchased(item_id: String)

const TEXT_POPUP := preload("res://Scenes/VFX/text_popup.tscn")
const PURCHASE_PARTICLES := preload("res://Scenes/VFX/purchase_particles.tscn")
const PIXEL_FONT := preload(
	"res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf"
)

const ICON_DIR := "res://Sprites/Active_Sprites/icons/"

## All items the shop can sell: name, price, icon, colour and effect (see _apply_item).
const CATALOG := {
	"heal":
	{"name": "REPAIR", "price": 4, "icon": "shop_repair.png", "color": Color(0.9, 0.35, 0.35)},
	"armor":
	{"name": "ARMOR", "price": 8, "icon": "shop_armor.png", "color": Color(0.4, 0.7, 1.0)},
	"ammo_up":
	{"name": "AMMO+", "price": 6, "icon": "shop_ammo.png", "color": Color(0.9, 0.8, 0.2)},
	"max_hp":
	{"name": "HP+1", "price": 12, "icon": "shop_hp.png", "color": Color(0.85, 0.2, 0.2)},
	"fire_rate":
	{"name": "FIRE+", "price": 10, "icon": "shop_fire.png", "color": Color(0.6, 0.9, 0.3)},
	"damage":
	{"name": "DMG+1", "price": 11, "icon": "shop_damage.png", "color": Color(0.8, 0.7, 1.0)},
	"magnet":
	{"name": "MAGNET", "price": 7, "icon": "shop_magnet.png", "color": Color(0.95, 0.6, 0.15)},
	"swift":
	{"name": "BOOTS", "price": 8, "icon": "perk_swift.png", "color": Color(0.4, 0.9, 0.9)},
	"high_jump":
	{"name": "SPRINGS", "price": 8, "icon": "perk_high_jump.png", "color": Color(0.6, 1.0, 0.5)},
	"vampire":
	{"name": "VAMPIRE", "price": 13, "icon": "perk_vampire.png", "color": Color(0.7, 0.15, 0.25)},
}

@export var item_id := "heal"
@export var price := 0  # 0 = use the catalog price

var _sold := false
var _world: Node2D
var _player_in_range := false
var _player_ref: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var price_label: Label = $PriceLabel
@onready var name_label: Label = get_node_or_null("NameLabel")


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if price_label:
		price_label.add_theme_font_override("font", PIXEL_FONT)
	if name_label:
		name_label.add_theme_font_override("font", PIXEL_FONT)
		name_label.add_theme_font_size_override("font_size", 6)
	configure(item_id, price)


## Set the item from the catalog (used by shop_stance to randomize the offering).
func configure(id: String, override_price: int = 0) -> void:
	item_id = id
	var def: Dictionary = CATALOG.get(id, {})
	price = override_price if override_price > 0 else int(def.get("price", 5))
	_update_price_label()
	_update_name_label(def)
	_update_icon(def)


func _update_price_label() -> void:
	if price_label:
		price_label.text = "$" + str(price)


func _update_name_label(def: Dictionary) -> void:
	if name_label:
		name_label.text = def.get("name", item_id.to_upper())
		name_label.modulate = def.get("color", Color.WHITE)


func _update_icon(def: Dictionary) -> void:
	if sprite and def.has("icon"):
		sprite.texture = load(ICON_DIR + def["icon"])


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
		# Note: shop upgrades are NOT shown in the HUD perk row (only end-of-level
		# perk picks are); _apply_item still records them in player.perks for gameplay.
		purchased.emit(item_id)
		SFX.play(SFX.combo_tier_1, -6.0)
		_spawn_purchase_vfx()
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		SFX.play(SFX.empty_click, -7.0)


func _apply_item(player: Node2D) -> void:
	match item_id:
		"heal":
			if player.has_method("heal"):
				player.heal(1)
		"ammo_up":
			if player.has_method("increase_max_ammo"):
				player.increase_max_ammo(1)
		"armor":
			if player.has_method("add_shield"):
				player.add_shield(1)  # blue armour pip (absorbs one hit, not regenerated)
		"swift":
			if player.has_method("apply_perk"):
				player.apply_perk("swift")
		"high_jump":
			if player.has_method("apply_perk"):
				player.apply_perk("high_jump")
		"vampire":
			if player.has_method("apply_perk"):
				player.apply_perk("vampire")
		"max_hp":
			if player.has_method("apply_perk"):
				player.apply_perk("max_hp")
		"fire_rate":
			if player.has_method("apply_perk"):
				player.apply_perk("fire_rate")
		"damage":
			if player.has_method("apply_perk"):
				player.apply_perk("sharpshooter")
		"magnet":
			if player.has_method("apply_perk"):
				player.apply_perk("magnet")


func _spawn_purchase_vfx() -> void:
	var particles := PURCHASE_PARTICLES.instantiate()
	particles.global_position = global_position
	_world.call_deferred("add_child", particles)
	var popup := TEXT_POPUP.instantiate()
	popup.popup_text = "SOLD!"
	popup.global_position = global_position - Vector2(0, 12)
	_world.call_deferred("add_child", popup)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_player_ref = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_player_ref = null
