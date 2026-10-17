extends "res://scripts/gameplay/interactive_object.gd"

## Tras la primera charla, Boji sigue a Sanjin. Las caminatas son opcionales.

const FOLLOW_GAP := 22.0
const FOLLOW_SPEED := 100.0
const TALK_RANGE := 36.0
const TRAIL_STEP := 4.0
const STOP_DIST := 1.5
const IDLE_ANIM := "boji_idle_front"
const IDLE_BACK_ANIM := "boji_idle_back"
const SIDE_IDLE_ANIM := "boji_side_idle"

var _following := false
var _face := "down"
var _trail: Array[Vector2] = []


func _ready() -> void:
	set_physics_process(false)
	super._ready()
	var dm := Engine.get_singleton("DialogueManager")
	if dm != null and not dm.dialogue_ended.is_connected(_on_follow_dialogue_ended):
		dm.dialogue_ended.connect(_on_follow_dialogue_ended)
	if GameState.boji_siguiendo:
		_begin_follow()


func _on_follow_dialogue_ended(resource: DialogueResource) -> void:
	if dialogue != resource:
		return
	if GameState.get_npc_talk_count("boji") < 1:
		return
	GameState.boji_siguiendo = true
	_begin_follow()


func _begin_follow() -> void:
	if _following:
		return
	_following = true
	add_to_group("boji_follower")
	remove_from_group("dialogue")
	_ignore_schedule()
	set_active(true)
	if collision:
		collision.disabled = true
	_reparent_to_main()
	set_physics_process(true)
	_play_idle()


func _ignore_schedule() -> void:
	if time_system != null and time_system.time_updated.is_connected(_on_time_updated):
		time_system.time_updated.disconnect(_on_time_updated)


func _reparent_to_main() -> void:
	var main := get_tree().current_scene
	if main == null or get_parent() == main:
		return
	var pos := global_position
	reparent(main)
	global_position = pos


func snap_beside_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	global_position = player.global_position + _behind(player)
	_trail = [player.global_position]
	_match_player_face(player)
	_play_idle()


func _physics_process(delta: float) -> void:
	if not _following:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_match_player_face(player)
	if DialogueController.input_locked:
		_play_idle()
		return
	var body := player as CharacterBody2D
	var sanjin_moving := body != null and body.velocity.length() > 1.0
	_push_trail(player.global_position)
	var goal := _follow_goal(player)
	var offset := goal - global_position
	var dist := offset.length()
	if dist <= STOP_DIST:
		global_position = goal
		_play_idle()
		return
	var speed := body.velocity.length() if sanjin_moving and body != null else FOLLOW_SPEED
	global_position += offset.normalized() * minf(speed * delta, dist)
	_play_move()


func _push_trail(pos: Vector2) -> void:
	if _trail.is_empty() or _trail[0].distance_to(pos) >= TRAIL_STEP:
		_trail.push_front(pos)
	else:
		_trail[0] = pos
	var kept: Array[Vector2] = [_trail[0]]
	var walked := 0.0
	for i in range(1, _trail.size()):
		walked += _trail[i - 1].distance_to(_trail[i])
		kept.append(_trail[i])
		if walked >= FOLLOW_GAP * 4.0:
			break
	_trail = kept


func _behind(player: Node2D) -> Vector2:
	var dir := "down"
	if "current_dir" in player:
		dir = str(player.current_dir)
	match dir:
		"left":
			return Vector2(FOLLOW_GAP, 0.0)
		"right":
			return Vector2(-FOLLOW_GAP, 0.0)
		"up":
			return Vector2(0.0, FOLLOW_GAP)
		_:
			return Vector2(0.0, -FOLLOW_GAP)


func _follow_goal(player: Node2D) -> Vector2:
	var behind := player.global_position + _behind(player)
	if _trail.size() < 2:
		return behind
	var left := FOLLOW_GAP
	var walked := 0.0
	for i in range(1, _trail.size()):
		var seg := _trail[i - 1].distance_to(_trail[i])
		walked += seg
		if seg <= 0.001:
			continue
		if seg >= left:
			return _trail[i - 1].lerp(_trail[i], left / seg)
		left -= seg
	if walked < FOLLOW_GAP:
		return behind
	return _trail[_trail.size() - 1]


func _unhandled_input(event: InputEvent) -> void:
	if not _following or not event.is_action_pressed("ui_accept"):
		return
	if DialogueController.input_locked:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if global_position.distance_to(player.global_position) > TALK_RANGE:
		return
	show_dialogue()
	get_viewport().set_input_as_handled()


func _play_idle() -> void:
	if _face == "left":
		_play_named(SIDE_IDLE_ANIM, true)
	elif _face == "right":
		_play_named(SIDE_IDLE_ANIM, false)
	elif _face == "up":
		_play_named(IDLE_BACK_ANIM, false)
	else:
		_play_named(IDLE_ANIM, false)


func _match_player_face(player: Node2D) -> void:
	if not ("current_dir" in player):
		return
	var dir := str(player.current_dir)
	if dir == "left" or dir == "right" or dir == "up" or dir == "down":
		_face = dir


func _play_move() -> void:
	var anim := "boji_front_walk"
	match _face:
		"left":
			anim = "boji_side_walk_left"
		"right":
			anim = "boji_side_walk_right"
		"up":
			anim = "boji_back_walk"
	_play_named(anim, false)


func _play_named(anim: String, flip: bool) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim):
		anim = IDLE_ANIM
	if not animated_sprite.sprite_frames.has_animation(anim):
		return
	animated_sprite.flip_h = flip
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	animated_sprite.play(anim)
