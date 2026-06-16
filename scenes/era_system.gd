extends Control

@onready var news_button: Button = $NewsButton

func _ready() -> void:
	_apply_platform_style()
	_style_button()
	news_button.tooltip_text = "Noticias del mundo (N)"
	news_button.pressed.connect(_on_news_pressed)

func _apply_platform_style() -> void:
	if OS.has_feature("mobile"):
		return
	if news_button:
		news_button.add_theme_font_size_override("font_size", 20)

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
