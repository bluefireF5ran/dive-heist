extends Area2D
## Weapon selection card shown in weapon stance rooms.
## Displays weapon info and equips on interact when player is nearby.

signal weapon_selected(weapon_name: String)

@export var weapon_name := ""

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
		_select()


const PIXEL_FONT := preload(
	"res://Sprites/Scraper/Cyberpunk_Assets/Game_UI/UI_Main/10 Font/CyberpunkCraftpixPixel.otf"
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
		name_label.text = weapon_name.to_upper()
		name_label.add_theme_font_override("font", PIXEL_FONT)
		name_label.add_theme_font_size_override("font_size", 6)
		if weapon_data.has("hud_color"):
			name_label.modulate = weapon_data["hud_color"]

	# Hide prompt until player is nearby
	if prompt_label:
		prompt_label.add_theme_font_override("font", PIXEL_FONT)
		prompt_label.add_theme_font_size_override("font_size", 5)
		prompt_label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if prompt_label:
			prompt_label.visible = false


func _select() -> void:
	_selected = true
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player and player.has_method("equip_weapon"):
		player.equip_weapon(weapon_name)
	SFX.play(SFX.combo_tier_2, -6.0)
	weapon_selected.emit(weapon_name)
	# Flash and disappear
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
