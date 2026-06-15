extends CharacterBody2D
## Factory boss: the LOADER — a heavy industrial mech. Same philosophy as the Warden
## (we hit it from the air via the side elevators; grounded shots do half damage) but
## with a punchier, position-aware moveset:
##   - Player above   -> SHELL FAN (Attack4): a wide spread of shells. Dodge sideways.
##   - Player level/far-> GROUND SHOCKWAVE (Special): two waves roll along the floor —
##                        jump them — or a RAM CHARGE (Attack3).
##   - Player close    -> POINT-BLANK VOLLEY (Attack2): a tight burst of shells.
##   - Filler          -> SCAN CONE (Attack1): area denial.
## Lots of HP, enrages under half. Built from the Bosses_Industrial/1 Loader sheets.

signal died

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")
const PROJECTILE := preload("res://Scenes/Enemies/boss_projectile.gd")
const CONE := preload("res://Scenes/Enemies/boss_cone.gd")
const GRAVITY := 800.0
const _DIR := "res://Sprites/Active_Sprites/enemies/boss_loader/"
const MUZZLE := Vector2(18.0, -34.0)  # cab-top shell origin (x mirrored by facing)
const HEAD_OFFSET := Vector2(20.0, -30.0)

const ANIMS := {
	"idle": {"tex": preload(_DIR + "Idle.png"), "count": 4, "fps": 6.0, "loop": true},
	"walk": {"tex": preload(_DIR + "Walk.png"), "count": 4, "fps": 8.0, "loop": true},
	"cone": {"tex": preload(_DIR + "Attack1.png"), "count": 6, "fps": 9.0, "loop": false},
	"volley": {"tex": preload(_DIR + "Attack2.png"), "count": 4, "fps": 12.0, "loop": false},
	"charge": {"tex": preload(_DIR + "Attack3.png"), "count": 6, "fps": 12.0, "loop": true},
	"fan": {"tex": preload(_DIR + "Attack4.png"), "count": 6, "fps": 10.0, "loop": false},
	"special": {"tex": preload(_DIR + "Special.png"), "count": 6, "fps": 8.0, "loop": false},
	"hurt": {"tex": preload(_DIR + "Hurt.png"), "count": 2, "fps": 8.0, "loop": false},
	"death": {"tex": preload(_DIR + "Death.png"), "count": 4, "fps": 8.0, "loop": false},
}

enum State { PATROL, WINDUP, CHARGE_WINDUP, CHARGE_DASH, RECOVER }

@export var hp := 42
@export var speed := 26.0
@export var attack_interval := 1.3
@export var patrol_half_width := 90.0
@export var charge_speed := 175.0

var boss_name := "LOADER"
var _is_dead := false
var _dir := 1.0
var _hurt_timer := 0.0
var _start_x: float
var _world: Node2D
var _player: CharacterBody2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _stomp_area: Area2D = $StompArea
@onready var _hitbox: Area2D = $Hitbox
var _base_offset_x := 0.0

var _state := State.PATROL
var _t := 0.0
var _attack_cd := 1.2
var _charge_dir := 1.0
var _pending := ""
var _hp_max := 42


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	_hp_max = hp
	_start_x = global_position.x
	_base_offset_x = _sprite.offset.x
	_build_frames()
	_stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	_hitbox.body_entered.connect(_on_hitbox_body_entered)
	if _world and "_boss_active" in _world:
		_world._boss_active = true
	if _world and _world.has_method("register_boss"):
		_world.register_boss(self)


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	for anim: String in ANIMS:
		var d: Dictionary = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, d["fps"])
		frames.set_animation_loop(anim, d["loop"])
		var tex: Texture2D = d["tex"]
		for i in range(int(d["count"])):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 96, 0, 96, 96)
			frames.add_frame(anim, at)
	_sprite.sprite_frames = frames
	_sprite.play("idle")


func _set_facing(face_left: bool) -> void:
	_sprite.flip_h = face_left
	_sprite.offset.x = -_base_offset_x if face_left else _base_offset_x


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_hurt_timer -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	match _state:
		State.PATROL:
			_state_patrol(delta)
		State.WINDUP:
			_state_windup(delta)
		State.CHARGE_WINDUP:
			_state_charge_windup(delta)
		State.CHARGE_DASH:
			_state_charge_dash(delta)
		State.RECOVER:
			_state_recover(delta)


func _state_patrol(delta: float) -> void:
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_choose_attack()
		return
	velocity.x = _dir * speed
	move_and_slide()
	var off := global_position.x - _start_x
	if off > patrol_half_width:
		_dir = -1.0
	elif off < -patrol_half_width:
		_dir = 1.0
	elif is_on_wall():
		_dir = -_dir
	_set_facing(_dir < 0.0)
	if _hurt_timer <= 0.0 and _sprite.animation != "walk":
		_sprite.play("walk")


func _state_recover(delta: float) -> void:
	velocity.x = 0.0
	move_and_slide()
	_t -= delta
	if _t <= 0.0:
		_state = State.PATROL
		_attack_cd = attack_interval * (0.55 if hp <= int(_hp_max / 2.0) else 1.0)
		_sprite.play("walk")


func _choose_attack() -> void:
	velocity.x = 0.0
	if not _player:
		_attack_cd = 0.5
		return
	var rel: Vector2 = _player.global_position - global_position
	_set_facing(rel.x < 0.0)
	var above := rel.y < -28.0
	var far := absf(rel.x) > 64.0

	# Far & level: ram or shockwave (both make camping on the floor dangerous).
	if far and not above and randf() < 0.5:
		_start_charge(-1.0 if rel.x < 0.0 else 1.0)
		return

	var opts: Array = ["volley", "shockwave"]
	if above:
		opts = ["fan", "fan", "cone"]
	elif far:
		opts = ["shockwave", "cone"]
	_pending = str(opts[randi() % opts.size()])
	# Shockwave telegraphs with the "special" slam wind-up; the rest share their name.
	_sprite.play("special" if _pending == "shockwave" else _pending)
	_state = State.WINDUP
	_t = 0.5


func _state_windup(delta: float) -> void:
	velocity.x = 0.0
	move_and_slide()
	_t -= delta
	if _t <= 0.0:
		_execute(_pending)
		_state = State.RECOVER
		_t = 0.5


func _execute(atk: String) -> void:
	if not _player or not is_instance_valid(_player):
		return
	match atk:
		"fan":
			_fire_fan()
		"cone":
			_fire_cone()
		"shockwave":
			_fire_shockwave()
		"volley":
			_fire_volley()


## Wide spread of shells aimed at the player — punishes camping above.
func _fire_fan() -> void:
	var origin := global_position + Vector2(_face() * MUZZLE.x, MUZZLE.y)
	var base := (_player.global_position - origin).angle()
	for spread: float in [-0.42, -0.21, 0.0, 0.21, 0.42]:
		_spawn_shell(origin, base + spread, 150.0)
	SFX.play_boss_shell()


## Tight, fast burst straight at the player — point-blank punish.
func _fire_volley() -> void:
	var origin := global_position + Vector2(_face() * MUZZLE.x, MUZZLE.y)
	var base := (_player.global_position - origin).angle()
	for spread: float in [-0.08, 0.0, 0.08, 0.0]:
		_spawn_shell(origin, base + spread, 220.0)
	SFX.play_boss_shell()


## Two shockwaves rolling along the floor in both directions — jump over them.
func _fire_shockwave() -> void:
	if _world and _world.has_method("screen_shake"):
		_world.screen_shake(3.0)
	SFX.play_shockwave()
	for d: float in [-1.0, 1.0]:
		var p := PROJECTILE.new()
		p.velocity = Vector2(d * 150.0, 0.0)
		p.life = 3.0
		var parent := get_parent()
		if parent:
			parent.add_child(p)
			p.global_position = global_position + Vector2(d * 22.0, -5.0)


func _fire_cone() -> void:
	var fwd := _face()
	var cone := CONE.new()
	cone.facing = fwd
	var parent := get_parent()
	if parent:
		parent.add_child(cone)
		cone.global_position = global_position + Vector2(fwd * HEAD_OFFSET.x, HEAD_OFFSET.y)
	SFX.play_shoot(0.4, 0.5)


func _spawn_shell(origin: Vector2, angle: float, spd: float) -> void:
	var p := PROJECTILE.new()
	p.velocity = Vector2(cos(angle), sin(angle)) * spd
	var parent := get_parent()
	if parent:
		parent.add_child(p)
		p.global_position = origin


func _face() -> float:
	return -1.0 if _sprite.flip_h else 1.0


func _start_charge(fwd: float) -> void:
	_charge_dir = fwd
	_set_facing(fwd < 0.0)
	_sprite.play("special")
	SFX.play_stomp_material()
	_state = State.CHARGE_WINDUP
	_t = 0.55


func _state_charge_windup(delta: float) -> void:
	velocity.x = 0.0
	move_and_slide()
	_t -= delta
	if _t <= 0.0:
		_sprite.play("charge")
		if _world and _world.has_method("screen_shake"):
			_world.screen_shake(2.0)
		_state = State.CHARGE_DASH
		_t = 1.3


func _state_charge_dash(delta: float) -> void:
	velocity.x = _charge_dir * charge_speed
	move_and_slide()
	_t -= delta
	if is_on_wall() or _t <= 0.0:
		_sprite.play("idle")
		_state = State.RECOVER
		_t = 0.5


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	# Grounded hits do half — fight from the air (ride the elevators), don't camp.
	var dmg := amount
	if _player and is_instance_valid(_player) and _player.is_on_floor():
		dmg = maxi(1, int(dmg / 2.0))
	hp -= dmg
	if hp <= 0:
		_die()
		return
	modulate = Color(2, 2, 2, 1)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if _state == State.PATROL:
		_sprite.play("hurt")
		_hurt_timer = 0.18


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	_sprite.play("death")
	SFX.play_death_warden()
	if _world and _world.has_method("screen_shake"):
		_world.screen_shake(6.0)
	_spawn_death_explosion()
	for i in range(10):
		var money := MONEY_SCENE.instantiate()
		money.value = 3
		money.global_position = global_position + Vector2(randf_range(-22, 22), -30)
		_world.call_deferred("add_child", money)
	_stomp_area.set_deferred("monitoring", false)
	_hitbox.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	died.emit()
	if _world and "_boss_active" in _world:
		_world._boss_active = false
	if _world and _world.has_method("_on_level_complete"):
		_world._on_level_complete()
	await _sprite.animation_finished
	queue_free()


func _spawn_death_explosion() -> void:
	for off in [Vector2(-22, -10), Vector2(22, 0), Vector2(0, -28)]:
		var fx := DEATH_EXPLOSION.instantiate()
		fx.explosion_type = "explosion"
		fx.global_position = global_position + off
		_world.call_deferred("add_child", fx)


func _on_stomp_area_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("refill_ammo") and body.velocity.y > 0:
		take_damage(2)
		if _world and _world.has_method("screen_shake"):
			_world.screen_shake(2.5)
		SFX.play_stomp_material()
		body.refill_ammo()
		body.velocity.y = -260.0


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.velocity.y > 0 and body.global_position.y < global_position.y - 30.0:
			return
		body.take_damage(1)
