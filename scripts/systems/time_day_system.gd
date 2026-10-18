extends Node
class_name TimeOfDaySystem

const Booth = preload("res://scripts/gameplay/booth.gd")

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

const SUNRISE_HOUR := 7.5
const SUNSET_HOUR := 19.0
const DAWN_LEAD_HOURS := 0.5
const DAWN_TAIL_HOURS := 0.75
const DUSK_LEAD_HOURS := 0.75
## Civil twilight (~25–30 min) after sunset — still evening.
const DUSK_TAIL_HOURS := 0.45
## Nautical + astronomical twilight: evening → night.
const NIGHT_SETTLE_HOURS := 1.0
## Settle to deep night after astronomical darkness.
const MIDNIGHT_SETTLE_HOURS := 0.5


func _ready() -> void:
	add_to_group("time_system")

	if not canvas_modulate:
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		call_deferred("add_child", canvas_modulate)

	if Booth.active():
		time_colors["night"] = Color(0.55, 0.62, 0.92, 1.0)
		time_colors["midnight"] = Color(0.5, 0.55, 0.85, 1.0)

	world_state = get_node_or_null("/root/WorldState")
	_sync_current_time()

	update_time_color()
	set_process(true)


func _process(delta: float) -> void:
	_time_poll_accumulator += delta
	if _time_poll_accumulator < 10.0:
		return
	_time_poll_accumulator = 0.0
	_sync_current_time()
	update_time_color()


func _sync_current_time() -> void:
	if world_state != null and world_state.has_method("get_fest_hour"):
		current_time = world_state.get_fest_hour()
		return
	current_time = 22.0


func update_time_color() -> void:
	if not is_inside_tree():
		return
	_sync_time_and_emit()
	_apply_canvas_tint()


func _sync_time_and_emit() -> void:
	_sync_current_time()
	var hour_changed := absf(current_time - _last_time_signal_hour) >= 1.0 / 60.0
	if hour_changed:
		_last_time_signal_hour = current_time
		emit_signal("time_updated", current_time, is_daytime())


func _apply_canvas_tint() -> void:
	if _news_popup_visible():
		return
	var color := _compute_time_color()
	if canvas_modulate:
		if world_state:
			var decay_color := Color(0.76, 0.70, 0.64, color.a)
			color = color.lerp(decay_color, world_state.get_decay_factor())
		canvas_modulate.color = color


func _compute_time_color() -> Color:
	var dawn_start := SUNRISE_HOUR - DAWN_LEAD_HOURS
	var dawn_end := SUNRISE_HOUR + DAWN_TAIL_HOURS
	var dusk_start := SUNSET_HOUR - DUSK_LEAD_HOURS
	var dusk_end := SUNSET_HOUR + DUSK_TAIL_HOURS

	if current_time >= dawn_start and current_time < dawn_end:
		var dawn_t := (current_time - dawn_start) / maxf(dawn_end - dawn_start, 0.01)
		return time_colors["midnight"].lerp(time_colors["morning"], clampf(dawn_t, 0.0, 1.0))
	if current_time >= dawn_end and current_time < dusk_start:
		return time_colors["day"]
	if current_time >= dusk_start and current_time < dusk_end:
		var dusk_t := (current_time - dusk_start) / maxf(dusk_end - dusk_start, 0.01)
		return time_colors["day"].lerp(time_colors["evening"], clampf(dusk_t, 0.0, 1.0))
	if current_time >= dusk_end or current_time < dawn_start:
		return _compute_night_color(current_time, dusk_end)
	return time_colors["day"]


func _compute_night_color(hour: float, dusk_end: float) -> Color:
	var hours_since_dusk := hour - dusk_end
	if hours_since_dusk < 0.0:
		hours_since_dusk += 24.0

	if hours_since_dusk < NIGHT_SETTLE_HOURS:
		var night_t := hours_since_dusk / maxf(NIGHT_SETTLE_HOURS, 0.01)
		return time_colors["evening"].lerp(time_colors["night"], clampf(night_t, 0.0, 1.0))

	var after_night := hours_since_dusk - NIGHT_SETTLE_HOURS
	if after_night < MIDNIGHT_SETTLE_HOURS:
		var midnight_t := after_night / maxf(MIDNIGHT_SETTLE_HOURS, 0.01)
		return time_colors["night"].lerp(time_colors["midnight"], clampf(midnight_t, 0.0, 1.0))

	return time_colors["midnight"]


func is_daytime() -> bool:
	return false


func is_nighttime() -> bool:
	return not is_daytime()


func _news_popup_visible() -> bool:
	if not is_inside_tree():
		return false
	var wp := get_tree().get_first_node_in_group("welcome_popup")
	return wp != null and wp.visible
