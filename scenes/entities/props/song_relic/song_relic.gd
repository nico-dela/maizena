extends Area2D

## Objeto del mapa que filtra una canción hasta que el jugador lo recoge.

const Feedback := preload("res://scripts/gameplay/collectable_feedback.gd")
const SPRITE_TARGET := 16.0

var song_id := -1
var collected := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var leak: AudioStreamPlayer2D = $Leak


func _ready() -> void:
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
	_play_leak()


func _configure_leak() -> void:
	if leak == null:
		return
	leak.bus = "Master"
	if OS.has_feature("booth"):
		leak.volume_db = -6.0
		leak.max_distance = 340.0
	else:
		leak.volume_db = -10.0
		leak.max_distance = 220.0
	leak.attenuation = 0.45


func _play_leak() -> void:
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
	leak.play()


func _on_body_entered(body: Node) -> void:
	if collected or song_id < 0:
		return
	if not body.is_in_group("player"):
		return
	collected = true
	monitoring = false
	if leak != null:
		leak.stop()
	GameState.encontrar_cancion(song_id)
	Feedback.play_pickup(sprite, queue_free)
