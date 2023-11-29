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
	THEMES.INTRO: [preload("res://soundtracks/01-Intro.mp3")],
	THEMES.REPOLLO: [preload("res://soundtracks/02-Repollo_Morado.mp3")],
	THEMES.SAL: [preload("res://soundtracks/03-Sal.mp3")],
	THEMES.NADIE: [preload("res://soundtracks/04-Nadie_Me_Enseñó_a_Vivir.mp3")],
	THEMES.PORORO: [preload("res://soundtracks/05-Pororo.mp3")],
	THEMES.TODO: [preload("res://soundtracks/06-Todo_lo_Que_Necesito.mp3")],
	THEMES.MEDIAS: [preload("res://soundtracks/07-Tus_Medias.mp3")],
	THEMES.ARROZ: [preload("res://soundtracks/08-Arroz.mp3")],
	THEMES.LEVANTO: [preload("res://soundtracks/09-Recién_Me_Levanto.mp3")],
	THEMES.CUMBIA: [preload("res://soundtracks/10-Cumbia_Naruto.mp3")]
}

var current_theme: int = THEMES.INTRO
var is_repeating: bool = true

@onready var streamPlayer: AudioStreamPlayer = $AudioStreamPlayer


func play_soundtrack(theme: int, repeat_themes: bool = true):
	if current_theme != theme or !streamPlayer.playing:
		is_repeating = false # Prevent accidentally starting an old track playing
								# again when next command is stop()
		streamPlayer.stop()
		
		is_repeating = repeat_themes
		current_theme = theme
		
		var theme_tracks: Array = TRACKS[current_theme]
		if theme_tracks != []:
			streamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
			streamPlayer.play()

func replay_current_theme():
	var theme_tracks: Array = TRACKS[current_theme]
	streamPlayer.stream = theme_tracks[randi() % theme_tracks.size()]
	streamPlayer.play()
	
func play_all_soundtracks():
	for theme in THEMES.values():
		play_soundtrack(theme)
		await streamPlayer.finished

func _on_AudioStreamPlayer_finished():
	if is_repeating:
		replay_current_theme()
