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


func _recalculate() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var size := vp.get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		return

	var narrow := size.x < COMFORTABLE_WIDTH
	var ratio := COMFORTABLE_WIDTH / maxf(size.x, 1.0) if narrow else 1.0

	var new_ui_scale := clampf(lerpf(1.0, ratio, UI_LERP), 1.0, MAX_UI_SCALE)
	var new_camera_boost := clampf(lerpf(1.0, ratio, 0.52), 1.0, MAX_CAMERA_BOOST)
	var new_portrait := size.y > size.x

	if (
		is_equal_approx(new_ui_scale, ui_scale)
		and is_equal_approx(new_camera_boost, camera_boost)
		and new_portrait == is_portrait
	):
		return

	ui_scale = new_ui_scale
	camera_boost = new_camera_boost
	is_portrait = new_portrait
	layout_changed.emit()
