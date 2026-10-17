class_name SongRelics
extends RefCounted

## Canciones que suenan sin recogerlas. El resto entra con un objeto del mapa.
const ALWAYS_IDS: Array[int] = [0, 5, 6, 9]

## song_id coincide con MusicManager.SONGS.
const RELICS: Array[Dictionary] = [
	{
		"song_id": 8,
		"texture": "res://assets/art/props/Lentes.png",
	},
	{
		"song_id": 4,
		"texture": "res://assets/art/props/Maceta_flor.png",
	},
	{
		"song_id": 7,
		"texture": "res://assets/art/props/chupetin.png",
	},
	{
		"song_id": 2,
		"texture": "res://assets/art/props/ford_sierra.png",
	},
	{
		"song_id": 1,
		"texture": "res://assets/art/props/futbol.png",
	},
	{
		"song_id": 3,
		"texture": "res://assets/art/props/remera1.png",
	},
	{
		"song_id": 10,
		"texture": "res://assets/art/props/sillon_roto.png",
	},
]


static func count() -> int:
	return RELICS.size()


static func is_always_available(song_id: int) -> bool:
	return ALWAYS_IDS.has(song_id)


static func relic_for(song_id: int) -> Dictionary:
	for relic in RELICS:
		if int(relic.get("song_id", -1)) == song_id:
			return relic
	return {}


static func texture_for(song_id: int) -> Texture2D:
	var relic := relic_for(song_id)
	var path := str(relic.get("texture", ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D
