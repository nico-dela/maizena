extends CanvasLayer

## Tarjeta a pantalla completa para escanear un QR desde un CRT por RCA.
## Payload: HTTPS://ANEZIAM.NETLIFY.APP/Q
## Versión 2 (25×25), ECC L, zona quieta de 4. El PNG mide 33 módulos.

const QR_TEXTURE: Texture2D = preload("res://assets/art/ui/crt_qr.png")
const QR_MODULES := 33
const SHORT_SIDE_FRACTION := 0.70
const MAX_SIDE_FRACTION := 0.92
const MIN_OUTPUT_MODULE := 8.0

var _open := false
var _backdrop: ColorRect
var _code: TextureRect


func _ready() -> void:
	layer = 110
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("qr_card")
	_build()
	get_viewport().size_changed.connect(_layout)
	set_process_unhandled_input(true)


func is_blocking() -> bool:
	return _open


func open_card() -> void:
	if _open:
		return
	_open = true
	visible = true
	_layout()
	_set_world_clear(true)


func close_card() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_set_world_clear(false)


func _unhandled_input(event: InputEvent) -> void:
	if _debug_toggle(event):
		return
	if not _open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		close_card()
		get_viewport().set_input_as_handled()


func _debug_toggle(event: InputEvent) -> bool:
	if not OS.is_debug_build() or not event is InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_F7:
		return false
	if _open:
		close_card()
	else:
		open_card()
	get_viewport().set_input_as_handled()
	return true


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color.WHITE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_code = TextureRect.new()
	_code.name = "Code"
	_code.texture = QR_TEXTURE
	_code.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_code.stretch_mode = TextureRect.STRETCH_SCALE
	_code.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_code)


func _layout() -> void:
	if _code == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x < 1.0 or view.y < 1.0:
		return
	var side := _side_for(view)
	_code.position = ((view - Vector2(side, side)) * 0.5).floor()
	_code.size = Vector2(side, side)


func _side_for(view: Vector2) -> float:
	var short := minf(view.x, view.y)
	var desired := short * SHORT_SIDE_FRACTION
	var min_side := _min_module_px(view) * float(QR_MODULES)
	var side := clampf(maxf(desired, min_side), float(QR_MODULES), short * MAX_SIDE_FRACTION)
	return floorf(side / float(QR_MODULES)) * float(QR_MODULES)


func _min_module_px(view: Vector2) -> float:
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h < 1.0:
		window_h = view.y
	var output_per_viewport := window_h / view.y
	return ceilf(MIN_OUTPUT_MODULE / maxf(output_per_viewport, 0.001))


func _set_world_clear(clear: bool) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("set_crt_scan_clear"):
		main.call("set_crt_scan_clear", clear)
