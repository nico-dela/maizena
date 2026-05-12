extends Node2D

const MAX_RESIDUE_NODES := 80
const CELL := 16
const RESIDUE_TEXTURE := preload("res://assets/tilesets/Basic Grass Biom things 1.png")
const WORLD_PROPS_DIR := "res://assets/world_props"

var world_state: Node = null
## Celdas 16×16 recortadas de los PNG en `assets/world_props/`. Si está vacío, se usa el tileset legacy.
var _world_prop_variants: Array[AtlasTexture] = []


func _ready() -> void:
	z_index = 20
	world_state = get_node_or_null("/root/WorldState")
	_load_world_prop_sources()
	if world_state:
		world_state.world_day_changed.connect(_on_world_shifted)
		world_state.world_state_changed.connect(_on_world_shifted)
	_rebuild_residue()


func _load_world_prop_sources() -> void:
	_world_prop_variants.clear()
	var d := DirAccess.open(WORLD_PROPS_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if d.current_is_dir() or fname.begins_with("."):
			fname = d.get_next()
			continue
		if not fname.to_lower().ends_with(".png"):
			fname = d.get_next()
			continue
		var path := WORLD_PROPS_DIR.path_join(fname)
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			push_warning("WorldResidueSystem: no se pudo cargar %s" % path)
			fname = d.get_next()
			continue
		_append_texture_as_16_cells(tex, path)
		fname = d.get_next()
	d.list_dir_end()


func _append_texture_as_16_cells(tex: Texture2D, path_for_log: String) -> void:
	var sz := tex.get_size()
	var w := int(sz.x)
	var h := int(sz.y)
	if w < CELL or h < CELL:
		push_warning("WorldResidueSystem: %s es más chico que %d×%d px, se omite." % [path_for_log, CELL, CELL])
		return
	if w % CELL != 0 or h % CELL != 0:
		push_warning(
			"WorldResidueSystem: %s debe tener ancho y alto múltiplos de %d (tamaño %d×%d). Se omite." % [path_for_log, CELL, w, h]
		)
		return
	for cy in range(0, h, CELL):
		for cx in range(0, w, CELL):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(cx, cy, CELL, CELL)
			_world_prop_variants.append(atlas)


func _on_world_shifted(_value = null) -> void:
	_rebuild_residue()


func _rebuild_residue() -> void:
	for child in get_children():
		child.queue_free()

	if not world_state:
		return

	var residue_count: int = mini(int(world_state.accumulation_level), MAX_RESIDUE_NODES)
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

	if not _world_prop_variants.is_empty():
		var pick: int = rng.randi_range(0, _world_prop_variants.size() - 1)
		return _world_prop_variants[pick].duplicate() as AtlasTexture

	var atlas := AtlasTexture.new()
	atlas.atlas = RESIDUE_TEXTURE
	var cell_x := rng.randi_range(0, 5) * CELL
	var cell_y := rng.randi_range(0, 3) * CELL
	atlas.region = Rect2(cell_x, cell_y, CELL, CELL)
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
