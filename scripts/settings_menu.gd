extends CanvasLayer

@onready var menu_panel: Control = $Menu
@onready var settings_button: Button = $Button
@onready var volume_slider: HSlider = $Menu/MarginContainer/VBoxContainer/Volume/VolumeHSlider

@export var icon_open: Texture2D
@export var icon_close: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	menu_panel.hide()

	settings_button.toggle_mode = true
	settings_button.button_pressed = false
	settings_button.icon = icon_open
	settings_button.toggled.connect(_on_settings_toggled)

	settings_button.mouse_entered.connect(_on_button_hover_enter)
	settings_button.mouse_exited.connect(_on_button_hover_exit)

	_remove_button_style(settings_button)

	volume_slider.min_value = -40
	volume_slider.max_value = 0
	volume_slider.step = 1
	volume_slider.value = 0
	volume_slider.value_changed.connect(_on_volume_changed)

	_on_volume_changed(volume_slider.value)


func _on_settings_toggled(pressed: bool) -> void:
	if pressed:
		_open_menu()
	else:
		_close_menu()


func _open_menu() -> void:
	menu_panel.show()
	get_tree().paused = true
	settings_button.icon = icon_close


func _close_menu() -> void:
	menu_panel.hide()
	get_tree().paused = false
	settings_button.icon = icon_open


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
