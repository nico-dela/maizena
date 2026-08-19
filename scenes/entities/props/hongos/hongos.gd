extends Area2D

@export var dialogue: DialogueResource
@export var start_node := "start"
var collected := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not body.is_in_group("player"):
		return
	if collected:
		return
	collected = true
	
	# 1. actualizar estado
	GameState.agarrar_comida()
	
	# 2. mostrar diálogo
	if dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, start_node)
		await get_tree().create_timer(0.1).timeout
	queue_free()
