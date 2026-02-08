extends Node

var input_locked := false

func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started(_resource):
	input_locked = true

func _on_dialogue_ended(_resource):
	input_locked = false
