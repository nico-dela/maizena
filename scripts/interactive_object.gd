extends StaticBody2D

@export var dialogue: DialogueResource
@export var start_node := "start"
@export var npc_id := ""
@export var idle_glow := true

@export var spawn_schedules: Array[Dictionary] = [
	{"start": 9.0, "end": 12.0, "probability": 0.75},
	{"start": 15.0, "end": 19.0, "probability": 0.85},
	{"start": 20.0, "end": 22.0, "probability": 0.5},
]

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

var is_active: bool = false
var time_system: TimeOfDaySystem
var rng = RandomNumberGenerator.new()
var original_modulate: Color
var _active_schedule_key := ""
var _idle_glow_tween: Tween

const IDLE_GLOW_PEAK := Color(1.14, 1.1, 0.98)
const IDLE_GLOW_CYCLE := 1.8


func _ready():
	original_modulate = modulate

	visible = false
	if collision:
		collision.disabled = true

	if dialogue and not npc_id.is_empty():
		var dm := Engine.get_singleton("DialogueManager")
		if dm and not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)

	if not dialogue:
		return

	await get_tree().process_frame
	time_system = get_tree().get_first_node_in_group("time_system")

	if time_system:
		time_system.time_updated.connect(_on_time_updated)
		if not spawn_schedules.is_empty():
			add_to_group("world_npc")
		_evaluate_appearance(time_system.current_time)
	else:
		print("ERROR: No se encontró TimeOfDaySystem en ", name)
		set_active(true)

	rng.randomize()


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if npc_id.is_empty() or dialogue != resource:
		return
	GameState.mark_npc_talked(npc_id)


func _on_time_updated(current_hour: float, _is_day: bool):
	_evaluate_appearance(current_hour)


func _evaluate_appearance(current_hour: float):
	if spawn_schedules.is_empty():
		set_active(true)
		return

	var schedule := _find_active_schedule(current_hour)
	if schedule.is_empty():
		if _active_schedule_key != "":
			_active_schedule_key = ""
			set_active(false)
		return

	var schedule_key := _schedule_key(schedule)
	if schedule_key == _active_schedule_key:
		return

	_active_schedule_key = schedule_key
	var prob: float = schedule.get("probability", 1.0)
	var presence_multiplier := 1.0
	var world_state = get_node_or_null("/root/WorldState")
	if world_state:
		presence_multiplier = world_state.get_presence_multiplier()
	var adjusted_prob := clampf(prob * presence_multiplier, 0.0, 1.0)
	set_active(rng.randf() < adjusted_prob)


func _find_active_schedule(current_hour: float) -> Dictionary:
	for schedule in spawn_schedules:
		var start: float = schedule.get("start", 8.0)
		var end: float = schedule.get("end", 20.0)
		var in_schedule := false
		if start <= end:
			in_schedule = current_hour >= start and current_hour < end
		else:
			in_schedule = current_hour >= start or current_hour < end
		if in_schedule:
			return schedule
	return {}


func _schedule_key(schedule: Dictionary) -> String:
	return "%s-%s" % [schedule.get("start", 0.0), schedule.get("end", 0.0)]


func is_in_schedule(current_hour: float) -> bool:
	return not _find_active_schedule(current_hour).is_empty()


func force_present() -> void:
	if is_active:
		return
	var hour := time_system.current_time if time_system else 0.0
	var schedule := _find_active_schedule(hour)
	if schedule.is_empty():
		return
	_active_schedule_key = _schedule_key(schedule)
	set_active(true)


func set_active(active: bool):
	if is_active == active:
		return

	is_active = active
	visible = active

	if collision:
		collision.disabled = not active

	if animated_sprite and animated_sprite.sprite_frames:
		if active:
			_play_sprite_animation()
			_update_idle_glow()
		else:
			_stop_idle_glow()
			animated_sprite.stop()
			animated_sprite.visible = false

	if active:
		modulate = Color.TRANSPARENT
		var tween = create_tween()
		tween.tween_property(self, "modulate", original_modulate, 0.5)
	else:
		modulate = original_modulate
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)


func _play_sprite_animation() -> void:
	var anim_names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
	if anim_names.is_empty():
		animated_sprite.frame = 0
		animated_sprite.visible = true
		return

	var anim := String(animated_sprite.animation)
	if anim.is_empty() or not animated_sprite.sprite_frames.has_animation(anim):
		anim = anim_names[0]
	animated_sprite.animation = anim
	animated_sprite.play(anim)


func _should_idle_glow() -> bool:
	if not idle_glow or not animated_sprite or not animated_sprite.sprite_frames:
		return false
	var anim := String(animated_sprite.animation)
	if anim.is_empty() or not animated_sprite.sprite_frames.has_animation(anim):
		return false
	return animated_sprite.sprite_frames.get_frame_count(anim) <= 1


func _update_idle_glow() -> void:
	_stop_idle_glow()
	if not _should_idle_glow():
		return
	animated_sprite.modulate = Color.WHITE
	_idle_glow_tween = create_tween().set_loops()
	_idle_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_glow_tween.tween_property(animated_sprite, "modulate", IDLE_GLOW_PEAK, IDLE_GLOW_CYCLE * 0.5)
	_idle_glow_tween.tween_property(animated_sprite, "modulate", Color.WHITE, IDLE_GLOW_CYCLE * 0.5)


func _stop_idle_glow() -> void:
	if _idle_glow_tween:
		_idle_glow_tween.kill()
		_idle_glow_tween = null
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE


func show_dialogue():
	if is_active and dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, start_node)
