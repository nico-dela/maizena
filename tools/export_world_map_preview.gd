extends SceneTree

const WORLD_SCENE := "res://scenes/world.scn"
const OUTPUT_PATH := "res://assets/ui/world_map_preview.png"
const PREVIEW_SIZE := 512

var _viewport: SubViewport


func _initialize() -> void:
	var packed := load(WORLD_SCENE) as PackedScene
	if packed == null:
		push_error("No se pudo cargar %s" % WORLD_SCENE)
		quit(1)
		return

	var world := packed.instantiate()
	_prepare_world(world)

	var bounds := _collect_tilemap_bounds(world)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		push_error("No se encontraron tiles en el mapa")
		world.free()
		quit(1)
		return

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PREVIEW_SIZE, PREVIEW_SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

	var holder := Node2D.new()
	_viewport.add_child(holder)
	holder.add_child(world)

	var margin := 0.88
	var scale_factor := minf(
		float(PREVIEW_SIZE) / bounds.size.x,
		float(PREVIEW_SIZE) / bounds.size.y
	) * margin
	holder.scale = Vector2(scale_factor, scale_factor)
	holder.position = Vector2(PREVIEW_SIZE, PREVIEW_SIZE) * 0.5 - bounds.get_center() * scale_factor

	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_capture)
	root.add_child(_viewport)
	root.add_child(timer)


func _capture() -> void:
	var tex := _viewport.get_texture()
	if tex == null:
		push_error("No se pudo renderizar la vista previa del mapa")
		quit(1)
		return

	var img := tex.get_image()
	if img == null or img.is_empty():
		push_error("No se pudo leer la imagen del viewport")
		quit(1)
		return

	var err := img.save_png(OUTPUT_PATH)
	if err != OK:
		push_error("No se pudo guardar %s (%s)" % [OUTPUT_PATH, error_string(err)])
		quit(1)
		return

	print("OK preview=%s size=%s" % [OUTPUT_PATH, str(img.get_size())])
	quit()


func _prepare_world(node: Node) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			(child as CanvasItem).visible = true
			child.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			if child is CanvasItem:
				(child as CanvasItem).visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED
			_prepare_world(child)


func _collect_tilemap_bounds(root: Node) -> Rect2:
	var merged := Rect2()
	var has_rect := false
	for layer in _find_tilemap_layers(root):
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size := layer.tile_set.tile_size if layer.tile_set else Vector2i(16, 16)
		var local_rect := Rect2(
			Vector2(used.position) * Vector2(tile_size),
			Vector2(used.size) * Vector2(tile_size)
		)
		var layer_rect := layer.global_transform * local_rect
		if has_rect:
			merged = merged.merge(layer_rect)
		else:
			merged = layer_rect
			has_rect = true
	return merged if has_rect else Rect2()


func _find_tilemap_layers(node: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	if node is TileMapLayer:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_tilemap_layers(child))
	return out
