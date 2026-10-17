extends Area2D

## Objeto del mapa que filtra una canción hasta que el jugador lo recoge.

const Feedback := preload("res://scripts/gameplay/collectable_feedback.gd")
const SPRITE_TARGET := 16.0
const RELIC_BUS := "Relic"
const LEAK_FADE_SEC := 0.7
const SILENT_DB := -80.0
const PANNING_STRENGTH := 2.0
const STEREO_PULLOUT := 1.35

var song_id := -1
var collected := false
var _full_volume_db := -10.0
var _closeness := 0.0
var _closeness_target := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var leak: AudioStreamPlayer2D = $Leak


func _ready() -> void:
	add_to_group("song_relic")
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_configure_leak()


func setup(id: int) -> void:
	song_id = id
	var tex := SongRelics.texture_for(id)
	if tex != null and sprite != null:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		var height := maxf(float(tex.get_height()), 1.0)
		var scale_to := SPRITE_TARGET / height
		sprite.scale = Vector2(scale_to, scale_to)
	Feedback.start_idle(sprite)
	_prepare_leak()


func _process(delta: float) -> void:
	if collected or leak == null:
		return
	if not is_equal_approx(_closeness, _closeness_target):
		_closeness = move_toward(_closeness, _closeness_target, delta / LEAK_FADE_SEC)
	_apply_leak_volume()


func hearing_radius() -> float:
	if leak == null:
		return 0.0
	return leak.max_distance


func set_leak_closeness(amount: float) -> void:
	if collected:
		return
	_closeness_target = clampf(amount, 0.0, 1.0)


func _apply_leak_volume() -> void:
	if _closeness <= 0.001:
		_silence_leak()
		return
	if leak.stream == null:
		_prepare_leak()
	if leak.stream == null:
		return
	leak.volume_db = lerpf(SILENT_DB, _full_volume_db, _closeness)
	if not leak.playing:
		leak.play()
	leak.stream_paused = false


func _silence_leak() -> void:
	leak.volume_db = SILENT_DB
	if leak.playing:
		leak.stream_paused = true


func _configure_leak() -> void:
	if leak == null:
		return
	_ensure_relic_bus()
	leak.bus = RELIC_BUS
	leak.panning_strength = PANNING_STRENGTH
	if OS.has_feature("booth"):
		_full_volume_db = -6.0
		leak.max_distance = 340.0
	else:
		_full_volume_db = -10.0
		leak.max_distance = 220.0
	# El volumen lo marca la cercanía; la atenuación por distancia lo cortaría antes.
	leak.attenuation = 0.0
	leak.volume_db = SILENT_DB


func _ensure_relic_bus() -> void:
	if AudioServer.get_bus_index(RELIC_BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, RELIC_BUS)
	AudioServer.set_bus_send(idx, "Master")
	var widen := AudioEffectStereoEnhance.new()
	widen.pan_pullout = STEREO_PULLOUT
	AudioServer.add_bus_effect(idx, widen)


func _prepare_leak() -> void:
	if leak == null or song_id < 0:
		return
	var mm := get_tree().get_first_node_in_group("music_manager")
	if mm == null or not mm.has_method("get_track"):
		return
	var source: AudioStream = mm.call("get_track", song_id)
	if source == null:
		return
	var stream := source.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	leak.stream = stream
	leak.stop()


func _on_body_entered(body: Node) -> void:
	if collected or song_id < 0:
		return
	if not body.is_in_group("player"):
		return
	collected = true
	set_deferred("monitoring", false)
	if leak != null:
		leak.stop()
	GameState.encontrar_cancion(song_id)
	Feedback.play_pickup(sprite, queue_free)
