extends Node
class_name SOUNDTRACKPLAYER_CLASS

enum THEMES {
	INTRO,
	REPOLLO,
	SAL,
	NADIE,
	PORORO,
	TODO,
	MEDIAS,
	ARROZ,
	LEVANTO,
	CUMBIA
}

var TRACKS = {
	THEMES.INTRO: [preload("res://soundtracks/01-Intro.ogg")],
	THEMES.REPOLLO: [preload("res://soundtracks/02-Repollo_Morado.ogg")],
	THEMES.SAL: [preload("res://soundtracks/03-Sal.ogg")],
	THEMES.NADIE: [preload("res://soundtracks/04-Nadie_Me_Enseño_a_Vivir.ogg")],
	THEMES.PORORO: [preload("res://soundtracks/05-Pororo.ogg")],
	THEMES.TODO: [preload("res://soundtracks/06-Todo_lo_Que_Necesito.ogg")],
	THEMES.MEDIAS: [preload("res://soundtracks/07-Tus_Medias.ogg")],
	THEMES.ARROZ: [preload("res://soundtracks/08-Arroz.ogg")],
	THEMES.LEVANTO: [preload("res://soundtracks/09-Recién_Me_Levanto.ogg")],
	THEMES.CUMBIA: [preload("res://soundtracks/10-Cumbia_Naruto.ogg")]
}

var current_theme: int = THEMES.REPOLLO

@onready var streamPlayer: AudioStreamPlayer = $AudioStreamPlayer

func play_soundtrack(theme: int):
	if current_theme != theme or !streamPlayer.playing:
		streamPlayer.stop()
		
		current_theme = theme
		
		var theme_tracks: Array = TRACKS[current_theme]
		if theme_tracks != []:
			streamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
			streamPlayer.play()
	
func play_all_soundtracks():
	# Create an Array instance and duplicate the themes
	var duplicate_themes = []
	for theme in THEMES.values():
		duplicate_themes.append(theme)
	
	# Shuffle the duplicate themes
	duplicate_themes.shuffle()

	# Iterate through the shuffled themes
	for theme in duplicate_themes:
		play_soundtrack(theme)
		await streamPlayer.finished

