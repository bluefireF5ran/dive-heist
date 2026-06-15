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

# Session additions — unique sounds for previously silent / borrowed events
var explosion: AudioStream = preload("res://Audio/SFX/explosion.wav")
var shield_up: AudioStream = preload("res://Audio/SFX/shield_up.wav")
var shield_break: AudioStream = preload("res://Audio/SFX/shield_break.wav")
var boss_intro: AudioStream = preload("res://Audio/SFX/boss_intro.wav")
var heated_platform: AudioStream = preload("res://Audio/SFX/heated_platform.wav")
var platform_crumble: AudioStream = preload("res://Audio/SFX/platform_crumble.wav")
var sawblade: AudioStream = preload("res://Audio/SFX/sawblade.wav")
var combo_lost: AudioStream = preload("res://Audio/SFX/combo_lost.wav")
var purchase: AudioStream = preload("res://Audio/SFX/purchase.wav")
var weapon_equip: AudioStream = preload("res://Audio/SFX/weapon_equip.wav")
var chest_open: AudioStream = preload("res://Audio/SFX/chest_open.wav")
var mimic_reveal: AudioStream = preload("res://Audio/SFX/mimic_reveal.wav")
var descend: AudioStream = preload("res://Audio/SFX/descend.wav")
var boss_shell: AudioStream = preload("res://Audio/SFX/boss_shell.wav")
var shockwave: AudioStream = preload("res://Audio/SFX/shockwave.wav")
var heal_chime: AudioStream = preload("res://Audio/SFX/heal.wav")
var victory: AudioStream = preload("res://Audio/SFX/victory.wav")

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
	play(death_robotic, -13.0, randf_range(0.9, 1.1))


func play_death_floor_drone() -> void:
	play(death_heavy_drone, -14.0, randf_range(0.9, 1.05))


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


# --- Session additions ---------------------------------------------------------

func play_explosion() -> void:
	play(explosion, -6.0, randf_range(0.9, 1.1))


func play_shield_up() -> void:
	play(shield_up, -8.0, randf_range(0.98, 1.05))


func play_shield_break() -> void:
	play(shield_break, -6.0, randf_range(0.95, 1.08))


func play_boss_intro() -> void:
	play(boss_intro, -4.0)


func play_heated_platform() -> void:
	play(heated_platform, -10.0, randf_range(0.95, 1.05))


func play_platform_crumble() -> void:
	play(platform_crumble, -8.0, randf_range(0.9, 1.1))


func play_combo_lost() -> void:
	play(combo_lost, -12.0)


func play_purchase() -> void:
	play(purchase, -6.0, randf_range(0.98, 1.04))


func play_weapon_equip() -> void:
	play(weapon_equip, -6.0, randf_range(0.97, 1.05))


func play_chest_open() -> void:
	play(chest_open, -5.0, randf_range(0.95, 1.08))


func play_mimic_reveal() -> void:
	play(mimic_reveal, -3.0, randf_range(0.95, 1.05))


func play_descend() -> void:
	play(descend, -7.0, randf_range(0.95, 1.05))


func play_boss_shell() -> void:
	play(boss_shell, -8.0, randf_range(0.9, 1.1))


func play_shockwave() -> void:
	play(shockwave, -5.0, randf_range(0.9, 1.05))


func play_heal() -> void:
	play(heal_chime, -8.0, randf_range(0.98, 1.05))


func play_victory() -> void:
	play(victory, -3.0)
