extends CanvasLayer

@onready var menu_panel: Control = $Menu
@onready var settings_button: Button = $Button
@onready var volume_slider: HSlider = $Menu/MarginContainer/VBoxContainer/Volume/VolumeHSlider
@onready var welcome_info_button: Button = $Menu/MarginContainer/VBoxContainer/WelcomeInfo

@export var icon_open: Texture2D
@export var icon_close: Texture2D
var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_menu")
	
	menu_panel.hide()

	settings_button.toggle_mode = true
	settings_button.button_pressed = false
	settings_button.icon = icon_open
	settings_button.toggled.connect(_on_settings_toggled)

	settings_button.mouse_entered.connect(_on_button_hover_enter)
	settings_button.mouse_exited.connect(_on_button_hover_exit)

	_remove_button_style(settings_button)
	_apply_settings_button_layout()

	volume_slider.min_value = -40
	volume_slider.max_value = 0
	volume_slider.step = 1
	volume_slider.value = 0
	volume_slider.value_changed.connect(_on_volume_changed)

	_on_volume_changed(volume_slider.value)

	welcome_info_button.pressed.connect(_on_welcome_info_pressed)
	_style_welcome_info_button(welcome_info_button)

func _apply_settings_button_layout() -> void:
	if icon_open == null or icon_close == null:
		return
	# Sin `scale`: el rect del botón ya incluye el icono grande y no se recorta en el borde.
	settings_button.scale = Vector2.ONE
	settings_button.expand_icon = true
	settings_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mult := 4.0 if OS.has_feature("mobile") else 2.6
	var src_w := maxf(float(icon_open.get_width()), float(icon_close.get_width()))
	var src_h := maxf(float(icon_open.get_height()), float(icon_close.get_height()))
	var iw := maxi(1, int(round(src_w * mult)))
	var ih := maxi(1, int(round(src_h * mult)))
	const SCREEN_MARGIN := 20.0
	settings_button.custom_minimum_size = Vector2(iw, ih)
	settings_button.anchor_left = 1.0
	settings_button.anchor_right = 1.0
	settings_button.anchor_top = 0.0
	settings_button.anchor_bottom = 0.0
	settings_button.offset_top = 0.0
	settings_button.offset_bottom = float(ih)
	settings_button.offset_left = -SCREEN_MARGIN - float(iw)
	settings_button.offset_right = -SCREEN_MARGIN


func _on_settings_toggled(pressed: bool) -> void:
	if pressed:
		_open_menu()
	else:
		_close_menu()


func _open_menu() -> void:
	menu_panel.show()
	get_tree().paused = true
	settings_button.icon = icon_close
	is_open = true


func _close_menu() -> void:
	menu_panel.hide()
	get_tree().paused = false
	settings_button.icon = icon_open
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		settings_button.button_pressed = not settings_button.button_pressed
		return

	if menu_panel.visible:
		if event.is_action_pressed("ui_up"):
			volume_slider.value += volume_slider.step
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			volume_slider.value -= volume_slider.step
			get_viewport().set_input_as_handled()


func _on_welcome_info_pressed() -> void:
	settings_button.button_pressed = false
	await get_tree().process_frame
	var wp := get_tree().get_first_node_in_group("welcome_popup")
	if wp != null and wp.has_method("open_from_settings"):
		wp.call("open_from_settings")


func _on_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, value)


# -------- HOVER SIN ROMPER LAYOUT --------

func _on_button_hover_enter() -> void:
	settings_button.modulate = Color(1.2, 1.2, 1.2) # brillo leve


func _on_button_hover_exit() -> void:
	settings_button.modulate = Color(1, 1, 1)


# -------- REMOVE DEFAULT STYLE --------

func _remove_button_style(button: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)


func _style_welcome_info_button(button: Button) -> void:
	button.flat = false
	button.custom_minimum_size = Vector2(280, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.1, 0.2, 0.3, 0.92)
	sb_n.set_corner_radius_all(8)
	sb_n.set_border_width_all(2)
	sb_n.border_color = Color(0.38, 0.78, 0.96, 0.9)
	sb_n.content_margin_left = 16
	sb_n.content_margin_top = 10
	sb_n.content_margin_right = 16
	sb_n.content_margin_bottom = 10
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(0.16, 0.3, 0.44, 1.0)
	sb_h.border_color = Color(0.55, 0.92, 1.0, 1.0)
	var sb_p := sb_n.duplicate()
	sb_p.bg_color = Color(0.07, 0.12, 0.18, 1.0)
	sb_p.border_color = Color(0.28, 0.65, 0.85, 1.0)
	button.add_theme_stylebox_override("normal", sb_n)
	button.add_theme_stylebox_override("hover", sb_h)
	button.add_theme_stylebox_override("pressed", sb_p)
	button.add_theme_stylebox_override("focus", sb_h)
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.82, 0.9, 1.0))
