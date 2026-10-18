extends Node

## La cima queda sobre el suelo y los árboles. Sanjin (z 2) se dibuja delante.
const FRONT_Z := 1
const PEAK_MIN_Y := 10
const PEAK_MAX_Y := 13
const CLIFF_X := 33
const CLIFF_MAX_Y := 11


func _ready() -> void:
	var elev := _find_layer("elevaciones")
	var trees := _find_layer("arboles")
	if elev == null:
		return
	var front := _make_front(elev)
	for cell in elev.get_used_cells():
		if not _covers(cell, trees):
			continue
		_move_cell(elev, front, cell)


func _covers(cell: Vector2i, trees: TileMapLayer) -> bool:
	if cell.y < PEAK_MIN_Y or cell.y > PEAK_MAX_Y:
		return false
	if cell.x == CLIFF_X and cell.y <= CLIFF_MAX_Y:
		return false
	if trees != null and trees.get_cell_source_id(cell) != -1:
		return false
	return true


func _make_front(elev: TileMapLayer) -> TileMapLayer:
	var front := TileMapLayer.new()
	front.name = "Cima"
	front.tile_set = elev.tile_set
	front.z_index = FRONT_Z
	front.texture_filter = elev.texture_filter
	elev.get_parent().add_child(front)
	return front


func _move_cell(elev: TileMapLayer, front: TileMapLayer, cell: Vector2i) -> void:
	var source := elev.get_cell_source_id(cell)
	var atlas := elev.get_cell_atlas_coords(cell)
	var alt := elev.get_cell_alternative_tile(cell)
	front.set_cell(cell, source, atlas, alt)
	elev.erase_cell(cell)


func _find_layer(layer_name: String) -> TileMapLayer:
	var world := get_parent()
	if world == null:
		return null
	return _search_layer(world, layer_name)


func _search_layer(node: Node, layer_name: String) -> TileMapLayer:
	if node is TileMapLayer and node.name.to_lower() == layer_name:
		return node
	for child in node.get_children():
		var found := _search_layer(child, layer_name)
		if found != null:
			return found
	return null
