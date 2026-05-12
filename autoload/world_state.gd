extends Node

signal world_time_updated(current_hour: float)
signal world_day_changed(current_day: int)
signal world_state_changed()

const SAVE_PATH := "user://world_state.json"

var world_day := 0
var current_hour := 0.0
var accumulation_level := 0
var decay_level := 0
var unseen_events := 0
var absent_days := 0
var residue_seed := 1337
var last_absence_mutation_day := -1

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
	var datetime := Time.get_datetime_dict_from_system()
	var hour := float(datetime.hour) + float(datetime.minute) / 60.0 + float(datetime.second) / 3600.0
	if abs(hour - current_hour) >= 1.0 / 120.0:
		current_hour = hour
		world_time_updated.emit(current_hour)

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

func _initialize_defaults():
	world_day = 0
	accumulation_level = 0
	decay_level = 0
	unseen_events = 0
	residue_seed = 1337
	last_absence_mutation_day = -1
	_last_seen_unix = int(Time.get_unix_time_from_system())
	_last_seen_unix_day = _get_unix_day()
	current_hour = float(Time.get_datetime_dict_from_system().hour)

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
		"last_seen_unix_day": _last_seen_unix_day
	}
	file.store_string(JSON.stringify(data))

func _get_unix_day() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)
