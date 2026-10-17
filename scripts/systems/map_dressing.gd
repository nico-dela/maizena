extends Node2D

## Sprites sueltos del tileset exterior para que la ciudad y el pantano no queden vacíos.
## No bloquean el paso: el jugador los cruza.

const OUTDOORS := preload("res://assets/art/tilesets/OutdoorsTileset.png")

const PLANT_RECTS: Array[Rect2] = [
	Rect2(0, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(0, 32, 16, 16),
	Rect2(32, 32, 16, 16),
	Rect2(80, 96, 16, 16),
	Rect2(80, 112, 16, 16),
]
const ROCK_RECTS: Array[Rect2] = [
	Rect2(80, 32, 16, 16),
	Rect2(96, 32, 16, 16),
	Rect2(112, 32, 16, 16),
	Rect2(128, 32, 16, 16),
	Rect2(80, 128, 16, 16),
]
const CITY_RECTS: Array[Rect2] = [
	Rect2(80, 0, 16, 16),
	Rect2(80, 48, 16, 16),
	Rect2(112, 80, 16, 16),
	Rect2(0, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(80, 96, 16, 16),
]

const SWAMP_COUNT := 28
const CITY_COUNT := 22
const SEPARATION := 88.0

var _placed := false


func _ready() -> void:
	z_index = 1
	call_deferred("_dress")


func _dress() -> void:
	if _placed:
		return
	var world := get_parent()
	if world == null:
		return
	var kind := str(world.get("map_ambience"))
	var rects := _rects_for(kind)
	if rects.is_empty():
		return
	var count := SWAMP_COUNT if kind == "swamp" else CITY_COUNT
	var avoid := _occupied_points(world)
	for _i in count:
		var pos := HongosSpawner.find_walkable_position(
			world,
			avoid,
			SEPARATION,
			false,
			"Ground",
			HongosSpawner.RELIC_BLOCK_LAYER_NAMES
		)
		if not _is_separated(pos, avoid):
			continue
		avoid.append(pos)
		_add_sprite(rects, pos)
	_placed = true


func _rects_for(kind: String) -> Array:
	if kind == "swamp":
		var swamp: Array = []
		swamp.append_array(PLANT_RECTS)
		swamp.append_array(ROCK_RECTS)
		return swamp
	if kind == "city":
		return CITY_RECTS.duplicate()
	return []


func _occupied_points(world: Node) -> Array:
	var points: Array = []
	_collect_points(world, points)
	return points


func _collect_points(node: Node, points: Array) -> void:
	if node != self and node is Node2D and _holds_a_place(node):
		points.append((node as Node2D).global_position)
	for child in node.get_children():
		_collect_points(child, points)


func _holds_a_place(node: Node) -> bool:
	if node.is_in_group("dialogue"):
		return true
	return node is Area2D


func _is_separated(pos: Vector2, avoid: Array) -> bool:
	for other in avoid:
		if typeof(other) != TYPE_VECTOR2:
			continue
		if pos.distance_to(other) < SEPARATION:
			return false
	return true


func _add_sprite(rects: Array, pos: Vector2) -> void:
	var region: Rect2 = rects[randi() % rects.size()]
	var atlas := AtlasTexture.new()
	atlas.atlas = OUTDOORS
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = pos - global_position
	sprite.flip_h = randf() > 0.5
	add_child(sprite)
