extends Node
## Centralized SFX manager — autoload singleton.
## Preloads all sound effects and exposes play_sfx() for any script.

# Shoot
var shoot_base: AudioStream = preload("res://Audio/SFX/shoot_base.wav")

# Player actions
var jump1: AudioStream = preload("res://Audio/SFX/jump1.wav")
var jump2: AudioStream = preload("res://Audio/SFX/jump2.wav")
var landing: AudioStream = preload("res://Audio/SFX/landing.wav")
var damage_taken: AudioStream = preload("res://Audio/SFX/damage_taken_player.wav")
var player_death: AudioStream = preload("res://Audio/SFX/player_death.wav")
var empty_click: AudioStream = preload("res://Audio/SFX/empty_click_no_bullets_left.wav")

# Enemy deaths
var death_bones: AudioStream = preload("res://Audio/SFX/death_bones.wav")
var death_electric: AudioStream = preload("res://Audio/SFX/death_electric.wav")
var death_robotic: AudioStream = preload("res://Audio/SFX/death_robotic.wav")
var death_disappear: AudioStream = preload("res://Audio/SFX/death_disappear.wav")
var death_heavy_drone: AudioStream = preload("res://Audio/SFX/death_heavy_drone.wav")

# Stomp
var stomp_bones: AudioStream = preload("res://Audio/SFX/stomp_bones.wav")
var stomp_material: AudioStream = preload("res://Audio/SFX/stomp_material.wav")

# Bullet impact
var bullet_impact: AudioStream = preload("res://Audio/SFX/bullet_impact.wav")
var bullet_ricochet: AudioStream = preload("res://Audio/SFX/bullet_ricochet.wav")
var bullet_ricochet_2: AudioStream = preload("res://Audio/SFX/bullet_ricochet_2.wav")

# Combo / rewards
var combo_increase: AudioStream = preload("res://Audio/SFX/full_combo_increase.wav")
var combo_tier_1: AudioStream = preload("res://Audio/SFX/heal_pickup_combo_1.wav")
var combo_tier_2: AudioStream = preload("res://Audio/SFX/combo_tier_2.wav")
var combo_tier_3: AudioStream = preload("res://Audio/SFX/super_combo_tier_3.wav")

# Ambient / loops
var drone_buzz: AudioStream = preload("res://Audio/SFX/drone_buzz.wav")
var spider_patrol: AudioStream = preload("res://Audio/SFX/spider_patrol.wav")
var invincibility: AudioStream = preload("res://Audio/SFX/invincibility.wav")

# UI
var game_over: AudioStream = preload("res://Audio/SFX/game_over.wav")
var restart_menu: AudioStream = preload("res://Audio/SFX/restart_menu.wav")

# Collectibles
var coin_pickup: AudioStream = preload("res://Audio/SFX/heal_pickup_2.wav")

# Pool of AudioStreamPlayers for concurrent sounds
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 12


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)


## Play a sound effect. Returns the player used (or null if pool exhausted).
func play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return p
	# All busy — steal the first one
	var p := _players[0]
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	return p


## Play shoot sound with weapon-specific pitch variation.
func play_shoot(pitch_min: float = 0.9, pitch_max: float = 1.1) -> void:
	play(shoot_base, -8.0, randf_range(pitch_min, pitch_max))


## Play a random jump sound.
func play_jump() -> void:
	var sound := jump1 if randf() < 0.5 else jump2
	play(sound, -12.0, randf_range(0.95, 1.05))


## Play stomp sound — bones for organic enemies, material for robotic.
func play_stomp_bones() -> void:
	play(stomp_bones, -5.0, randf_range(0.9, 1.1))


func play_stomp_material() -> void:
	play(stomp_material, -5.0, randf_range(0.9, 1.1))


## Per-enemy death sounds — each enemy type has one consistent sound.
func play_death_prisoner() -> void:
	play(death_bones, -7.0, randf_range(0.9, 1.1))


func play_death_warden() -> void:
	play(death_disappear, -7.0, randf_range(0.9, 1.1))


func play_death_drone() -> void:
	play(death_electric, -7.0, randf_range(0.9, 1.1))


func play_death_spider() -> void:
	play(death_robotic, -7.0, randf_range(0.9, 1.1))


func play_death_floor_drone() -> void:
	play(death_heavy_drone, -4.0, randf_range(0.9, 1.05))


## Bullet hit
func play_bullet_hit() -> void:
	play(bullet_impact, -9.0, randf_range(0.9, 1.1))


## Bullet ricochet (floor drone)
func play_ricochet() -> void:
	play(bullet_ricochet, -7.0, randf_range(0.9, 1.1))


## Combo reward sound by tier
func play_combo_reward(tier: int) -> void:
	match tier:
		1: play(combo_tier_1, -7.0)
		2: play(combo_tier_2, -5.0)
		3: play(combo_tier_3, -3.0)


## Coin pickup — pitched up for a bright "ding"
func play_coin_pickup() -> void:
	play(coin_pickup, -16.0, randf_range(1.2, 1.4))
