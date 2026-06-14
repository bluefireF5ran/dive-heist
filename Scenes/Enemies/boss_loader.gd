extends CharacterBody2D
## Factory boss (end of factory, level 6): the LOADER — a heavy industrial mech.
## Same fight philosophy as the prison Warden: we only attack downward, so we ride
## the side elevators up and hit it from above; the boss punishes the spots we want
## to stand in. Factory-flavoured attack set:
##   - Player above   -> cargo barrage (Attack4): a fan of three lobbed shells.
##                       Dodge the spread, or scan-cone (Attack1) for area denial.
##   - Player low/far  -> ram charge (Special wind-up -> Attack3 dash).
##   - Player adjacent -> piston punch (Attack2).
## Death completes the level. Built from the Bosses_Industrial/1 Loader sheets (96px).

signal died

const MONEY_SCENE := preload("res://Scenes/Collectibles/money.tscn")
const DEATH_EXPLOSION := preload("res://Scenes/VFX/death_explosion.tscn")
const PROJECTILE := preload("res://Scenes/Enemies/boss_projectile.gd")
const CONE := preload("res://Scenes/Enemies/boss_cone.gd")
const GRAVITY := 800.0
const _DIR := "res://Sprites/Active_Sprites/enemies/boss_loader/"
# Attack origins relative to the boss origin (feet); X is mirrored by facing.
const HEAD_OFFSET := Vector2(20.0, -30.0)  # cone (scanner) origin, toward the forks
const ARM_OFFSET := Vector2(18.0, -34.0)  # cargo-throw origin (cab/loader top)

const ANIMS := {
	"idle": {"tex": preload(_DIR + "Idle.png"), "count": 4, "fps": 6.0, "loop": true},
	"walk": {"tex": preload(_DIR + "Walk.png"), "count": 4, "fps": 8.0, "loop": true},
	"cone": {"tex": preload(_DIR + "Attack1.png"), "count": 6, "fps": 9.0, "loop": false},
	"punch": {"tex": preload(_DIR + "Attack2.png"), "count": 4, "fps": 12.0, "loop": false},
	"charge": {"tex": preload(_DIR + "Attack3.png"), "count": 6, "fps": 12.0, "loop": true},
	"throw": {"tex": preload(_DIR + "Attack4.png"), "count": 6, "fps": 10.0, "loop": false},
	"special": {"tex": preload(_DIR + "Special.png"), "count": 6, "fps": 8.0, "loop": false},
	"hurt": {"tex": preload(_DIR + "Hurt.png"), "count": 2, "fps": 8.0, "loop": false},
	"death": {"tex": preload(_DIR + "Death.png"), "count": 4, "fps": 8.0, "loop": false},
}

enum State { PATROL, BUSY, CHARGE_WINDUP, CHARGE_DASH, PUNCH, RECOVER }

@export var hp := 24
@export var speed := 26.0
@export var attack_interval := 1.5
@export var patrol_half_width := 90.0
@export var charge_speed := 165.0

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
var _punch_done := false


func _ready() -> void:
	_world = get_tree().current_scene as Node2D
	_start_x = global_position.x
	_base_offset_x = _sprite.offset.x
	_build_frames()
	_stomp_area.body_entered.connect(_on_stomp_area_body_entered)
	_hitbox.body_entered.connect(_on_hitbox_body_entered)
	if _world and "_boss_active" in _world:
		_world._boss_active = true


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
		State.BUSY:
			_state_timed(delta, State.RECOVER, 0.35)
		State.CHARGE_WINDUP:
			_state_charge_windup(delta)
		State.CHARGE_DASH:
			_state_charge_dash(delta)
		State.PUNCH:
			_state_punch(delta)
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


func _state_timed(delta: float, next: State, next_t: float) -> void:
	velocity.x = 0.0
	move_and_slide()
	_t -= delta
	if _t <= 0.0:
		_state = next
		_t = next_t


func _state_recover(delta: float) -> void:
	velocity.x = 0.0
	move_and_slide()
	_t -= delta
	if _t <= 0.0:
		_state = State.PATROL
		# Overclock: attack faster below half HP.
		_attack_cd = attack_interval * (0.6 if hp <= 12 else 1.0)
		_sprite.play("walk")


func _choose_attack() -> void:
	velocity.x = 0.0
	if not _player:
		_attack_cd = 0.5
		return
	var rel: Vector2 = _player.global_position - global_position
	var face_left := rel.x < 0.0
	_set_facing(face_left)
	var fwd := -1.0 if face_left else 1.0
	var above := rel.y < -24.0
	var close := absf(rel.x) < 52.0 and absf(rel.y) < 44.0

	if close:
		_start_punch()
	elif not above and absf(rel.x) > 56.0:
		_start_charge(fwd)
	elif above and randf() < 0.6:
		_start_throw(fwd, rel)
	else:
		_start_cone(fwd)


## Cargo barrage: a fan of three lobbed shells aimed at the player. Punishes
## camping above the boss on the elevators.
func _start_throw(fwd: float, rel: Vector2) -> void:
	_sprite.play("throw")
	var origin := global_position + Vector2(fwd * ARM_OFFSET.x, ARM_OFFSET.y)
	var to := _player.global_position - origin
	var base_ang := atan2(to.y, to.x)
	var parent := get_parent()
	for spread: float in [-0.2, 0.0, 0.2]:
		var ang: float = base_ang + spread
		var proj := PROJECTILE.new()
		proj.velocity = Vector2(cos(ang), sin(ang)) * 155.0
		if parent:
			parent.add_child(proj)
			proj.global_position = origin
	SFX.play_shoot(0.5, 0.6)
	_state = State.BUSY
	_t = 0.95


func _start_cone(fwd: float) -> void:
	_sprite.play("cone")
	var cone := CONE.new()
	cone.facing = fwd
	var parent := get_parent()
	if parent:
		parent.add_child(cone)
		cone.global_position = global_position + Vector2(fwd * HEAD_OFFSET.x, HEAD_OFFSET.y)
	SFX.play_shoot(0.4, 0.5)
	_state = State.BUSY
	_t = 1.0


func _start_charge(fwd: float) -> void:
	_charge_dir = fwd
	_set_facing(fwd < 0.0)
	_sprite.play("special")  # wind-up telegraph
	SFX.play_stomp_material()
	_state = State.CHARGE_WINDUP
	_t = 0.6


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


func _start_punch() -> void:
	_sprite.play("punch")
	_punch_done = false
	_state = State.PUNCH
	_t = 0.5


func _state_punch(delta: float) -> void:
	velocity.x = 0.0
	move_and_slide()
	_t -= delta
	if not _punch_done and _t <= 0.28:
		_punch_done = true
		_do_punch()
	if _t <= 0.0:
		_state = State.RECOVER
		_t = 0.3


func _do_punch() -> void:
	if not _player:
		return
	var rel: Vector2 = _player.global_position - global_position
	var fwd := -1.0 if _sprite.flip_h else 1.0
	if fwd * rel.x > 0.0 and absf(rel.x) < 46.0 and absf(rel.y) < 32.0:
		if _player.has_method("take_damage"):
			_player.take_damage(1)
		if _world and _world.has_method("screen_shake"):
			_world.screen_shake(2.0)
	SFX.play_stomp_bones()


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount
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
	for i in range(8):
		var money := MONEY_SCENE.instantiate()
		money.value = 3
		money.global_position = global_position + Vector2(randf_range(-20, 20), -30)
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
