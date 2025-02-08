extends Control

@onready var audio_player = $MarginContainer/Volume/AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_texture_button_pressed():
	if !self.visible:
		self.visible = true
		get_tree().paused = true  # Pausar el juego

func _on_close_button_pressed():
	if self.visible:
		self.visible = false
		get_tree().paused = false  # Reanudar el juego
