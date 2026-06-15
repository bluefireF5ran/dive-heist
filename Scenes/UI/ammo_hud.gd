extends CanvasLayer

var max_ammo := 8
var current_ammo := 8
var max_hp := 4
var current_hp := 4
var shield := 0
var depth := 0
var combo := 0
var money := 0
var score := 0
var game_over := false
var reward_text := ""
var reward_timer := 0.0
var perks: Array = []  # Acquired perk icon paths, shown as icons top-right
var _perk_nodes: Array = []  # Live TextureRect nodes for the perk icons

# Level complete screen state
var level_complete := false
var lc_level := 1
var lc_kills := 0
var lc_money_earned := 0
var lc_max_combo := 0
var lc_depth := 0
var lc_perk_pending := false  # Hide the "JUMP to continue" hint while perks show

# Death screen state (cumulative run stats)
var death_screen := false
var victory_screen := false  # Demo cleared (factory boss beaten)
var ds_depth := 0
var ds_kills := 0
var ds_money := 0
var ds_max_combo := 0

# Boss health bar (shown during a boss fight)
var boss_active := false
var boss_hp := 0
var boss_max_hp := 1
var boss_name := ""
var boss_intro_name := ""  # Transient "boss appeared" flash
var boss_intro_timer := 0.0

@onready var bar_container: Control = $AmmoBar


func _ready() -> void:
	bar_container.queue_redraw()


func _process(delta: float) -> void:
	if reward_timer > 0:
		reward_timer -= delta
		if reward_timer <= 0:
			reward_text = ""
		bar_container.queue_redraw()
	if boss_intro_timer > 0.0:
		boss_intro_timer -= delta
		bar_container.queue_redraw()
	# Continuous redraw for pulsing text overlays
	if level_complete or death_screen or victory_screen:
		bar_container.queue_redraw()


func set_ammo(value: int) -> void:
	current_ammo = maxi(value, 0)
	bar_container.queue_redraw()


func set_max_ammo(value: int) -> void:
	max_ammo = value
	bar_container.queue_redraw()


func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)
	bar_container.queue_redraw()


func set_shield(value: int) -> void:
	shield = maxi(value, 0)
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


func set_weapon(weapon_name: String, color: Color) -> void:
	bar_container.set_weapon(weapon_name, color)


## Show the acquired perks as a row of icons in the top-right, above the weapon
## name. `value` is a list of icon resource paths (resolved by world.gd). Uses
## TextureRect nodes — draw_texture_rect renders these textures as white squares.
func set_perks(value: Array) -> void:
	perks = value
	for n in _perk_nodes:
		n.queue_free()
	_perk_nodes.clear()
	var vp := get_viewport().get_visible_rect().size
	var sz := 12.0
	var pad := 2.0
	var per_row := 8
	for i in range(value.size()):
		var path: String = value[i]
		if path == "":
			continue
		var tex: Texture2D = load(path)
		if not tex:
			continue
		var col := i % per_row
		var row := i / per_row
		var ic := TextureRect.new()
		ic.texture = tex
		ic.size = Vector2(sz, sz)
		ic.position = Vector2(
			vp.x - 4.0 - float(col + 1) * (sz + pad), 4.0 + float(row) * (sz + pad)
		)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		_perk_nodes.append(ic)


func set_score(value: int) -> void:
	score = value
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


func show_death_screen(depth_val: int, kills: int, money_val: int, max_combo: int) -> void:
	game_over = true
	death_screen = true
	ds_depth = depth_val
	ds_kills = kills
	ds_money = money_val
	ds_max_combo = max_combo
	bar_container.queue_redraw()


## Demo cleared (factory boss beaten) — celebratory terminal screen. Reuses the
## death-screen run stats.
func show_victory(depth_val: int, kills: int, money_val: int, max_combo: int) -> void:
	victory_screen = true
	ds_depth = depth_val
	ds_kills = kills
	ds_money = money_val
	ds_max_combo = max_combo
	bar_container.queue_redraw()


func show_boss_bar(bname: String, max_hp: int) -> void:
	boss_active = true
	boss_name = bname
	boss_max_hp = maxi(max_hp, 1)
	boss_hp = boss_max_hp
	boss_intro_name = bname
	boss_intro_timer = 2.2
	bar_container.queue_redraw()


func set_boss_hp(hp: int) -> void:
	if not boss_active:
		return
	boss_hp = hp
	bar_container.queue_redraw()


func hide_boss_bar() -> void:
	boss_active = false
	bar_container.queue_redraw()


func show_level_complete(level: int, kills: int, money_earned: int, max_combo: int, depth_reached: int) -> void:
	level_complete = true
	lc_level = level
	lc_kills = kills
	lc_money_earned = money_earned
	lc_max_combo = max_combo
	lc_depth = depth_reached
	bar_container.queue_redraw()


func hide_level_complete() -> void:
	level_complete = false
	lc_perk_pending = false
	bar_container.queue_redraw()
