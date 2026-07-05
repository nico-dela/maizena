extends Control

const BASE_MAP_SIZE := 132.0
const SCREEN_MARGIN := 14.0
const FIT_MARGIN := 1.12
const WATER_LAYER_AREA_RATIO := 0.82
const BASE_DOT_SIZE := 6.0
const BOCETO_NAME := "BOCETO"
const NEW_WORLD_NAME := "NewWorld"

@onready var _frame: PanelContainer = $Frame
@onready var _map_stack: Control = $Frame/MapStack
@onready var _subviewport: SubViewport = $Frame/MapStack/ViewportBox/SubViewport
@onready var _player_dot: ColorRect = $Frame/MapStack/PlayerDot

var _player: Node2D
var _world_bounds := Rect2()
var _cam_zoom := 1.0
var _frame_style: StyleBoxFlat
var _map_ready := false
var _minimap_camera: Camera2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subviewport.transparent_bg = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_subviewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_player_dot.color = Color(0.95, 0.28, 0.35, 1.0)
	_style_frame()
	ViewportLayout.layout_changed.connect(_on_layout_changed)
	call_deferred("_setup_minimap")


func _process(_delta: float) -> void:
	_update_player_dot()


func _on_layout_changed() -> void:
	_apply_layout()
	if _map_ready:
		_configure_camera()


func _setup_minimap() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

	var boceto_ref := _get_boceto_ref()
	if boceto_ref == null:
		await get_tree().process_frame
		boceto_ref = _get_boceto_ref()
	if boceto_ref == null:
		push_warning("Minimap: no se encontró el nodo BOCETO en la escena")
		return

	_world_bounds = _collect_tilemap_bounds(boceto_ref)
	if _world_bounds.size == Vector2.ZERO:
		push_warning("Minimap: BOCETO no tiene tiles")
		return

	_subviewport.world_2d = get_viewport().world_2d

	_minimap_camera = Camera2D.new()
	_minimap_camera.enabled = true
	_subviewport.add_child(_minimap_camera)

	_map_ready = true
	_apply_layout()
	await get_tree().process_frame
	_configure_camera()


func _get_boceto_ref() -> Node2D:
	var game_root := _get_game_root()
	if game_root == null:
		return null

	var new_world := game_root.get_node_or_null(NEW_WORLD_NAME)
	if new_world != null:
		var boceto := new_world.get_node_or_null(BOCETO_NAME)
		if boceto is Node2D:
			return boceto as Node2D

	return _find_node_by_name(game_root, BOCETO_NAME) as Node2D


func _get_game_root() -> Node:
	var ui_layer := get_parent()
	if ui_layer != null and ui_layer.get_parent() != null:
		return ui_layer.get_parent()
	return get_tree().current_scene


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _configure_camera() -> void:
	if not _map_ready or _world_bounds.size == Vector2.ZERO or _minimap_camera == null:
		return

	var map_pixels := _map_stack.custom_minimum_size
	if map_pixels.x <= 1.0 or map_pixels.y <= 1.0:
		return

	var vp_size := Vector2i(maxi(1, int(map_pixels.x)), maxi(1, int(map_pixels.y)))
	if _subviewport.size != vp_size:
		_subviewport.size = vp_size

	_cam_zoom = minf(
		map_pixels.x / (_world_bounds.size.x * FIT_MARGIN),
		map_pixels.y / (_world_bounds.size.y * FIT_MARGIN)
	)
	_minimap_camera.position = _world_bounds.get_center()
	_minimap_camera.zoom = Vector2(_cam_zoom, _cam_zoom)


func _apply_layout() -> void:
	ViewportLayout.refresh()
	var s := ViewportLayout.effective_ui_scale()
	var layout := ViewportLayout.visible_layout_size()
	var margin_right := ViewportLayout.screen_margin_right(SCREEN_MARGIN)
	var margin_bottom := ViewportLayout.screen_margin_bottom(SCREEN_MARGIN)
	var map_side := maxf(BASE_MAP_SIZE * s, 96.0 * s)
	var frame_pad := int(round(6.0 * s))

	_map_stack.custom_minimum_size = Vector2(map_side, map_side)
	var dot_size := clampf(BASE_DOT_SIZE * s, 4.0, 10.0)
	_player_dot.custom_minimum_size = Vector2.ZERO
	_player_dot.size = Vector2(dot_size, dot_size)

	if _frame_style != null:
		_frame_style.content_margin_left = frame_pad
		_frame_style.content_margin_top = frame_pad
		_frame_style.content_margin_right = frame_pad
		_frame_style.content_margin_bottom = frame_pad
		_frame_style.set_border_width_all(maxi(2, int(round(2.0 * s))))
		_frame_style.set_corner_radius_all(maxi(4, int(round(6.0 * s))))

	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = -margin_right
	offset_bottom = -margin_bottom
	var frame_size := _frame.get_combined_minimum_size()
	offset_left = -margin_right - frame_size.x
	offset_top = -margin_bottom - frame_size.y

	var settings := get_tree().get_first_node_in_group("settings_menu")
	if settings != null and settings.has_node("Button"):
		var settings_btn: Control = settings.get_node("Button")
		var settings_rect := settings_btn.get_global_rect()
		var minimap_rect := Rect2(
			layout.x - margin_right - frame_size.x,
			layout.y - margin_bottom - frame_size.y,
			frame_size.x,
			frame_size.y
		)
		if minimap_rect.intersects(settings_rect):
			offset_top -= settings_rect.size.y + 8.0 * s
			offset_bottom -= settings_rect.size.y + 8.0 * s

	if _map_ready:
		_configure_camera()


func _style_frame() -> void:
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color(0.04, 0.06, 0.12, 0.78)
	_frame_style.border_color = Color(0.35, 0.78, 0.96, 0.72)
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(6)
	_frame.add_theme_stylebox_override("panel", _frame_style)


func _update_player_dot() -> void:
	if _player == null or _world_bounds.size == Vector2.ZERO or not _map_ready:
		_player_dot.visible = false
		return

	var map_size := _map_stack.custom_minimum_size
	if map_size.x <= 1.0 or map_size.y <= 1.0:
		return

	_player_dot.visible = true
	var local_pos := _world_to_minimap(_player.global_position, map_size)
	local_pos.x = clampf(local_pos.x, 0.0, map_size.x)
	local_pos.y = clampf(local_pos.y, 0.0, map_size.y)
	_player_dot.position = local_pos - _player_dot.size * 0.5


func _world_to_minimap(world_pos: Vector2, map_size: Vector2) -> Vector2:
	if _cam_zoom <= 0.0:
		return map_size * 0.5
	var center := _world_bounds.get_center()
	var world_half := map_size / (2.0 * _cam_zoom)
	var rel := world_pos - center
	return map_size * 0.5 + Vector2(rel.x / world_half.x, rel.y / world_half.y) * (map_size * 0.5)


func _collect_tilemap_bounds(root: Node) -> Rect2:
	var layer_rects: Array[Rect2] = []
	for layer in _find_tilemap_layers(root):
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var tile_size := layer.tile_set.tile_size if layer.tile_set else Vector2i(16, 16)
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
