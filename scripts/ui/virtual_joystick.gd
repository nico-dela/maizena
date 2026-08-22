extends Control
## Fixed virtual stick for mobile / touch web. Hidden on desktop without touch.

const InputPlatformRes := preload("res://scripts/ui/input_platform.gd")
const PlayerSettingsRes := preload("res://scripts/ui/player_settings.gd")

const DEADZONE := 0.18
const BASE_DIAMETER := 128.0
const KNOB_RATIO := 0.42
const SCREEN_MARGIN_LEFT := 48.0
const SCREEN_MARGIN_BOTTOM := 64.0
const THUMB_INSET_RATIO := 0.04
const GB_RING := Color(0.545, 0.584, 0.427, 0.92)
const GB_RING_BORDER := Color(0.188, 0.384, 0.188, 1.0)
const GB_KNOB := Color(0.608, 0.737, 0.059, 0.92)
const GB_KNOB_BORDER := Color(0.059, 0.220, 0.059, 1.0)

var _pointer_id := -1
var _value := Vector2.ZERO
var _is_touch := false
var _joystick_scale := 1.0

@onready var _ring: Panel = $Ring
@onready var _knob: Panel = $Ring/Knob


func _ready() -> void:
	add_to_group("virtual_joystick")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_touch = InputPlatformRes.is_touch_primary()
	visible = false
	_style_parts()
	_ring.gui_input.connect(_on_ring_gui_input)
	ViewportLayout.layout_changed.connect(_apply_layout)
	_apply_layout()
	_reset_knob()


func get_vector() -> Vector2:
	if not visible:
		return Vector2.ZERO
	return _value


func refresh_layout() -> void:
	_apply_layout()


func _process(_delta: float) -> void:
	var show_stick := _should_show()
	if visible != show_stick:
		visible = show_stick
		if not show_stick:
			_release_pointer()


func _should_show() -> bool:
	if not _is_touch:
		return false
	if DialogueController.input_locked:
		return false
	if GameState.bollo_training_active:
		return false
	var settings := get_tree().get_first_node_in_group("settings_menu")
	if settings != null and bool(settings.get("is_open")):
		return false
	var welcome := get_tree().get_first_node_in_group("welcome_popup")
	if welcome != null and welcome.has_method("is_blocking") and welcome.call("is_blocking"):
		return false
	var tutorial := get_tree().get_first_node_in_group("movement_tutorial")
	if tutorial != null and tutorial.has_method("is_blocking") and tutorial.call("is_blocking"):
		return true
	return true


func _apply_layout() -> void:
	ViewportLayout.refresh()
	var s := ViewportLayout.effective_ui_scale()
	var layout := ViewportLayout.visible_layout_size()
	_joystick_scale = float(
		PlayerSettingsRes.load_all().get("joystick_scale", PlayerSettingsRes.DEFAULT_JOYSTICK_SCALE)
	)
	var diameter := clampf(BASE_DIAMETER * s * _joystick_scale, 80.0, 220.0)
	var margin_left := ViewportLayout.screen_margin_left(SCREEN_MARGIN_LEFT)
	var margin_bottom := ViewportLayout.screen_margin_bottom(SCREEN_MARGIN_BOTTOM)
	margin_left += layout.x * THUMB_INSET_RATIO

	_ring.size = Vector2(diameter, diameter)
	_ring.position = Vector2(margin_left, layout.y - margin_bottom - diameter)

	var knob_size := diameter * KNOB_RATIO
	_knob.custom_minimum_size = Vector2(knob_size, knob_size)
	_knob.size = Vector2(knob_size, knob_size)
	_style_parts()
	_reset_knob()


func _style_parts() -> void:
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = GB_RING
	ring_style.border_color = GB_RING_BORDER
	ring_style.set_border_width_all(3)
	var corner := int(_ring.size.x * 0.22)
	ring_style.set_corner_radius_all(corner)
	_ring.add_theme_stylebox_override("panel", ring_style)

	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = GB_KNOB
	knob_style.border_color = GB_KNOB_BORDER
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(int(_knob.size.x * 0.22))
	_knob.add_theme_stylebox_override("panel", knob_style)


func _on_ring_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _pointer_id == 0:
		_update_from_local(event.position)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _pointer_id < 0:
		_unlock_audio()
		_pointer_id = event.index
		_update_from_local(event.position)
	elif not event.pressed and event.index == _pointer_id:
		_release_pointer()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _pointer_id:
		_update_from_local(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and _pointer_id < 0:
		_unlock_audio()
		_pointer_id = 0
		_update_from_local(event.position)
	elif not event.pressed and _pointer_id == 0:
		_release_pointer()


func _update_from_local(local_pos: Vector2) -> void:
	var center := _ring.size * 0.5
	var max_len := center.x - _knob.size.x * 0.5
	if max_len <= 1.0:
		return
	var delta := local_pos - center
	var vec := delta / max_len
	if vec.length() > 1.0:
		vec = vec.normalized()
	if vec.length() < DEADZONE:
		_value = Vector2.ZERO
	else:
		_value = vec
	_knob.position = center + _value * max_len - _knob.size * 0.5
	_notify_tutorial_input(_value)
	accept_event()


func _notify_tutorial_input(vec: Vector2) -> void:
	if vec.length() < DEADZONE:
		return
	var tutorial := get_tree().get_first_node_in_group("movement_tutorial")
	if tutorial != null and tutorial.has_method("notify_stick_used"):
		tutorial.notify_stick_used()


func _unlock_audio() -> void:
	var music := get_tree().get_first_node_in_group("music_manager")
	if music != null and music.has_method("unlock_and_play"):
		music.unlock_and_play()


func _release_pointer() -> void:
	_pointer_id = -1
	_value = Vector2.ZERO
	_reset_knob()


func _reset_knob() -> void:
	if _ring == null or _knob == null:
		return
	_knob.position = (_ring.size - _knob.size) * 0.5
