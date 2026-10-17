extends Node

## Coloca una vez las reliquias de canciones y las vuelve a instanciar al cambiar de mapa.

const RELIC_SCENE := preload("res://scenes/entities/props/song_relic/song_relic.tscn")
const WORLD_NODE_NAME := "NewWorld"
const MIN_SEPARATION := 160.0


func _ready() -> void:
	call_deferred("refresh")


func refresh() -> void:
	_ensure_layout()
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
	if parent.get_node_or_null("SongRelics") != null:
		return

	var holder := Node2D.new()
	holder.name = "SongRelics"
	parent.add_child(holder)

	var relics := _place_pending_on(world, map_id)
	for relic in relics:
		if typeof(relic) != TYPE_DICTIONARY:
			continue
		if str(relic.get("map_id", "")) != map_id:
			continue
		if not bool(relic.get("placed", false)):
			continue
		var song_id := int(relic.get("song", -1))
		if song_id < 0 or MaizenaMeta.has_collected_song(song_id):
			continue
		_spawn_one(holder, song_id, Vector2(float(relic.get("x", 0.0)), float(relic.get("y", 0.0))))


func _place_pending_on(world: Node, map_id: String) -> Array:
	var relics := MaizenaMeta.get_song_relics()
	var avoid: Array[Vector2] = []
	var changed := false
	for relic in relics:
		if typeof(relic) != TYPE_DICTIONARY:
			continue
		if str(relic.get("map_id", "")) != map_id:
			continue
		if bool(relic.get("placed", false)):
			avoid.append(Vector2(float(relic.get("x", 0.0)), float(relic.get("y", 0.0))))
			continue
		var pos := HongosSpawner.find_walkable_position(
			world,
			avoid,
			MIN_SEPARATION,
			true,
			"Ground",
			HongosSpawner.RELIC_BLOCK_LAYER_NAMES
		)
		relic["x"] = pos.x
		relic["y"] = pos.y
		relic["placed"] = true
		avoid.append(pos)
		changed = true
	if changed:
		MaizenaMeta.set_song_relics(relics)
	return relics


func _spawn_one(holder: Node, song_id: int, pos: Vector2) -> void:
	var node := RELIC_SCENE.instantiate()
	holder.add_child(node)
	if node is Node2D:
		(node as Node2D).global_position = pos
	if node.has_method("setup"):
		node.call("setup", song_id)


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
