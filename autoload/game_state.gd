extends Node

var quest_hambre_active := false
var quest_hambre_completed := false
var tiene_comida := false
var inventory := {}
var bollo_training_active := false
var bollo_training_completed := false

const BOLLO_FIGHT_SCENE_PATH := "res://scenes/bollo_fight_minigame.tscn"

func buscar_comida():
	quest_hambre_active = true
	tiene_comida = false

func agarrar_comida():
	add_item("hongos", 1)
	tiene_comida = has_item("hongos")

func completar_comida():
	quest_hambre_active = false
	quest_hambre_completed = true
	remove_item("hongos", 1)
	tiene_comida = has_item("hongos")

func add_item(item_id: String, amount: int = 1):
	inventory[item_id] = int(inventory.get(item_id, 0)) + max(amount, 0)

func has_item(item_id: String, amount: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= amount

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	inventory[item_id] = int(inventory.get(item_id, 0)) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	return true

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func start_bollo_training():
	if bollo_training_active:
		return

	var current_scene := get_tree().current_scene
	if not current_scene:
		return

	var packed_scene := load(BOLLO_FIGHT_SCENE_PATH) as PackedScene
	if not packed_scene:
		return

	_dismiss_active_dialogue_balloons()

	var minigame = packed_scene.instantiate()
	current_scene.add_child(minigame)
	bollo_training_active = true
	DialogueController.input_locked = true
	get_tree().paused = true

	if minigame.has_signal("finished"):
		minigame.finished.connect(_on_bollo_training_finished)

func _on_bollo_training_finished(victory: bool):
	bollo_training_active = false
	DialogueController.input_locked = false
	get_tree().paused = false
	if victory:
		bollo_training_completed = true

func _dismiss_active_dialogue_balloons():
	var root := get_tree().root
	if not root:
		return

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if not (node is CanvasLayer):
			continue
		if not node.get_script():
			continue

		var script_path := str(node.get_script().resource_path)
		if "balloon.gd" in script_path:
			node.queue_free()
