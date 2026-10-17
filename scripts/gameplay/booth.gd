extends RefCounted

## Windows fest build (export feature "booth"). Web never sees this.

const HEADPHONE_DB := -8.0
const STICK_DEADZONE := 0.28
const BOOTH_HOUR := 21.5


static func active() -> bool:
	return OS.has_feature("booth")


static func apply_display() -> void:
	if not active():
		return
	Engine.max_fps = 60
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Input.emulate_touch_from_mouse = false
	ProjectSettings.set_setting("display/window/stretch/aspect", 1)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


static func configure_pad() -> void:
	if not active():
		return
	_remove_joy_button("ui_cancel", JOY_BUTTON_LEFT_SHOULDER)
	_remove_joy_button("ui_world_news", JOY_BUTTON_LEFT_SHOULDER)
	_ensure_joy_button("ui_cancel", JOY_BUTTON_B)
	for action_name in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		InputMap.action_set_deadzone(action_name, STICK_DEADZONE)


static func apply_headphone_mix() -> void:
	if not active():
		return
	_set_master_db(HEADPHONE_DB)


static func _set_master_db(db: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, db)


static func _remove_joy_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			InputMap.action_erase_event(action, event)


static func _ensure_joy_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
