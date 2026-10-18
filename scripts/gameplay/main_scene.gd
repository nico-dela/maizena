extends Node2D

const WORLD_NODE_NAME := "NewWorld"
const FADE_LAYER := 100
const FADE_COLOR := Color(0.02, 0.03, 0.06, 1.0)
const FADE_OUT_TIME := 0.22
const FADE_IN_TIME := 0.3

const SongRelicSpawnerScript := preload("res://scripts/systems/song_relic_spawner.gd")
const Booth = preload("res://scripts/gameplay/booth.gd")
const BoothSession := preload("res://scripts/gameplay/booth_session.gd")
const FestReloadScript := preload("res://scripts/gameplay/fest_reload.gd")
const WARM_WORLD_PATHS: Array[String] = [
	"res://scenes/world/ciudad_world.tscn",
	"res://scenes/world/pantano_world.tscn",
]

@onready var _player: Node2D = $Player

var _fade_rect: ColorRect
var _travel_busy := false
## Solo el mapa recién dejado. El anterior se libera para no retener los tres mundos.
var _parked_worlds: Dictionary = {}
var _boji_hold: Node2D
var _boji_visit := 0


func _ready() -> void:
	_build_fade_overlay()
	var relics := SongRelicSpawnerScript.new()
	relics.name = "SongRelicSpawner"
	add_child(relics)
	var reload := FestReloadScript.new()
	reload.name = "FestReload"
	add_child(reload)
	if Booth.active():
		var session := BoothSession.new()
		session.name = "BoothSession"
		add_child(session)
	_boji_hold = Node2D.new()
	_boji_hold.name = "BojiHold"
	add_child(_boji_hold)
	call_deferred("_apply_initial_camera_limits")
	call_deferred("_warm_other_worlds")


func set_crt_scan_clear(clear: bool) -> void:
	var world := get_node_or_null(WORLD_NODE_NAME)
	if world != null:
		_set_weather_layer_visible(world, not clear)


func _apply_initial_camera_limits() -> void:
	var world := get_node_or_null(WORLD_NODE_NAME)
	if world != null and _player != null and _player.has_method("apply_camera_limits_from_world"):
		_player.apply_camera_limits_from_world(world)
	_notify_hongos_spawner()
	_notify_song_relics()
	_place_boji_for_world(world)


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
	_notify_song_relics()
	await _fade_to(0.0, FADE_IN_TIME)
	_travel_busy = false


func _swap_world(packed: PackedScene, spawn: Vector2) -> Node:
	var old_world := get_node_or_null(WORLD_NODE_NAME)
	if old_world != null:
		_park_world(old_world)

	var new_world := _take_parked_world(packed)
	if new_world == null:
		new_world = _instantiate_world(packed)
	new_world.name = WORLD_NODE_NAME
	_drop_duplicate_hi(new_world)
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
	_place_hi_follower()
	_place_boji_for_world(new_world)
	return new_world


func _park_world(world: Node) -> void:
	var path := str(world.scene_file_path)
	remove_child(world)
	if path.is_empty():
		world.queue_free()
		return
	_release_parked_except(path)
	world.name = "ParkedWorld"
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_parked_worlds[path] = world


func _release_parked_except(keep_path: String) -> void:
	var drop: Array[String] = []
	for key in _parked_worlds.keys():
		var parked_path := str(key)
		if parked_path != keep_path:
			drop.append(parked_path)
	for parked_path in drop:
		var parked: Node = _parked_worlds[parked_path]
		_parked_worlds.erase(parked_path)
		if is_instance_valid(parked):
			parked.queue_free()


func _take_parked_world(packed: PackedScene) -> Node:
	var path := str(packed.resource_path)
	if path.is_empty() or not _parked_worlds.has(path):
		return null
	var parked: Node = _parked_worlds[path]
	_parked_worlds.erase(path)
	if not is_instance_valid(parked):
		return null
	parked.process_mode = Node.PROCESS_MODE_INHERIT
	return parked


func _instantiate_world(packed: PackedScene) -> Node:
	return packed.instantiate()


## La primera visita arma colisión de agua y casas. En web no se precalienta:
## los tres mapas a la vez tumban la pestaña. En escritorio, un solo vecino.
func _warm_other_worlds() -> void:
	if OS.has_feature("web"):
		return
	await get_tree().process_frame
	for path in WARM_WORLD_PATHS:
		if _parked_worlds.has(path) or _live_world_path() == path:
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("MainScene: no se pudo precalentar %s" % path)
			continue
		if _parked_worlds.has(path) or _live_world_path() == path:
			continue
		var world := _instantiate_world(packed)
		world.name = "ParkedWorld"
		_hide_warming_world(world)
		add_child(world)
		await get_tree().process_frame
		if world.get_parent() == self:
			remove_child(world)
		_show_warming_world(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		_parked_worlds[path] = world
		return


func _hide_warming_world(world: Node) -> void:
	if world is CanvasItem:
		(world as CanvasItem).visible = false
	var tint := world.get_node_or_null("TimeOfDaySystem/CanvasModulate")
	if tint is CanvasItem:
		(tint as CanvasItem).visible = false
	_set_weather_layer_visible(world, false)


func _show_warming_world(world: Node) -> void:
	if world is CanvasItem:
		(world as CanvasItem).visible = true
	var tint := world.get_node_or_null("TimeOfDaySystem/CanvasModulate")
	if tint is CanvasItem:
		(tint as CanvasItem).visible = true
	_set_weather_layer_visible(world, true)


func _set_weather_layer_visible(world: Node, shown: bool) -> void:
	var weather := world.get_node_or_null("TimeOfDaySystem/WeatherVisualSystem")
	if weather == null:
		return
	for child in weather.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = shown


func _live_world_path() -> String:
	var world := get_node_or_null(WORLD_NODE_NAME)
	if world == null:
		return ""
	return str(world.scene_file_path)


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


func _drop_duplicate_hi(world: Node) -> void:
	if not GameState.hi_siguiendo:
		return
	var planted := world.get_node_or_null("InteractiveObjects/hi")
	var follower := get_tree().get_first_node_in_group("hi_follower")
	if planted != null and planted != follower:
		planted.free()


func _place_hi_follower() -> void:
	var follower := get_tree().get_first_node_in_group("hi_follower")
	if follower != null and follower.has_method("snap_beside_player"):
		follower.call("snap_beside_player")


func _place_boji_for_world(world: Node) -> void:
	if world == null:
		return
	_ensure_boji_map()
	var boji := _find_boji()
	if boji == null:
		return
	if str(world.scene_file_path) != GameState.boji_map_path:
		_hold_boji(boji)
		return
	var parent := world.get_node_or_null("InteractiveObjects")
	if parent == null:
		parent = world
	if boji.get_parent() != parent:
		_reparent_detached(boji, parent)
	_boji_visit += 1
	var home := HongosSpawner.find_walkable_position(
		world, [], 0.0, true, "", HongosSpawner.RELIC_BLOCK_LAYER_NAMES
	)
	if boji.has_method("relocate"):
		boji.call("relocate", home, _boji_visit)


func _ensure_boji_map() -> void:
	if not GameState.boji_map_path.is_empty():
		return
	var maps: Array = HongosSpawner.MAPS
	if maps.is_empty():
		return
	var pick: Dictionary = maps[randi() % maps.size()]
	GameState.boji_map_path = str(pick.get("path", ""))


func _find_boji() -> Node:
	if _boji_hold != null:
		var held := _boji_hold.get_node_or_null("boji")
		if held != null:
			return held
	var live := get_node_or_null("%s/InteractiveObjects/boji" % WORLD_NODE_NAME)
	if live != null:
		return live
	for parked_variant in _parked_worlds.values():
		var parked := parked_variant as Node
		if parked == null or not is_instance_valid(parked):
			continue
		var npc := parked.get_node_or_null("InteractiveObjects/boji")
		if npc != null:
			return npc
	return null


## Boji nace dentro del mundo instanciado, así que su owner es esa raíz.
## Al sacarlo (BojiHold u otro mapa) hay que soltar el owner o Godot avisa
## que el owner ya no es ancestro del nuevo padre.
func _reparent_detached(node: Node, parent: Node) -> void:
	node.owner = null
	node.reparent(parent)


func _hold_boji(boji: Node) -> void:
	if _boji_hold == null:
		return
	if boji.get_parent() != _boji_hold:
		_reparent_detached(boji, _boji_hold)
	if boji.has_method("hold_off_map"):
		boji.call("hold_off_map")


func _notify_hongos_spawner() -> void:
	var spawner := get_node_or_null("/root/HongosSpawner")
	if spawner != null and spawner.has_method("try_spawn_in_current_world"):
		spawner.call_deferred("try_spawn_in_current_world")


func _notify_song_relics() -> void:
	var spawner := get_node_or_null("SongRelicSpawner")
	if spawner != null and spawner.has_method("refresh"):
		spawner.call_deferred("refresh")
