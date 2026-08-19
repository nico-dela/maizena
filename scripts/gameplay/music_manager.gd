extends Node

const PlayerSettings = preload("res://scripts/ui/player_settings.gd")

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
	MEDIAS,
	MATAR,
	AMIGOS
}

const TRACKS := {
	SONGS.COLORES: preload("res://assets/audio/music/Colores.ogg"),
	SONGS.CUMBIA: preload("res://assets/audio/music/Cumbia_naruto.ogg"),
	SONGS.GRUA: preload("res://assets/audio/music/Grua.ogg"),
	SONGS.RECIEN: preload("res://assets/audio/music/Recien_me_levanto.ogg"),
	SONGS.REPOLLO: preload("res://assets/audio/music/Repollo_Morado.ogg"),
	SONGS.RESAKA: preload("res://assets/audio/music/Resaka.ogg"),
	SONGS.TODO: preload("res://assets/audio/music/Todo_lo_que_necesito.ogg"),
	SONGS.MEDIAS: preload("res://assets/audio/music/Tus_medias.ogg"),
	SONGS.MATAR: preload("res://assets/audio/music/Matar_al_sol.ogg"),
	SONGS.AMIGOS: preload("res://assets/audio/music/Los_amigos.ogg")
}

const SONG_TITLES := {
	SONGS.COLORES: "Colores",
	SONGS.CUMBIA: "La cumbia de Naruto",
	SONGS.GRUA: "Grua",
	SONGS.RECIEN: "Recien me levanto",
	SONGS.REPOLLO: "Repollo Morado",
	SONGS.RESAKA: "Resaka",
	SONGS.TODO: "Todo lo que necesito",
	SONGS.MEDIAS: "Tus medias",
	SONGS.MATAR: "Matar al sol",
	SONGS.AMIGOS: "Los amigos"
}

var playlist: Array = []
var current_index := -1
var current_song: int
var play_in_background := false
var _background_paused := false
var _paused_playback_position := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("music_manager")
	player.finished.connect(_play_next)
	play_in_background = bool(PlayerSettings.load_all().get("play_in_background", false))
	_create_playlist()
	_play_next()
	call_deferred("_connect_window_focus")
	if OS.has_feature("web"):
		_setup_web_visibility_pause()


func is_play_in_background() -> bool:
	return play_in_background


func set_play_in_background(enabled: bool) -> void:
	play_in_background = enabled
	PlayerSettings.save_partial({"play_in_background": enabled})


func _connect_window_focus() -> void:
	var win := get_window()
	if win == null:
		return
	if not win.focus_entered.is_connected(_resume_from_background):
		win.focus_entered.connect(_resume_from_background)
	if not win.focus_exited.is_connected(_pause_for_background):
		win.focus_exited.connect(_pause_for_background)


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
	if play_in_background:
		return
	if _background_paused:
		return
	if player.stream == null:
		return
	if not player.playing:
		return
	_paused_playback_position = player.get_playback_position()
	_background_paused = true
	player.stream_paused = true


func _resume_from_background() -> void:
	if not _background_paused:
		return
	_background_paused = false
	if player.stream == null:
		return
	if player.playing:
		player.stream_paused = false
	else:
		player.play(_paused_playback_position)


func _create_playlist() -> void:
	playlist.clear()
	for value in SONGS.values():
		playlist.append(int(value))
	playlist.shuffle()
	current_index = -1


func _play_next() -> void:
	current_index += 1

	if current_index >= playlist.size():
		_create_playlist()
		current_index = 0

	current_song = playlist[current_index]

	player.stream = TRACKS[current_song]
	player.play()
	_background_paused = false
	_paused_playback_position = 0.0

	MaizenaMeta.record_song_play(current_song)
	song_changed.emit(SONG_TITLES[current_song])


func get_current_song_title() -> String:
	return str(SONG_TITLES.get(current_song, "…"))


func get_current_song_key() -> int:
	return current_song
