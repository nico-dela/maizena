extends Area2D

## Path to the world scene to load (avoids circular PackedScene deps).
@export_file("*.tscn") var target_scene_path: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
@export var destination_label: String = ""
@export var hint_radius: float = 56.0

const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")
const BASE_HINT_FONT := 14
const BASE_SCREEN_OFFSET := 24.0
const SCREEN_EDGE_PAD := 6.0

var _cooldown_until_msec: int = 0
var _travel_pending: bool = false
var _mouse_over: bool = false
var _player: Node2D
var _hint_layer: CanvasLayer
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_style: StyleBoxFlat


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	monitoring = true
	monitorable = true
	input_pickable = true
	# El aviso vive en una CanvasLayer para no heredar el zoom de la cámara.
	_build_hint()
	ViewportLayout.layout_changed.connect(_apply_hint_scale)
	# Brief grace so the player does not instantly re-trigger on arrival.
	_cooldown_until_msec = Time.get_ticks_msec() + 500
	set_process(true)


func _process(_delta: float) -> void:
	if _hint_panel == null:
		return
	var should_show := _mouse_over or _is_player_near()
	_hint_panel.visible = should_show
	if should_show:
		_update_hint_position()


func _build_hint() -> void:
	_hint_layer = CanvasLayer.new()
	_hint_layer.name = "DestinationHintLayer"
	_hint_layer.layer = 15
	add_child(_hint_layer)

	_hint_style = StyleBoxFlat.new()
	_hint_style.bg_color = Color(0.04, 0.06, 0.14, 0.86)
	_hint_style.border_color = Color(0.42, 0.76, 0.94, 0.6)
	_hint_style.set_border_width_all(1)
	_hint_style.set_corner_radius_all(4)

	_hint_panel = PanelContainer.new()
	_hint_panel.name = "DestinationHint"
	_hint_panel.visible = false
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", _hint_style)
	_hint_layer.add_child(_hint_panel)

	_hint_label = Label.new()
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_override("font", FONT)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	_hint_panel.add_child(_hint_label)

	_apply_hint_scale()


func _apply_hint_scale() -> void:
	if _hint_label == null or _hint_style == null:
		return
	var s := ViewportLayout.effective_ui_scale()
	_hint_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(BASE_HINT_FONT))
	var pad_x := int(round(8.0 * s))
	var pad_y := int(round(5.0 * s))
	_hint_style.content_margin_left = pad_x
	_hint_style.content_margin_right = pad_x
	_hint_style.content_margin_top = pad_y
	_hint_style.content_margin_bottom = pad_y
	_hint_label.text = _hint_text()
	_hint_panel.reset_size()


func _hint_text() -> String:
	var text := destination_label.strip_edges()
	if text.is_empty():
		text = _fallback_destination_name()
	return text


func _update_hint_position() -> void:
	var panel_size := _hint_panel.get_combined_minimum_size()
	_hint_panel.size = panel_size

	var screen_pos := get_global_transform_with_canvas().origin
	var viewport_size := get_viewport_rect().size
	var offset_y := BASE_SCREEN_OFFSET * ViewportLayout.effective_ui_scale()
	var max_x := maxf(SCREEN_EDGE_PAD, viewport_size.x - panel_size.x - SCREEN_EDGE_PAD)
	var max_y := maxf(SCREEN_EDGE_PAD, viewport_size.y - panel_size.y - SCREEN_EDGE_PAD)
	_hint_panel.position = Vector2(
		clampf(screen_pos.x - panel_size.x * 0.5, SCREEN_EDGE_PAD, max_x),
		clampf(screen_pos.y - panel_size.y - offset_y, SCREEN_EDGE_PAD, max_y)
	)


func _fallback_destination_name() -> String:
	var path := target_scene_path.get_file().get_basename()
	match path:
		"ciudad_world":
			return "Ciudad"
		"pantano_world":
			return "Pantano"
		"bosque_encantado":
			return "Bosque"
		_:
			if target_scene_path.begins_with("uid://"):
				# ciudad_world is referenced by uid in bosque hotspots
				return "Ciudad"
			return "Salida"


func _is_player_near() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return false
	return global_position.distance_to(_player.global_position) <= hint_radius


func _on_body_entered(body: Node2D) -> void:
	if _travel_pending:
		return
	if Time.get_ticks_msec() < _cooldown_until_msec:
		return
	if not body.is_in_group("player"):
		return
	if target_scene_path.is_empty():
		push_warning("MapHotspot '%s': target_scene_path vacío" % name)
		return

	var packed := load(target_scene_path) as PackedScene
	if packed == null:
		push_error("MapHotspot '%s': no se pudo cargar %s" % [name, target_scene_path])
		return

	var main := get_tree().current_scene
	if main == null or not main.has_method("travel_to"):
		push_error("MapHotspot: MainScene sin travel_to()")
		return

	_travel_pending = true
	_cooldown_until_msec = Time.get_ticks_msec() + 500
	# Must defer: body_entered runs during physics query flush.
	main.call_deferred("travel_to", packed, spawn_position)


func _on_mouse_entered() -> void:
	_mouse_over = true


func _on_mouse_exited() -> void:
	_mouse_over = false
