extends Node2D

const MAX_RESIDUE_NODES := 80
const RESIDUE_TEXTURE := preload("res://assets/tilesets/Basic Grass Biom things 1.png")
var world_state: Node = null

func _ready():
	z_index = 20
	world_state = get_node_or_null("/root/WorldState")
	if world_state:
		world_state.world_day_changed.connect(_on_world_shifted)
		world_state.world_state_changed.connect(_on_world_shifted)
	_rebuild_residue()

func _on_world_shifted(_value = null):
	_rebuild_residue()

func _rebuild_residue():
	for child in get_children():
		child.queue_free()

	if not world_state:
		return

	var residue_count: int = min(int(world_state.accumulation_level), MAX_RESIDUE_NODES)
	for i in range(residue_count):
		var sprite := Sprite2D.new()
		sprite.texture = _build_residue_texture(i)
		sprite.position = _build_residue_position(i)
		sprite.rotation = _build_residue_rotation(i)
		sprite.scale = Vector2.ONE * _build_residue_scale(i)
		sprite.modulate = _build_residue_color(i)
		add_child(sprite)

func _build_residue_texture(index: int) -> AtlasTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_state.residue_seed) + index * 7919

	var atlas := AtlasTexture.new()
	atlas.atlas = RESIDUE_TEXTURE
	var cell_x := rng.randi_range(0, 5) * 16
	var cell_y := rng.randi_range(0, 3) * 16
	atlas.region = Rect2(cell_x, cell_y, 16, 16)
	return atlas

func _build_residue_position(index: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_state.residue_seed) + index * 1543

	var x := rng.randf_range(-700.0, 250.0)
	var y := rng.randf_range(-1150.0, 120.0)
	return Vector2(x, y)

func _build_residue_rotation(index: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_state.residue_seed) + index * 2281
	return rng.randf_range(-0.6, 0.6)

func _build_residue_scale(index: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_state.residue_seed) + index * 3571
	return rng.randf_range(0.75, 1.5)

func _build_residue_color(index: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_state.residue_seed) + index * 9901

	var decay: float = world_state.get_decay_factor()
	var tint: float = rng.randf_range(0.6, 0.95) - decay * 0.25
	return Color(tint, tint * 0.92, tint * 0.88, 0.85)
