extends Node
## Clima y luz diurna de Córdoba, Argentina vía Open-Meteo (sin API key).

signal weather_updated(condition: String, precipitation_mm: float, cloud_cover: int)
signal daylight_updated(is_day: bool, sunrise_hour: float, sunset_hour: float, local_hour: float)

const LAT := -31.4201
const LON := -64.1888
const TIMEZONE := "America/Argentina/Cordoba"
const UTC_OFFSET_SECONDS := -3 * 3600

const API_URL := (
	"https://api.open-meteo.com/v1/forecast"
	+ "?latitude=-31.4201&longitude=-64.1888"
	+ "&current=weather_code,precipitation,cloud_cover,is_day"
	+ "&daily=sunrise,sunset"
	+ "&forecast_days=1"
	+ "&timezone=America%2FArgentina%2FCordoba"
)

var condition: String = "clear"
var precipitation_mm: float = 0.0
var cloud_cover: int = 0
var is_available: bool = false

var api_is_day: bool = true
var api_local_hour: float = 12.0
var api_sunrise_hour: float = 7.5
var api_sunset_hour: float = 19.0
var _api_day_key: String = ""

var _cached_sunrise_hour: float = 7.5
var _cached_sunset_hour: float = 19.0
var _cache_day_key: String = ""

var _http: HTTPRequest
var _refresh_minutes: float = 30.0
var _debug_override := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_minutes = float(ProjectSettings.get_setting("maizena/weather/refresh_minutes", 30))

	var seasonal := compute_seasonal_sunrise_sunset(_cordoba_day_of_year())
	_cached_sunrise_hour = seasonal.x
	_cached_sunset_hour = seasonal.y

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var timer := Timer.new()
	timer.wait_time = _refresh_minutes * 60.0
	timer.autostart = true
	timer.timeout.connect(_fetch_weather)
	add_child(timer)

	call_deferred("_fetch_weather")
	call_deferred("_emit_daylight")


func apply_debug_condition(cond: String) -> void:
	if not OS.is_debug_build():
		return
	_debug_override = true
	condition = cond
	is_available = true
	weather_updated.emit(condition, precipitation_mm, cloud_cover)
	_emit_daylight()


func get_cordoba_local_hour() -> float:
	if is_available:
		return api_local_hour
	return _local_hour_from_unix(Time.get_unix_time_from_system())


func get_effective_sunrise_hour() -> float:
	if is_available and _api_day_key != "":
		return api_sunrise_hour
	if _cache_day_key == _today_key():
		return _cached_sunrise_hour
	var seasonal := compute_seasonal_sunrise_sunset(_cordoba_day_of_year())
	return seasonal.x


func get_effective_sunset_hour() -> float:
	if is_available and _api_day_key != "":
		return api_sunset_hour
	if _cache_day_key == _today_key():
		return _cached_sunset_hour
	var seasonal := compute_seasonal_sunrise_sunset(_cordoba_day_of_year())
	return seasonal.y


func get_effective_is_day() -> bool:
	if is_available:
		return api_is_day
	var hour := get_cordoba_local_hour()
	var sunrise := get_effective_sunrise_hour()
	var sunset := get_effective_sunset_hour()
	return hour >= sunrise and hour < sunset


func compute_seasonal_sunrise_sunset(day_of_year: int) -> Vector2:
	var lat_rad := deg_to_rad(LAT)
	var decl := -23.44 * cos(deg_to_rad(360.0 / 365.0 * float(day_of_year + 10)))
	var decl_rad := deg_to_rad(decl)
	var cos_hour_angle := -tan(lat_rad) * tan(decl_rad)
	cos_hour_angle = clampf(cos_hour_angle, -1.0, 1.0)
	var hour_angle := rad_to_deg(acos(cos_hour_angle))
	var solar_noon := 12.0
	var sunrise := solar_noon - hour_angle / 15.0
	var sunset := solar_noon + hour_angle / 15.0
	return Vector2(sunrise, sunset)


func _fetch_weather() -> void:
	if _debug_override:
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var err := _http.request(API_URL)
	if err != OK:
		push_warning("CordobaWeather: request falló (%s)" % str(err))


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("CordobaWeather: respuesta inválida (%d)" % response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("CordobaWeather: JSON inválido")
		return

	var data: Variant = json.get_data()
	if not data is Dictionary:
		return

	var root := data as Dictionary
	var current: Variant = root.get("current", {})
	if not current is Dictionary:
		return

	var current_dict := current as Dictionary
	var code := int(current_dict.get("weather_code", 0))
	var precip := float(current_dict.get("precipitation", 0.0))
	var clouds := int(current_dict.get("cloud_cover", 0))
	api_is_day = int(current_dict.get("is_day", 1)) == 1
	api_local_hour = _parse_iso_hour(str(current_dict.get("time", "")))

	var daily: Variant = root.get("daily", {})
	if daily is Dictionary:
		var daily_dict := daily as Dictionary
		var sunrises: Variant = daily_dict.get("sunrise", [])
		var sunsets: Variant = daily_dict.get("sunset", [])
		if sunrises is Array and (sunrises as Array).size() > 0:
			api_sunrise_hour = _parse_iso_hour(str((sunrises as Array)[0]))
		if sunsets is Array and (sunsets as Array).size() > 0:
			api_sunset_hour = _parse_iso_hour(str((sunsets as Array)[0]))
		_api_day_key = _today_key()
		_cached_sunrise_hour = api_sunrise_hour
		_cached_sunset_hour = api_sunset_hour
		_cache_day_key = _api_day_key

	condition = _map_weather_code(code)
	precipitation_mm = precip
	cloud_cover = clouds
	is_available = true
	weather_updated.emit(condition, precipitation_mm, cloud_cover)
	_emit_daylight()


func _emit_daylight() -> void:
	daylight_updated.emit(
		get_effective_is_day(),
		get_effective_sunrise_hour(),
		get_effective_sunset_hour(),
		get_cordoba_local_hour()
	)


func _map_weather_code(code: int) -> String:
	if code == 45 or code == 48:
		return "fog"
	if code >= 51 and code <= 67:
		return "rain"
	if code >= 80 and code <= 82:
		return "rain"
	if code >= 95 and code <= 99:
		return "storm"
	return "clear"


func _parse_iso_hour(iso_time: String) -> float:
	if iso_time.is_empty():
		return _local_hour_from_unix(Time.get_unix_time_from_system())
	var time_part := iso_time
	if "T" in iso_time:
		time_part = iso_time.split("T")[1]
	var parts := time_part.split(":")
	if parts.size() < 2:
		return 12.0
	return float(parts[0]) + float(parts[1]) / 60.0


func _local_hour_from_unix(unix: float) -> float:
	var local_unix: int = int(floor(unix)) + UTC_OFFSET_SECONDS
	var seconds_in_day: int = posmod(local_unix, 86400)
	return float(seconds_in_day) / 3600.0


func _cordoba_day_of_year() -> int:
	var unix: float = Time.get_unix_time_from_system() + float(UTC_OFFSET_SECONDS)
	var days: int = int(floor(unix / 86400.0))
	return ((days + 365) % 365) + 1


func _today_key() -> String:
	var unix: float = Time.get_unix_time_from_system() + float(UTC_OFFSET_SECONDS)
	return str(int(floor(unix / 86400.0)))
