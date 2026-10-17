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
	AMIGOS,
	NADIE
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
	SONGS.AMIGOS: preload("res://assets/audio/music/Los_amigos.ogg"),
	SONGS.NADIE: preload("res://assets/audio/music/Nadie_me_enseno_a_vivir.ogg")
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
	SONGS.AMIGOS: "Los amigos",
	SONGS.NADIE: "Nadie me enseñó a vivir"
}

var playlist: Array = []
var current_index := -1
var current_song: int
var play_in_background := false
var _background_paused := false
var _paused_playback_position := 0.0
var _audio_unlocked := false
var _pending_start := false
## Must stay referenced or the JS listener is garbage-collected.
var _web_visibility_cb: JavaScriptObject
var _seen_output_devices: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = "Master"
	add_to_group("music_manager")
	player.finished.connect(_play_next)
	play_in_background = bool(PlayerSettings.load_all().get("play_in_background", false))
	_apply_audio_from_settings()
	_create_playlist()
	if OS.has_feature("web"):
		_pending_start = true
		_setup_web_visibility_pause()
	else:
		call_deferred("_play_next")
	_arm_output_rebind()


func is_play_in_background() -> bool:
	return play_in_background


func set_play_in_background(enabled: bool) -> void:
	play_in_background = enabled
	PlayerSettings.save_partial({"play_in_background": enabled})


func unlock_and_play() -> void:
	if OS.has_feature("web") and not _audio_unlocked:
		JavaScriptBridge.eval(
			"(function(){if(typeof GodotAudio!=='undefined'&&GodotAudio.ctx){GodotAudio.ctx.resume();}})();",
			true
		)
	_audio_unlocked = true
	_poke_web_audio()
	if _pending_start or not player.playing:
		_pending_start = false
		_play_next()


func _apply_audio_from_settings() -> void:
	if OS.has_feature("booth"):
		var booth_bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(booth_bus, false)
		AudioServer.set_bus_volume_db(booth_bus, -8.0)
		return
	var settings := PlayerSettings.load_all()
	var master_bus := AudioServer.get_bus_index("Master")
	var muted := bool(settings.get("master_muted", false))
	AudioServer.set_bus_mute(master_bus, muted)
	if not muted:
		AudioServer.set_bus_volume_db(
			master_bus,
			float(settings.get("master_volume_db", PlayerSettings.default_volume_db()))
		)


func _setup_web_visibility_pause() -> void:
	# Do not string-interpolate create_callback — str() becomes `<JavaScriptObject#...>`
	# and JavaScriptBridge.eval then throws SyntaxError: Unexpected token '<'.
	_web_visibility_cb = JavaScriptBridge.create_callback(_on_web_visibility_js)
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return
	document.addEventListener("visibilitychange", _web_visibility_cb)


func _on_web_visibility_js(_args: Array) -> void:
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return
	_on_web_visibility_changed(document.hidden)


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
	_poke_web_audio()
	if player.stream == null:
		return
	if player.playing:
		player.stream_paused = false
	else:
		player.play(_paused_playback_position)


## Parlantes Bluetooth (p. ej. JBL) dejan el stream de Godot mudo hasta que otra app abre el dispositivo.
func _arm_output_rebind() -> void:
	if not OS.has_feature("web"):
		_seen_output_devices = AudioServer.get_output_device_list()
	for delay in [1.0, 4.0]:
		get_tree().create_timer(delay).timeout.connect(_reopen_output_device)
	var watch := Timer.new()
	watch.wait_time = 3.0
	watch.autostart = true
	watch.timeout.connect(_rebind_output_if_device_changed)
	add_child(watch)


func _rebind_output_if_device_changed() -> void:
	if OS.has_feature("web"):
		return
	var devices := AudioServer.get_output_device_list()
	if not _output_devices_changed(devices):
		return
	_seen_output_devices = devices
	_reopen_output_device()


func _output_devices_changed(devices: PackedStringArray) -> bool:
	if devices.size() != _seen_output_devices.size():
		return true
	for i in devices.size():
		if devices[i] != _seen_output_devices[i]:
			return true
	return false


func _reopen_output_device() -> void:
	if OS.has_feature("web"):
		_poke_web_audio()
		return
	var selected := str(AudioServer.output_device)
	AudioServer.output_device = "Default"
	if selected != "" and selected != "Default":
		AudioServer.output_device = selected
	_restart_player_stream()


func _restart_player_stream() -> void:
	if _background_paused or player.stream == null or not player.playing:
		return
	var pos := player.get_playback_position()
	player.stop()
	player.play(pos)


func _poke_web_audio() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"(function(){var ctx=typeof GodotAudio!=='undefined'&&GodotAudio.ctx;if(!ctx)return;ctx.resume();var buffer=ctx.createBuffer(1,1,ctx.sampleRate);var src=ctx.createBufferSource();src.buffer=buffer;src.connect(ctx.destination);src.start();})();",
		true
	)


func _create_playlist() -> void:
	var last_song := current_song if current_index >= 0 else -1
	playlist.clear()
	for song_id in TRACKS.keys():
		if _is_song_unlocked(int(song_id)):
			playlist.append(int(song_id))
	playlist.shuffle()
	if playlist.size() > 1 and last_song >= 0 and playlist[0] == last_song:
		playlist[0] = playlist[1]
		playlist[1] = last_song
	current_index = -1


func _is_song_unlocked(song_id: int) -> bool:
	if SongRelics.is_always_available(song_id):
		return true
	return MaizenaMeta.has_collected_song(song_id)


func note_song_unlocked(song_id: int) -> void:
	if not _is_song_unlocked(song_id):
		return
	if playlist.has(song_id):
		return
	var at := clampi(current_index + 1, 0, playlist.size())
	playlist.insert(at, song_id)


func get_track(song_id: int) -> AudioStream:
	return TRACKS.get(song_id) as AudioStream


func get_song_title(song_id: int) -> String:
	return str(SONG_TITLES.get(song_id, ""))


func _play_next() -> void:
	if playlist.is_empty():
		_create_playlist()
	current_index += 1

	if current_index >= playlist.size():
		_create_playlist()
		current_index = 0

	current_song = int(playlist[current_index])

	var source: AudioStream = TRACKS.get(current_song)
	if source == null:
		push_error("MusicManager: no hay stream para la canción %s" % current_song)
		return
	var stream: AudioStream = source.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	player.stop()
	player.stream = stream
	player.volume_db = 0.0
	player.stream_paused = false
	player.play()
	_background_paused = false
	_paused_playback_position = 0.0

	MaizenaMeta.record_song_play(current_song)
	song_changed.emit(SONG_TITLES[current_song])


func get_current_song_title() -> String:
	return str(SONG_TITLES.get(current_song, "…"))


func get_current_song_key() -> int:
	return current_song
