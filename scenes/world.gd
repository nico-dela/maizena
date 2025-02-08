extends Node2D

@onready var audio_player = $CanvasLayer/settings_window/MarginContainer/Volume/AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var settings_window = $CanvasLayer/settings_window
		
		settings_window.visible = !settings_window.visible
		#get_tree().paused = settings_window.visible  # Pausa el juego solo si el menú está visible
