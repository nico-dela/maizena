extends Node
class_name MapDiscovery

signal exploration_updated(map_id: String)

const TILE_SIZE := 16
const VISION_RADIUS := 140.0
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
var _pending_cells: Array[String] = []


func _ready() -> void:
	exploration_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	exploration_image.fill(Color(0.0, 0.0, 0.0, 0.92))
	exploration_texture = ImageTexture.create_from_image(exploration_image)


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
	exploration_image.fill(Color(0.0, 0.0, 0.0, 0.92))
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

	var radius_cells := int(ceil(VISION_RADIUS / float(TILE_SIZE)))
	var changed := false
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var cell := center_cell + Vector2i(dx, dy)
			if not _is_cell_in_grid(cell):
				continue
			var cell_center := _cell_to_world(cell)
			if cell_center.distance_to(world_pos) > VISION_RADIUS:
				continue
			var key := _cell_key(cell)
			if WorldState.is_cell_explored(map_id, key):
				continue
			_paint_cell(cell)
			_pending_cells.append(key)
			changed = true

	if changed:
		_dirty = true
		exploration_texture.update(exploration_image)
		exploration_updated.emit(map_id)
		if _pending_cells.size() >= 8:
			_flush_pending_cells()


func flush_pending() -> void:
	_flush_pending_cells()


func _flush_pending_cells() -> void:
	if _pending_cells.is_empty():
		return
	WorldState.add_explored_cells(map_id, _pending_cells)
	_pending_cells.clear()


func get_fog_texture() -> ImageTexture:
	return exploration_texture


func sample_fog_alpha(world_pos: Vector2) -> float:
	if map_id.is_empty() or _grid_size == Vector2i.ZERO:
		return 0.92
	if not world_bounds.has_point(world_pos):
		return 0.92
	var cell := _world_to_cell(world_pos)
	if not _is_cell_in_grid(cell):
		return 0.92
	return exploration_image.get_pixel(cell.x, cell.y).a


func build_minimap_fog_image(map_size: Vector2, bounds: Rect2, cam_zoom: float) -> Image:
	var w := maxi(1, int(map_size.x))
	var h := maxi(1, int(map_size.y))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	if bounds.size == Vector2.ZERO or cam_zoom <= 0.0:
		img.fill(Color(0.0, 0.0, 0.0, 0.92))
		return img

	var center := bounds.get_center()
	var world_half := map_size / (2.0 * cam_zoom)
	for py in range(h):
		for px in range(w):
			var rel := Vector2(
				(float(px) / float(w) - 0.5) * 2.0,
				(float(py) / float(h) - 0.5) * 2.0
			)
			var world_pos := center + Vector2(rel.x * world_half.x, rel.y * world_half.y)
			var alpha := sample_fog_alpha(world_pos)
			img.set_pixel(px, py, Color(0.0, 0.0, 0.0, alpha))
	return img


func _apply_saved_cells(keys: Array) -> void:
	for raw in keys:
		var key := str(raw)
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if _is_cell_in_grid(cell):
			_paint_cell(cell, false)


func _paint_cell(cell: Vector2i, mark_dirty: bool = true) -> void:
	var px := cell.x
	var py := cell.y
	for y in range(maxi(0, py - 1), mini(_grid_size.y, py + 2)):
		for x in range(maxi(0, px - 1), mini(_grid_size.x, px + 2)):
			var dist := Vector2(float(x - px), float(y - py)).length()
			var target_alpha := clampf(dist * 0.35, 0.0, 0.92)
			var current := exploration_image.get_pixel(x, y).a
			exploration_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, minf(current, target_alpha)))
	if mark_dirty:
		_dirty = true


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - world_bounds.position
	return Vector2i(
		int(floor(local.x / float(TILE_SIZE))),
		int(floor(local.y / float(TILE_SIZE)))
	)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return world_bounds.position + Vector2(
		(float(cell.x) + 0.5) * float(TILE_SIZE),
		(float(cell.y) + 0.5) * float(TILE_SIZE)
	)


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


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
