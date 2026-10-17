extends CanvasLayer

## Pad volume, headphone level, and idle handoff. Only added on the booth export.

const Booth = preload("res://scripts/gameplay/booth.gd")
const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

const IDLE_LIMIT_SEC := 180.0
const OSD_SEC := 1.0

var _idle_sec := 0.0
var _osd_left := 0.0
var _reloading := false
var _label: Label


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	Booth.configure_pad()
	Booth.apply_headphone_mix()
	GameState.evento_todos_presentes = true
	_build_label()


func _build_label() -> void:
	_label = Label.new()
	_label.visible = false
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	add_child(_label)
	_place_label()


func _place_label() -> void:
	if _label == null:
		return
	var layout := ViewportLayout.visible_layout_size()
	var top := ViewportLayout.screen_margin_top(28.0)
	_label.position = Vector2(layout.x * 0.5 - 180.0, top)
	_label.size = Vector2(360.0, 48.0)


func _process(delta: float) -> void:
	_idle_sec += delta
	if _idle_sec >= IDLE_LIMIT_SEC:
		_reload_session()
		return
	if _osd_left <= 0.0:
		return
	_osd_left -= delta
	if _osd_left <= 0.0 and _label != null:
		_label.visible = false


func _input(event: InputEvent) -> void:
	_note_activity(event)
	if not (event is InputEventJoypadButton):
		return
	var button := event as InputEventJoypadButton
	if not button.pressed:
		return
	if button.button_index == JOY_BUTTON_LEFT_SHOULDER:
		_show_volume(Booth.nudge_volume(-Booth.VOLUME_STEP_DB))
		get_viewport().set_input_as_handled()
	elif button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		_show_volume(Booth.nudge_volume(Booth.VOLUME_STEP_DB))
		get_viewport().set_input_as_handled()


func _note_activity(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= Booth.STICK_DEADZONE:
			_idle_sec = 0.0
		return
	if event is InputEventJoypadButton and event.pressed:
		_idle_sec = 0.0
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_idle_sec = 0.0


func _show_volume(db: float) -> void:
	if _label == null:
		return
	_place_label()
	_label.text = "Volumen %d%%" % Booth.volume_percent(db)
	_label.visible = true
	_osd_left = OSD_SEC


func _reload_session() -> void:
	if _reloading:
		return
	_reloading = true
	_idle_sec = 0.0
	GameState.reset_session()
	DialogueController.input_locked = false
	get_tree().paused = false
	get_tree().reload_current_scene()
