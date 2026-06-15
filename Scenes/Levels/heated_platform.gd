extends StaticBody2D
## Heated platform factory hazard. Damages the player on contact
## after a brief warmup period. Visual warning before damage ticks.

@export var damage_interval := 1.0
@export var warmup_time := 0.5

var _player_on := false
var _active := false
var _damage_timer := 0.0
var _warmup_timer := 0.0
var _visual: Sprite2D


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Sprite2D
	var detect := Area2D.new()
	detect.collision_mask = 2
	detect.collision_layer = 0
	var shape := CollisionShape2D.new()
	var detect_rect := RectangleShape2D.new()
	var body_col := get_child(0) as CollisionShape2D
	if body_col and body_col.shape:
		detect_rect.size = Vector2(body_col.shape.size.x, 6.0)
	else:
		detect_rect.size = Vector2(48.0, 6.0)
	shape.shape = detect_rect
	shape.position = Vector2(0, -6.0)
	detect.add_child(shape)
	add_child(detect)
	detect.body_entered.connect(_on_body_landed)
	detect.body_exited.connect(_on_body_left)
	set_process(false)


func _on_body_landed(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_on = true
	_warmup_timer = warmup_time
	_damage_timer = damage_interval
	_active = false
	set_process(true)
	SFX.play_heated_platform()  # sizzling warning as it heats up


func _on_body_left(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_on = false
	set_process(false)
	if _visual:
		_visual.modulate = Color(1.0, 0.2, 0.1, 1.0)


func _process(delta: float) -> void:
	if not _player_on:
		return

	if not _active:
		_warmup_timer -= delta
		if _visual:
			var blink := 0.3 if fmod(_warmup_timer, 0.15) < 0.075 else 0.0
			_visual.modulate = Color(1.0, blink, blink, 1.0)
		if _warmup_timer <= 0.0:
			_active = true
			_damage_timer = damage_interval
			if _visual:
				_visual.modulate = Color(1.0, 0.0, 0.0, 1.0)
		return

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = damage_interval
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player and player.has_method("take_damage"):
			player.take_damage(1)
			if _visual:
				_visual.modulate = Color(2.0, 0.0, 0.0, 1.0)
				var tween := create_tween()
				tween.tween_property(_visual, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.1)
