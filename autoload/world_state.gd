extends Node

signal world_time_updated(current_hour: float)
signal world_day_changed(current_day: int)
signal world_state_changed()

const SAVE_PATH := "user://world_state.json"
## Subir cuando cambie el tamaño/origen del grid de exploración (invalida fog guardado).
## v3: explored_cells[map_id] es Dictionary clave→true (O(1) al revelar).
const EXPLORATION_SAVE_VERSION := 3

var world_day := 0
var current_hour := 0.0
var accumulation_level := 0
var decay_level := 0
var unseen_events := 0
var absent_days := 0
var residue_seed := 1337
var last_absence_mutation_day := -1
var explored_cells: Dictionary = {}

var _last_seen_unix := 0
var _last_seen_unix_day := 0
var _visit_cooldown_penalty := 1.0
var _save_timer := 0.0
var _clock_timer := 0.0

func _ready():
	_load_state()
	_apply_absence_effects()
	_sync_time_from_system()
	_touch_visit()
	set_process(true)

func _process(delta: float):
	_save_timer += delta
	_clock_timer += delta

	if _clock_timer >= 10.0:
		_clock_timer = 0.0
		_sync_time_from_system()
		_check_day_rollover()

	if _save_timer >= 20.0:
		_save_timer = 0.0
		_save_state()

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

func _sync_time_from_system():
	var hour := _get_cordoba_hour()
	if abs(hour - current_hour) >= 1.0 / 120.0:
		current_hour = hour
		world_time_updated.emit(current_hour)


func _get_cordoba_hour() -> float:
	var weather := get_node_or_null("/root/CordobaWeather")
	if weather != null and weather.has_method("get_cordoba_local_hour"):
		return weather.get_cordoba_local_hour()
	var unix := int(Time.get_unix_time_from_system()) - 3 * 3600
	var seconds_in_day: int = unix % 86400
	if seconds_in_day < 0:
		seconds_in_day += 86400
	return float(seconds_in_day) / 3600.0

func _check_day_rollover():
	var unix_day := _get_unix_day()
	if unix_day > _last_seen_unix_day:
		_advance_days(unix_day - _last_seen_unix_day)
		_last_seen_unix_day = unix_day
		_save_state()

func _apply_absence_effects():
	var now_unix := Time.get_unix_time_from_system()
	var now_day := _get_unix_day()

	absent_days = max(0, now_day - _last_seen_unix_day)
	if absent_days > 0:
		_advance_days(absent_days)

	var seconds_since_last := int(now_unix) - _last_seen_unix
	if absent_days == 0 and seconds_since_last < 60 * 60:
		_visit_cooldown_penalty = 0.45
	elif absent_days == 0 and seconds_since_last < 4 * 60 * 60:
		_visit_cooldown_penalty = 0.7
	else:
		_visit_cooldown_penalty = 1.0

func _touch_visit():
	_last_seen_unix = int(Time.get_unix_time_from_system())
	_last_seen_unix_day = _get_unix_day()
	_save_state()

func _advance_days(days: int):
	for _i in range(days):
		world_day += 1
		accumulation_level += _daily_accumulation_gain(world_day)
		decay_level += 1
		unseen_events += _daily_unseen_event_gain(world_day)
	world_day_changed.emit(world_day)
	world_state_changed.emit()

func _daily_accumulation_gain(day_value: int) -> int:
	# 1-2 residuos por dia, determinista.
	return 1 + int(abs((day_value * 1103515245 + 12345) % 2))

func _daily_unseen_event_gain(day_value: int) -> int:
	# Eventos que "pasaron" aunque nadie mire.
	return int(abs((day_value * 214013 + 2531011) % 2))

func get_presence_multiplier() -> float:
	# Menos cambios con reingreso ansioso, mas mutacion tras ausencia.
	var absence_boost: float = 1.0 + min(float(absent_days), 5.0) * 0.18
	return clamp(absence_boost * _visit_cooldown_penalty, 0.25, 2.0)

func get_decay_factor() -> float:
	return clamp(float(decay_level) / 120.0, 0.0, 0.4)

func consume_unseen_events(max_count: int) -> int:
	var consumed: int = min(max_count, unseen_events)
	unseen_events -= consumed
	world_state_changed.emit()
	return consumed


func get_explored_cells(map_id: String) -> Array:
	if map_id.is_empty():
		return []
	var raw = explored_cells.get(map_id, {})
	if typeof(raw) == TYPE_DICTIONARY:
		return raw.keys()
	if typeof(raw) == TYPE_ARRAY:
		return raw.duplicate()
	return []


func is_cell_explored(map_id: String, cell_key: String) -> bool:
	if map_id.is_empty() or cell_key.is_empty():
		return false
	var raw = explored_cells.get(map_id, {})
	if typeof(raw) == TYPE_DICTIONARY:
		return raw.has(cell_key)
	if typeof(raw) == TYPE_ARRAY:
		return cell_key in raw
	return false


func add_explored_cells(map_id: String, keys: Array) -> void:
	if map_id.is_empty() or keys.is_empty():
		return
	var stored: Dictionary = _ensure_explored_dict(map_id)
	for key in keys:
		var cell_key := str(key)
		if cell_key.is_empty():
			continue
		stored[cell_key] = true
	## No emitir world_state_changed: la niebla no debe despertar sistemas de mundo.


func _ensure_explored_dict(map_id: String) -> Dictionary:
	var raw = explored_cells.get(map_id, null)
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	var converted: Dictionary = {}
	if typeof(raw) == TYPE_ARRAY:
		for key in raw:
			var cell_key := str(key)
			if not cell_key.is_empty():
				converted[cell_key] = true
	explored_cells[map_id] = converted
	return converted


func _normalize_explored_dict(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id in raw.keys():
		var entry = raw[map_id]
		if typeof(entry) == TYPE_DICTIONARY:
			var cells: Dictionary = {}
			for key in entry.keys():
				cells[str(key)] = true
			out[str(map_id)] = cells
		elif typeof(entry) == TYPE_ARRAY:
			out[str(map_id)] = _array_to_explored_dict(entry)
	return out


func _migrate_explored_arrays(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id in raw.keys():
		var entry = raw[map_id]
		if typeof(entry) == TYPE_DICTIONARY:
			var cells: Dictionary = {}
			for key in entry.keys():
				cells[str(key)] = true
			out[str(map_id)] = cells
		elif typeof(entry) == TYPE_ARRAY:
			out[str(map_id)] = _array_to_explored_dict(entry)
	return out


func _array_to_explored_dict(keys: Array) -> Dictionary:
	var cells: Dictionary = {}
	for key in keys:
		var cell_key := str(key)
		if not cell_key.is_empty():
			cells[cell_key] = true
	return cells


func _load_state():
	if not FileAccess.file_exists(SAVE_PATH):
		_initialize_defaults()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_initialize_defaults()
		return

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		_initialize_defaults()
		return

	world_day = int(data.get("world_day", 0))
	current_hour = float(data.get("current_hour", 0.0))
	accumulation_level = int(data.get("accumulation_level", 0))
	decay_level = int(data.get("decay_level", 0))
	unseen_events = int(data.get("unseen_events", 0))
	residue_seed = int(data.get("residue_seed", 1337))
	last_absence_mutation_day = int(data.get("last_absence_mutation_day", -1))
	_last_seen_unix = int(data.get("last_seen_unix", int(Time.get_unix_time_from_system())))
	_last_seen_unix_day = int(data.get("last_seen_unix_day", _get_unix_day()))
	var loaded_exploration_version := int(data.get("exploration_save_version", 0))
	var raw_explored = data.get("explored_cells", {})
	if typeof(raw_explored) != TYPE_DICTIONARY:
		explored_cells = {}
	elif loaded_exploration_version == EXPLORATION_SAVE_VERSION:
		explored_cells = _normalize_explored_dict(raw_explored)
	elif loaded_exploration_version == 2:
		## v2 guardaba Array por mapa; migrar a Dictionary sin invalidar progreso.
		explored_cells = _migrate_explored_arrays(raw_explored)
	else:
		explored_cells = {}

func _initialize_defaults():
	world_day = 0
	accumulation_level = 0
	decay_level = 0
	unseen_events = 0
	residue_seed = 1337
	last_absence_mutation_day = -1
	_last_seen_unix = int(Time.get_unix_time_from_system())
	_last_seen_unix_day = _get_unix_day()
	current_hour = _get_cordoba_hour()
	explored_cells = {}

func _save_state():
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return

	var data := {
		"world_day": world_day,
		"current_hour": current_hour,
		"accumulation_level": accumulation_level,
		"decay_level": decay_level,
		"unseen_events": unseen_events,
		"residue_seed": residue_seed,
		"last_absence_mutation_day": last_absence_mutation_day,
		"last_seen_unix": _last_seen_unix,
		"last_seen_unix_day": _last_seen_unix_day,
		"exploration_save_version": EXPLORATION_SAVE_VERSION,
		"explored_cells": explored_cells,
	}
	file.store_string(JSON.stringify(data))

func _get_unix_day() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)
