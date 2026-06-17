extends Node
## Clima actual de Córdoba, Argentina vía Open-Meteo (sin API key).

signal weather_updated(condition: String, precipitation_mm: float, cloud_cover: int)

const API_URL := (
	"https://api.open-meteo.com/v1/forecast"
	+ "?latitude=-31.4201&longitude=-64.1888"
	+ "&current=weather_code,precipitation,cloud_cover,is_day"
	+ "&timezone=America%2FArgentina%2FCordoba"
)

var condition: String = "clear"
var precipitation_mm: float = 0.0
var cloud_cover: int = 0
var is_available: bool = false

var _http: HTTPRequest
var _refresh_minutes: float = 30.0
var _debug_override := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_minutes = float(ProjectSettings.get_setting("maizena/weather/refresh_minutes", 30))

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var timer := Timer.new()
	timer.wait_time = _refresh_minutes * 60.0
	timer.autostart = true
	timer.timeout.connect(_fetch_weather)
	add_child(timer)

	call_deferred("_fetch_weather")


func apply_debug_condition(cond: String) -> void:
	if not OS.is_debug_build():
		return
	_debug_override = true
	condition = cond
	is_available = true
	weather_updated.emit(condition, precipitation_mm, cloud_cover)
	print("CordobaWeather [debug]: %s" % cond)


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

	var current: Variant = (data as Dictionary).get("current", {})
	if not current is Dictionary:
		return

	var code := int((current as Dictionary).get("weather_code", 0))
	var precip := float((current as Dictionary).get("precipitation", 0.0))
	var clouds := int((current as Dictionary).get("cloud_cover", 0))

	condition = _map_weather_code(code)
	precipitation_mm = precip
	cloud_cover = clouds
	is_available = true
	weather_updated.emit(condition, precipitation_mm, cloud_cover)


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
