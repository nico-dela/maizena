extends Node2D

## La saturación de cosas no se muestra en esta rama. El nodo sigue en el mapa para no romper la escena.


func _ready() -> void:
	z_index = 20
	_clear_residue()


func _clear_residue() -> void:
	for child in get_children():
		child.queue_free()
