extends Area2D

## Path to the world scene to load (avoids circular PackedScene deps).
@export_file("*.tscn") var target_scene_path: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO

var _cooldown_until_msec: int = 0
var _travel_pending: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Brief grace so the player does not instantly re-trigger on arrival.
	_cooldown_until_msec = Time.get_ticks_msec() + 500


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
