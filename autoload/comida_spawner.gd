extends Node

var cabbage_scene = preload("res://scenes/interactive_objects/comida.tscn")
var cabbage_spawned := false

# posiciones válidas
var spawn_positions := [
	Vector2(-294, -859),
	Vector2(-232, 21),
	Vector2(-30, -450)
]

var rng := RandomNumberGenerator.new()
var last_index := -1

func _ready():
	rng.randomize()

func spawn_cabbage():

	if cabbage_spawned:
		return

	if spawn_positions.is_empty():
		print("No hay posiciones definidas")
		return

	var scene = get_tree().current_scene
	if not scene:
		print("No hay escena actual")
		return

	var cabbage = cabbage_scene.instantiate()

	# elegir índice aleatorio evitando repetir el último
	var index = rng.randi_range(0, spawn_positions.size() - 1)

	while index == last_index and spawn_positions.size() > 1:
		index = rng.randi_range(0, spawn_positions.size() - 1)

	last_index = index
	var pos = spawn_positions[index]

	cabbage.global_position = pos
	
	scene.add_child(cabbage)

	print("Spawn en índice:", index, "posición:", pos)

	cabbage_spawned = true
