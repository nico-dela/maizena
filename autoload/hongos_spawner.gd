extends Node

var hongos_scene = preload("res://scenes/interactive_objects/hongos.tscn")
var hongos_spawned := false

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

func spawn_hongos():

	if hongos_spawned:
		return

	if spawn_positions.is_empty():
		print("No hay posiciones definidas")
		return

	var scene = get_tree().current_scene
	if not scene:
		print("No hay escena actual")
		return

	var hongos = hongos_scene.instantiate()

	# elegir índice aleatorio evitando repetir el último
	var index = rng.randi_range(0, spawn_positions.size() - 1)

	while index == last_index and spawn_positions.size() > 1:
		index = rng.randi_range(0, spawn_positions.size() - 1)

	last_index = index
	var pos = spawn_positions[index]

	hongos.global_position = pos
	
	scene.add_child(hongos)

	print("Spawn en índice:", index, "posición:", pos)

	hongos_spawned = true
