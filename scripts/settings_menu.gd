extends Control

var is_open = false

@onready var volume_slider = $MarginContainer/VBoxContainer/Volume/VolumeHSlider
@onready var music_manager = get_tree().get_first_node_in_group("music_manager")

func _ready():
	hide()
	# Configurar slider en decibelios
	volume_slider.min_value = -40
	volume_slider.max_value = 0
	volume_slider.step = 1
	
	# VOLUMEN AL 100% AL INICIAR (0 dB)
	volume_slider.value = 0
	
	volume_slider.value_changed.connect(_on_volume_changed)
	_on_volume_changed(0) # Aplicar volumen inicial

func _input(event):
	if not is_open:
		return
	
	if event.is_action_pressed("ui_up"):
		volume_slider.value += 1
		get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_down"):
		volume_slider.value -= 1
		get_viewport().set_input_as_handled()

func _on_volume_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), value)
	if music_manager:
		music_manager.player.volume_db = value

func open_menu():
	show()
	is_open = true
	Engine.time_scale = 0
	volume_slider.grab_focus()

func close_menu():
	hide()
	is_open = false
	Engine.time_scale = 1

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if is_open:
			close_menu()
		else:
			open_menu()

func _on_settings_button_pressed() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()
	get_viewport().gui_release_focus()
