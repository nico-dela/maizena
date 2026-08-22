extends CanvasLayer

const PlayerSettings = preload("res://scripts/ui/player_settings.gd")
const InputPlatformRes = preload("res://scripts/ui/input_platform.gd")
const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

const BASE_TITLE_FONT := 38
const BASE_VOLUME_FONT := 28
const BASE_MUSIC_FONT := 22
const BASE_HINT_FONT := 14
const BASE_CLOSE_FONT := 22
const BASE_PANEL_WIDTH := 420.0
const PORTRAIT_PANEL_RATIO := 0.94
const PORTRAIT_FONT_MUL := 1.22

@onready var menu_panel: Control = $Menu
@onready var menu_dim: ColorRect = $Menu/Dim
@onready var menu_box: PanelContainer = $Menu/CenterContainer/Panel
@onready var menu_vbox: VBoxContainer = $Menu/CenterContainer/Panel/Margin/VBox
@onready var settings_button: Button = $Button
@onready var close_btn: Button = $Menu/CenterContainer/Panel/Margin/VBox/CloseButton
@onready var volume_row: HBoxContainer = $Menu/CenterContainer/Panel/Margin/VBox/VolumeRow
@onready var mute_toggle_btn: Button = $Menu/CenterContainer/Panel/Margin/VBox/VolumeRow/MuteToggleButton
@onready var volume_slider: HSlider = $Menu/CenterContainer/Panel/Margin/VBox/VolumeRow/VolumeHSlider
@onready var title_label: Label = $Menu/CenterContainer/Panel/Margin/VBox/Titulo
@onready var volume_label: Label = $Menu/CenterContainer/Panel/Margin/VBox/VolumeLabel
@onready var joystick_label: Label = $Menu/CenterContainer/Panel/Margin/VBox/JoystickLabel
@onready var joystick_row: HBoxContainer = $Menu/CenterContainer/Panel/Margin/VBox/JoystickRow
@onready var joystick_slider: HSlider = $Menu/CenterContainer/Panel/Margin/VBox/JoystickRow/JoystickHSlider
@onready var music_row: HBoxContainer = $Menu/CenterContainer/Panel/Margin/VBox/MusicRow
@onready var music_label: Label = $Menu/CenterContainer/Panel/Margin/VBox/MusicRow/MusicLabel
@onready var music_toggle: CheckButton = $Menu/CenterContainer/Panel/Margin/VBox/MusicRow/MusicToggle
@onready var fullscreen_row: HBoxContainer = $Menu/CenterContainer/Panel/Margin/VBox/FullscreenRow
@onready var fullscreen_btn: Button = $Menu/CenterContainer/Panel/Margin/VBox/FullscreenRow/FullscreenButton
@onready var hint_label: Label = $Menu/CenterContainer/Panel/Margin/VBox/Hint

@export var icon_open: Texture2D
var is_open := false

var _panel_style: StyleBoxFlat
var _loading_settings := false
var _master_muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	add_to_group("settings_menu")

	_panel_style = _make_panel_style()
	menu_box.add_theme_stylebox_override("panel", _panel_style)

	menu_panel.hide()
	is_open = false

	settings_button.icon = icon_open
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button.mouse_entered.connect(_on_button_hover_enter)
	settings_button.mouse_exited.connect(_on_button_hover_exit)
	_remove_button_style(settings_button)

	close_btn.pressed.connect(_on_close_pressed)
	_style_close_button()

	volume_slider.min_value = PlayerSettings.VOLUME_MIN_DB
	volume_slider.max_value = PlayerSettings.VOLUME_MAX_DB
	volume_slider.step = 1
	joystick_slider.min_value = PlayerSettings.JOYSTICK_SCALE_MIN
	joystick_slider.max_value = PlayerSettings.JOYSTICK_SCALE_MAX
	joystick_slider.step = 0.05
	_loading_settings = true
	var settings := PlayerSettings.load_all()
	volume_slider.value = float(settings.get("master_volume_db", PlayerSettings.default_volume_db()))
	_master_muted = bool(settings.get("master_muted", false))
	joystick_slider.value = float(settings.get("joystick_scale", PlayerSettings.DEFAULT_JOYSTICK_SCALE))
	_loading_settings = false
	volume_slider.value_changed.connect(_on_volume_changed)
	joystick_slider.value_changed.connect(_on_joystick_scale_changed)
	mute_toggle_btn.pressed.connect(_on_mute_toggle_pressed)
	_apply_master_audio()
	_update_volume_label()
	_update_joystick_label()
	_sync_mute_icon()
	_apply_joystick_settings_visibility()

	_style_music_toggle()
	music_toggle.toggled.connect(_on_background_play_toggled)
	call_deferred("_bind_background_toggle")

	fullscreen_btn.pressed.connect(_on_fullscreen_pressed)
	fullscreen_row.visible = true
	_sync_fullscreen_button()

	menu_dim.gui_input.connect(_on_dim_gui_input)
	_style_volume_slider()
	_style_joystick_slider()

	_apply_settings_button_layout()
	_apply_menu_layout()
	ViewportLayout.layout_changed.connect(_on_viewport_layout_changed)


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


func _style_close_button() -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.2, 0.3, 0.88)
	sb_n.set_corner_radius_all(5)
	sb_n.set_border_width_all(1)
	sb_n.border_color = Color(0.42, 0.76, 0.94, 0.5)
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(0.16, 0.26, 0.38, 0.95)
	close_btn.add_theme_stylebox_override("normal", sb_n)
	close_btn.add_theme_stylebox_override("hover", sb_h)
	close_btn.add_theme_stylebox_override("pressed", sb_h)
	close_btn.add_theme_stylebox_override("focus", sb_n)
	close_btn.add_theme_font_override("font", FONT)


func _style_volume_slider() -> void:
	_apply_slider_theme(volume_slider)


func _style_joystick_slider() -> void:
	_apply_slider_theme(joystick_slider)


func _apply_joystick_settings_visibility() -> void:
	var show_joystick := InputPlatformRes.is_touch_primary()
	if joystick_label != null:
		joystick_label.visible = show_joystick
	if joystick_row != null:
		joystick_row.visible = show_joystick


func _apply_slider_theme(slider: HSlider) -> void:
	if slider == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.04, 0.07, 0.1, 0.95)
	track.set_corner_radius_all(4)
	track.set_content_margin_all(6)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.35, 0.82, 0.96, 1)
	grabber.set_corner_radius_all(5)
	grabber.set_content_margin_all(5)
	var grabber_h := grabber.duplicate()
	grabber_h.bg_color = Color(0.5, 0.9, 1.0, 1)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber_h)


func _style_music_toggle() -> void:
	music_label.add_theme_font_override("font", FONT)
	music_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
	music_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	music_toggle.text = ""
	music_toggle.flat = true
	music_toggle.add_theme_font_override("font", FONT)
	music_toggle.focus_mode = Control.FOCUS_NONE


func _bind_background_toggle() -> void:
	var mm := get_tree().get_first_node_in_group("music_manager")
	if mm == null:
		return
	music_toggle.button_pressed = mm.is_play_in_background()


func _on_background_play_toggled(enabled: bool) -> void:
	var mm := get_tree().get_first_node_in_group("music_manager")
	if mm == null:
		return
	mm.set_play_in_background(enabled)


func _on_viewport_layout_changed() -> void:
	_apply_settings_button_layout()
	_apply_menu_layout()


func _apply_menu_layout() -> void:
	var s := ViewportLayout.effective_ui_scale()
	var layout: Vector2 = ViewportLayout.visible_layout_size()
	var portrait := ViewportLayout.is_portrait
	# En portrait el panel acompaña el ancho de la pantalla, como el popup de Noticias.
	var panel_w := layout.x * PORTRAIT_PANEL_RATIO if portrait else minf(
		BASE_PANEL_WIDTH * s, layout.x * 0.94
	)
	menu_box.custom_minimum_size = Vector2(panel_w, 0)
	menu_vbox.add_theme_constant_override("separation", int(round((26.0 if portrait else 20.0) * s)))
	_apply_panel_padding(s, portrait)

	_set_label_font(title_label, BASE_TITLE_FONT)
	title_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.96, 1))
	_set_label_font(volume_label, BASE_VOLUME_FONT)
	_set_label_font(joystick_label, BASE_VOLUME_FONT)
	_style_mute_toggle(s)
	_set_label_font(music_label, BASE_MUSIC_FONT)
	_apply_toggle_layout(music_toggle, s)
	_style_action_button(fullscreen_btn, s)
	_set_label_font(hint_label, BASE_HINT_FONT)
	close_btn.add_theme_font_size_override("font_size", _menu_font(BASE_CLOSE_FONT))
	close_btn.custom_minimum_size.y = maxf(56.0 if portrait else 48.0, 44.0 * s)
	var slider_h := maxi(36 if portrait else 28, int(round(30.0 * s)))
	volume_slider.custom_minimum_size.y = slider_h
	joystick_slider.custom_minimum_size.y = slider_h


func _menu_font(base_size: int) -> int:
	var mul := PORTRAIT_FONT_MUL if ViewportLayout.is_portrait else 1.0
	return maxi(1, int(round(float(ViewportLayout.scaled_font(base_size)) * mul)))


func _apply_panel_padding(s: float, portrait: bool) -> void:
	if _panel_style == null:
		return
	var pad := int(round((16.0 if portrait else 6.0) * s))
	_panel_style.content_margin_left = pad
	_panel_style.content_margin_top = pad
	_panel_style.content_margin_right = pad
	_panel_style.content_margin_bottom = pad


func _style_mute_toggle(s: float) -> void:
	if mute_toggle_btn == null:
		return
	var side := maxf(40.0, 36.0 * s)
	if ViewportLayout.is_portrait:
		side = maxf(44.0, side)
	mute_toggle_btn.custom_minimum_size = Vector2(side, side)
	mute_toggle_btn.add_theme_font_size_override("font_size", _menu_font(BASE_MUSIC_FONT))
	mute_toggle_btn.flat = true
	mute_toggle_btn.focus_mode = Control.FOCUS_NONE


func _style_action_button(button: Button, s: float) -> void:
	if button == null:
		return
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", _menu_font(BASE_MUSIC_FONT))
	button.custom_minimum_size.y = maxf(48.0 if ViewportLayout.is_portrait else 40.0, 40.0 * s)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.1, 0.16, 0.24, 0.92)
	sb_n.set_corner_radius_all(5)
	sb_n.set_border_width_all(1)
	sb_n.border_color = Color(0.42, 0.76, 0.94, 0.5)
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(0.14, 0.22, 0.32, 0.98)
	button.add_theme_stylebox_override("normal", sb_n)
	button.add_theme_stylebox_override("hover", sb_h)
	button.add_theme_stylebox_override("pressed", sb_h)
	button.add_theme_stylebox_override("focus", sb_n)


func _apply_toggle_layout(toggle: CheckButton, s: float) -> void:
	if toggle == null:
		return
	toggle.add_theme_font_size_override("font_size", _menu_font(BASE_MUSIC_FONT))
	var side := maxf(52.0 if ViewportLayout.is_portrait else 40.0, 40.0 * s)
	toggle.custom_minimum_size = Vector2(side, side)


func _set_label_font(label: Label, base_size: int, font: FontFile = FONT) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", _menu_font(base_size))


func _apply_settings_button_layout() -> void:
	if icon_open == null:
		return
	settings_button.scale = Vector2.ONE
	settings_button.expand_icon = true
	settings_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mult := 2.9 if OS.has_feature("mobile") else 2.6
	mult *= minf(ViewportLayout.effective_ui_scale(), 2.0)
	var iw := maxi(1, int(round(float(icon_open.get_width()) * mult)))
	var ih := maxi(1, int(round(float(icon_open.get_height()) * mult)))
	const SCREEN_MARGIN := 20.0
	var margin_top: float = ViewportLayout.screen_margin_top(8.0)
	var margin_right: float = ViewportLayout.screen_margin_right(SCREEN_MARGIN)
	settings_button.custom_minimum_size = Vector2(iw, ih)
	settings_button.anchor_left = 1.0
	settings_button.anchor_right = 1.0
	settings_button.anchor_top = 0.0
	settings_button.anchor_bottom = 0.0
	settings_button.offset_top = margin_top
	settings_button.offset_bottom = margin_top + float(ih)
	settings_button.offset_left = -margin_right - float(iw)
	settings_button.offset_right = -margin_right
	settings_button.visible = true
	settings_button.modulate = Color(1, 1, 1, 1)


func _on_settings_pressed() -> void:
	if is_open:
		return
	_open_menu()


func _open_menu() -> void:
	ViewportLayout.refresh()
	menu_panel.show()
	is_open = true
	_apply_joystick_settings_visibility()
	_apply_menu_layout()
	call_deferred("_apply_menu_layout")


func _close_menu() -> void:
	menu_panel.hide()
	is_open = false


func _on_close_pressed() -> void:
	_close_menu()


func _can_open_menu() -> bool:
	if GameState.bollo_training_active:
		return false
	if DialogueController.input_locked:
		return false
	var wp := get_tree().get_first_node_in_group("welcome_popup")
	if wp != null and wp.has_method("is_blocking") and wp.call("is_blocking"):
		return false
	return true


func _show_menu() -> void:
	if is_open:
		return
	_open_menu()


func _on_dim_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_menu()


func _is_menu_toggle(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_menu")


func _unhandled_input(event: InputEvent) -> void:
	if _is_menu_toggle(event):
		if is_open:
			_close_menu()
			get_viewport().set_input_as_handled()
		elif _can_open_menu():
			_show_menu()
			get_viewport().set_input_as_handled()
		return

	if not menu_panel.visible:
		return

	if event.is_action_pressed("ui_up"):
		volume_slider.value += volume_slider.step
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		volume_slider.value -= volume_slider.step
		get_viewport().set_input_as_handled()


func _on_mute_toggle_pressed() -> void:
	_master_muted = not _master_muted
	_apply_master_audio()
	_update_volume_label()
	_sync_mute_icon()
	if not _loading_settings:
		PlayerSettings.save_partial({"master_muted": _master_muted})
	get_tree().call_group("sound_toggle", "_update_label")


func _on_volume_changed(value: float) -> void:
	if not _loading_settings and _master_muted:
		_master_muted = false
	_apply_master_audio()
	_update_volume_label()
	_sync_mute_icon()
	if not _loading_settings:
		PlayerSettings.save_partial({
			"master_volume_db": value,
			"master_muted": _master_muted,
		})
		get_tree().call_group("sound_toggle", "_update_label")


func _on_joystick_scale_changed(value: float) -> void:
	_update_joystick_label()
	if _loading_settings:
		return
	PlayerSettings.save_partial({"joystick_scale": value})
	get_tree().call_group("virtual_joystick", "refresh_layout")


func _apply_master_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, _master_muted)
	if not _master_muted:
		AudioServer.set_bus_volume_db(master_bus, volume_slider.value)
		var music := get_tree().get_first_node_in_group("music_manager")
		if music != null and music.has_method("unlock_and_play"):
			music.unlock_and_play()


func _sync_mute_icon() -> void:
	if mute_toggle_btn == null:
		return
	mute_toggle_btn.text = "🔇" if _master_muted else "🔊"


func _on_fullscreen_pressed() -> void:
	# Prefer DisplayServer so Godot resizes the viewport consistently (incl. web).
	var mode := DisplayServer.window_get_mode()
	var going_fullscreen := (
		mode != DisplayServer.WINDOW_MODE_FULLSCREEN
		and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if going_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_sync_fullscreen_button(going_fullscreen, true)

	var music := get_tree().get_first_node_in_group("music_manager")
	if music != null and music.has_method("unlock_and_play"):
		music.unlock_and_play()
	call_deferred("_refresh_after_fullscreen")


func _sync_fullscreen_button(is_fullscreen: bool = false, force: bool = false) -> void:
	if fullscreen_btn == null:
		return
	var fs := is_fullscreen
	if not force:
		var mode := DisplayServer.window_get_mode()
		fs = (
			mode == DisplayServer.WINDOW_MODE_FULLSCREEN
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		)
	fullscreen_btn.text = "Salir de pantalla completa" if fs else "Pantalla completa"


func _refresh_after_fullscreen() -> void:
	# Fullscreen resize can arrive 1–2 frames late on web.
	await get_tree().process_frame
	await get_tree().process_frame
	ViewportLayout.refresh()
	_sync_fullscreen_button()
	_apply_settings_button_layout()
	_apply_menu_layout()
	await get_tree().create_timer(0.15).timeout
	ViewportLayout.refresh()
	_sync_fullscreen_button()
	_apply_settings_button_layout()
	_apply_menu_layout()


func _update_volume_label() -> void:
	if _master_muted:
		volume_label.text = "Volumen — Silenciado"
	else:
		volume_label.text = "Volumen — %d%%" % _volume_percent(volume_slider.value)


func _update_joystick_label() -> void:
	var pct := int(round(joystick_slider.value * 100.0))
	joystick_label.text = "Joystick — %d%%" % pct


func _volume_percent(db: float) -> int:
	var min_db := volume_slider.min_value
	if db <= min_db:
		return 0
	return int(round(inverse_lerp(min_db, volume_slider.max_value, db) * 100.0))


func _on_button_hover_enter() -> void:
	settings_button.modulate = Color(1.15, 1.15, 1.15)


func _on_button_hover_exit() -> void:
	settings_button.modulate = Color(1, 1, 1)


func _remove_button_style(button: Button) -> void:
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
