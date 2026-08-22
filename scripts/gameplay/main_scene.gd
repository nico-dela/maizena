extends Node2D

const WORLD_NODE_NAME := "NewWorld"
const FADE_LAYER := 100
const FADE_COLOR := Color(0.02, 0.03, 0.06, 1.0)
const FADE_OUT_TIME := 0.22
const FADE_IN_TIME := 0.3

const FogOverlayScene := preload("res://scenes/world/world_resources/fog_overlay.tscn")

@onready var _player: Node2D = $Player

var _fade_rect: ColorRect
var _travel_busy := false
var _map_discovery: Node
var _fog_overlay: Node2D


func _ready() -> void:
	_build_fade_overlay()
	_setup_map_discovery()
	call_deferred("_apply_initial_camera_limits")


func _setup_map_discovery() -> void:
	_map_discovery = MapDiscovery.new()
	_map_discovery.name = "MapDiscovery"
	add_child(_map_discovery)

	_fog_overlay = FogOverlayScene.instantiate() as Node2D
	_fog_overlay.name = "FogOverlay"
	add_child(_fog_overlay)
	if _fog_overlay.has_method("bind"):
		_fog_overlay.bind(_map_discovery)

	call_deferred("_refresh_map_discovery")


func _refresh_map_discovery() -> void:
	var world := get_node_or_null(WORLD_NODE_NAME)
	if world == null or _map_discovery == null:
		return
	if _map_discovery.has_method("flush_pending"):
		_map_discovery.flush_pending()
	_map_discovery.setup_from_world(world)
	if _fog_overlay != null:
		if _fog_overlay.get_parent() != world:
			if _fog_overlay.get_parent() != null:
				_fog_overlay.get_parent().remove_child(_fog_overlay)
			world.add_child(_fog_overlay)
		world.move_child(_fog_overlay, world.get_child_count() - 1)
		if _fog_overlay.has_method("bind"):
			_fog_overlay.bind(_map_discovery)
	if _player == null:
		_player = get_node_or_null("Player") as Node2D
	if _player != null and _map_discovery.has_method("reveal_at"):
		_map_discovery.reveal_at(_player.global_position)


func get_map_discovery() -> Node:
	return _map_discovery


func _apply_initial_camera_limits() -> void:
	var world := get_node_or_null(WORLD_NODE_NAME)
	if world != null and _player != null and _player.has_method("apply_camera_limits_from_world"):
		_player.apply_camera_limits_from_world(world)
	_notify_hongos_spawner()


## El fundido vive en su propia CanvasLayer y sigue corriendo con el árbol pausado.
func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TransitionFade"
	layer.layer = FADE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = FADE_COLOR
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	_fade_rect.visible = false
	layer.add_child(_fade_rect)


func travel_to(packed: PackedScene, spawn: Vector2) -> void:
	if packed == null:
		push_error("MainScene.travel_to: PackedScene nulo")
		return
	if _travel_busy:
		return
	if _player == null:
		_player = get_node_or_null("Player") as Node2D
	if _player == null:
		push_error("MainScene.travel_to: Player no encontrado")
		return

	_travel_busy = true
	if _player.has_method("reset_movement"):
		_player.reset_movement()

	await _fade_to(1.0, FADE_OUT_TIME)
	var new_world := _swap_world(packed, spawn)
	await _settle_new_world(new_world)
	_notify_hongos_spawner()
	await _fade_to(0.0, FADE_IN_TIME)
	_travel_busy = false


func _swap_world(packed: PackedScene, spawn: Vector2) -> Node:
	var old_world := get_node_or_null(WORLD_NODE_NAME)
	if old_world != null:
		old_world.name = "OldWorld"
		old_world.queue_free()

	var new_world := packed.instantiate()
	new_world.name = WORLD_NODE_NAME
	add_child(new_world)
	move_child(new_world, 0)

	if _player.has_method("reset_movement"):
		_player.reset_movement()
	_player.global_position = spawn

	if _player.has_method("apply_camera_limits_from_world"):
		_player.apply_camera_limits_from_world(new_world)
	# Después de los límites: el clamp puede volver a mover al jugador.
	if _player.has_method("snap_camera_to_player"):
		_player.snap_camera_to_player()

	_refresh_minimap()
	_refresh_map_discovery()
	return new_world


## Espera a que el mapa viejo se libere antes de mostrar el nuevo: los dos CanvasModulate
## conviven un frame, así que el tinte horario se reaplica con la pantalla en negro.
func _settle_new_world(world: Node) -> void:
	await get_tree().process_frame
	if world == null or not is_instance_valid(world):
		return
	var time_system := world.get_node_or_null("TimeOfDaySystem")
	if time_system != null and time_system.has_method("update_time_color"):
		time_system.call("update_time_color")


func _fade_to(target_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	_fade_rect.visible = true
	var tween := _fade_rect.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished
	if is_zero_approx(target_alpha):
		_fade_rect.visible = false


func _refresh_minimap() -> void:
	var minimap := get_node_or_null("UI/Minimap")
	if minimap != null and minimap.has_method("refresh"):
		minimap.call_deferred("refresh")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_try_unlock_audio()


func _try_unlock_audio() -> void:
	var music := get_node_or_null("MusicManager")
	if music != null and music.has_method("unlock_and_play"):
		music.unlock_and_play()


func _notify_hongos_spawner() -> void:
	var spawner := get_node_or_null("/root/HongosSpawner")
	if spawner != null and spawner.has_method("try_spawn_in_current_world"):
		spawner.call_deferred("try_spawn_in_current_world")
