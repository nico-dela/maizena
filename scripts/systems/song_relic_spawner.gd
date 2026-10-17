extends Node

## Coloca una vez las reliquias de canciones y las vuelve a instanciar al cambiar de mapa.
## Solo en celdas donde el jugador puede pararse y llegar caminando.

const RELIC_SCENE := preload("res://scenes/entities/props/song_relic/song_relic.tscn")
const WORLD_NODE_NAME := "NewWorld"
const MIN_SEPARATION := 160.0
const CLOSE_DISTANCE := 48.0
const PHYSICS_WAITS := 4

var _audio_timer := 0.0
var _spawn_serial := 0


func _ready() -> void:
	set_process(true)
	call_deferred("refresh")


func _process(delta: float) -> void:
	_audio_timer += delta
	if _audio_timer < 0.2:
		return
	_audio_timer = 0.0
	_update_relic_audio()


func refresh() -> void:
	_ensure_layout()
	_spawn_serial += 1
	_spawn_when_ready(_spawn_serial)


func _spawn_when_ready(serial: int) -> void:
	for _attempt in PHYSICS_WAITS:
		await get_tree().physics_frame
		if serial != _spawn_serial:
			return
	HongosSpawner.clear_reach_cache()
	_spawn_current()


func _ensure_layout() -> void:
	if not MaizenaMeta.get_song_relics().is_empty():
		return
	var assigned := _assign_maps()
	if assigned.is_empty():
		return
	MaizenaMeta.set_song_relics(assigned)


func _assign_maps() -> Array:
	var maps: Array = HongosSpawner.MAPS
	if maps.is_empty():
		return []
	var map_ids: Array[String] = []
	for map_entry in maps:
		if typeof(map_entry) != TYPE_DICTIONARY:
			continue
		map_ids.append(str(map_entry.get("id", "")))
	if map_ids.is_empty():
		return []
	map_ids.shuffle()
	var song_ids: Array[int] = []
	for relic in SongRelics.RELICS:
		song_ids.append(int(relic.get("song_id", -1)))
	song_ids.shuffle()
	var assigned: Array = []
	for i in song_ids.size():
		assigned.append({
			"song": song_ids[i],
			"map_id": map_ids[i % map_ids.size()],
			"x": 0.0,
			"y": 0.0,
			"placed": false,
		})
	return assigned


func _spawn_current() -> void:
	var world := _live_world()
	if world == null:
		return
	var map_id := _map_id_for_world(world)
	if map_id.is_empty():
		return
	var parent: Node = world.get_node_or_null("InteractiveObjects")
	if parent == null:
		parent = world
	var existing := parent.get_node_or_null("SongRelics")
	if existing != null and existing.get_child_count() > 0:
		return
	if existing != null:
		existing.free()

	var relics := _place_pending_on(world, map_id)
	_spawn_placed(parent, relics, map_id)


func _spawn_placed(parent: Node, relics: Array, map_id: String) -> void:
	var holder := Node2D.new()
	holder.name = "SongRelics"
	var spawned := 0
	for relic in relics:
		if not _should_spawn(relic, map_id):
			continue
		if spawned == 0:
			parent.add_child(holder)
		spawned += 1
		var pos := Vector2(float(relic.get("x", 0.0)), float(relic.get("y", 0.0)))
		_spawn_one(holder, int(relic.get("song", -1)), pos)
	if spawned == 0:
		holder.free()


func _should_spawn(relic: Variant, map_id: String) -> bool:
	if not _relic_on_map(relic, map_id):
		return false
	if not bool(relic.get("placed", false)):
		return false
	var song_id := int(relic.get("song", -1))
	return song_id >= 0 and not MaizenaMeta.has_collected_song(song_id)


func _place_pending_on(world: Node, map_id: String) -> Array:
	var relics := MaizenaMeta.get_song_relics()
	var open := HongosSpawner.reachable_points(world)
	if open.is_empty():
		return relics
	var avoid: Array[Vector2] = []
	var changed := false
	for relic in relics:
		if not _relic_on_map(relic, map_id):
			continue
		if _retain_placed(relic, open, avoid):
			continue
		if _assign_reachable(relic, open, avoid):
			changed = true
	if changed:
		MaizenaMeta.set_song_relics(relics)
	return relics


func _relic_on_map(relic: Variant, map_id: String) -> bool:
	return typeof(relic) == TYPE_DICTIONARY and str(relic.get("map_id", "")) == map_id


func _retain_placed(relic: Dictionary, open: Array[Vector2], avoid: Array[Vector2]) -> bool:
	if not bool(relic.get("placed", false)):
		return false
	var saved := Vector2(float(relic.get("x", 0.0)), float(relic.get("y", 0.0)))
	if not HongosSpawner.has_reachable_point(open, saved):
		return false
	avoid.append(saved)
	return true


func _assign_reachable(relic: Dictionary, open: Array[Vector2], avoid: Array[Vector2]) -> bool:
	var pos := HongosSpawner.pick_reachable(open, avoid, MIN_SEPARATION)
	if pos == Vector2.INF:
		return false
	relic["x"] = pos.x
	relic["y"] = pos.y
	relic["placed"] = true
	avoid.append(pos)
	return true


func _spawn_one(holder: Node, song_id: int, pos: Vector2) -> void:
	var node := RELIC_SCENE.instantiate()
	holder.add_child(node)
	if node is Node2D:
		(node as Node2D).global_position = pos
	if node.has_method("setup"):
		node.call("setup", song_id)


func _update_relic_audio() -> void:
	var heard := _nearest_audible_relic()
	var nearest: Node = heard["relic"]
	var closeness := float(heard["closeness"])
	for relic in get_tree().get_nodes_in_group("song_relic"):
		if not relic.has_method("set_leak_closeness"):
			continue
		var amount := closeness if relic == nearest else 0.0
		relic.call("set_leak_closeness", amount)
	var music := get_tree().get_first_node_in_group("music_manager")
	if music != null and music.has_method("set_relic_proximity"):
		music.call("set_relic_proximity", closeness)


func _nearest_audible_relic() -> Dictionary:
	var empty := {"relic": null, "closeness": 0.0}
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return empty
	var nearest: Node = null
	var nearest_distance := INF
	var nearest_radius := 0.0
	for relic in get_tree().get_nodes_in_group("song_relic"):
		if not relic is Node2D or not relic.has_method("hearing_radius"):
			continue
		var radius := float(relic.call("hearing_radius"))
		var distance := player.global_position.distance_to((relic as Node2D).global_position)
		if distance > radius or distance >= nearest_distance:
			continue
		nearest = relic
		nearest_distance = distance
		nearest_radius = radius
	if nearest == null:
		return empty
	return {
		"relic": nearest,
		"closeness": _distance_closeness(nearest_distance, nearest_radius),
	}


func _distance_closeness(distance: float, radius: float) -> float:
	if radius <= CLOSE_DISTANCE:
		return 1.0 if distance <= radius else 0.0
	var span := radius - CLOSE_DISTANCE
	var linear := 1.0 - (distance - CLOSE_DISTANCE) / span
	return smoothstep(0.0, 1.0, clampf(linear, 0.0, 1.0))


func _live_world() -> Node:
	var main := get_parent()
	if main == null:
		return null
	return main.get_node_or_null(WORLD_NODE_NAME)


func _map_id_for_world(world: Node) -> String:
	var path := str(world.scene_file_path)
	for entry in HongosSpawner.MAPS:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_path := str(entry.get("path", ""))
		if path == entry_path or (not path.is_empty() and path.get_file() == entry_path.get_file()):
			return str(entry.get("id", ""))
	return ""
