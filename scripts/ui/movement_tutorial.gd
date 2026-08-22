extends CanvasLayer

const InputPlatformRes := preload("res://scripts/ui/input_platform.gd")
const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _margin: MarginContainer = $Panel/Margin
@onready var _vbox: VBoxContainer = $Panel/Margin/VBox
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _body: Label = $Panel/Margin/VBox/Body
@onready var _hint: Label = $Panel/Margin/VBox/Hint
@onready var _ok_btn: Button = $Panel/Margin/VBox/OkButton

var _panel_style: StyleBoxFlat


func _ready() -> void:
	add_to_group("movement_tutorial")
	layer = 120
	hide()
	_panel_style = _make_panel_style()
	_panel.add_theme_stylebox_override("panel", _panel_style)
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
	call_deferred("_apply_layout")


func is_blocking() -> bool:
	return visible


func notify_stick_used() -> void:
	if visible:
		_complete()


func _complete() -> void:
	MaizenaMeta.mark_movement_tutorial_seen()
	hide()


func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.14, 0.98)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.82, 0.96, 0.82)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	return sb


func _style_ok_button(s: float) -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.2, 0.3, 0.88)
	sb_n.set_corner_radius_all(5)
	sb_n.set_border_width_all(1)
	sb_n.border_color = Color(0.42, 0.76, 0.94, 0.5)
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(0.16, 0.26, 0.38, 0.95)
	_ok_btn.add_theme_stylebox_override("normal", sb_n)
	_ok_btn.add_theme_stylebox_override("hover", sb_h)
	_ok_btn.add_theme_stylebox_override("pressed", sb_h)
	_ok_btn.add_theme_stylebox_override("focus", sb_n)
	_ok_btn.add_theme_font_override("font", FONT)
	_ok_btn.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	_ok_btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	_ok_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_ok_btn.custom_minimum_size.y = maxf(44.0, 40.0 * s)


func _apply_layout() -> void:
	if _panel == null:
		return
	ViewportLayout.refresh()
	var s := ViewportLayout.effective_ui_scale()
	var layout := ViewportLayout.visible_layout_size()
	var portrait := ViewportLayout.is_portrait

	_title.add_theme_font_override("font", FONT)
	_body.add_theme_font_override("font", FONT)
	_hint.add_theme_font_override("font", FONT)
	_title.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(22 if portrait else 20))
	_body.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(15 if portrait else 14))
	_hint.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(13 if portrait else 12))
	_title.add_theme_color_override("font_color", Color(0.45, 0.85, 0.96, 1.0))
	_body.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	_hint.add_theme_color_override("font_color", Color(0.55, 0.72, 0.86, 1.0))
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var pad := int(round((14.0 if portrait else 12.0) * s))
	_margin.add_theme_constant_override("margin_left", pad)
	_margin.add_theme_constant_override("margin_top", pad)
	_margin.add_theme_constant_override("margin_right", pad)
	_margin.add_theme_constant_override("margin_bottom", pad)
	_vbox.add_theme_constant_override("separation", int(round((14.0 if portrait else 10.0) * s)))

	if _panel_style != null:
		var style_pad := int(round((10.0 if portrait else 6.0) * s))
		_panel_style.content_margin_left = style_pad
		_panel_style.content_margin_top = style_pad
		_panel_style.content_margin_right = style_pad
		_panel_style.content_margin_bottom = style_pad

	_style_ok_button(s)

	var panel_w := minf(420.0 * s, layout.x * 0.9)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(panel_w, 0.0)
	_panel.size = Vector2(panel_w, 0.0)
	_panel.reset_size()
	var panel_h := maxf(_panel.get_combined_minimum_size().y, _panel.size.y)
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2(
		(layout.x - panel_w) * 0.5,
		layout.y * (0.10 if portrait else 0.12)
	)

	if _dim != null:
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim.color = Color(0.02, 0.04, 0.08, 0.62)
