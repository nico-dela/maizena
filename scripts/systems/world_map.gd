extends Node2D

## Root script for each world map scene. Holds camera limits for the player.
@export var camera_limit_right: int = 640
@export var camera_limit_bottom: int = 640

const LAND_LAYER_NAMES := [
	"ground",
	"caminos",
	"elevaciones",
	"construcciones",
	"muralla",
	"bajo elevaciones",
]
const OPAQUE_COVER_MIN := 0.5
const WATERISH_MIN := 0.35

var _cover_cache: Dictionary = {}


func _ready() -> void:
	_setup_water_collision()
	_setup_construction_collision()


func _setup_water_collision() -> void:
	var water := _find_layer_by_name("agua")
	if water == null:
		return
	# El relleno visual queda debajo del pasto; el collider solo en agua al descubierto.
	water.collision_enabled = false
	if water.get_parent().get_node_or_null("AguaCollision") != null:
		return

	var covered: Dictionary = {}
	for layer in _find_tilemap_layers(self):
		if not _is_land_layer(layer.name):
			continue
		for cell in layer.get_used_cells():
			if _land_covers_water(layer, cell):
				covered[cell] = true

	# Sombras de agua marcan estanques pintados sobre pasto: no hay que agujerearlas.
	var shade := _find_layer_by_name("sombras agua")
	if shade != null:
		shade.collision_enabled = true
		for cell in shade.get_used_cells():
			covered.erase(cell)

	var blocker := TileMapLayer.new()
	blocker.name = "AguaCollision"
	blocker.tile_set = water.tile_set
	blocker.position = water.position
	blocker.collision_enabled = true
	blocker.modulate = Color(1, 1, 1, 0)
	water.add_sibling(blocker)

	_copy_cells_except(water, blocker, covered)


func _setup_construction_collision() -> void:
	var buildings := _find_layer_by_name("construcciones")
	if buildings == null:
		return
	# Las casas se pintaron encima de las calles: la calle gana.
	buildings.collision_enabled = false
	if buildings.get_parent().get_node_or_null("BuildingCollision") != null:
		return

	var roads := _find_layer_by_name("caminos")
	var on_road: Dictionary = {}
	if roads != null:
		for cell in roads.get_used_cells():
			on_road[cell] = true

	var blocker := TileMapLayer.new()
	blocker.name = "BuildingCollision"
	blocker.tile_set = buildings.tile_set
	blocker.position = buildings.position
	blocker.collision_enabled = true
	blocker.modulate = Color(1, 1, 1, 0)
	buildings.add_sibling(blocker)
	_copy_cells_except(buildings, blocker, on_road)


func _copy_cells_except(from_layer: TileMapLayer, to_layer: TileMapLayer, skip: Dictionary) -> void:
	for cell in from_layer.get_used_cells():
		if skip.has(cell):
			continue
		to_layer.set_cell(
			cell,
			from_layer.get_cell_source_id(cell),
			from_layer.get_cell_atlas_coords(cell),
			from_layer.get_cell_alternative_tile(cell)
		)


func _land_covers_water(layer: TileMapLayer, cell: Vector2i) -> bool:
	var info := _tile_cover_info(layer, cell)
	if info.opaque < OPAQUE_COVER_MIN:
		return false
	if info.waterish:
		return false
	return true


func _tile_cover_info(layer: TileMapLayer, cell: Vector2i) -> Dictionary:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return {"opaque": 0.0, "waterish": false}
	var atlas := layer.get_cell_atlas_coords(cell)
	var key := "%s:%s:%s" % [layer.tile_set.get_instance_id(), source_id, atlas]
	if _cover_cache.has(key):
		return _cover_cache[key]
	var info := _compute_cover_info(layer.tile_set, source_id, atlas)
	_cover_cache[key] = info
	return info


func _compute_cover_info(tile_set: TileSet, source_id: int, atlas: Vector2i) -> Dictionary:
	var fallback := {"opaque": 1.0, "waterish": false}
	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return fallback
	var img: Image = source.texture.get_image()
	if img == null:
		return fallback
	if img.is_compressed():
		img.decompress()
	var region: Rect2i = source.get_tile_texture_region(atlas)
	if region.size.x < 1 or region.size.y < 1:
		return fallback
	var total := region.size.x * region.size.y
	var opaque := 0
	var water := 0
	for py in range(region.position.y, region.position.y + region.size.y):
		for px in range(region.position.x, region.position.x + region.size.x):
			var color := img.get_pixel(px, py)
			if color.a < 0.15:
				continue
			opaque += 1
			if color.b > color.r + 0.05 and color.b > color.g:
				water += 1
	var opaque_ratio := float(opaque) / float(total)
	var waterish := opaque > 0 and float(water) / float(opaque) >= WATERISH_MIN
	return {"opaque": opaque_ratio, "waterish": waterish}


func _is_land_layer(layer_name: String) -> bool:
	return layer_name.to_lower().replace("_", " ") in LAND_LAYER_NAMES


func _find_layer_by_name(layer_name: String) -> TileMapLayer:
	var wanted := layer_name.to_lower()
	for layer in _find_tilemap_layers(self):
		if layer.name.to_lower() == wanted:
			return layer
	return null


func _find_tilemap_layers(node: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	if node is TileMapLayer:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_tilemap_layers(child))
	return out
