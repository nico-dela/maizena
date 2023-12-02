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
#	THEMES.REPOLLO: [preload("res://soundtracks/Repollo Morado b 8 bits.ogg")],
#	THEMES.TODO: [preload("res://soundtracks/Todo lo que necesito 8 bit.ogg")],
#	THEMES.MEDIAS: [preload("res://soundtracks/tus medias 8bit.ogg")],
#	THEMES.LEVANTO: [preload("res://soundtracks/Recien me levanto 8 bit.ogg")],
#	THEMES.CUMBIA: [preload("res://soundtracks/Cumbia naruto 8bit.ogg")],
#	THEMES.GRUA: [preload("res://soundtracks/Grua 8 bit.ogg")],
#	THEMES.RESACA: [preload("res://soundtracks/Resaka 8 bits.ogg")],
	THEMES.INTRO: [preload("res://soundtracks/01 - Intro.ogg")],
	THEMES.REPOLLO: [preload("res://soundtracks/02 - Repollo Morado.ogg")],
	THEMES.SAL: [preload("res://soundtracks/03 - Sal.ogg")],
	THEMES.NADIE: [preload("res://soundtracks/04 - Nadie Me Enseñó a Vivir.ogg")],
	THEMES.PORORO: [preload("res://soundtracks/05 - Pororo.ogg")],
	THEMES.TODO: [preload("res://soundtracks/06 - Todo lo Que Necesito.ogg")],
	THEMES.MEDIAS: [preload("res://soundtracks/07 - Tus Medias.ogg")],
	THEMES.ARROZ: [preload("res://soundtracks/08 - Arroz.ogg")],
	THEMES.LEVANTO: [preload("res://soundtracks/09 - Recién Me Levanto feat. Ema Oliva.ogg")],
	THEMES.CUMBIA: [preload("res://soundtracks/10 - Cumbia Naruto.ogg")]
}

var current_theme: int = THEMES.REPOLLO
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
		
func play_soundtracks_randomly():
	var random_theme: int = THEMES.values()[randi() % THEMES.size()]
	play_soundtrack(random_theme)

func _on_AudioStreamPlayer_finished():
	if is_repeating:
		replay_current_theme()
