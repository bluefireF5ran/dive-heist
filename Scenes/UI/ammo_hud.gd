extends CanvasLayer

var max_ammo := 8
var current_ammo := 8
var max_hp := 3
var current_hp := 3
var depth := 0
var combo := 0
var money := 0
var game_over := false
var reward_text := ""
var reward_timer := 0.0

@onready var bar_container: Control = $AmmoBar


func _ready() -> void:
	bar_container.queue_redraw()


func _process(delta: float) -> void:
	if reward_timer > 0:
		reward_timer -= delta
		if reward_timer <= 0:
			reward_text = ""
		bar_container.queue_redraw()


func set_ammo(value: int) -> void:
	current_ammo = clampi(value, 0, max_ammo)
	bar_container.queue_redraw()


func set_max_ammo(value: int) -> void:
	max_ammo = value
	bar_container.queue_redraw()


func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)
	bar_container.queue_redraw()


func set_max_hp(value: int) -> void:
	max_hp = value
	bar_container.queue_redraw()


func set_depth(value: int) -> void:
	depth = value
	bar_container.queue_redraw()


func set_combo(value: int) -> void:
	combo = value
	bar_container.queue_redraw()


func set_money(value: int) -> void:
	money = value
	bar_container.queue_redraw()


func show_combo_reward(tier: int, combo_val: int) -> void:
	if tier == 0:
		reward_text = "x" + str(combo_val)
	elif tier == 1:
		reward_text = "x" + str(combo_val) + " +HP!"
	elif tier == 2:
		reward_text = "x" + str(combo_val) + " +HP +AMMO!"
	else:
		reward_text = "x" + str(combo_val) + " JACKPOT!"
	reward_timer = 1.5
	bar_container.queue_redraw()


func show_game_over() -> void:
	game_over = true
	bar_container.queue_redraw()
