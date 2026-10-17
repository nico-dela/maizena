extends Node

## Con el evento de asamblea, muestra a todo NPC con horario. Si no, garantiza un mínimo visible.

func _ready() -> void:
	var time_system := _time_system()
	if time_system == null:
		return
	if not time_system.time_updated.is_connected(_on_time_updated):
		time_system.time_updated.connect(_on_time_updated)
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_ensure_presence(time_system.current_time)
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_ensure_presence(time_system.current_time)


func _on_time_updated(hour: float, _is_day: bool) -> void:
	call_deferred("_ensure_presence", hour)


func refresh_presence() -> void:
	var time_system := _time_system()
	if time_system == null:
		return
	call_deferred("_ensure_presence", time_system.current_time)


func _time_system() -> Node:
	var world := get_parent()
	if world == null:
		return null
	return world.get_node_or_null("TimeOfDaySystem")


func _world_npcs() -> Array[Node]:
	var found: Array[Node] = []
	if not is_inside_tree():
		return found
	var world := get_parent()
	if world == null:
		return found
	for npc in get_tree().get_nodes_in_group("world_npc"):
		if world.is_ancestor_of(npc):
			found.append(npc)
	return found


func _ensure_presence(hour: float) -> void:
	if not is_inside_tree():
		return
	var npcs := _world_npcs()
	if GameState.evento_todos_presentes:
		for npc in npcs:
			if npc.has_method("force_present"):
				npc.call("force_present")
		return

	var min_count := _min_npcs_for_hour(hour)
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
