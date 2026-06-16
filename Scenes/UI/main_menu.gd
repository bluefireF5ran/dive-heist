extends Control

## Main menu — title screen with Start / Options / Quit.
## Title and decorations drawn via _draw(); buttons/sliders are Control nodes.

const WORLD_SCENE := "res://Scenes/Levels/world.tscn"
const WORLD_SCRIPT := preload("res://Scenes/Levels/world.gd")
const PAUSE_MENU := preload("res://Scenes/UI/pause_menu.gd")
const FONT_PATH := "res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf"

var _font: Font
var _transitioning := false
var _ach_panel: Panel
var _debug_panel: Panel
var _controls_panel: Panel

@onready var _start_button: Button = $VBoxContainer/StartButton
@onready var _options_button: Button = $VBoxContainer/OptionsButton
@onready var _quit_button: Button = $VBoxContainer/QuitButton
@onready var _options_panel: Panel = $OptionsPanel
@onready var _music_slider: HSlider = $OptionsPanel/VBoxContainer/MusicSlider
@onready var _sfx_slider: HSlider = $OptionsPanel/VBoxContainer/SFXSlider
@onready var _back_button: Button = $OptionsPanel/VBoxContainer/BackButton
@onready var _fade_rect: ColorRect = $FadeRect


func _ready() -> void:
	_font = load(FONT_PATH)
	queue_redraw()
	_apply_theme(self)

	# Style the options panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.09, 0.13, 0.95)
	panel_style.border_color = Color(0.5, 0.45, 0.6, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	_options_panel.add_theme_stylebox_override("panel", panel_style)

	# Connect button signals
	_start_button.pressed.connect(_on_start_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	# Add an Achievements button (between Options and Quit) + its panel.
	var ach_button := Button.new()
	ach_button.text = "Achievements"
	var vbox := $VBoxContainer
	vbox.add_child(ach_button)
	vbox.move_child(ach_button, 2)
	_apply_theme(ach_button)
	ach_button.pressed.connect(_on_achievements_pressed)
	_build_achievements_panel()

	# Add a Controls button (after Options) + its panel.
	var ctrl_button := Button.new()
	ctrl_button.text = "Controls"
	vbox.add_child(ctrl_button)
	vbox.move_child(ctrl_button, 2)
	_apply_theme(ctrl_button)
	ctrl_button.pressed.connect(_on_controls_pressed)
	_build_controls_panel()

	# Add a Debug button (between Achievements and Quit) + its panel.
	var dbg_button := Button.new()
	dbg_button.text = "Debug"
	vbox.add_child(dbg_button)
	vbox.move_child(dbg_button, 4)
	_apply_theme(dbg_button)
	dbg_button.pressed.connect(_on_debug_pressed)
	_build_debug_panel()

	# Sync sliders with current audio bus volumes
	_music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	_sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	# Options panel hidden initially
	_options_panel.visible = false

	# Start with black overlay, fade in
	_fade_rect.color = Color.BLACK

	# Hide Quit on web builds
	if OS.get_name() == "Web":
		_quit_button.visible = false

	# Focus the start button for keyboard navigation
	_start_button.grab_focus()


func _process(delta: float) -> void:
	if _fade_rect.color.a > 0.0 and not _transitioning:
		_fade_rect.color.a = maxf(_fade_rect.color.a - delta * 2.0, 0.0)


func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if _debug_panel and _debug_panel.visible:
		if event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
			_close_debug()
			get_viewport().set_input_as_handled()
	elif _ach_panel and _ach_panel.visible:
		if event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
			_close_achievements()
			get_viewport().set_input_as_handled()
	elif _controls_panel and _controls_panel.visible:
		if event.is_action_pressed("jump") or event.is_action_pressed("ui_cancel"):
			_close_controls()
			get_viewport().set_input_as_handled()
	elif _options_panel.visible:
		if event.is_action_pressed("jump"):
			_on_back_pressed()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var vp := get_viewport_rect().size

	for y in range(0, int(vp.y), 4):
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color(1, 1, 1, 0.015))

	# Version text at bottom
	var ver := "v0.2"
	var vs := _font.get_string_size(ver, HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	var vx := vp.y - 8
	var ver_color := Color(0.4, 0.4, 0.4, 0.5)
	draw_string(_font, Vector2((vp.x - vs.x) / 2.0, vx), ver, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, ver_color)


func _on_start_pressed() -> void:
	WORLD_SCRIPT.debug_start_level = 1
	_begin_transition()


func _begin_transition() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(WORLD_SCENE)
	)


## Debug: launch the game starting at the given level (with a balanced build).
func _start_at_level(n: int) -> void:
	WORLD_SCRIPT.debug_start_level = n
	_begin_transition()


## Debug: drop straight into a chest room (random variant) to test it.
func _start_chest_room() -> void:
	WORLD_SCRIPT.debug_start_level = 1
	WORLD_SCRIPT.debug_chest_room = true
	_begin_transition()


func _on_debug_pressed() -> void:
	if _debug_panel:
		_debug_panel.visible = true
		_debug_panel.move_to_front()


func _close_debug() -> void:
	if _debug_panel:
		_debug_panel.visible = false
	_options_button.grab_focus()


func _build_debug_panel() -> void:
	_debug_panel = Panel.new()
	_debug_panel.size = Vector2(220, 260)
	_debug_panel.position = Vector2(50, 70)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.11, 0.97)
	style.border_color = Color(0.5, 0.45, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	_debug_panel.add_theme_stylebox_override("panel", style)
	add_child(_debug_panel)

	var title := Label.new()
	title.text = "DEBUG"
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(220, 16)
	title.position = Vector2(0, 8)
	_debug_panel.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(30, 30)
	vbox.custom_minimum_size = Vector2(160, 0)
	vbox.add_theme_constant_override("separation", 4)
	_debug_panel.add_child(vbox)

	# Only the key test targets: level 1, the boss (level 3), and a chest room.
	var b1 := Button.new()
	b1.text = "Level 1  (Prison)"
	b1.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(b1)
	_apply_theme(b1)
	b1.pressed.connect(_start_at_level.bind(1))

	var b3 := Button.new()
	b3.text = "Level 3  (Boss)"
	b3.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(b3)
	_apply_theme(b3)
	b3.pressed.connect(_start_at_level.bind(3))

	var b4 := Button.new()
	b4.text = "Level 4  (Factory)"
	b4.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(b4)
	_apply_theme(b4)
	b4.pressed.connect(_start_at_level.bind(4))

	var b6 := Button.new()
	b6.text = "Level 6  (Fac Boss)"
	b6.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(b6)
	_apply_theme(b6)
	b6.pressed.connect(_start_at_level.bind(6))

	var bc := Button.new()
	bc.text = "Chest Room"
	bc.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(bc)
	_apply_theme(bc)
	bc.pressed.connect(_start_chest_room)

	var hint := Label.new()
	hint.text = "JUMP / ESC to return"
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(220, 12)
	hint.position = Vector2(0, 242)
	_debug_panel.add_child(hint)

	_debug_panel.visible = false


func _on_controls_pressed() -> void:
	if _controls_panel:
		_controls_panel.visible = true
		_controls_panel.move_to_front()


func _close_controls() -> void:
	if _controls_panel:
		_controls_panel.visible = false
	_options_button.grab_focus()


func _build_controls_panel() -> void:
	_controls_panel = Panel.new()
	_controls_panel.size = Vector2(260, 220)
	_controls_panel.position = Vector2(30, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.11, 0.97)
	style.border_color = Color(0.5, 0.45, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	_controls_panel.add_theme_stylebox_override("panel", style)
	add_child(_controls_panel)

	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(260, 16)
	title.position = Vector2(0, 8)
	_controls_panel.add_child(title)

	var body := Label.new()
	body.text = PAUSE_MENU.CONTROLS_TEXT
	body.add_theme_font_override("font", _font)
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	body.position = Vector2(16, 30)
	_controls_panel.add_child(body)

	var hint := Label.new()
	hint.text = "JUMP / ESC to return"
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(260, 12)
	hint.position = Vector2(0, 202)
	_controls_panel.add_child(hint)

	_controls_panel.visible = false


func _on_options_pressed() -> void:
	_options_panel.visible = true
	_back_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_achievements_pressed() -> void:
	if _ach_panel:
		_ach_panel.visible = true
		_ach_panel.move_to_front()


func _close_achievements() -> void:
	if _ach_panel:
		_ach_panel.visible = false
	_options_button.grab_focus()


## Build the achievements list panel (hidden until opened).
func _build_achievements_panel() -> void:
	_ach_panel = Panel.new()
	_ach_panel.size = Vector2(300, 410)
	_ach_panel.position = Vector2(10, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.11, 0.97)
	style.border_color = Color(0.5, 0.45, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	_ach_panel.add_theme_stylebox_override("panel", style)
	add_child(_ach_panel)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(300, 18)
	title.position = Vector2(0, 8)
	_ach_panel.add_child(title)

	# Lifetime stats summary
	var unlocked_count := 0
	for id: String in Achievements.ORDER:
		if Achievements.is_unlocked(id):
			unlocked_count += 1
	var stats := Label.new()
	stats.text = (
		"%d / %d unlocked\nKills %d   Deaths %d   Best %dm"
		% [
			unlocked_count,
			Achievements.ORDER.size(),
			int(Achievements.get_stat("total_kills")),
			int(Achievements.get_stat("deaths")),
			int(Achievements.get_stat("best_depth")),
		]
	)
	stats.add_theme_font_override("font", _font)
	stats.add_theme_font_size_override("font_size", 7)
	stats.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.position = Vector2(0, 24)
	stats.size = Vector2(300, 24)
	stats.custom_minimum_size = Vector2(300, 24)
	_ach_panel.add_child(stats)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 56)
	scroll.custom_minimum_size = Vector2(280, 326)
	scroll.size = Vector2(280, 326)
	_ach_panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for id: String in Achievements.ORDER:
		var data: Dictionary = Achievements.CATALOG[id]
		var got := Achievements.is_unlocked(id)
		var entry := Label.new()
		var mark := "[*] " if got else "[ ] "
		entry.text = mark + str(data["title"]) + "\n      " + str(data["desc"])
		entry.add_theme_font_override("font", _font)
		entry.add_theme_font_size_override("font_size", 7)
		entry.add_theme_color_override(
			"font_color", Color(0.95, 0.85, 0.4) if got else Color(0.45, 0.45, 0.5)
		)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.custom_minimum_size = Vector2(264, 0)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(entry)

	var hint := Label.new()
	hint.text = "JUMP / ESC to return"
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(300, 12)
	hint.position = Vector2(0, 392)
	_ach_panel.add_child(hint)

	_ach_panel.visible = false


func _on_back_pressed() -> void:
	_options_panel.visible = false
	_options_button.grab_focus()


func _on_music_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))


func _on_sfx_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))


func _apply_theme(node: Node) -> void:
	# Recursively apply cyberpunk font and flat button styles to all controls
	if node is Button:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", 10)
		node.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		node.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.3))
		node.add_theme_color_override("font_pressed_color", Color(0.9, 0.2, 0.2))
		node.add_theme_color_override("font_focus_color", Color(1, 0.9, 0.3))
		# Normal state — dark flat
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.12, 0.11, 0.15, 0.8)
		normal.border_color = Color(0.4, 0.35, 0.5, 0.6)
		normal.set_border_width_all(1)
		normal.set_content_margin_all(4)
		node.add_theme_stylebox_override("normal", normal)
		# Hover state — brighter
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.18, 0.16, 0.22, 0.9)
		hover.border_color = Color(0.9, 0.8, 0.2, 0.8)
		hover.set_border_width_all(1)
		hover.set_content_margin_all(4)
		node.add_theme_stylebox_override("hover", hover)
		# Pressed state — red tint
		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color(0.25, 0.12, 0.15, 0.9)
		pressed.border_color = Color(0.9, 0.2, 0.2, 0.8)
		pressed.set_border_width_all(1)
		pressed.set_content_margin_all(4)
		node.add_theme_stylebox_override("pressed", pressed)
		# Focus state — gold border
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0.15, 0.14, 0.19, 0.9)
		focus.border_color = Color(0.9, 0.8, 0.2, 0.5)
		focus.set_border_width_all(1)
		focus.set_content_margin_all(4)
		node.add_theme_stylebox_override("focus", focus)
	elif node is Label:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", 8)
		node.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	for child in node.get_children():
		_apply_theme(child)
