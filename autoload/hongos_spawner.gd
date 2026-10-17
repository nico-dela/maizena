extends Node

## Spawnea hongos en un mapa al azar, sobre tiles caminables (Ground/Caminos).

const HONGOS_SCENE := preload("res://scenes/entities/props/hongos/hongos.tscn")
const WORLD_NODE_NAME := "NewWorld"
const MAX_ATTEMPTS := 48
const EDGE_MARGIN_CELLS := 2
const MIN_PLAYER_DISTANCE := 96.0
## Mismo círculo que CollisionShape2D de Sanjin.
const BODY_OFFSET := Vector2(0, -6)
const BODY_RADIUS := 7.0
const REACH_NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
]

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
## Capas sólidas para el hongo. Comparación en minúsculas, incluye la cima y el acantilado.
const STRICT_BLOCK_LAYER_NAMES: Array[String] = [
	"agua",
	"arboles",
	"construcciones",
	"muralla",
	"elevaciones",
	"cascada",
	"cima",
	"bajo elevaciones",
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
var _body_shape := CircleShape2D.new()
var _reach_world_id := 0
var _reach_points: Array[Vector2] = []


func _ready() -> void:
	_rng.randomize()
	_body_shape.radius = BODY_RADIUS


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
	return find_walkable_position(world, [], 0.0, true, "", [], true)


func clear_reach_cache() -> void:
	_reach_world_id = 0
	_reach_points = []


## Celdas donde entra el cuerpo del jugador y que conectan con su posición.
func reachable_points(world: Node) -> Array[Vector2]:
	if world == null:
		return []
	var world_id := world.get_instance_id()
	if world_id == _reach_world_id and not _reach_points.is_empty():
		return _reach_points
	var built := _build_reachable_points(world)
	if built.is_empty():
		return []
	_reach_world_id = world_id
	_reach_points = built
	return _reach_points


func has_reachable_point(points: Array[Vector2], point: Vector2) -> bool:
	for candidate in points:
		if candidate.distance_squared_to(point) <= 16.0:
			return true
	return false


func pick_reachable(points: Array[Vector2], avoid: Array, min_separation: float) -> Vector2:
	var separated := _first_reachable(points, avoid, min_separation, true)
	if separated != Vector2.INF:
		return separated
	return _first_reachable(points, avoid, 0.0, false)


func _first_reachable(
	points: Array[Vector2],
	avoid: Array,
	min_separation: float,
	respect_player: bool
) -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var order: Array[Vector2] = points.duplicate()
	order.shuffle()
	for point in order:
		if _player_too_close(point, player, respect_player):
			continue
		if not _is_separated(point, avoid, min_separation):
			continue
		return point
	return Vector2.INF


func _player_too_close(point: Vector2, player: Node2D, respect_player: bool) -> bool:
	if not respect_player or player == null:
		return false
	return point.distance_to(player.global_position) < MIN_PLAYER_DISTANCE


func _build_reachable_points(world: Node) -> Array[Vector2]:
	if not _blocking_collision_live(world):
		return []
	var layers := _walk_layers(world)
	if layers.is_empty():
		return []
	var open := _cells_player_can_stand(world, layers, _world_limits(world))
	return _connected_points(layers[0], open)


func _blocking_collision_live(world: Node) -> bool:
	if _space_state(world) == null:
		return false
	var saw_cells := false
	for layer_name in ["AguaCollision", "BuildingCollision", "Arboles", "Muralla"]:
		var probe := _layer_named(world, layer_name)
		if probe == null:
			continue
		var verdict := _probe_blocks(world, probe)
		if verdict == 1:
			return true
		if verdict == 0:
			saw_cells = true
	return not saw_cells


## 1 si un sólido ya choca, 0 si hay celdas pero ninguna choca, -1 si la capa está vacía.
func _probe_blocks(world: Node, probe: TileMapLayer) -> int:
	var samples := 0
	for cell in probe.get_used_cells():
		var pos := probe.to_global(probe.map_to_local(cell))
		if not _body_fits(world, pos):
			return 1
		samples += 1
		if samples >= 24:
			return 0
	return -1


func _layer_named(world: Node, layer_name: String) -> TileMapLayer:
	var wanted := layer_name.to_lower()
	for layer in _collect_tile_layers(world):
		if str(layer.name).to_lower() == wanted:
			return layer
	return null


func _walk_layers(world: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	for layer in _collect_tile_layers(world):
		if str(layer.name) in WALK_LAYER_NAMES:
			found.append(layer)
	return found


func _cells_player_can_stand(world: Node, layers: Array[TileMapLayer], limits: Rect2) -> Dictionary:
	var grid := layers[0]
	var open := {}
	for layer in layers:
		for cell in layer.get_used_cells():
			var pos := layer.to_global(layer.map_to_local(cell))
			if not limits.has_point(pos) or not _body_fits(world, pos):
				continue
			open[grid.local_to_map(grid.to_local(pos))] = pos
	return open


func _connected_points(grid: TileMapLayer, open: Dictionary) -> Array[Vector2]:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or open.is_empty():
		return []
	var start_cell: Variant = _seed_cell(grid, open, player.global_position)
	if start_cell == null:
		return []
	return _flood_open(open, start_cell as Vector2i)


func _seed_cell(grid: TileMapLayer, open: Dictionary, origin: Vector2) -> Variant:
	var direct := grid.local_to_map(grid.to_local(origin))
	if open.has(direct):
		return direct
	var reach := _seed_reach(grid)
	var best: Variant = null
	var best_dist := reach
	for key in open.keys():
		var dist: float = origin.distance_to(open[key])
		if dist > best_dist:
			continue
		best_dist = dist
		best = key
	return best


func _seed_reach(grid: TileMapLayer) -> float:
	var span := 16.0
	if grid.tile_set != null:
		span = maxf(grid.tile_set.tile_size.x, grid.tile_set.tile_size.y)
	return span * 2.0


func _flood_open(open: Dictionary, start: Vector2i) -> Array[Vector2]:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var points: Array[Vector2] = []
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		points.append(open[cell])
		_enqueue_steps(open, seen, queue, cell)
	return points


func _enqueue_steps(
	open: Dictionary,
	seen: Dictionary,
	queue: Array[Vector2i],
	cell: Vector2i
) -> void:
	for step in REACH_NEIGHBORS:
		var next: Vector2i = cell + step
		if seen.has(next) or not open.has(next):
			continue
		seen[next] = true
		queue.append(next)


func find_walkable_position(
	world: Node,
	avoid: Array = [],
	min_separation: float = 0.0,
	respect_player: bool = true,
	preferred_layer: String = "",
	block_names: Array = [],
	strict: bool = false
) -> Vector2:
	var found := _search_walkable(
		world, avoid, min_separation, respect_player, preferred_layer, block_names, strict
	)
	if found != Vector2.INF:
		return found
	if strict:
		return Vector2.INF
	return _fallback_away(world, avoid)


func _search_walkable(
	world: Node,
	avoid: Array,
	min_separation: float,
	respect_player: bool,
	preferred_layer: String,
	block_names: Array,
	strict: bool
) -> Vector2:
	var query := _make_query(
		world, avoid, min_separation, respect_player, preferred_layer, block_names, strict
	)
	if query == null:
		return Vector2.INF
	var used: Array[Vector2i] = query.walk_layer.get_used_cells()
	var attempts := maxi(MAX_ATTEMPTS, avoid.size() * 16)
	var picked := _random_cell(query, used, attempts, true)
	if picked != Vector2.INF:
		return picked
	if query.strict:
		return _scan_cells(query, used)
	return _random_cell(query, used, mini(used.size(), attempts), false)


func _make_query(
	world: Node,
	avoid: Array,
	min_separation: float,
	respect_player: bool,
	preferred_layer: String,
	block_names: Array,
	strict: bool
) -> WalkQuery:
	var layers := _collect_tile_layers(world)
	if layers.is_empty():
		return null
	var walk_layer := _pick_walk_layer(layers, preferred_layer)
	if walk_layer == null or walk_layer.get_used_cells().is_empty():
		return null
	var query := WalkQuery.new()
	query.world = world
	query.walk_layer = walk_layer
	query.block_layers = _block_layers(layers, walk_layer, block_names, strict)
	query.limits = _world_limits(world)
	query.player = get_tree().get_first_node_in_group("player") as Node2D
	query.respect_player = respect_player
	query.avoid = avoid
	query.min_separation = min_separation
	query.strict = strict
	return query


func _block_layers(
	layers: Array[TileMapLayer],
	walk_layer: TileMapLayer,
	names: Array,
	strict: bool
) -> Array[TileMapLayer]:
	var wanted: Array = STRICT_BLOCK_LAYER_NAMES if strict else _resolved_block_names(names)
	var blocked: Array[TileMapLayer] = []
	for layer in layers:
		if layer == walk_layer:
			continue
		if _layer_blocks(str(layer.name), wanted, strict):
			blocked.append(layer)
	return blocked


func _resolved_block_names(names: Array) -> Array:
	if names.is_empty():
		return BLOCK_LAYER_NAMES
	return names


func _layer_blocks(layer_name: String, names: Array, strict: bool) -> bool:
	if not strict:
		return layer_name in names
	var lowered := layer_name.to_lower()
	for blocked in names:
		if lowered == str(blocked):
			return true
	return false


func _random_cell(
	query: WalkQuery,
	used: Array[Vector2i],
	attempts: int,
	full_checks: bool
) -> Vector2:
	for _i in range(attempts):
		var cell: Vector2i = used[_rng.randi_range(0, used.size() - 1)]
		var pos := _accept_cell(query, cell, full_checks)
		if pos != Vector2.INF:
			return pos
	return Vector2.INF


func _scan_cells(query: WalkQuery, used: Array[Vector2i]) -> Vector2:
	var start := _rng.randi_range(0, used.size() - 1)
	for offset in used.size():
		var cell: Vector2i = used[(start + offset) % used.size()]
		var pos := _accept_cell(query, cell, true)
		if pos != Vector2.INF:
			return pos
	return Vector2.INF


func _accept_cell(query: WalkQuery, cell: Vector2i, full_checks: bool) -> Vector2:
	if full_checks and not _cell_in_inner_bounds(query.walk_layer, cell):
		return Vector2.INF
	if _cell_blocked(query.walk_layer, cell, query.block_layers):
		return Vector2.INF
	var pos := query.walk_layer.to_global(query.walk_layer.map_to_local(cell))
	if not full_checks:
		return _accept_loose(query, pos)
	if not _accepts_point(pos, query.limits, query.player, query.respect_player, query.avoid, query.min_separation):
		return Vector2.INF
	if not _feet_clear(query.world, pos, query.strict):
		return Vector2.INF
	return pos


func _accept_loose(query: WalkQuery, pos: Vector2) -> Vector2:
	if query.respect_player and query.player != null and pos.distance_to(query.player.global_position) < MIN_PLAYER_DISTANCE:
		return Vector2.INF
	if not _is_separated(pos, query.avoid, query.min_separation):
		return Vector2.INF
	return pos


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


func _feet_clear(world: Node, feet: Vector2, strict: bool) -> bool:
	if strict:
		return _body_fits(world, feet)
	return _physics_clear(world, feet)


func _body_fits(world: Node, feet: Vector2) -> bool:
	var state := _space_state(world)
	if state == null:
		return true
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _body_shape
	params.transform = Transform2D(0.0, feet + BODY_OFFSET)
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = _player_exclude()
	return state.intersect_shape(params, 1).is_empty()


func _player_exclude() -> Array[RID]:
	var exclude: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player") as CollisionObject2D
	if player != null:
		exclude.append(player.get_rid())
	return exclude


func _physics_clear(world: Node, global_pos: Vector2) -> bool:
	var state := _space_state(world)
	if state == null:
		return true
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_pos
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return state.intersect_point(params, 1).is_empty()


func _space_state(world: Node) -> PhysicsDirectSpaceState2D:
	if not (world is Node2D):
		return null
	var world_2d: World2D = (world as Node2D).get_world_2d()
	if world_2d == null:
		return null
	return world_2d.direct_space_state


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


class WalkQuery:
	var world: Node
	var walk_layer: TileMapLayer
	var block_layers: Array[TileMapLayer] = []
	var limits: Rect2
	var player: Node2D
	var respect_player: bool
	var avoid: Array = []
	var min_separation: float
	var strict: bool
