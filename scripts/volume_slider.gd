extends Control


@onready var audio_player = $AudioStreamPlayer
@onready var volume_slider = $VolumeHSlider

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

var TRACKS = {
	SONGS.COLORES: [preload("res://soundtracks/Colores.ogg")],
	SONGS.CUMBIA: [preload("res://soundtracks/Cumbia_naruto.ogg")],
	SONGS.GRUA: [preload("res://soundtracks/Grua.ogg")],
	SONGS.RECIEN: [preload("res://soundtracks/Recien_me_levanto.ogg")],
	SONGS.REPOLLO: [preload("res://soundtracks/Repollo_Morado.ogg")],
	SONGS.RESAKA: [preload("res://soundtracks/Resaka.ogg")],
	SONGS.TODO: [preload("res://soundtracks/Todo_lo_que_necesito.ogg")],
	SONGS.MEDIAS: [preload("res://soundtracks/Tus_medias.ogg")]
}

var current_song: int = SONGS.COLORES
var playlist: Array = []

func _ready():
	#volume_slider.focus_mode = Control.FOCUS_NONE
	volume_slider.value = audio_player.volume_db

	create_playlist()
	play_all_soundtracks()

func _on_volume_slider_value_changed(value: float) -> void:
	audio_player.volume_db = value

func create_playlist():
	for song in SONGS.values():
		playlist.append(song)
	
	playlist.shuffle()

func play_soundtrack(song: int):
	if current_song != song or !audio_player.playing:
		audio_player.stop()
		
		current_song = song
		
		var song_tracks: Array = TRACKS[current_song]
		if song_tracks != []:
			audio_player.stream = song_tracks[randi() % song_tracks.size()]
			audio_player.play()
	
func play_all_soundtracks():
	for song in playlist:
		play_soundtrack(song)
		await audio_player.finished
