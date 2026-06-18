extends Node

signal layout_changed

const COMFORTABLE_WIDTH := 820.0
const UI_LERP := 0.82
const MAX_UI_SCALE := 2.8
const MAX_CAMERA_BOOST := 2.0
const PORTRAIT_UI_EXTRA := 1.18

var ui_scale := 1.0
var camera_boost := 1.0
var is_portrait := false
var visible_layout := Vector2(1152.0, 648.0)

var _connected := false


func _ready() -> void:
	call_deferred("refresh")
	call_deferred("_connect_root")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		refresh()


func refresh() -> void:
	_recalculate()


func _connect_root() -> void:
	if _connected:
		return
	var root := get_tree().root
	if root == null:
		return
	if not root.size_changed.is_connected(_on_viewport_size_changed):
		root.size_changed.connect(_on_viewport_size_changed)
	_connected = true
	refresh()


func _on_viewport_size_changed() -> void:
	_recalculate()


func effective_ui_scale() -> float:
	var s := ui_scale
	if is_portrait:
		s *= PORTRAIT_UI_EXTRA
	return s


func scaled_font(base: int) -> int:
	return maxi(1, int(round(float(base) * effective_ui_scale())))


func visible_layout_size() -> Vector2:
	return visible_layout


func _stretch_scale(design: Vector2, window: Vector2i) -> float:
	var aspect := int(ProjectSettings.get_setting("display/window/stretch/aspect", 1))
	match aspect:
		0:
			return maxf(float(window.x) / design.x, float(window.y) / design.y)
		1, 2, 3:
			return minf(float(window.x) / design.x, float(window.y) / design.y)
		_:
			return maxf(float(window.x) / design.x, float(window.y) / design.y)


func _recalculate() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var design := vp.get_visible_rect().size
	if design.x < 1.0 or design.y < 1.0:
		return

	var window := DisplayServer.window_get_size()
	if window.x < 1 or window.y < 1:
		window = Vector2i(int(design.x), int(design.y))

	var stretch := maxf(_stretch_scale(design, window), 0.001)
	var aspect := int(ProjectSettings.get_setting("display/window/stretch/aspect", 1))
	var visible := design
	if aspect == 4:
		visible = Vector2(float(window.x) / stretch, float(window.y) / stretch)

	var new_portrait := window.y > window.x
	var layout_metric := minf(visible.x, visible.y) if new_portrait else visible.x
	var narrow := layout_metric < COMFORTABLE_WIDTH
	var ratio := COMFORTABLE_WIDTH / maxf(layout_metric, 1.0) if narrow else 1.0

	var new_ui_scale := clampf(lerpf(1.0, ratio, UI_LERP), 1.0, MAX_UI_SCALE)
	var new_camera_boost := clampf(lerpf(1.0, ratio, 0.52), 1.0, MAX_CAMERA_BOOST)

	if new_portrait and aspect in [1, 2, 3]:
		var letterbox_boost := clampf(1.0 / stretch, 1.0, MAX_UI_SCALE)
		new_ui_scale = maxf(new_ui_scale, letterbox_boost * 0.88)
		new_camera_boost = maxf(new_camera_boost, clampf(letterbox_boost * 0.55, 1.0, MAX_CAMERA_BOOST))

	if (
		is_equal_approx(new_ui_scale, ui_scale)
		and is_equal_approx(new_camera_boost, camera_boost)
		and new_portrait == is_portrait
		and visible.is_equal_approx(visible_layout)
	):
		return

	ui_scale = new_ui_scale
	camera_boost = new_camera_boost
	is_portrait = new_portrait
	visible_layout = visible
	layout_changed.emit()
