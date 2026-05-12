extends Node
## Agrega telemetría anónima de sesión (duración, canciones, diálogos) y la envía por HTTP.
## Configuración: Project Settings → `maizena/metrics/endpoint` (URL HTTPS, ej. función Netlify).
## Opcional: `maizena/metrics/ingest_secret` (misma clave que METRICS_INGEST_SECRET en Netlify).
## El `client_id` se guarda en user:// y reutiliza el mismo navegador entre visitas (web).

const CLIENT_ID_PATH := "user://metrics_client_id"
const MIN_TICK_INTERVAL_SEC := 45.0

var _client_id: String = ""
var _session_id: String = ""
var _session_start_unix: int = 0
var _active_play_sec: float = 0.0
var _song_counts: Dictionary = {} # title -> int
var _song_events: int = 0
var _dialogue_counts: Dictionary = {} # resource_path -> int
var _dialogue_events: int = 0

var _http: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_client_id()
	_session_id = _new_session_id()
	_session_start_unix = int(Time.get_unix_time_from_system())

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_request_completed)

	var tick := Timer.new()
	tick.wait_time = MIN_TICK_INTERVAL_SEC
	tick.autostart = true
	tick.timeout.connect(_on_tick_timer)
	add_child(tick)

	call_deferred("_connect_sources")
	call_deferred("_post_session_start")


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree != null and not tree.paused:
		_active_play_sec += delta


func _connect_sources() -> void:
	var dm: Node = Engine.get_singleton("DialogueManager")
	if dm != null and dm.has_signal("dialogue_started"):
		dm.dialogue_started.connect(_on_dialogue_started)

	await get_tree().process_frame
	var mm := get_tree().get_first_node_in_group("music_manager")
	if mm != null and mm.has_signal("song_changed"):
		mm.song_changed.connect(_on_song_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush("end")


func _exit_tree() -> void:
	_flush("end")


func _on_tick_timer() -> void:
	_flush("tick")


func _ensure_client_id() -> void:
	if FileAccess.file_exists(CLIENT_ID_PATH):
		var f := FileAccess.open(CLIENT_ID_PATH, FileAccess.READ)
		if f:
			var line := f.get_as_text().strip_edges()
			if line.length() > 8:
				_client_id = line
				return
	_client_id = _new_session_id()
	var w := FileAccess.open(CLIENT_ID_PATH, FileAccess.WRITE)
	if w:
		w.store_string(_client_id)


func _new_session_id() -> String:
	var hex := "0123456789abcdef"
	var s := ""
	for _i in range(32):
		s += hex[randi() % hex.length()]
	return s


func _metrics_endpoint() -> String:
	return str(ProjectSettings.get_setting("maizena/metrics/endpoint", "")).strip_edges()


func _metrics_secret() -> String:
	return str(ProjectSettings.get_setting("maizena/metrics/ingest_secret", "")).strip_edges()


func _on_dialogue_started(resource: Variant) -> void:
	var path := ""
	if resource != null and resource is Resource:
		path = str((resource as Resource).resource_path)
	if path.is_empty():
		path = "(unknown)"
	_dialogue_counts[path] = int(_dialogue_counts.get(path, 0)) + 1
	_dialogue_events += 1


func _on_song_changed(title: String) -> void:
	var key := str(title)
	_song_counts[key] = int(_song_counts.get(key, 0)) + 1
	_song_events += 1


func _post_session_start() -> void:
	_flush("start")


func _flush(phase: String) -> void:
	var url := _metrics_endpoint()
	if url.is_empty():
		return

	var payload := _build_payload(phase)
	var body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var secret := _metrics_secret()
	if not secret.is_empty():
		headers.append("X-Maizena-Metrics-Secret: " + secret)

	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("WorldMetrics: request falló (%s)" % str(err))


func _build_payload(phase: String) -> Dictionary:
	var ws: Node = get_node_or_null("/root/WorldState")
	var meta: Node = get_node_or_null("/root/MaizenaMeta")
	var era := 0
	var world_day := 0
	var accumulation := 0
	if meta != null and meta.has_method("get_current_era_number"):
		era = int(meta.call("get_current_era_number"))
	if ws != null:
		world_day = int(ws.world_day)
		accumulation = int(ws.accumulation_level)

	return {
		"schema": 1,
		"phase": phase,
		"client_id": _client_id,
		"session_id": _session_id,
		"started_at_unix": _session_start_unix,
		"sent_at_unix": int(Time.get_unix_time_from_system()),
		"wall_sec": max(0, int(Time.get_unix_time_from_system()) - _session_start_unix),
		"active_play_sec": snappedf(_active_play_sec, 0.1),
		"songs_by_title": _song_counts.duplicate(),
		"song_starts_total": _song_events,
		"dialogues_by_resource": _dialogue_counts.duplicate(),
		"dialogue_opens_total": _dialogue_events,
		"era": era,
		"world_day": world_day,
		"accumulation_level": accumulation,
		"welcome_seen": bool(meta.call("is_welcome_seen")) if meta != null and meta.has_method("is_welcome_seen") else false,
		"os_name": OS.get_name(),
		"locale": TranslationServer.get_locale(),
	}


func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code < 200 or response_code >= 300:
		push_warning("WorldMetrics: servidor respondió %d" % response_code)
