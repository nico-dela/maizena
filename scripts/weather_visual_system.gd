extends Node2D

const RAIN_AMOUNT := 120.0
const STORM_AMOUNT := 220.0
const NIGHT_OPACITY_FACTOR := 0.6
const FOG_HAZE_ALPHA := 0.30
const FOG_HAZE_PULSE := 0.06
const DEBUG_CYCLE := ["clear", "fog", "rain", "storm"]

var _layer: CanvasLayer
var _fog_haze: ColorRect
var _fog: CPUParticles2D
var _rain: CPUParticles2D
var _flash: ColorRect
var _storm_timer: Timer
var _time_system: Node
var _current_condition := "clear"
var _base_rain_color := Color(0.62, 0.72, 0.88, 0.55)
var _base_fog_color := Color(0.90, 0.92, 0.95, 0.22)
var _debug_cycle_index := -1
var _fog_pulse_time := 0.0


func _ready() -> void:
	add_to_group("weather_visual_system")
	_build_overlay()
	_time_system = get_parent()

	var weather := get_node_or_null("/root/CordobaWeather")
	if weather != null:
		weather.weather_updated.connect(_on_weather_updated)
		if weather.is_available:
			_on_weather_updated(weather.condition, weather.precipitation_mm, weather.cloud_cover)

	set_process(true)
	set_process_unhandled_input(OS.is_debug_build())


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_F6:
		return
	_debug_cycle_index = (_debug_cycle_index + 1) % DEBUG_CYCLE.size()
	var cond: String = DEBUG_CYCLE[_debug_cycle_index]
	var weather := get_node_or_null("/root/CordobaWeather")
	if weather != null and weather.has_method("apply_debug_condition"):
		weather.apply_debug_condition(cond)
	else:
		_on_weather_updated(cond, 0.0, 0)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_rain_opacity()
	_update_fog_haze(delta)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)

	_fog_haze = ColorRect.new()
	_fog_haze.color = Color(0.88, 0.90, 0.93, 0.0)
	_fog_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fog_haze)

	_fog = CPUParticles2D.new()
	_fog.texture = _make_fog_texture()
	_fog.emitting = false
	_fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fog.amount = 48
	_fog.lifetime = 6.0
	_fog.one_shot = false
	_fog.explosiveness = 0.0
	_fog.randomness = 0.65
	_fog.direction = Vector2(1.0, -0.05)
	_fog.spread = 28.0
	_fog.gravity = Vector2(6.0, -4.0)
	_fog.initial_velocity_min = 6.0
	_fog.initial_velocity_max = 18.0
	_fog.scale_amount_min = 10.0
	_fog.scale_amount_max = 22.0
	_fog.color = _base_fog_color
	_layer.add_child(_fog)

	_rain = CPUParticles2D.new()
	_rain.texture = _make_rain_texture()
	_rain.emitting = false
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.amount = 300
	_rain.lifetime = 1.2
	_rain.one_shot = false
	_rain.explosiveness = 0.0
	_rain.randomness = 0.35
	_rain.direction = Vector2(0.2, 1.0)
	_rain.spread = 8.0
	_rain.gravity = Vector2(40, 520)
	_rain.initial_velocity_min = 280.0
	_rain.initial_velocity_max = 420.0
	_rain.scale_amount_min = 1.5
	_rain.scale_amount_max = 2.5
	_rain.color = _base_rain_color
	_layer.add_child(_rain)

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_flash)

	_storm_timer = Timer.new()
	_storm_timer.one_shot = true
	_storm_timer.timeout.connect(_on_storm_flash)
	add_child(_storm_timer)

	get_viewport().size_changed.connect(_resize_overlay)
	call_deferred("_resize_overlay")


func _make_rain_texture() -> ImageTexture:
	var img := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		var alpha := 1.0 - float(y) / float(img.get_height())
		img.set_pixel(0, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


func _make_fog_texture() -> ImageTexture:
	var size := 20
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for x in size:
		for y in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


func _resize_overlay() -> void:
	var vp := get_viewport().get_visible_rect().size
	var margin := 120.0
	var center := Vector2(vp.x * 0.5, vp.y * 0.5)
	var extents := Vector2(vp.x * 0.5 + margin, vp.y * 0.5 + margin)

	_fog.position = center
	_fog.emission_rect_extents = extents

	_rain.position = Vector2(vp.x * 0.5, -margin)
	_rain.emission_rect_extents = Vector2(vp.x * 0.5 + margin, margin)


func _on_weather_updated(cond: String, _precipitation_mm: float, _cloud_cover: int) -> void:
	_current_condition = cond
	var is_fog := cond == "fog"
	var is_rain := cond == "rain" or cond == "storm"

	_fog.emitting = is_fog
	if not is_fog:
		_fog_haze.color.a = 0.0

	var is_rain_emitting := is_rain
	_rain.emitting = is_rain_emitting
	if is_rain_emitting:
		_rain.amount = int(STORM_AMOUNT if cond == "storm" else RAIN_AMOUNT)

	if cond == "storm":
		_schedule_storm_flash()
	else:
		_storm_timer.stop()
		_flash.color.a = 0.0

	_update_rain_opacity()
	_update_fog_particles()


func _is_night() -> bool:
	return (
		_time_system != null
		and _time_system.has_method("is_nighttime")
		and _time_system.call("is_nighttime")
	)


func _update_fog_haze(delta: float) -> void:
	if _current_condition != "fog":
		return
	_fog_pulse_time += delta
	var pulse := sin(_fog_pulse_time * 0.55) * FOG_HAZE_PULSE
	var alpha := FOG_HAZE_ALPHA + pulse
	if _is_night():
		alpha *= NIGHT_OPACITY_FACTOR
		_fog_haze.color = Color(0.72, 0.76, 0.84, alpha)
	else:
		_fog_haze.color = Color(0.88, 0.90, 0.93, alpha)


func _update_fog_particles() -> void:
	if not _fog.emitting:
		return
	var alpha := _base_fog_color.a
	if _is_night():
		alpha *= NIGHT_OPACITY_FACTOR
		_fog.color = Color(0.72, 0.76, 0.84, alpha)
	else:
		_fog.color = Color(_base_fog_color.r, _base_fog_color.g, _base_fog_color.b, alpha)


func _update_rain_opacity() -> void:
	if not _rain.emitting:
		return
	var alpha := _base_rain_color.a
	if _is_night():
		alpha *= NIGHT_OPACITY_FACTOR
	_rain.color = Color(_base_rain_color.r, _base_rain_color.g, _base_rain_color.b, alpha)


func _schedule_storm_flash() -> void:
	if not _storm_timer.is_stopped():
		return
	_storm_timer.wait_time = randf_range(8.0, 20.0)
	_storm_timer.start()


func _on_storm_flash() -> void:
	if _current_condition != "storm":
		return
	_flash.color = Color(1.0, 1.0, 1.0, 0.15)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.08)
	tween.finished.connect(_schedule_storm_flash)
