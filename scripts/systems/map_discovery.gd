extends Node
class_name MapDiscovery

signal exploration_updated(map_id: String)

const TILE_SIZE := 16
const VISION_RADIUS := 140.0
## ceil(VISION_RADIUS / TILE_SIZE); circle test uses cell-distance squared.
const RADIUS_CELLS := 9
const RADIUS_CELLS_SQ := 77
const WATER_LAYER_AREA_RATIO := 0.82
const NEW_WORLD_NAME := "NewWorld"
const KNOWN_MAP_ROOTS: Array[String] = ["Bosque encantado 1", "Ciudad", "Pantano Sur"]

var map_id: String = ""
var world_bounds: Rect2 = Rect2()
var exploration_image: Image
var exploration_texture: ImageTexture

var _grid_size := Vector2i.ZERO
var _dirty := false
var _last_cell := Vector2i(-999999, -999999)
var _pending_cells: Array[Vector2i] = []
## Vector2i → true (O(1), no string alloc on the reveal hot path).
var _explored: Dictionary = {}


func _ready() -> void:
	exploration_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	exploration_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	exploration_texture = ImageTexture.create_from_image(exploration_image)


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		if exploration_texture != null and exploration_image != null:
			exploration_texture.update(exploration_image)
		exploration_updated.emit(map_id)
	if not _pending_cells.is_empty():
		_flush_pending_cells()


func setup_from_world(world: Node) -> void:
	map_id = _resolve_map_id(world)
	world_bounds = _collect_bounds(world)
	if world_bounds.size == Vector2.ZERO or map_id.is_empty():
		return

	_grid_size = Vector2i(
		maxi(1, int(ceil(world_bounds.size.x / float(TILE_SIZE)))),
		maxi(1, int(ceil(world_bounds.size.y / float(TILE_SIZE))))
	)
	exploration_image = Image.create(_grid_size.x, _grid_size.y, false, Image.FORMAT_RGBA8)
	exploration_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_explored.clear()
	_pending_cells.clear()
	_apply_saved_cells(WorldState.get_explored_cells(map_id))
	exploration_texture = ImageTexture.create_from_image(exploration_image)
	_last_cell = Vector2i(-999999, -999999)
	_dirty = false
	exploration_updated.emit(map_id)


func reveal_at(world_pos: Vector2) -> void:
	if map_id.is_empty() or _grid_size == Vector2i.ZERO:
		return

	var center_cell := _world_to_cell(world_pos)
	if center_cell == _last_cell:
		return
	_last_cell = center_cell

	var changed := false
	for dy in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
		for dx in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
			if dx * dx + dy * dy > RADIUS_CELLS_SQ:
				continue
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= _grid_size.x or cell.y >= _grid_size.y:
				continue
			if _explored.has(cell):
				continue
			_explored[cell] = true
			_paint_cell(cell)
			_pending_cells.append(cell)
			changed = true

	if changed:
		_dirty = true


func flush_pending() -> void:
	_flush_pending_cells()


func _flush_pending_cells() -> void:
	if _pending_cells.is_empty():
		return
	var keys: Array[String] = []
	keys.resize(_pending_cells.size())
	for i in range(_pending_cells.size()):
		var cell: Vector2i = _pending_cells[i]
		keys[i] = "%d,%d" % [cell.x, cell.y]
	WorldState.add_explored_cells(map_id, keys)
	_pending_cells.clear()


func get_fog_texture() -> ImageTexture:
	return exploration_texture


func sample_fog_alpha(world_pos: Vector2) -> float:
	if map_id.is_empty() or _grid_size == Vector2i.ZERO:
		return 1.0
	if not world_bounds.has_point(world_pos):
		return 1.0
	var cell := _world_to_cell(world_pos)
	if not _is_cell_in_grid(cell):
		return 1.0
	return exploration_image.get_pixel(cell.x, cell.y).a


func build_minimap_fog_image(map_size: Vector2, bounds: Rect2, cam_zoom: float) -> Image:
	var w := maxi(1, int(map_size.x))
	var h := maxi(1, int(map_size.y))
	if (
		exploration_image == null
		or _grid_size == Vector2i.ZERO
		or bounds.size == Vector2.ZERO
		or cam_zoom <= 0.0
	):
		var blank := Image.create(w, h, false, Image.FORMAT_RGBA8)
		blank.fill(Color(0.0, 0.0, 0.0, 1.0))
		return blank

	var center := bounds.get_center()
	var world_half := map_size / (2.0 * cam_zoom)
	var c0 := _world_to_cell(center - world_half)
	var c1 := _world_to_cell(center + world_half)
	var x0 := clampi(mini(c0.x, c1.x), 0, _grid_size.x - 1)
	var y0 := clampi(mini(c0.y, c1.y), 0, _grid_size.y - 1)
	var x1 := clampi(maxi(c0.x, c1.x), 0, _grid_size.x - 1)
	var y1 := clampi(maxi(c0.y, c1.y), 0, _grid_size.y - 1)
	var rw := x1 - x0 + 1
	var rh := y1 - y0 + 1
	if rw <= 0 or rh <= 0:
		var blank2 := Image.create(w, h, false, Image.FORMAT_RGBA8)
		blank2.fill(Color(0.0, 0.0, 0.0, 1.0))
		return blank2

	var cropped := exploration_image.get_region(Rect2i(x0, y0, rw, rh))
	cropped.resize(w, h, Image.INTERPOLATE_NEAREST)
	return cropped


func _apply_saved_cells(keys: Array) -> void:
	for raw in keys:
		var key := str(raw)
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if _is_cell_in_grid(cell):
			_explored[cell] = true
			_paint_cell(cell)


func _paint_cell(cell: Vector2i) -> void:
	## Center clear + cheap ortho soft edge (no diagonal reads).
	exploration_image.set_pixel(cell.x, cell.y, Color(0.0, 0.0, 0.0, 0.0))
	_soften_neighbor(cell.x - 1, cell.y, 0.35)
	_soften_neighbor(cell.x + 1, cell.y, 0.35)
	_soften_neighbor(cell.x, cell.y - 1, 0.35)
	_soften_neighbor(cell.x, cell.y + 1, 0.35)


func _soften_neighbor(x: int, y: int, target_alpha: float) -> void:
	if x < 0 or y < 0 or x >= _grid_size.x or y >= _grid_size.y:
		return
	var current := exploration_image.get_pixel(x, y).a
	if current > target_alpha:
		exploration_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, target_alpha))


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - world_bounds.position
	return Vector2i(
		int(floor(local.x / float(TILE_SIZE))),
		int(floor(local.y / float(TILE_SIZE)))
	)


func _is_cell_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y


func _resolve_map_id(world: Node) -> String:
	if world == null:
		return ""
	var path := world.scene_file_path
	for entry in HongosSpawner.MAPS:
		if str(entry.get("path", "")) == path:
			return str(entry.get("id", ""))
	return ""


func _collect_bounds(world: Node) -> Rect2:
	var from_limits := _bounds_from_limits(world)
	var map_root := _find_map_root(world)
	var from_tiles := Rect2()
	if map_root != null:
		from_tiles = _tilemap_bounds_filtered(map_root)
	if from_limits.size == Vector2.ZERO:
		return from_tiles
	if from_tiles.size == Vector2.ZERO:
		return from_limits
	return from_limits.merge(from_tiles)


func _find_map_root(world: Node) -> Node2D:
	for map_name in KNOWN_MAP_ROOTS:
		var named := world.get_node_or_null(map_name)
		if named is Node2D:
			return named as Node2D
	for child in world.get_children():
		if child is Node2D and not _find_tilemap_layers(child).is_empty():
			return child as Node2D
	if not _find_tilemap_layers(world).is_empty() and world is Node2D:
		return world as Node2D
	return null


func _bounds_from_limits(world: Node) -> Rect2:
	var right := int(world.get("camera_limit_right")) if "camera_limit_right" in world else 640
	var bottom := int(world.get("camera_limit_bottom")) if "camera_limit_bottom" in world else 640
	if right <= 0 or bottom <= 0:
		return Rect2()
	return Rect2(0.0, 0.0, float(right), float(bottom))


func _tilemap_bounds_filtered(root: Node) -> Rect2:
	var layer_rects: Array[Rect2] = []
	for layer in _find_tilemap_layers(root):
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size := layer.tile_set.tile_size if layer.tile_set else Vector2i(TILE_SIZE, TILE_SIZE)
		var local_rect := Rect2(
			Vector2(used.position) * Vector2(tile_size),
			Vector2(used.size) * Vector2(tile_size)
		)
		layer_rects.append(layer.global_transform * local_rect)
	if layer_rects.is_empty():
		return Rect2()

	var max_area := 0.0
	for rect in layer_rects:
		max_area = maxf(max_area, rect.size.x * rect.size.y)

	var merged := Rect2()
	var has_rect := false
	for rect in layer_rects:
		var area := rect.size.x * rect.size.y
		if max_area > 0.0 and area >= max_area * WATER_LAYER_AREA_RATIO:
			continue
		if has_rect:
			merged = merged.merge(rect)
		else:
			merged = rect
			has_rect = true

	if not has_rect:
		for rect in layer_rects:
			if has_rect:
				merged = merged.merge(rect)
			else:
				merged = rect
				has_rect = true
	return merged


func _find_tilemap_layers(node: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	if node is TileMapLayer:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_tilemap_layers(child))
	return out
