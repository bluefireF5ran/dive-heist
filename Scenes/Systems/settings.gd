extends Node
## Global settings singleton (autoload "Settings").
## Accessibility + display options, persisted to user://settings.cfg.

const PATH := "user://settings.cfg"

# --- Accessibility ---
var screen_shake_scale := 1.0   # 1.0 = Full, 0.5 = Reduced, 0.0 = Off
var reduce_flashing := false    # Dampen full-screen flashes (boss intro, rainbow score)
var hitstop_enabled := true     # Tiny freeze-frames on big hits

# --- Display / other ---
var fullscreen := false
var show_fps := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_apply_window()
	_setup_gamepad()


## Add controller bindings at runtime so a gamepad works without editing the saved
## InputMap. UI navigation (ui_accept/ui_left/…) already includes joypad defaults.
func _setup_gamepad() -> void:
	_bind_button("jump", JOY_BUTTON_A)          # A = jump / shoot
	_bind_button("jump", JOY_BUTTON_RIGHT_SHOULDER)
	_bind_button("interact", JOY_BUTTON_X)      # X = interact / enter door
	_bind_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_bind_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_button("ui_cancel", JOY_BUTTON_START) # Start = pause / back


func _bind_button(action: String, btn: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == btn:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)


func _bind_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and e.axis == axis and signf(e.axis_value) == signf(value):
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	screen_shake_scale = float(cfg.get_value("accessibility", "screen_shake_scale", screen_shake_scale))
	reduce_flashing = bool(cfg.get_value("accessibility", "reduce_flashing", reduce_flashing))
	hitstop_enabled = bool(cfg.get_value("accessibility", "hitstop_enabled", hitstop_enabled))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	show_fps = bool(cfg.get_value("display", "show_fps", show_fps))
	var mv := float(cfg.get_value("audio", "music", -1.0))
	var sv := float(cfg.get_value("audio", "sfx", -1.0))
	if mv >= 0.0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(mv, 0.0001)))
	if sv >= 0.0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sv, 0.0001)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("accessibility", "screen_shake_scale", screen_shake_scale)
	cfg.set_value("accessibility", "reduce_flashing", reduce_flashing)
	cfg.set_value("accessibility", "hitstop_enabled", hitstop_enabled)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("audio", "music", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))))
	cfg.set_value("audio", "sfx", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))))
	cfg.save(PATH)


func _apply_window() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func set_fullscreen(v: bool) -> void:
	fullscreen = v
	_apply_window()
	save_settings()


## Cycle screen shake Full -> Reduced -> Off -> Full and return a label.
func cycle_screen_shake() -> String:
	if screen_shake_scale >= 1.0:
		screen_shake_scale = 0.5
	elif screen_shake_scale >= 0.5:
		screen_shake_scale = 0.0
	else:
		screen_shake_scale = 1.0
	save_settings()
	return screen_shake_label()


func screen_shake_label() -> String:
	if screen_shake_scale >= 1.0:
		return "Full"
	elif screen_shake_scale >= 0.5:
		return "Reduced"
	return "Off"
