extends CanvasLayer
## In-game pause menu (Escape). Resume / Options / Audio / Exit to Menu / Quit.
## Built entirely in code; process_mode ALWAYS so it works while the tree is paused.
## Options covers accessibility (screen shake, reduced flashing, hitstop) and display
## (fullscreen, FPS). Exit-to-menu and Quit ask for confirmation.

const FONT_PATH := "res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf"

## Shared control reference, also used by the main menu.
const CONTROLS_TEXT := """KEYBOARD
Move          A / D / Arrows
Jump / Shoot  Space / W / Up
Interact      S / Down
Pause         Esc

GAMEPAD
Move          Stick / D-Pad
Jump / Shoot  A  /  RB
Interact      X
Pause         Start"""

var _font: Font
var _open := false
var _panel := "main"        # main | options | audio | controls | confirm
var _confirm_action := ""   # menu | quit

var _root: Control
var _dim: ColorRect
var _title: Label
var _main_box: VBoxContainer
var _options_box: VBoxContainer
var _audio_box: VBoxContainer
var _controls_box: VBoxContainer
var _confirm_box: VBoxContainer
var _confirm_label: Label

var _shake_btn: Button
var _flash_btn: Button
var _hitstop_btn: Button
var _fullscreen_btn: Button
var _fps_btn: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH)
	_build()
	_set_all_hidden()
	_root.visible = false


func is_open() -> bool:
	return _open


# --- Open / close / back -------------------------------------------------------

func open() -> void:
	_open = true
	get_tree().paused = true
	_root.visible = true
	_show_panel("main")


func resume() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false


func back() -> void:
	match _panel:
		"main":
			resume()
		_:
			_show_panel("main")


func _show_panel(p: String) -> void:
	_panel = p
	_set_all_hidden()
	match p:
		"main":
			_title.text = "PAUSED"
			_main_box.visible = true
			_focus_first(_main_box)
		"options":
			_title.text = "OPTIONS"
			_refresh_option_labels()
			_options_box.visible = true
			_focus_first(_options_box)
		"audio":
			_title.text = "AUDIO"
			_audio_box.visible = true
			_focus_first(_audio_box)
		"controls":
			_title.text = "CONTROLS"
			_controls_box.visible = true
			_focus_first(_controls_box)
		"confirm":
			_title.text = ""
			_confirm_box.visible = true
			_focus_first(_confirm_box)


func _set_all_hidden() -> void:
	for b: Control in [_main_box, _options_box, _audio_box, _controls_box, _confirm_box]:
		if b:
			b.visible = false


func _focus_first(box: Control) -> void:
	for c in box.get_children():
		if c is Button:
			# Deferred: grabbing focus the same frame a control becomes visible can
			# fail, which breaks keyboard/gamepad navigation of the pause menu.
			(c as Button).call_deferred("grab_focus")
			return


# --- Build UI ------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_title = Label.new()
	_title.text = "PAUSED"
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(320, 24)
	_title.position = Vector2(0, 70)
	_root.add_child(_title)

	_build_main()
	_build_options()
	_build_audio()
	_build_controls()
	_build_confirm()


func _box() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(200, 0)
	v.position = Vector2(60, 120)
	v.size = Vector2(200, 0)
	_root.add_child(v)
	return v


func _build_main() -> void:
	_main_box = _box()
	var resume_b := _mk_btn("Resume")
	resume_b.pressed.connect(resume)
	_main_box.add_child(resume_b)
	var opt_b := _mk_btn("Options")
	opt_b.pressed.connect(_show_panel.bind("options"))
	_main_box.add_child(opt_b)
	var aud_b := _mk_btn("Audio")
	aud_b.pressed.connect(_show_panel.bind("audio"))
	_main_box.add_child(aud_b)
	var ctrl_b := _mk_btn("Controls")
	ctrl_b.pressed.connect(_show_panel.bind("controls"))
	_main_box.add_child(ctrl_b)
	var menu_b := _mk_btn("Exit to Menu")
	menu_b.pressed.connect(_ask_confirm.bind("menu"))
	_main_box.add_child(menu_b)
	var quit_b := _mk_btn("Quit Game")
	quit_b.pressed.connect(_ask_confirm.bind("quit"))
	_main_box.add_child(quit_b)


func _build_options() -> void:
	_options_box = _box()
	_add_header(_options_box, "Accessibility")
	_shake_btn = _mk_btn("")
	_shake_btn.pressed.connect(_on_shake)
	_options_box.add_child(_shake_btn)
	_flash_btn = _mk_btn("")
	_flash_btn.pressed.connect(_on_flash)
	_options_box.add_child(_flash_btn)
	_hitstop_btn = _mk_btn("")
	_hitstop_btn.pressed.connect(_on_hitstop)
	_options_box.add_child(_hitstop_btn)
	_add_header(_options_box, "Display")
	_fullscreen_btn = _mk_btn("")
	_fullscreen_btn.pressed.connect(_on_fullscreen)
	_options_box.add_child(_fullscreen_btn)
	_fps_btn = _mk_btn("")
	_fps_btn.pressed.connect(_on_fps)
	_options_box.add_child(_fps_btn)
	var back_b := _mk_btn("Back")
	back_b.pressed.connect(_show_panel.bind("main"))
	_options_box.add_child(back_b)


func _build_audio() -> void:
	_audio_box = _box()
	_add_header(_audio_box, "Music")
	var music := _mk_slider("Music")
	_audio_box.add_child(music)
	_add_header(_audio_box, "SFX")
	var sfx := _mk_slider("SFX")
	_audio_box.add_child(sfx)
	var back_b := _mk_btn("Back")
	back_b.pressed.connect(_show_panel.bind("main"))
	_audio_box.add_child(back_b)


func _build_controls() -> void:
	_controls_box = _box()
	var l := Label.new()
	l.text = CONTROLS_TEXT
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	l.custom_minimum_size = Vector2(200, 0)
	_controls_box.add_child(l)
	var back_b := _mk_btn("Back")
	back_b.pressed.connect(_show_panel.bind("main"))
	_controls_box.add_child(back_b)


func _build_confirm() -> void:
	_confirm_box = _box()
	_confirm_label = Label.new()
	_confirm_label.text = "Are you sure?"
	_confirm_label.add_theme_font_override("font", _font)
	_confirm_label.add_theme_font_size_override("font_size", 10)
	_confirm_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85))
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.custom_minimum_size = Vector2(200, 30)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_box.add_child(_confirm_label)
	var yes_b := _mk_btn("Yes")
	yes_b.pressed.connect(_on_confirm_yes)
	_confirm_box.add_child(yes_b)
	var no_b := _mk_btn("No")
	no_b.pressed.connect(_show_panel.bind("main"))
	_confirm_box.add_child(no_b)


# --- Option handlers -----------------------------------------------------------

func _refresh_option_labels() -> void:
	_shake_btn.text = "Screen Shake: " + Settings.screen_shake_label()
	_flash_btn.text = "Reduce Flashing: " + ("On" if Settings.reduce_flashing else "Off")
	_hitstop_btn.text = "Hit Stop: " + ("On" if Settings.hitstop_enabled else "Off")
	_fullscreen_btn.text = "Fullscreen: " + ("On" if Settings.fullscreen else "Off")
	_fps_btn.text = "Show FPS: " + ("On" if Settings.show_fps else "Off")


func _on_shake() -> void:
	Settings.cycle_screen_shake()
	_refresh_option_labels()


func _on_flash() -> void:
	Settings.reduce_flashing = not Settings.reduce_flashing
	Settings.save_settings()
	_refresh_option_labels()


func _on_hitstop() -> void:
	Settings.hitstop_enabled = not Settings.hitstop_enabled
	Settings.save_settings()
	_refresh_option_labels()


func _on_fullscreen() -> void:
	Settings.set_fullscreen(not Settings.fullscreen)
	_refresh_option_labels()


func _on_fps() -> void:
	Settings.show_fps = not Settings.show_fps
	Settings.save_settings()
	_refresh_option_labels()


# --- Confirm (exit / quit) -----------------------------------------------------

func _ask_confirm(action: String) -> void:
	_confirm_action = action
	_confirm_label.text = "Return to the main menu?" if action == "menu" else "Quit the game?"
	_show_panel("confirm")


func _on_confirm_yes() -> void:
	if _confirm_action == "menu":
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
	elif _confirm_action == "quit":
		get_tree().quit()


# --- Widgets -------------------------------------------------------------------

func _add_header(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(0.55, 0.8, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(200, 10)
	box.add_child(l)


func _mk_slider(bus_name: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(200, 18)
	s.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name)))
	s.value_changed.connect(func(v: float) -> void:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(maxf(v, 0.0001)))
		Settings.save_settings()
	)
	return s


func _mk_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 20)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.3))
	b.add_theme_color_override("font_focus_color", Color(1, 0.9, 0.3))
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.2, 0.2))
	b.add_theme_stylebox_override("normal", _sb(Color(0.12, 0.11, 0.15, 0.85), Color(0.4, 0.35, 0.5, 0.6)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.18, 0.16, 0.22, 0.92), Color(0.9, 0.8, 0.2, 0.8)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.25, 0.12, 0.15, 0.92), Color(0.9, 0.2, 0.2, 0.8)))
	b.add_theme_stylebox_override("focus", _sb(Color(0.15, 0.14, 0.19, 0.9), Color(0.9, 0.8, 0.2, 0.6)))
	return b


func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(4)
	return s
