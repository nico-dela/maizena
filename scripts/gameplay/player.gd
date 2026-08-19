extends CharacterBody2D

const SPEED = 100.0
const BASE_CAMERA_ZOOM := Vector2(4, 4)
var current_dir = "none"
var anim_dict = {
	"right": {"flip_h": false, "walk": "side_walk", "idle": "side_idle"},
	"left": {"flip_h": true, "walk": "side_walk", "idle": "side_idle"},
	"down": {"flip_h": true, "walk": "front_walk", "idle": "front_idle"},
	"up": {"flip_h": true, "walk": "back_walk", "idle": "back_idle"}
}

# Variables para movimiento por tap/clic
var tap_position = null
var is_moving_to_tap = false
var tap_threshold = 10.0

# Referencia al menú
var settings_menu = null
var welcome_popup: Node = null
var _joystick: Node = null
var _is_mobile := false

@onready var _body_collision: CollisionShape2D = $CollisionShape2D

var _map_limits := Rect2(0.0, 0.0, 640.0, 640.0)


func _ready():
	$AnimatedSprite2D.play("front_idle")
	settings_menu = get_tree().get_first_node_in_group("settings_menu")
	welcome_popup = get_tree().get_first_node_in_group("welcome_popup")
	_is_mobile = OS.has_feature("mobile")
	var ui := get_parent().get_node_or_null("UI")
	if ui != null:
		_joystick = ui.get_node_or_null("VirtualJoystick")
	_apply_camera_zoom()
	ViewportLayout.layout_changed.connect(_apply_camera_zoom)
	call_deferred("_refresh_viewport_layout")
	call_deferred("_ensure_can_move")
	call_deferred("_apply_camera_limits_from_current_world")


func _refresh_viewport_layout() -> void:
	ViewportLayout.refresh()


func _ensure_can_move() -> void:
	if GameState.bollo_training_active:
		return
	if DialogueController.input_locked:
		return
	if settings_menu != null and settings_menu.is_open:
		return
	get_tree().paused = false


func reset_movement() -> void:
	velocity = Vector2.ZERO
	is_moving_to_tap = false
	tap_position = null
	Input.flush_buffered_events()
	play_anim(0)


func _apply_camera_zoom() -> void:
	var cam: Camera2D = $Camera2D
	if cam == null:
		return
	var boost := ViewportLayout.camera_boost
	cam.zoom = BASE_CAMERA_ZOOM * boost


func apply_camera_limits(limit_right: int, limit_bottom: int) -> void:
	var cam: Camera2D = $Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = limit_right
	cam.limit_bottom = limit_bottom
	_map_limits.size = Vector2(limit_right, limit_bottom)
	global_position = _clamp_to_map(global_position)


## Deja la cámara centrada en el jugador sin interpolar, para teleports entre mapas.
func snap_camera_to_player() -> void:
	var cam: Camera2D = $Camera2D
	if cam == null:
		return
	cam.drag_horizontal_offset = 0.0
	cam.drag_vertical_offset = 0.0
	cam.reset_smoothing()
	cam.force_update_scroll()


func _clamp_to_map(target: Vector2) -> Vector2:
	var footprint := Rect2()
	if _body_collision != null and _body_collision.shape != null:
		footprint = _body_collision.shape.get_rect()
		footprint.position += _body_collision.position

	var minimum := _map_limits.position - footprint.position
	var maximum := _map_limits.end - footprint.end
	return Vector2(
		clampf(target.x, minimum.x, maximum.x),
		clampf(target.y, minimum.y, maximum.y)
	)


func apply_camera_limits_from_world(world: Node) -> void:
	if world == null:
		return
	var right: int = 640
	var bottom: int = 640
	if "camera_limit_right" in world:
		right = int(world.camera_limit_right)
	if "camera_limit_bottom" in world:
		bottom = int(world.camera_limit_bottom)
	apply_camera_limits(right, bottom)


func _apply_camera_limits_from_current_world() -> void:
	var root := get_parent()
	if root == null:
		return
	var world := root.get_node_or_null("NewWorld")
	if world != null:
		apply_camera_limits_from_world(world)

func _input(event):
	# Solo procesar taps si el menú no está abierto
	if settings_menu and settings_menu.is_open:
		return

	if welcome_popup and welcome_popup.has_method("is_blocking") and welcome_popup.call("is_blocking"):
		return
		
	if DialogueController.input_locked:
		return

	# Mobile usa el stick fijo; tap-to-move tapaba el sprite.
	if _is_mobile:
		return
	
	# Detectar tap/clic en la pantalla
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tap_position = event.position
			is_moving_to_tap = true
		
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_moving_to_tap = false
			tap_position = null

func _physics_process(_delta):
	if _movement_blocked():
		velocity = Vector2.ZERO
		if GameState.bollo_training_active:
			is_moving_to_tap = false
			tap_position = null
		play_anim(0)
		move_and_slide()
		return

	velocity = Vector2.ZERO

	# Input por teclado
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 1
	
	if velocity != Vector2.ZERO:
		velocity = velocity.normalized() * SPEED
	else:
		var joy := _joystick_vector()
		if joy != Vector2.ZERO:
			velocity = joy.normalized() * SPEED
		elif not _is_mobile:
			_apply_click_hold_move()

	if velocity != Vector2.ZERO:
		update_current_dir()
		play_anim(1)
	else:
		play_anim(0)

	move_and_slide()
	global_position = _clamp_to_map(global_position)


func _movement_blocked() -> bool:
	if settings_menu and settings_menu.is_open:
		return true
	if welcome_popup and welcome_popup.has_method("is_blocking") and welcome_popup.call("is_blocking"):
		return true
	if DialogueController.input_locked:
		return true
	return GameState.bollo_training_active


func _apply_click_hold_move() -> void:
	if not is_moving_to_tap or tap_position == null:
		return
	var target_position := _clamp_to_map(get_global_mouse_position())
	var distance := global_position.distance_to(target_position)
	if distance > tap_threshold:
		velocity = (target_position - global_position).normalized() * SPEED
	else:
		is_moving_to_tap = false
		tap_position = null


func _joystick_vector() -> Vector2:
	if _joystick == null or not is_instance_valid(_joystick):
		return Vector2.ZERO
	if not _joystick.visible:
		return Vector2.ZERO
	if _joystick.has_method("get_vector"):
		return _joystick.get_vector()
	return Vector2.ZERO

func update_current_dir():
	# Priorizar la dirección con mayor magnitud
	if abs(velocity.x) > abs(velocity.y):
		# Movimiento horizontal
		if velocity.x > 0:
			current_dir = "right"
		else:
			current_dir = "left"
	else:
		# Movimiento vertical
		if velocity.y > 0:
			current_dir = "down"
		else:
			current_dir = "up"

func play_anim(movement):
	if current_dir in anim_dict:
		var dir_info = anim_dict[current_dir]
		$AnimatedSprite2D.flip_h = dir_info["flip_h"]
		
		if movement == 1:
			$AnimatedSprite2D.play(dir_info["walk"])
		elif movement == 0:
			$AnimatedSprite2D.play(dir_info["idle"])

func _on_detection_area_body_entered(body):
	if body.is_in_group("dialogue") and body.has_method("show_dialogue"):
		body.show_dialogue()

func _on_detection_area_area_entered(area):
	if area.is_in_group("dialogue") and area.has_method("show_dialogue"):
		area.show_dialogue()
