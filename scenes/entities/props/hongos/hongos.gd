extends Area2D

const Feedback := preload("res://scripts/gameplay/collectable_feedback.gd")

@export var dialogue: DialogueResource
@export var start_node := "start"
var collected := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	Feedback.start_idle(_sprite)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if collected:
		return
	collected = true
	monitoring = false
	GameState.agarrar_comida()
	if dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, start_node)
	Feedback.play_pickup(_sprite, queue_free)
