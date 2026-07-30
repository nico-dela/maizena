extends Node2D

const WORLD_NODE_NAME := "NewWorld"

@onready var _player: Node2D = $Player


func _ready() -> void:
	call_deferred("_apply_initial_camera_limits")


func _apply_initial_camera_limits() -> void:
	var world := get_node_or_null(WORLD_NODE_NAME)
	if world != null and _player != null and _player.has_method("apply_camera_limits_from_world"):
		_player.apply_camera_limits_from_world(world)


func travel_to(packed: PackedScene, spawn: Vector2) -> void:
	if packed == null:
		push_error("MainScene.travel_to: PackedScene nulo")
		return
	if _player == null:
		_player = get_node_or_null("Player") as Node2D
	if _player == null:
		push_error("MainScene.travel_to: Player no encontrado")
		return

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

	_refresh_minimap()


func _refresh_minimap() -> void:
	var minimap := get_node_or_null("UI/Minimap")
	if minimap != null and minimap.has_method("refresh"):
		minimap.call_deferred("refresh")
