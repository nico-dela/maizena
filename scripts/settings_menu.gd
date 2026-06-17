extends CanvasLayer

@onready var menu_panel: Control = $Menu
@onready var settings_button: Button = $Button
@onready var volume_slider: HSlider = $Menu/MarginContainer/VBoxContainer/Volume/VolumeHSlider
@onready var title_label: Label = $Menu/MarginContainer/VBoxContainer/Titulo
@onready var volume_label: Label = $Menu/MarginContainer/VBoxContainer/Volume/Label
@onready var menu_vbox: VBoxContainer = $Menu/MarginContainer/VBoxContainer
@onready var volume_row: Control = $Menu/MarginContainer/VBoxContainer/Volume

@export var icon_open: Texture2D
@export var icon_close: Texture2D
var is_open := false

const BASE_TITLE_FONT := 38
const BASE_VOLUME_FONT := 28

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
	_apply_menu_typography()

	volume_slider.min_value = -40
	volume_slider.max_value = 0
	volume_slider.step = 1
	volume_slider.value = 0
	volume_slider.value_changed.connect(_on_volume_changed)

	_on_volume_changed(volume_slider.value)
	ViewportLayout.layout_changed.connect(_on_viewport_layout_changed)
	call_deferred("_on_viewport_layout_changed")


func _on_viewport_layout_changed() -> void:
	_apply_settings_button_layout()
	_apply_menu_typography()


func _apply_menu_typography() -> void:
	var title_size := ViewportLayout.scaled_font(BASE_TITLE_FONT)
	var volume_size := ViewportLayout.scaled_font(BASE_VOLUME_FONT)
	var s := ViewportLayout.effective_ui_scale()

	if title_label != null:
		title_label.label_settings = null
		title_label.add_theme_font_size_override("font_size", title_size)
	if volume_label != null:
		volume_label.label_settings = null
		volume_label.add_theme_font_size_override("font_size", volume_size)

	if menu_vbox != null:
		menu_vbox.add_theme_constant_override("separation", int(round(50.0 * s)))

	if volume_slider != null and volume_row != null:
		var half_w := 175.0 * s
		var slider_w := 150.0 * s
		volume_label.offset_left = -half_w
		volume_label.offset_right = -8.0
		volume_label.offset_top = -5.0 * s
		volume_label.offset_bottom = 24.0 * s
		volume_slider.offset_left = 16.0 * s
		volume_slider.offset_right = 16.0 * s + slider_w
		volume_slider.offset_bottom = 20.0 * s
		volume_row.custom_minimum_size.y = 48.0 * s


func _apply_settings_button_layout() -> void:
	if icon_open == null or icon_close == null:
		return
	settings_button.scale = Vector2.ONE
	settings_button.expand_icon = true
	settings_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mult := 4.0 if OS.has_feature("mobile") else 2.6
	mult *= ViewportLayout.effective_ui_scale()
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
