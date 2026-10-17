extends Node2D

## Gente de fondo en la fiesta. No habla y no bloquea el paso.

const FRAME := 16
const SPRITE_SCALE := 1.0
const WALK_SPEED := 18.0
const PATCH_RADIUS := 40.0
const SEPARATION := 64.0
const ZONE_TRIES := 36
const IDLE_MIN := 1.4
const IDLE_MAX := 3.6
const STOP_DIST := 2.0
const WALK_FPS := 6.0

const SHEETS: Array[Texture2D] = [
	preload("res://assets/art/characters/crowd/ninja_blue.png"),
	preload("res://assets/art/characters/crowd/samurai_blue.png"),
	preload("res://assets/art/characters/crowd/samurai_green.png"),
]

const FACES: Array[String] = ["down", "up", "left", "right"]
const FACE_COLUMN := {"down": 0, "up": 1, "left": 2, "right": 3}
const WALK_ROWS: Array[int] = [0, 1, 2, 3]

var _placed := false
var _zone := Rect2()
var _frames: Array[SpriteFrames] = []
var _members: Array[Member] = []


func _ready() -> void:
	z_index = 2
	_frames = _build_frames()
	call_deferred("_spawn")


func _physics_process(delta: float) -> void:
	var locked := DialogueController.input_locked
	for member in _members:
		_tick(member, delta, locked)


func _spawn() -> void:
	if _placed:
		return
	var world := get_parent()
	if world == null:
		return
	var kind := str(world.get("map_ambience"))
	var count := _count_for(kind)
	_zone = _zone_for(kind)
	if count <= 0 or _zone.size == Vector2.ZERO:
		return
	var avoid := _occupied_points(world)
	for index in count:
		var pos := _find_in_zone(world, avoid)
		if not _zone.has_point(pos):
			continue
		avoid.append(pos)
		_add_member(pos, index % 2 == 0)
	_placed = true
	set_physics_process(not _members.is_empty())
	_add_screen_cull()


func _add_screen_cull() -> void:
	if _members.is_empty() or _zone.size == Vector2.ZERO:
		return
	var enabler := VisibleOnScreenEnabler2D.new()
	enabler.name = "ScreenCull"
	enabler.enable_node_path = NodePath("..")
	enabler.rect = _zone.grow(64.0)
	add_child(enabler)


func _count_for(kind: String) -> int:
	match kind:
		"city":
			return 8
		"swamp":
			return 4
		_:
			return 0


func _zone_for(kind: String) -> Rect2:
	# Lado derecho de la ciudad y la franja alta del pantano, lejos del elenco.
	match kind:
		"city":
			return Rect2(880, 80, 300, 860)
		"swamp":
			return Rect2(48, 48, 540, 260)
		_:
			return Rect2()


func _find_in_zone(world: Node, avoid: Array) -> Vector2:
	for _i in ZONE_TRIES:
		var pos := HongosSpawner.find_walkable_position(
			world,
			avoid,
			SEPARATION,
			false,
			"Ground",
			HongosSpawner.RELIC_BLOCK_LAYER_NAMES
		)
		if _zone.has_point(pos) and _is_separated(pos, avoid):
			return pos
	return Vector2.INF


func _tick(member: Member, delta: float, locked: bool) -> void:
	if locked:
		_play(member, false)
		return
	if not member.wanders:
		_tick_loiter(member, delta)
	elif member.walking:
		_tick_walk(member, delta)
	else:
		_tick_idle(member, delta)


func _tick_loiter(member: Member, delta: float) -> void:
	member.idle_left -= delta
	if member.idle_left > 0.0:
		return
	member.face = _random_face()
	member.idle_left = randf_range(IDLE_MIN, IDLE_MAX)
	_play(member, false)


func _tick_idle(member: Member, delta: float) -> void:
	member.idle_left -= delta
	if member.idle_left > 0.0:
		return
	_begin_walk(member)


func _tick_walk(member: Member, delta: float) -> void:
	var offset := member.goal - member.sprite.global_position
	if offset.length() <= STOP_DIST:
		_enter_idle(member)
		return
	var step := offset.normalized() * minf(WALK_SPEED * delta, offset.length())
	var next := member.sprite.global_position + step
	if not _point_clear(next):
		_enter_idle(member)
		return
	_face_toward(member, step)
	member.sprite.global_position = next
	_play(member, true)


func _enter_idle(member: Member) -> void:
	member.walking = false
	member.idle_left = randf_range(IDLE_MIN, IDLE_MAX)
	member.face = _random_face()
	_play(member, false)


func _begin_walk(member: Member) -> void:
	var goal := _pick_goal(member)
	if goal.distance_to(member.sprite.global_position) <= STOP_DIST:
		_enter_idle(member)
		return
	member.goal = goal
	member.walking = true
	_face_toward(member, member.goal - member.sprite.global_position)
	_play(member, true)


func _pick_goal(member: Member) -> Vector2:
	for _i in 6:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(16.0, PATCH_RADIUS)
		var goal := member.home + offset
		if _zone.has_point(goal) and _point_clear(goal):
			return goal
	return member.sprite.global_position


func _add_member(pos: Vector2, wanders: bool) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _frames[randi() % _frames.size()]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.offset = Vector2(0, -FRAME * 0.5)
	sprite.position = pos - global_position
	add_child(sprite)
	var member := Member.new()
	member.sprite = sprite
	member.home = pos
	member.wanders = wanders
	member.face = _random_face()
	member.idle_left = randf_range(0.2, IDLE_MAX)
	_members.append(member)
	_play(member, false)


func _play(member: Member, moving: bool) -> void:
	var prefix := "walk_" if moving else "idle_"
	var anim := prefix + member.face
	var sprite := member.sprite
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)


func _face_toward(member: Member, offset: Vector2) -> void:
	if absf(offset.x) > absf(offset.y):
		member.face = "right" if offset.x > 0.0 else "left"
	else:
		member.face = "down" if offset.y > 0.0 else "up"


func _random_face() -> String:
	return FACES[randi() % FACES.size()]


func _point_clear(point: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return true
	var state := world.direct_space_state
	if state == null:
		return true
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return state.intersect_point(params, 1).is_empty()


func _occupied_points(world: Node) -> Array:
	var points: Array = []
	_collect_points(world, points)
	return points


func _collect_points(node: Node, points: Array) -> void:
	if node != self and node is Node2D and node.is_in_group("dialogue"):
		points.append((node as Node2D).global_position)
	for child in node.get_children():
		_collect_points(child, points)


func _is_separated(pos: Vector2, avoid: Array) -> bool:
	for other in avoid:
		if typeof(other) != TYPE_VECTOR2:
			continue
		if pos.distance_to(other) < SEPARATION:
			return false
	return true


func _build_frames() -> Array[SpriteFrames]:
	var built: Array[SpriteFrames] = []
	for sheet in SHEETS:
		built.append(_frames_for(sheet))
	return built


func _frames_for(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for face in FACES:
		var column: int = int(FACE_COLUMN[face])
		_add_anim(frames, "idle_" + face, sheet, column, [0], 1.0)
		_add_anim(frames, "walk_" + face, sheet, column, WALK_ROWS, WALK_FPS)
	return frames


func _add_anim(
	frames: SpriteFrames,
	anim: String,
	sheet: Texture2D,
	column: int,
	rows: Array,
	fps: float
) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for row in rows:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(column * FRAME, int(row) * FRAME, FRAME, FRAME)
		frames.add_frame(anim, atlas)


class Member:
	var sprite: AnimatedSprite2D
	var home := Vector2.ZERO
	var goal := Vector2.ZERO
	var face := "down"
	var idle_left := 0.0
	var wanders := false
	var walking := false
