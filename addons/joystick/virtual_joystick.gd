class_name VirtualJoystick
extends Control

## A simple virtual joystick for touchscreens with customizable options.
@export var pressed_color := Color.GRAY
@export_range(0, 200, 1) var deadzone_size: float = 10
@export_range(0, 500, 1) var clampzone_size: float = 75

enum JoystickMode { FIXED, DYNAMIC }
@export var joystick_mode := JoystickMode.FIXED

enum VisibilityMode { ALWAYS, TOUCHSCREEN_ONLY }
@export var visibility_mode := VisibilityMode.ALWAYS

@export var use_input_actions := true
@export var action_left := "ui_left"
@export var action_right := "ui_right"
@export var action_up := "ui_up"
@export var action_down := "ui_down"

var is_pressed := false
var output := Vector2.ZERO
var _touch_index: int = -1

@onready var _base := $Base
@onready var _tip := $Base/Tip
@onready var _base_radius = _base.size * _base.get_global_transform_with_canvas().get_scale() / 2
@onready var _default_base_pos: Vector2 = _base.position
@onready var _default_tip_pos: Vector2 = _tip.position
@onready var _default_color: Color = _tip.modulate

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available() and visibility_mode == VisibilityMode.TOUCHSCREEN_ONLY:
		hide()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _is_touch_on_joystick(event.position):
		if joystick_mode == JoystickMode.DYNAMIC:
			_set_base_position(event.position)
		_touch_index = event.index
		_tip.modulate = pressed_color
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()
	elif event.index == _touch_index:
		_reset_joystick()
		get_viewport().set_input_as_handled()

func _is_touch_on_joystick(point: Vector2) -> bool:
	return _is_point_in_rect(point, global_position, size * get_global_transform_with_canvas().get_scale())

func _is_point_in_rect(point: Vector2, pos: Vector2, size: Vector2) -> bool:
	return point.x >= pos.x and point.x <= pos.x + size.x and point.y >= pos.y and point.y <= pos.y + size.y

func _set_base_position(new_position: Vector2) -> void:
	_base.global_position = new_position - _base.pivot_offset * get_global_transform_with_canvas().get_scale()

func _update_joystick(touch_position: Vector2) -> void:
	var center = _base.global_position + _base_radius
	var vector = (touch_position - center).limit_length(clampzone_size)
	_move_tip(center + vector)

	if vector.length_squared() > deadzone_size * deadzone_size:
		is_pressed = true
		output = (vector - vector.normalized() * deadzone_size) / (clampzone_size - deadzone_size)
	else:
		is_pressed = false
		output = Vector2.ZERO

	_update_input_actions()

func _move_tip(new_position: Vector2) -> void:
	_tip.global_position = new_position - _tip.pivot_offset * _base.get_global_transform_with_canvas().get_scale()

func _update_input_actions() -> void:
	if use_input_actions:
		_set_input_action(action_right, output.x > 0, output.x)
		_set_input_action(action_left, output.x < 0, -output.x)
		_set_input_action(action_down, output.y > 0, output.y)
		_set_input_action(action_up, output.y < 0, -output.y)

func _set_input_action(action: String, condition: bool, value: float) -> void:
	if condition and value > InputMap.action_get_deadzone(action):
		Input.action_press(action, value)
	elif Input.is_action_pressed(action):
		Input.action_release(action)

func _reset_joystick() -> void:
	is_pressed = false
	output = Vector2.ZERO
	_touch_index = -1
	_tip.modulate = _default_color
	_base.position = _default_base_pos
	_tip.position = _default_tip_pos
	if use_input_actions:
		for action in [action_left, action_right, action_down, action_up]:
			if Input.is_action_pressed(action):
				Input.action_release(action)
