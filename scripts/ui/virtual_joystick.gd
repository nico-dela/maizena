extends Control
## Fixed virtual stick for mobile. Hidden on desktop even if touch is emulated.

const DEADZONE := 0.18
const BASE_DIAMETER := 128.0
const KNOB_RATIO := 0.42
const SCREEN_MARGIN := 18.0
const NAVY := Color(0.04, 0.06, 0.14, 0.78)
const CYAN := Color(0.35, 0.82, 0.96, 0.9)

var _pointer_id := -1
var _value := Vector2.ZERO
var _is_mobile := false

@onready var _ring: Panel = $Ring
@onready var _knob: Panel = $Ring/Knob


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_mobile = OS.has_feature("mobile")
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


func _process(_delta: float) -> void:
	var show_stick := _should_show()
	if visible != show_stick:
		visible = show_stick
		if not show_stick:
			_release_pointer()


func _should_show() -> bool:
	if not _is_mobile:
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
	return true


func _apply_layout() -> void:
	ViewportLayout.refresh()
	var s := ViewportLayout.effective_ui_scale()
	var layout := ViewportLayout.visible_layout_size()
	var diameter := clampf(BASE_DIAMETER * s, 96.0, 168.0)
	var margin_left := ViewportLayout.screen_margin_left(SCREEN_MARGIN)
	var margin_bottom := ViewportLayout.screen_margin_bottom(SCREEN_MARGIN)

	_ring.size = Vector2(diameter, diameter)
	_ring.position = Vector2(margin_left, layout.y - margin_bottom - diameter)

	var knob_size := diameter * KNOB_RATIO
	_knob.custom_minimum_size = Vector2(knob_size, knob_size)
	_knob.size = Vector2(knob_size, knob_size)
	_style_parts()
	_reset_knob()


func _style_parts() -> void:
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = NAVY
	ring_style.border_color = CYAN
	ring_style.set_border_width_all(2)
	ring_style.set_corner_radius_all(int(_ring.size.x * 0.5))
	_ring.add_theme_stylebox_override("panel", ring_style)

	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.35, 0.82, 0.96, 0.82)
	knob_style.border_color = Color(0.85, 0.95, 1.0, 0.95)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(int(_knob.size.x * 0.5))
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
		_pointer_id = event.index
		_update_from_local(event.position)
	elif not event.pressed and event.index == _pointer_id:
		_release_pointer()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _pointer_id:
		_update_from_local(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and _pointer_id < 0:
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
	accept_event()


func _release_pointer() -> void:
	_pointer_id = -1
	_value = Vector2.ZERO
	_reset_knob()


func _reset_knob() -> void:
	if _ring == null or _knob == null:
		return
	_knob.position = (_ring.size - _knob.size) * 0.5
