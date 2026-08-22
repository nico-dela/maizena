extends CanvasLayer

const InputPlatformRes := preload("res://scripts/ui/input_platform.gd")
const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _body: Label = $Panel/Margin/VBox/Body
@onready var _hint: Label = $Panel/Margin/VBox/Hint
@onready var _ok_btn: Button = $Panel/Margin/VBox/OkButton


func _ready() -> void:
	add_to_group("movement_tutorial")
	layer = 120
	hide()
	_ok_btn.pressed.connect(_complete)
	ViewportLayout.layout_changed.connect(_apply_layout)
	call_deferred("_maybe_show")


func _maybe_show() -> void:
	if MaizenaMeta.is_movement_tutorial_seen():
		return
	if not InputPlatformRes.is_touch_primary():
		return
	_show()


func _show() -> void:
	_apply_layout()
	show()


func is_blocking() -> bool:
	return visible


func notify_stick_used() -> void:
	if visible:
		_complete()


func _complete() -> void:
	MaizenaMeta.mark_movement_tutorial_seen()
	hide()


func _apply_layout() -> void:
	var s := ViewportLayout.effective_ui_scale()
	_title.add_theme_font_override("font", FONT)
	_body.add_theme_font_override("font", FONT)
	_hint.add_theme_font_override("font", FONT)
	_ok_btn.add_theme_font_override("font", FONT)
	_title.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(22))
	_body.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	_hint.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(14))
	_ok_btn.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))

	var layout := ViewportLayout.visible_layout_size()
	var panel_w := minf(420.0 * s, layout.x * 0.9)
	_panel.custom_minimum_size = Vector2(panel_w, 0.0)
	_panel.position = Vector2(
		(layout.x - panel_w) * 0.5,
		layout.y * 0.12
	)
