extends Control

var is_open = false

func _ready():
	hide()

func open_menu():
	show()
	is_open = true
	Engine.time_scale = 0

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
