extends Control

const BASE_FONT_SIZE := 24
const BASE_BUTTON_SIZE := Vector2(240, 36)
const SCREEN_MARGIN := 20.0

@onready var news_button: Button = $NewsButton


func _ready() -> void:
	_style_button()
	_apply_layout()
	news_button.tooltip_text = "Noticias del mundo (N)"
	news_button.pressed.connect(_on_news_pressed)
	ViewportLayout.layout_changed.connect(_apply_layout)
	call_deferred("_apply_layout")


func _apply_layout() -> void:
	var s := ViewportLayout.effective_ui_scale()
	news_button.text = "Noticias"
	news_button.icon = null
	news_button.expand_icon = false
	news_button.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(BASE_FONT_SIZE))

	var btn_w := maxf(BASE_BUTTON_SIZE.x * s, 160.0 * s)
	var btn_h := maxf(BASE_BUTTON_SIZE.y * s, 44.0)
	var btn_size := Vector2(btn_w, btn_h)
	news_button.custom_minimum_size = btn_size
	news_button.size = btn_size

	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = SCREEN_MARGIN
	offset_top = SCREEN_MARGIN
	offset_right = SCREEN_MARGIN + btn_size.x
	offset_bottom = SCREEN_MARGIN + btn_size.y


func _style_button() -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.08, 0.12, 0.18, 0.88)
	sb_n.set_corner_radius_all(6)
	sb_n.set_border_width_all(2)
	sb_n.border_color = Color(0.38, 0.78, 0.96, 0.85)
	sb_n.content_margin_left = 10
	sb_n.content_margin_top = 6
	sb_n.content_margin_right = 10
	sb_n.content_margin_bottom = 6
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(0.12, 0.2, 0.3, 0.95)
	sb_h.border_color = Color(0.55, 0.92, 1.0, 1.0)
	news_button.add_theme_stylebox_override("normal", sb_n)
	news_button.add_theme_stylebox_override("hover", sb_h)
	news_button.add_theme_stylebox_override("pressed", sb_h)
	news_button.add_theme_stylebox_override("focus", sb_h)
	news_button.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	news_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))


func _on_news_pressed() -> void:
	var wp := get_tree().get_first_node_in_group("welcome_popup")
	if wp != null and wp.has_method("open_from_button"):
		wp.call("open_from_button")
