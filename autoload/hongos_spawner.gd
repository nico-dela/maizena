extends Node

## Spawnea hongos en un mapa al azar, sobre tiles caminables (Ground/Caminos).

const HONGOS_SCENE := preload("res://scenes/entities/props/hongos/hongos.tscn")
const WORLD_NODE_NAME := "NewWorld"
const MAX_ATTEMPTS := 48
const EDGE_MARGIN_CELLS := 2
const MIN_PLAYER_DISTANCE := 96.0

const MAPS: Array[Dictionary] = [
	{
		"id": "bosque_encantado",
		"path": "res://scenes/world/bosque_encantado.tscn",
		"hint": "el bosque",
	},
	{
		"id": "ciudad_world",
		"path": "res://scenes/world/ciudad_world.tscn",
		"hint": "la ciudad",
	},
	{
		"id": "pantano_world",
		"path": "res://scenes/world/pantano_world.tscn",
		"hint": "el pantano",
	},
]

const WALK_LAYER_NAMES: Array[String] = ["Caminos", "Ground"]
const BLOCK_LAYER_NAMES: Array[String] = [
	"Agua",
	"Arboles",
	"Construcciones",
	"construcciones",
	"Muralla",
	"Elevaciones",
	"elevaciones",
	"Cascada",
]
## El agua queda debajo del pasto en estos mapas; no bloquea una celda de Ground.
const RELIC_BLOCK_LAYER_NAMES: Array[String] = [
	"Arboles",
	"Construcciones",
	"construcciones",
	"Muralla",
	"Elevaciones",
	"elevaciones",
]

var hongos_spawned := false
## Texto para el diálogo del viejo, p.ej. "el bosque".
var hint_place: String = "el bosque"

var _target_map_path: String = ""
var _rng := RandomNumberGenerator.new()
var _active_hongos: Node = null


func _ready() -> void:
	_rng.randomize()


func spawn_hongos() -> void:
	if GameState.has_item("hongos") or GameState.quest_hambre_completed:
		return

	_pick_target_map()
	call_deferred("try_spawn_in_current_world")


func clear_pending() -> void:
	_target_map_path = ""
	hongos_spawned = false
	_active_hongos = null


func try_spawn_in_current_world() -> void:
	if _target_map_path.is_empty():
		return
	if not GameState.quest_hambre_active:
		return
	if GameState.has_item("hongos") or GameState.quest_hambre_completed:
		return
	if hongos_spawned and is_instance_valid(_active_hongos):
		return

	var world := _get_current_world()
	if world == null:
		return
	if not _world_matches(world, _target_map_path):
		return

	var pos := _find_walkable_position(world)
	if pos == Vector2.INF:
		push_warning("HongosSpawner: no se encontró celda caminable en %s" % _target_map_path)
		return

	_spawn_at(world, pos)


func _pick_target_map() -> void:
	var pick: Dictionary = MAPS[_rng.randi_range(0, MAPS.size() - 1)]
	_target_map_path = str(pick["path"])
	hint_place = str(pick["hint"])
	hongos_spawned = false
	_active_hongos = null


func _spawn_at(world: Node, pos: Vector2) -> void:
	if hongos_spawned and is_instance_valid(_active_hongos):
		return

	var parent: Node = world.get_node_or_null("InteractiveObjects")
	if parent == null:
		parent = world

	var hongos: Node = HONGOS_SCENE.instantiate()
	parent.add_child(hongos)
	if hongos is Node2D:
		(hongos as Node2D).global_position = pos

	_active_hongos = hongos
	hongos_spawned = true
	hongos.tree_exited.connect(_on_hongos_removed)


func _on_hongos_removed() -> void:
	# El mapa se aparca al viajar; el hongo sigue siendo hijo de ese mundo.
	if is_instance_valid(_active_hongos) and _active_hongos.get_parent() != null:
		return
	hongos_spawned = false
	_active_hongos = null


func _get_current_world() -> Node:
	var main := get_tree().current_scene
	if main == null:
		return null
	return main.get_node_or_null(WORLD_NODE_NAME)


func _world_matches(world: Node, map_path: String) -> bool:
	var path := _resolve_world_scene_path(world)
	if path.is_empty():
		return false
	return path == map_path or path.get_file() == map_path.get_file()


func _resolve_world_scene_path(world: Node) -> String:
	var path := str(world.scene_file_path)
	if not path.is_empty():
		return path
	# Fallback: comparar por nodos típicos de cada mapa.
	if world.get_node_or_null("InteractiveObjects/el_viejo") != null:
		return "res://scenes/world/pantano_world.tscn"
	if world.get_node_or_null("InteractiveObjects/boji") != null:
		return "res://scenes/world/bosque_encantado.tscn"
	if world.get_node_or_null("InteractiveObjects/spinetto") != null \
		or world.get_node_or_null("InteractiveObjects/michis") != null:
		return "res://scenes/world/ciudad_world.tscn"
	return ""


func _find_walkable_position(world: Node) -> Vector2:
	return find_walkable_position(world)


func find_walkable_position(
	world: Node,
	avoid: Array = [],
	min_separation: float = 0.0,
	respect_player: bool = true,
	preferred_layer: String = "",
	block_names: Array = []
) -> Vector2:
	var layers := _collect_tile_layers(world)
	if layers.is_empty():
		return _fallback_away(world, avoid)

	var walk_layer := _pick_walk_layer(layers, preferred_layer)
	if walk_layer == null:
		return _fallback_away(world, avoid)

	var names: Array = block_names if not block_names.is_empty() else BLOCK_LAYER_NAMES
	var block_layers: Array[TileMapLayer] = []
	for layer in layers:
		if layer == walk_layer:
			continue
		if str(layer.name) in names:
			block_layers.append(layer)

	var used: Array[Vector2i] = walk_layer.get_used_cells()
	if used.is_empty():
		return _fallback_away(world, avoid)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var limits := _world_limits(world)
	var attempts := maxi(MAX_ATTEMPTS, avoid.size() * 16)

	for _i in range(attempts):
		var cell: Vector2i = used[_rng.randi_range(0, used.size() - 1)]
		if not _cell_in_inner_bounds(walk_layer, cell):
			continue
		if _cell_blocked(walk_layer, cell, block_layers):
			continue
		var global := walk_layer.to_global(walk_layer.map_to_local(cell))
		if not _accepts_point(global, limits, player, respect_player, avoid, min_separation):
			continue
		if not _physics_clear(world, global):
			continue
		return global

	for _i in range(mini(used.size(), attempts)):
		var cell2: Vector2i = used[_rng.randi_range(0, used.size() - 1)]
		if _cell_blocked(walk_layer, cell2, block_layers):
			continue
		var global2 := walk_layer.to_global(walk_layer.map_to_local(cell2))
		if respect_player and player != null and global2.distance_to(player.global_position) < MIN_PLAYER_DISTANCE:
			continue
		if not _is_separated(global2, avoid, min_separation):
			continue
		return global2

	return _fallback_away(world, avoid)


func _accepts_point(
	point: Vector2,
	limits: Rect2,
	player: Node2D,
	respect_player: bool,
	avoid: Array,
	min_separation: float
) -> bool:
	if not limits.has_point(point):
		return false
	if respect_player and player != null and point.distance_to(player.global_position) < MIN_PLAYER_DISTANCE:
		return false
	return _is_separated(point, avoid, min_separation)


func _is_separated(point: Vector2, avoid: Array, min_separation: float) -> bool:
	if min_separation <= 0.0:
		return true
	for other in avoid:
		if typeof(other) != TYPE_VECTOR2:
			continue
		if point.distance_to(other) < min_separation:
			return false
	return true


func _fallback_away(world: Node, avoid: Array) -> Vector2:
	var fallback := _fallback_position(world)
	fallback.x += float(avoid.size()) * 24.0
	return fallback


func _pick_walk_layer(layers: Array[TileMapLayer], preferred: String = "") -> TileMapLayer:
	if not preferred.is_empty():
		for layer in layers:
			if str(layer.name) == preferred and not layer.get_used_cells().is_empty():
				return layer
	for preferred_name in WALK_LAYER_NAMES:
		for layer in layers:
			if str(layer.name) == preferred_name and not layer.get_used_cells().is_empty():
				return layer
	for layer in layers:
		if not layer.get_used_cells().is_empty():
			return layer
	return null


func _cell_in_inner_bounds(layer: TileMapLayer, cell: Vector2i) -> bool:
	var rect := layer.get_used_rect()
	return (
		cell.x >= rect.position.x + EDGE_MARGIN_CELLS
		and cell.y >= rect.position.y + EDGE_MARGIN_CELLS
		and cell.x < rect.position.x + rect.size.x - EDGE_MARGIN_CELLS
		and cell.y < rect.position.y + rect.size.y - EDGE_MARGIN_CELLS
	)


func _cell_blocked(walk_layer: TileMapLayer, cell: Vector2i, block_layers: Array[TileMapLayer]) -> bool:
	var world_pos := walk_layer.to_global(walk_layer.map_to_local(cell))
	for layer in block_layers:
		var other_cell := layer.local_to_map(layer.to_local(world_pos))
		if layer.get_cell_source_id(other_cell) != -1:
			return true
	return false


func _physics_clear(world: Node, global_pos: Vector2) -> bool:
	if not (world is Node2D):
		return true
	var world_2d: World2D = (world as Node2D).get_world_2d()
	if world_2d == null:
		return true
	var state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	if state == null:
		return true
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_pos
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return state.intersect_point(params, 1).is_empty()


func _world_limits(world: Node) -> Rect2:
	var right := 640
	var bottom := 640
	if world.get("camera_limit_right") != null:
		right = int(world.get("camera_limit_right"))
	if world.get("camera_limit_bottom") != null:
		bottom = int(world.get("camera_limit_bottom"))
	return Rect2(Vector2.ZERO, Vector2(float(right), float(bottom)))


func _fallback_position(world: Node) -> Vector2:
	var limits := _world_limits(world)
	return limits.get_center()


func _collect_tile_layers(node: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	_collect_tile_layers_into(node, out)
	return out


func _collect_tile_layers_into(node: Node, out: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		out.append(node as TileMapLayer)
	for child in node.get_children():
		_collect_tile_layers_into(child, out)
