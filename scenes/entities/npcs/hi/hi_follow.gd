extends "res://scripts/gameplay/interactive_object.gd"

## Tras la primera charla, Hi sigue a Sanjin y alumbra la niebla.

const FOLLOW_GAP := 22.0
const FOLLOW_SPEED := 100.0
const TALK_RANGE := 36.0
const TRAIL_STEP := 4.0
const STOP_DIST := 1.5
const IDLE_ANIM := "hi_idle"
const IDLE_SPEED_SCALE := 1.0
const MOVE_SPEED_SCALE := 2.0
const BOB_AMPLITUDE := 1.5
const BOB_SPEED := 8.0

var _following := false
var _trail: Array[Vector2] = []
var _bob_time := 0.0


func _ready() -> void:
	set_physics_process(false)
	_add_lamp()
	super._ready()
	var dm := Engine.get_singleton("DialogueManager")
	if dm != null and not dm.dialogue_ended.is_connected(_on_follow_dialogue_ended):
		dm.dialogue_ended.connect(_on_follow_dialogue_ended)
	if GameState.hi_siguiendo:
		_begin_follow()


func _on_follow_dialogue_ended(resource: DialogueResource) -> void:
	if dialogue != resource:
		return
	if GameState.get_npc_talk_count("hi") < 1:
		return
	GameState.hi_siguiendo = true
	_begin_follow()


func _add_lamp() -> void:
	var lamp := PointLight2D.new()
	lamp.texture = _falloff_texture(48, 3.4)
	lamp.texture_scale = 1.35
	lamp.color = Color(0.62, 0.82, 1.0)
	lamp.energy = 0.55
	lamp.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(lamp)


func _falloff_texture(size: int, power: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for x in size:
		for y in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, power)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


func _begin_follow() -> void:
	if _following:
		return
	_following = true
	add_to_group("hi_follower")
	remove_from_group("dialogue")
	_ignore_schedule()
	set_active(true)
	if collision:
		collision.disabled = true
	_reparent_to_main()
	set_physics_process(true)
	_play_flame(false)


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
	_play_flame(false)


func _physics_process(delta: float) -> void:
	if not _following:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if DialogueController.input_locked:
		_play_flame(false)
		return
	var body := player as CharacterBody2D
	var sanjin_moving := body != null and body.velocity.length() > 1.0
	_push_trail(player.global_position)
	var goal := _follow_goal(player)
	var offset := goal - global_position
	var dist := offset.length()
	if dist <= STOP_DIST:
		global_position = goal
		_play_flame(false)
		return
	var speed := body.velocity.length() if sanjin_moving and body != null else FOLLOW_SPEED
	global_position += offset.normalized() * minf(speed * delta, dist)
	_play_flame(true)
	_bob(delta)


func _bob(delta: float) -> void:
	if animated_sprite == null:
		return
	_bob_time += delta
	animated_sprite.position.y = sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE


func _play_flame(moving: bool) -> void:
	if animated_sprite == null:
		return
	animated_sprite.speed_scale = MOVE_SPEED_SCALE if moving else IDLE_SPEED_SCALE
	if not moving:
		animated_sprite.position.y = 0.0
		_bob_time = 0.0
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(IDLE_ANIM):
		return
	if animated_sprite.animation != IDLE_ANIM or not animated_sprite.is_playing():
		animated_sprite.play(IDLE_ANIM)


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
	for i in range(1, _trail.size()):
		var seg := _trail[i - 1].distance_to(_trail[i])
		if seg <= 0.001:
			continue
		if seg >= left:
			return _trail[i - 1].lerp(_trail[i], left / seg)
		left -= seg
	return behind


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
