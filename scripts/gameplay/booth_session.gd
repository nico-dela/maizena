extends CanvasLayer

## Headphone level and idle handoff. Only added on the booth export.

const Booth = preload("res://scripts/gameplay/booth.gd")

const IDLE_LIMIT_SEC := 180.0

var _idle_sec := 0.0
var _reloading := false


func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	Booth.configure_pad()
	Booth.apply_headphone_mix()
	GameState.evento_todos_presentes = true


func _process(delta: float) -> void:
	_idle_sec += delta
	if _idle_sec >= IDLE_LIMIT_SEC:
		_reload_session()


func _input(event: InputEvent) -> void:
	_note_activity(event)


func _note_activity(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= Booth.STICK_DEADZONE:
			_idle_sec = 0.0
		return
	if event is InputEventJoypadButton and event.pressed:
		_idle_sec = 0.0
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_idle_sec = 0.0


func _reload_session() -> void:
	if _reloading:
		return
	_reloading = true
	_idle_sec = 0.0
	var reload := get_parent().get_node_or_null("FestReload")
	if reload != null and reload.has_method("reload_guest"):
		reload.reload_guest()
		return
	GameState.reset_session()
	DialogueController.input_locked = false
	get_tree().paused = false
	get_tree().reload_current_scene()
