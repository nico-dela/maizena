extends Control

@onready var volume_slider: HSlider = $VolumeHSlider

var music_manager

func _ready():
	await get_tree().process_frame
	music_manager = get_tree().get_first_node_in_group("music_manager")
	assert(music_manager != null)
	volume_slider.value = music_manager.player.volume_db

func _on_volume_slider_value_changed(value: float) -> void:
	music_manager.player.volume_db = value
