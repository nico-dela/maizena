extends Node

@onready var player: AudioStreamPlayer2D = $AudioStreamPlayer2D

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

func _ready():
	add_to_group("music_manager")
	player.finished.connect(_play_next)
	_create_playlist()
	_play_next()

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

	song_changed.emit(SONG_TITLES[current_song])
