extends SceneTree

const WORLD_SCENE := "res://scenes/world.tscn"
const TILESET_DIR := "res://scenes/world_resources"
const OUTPUT_SCENE := "res://scenes/world.scn"


func _initialize() -> void:
	var packed := ResourceLoader.load(WORLD_SCENE) as PackedScene
	if packed == null:
		push_error("No se pudo cargar %s" % WORLD_SCENE)
		quit(1)
		return

	var root := packed.instantiate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TILESET_DIR))

	var unique_tilesets: Array[TileSet] = []
	_assign_external_tilesets(root, unique_tilesets)

	var exported := PackedScene.new()
	var pack_err := exported.pack(root)
	root.free()
	if pack_err != OK:
		push_error("No se pudo empaquetar la escena (%s)" % error_string(pack_err))
		quit(1)
		return

	var err := ResourceSaver.save(exported, OUTPUT_SCENE)
	if err != OK:
		push_error("No se pudo guardar %s (%s)" % [OUTPUT_SCENE, error_string(err)])
		quit(1)
		return

	print("OK tilesets=%d bytes_scn=%s" % [unique_tilesets.size(), OUTPUT_SCENE])
	quit()


func _assign_external_tilesets(node: Node, unique_tilesets: Array[TileSet]) -> void:
	var tile_set: TileSet = null
	if node is TileMapLayer:
		tile_set = (node as TileMapLayer).tile_set
	elif node is TileMap:
		tile_set = (node as TileMap).tile_set

	if tile_set != null:
		var path := _save_unique_tileset(tile_set, unique_tilesets)
		if node is TileMapLayer:
			(node as TileMapLayer).tile_set = load(path)
		elif node is TileMap:
			(node as TileMap).tile_set = load(path)

	for child in node.get_children():
		_assign_external_tilesets(child, unique_tilesets)


func _save_unique_tileset(tile_set: TileSet, unique_tilesets: Array[TileSet]) -> String:
	for i in unique_tilesets.size():
		if unique_tilesets[i] == tile_set:
			return "%s/world_tileset_%d.tres" % [TILESET_DIR, i + 1]

	unique_tilesets.append(tile_set)
	var index := unique_tilesets.size()
	var path := "%s/world_tileset_%d.tres" % [TILESET_DIR, index]
	var err := ResourceSaver.save(tile_set, path)
	if err != OK:
		push_error("No se pudo guardar %s" % path)
	return path
