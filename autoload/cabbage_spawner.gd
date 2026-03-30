extends Node

var cabbage_scene = preload("res://scenes/interactive_objects/repollo.tscn")
var cabbage_spawned := false

# ✅ posiciones válidas (las definís vos)
var spawn_positions := [
	Vector2(-228, -718),
	Vector2(-228, 21),
	Vector2(-100, -464)
]

func spawn_cabbage():

	if cabbage_spawned:
		return

	var scene = get_tree().current_scene
	var cabbage = cabbage_scene.instantiate()

	# elegir una posición al azar
	var pos = spawn_positions.pick_random()
	cabbage.global_position = pos
	
	scene.add_child(cabbage)

	cabbage_spawned = true
