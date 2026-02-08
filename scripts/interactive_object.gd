extends Node2D

@export var dialogue: DialogueResource
@export var start_node := "start"

func show_dialogue():
	if dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, start_node)
