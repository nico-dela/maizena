extends "res://scripts/gameplay/interactive_object.gd"

## Deambula en un radio chico alrededor del punto que elige MainScene al entrar al mapa.

const WALK_SPEED := 40.0
const PATCH_RADIUS := 64.0
const PLAYER_BUFFER := 32.0
const IDLE_MIN := 1.5
const IDLE_MAX := 4.0
const STOP_DIST := 1.5
const IDLE_ANIM := "boji_idle_front"
const IDLE_BACK_ANIM := "boji_idle_back"
const SIDE_IDLE_ANIM := "boji_side_idle"

enum Mode { IDLE, WALK }

var _home := Vector2.ZERO
var _goal := Vector2.ZERO
var _face := "down"
var _idle_left := 0.0
var _mode := Mode.IDLE
var _visit := -1
var _placed := false
var _released := false


func _ready() -> void:
	# Sanjin está en z 2. Con z relativo, Boji queda debajo y desaparece al hablar.
	z_as_relative = false
	z_index = 3
	set_physics_process(false)
	super._ready()


func set_active(active: bool):
	if not _released or not _placed:
		active = false
	super.set_active(active)


func hold_off_map() -> void:
	_released = true
	_placed = false
	_visit = -1
	set_physics_process(false)
	set_active(false)
	call_deferred("_bind_live_time")


func relocate(home: Vector2, visit: int) -> void:
	if visit == _visit and _placed:
		return
	_visit = visit
	_released = true
	_placed = true
	_home = home
	global_position = home
	_enter_idle()
	set_physics_process(true)
	call_deferred("_bind_live_time")


func _physics_process(delta: float) -> void:
	if not _placed or not is_active:
		return
	if DialogueController.input_locked:
		_play_idle()
		return
	if _mode == Mode.WALK:
		_tick_walk(delta)
	else:
		_tick_idle(delta)


func _tick_idle(delta: float) -> void:
	_idle_left -= delta
	if _idle_left > 0.0:
		return
	_begin_walk()


func _tick_walk(delta: float) -> void:
	var offset := _goal - global_position
	if offset.length() <= STOP_DIST:
		_enter_idle()
		return
	var step := offset.normalized() * minf(WALK_SPEED * delta, offset.length())
	if not _can_step(global_position + step):
		_enter_idle()
		return
	_face_toward(step)
	global_position += step
	_play_move()


func _enter_idle() -> void:
	_mode = Mode.IDLE
	_idle_left = randf_range(IDLE_MIN, IDLE_MAX)
	_face = _random_face()
	_play_idle()


func _begin_walk() -> void:
	var goal := _pick_goal()
	if goal.distance_to(global_position) <= STOP_DIST:
		_enter_idle()
		return
	_goal = goal
	_mode = Mode.WALK
	_face_toward(_goal - global_position)
	_play_move()


func _pick_goal() -> Vector2:
	for _i in 6:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(16.0, PATCH_RADIUS)
		var goal := _home + offset
		if _can_step(goal):
			return goal
	return global_position


func _random_face() -> String:
	var faces: Array[String] = ["down", "up", "left", "right"]
	return faces[randi() % faces.size()]


func _can_step(point: Vector2) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and point.distance_to(player.global_position) < PLAYER_BUFFER:
		return false
	return _point_clear(point)


func _point_clear(point: Vector2) -> bool:
	var state := _space_state()
	if state == null:
		return true
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collision_mask = collision_mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	return state.intersect_point(params, 1).is_empty()


func _space_state() -> PhysicsDirectSpaceState2D:
	var world := get_world_2d()
	if world == null:
		return null
	return world.direct_space_state


func _bind_live_time() -> void:
	_disconnect_time()
	if not _placed:
		set_active(false)
		return
	time_system = _resolve_time_system()
	if time_system == null:
		return
	if not time_system.time_updated.is_connected(_on_time_updated):
		time_system.time_updated.connect(_on_time_updated)
	_evaluate_appearance(time_system.current_time)


func _disconnect_time() -> void:
	if time_system != null and time_system.time_updated.is_connected(_on_time_updated):
		time_system.time_updated.disconnect(_on_time_updated)
	time_system = null


func _face_toward(offset: Vector2) -> void:
	if absf(offset.x) > absf(offset.y):
		_face = "right" if offset.x > 0.0 else "left"
	else:
		_face = "down" if offset.y > 0.0 else "up"


func _play_idle() -> void:
	if _face == "left":
		_play_named(SIDE_IDLE_ANIM, true)
	elif _face == "right":
		_play_named(SIDE_IDLE_ANIM, false)
	elif _face == "up":
		_play_named(IDLE_BACK_ANIM, false)
	else:
		_play_named(IDLE_ANIM, false)


func _play_move() -> void:
	var anim := "boji_front_walk"
	if _face == "left":
		anim = "boji_side_walk_left"
	elif _face == "right":
		anim = "boji_side_walk_right"
	elif _face == "up":
		anim = "boji_back_walk"
	_play_named(anim, false)


func _play_named(anim: String, flip: bool) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim):
		return
	animated_sprite.visible = true
	animated_sprite.flip_h = flip
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	animated_sprite.play(anim)
