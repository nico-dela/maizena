extends Node
class_name SOUNDTRACKPLAYER_CLASS

enum THEMES {
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
	THEMES.COLORES: [preload("res://soundtracks/Colores.ogg")],
	THEMES.CUMBIA: [preload("res://soundtracks/Cumbia_naruto.ogg")],
	THEMES.GRUA: [preload("res://soundtracks/Grua.ogg")],
	THEMES.RECIEN: [preload("res://soundtracks/Recien_me_levanto.ogg")],
	THEMES.REPOLLO: [preload("res://soundtracks/Repollo_Morado.ogg")],
	THEMES.RESAKA: [preload("res://soundtracks/Resaka.ogg")],
	THEMES.TODO: [preload("res://soundtracks/Todo_lo_que_necesito.ogg")],
	THEMES.MEDIAS: [preload("res://soundtracks/Tus_medias.ogg")]
}

var current_theme: int = THEMES.COLORES
var playlist: Array = []

@onready var streamPlayer: AudioStreamPlayer = $AudioStreamPlayer

func _ready():
	create_playlist()

func create_playlist():
	for theme in THEMES.values():
		playlist.append(theme)
	
	playlist.shuffle()

func play_soundtrack(theme: int):
	if current_theme != theme or !streamPlayer.playing:
		streamPlayer.stop()
		
		current_theme = theme
		
		var theme_tracks: Array = TRACKS[current_theme]
		if theme_tracks != []:
			streamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
			streamPlayer.play()
	
func play_all_soundtracks():
	for theme in playlist:
		play_soundtrack(theme)
		await streamPlayer.finished

