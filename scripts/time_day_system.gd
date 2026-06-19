extends Node
class_name TimeOfDaySystem

signal time_updated(current_hour: float, is_day: bool)

var time_colors := {
	"morning": Color(1.0, 1.0, 0.9),
	"day": Color(1.0, 1.0, 1.0),
	"evening": Color(1.0, 0.8, 0.7),
	"night": Color(0.3, 0.4, 0.8, 0.7),
	"midnight": Color(0.2, 0.2, 0.5, 0.8),
}

@onready var canvas_modulate: CanvasModulate = get_node("CanvasModulate")

var current_time: float = 8.0
var _time_poll_accumulator := 0.0
var world_state: Node = null
var _last_time_signal_hour: float = -999.0
var _weather: Node = null

const WEATHER_TINTS := {
	"rain": {"color": Color(0.68, 0.74, 0.82), "strength": 0.18},
	"storm": {"color": Color(0.62, 0.68, 0.78), "strength": 0.18},
}

const DAWN_LEAD_HOURS := 0.5
const DAWN_TAIL_HOURS := 0.75
const DUSK_LEAD_HOURS := 0.75
const DUSK_TAIL_HOURS := 0.5


func _ready() -> void:
	add_to_group("time_system")

	if not canvas_modulate:
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		get_node("..").call_deferred("add_child", canvas_modulate)

	world_state = get_node_or_null("/root/WorldState")
	_weather = get_node_or_null("/root/CordobaWeather")
	if _weather != null:
		if _weather.has_signal("daylight_updated"):
			_weather.daylight_updated.connect(_on_daylight_updated)
		if _weather.has_signal("weather_updated"):
			_weather.weather_updated.connect(_on_weather_updated)
		if _weather.has_method("get_cordoba_local_hour"):
			current_time = _weather.get_cordoba_local_hour()
	elif world_state:
		current_time = world_state.current_hour

	update_time_color()
	set_process(true)


func _process(delta: float) -> void:
	_time_poll_accumulator += delta
	if _time_poll_accumulator < 10.0:
		return
	_time_poll_accumulator = 0.0
	_sync_current_time()
	update_time_color()


func _on_daylight_updated(_is_day: bool, _sunrise: float, _sunset: float, local_hour: float) -> void:
	current_time = local_hour
	update_time_color()


func _on_weather_updated(_condition: String, _precipitation_mm: float, _cloud_cover: int) -> void:
	update_time_color()


func _sync_current_time() -> void:
	if _weather != null and _weather.has_method("get_cordoba_local_hour"):
		current_time = _weather.get_cordoba_local_hour()
	elif world_state:
		current_time = world_state.current_hour


func update_time_color() -> void:
	_sync_current_time()

	var hour_changed := absf(current_time - _last_time_signal_hour) >= 1.0 / 60.0
	if hour_changed:
		_last_time_signal_hour = current_time
		emit_signal("time_updated", current_time, is_daytime())

	var color := _compute_time_color()
	if canvas_modulate:
		if world_state:
			var decay_color := Color(0.76, 0.70, 0.64, color.a)
			color = color.lerp(decay_color, world_state.get_decay_factor())
		color = _apply_weather_tint(color)
		canvas_modulate.color = color


func _compute_time_color() -> Color:
	if _weather != null and _weather.has_method("get_effective_is_day"):
		if not _weather.get_effective_is_day():
			return time_colors["night"]

	var sunrise := 7.5
	var sunset := 19.0
	if _weather != null:
		if _weather.has_method("get_effective_sunrise_hour"):
			sunrise = _weather.get_effective_sunrise_hour()
		if _weather.has_method("get_effective_sunset_hour"):
			sunset = _weather.get_effective_sunset_hour()

	var dawn_start := sunrise - DAWN_LEAD_HOURS
	var dawn_end := sunrise + DAWN_TAIL_HOURS
	var dusk_start := sunset - DUSK_LEAD_HOURS
	var dusk_end := sunset + DUSK_TAIL_HOURS

	if current_time >= dawn_start and current_time < dawn_end:
		var dawn_t := (current_time - dawn_start) / maxf(dawn_end - dawn_start, 0.01)
		return time_colors["midnight"].lerp(time_colors["morning"], clampf(dawn_t, 0.0, 1.0))
	if current_time >= dawn_end and current_time < dusk_start:
		return time_colors["day"]
	if current_time >= dusk_start and current_time < dusk_end:
		var dusk_t := (current_time - dusk_start) / maxf(dusk_end - dusk_start, 0.01)
		return time_colors["day"].lerp(time_colors["evening"], clampf(dusk_t, 0.0, 1.0))
	if current_time >= dusk_end or current_time < dawn_start:
		if current_time >= dusk_end:
			var night_t := (current_time - dusk_end) / maxf(24.0 - dusk_end + dawn_start, 0.01)
			return time_colors["evening"].lerp(time_colors["night"], clampf(night_t, 0.0, 1.0))
		var pre_dawn_t := current_time / maxf(dawn_start, 0.01)
		return time_colors["midnight"].lerp(time_colors["night"], clampf(pre_dawn_t, 0.0, 1.0))
	return time_colors["day"]


func _apply_weather_tint(color: Color) -> Color:
	if _weather == null or not _weather.is_available:
		return color
	var cond: String = _weather.condition
	if WEATHER_TINTS.has(cond):
		var tint: Dictionary = WEATHER_TINTS[cond]
		color = color.lerp(tint["color"], float(tint["strength"]))
	var clouds: int = int(_weather.cloud_cover)
	if clouds > 0:
		var overcast := Color(0.82, 0.84, 0.88)
		color = color.lerp(overcast, clampf(float(clouds) / 100.0 * 0.15, 0.0, 0.15))
	return color


func get_formatted_time() -> String:
	var hour := int(current_time)
	var minute := int((current_time - hour) * 60)
	return "%02d:%02d" % [hour, minute]


func is_daytime() -> bool:
	if _weather != null and _weather.has_method("get_effective_is_day"):
		return _weather.get_effective_is_day()
	return current_time >= 6.0 and current_time < 18.0


func is_nighttime() -> bool:
	return not is_daytime()
