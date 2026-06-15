extends Area2D
## Factory wall hazard. A spiked strip mounted on a well wall that damages the
## player periodically while touching it — discourages hugging a wall to fall
## fast. Built procedurally by chunk_generator; visuals are code-drawn spikes.

const DAMAGE_INTERVAL := 0.75
const HEAR_DISTANCE := 150.0  # only whirr when the player is close (bounds active voices)

var _cooldown := 0.0
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player
	# Positional, looping saw whirr — only audible near the blades.
	var s: AudioStream = SFX.sawblade
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_audio = AudioStreamPlayer2D.new()
	_audio.stream = s
	_audio.bus = "SFX"
	_audio.volume_db = -13.0
	_audio.max_distance = 170.0
	_audio.attenuation = 1.5
	add_child(_audio)


func _process(delta: float) -> void:
	# Start/stop the whirr based on player proximity so far-off saws aren't all playing.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var near := global_position.distance_to(player.global_position) < HEAR_DISTANCE
		if near and not _audio.playing:
			_audio.play()
		elif not near and _audio.playing:
			_audio.stop()

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1)
			_cooldown = DAMAGE_INTERVAL
			return
