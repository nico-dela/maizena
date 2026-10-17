extends Node

## Select + Start sostenidos recargan la noche para la persona que sigue.

const HOLD_SEC := 1.5

var _hold_sec := 0.0
var _reloading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(delta: float) -> void:
	if _reloading:
		return
	if _both_held():
		_hold_sec += delta
		if _hold_sec >= HOLD_SEC:
			reload_guest()
		return
	_hold_sec = 0.0


func reload_guest() -> void:
	if _reloading:
		return
	_reloading = true
	_hold_sec = 0.0
	var world := get_node_or_null("/root/WorldState")
	if world != null and world.has_method("wipe_guest_progress"):
		world.wipe_guest_progress()
	var meta := get_node_or_null("/root/MaizenaMeta")
	if meta != null and meta.has_method("wipe_guest_progress"):
		meta.wipe_guest_progress()
	GameState.reset_session()
	DialogueController.input_locked = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _both_held() -> bool:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		pads = [0]
	for device in pads:
		var select_held := Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)
		var start_held := Input.is_joy_button_pressed(device, JOY_BUTTON_START)
		if select_held and start_held:
			return true
	return false
