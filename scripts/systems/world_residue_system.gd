extends Node2D

const CELL := 16
const ALLOWED_PROP_SIZES := [16, 24, 32, 48]
const REBOOT_DELAY := 2.0
const WALK_LAYERS: Array[String] = ["caminos", "ground"]
const BLOCK_LAYERS: Array[String] = ["agua", "arboles", "construcciones", "muralla", "sombras agua"]

const SCALE_RANGES := {
	16: Vector2(0.75, 1.5),
	24: Vector2(0.6, 1.1),
	32: Vector2(0.5, 0.9),
	48: Vector2(0.4, 0.75),
}

## Lista explícita: en web, DirAccess sobre res:// a menudo solo ve `.import`.
const WORLD_PROP_PATHS: Array[String] = [
	"res://assets/art/props/Lentes.png",
	"res://assets/art/props/Maceta_flor.png",
	"res://assets/art/props/chupetin.png",
	"res://assets/art/props/ford_sierra.png",
	"res://assets/art/props/futbol.png",
	"res://assets/art/props/remera1.png",
	"res://assets/art/props/sillon_roto.png",
	"res://assets/art/props/saturation/ball_basket.png",
	"res://assets/art/props/saturation/ball_soccer.png",
	"res://assets/art/props/saturation/ball_tennis.png",
	"res://assets/art/props/saturation/ball_volley.png",
	"res://assets/art/props/saturation/book.png",
	"res://assets/art/props/saturation/bottle.png",
	"res://assets/art/props/saturation/bottle_blue.png",
	"res://assets/art/props/saturation/bottle_green.png",
	"res://assets/art/props/saturation/bowl.png",
	"res://assets/art/props/saturation/bush.png",
	"res://assets/art/props/saturation/bush_round.png",
	"res://assets/art/props/saturation/chair.png",
	"res://assets/art/props/saturation/chest.png",
	"res://assets/art/props/saturation/chicken.png",
	"res://assets/art/props/saturation/crate.png",
	"res://assets/art/props/saturation/crate_small.png",
	"res://assets/art/props/saturation/cup.png",
	"res://assets/art/props/saturation/cushion.png",
	"res://assets/art/props/saturation/flower_orange.png",
	"res://assets/art/props/saturation/flower_purple.png",
	"res://assets/art/props/saturation/flower_white.png",
	"res://assets/art/props/saturation/fruit.png",
	"res://assets/art/props/saturation/hood.png",
	"res://assets/art/props/saturation/mushroom.png",
	"res://assets/art/props/saturation/mushroom_red.png",
	"res://assets/art/props/saturation/pot.png",
	"res://assets/art/props/saturation/roast.png",
	"res://assets/art/props/saturation/sack.png",
	"res://assets/art/props/saturation/sack_open.png",
	"res://assets/art/props/saturation/salad.png",
	"res://assets/art/props/saturation/stool.png",
]

var world_state: Node = null
## { texture: Texture2D, base_size: int }
var _world_prop_variants: Array[Dictionary] = []
var _warned_empty_props := false
var _reboot_queued := false


func _ready() -> void:
	z_index = 20
	world_state = get_node_or_null("/root/WorldState")
	_load_world_prop_sources()
	if world_state and not world_state.world_day_changed.is_connected(_on_world_shifted):
		world_state.world_day_changed.connect(_on_world_shifted)
	call_deferred("_rebuild_residue")


func _load_world_prop_sources() -> void:
	_world_prop_variants.clear()
	for path in WORLD_PROP_PATHS:
		_try_append_prop_path(path)


func _try_append_prop_path(path: String) -> void:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("WorldResidueSystem: no se pudo cargar %s" % path)
		return
	var sz := tex.get_size()
	var side := int(sz.x)
	if int(sz.y) != side or side not in ALLOWED_PROP_SIZES:
		push_warning("WorldResidueSystem: %s debe ser cuadrado de %s px." % [path, str(ALLOWED_PROP_SIZES)])
		return
	_world_prop_variants.append({"texture": tex, "base_size": side})


func _on_world_shifted(_value = null) -> void:
	_rebuild_residue()


func _rebuild_residue() -> void:
	_clear_props()
	if world_state == null or _world_prop_variants.is_empty():
		_warn_if_empty()
		return
	var points := _walk_points()
	if points.is_empty():
		points = _fallback_points()
	var residue_count: int = mini(int(world_state.accumulation_level), int(WorldState.RESIDUE_CAP))
	for i in range(residue_count):
		_spawn_prop(i, points)
	if residue_count >= int(WorldState.RESIDUE_CAP):
		_queue_reboot()


func _warn_if_empty() -> void:
	if _world_prop_variants.is_empty() and not _warned_empty_props:
		_warned_empty_props = true
		push_warning("WorldResidueSystem: no hay props válidos")


func _clear_props() -> void:
	var kids := get_children()
	for child in kids:
		child.free()


func _walk_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var world := get_parent()
	if world == null:
		return points
	var blocked := _blocked_keys(world)
	for layer in _tile_layers(world):
		if str(layer.name).to_lower() not in WALK_LAYERS:
			continue
		_append_open_cells(layer, blocked, points)
	return points


func _append_open_cells(layer: TileMapLayer, blocked: Dictionary, points: Array[Vector2]) -> void:
	for cell in layer.get_used_cells():
		var global_pos: Vector2 = layer.to_global(layer.map_to_local(cell))
		if blocked.has(_cell_key(global_pos)):
			continue
		points.append(to_local(global_pos))


func _blocked_keys(world: Node) -> Dictionary:
	var blocked := {}
	for layer in _tile_layers(world):
		if str(layer.name).to_lower() not in BLOCK_LAYERS:
			continue
		for cell in layer.get_used_cells():
			var global_pos: Vector2 = layer.to_global(layer.map_to_local(cell))
			blocked[_cell_key(global_pos)] = true
	return blocked


func _tile_layers(node: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	if node is TileMapLayer:
		out.append(node)
	for child in node.get_children():
		if child == self:
			continue
		out.append_array(_tile_layers(child))
	return out


func _cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(int(round(pos.x / float(CELL))), int(round(pos.y / float(CELL))))


func _fallback_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var world := get_parent() as Node2D
	if world == null:
		return points
	var right := float(world.get("camera_limit_right"))
	var bottom := float(world.get("camera_limit_bottom"))
	var x := float(CELL)
	while x < right:
		var y := float(CELL)
		while y < bottom:
			points.append(to_local(world.to_global(Vector2(x, y))))
			y += float(CELL) * 2.0
		x += float(CELL) * 2.0
	return points


func _spawn_prop(index: int, points: Array[Vector2]) -> void:
	var prop := _pick_prop(index)
	var body := StaticBody2D.new()
	body.position = _pick_point(index, points)
	var sprite := _make_sprite(index, prop)
	body.add_child(sprite)
	body.add_child(_make_shape(int(prop["base_size"]), sprite.scale.x))
	add_child(body)


func _make_sprite(index: int, prop: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = prop["texture"]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.rotation = _build_rotation(index)
	sprite.scale = Vector2.ONE * _build_scale(index, int(prop["base_size"]))
	sprite.modulate = _build_color(index)
	return sprite


func _make_shape(base_size: int, sprite_scale: float) -> CollisionShape2D:
	var circle := CircleShape2D.new()
	circle.radius = clampf(float(base_size) * sprite_scale * 0.35, 6.0, 14.0)
	var shape := CollisionShape2D.new()
	shape.shape = circle
	return shape


func _pick_prop(index: int) -> Dictionary:
	var rng := _rng(index, 7919)
	return _world_prop_variants[rng.randi_range(0, _world_prop_variants.size() - 1)]


func _pick_point(index: int, points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var rng := _rng(index, 1543)
	return points[rng.randi_range(0, points.size() - 1)]


func _build_rotation(index: int) -> float:
	return _rng(index, 2281).randf_range(-0.6, 0.6)


func _build_scale(index: int, base_size: int) -> float:
	var range_v: Vector2 = SCALE_RANGES.get(base_size, SCALE_RANGES[16])
	return _rng(index, 3571).randf_range(range_v.x, range_v.y)


func _build_color(index: int) -> Color:
	var decay: float = 0.0
	if world_state != null and world_state.has_method("get_decay_factor"):
		decay = float(world_state.get_decay_factor())
	var tint: float = _rng(index, 9901).randf_range(0.6, 0.95) - decay * 0.25
	return Color(tint, tint * 0.92, tint * 0.88, 0.85)


func _rng(index: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var seed_value := 1337
	if world_state != null:
		seed_value = int(world_state.residue_seed)
	rng.seed = seed_value + index * salt
	return rng


func _queue_reboot() -> void:
	if _reboot_queued or get_parent() == null or get_parent().name != "NewWorld":
		return
	_reboot_queued = true
	get_tree().create_timer(REBOOT_DELAY).timeout.connect(_reboot_guest)


func _reboot_guest() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var reload := scene.get_node_or_null("FestReload")
	if reload != null and reload.has_method("reload_guest"):
		reload.call("reload_guest")
