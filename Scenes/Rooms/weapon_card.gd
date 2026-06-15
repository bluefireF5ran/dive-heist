extends Area2D
## Weapon selection card shown in weapon stance rooms.
## Displays weapon info and equips on interact when player is nearby.

signal weapon_selected(weapon_name: String)

@export var weapon_name := ""
@export var price := 0  # 0 = free swap; >0 costs money to equip

var _player_nearby := false
var _selected := false

@onready var gun_sprite: Sprite2D = $GunSprite
@onready var name_label: Label = $NameLabel
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_display()
	# Bob animation
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 3, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y + 3, 0.5).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	if _player_nearby and not _selected and Input.is_action_just_pressed("interact"):
		# If the player is also standing in a door, that interact is for leaving the
		# room — don't snatch a weapon on the way out.
		for d in get_tree().get_nodes_in_group("room_door"):
			if d.get("_player_in_range"):
				return
		_select()


const PIXEL_FONT := preload(
	"res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf"
)


func _setup_display() -> void:
	# Load weapon data from player constant
	var player_script := load("res://Scenes/Player/player.gd")
	var weapon_data: Dictionary = player_script.WEAPON_DATA.get(weapon_name, {})
	if weapon_data.is_empty():
		return

	# Gun sprite
	if gun_sprite and weapon_data.has("gun_texture"):
		gun_sprite.texture = load(weapon_data["gun_texture"])

	# Name label — small pixel font so text fits between cards
	if name_label:
		name_label.text = weapon_name.to_upper().replace("_", " ")
		name_label.add_theme_font_override("font", PIXEL_FONT)
		name_label.add_theme_font_size_override("font_size", 6)
		if weapon_data.has("hud_color"):
			name_label.modulate = weapon_data["hud_color"]

	# Price/free tag — always visible so the player can compare before stepping up.
	if prompt_label:
		prompt_label.add_theme_font_override("font", PIXEL_FONT)
		prompt_label.add_theme_font_size_override("font_size", 6)
		prompt_label.visible = true
		_update_price_label()


## Show FREE / $price, coloured by affordability.
func _update_price_label() -> void:
	if not prompt_label:
		return
	if price <= 0:
		prompt_label.text = "FREE"
		prompt_label.modulate = Color(0.4, 0.9, 0.4)
		return
	prompt_label.text = "$" + str(price)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var can_afford: bool = player != null and int(player._money) >= price
	prompt_label.modulate = Color(0.95, 0.8, 0.2) if can_afford else Color(0.9, 0.35, 0.3)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_update_price_label()  # refresh affordability colour


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false


func _select() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	# Paid weapons require money; deny if the player can't afford it.
	if price > 0:
		if player == null or not player.has_method("spend_money") or not player.spend_money(price):
			SFX.play(SFX.empty_click, -6.0)
			return
	_selected = true
	if player and player.has_method("equip_weapon"):
		player.equip_weapon(weapon_name)
	SFX.play(SFX.combo_tier_2, -6.0)
	weapon_selected.emit(weapon_name)
	# Flash and disappear
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
