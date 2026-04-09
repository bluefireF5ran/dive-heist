extends Control

## Main menu — title screen with Start / Options / Quit.
## Title and decorations drawn via _draw(); buttons/sliders are Control nodes.

const WORLD_SCENE := "res://Scenes/Levels/world.tscn"
const FONT_PATH := "res://Sprites/Scraper/Cyberpunk_Assets/Game_UI/UI_Main/10 Font/CyberpunkCraftpixPixel.otf"

var _font: Font
var _transitioning := false
var _time := 0.0

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
	_time += delta
	# Fade in from black on boot
	if _fade_rect.color.a > 0.0 and not _transitioning:
		_fade_rect.color.a = maxf(_fade_rect.color.a - delta * 2.0, 0.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if _options_panel.visible:
		if event.is_action_pressed("jump"):
			_on_back_pressed()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var cx := vp.x / 2.0

	# Subtle horizontal scan lines for atmosphere
	for y in range(0, int(vp.y), 4):
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color(1, 1, 1, 0.015))

	# Title: "DIVE HEIST" with glow + shadow
	var title := "DIVE HEIST"
	var title_font_size := 22
	var ts := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size)
	var tx := (vp.x - ts.x) / 2.0
	var ty := 100.0

	# Pulsing glow behind title
	var glow_a := 0.12 + 0.06 * sin(_time * 2.0)
	draw_string(_font, Vector2(tx - 1, ty - 1), title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size, Color(0.9, 0.2, 0.9, glow_a))
	draw_string(_font, Vector2(tx + 1, ty + 1), title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size, Color(0.9, 0.2, 0.9, glow_a))
	# Drop shadow
	draw_string(_font, Vector2(tx + 1, ty + 1), title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size, Color(0, 0, 0, 0.6))
	# Main title text — gold
	draw_string(_font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size, Color(0.95, 0.9, 0.3, 1.0))

	# Subtitle
	var sub := "A VERTICAL ROGUELIKE"
	var sub_size := 6
	var ss := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size)
	var sx := (vp.x - ss.x) / 2.0
	draw_string(_font, Vector2(sx, ty + 16), sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size, Color(0.5, 0.5, 0.6, 0.7))

	# Decorative line under title
	var line_y := ty + 24.0
	draw_line(Vector2(cx - 60, line_y), Vector2(cx + 60, line_y), Color(0.9, 0.8, 0.2, 0.3), 1.0)

	# Version text at bottom
	var ver := "v0.2"
	var vs := _font.get_string_size(ver, HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	draw_string(_font, Vector2((vp.x - vs.x) / 2.0, vp.y - 8), ver, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, Color(0.4, 0.4, 0.4, 0.5))


func _on_start_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(WORLD_SCENE)
	)


func _on_options_pressed() -> void:
	_options_panel.visible = true
	_back_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


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
