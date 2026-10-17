extends Node

var quest_hambre_active := false
var quest_hambre_completed := false
var tiene_comida := false
var inventory := {}
var bollo_training_active := false
var bollo_training_completed := false
var npc_talk_counts := {}
var boji_chose_pantano := false
var boji_chose_siluetos := false
var boji_chose_templo := false
var boji_siguiendo := false
var hi_siguiendo := false
var spinetto_chose_album := false
var spinetto_chose_island := false
var silueto1_chose_defend := false
var silueto1_chose_silence := false
var silueto1_chose_ask := false
## Evento asamblea: horarios no esconden NPCs.
var evento_todos_presentes := true
var quest_canciones_active := true
var quest_canciones_completed := false
var canciones_encontradas: Array[int] = []

const BOLLO_FIGHT_SCENE_PATH := "res://scenes/minigames/bollo_fight_minigame.tscn"

func _ready() -> void:
	call_deferred("_sync_canciones_from_meta")


func _sync_canciones_from_meta() -> void:
	canciones_encontradas.clear()
	for song_id in MaizenaMeta.get_collected_songs():
		canciones_encontradas.append(int(song_id))
	_refresh_canciones_quest()


func encontrar_cancion(song_id: int) -> void:
	if canciones_encontradas.has(song_id):
		return
	canciones_encontradas.append(song_id)
	MaizenaMeta.collect_song(song_id)
	_refresh_canciones_quest()
	_notify_song_unlocked(song_id)


func _refresh_canciones_quest() -> void:
	quest_canciones_completed = canciones_encontradas.size() >= SongRelics.count()
	quest_canciones_active = not quest_canciones_completed


func _notify_song_unlocked(song_id: int) -> void:
	var mm := get_tree().get_first_node_in_group("music_manager")
	if mm != null and mm.has_method("note_song_unlocked"):
		mm.call("note_song_unlocked", song_id)
	var title := ""
	if mm != null and mm.has_method("get_song_title"):
		title = str(mm.call("get_song_title", song_id))
	var banner := _song_banner()
	if banner != null and banner.has_method("show_found") and not title.is_empty():
		banner.call("show_found", title)


func _song_banner() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("UI/SongBanner")


func get_npc_talk_count(id: String) -> int:
	return int(npc_talk_counts.get(id, 0))

func mark_npc_talked(id: String) -> void:
	npc_talk_counts[id] = get_npc_talk_count(id) + 1


## Handoff entre personas en el booth. Las canciones quedan en MaizenaMeta.
func reset_session() -> void:
	quest_hambre_active = false
	quest_hambre_completed = false
	tiene_comida = false
	inventory.clear()
	bollo_training_active = false
	bollo_training_completed = false
	npc_talk_counts.clear()
	boji_chose_pantano = false
	boji_chose_siluetos = false
	boji_chose_templo = false
	boji_siguiendo = false
	hi_siguiendo = false
	spinetto_chose_album = false
	spinetto_chose_island = false
	silueto1_chose_defend = false
	silueto1_chose_silence = false
	silueto1_chose_ask = false
	evento_todos_presentes = true
	_dismiss_active_dialogue_balloons()
	_sync_canciones_from_meta()

func mision_secundaria_activa() -> Dictionary:
	if quest_hambre_active and not quest_hambre_completed:
		return {
			"titulo": "El hambre del viejo",
			"detalle": _detalle_hambre(),
		}
	return {"titulo": "", "detalle": ""}


func _detalle_hambre() -> String:
	if has_item("hongos"):
		return "Llevále los hongos a el viejo."
	var place := "la isla"
	var spawner := get_node_or_null("/root/HongosSpawner")
	if spawner != null and str(spawner.hint_place) != "":
		place = str(spawner.hint_place)
	return "Buscá hongos en %s." % place


func buscar_comida():
	quest_hambre_active = true
	tiene_comida = false

func agarrar_comida():
	add_item("hongos", 1)
	tiene_comida = has_item("hongos")
	var spawner := get_node_or_null("/root/HongosSpawner")
	if spawner != null and spawner.has_method("clear_pending"):
		spawner.clear_pending()

func completar_comida():
	quest_hambre_active = false
	quest_hambre_completed = true
	remove_item("hongos", 1)
	tiene_comida = has_item("hongos")

func add_item(item_id: String, amount: int = 1):
	inventory[item_id] = int(inventory.get(item_id, 0)) + max(amount, 0)

func has_item(item_id: String, amount: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= amount

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	inventory[item_id] = int(inventory.get(item_id, 0)) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	return true

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func start_bollo_training():
	if bollo_training_active:
		return

	var current_scene := get_tree().current_scene
	if not current_scene:
		return

	var packed_scene := load(BOLLO_FIGHT_SCENE_PATH) as PackedScene
	if not packed_scene:
		return

	_dismiss_active_dialogue_balloons()

	var minigame = packed_scene.instantiate()
	current_scene.add_child(minigame)
	bollo_training_active = true
	DialogueController.input_locked = true
	get_tree().paused = true

	if minigame.has_signal("finished"):
		minigame.finished.connect(_on_bollo_training_finished)

func _on_bollo_training_finished(victory: bool):
	bollo_training_active = false
	DialogueController.input_locked = false
	get_tree().paused = false
	_reset_player_movement()
	if victory:
		bollo_training_completed = true
		MaizenaMeta.record_bollo_win()


func _reset_player_movement() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("reset_movement"):
		player.reset_movement()

func _dismiss_active_dialogue_balloons():
	var root := get_tree().root
	if not root:
		return

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)

		if not (node is CanvasLayer):
			continue
		if not node.get_script():
			continue

		var script_path := str(node.get_script().resource_path)
		if "balloon.gd" in script_path:
			node.queue_free()
