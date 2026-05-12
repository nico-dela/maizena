extends Node

## Fecha de referencia (debe ser martes): misma base que el contador de Eras en pantalla.
const ERA_START_DATE := {"year": 2023, "month": 12, "day": 2}

const SAVE_PATH := "user://maizena_meta.json"
const RECENT_ERA_COUNT := 5
const PLAY_LOG_MAX := 400

var welcome_popup_seen := false
var _play_log: Array = []


func _ready() -> void:
	_load()
	if "--maizena-reset-welcome" in OS.get_cmdline_args():
		welcome_popup_seen = false
		_save()


func get_current_era_number() -> int:
	var now := Time.get_datetime_dict_from_system()
	var start_unix := float(Time.get_unix_time_from_datetime_dict(ERA_START_DATE))
	var now_unix := float(Time.get_unix_time_from_datetime_dict(now))
	var seconds_passed := now_unix - start_unix
	var days_passed := int(seconds_passed / 86400.0)
	if days_passed < 0:
		return 0
	return int(days_passed / 7.0) + 1


## Lore: martes de ensayo desde la fecha del disco hasta hoy (días calendario, TZ del sistema).
func count_tuesday_rehearsals_since_release() -> int:
	var start_unix := int(Time.get_unix_time_from_datetime_dict(ERA_START_DATE))
	var end_unix := int(Time.get_unix_time_from_system())
	const DAY := 86400
	var n := 0
	var u := start_unix
	while u <= end_unix:
		var dt := Time.get_datetime_dict_from_unix_time(u)
		if int(dt.get("weekday", -1)) == 2:
			n += 1
		u += DAY
	return n


func record_song_play(song_enum: int) -> void:
	var era := get_current_era_number()
	_play_log.append({"era": era, "song": song_enum})
	if _play_log.size() > PLAY_LOG_MAX:
		_play_log = _play_log.slice(_play_log.size() - PLAY_LOG_MAX, _play_log.size())
	_save()


## Cuántas veces arrancó esta canción en las últimas `RECENT_ERA_COUNT` eras (incluye la actual).
func count_song_plays_in_recent_eras(song_enum: int) -> int:
	var ce := get_current_era_number()
	if ce < 1:
		return 0
	var min_era := ce - RECENT_ERA_COUNT + 1
	var c := 0
	for entry in _play_log:
		if int(entry.get("song", -999)) != song_enum:
			continue
		var e := int(entry.get("era", 0))
		if e >= min_era and e <= ce:
			c += 1
	return c


func mark_welcome_seen() -> void:
	welcome_popup_seen = true
	_save()


func is_welcome_seen() -> bool:
	return welcome_popup_seen


func get_recent_era_window() -> int:
	return RECENT_ERA_COUNT


func get_visible_residue_count() -> int:
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return 0
	return mini(int(ws.accumulation_level), 80)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	welcome_popup_seen = bool(data.get("welcome_popup_seen", false))
	var raw_log = data.get("play_log", [])
	if typeof(raw_log) == TYPE_ARRAY:
		_play_log.clear()
		for item in raw_log:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			_play_log.append({
				"era": int(item.get("era", 0)),
				"song": int(item.get("song", 0)),
			})


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var serializable: Array = []
	for entry in _play_log:
		serializable.append({"era": entry.get("era", 0), "song": entry.get("song", 0)})
	var data := {
		"welcome_popup_seen": welcome_popup_seen,
		"play_log": serializable,
	}
	f.store_string(JSON.stringify(data))
