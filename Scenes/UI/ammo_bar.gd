extends Control

# Draws ammo bar (right), HP pips (top-left), depth counter, combo, game over.

const BAR_WIDTH := 8.0
const BAR_MARGIN_RIGHT := 4.0
const BAR_MARGIN_TOP := 40.0
const BAR_MARGIN_BOTTOM := 40.0
const SEGMENT_GAP := 2.0
const FILL_COLOR := Color(0.9, 0.8, 0.2, 1.0)
const EMPTY_COLOR := Color(0.2, 0.2, 0.25, 0.5)
const BORDER_COLOR := Color(0.6, 0.55, 0.25, 0.8)
const BONUS_COLOR := Color(0.3, 1.0, 0.6, 1.0)

# HP display
const HP_MARGIN_LEFT := 6.0
const HP_MARGIN_TOP := 6.0
const HP_SIZE := 8.0
const HP_GAP := 3.0
const HP_FILL := Color(0.85, 0.2, 0.2, 1.0)
const HP_EMPTY := Color(0.3, 0.15, 0.15, 0.5)
const HP_BORDER := Color(0.6, 0.15, 0.15, 0.8)

var _font: Font
var weapon_color := Color(0.9, 0.8, 0.2, 1.0)
var weapon_name := "pistol"


func _ready() -> void:
	_font = load(
		"res://Sprites/Scraper/Cyberpunk_Assets/Game_UI/UI_Main/10 Font/CyberpunkCraftpixPixel.otf"
	)


func set_weapon(wname: String, color: Color) -> void:
	weapon_name = wname
	weapon_color = color
	queue_redraw()


func _draw() -> void:
	var hud: CanvasLayer = get_parent()
	_draw_ammo_bar(hud.max_ammo, hud.current_ammo)
	_draw_weapon_name()
	_draw_hp(hud.max_hp, hud.current_hp)
	_draw_money(hud.money)
	_draw_depth(hud.depth)
	_draw_combo(hud.combo)
	if hud.reward_text != "":
		_draw_reward(hud.reward_text, hud.reward_timer)
	if hud.level_complete:
		_draw_level_complete(hud)
	elif hud.death_screen:
		_draw_death_screen(hud)
	elif hud.game_over:
		_draw_game_over()



func _draw_ammo_bar(max_ammo: int, current_ammo: int) -> void:
	var total_segments := maxi(max_ammo, current_ammo)
	var viewport_size := get_viewport_rect().size
	var bar_x := viewport_size.x - BAR_WIDTH - BAR_MARGIN_RIGHT
	var bar_top := BAR_MARGIN_TOP
	var bar_bottom := viewport_size.y - BAR_MARGIN_BOTTOM
	var total_height := bar_bottom - bar_top
	var segment_height := (total_height - SEGMENT_GAP * (total_segments - 1)) / total_segments

	for i in range(total_segments):
		var seg_y := bar_bottom - (i + 1) * segment_height - i * SEGMENT_GAP
		var rect := Rect2(bar_x, seg_y, BAR_WIDTH, segment_height)

		if i < current_ammo:
			if i < max_ammo:
				draw_rect(rect, weapon_color)
			else:
				draw_rect(rect, BONUS_COLOR)
		else:
			draw_rect(rect, EMPTY_COLOR)

		draw_rect(rect, BORDER_COLOR, false, 1.0)


func _draw_weapon_name() -> void:
	var text := weapon_name.to_upper()
	var font_size := 8
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var viewport_size := get_viewport_rect().size
	var x := viewport_size.x - BAR_WIDTH - BAR_MARGIN_RIGHT - text_size.x - 4.0
	var y := BAR_MARGIN_TOP - 10.0
	# Shadow
	draw_string(
		_font,
		Vector2(x + 1, y + 1),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0, 0, 0, 0.7)
	)
	# Text in weapon color
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, weapon_color)


func _draw_hp(max_hp: int, current_hp: int) -> void:
	for i in range(max_hp):
		var x := HP_MARGIN_LEFT + i * (HP_SIZE + HP_GAP)
		var rect := Rect2(x, HP_MARGIN_TOP, HP_SIZE, HP_SIZE)

		if i < current_hp:
			draw_rect(rect, HP_FILL)
		else:
			draw_rect(rect, HP_EMPTY)

		draw_rect(rect, HP_BORDER, false, 1.0)


func _draw_money(amount: int) -> void:
	var text := "$" + str(amount)
	var color := Color(0.9, 0.8, 0.2, 1.0)  # Gold, matches ammo bar
	var font_size := 10
	# Below HP pips, left-aligned
	var x := HP_MARGIN_LEFT
	var y := HP_MARGIN_TOP + HP_SIZE + 12.0
	draw_string(
		_font,
		Vector2(x + 1, y + 1),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0, 0, 0, 0.7)
	)
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_depth(depth: int) -> void:
	var text := str(depth) + "m"
	var viewport_size := get_viewport_rect().size
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	var x := (viewport_size.x - text_size.x) / 2.0
	draw_string(_font, Vector2(x, 18), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)


func _draw_combo(combo_val: int) -> void:
	if combo_val <= 0:
		return
	var text := "x" + str(combo_val)
	var viewport_size := get_viewport_rect().size
	# Color escalates with combo tier
	var color: Color
	var font_size: int
	if combo_val >= 25:
		color = Color(1, 0.2, 0.9, 1)  # Hot pink - jackpot tier
		font_size = 18
	elif combo_val >= 15:
		color = Color(1, 0.3, 0.15, 1)  # Red-orange
		font_size = 16
	elif combo_val >= 8:
		color = Color(1, 0.6, 0.1, 1)  # Orange
		font_size = 15
	elif combo_val >= 3:
		color = Color(1, 0.9, 0.3, 1)  # Yellow
		font_size = 14
	else:
		color = Color(0.8, 0.8, 0.8, 1)  # Grey
		font_size = 12
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var x := (viewport_size.x - text_size.x) / 2.0
	# Outline for readability
	draw_string(
		_font, Vector2(x + 1, 39), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK
	)
	draw_string(
		_font, Vector2(x - 1, 39), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK
	)
	draw_string(
		_font, Vector2(x, 40), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK
	)
	draw_string(
		_font, Vector2(x, 38), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK
	)
	draw_string(_font, Vector2(x, 39), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _draw_reward(text: String, timer: float) -> void:
	var viewport_size := get_viewport_rect().size
	var alpha := clampf(timer / 0.5, 0.0, 1.0)  # Fade out in last 0.5s
	var color := Color(1, 0.95, 0.4, alpha)
	var font_size := 12
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var x := (viewport_size.x - text_size.x) / 2.0
	var y := 56.0 - (1.0 - alpha) * 8.0  # Float upward as it fades
	draw_string(
		_font,
		Vector2(x + 1, y + 1),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		Color(0, 0, 0, alpha)
	)
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _draw_game_over() -> void:
	var viewport_size := get_viewport_rect().size
	# Dim overlay
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.6))
	# GAME OVER text
	var go_text := "GAME OVER"
	var go_size := _font.get_string_size(go_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var go_x := (viewport_size.x - go_size.x) / 2.0
	var go_y := viewport_size.y / 2.0
	draw_string(
		_font,
		Vector2(go_x, go_y),
		go_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		16,
		Color(0.9, 0.2, 0.2)
	)
	# Restart hint
	var hint := "JUMP to restart"
	var hint_size := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	var hint_x := (viewport_size.x - hint_size.x) / 2.0
	draw_string(
		_font,
		Vector2(hint_x, go_y + 20),
		hint,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		8,
		Color(0.7, 0.7, 0.7)
	)


func _draw_death_screen(hud: CanvasLayer) -> void:
	var viewport_size := get_viewport_rect().size
	var cx := viewport_size.x / 2.0
	var cy := viewport_size.y / 2.0

	# Darker overlay
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.75))

	# Title: "GAME OVER" in red
	var title := "GAME OVER"
	var title_size := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var title_x := (viewport_size.x - title_size.x) / 2.0
	draw_string(
		_font,
		Vector2(title_x + 1, cy - 60 + 1),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		16,
		Color(0, 0, 0, 0.8)
	)
	draw_string(
		_font,
		Vector2(title_x, cy - 60),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		16,
		Color(0.9, 0.2, 0.2, 1.0)
	)

	# Stats — label on left, value on right, centered as a block
	var stats: Array[Dictionary] = [
		{label = "Depth:", value = str(hud.ds_depth) + "m", color = Color(0.6, 0.7, 0.9, 1.0)},
		{label = "Kills:", value = str(hud.ds_kills), color = Color(0.85, 0.85, 0.85, 1.0)},
		{label = "Money:", value = "$" + str(hud.ds_money), color = Color(0.9, 0.8, 0.2, 1.0)},
		{
			label = "Max Combo:",
			value = "x" + str(hud.ds_max_combo),
			color = Color(1.0, 0.6, 0.2, 1.0)
		},
	]
	var stat_y_start := cy - 30.0
	var label_x := cx - 60.0
	var value_x := cx + 10.0
	for i in range(stats.size()):
		var sy := stat_y_start + i * 18.0
		# Label (left-aligned)
		draw_string(
			_font,
			Vector2(label_x + 1, sy + 1),
			stats[i].label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(0, 0, 0, 0.6)
		)
		draw_string(
			_font,
			Vector2(label_x, sy),
			stats[i].label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(0.6, 0.6, 0.6, 1.0)
		)
		# Value (left-aligned, colored)
		draw_string(
			_font,
			Vector2(value_x + 1, sy + 1),
			stats[i].value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color(0, 0, 0, 0.6)
		)
		draw_string(
			_font,
			Vector2(value_x, sy),
			stats[i].value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			stats[i].color
		)

	# Restart hint — pulsing
	var hint := "JUMP to restart"
	var hint_size := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	var hint_x := (viewport_size.x - hint_size.x) / 2.0
	draw_string(
		_font,
		Vector2(hint_x, cy + 56),
		hint,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		8,
		Color(0.6, 0.6, 0.6, 0.8 + 0.2 * sin(Time.get_ticks_msec() / 300.0))
	)


func _draw_level_complete(hud: CanvasLayer) -> void:
	var viewport_size := get_viewport_rect().size
	var cx := viewport_size.x / 2.0
	var cy := viewport_size.y / 2.0

	# Dim overlay
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.7))

	# Title: "LEVEL X COMPLETE"
	var title := "LEVEL " + str(hud.lc_level) + " COMPLETE"
	var title_size := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	var title_x := (viewport_size.x - title_size.x) / 2.0
	draw_string(
		_font,
		Vector2(title_x + 1, cy - 60 + 1),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14,
		Color(0, 0, 0, 0.8)
	)
	draw_string(
		_font,
		Vector2(title_x, cy - 60),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14,
		Color(0.2, 1.0, 0.4, 1.0)
	)

	# Stats
	var stats: Array[String] = [
		"Kills: " + str(hud.lc_kills),
		"Money: $" + str(hud.lc_money_earned),
		"Max Combo: x" + str(hud.lc_max_combo),
		"Depth: " + str(hud.lc_depth) + "m",
	]
	var stat_color := Color(0.85, 0.85, 0.85, 1.0)
	var stat_y_start := cy - 30.0
	for i in range(stats.size()):
		var stat_text := stats[i]
		var stat_size := _font.get_string_size(stat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var stat_x := (viewport_size.x - stat_size.x) / 2.0
		var sy := stat_y_start + i * 18.0
		draw_string(
			_font,
			Vector2(stat_x + 1, sy + 1),
			stat_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			10,
			Color(0, 0, 0, 0.6)
		)
		draw_string(
			_font, Vector2(stat_x, sy), stat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, stat_color
		)

	# Continue hint
	var hint := "JUMP to continue"
	var hint_size := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	var hint_x := (viewport_size.x - hint_size.x) / 2.0
	draw_string(
		_font,
		Vector2(hint_x, cy + 56),
		hint,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		8,
		Color(0.6, 0.6, 0.6, 0.8 + 0.2 * sin(Time.get_ticks_msec() / 300.0))
	)
