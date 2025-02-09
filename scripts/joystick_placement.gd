extends Button

var dragging = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventMouseButton:
		dragging = event.pressed
		get_viewport().set_input_as_handled()

func _input(event):
	if dragging and event is InputEventMouseMotion:
		global_position += event.relative
