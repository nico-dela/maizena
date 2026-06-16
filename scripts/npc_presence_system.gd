extends Node

## Garantiza varios NPCs visibles a la vez en horas concurridas del día.

func _ready() -> void:
	await get_tree().process_frame
	var time_system := get_tree().get_first_node_in_group("time_system")
	if time_system == null:
		return
	if not time_system.time_updated.is_connected(_on_time_updated):
		time_system.time_updated.connect(_on_time_updated)
	call_deferred("_ensure_presence", time_system.current_time)


func _on_time_updated(hour: float, _is_day: bool) -> void:
	call_deferred("_ensure_presence", hour)


func _ensure_presence(hour: float) -> void:
	var min_count := _min_npcs_for_hour(hour)
	var npcs := get_tree().get_nodes_in_group("world_npc")
	var visible_count := 0
	for npc in npcs:
		if npc.visible:
			visible_count += 1
	if visible_count >= min_count:
		return

	var candidates: Array[Node] = []
	for npc in npcs:
		if npc.visible:
			continue
		if npc.has_method("is_in_schedule") and npc.call("is_in_schedule", hour):
			candidates.append(npc)
	candidates.shuffle()

	for npc in candidates:
		if visible_count >= min_count:
			break
		if npc.has_method("force_present"):
			npc.call("force_present")
			visible_count += 1


func _min_npcs_for_hour(hour: float) -> int:
	if hour >= 15.0 and hour < 19.0:
		return 5
	if hour >= 9.0 and hour < 13.0:
		return 4
	if hour >= 19.0 and hour < 22.0:
		return 3
	if hour >= 13.0 and hour < 15.0:
		return 2
	return 1
