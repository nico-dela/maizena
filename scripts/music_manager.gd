extends Node

@onready var player: AudioStreamPlayer = $AudioStreamPlayer

signal song_changed(title: String)

enum SONGS {
	COLORES,
	CUMBIA,
	GRUA,
	RECIEN,
	REPOLLO,
	RESAKA,
	TODO,
	MEDIAS
}

const TRACKS := {
	SONGS.COLORES: preload("res://assets/soundtrack/Colores.ogg"),
	SONGS.CUMBIA: preload("res://assets/soundtrack/Cumbia_naruto.ogg"),
	SONGS.GRUA: preload("res://assets/soundtrack/Grua.ogg"),
	SONGS.RECIEN: preload("res://assets/soundtrack/Recien_me_levanto.ogg"),
	SONGS.REPOLLO: preload("res://assets/soundtrack/Repollo_Morado.ogg"),
	SONGS.RESAKA: preload("res://assets/soundtrack/Resaka.ogg"),
	SONGS.TODO: preload("res://assets/soundtrack/Todo_lo_que_necesito.ogg"),
	SONGS.MEDIAS: preload("res://assets/soundtrack/Tus_medias.ogg")
}

const SONG_TITLES := {
	SONGS.COLORES: "Colores",
	SONGS.CUMBIA: "La cumbia de Naruto",
	SONGS.GRUA: "Grua",
	SONGS.RECIEN: "Recien me levanto",
	SONGS.REPOLLO: "Repollo Morado",
	SONGS.RESAKA: "Resaka",
	SONGS.TODO: "Todo lo que necesito",
	SONGS.MEDIAS: "Tus medias"
}

var playlist: Array = []
var current_index := -1
var current_song: int
var _background_paused := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("music_manager")
	player.finished.connect(_play_next)
	_create_playlist()
	_play_next()
	if OS.has_feature("web"):
		_setup_web_visibility_pause()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_pause_for_background()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_resume_from_background()


func _setup_web_visibility_pause() -> void:
	var callback := JavaScriptBridge.create_callback(_on_web_visibility_changed)
	var js := (
		"document.addEventListener('visibilitychange', function() { %s(document.hidden); });"
		% callback
	)
	JavaScriptBridge.eval(js, true)


func _on_web_visibility_changed(hidden: Variant) -> void:
	if bool(hidden):
		_pause_for_background()
	else:
		_resume_from_background()


func _pause_for_background() -> void:
	if _background_paused or not player.playing:
		return
	_background_paused = true
	player.stream_paused = true


func _resume_from_background() -> void:
	if not _background_paused:
		return
	_background_paused = false
	if player.playing:
		player.stream_paused = false


func _create_playlist():
	playlist.clear()
	for value in SONGS.values():
		playlist.append(int(value))
	playlist.shuffle()
	current_index = -1


func _play_next():
	current_index += 1

	if current_index >= playlist.size():
		_create_playlist()
		current_index = 0

	current_song = playlist[current_index]

	player.stream = TRACKS[current_song]
	player.play()
	_background_paused = false

	MaizenaMeta.record_song_play(current_song)
	song_changed.emit(SONG_TITLES[current_song])


func get_current_song_title() -> String:
	return str(SONG_TITLES.get(current_song, "…"))


func get_current_song_key() -> int:
	return current_song
