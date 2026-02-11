extends CharacterBody2D

const SPEED = 100.0
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

func _ready():
	$AnimatedSprite2D.play("front_idle")
	settings_menu = get_tree().root.find_child("Settings", true, false)

func _input(event):
	# Solo procesar taps si el menú no está abierto
	if settings_menu and settings_menu.is_open:
		return
		
	if DialogueController.input_locked:
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
	# Verificar si el menú de configuración está abierto
	if settings_menu and settings_menu.is_open:
		velocity = Vector2.ZERO
		play_anim(0)
		move_and_slide()
		return
	
	if DialogueController.input_locked:
		velocity = Vector2.ZERO
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
		# Movimiento por tap/clic
		if is_moving_to_tap and tap_position != null:
			var target_position = get_global_mouse_position() if tap_position is Vector2 else tap_position
			var direction = (target_position - global_position).normalized()
			var distance = global_position.distance_to(target_position)
			
			if distance > tap_threshold:
				velocity = direction * SPEED
			else:
				is_moving_to_tap = false
				tap_position = null

	if velocity != Vector2.ZERO:
		update_current_dir()
		play_anim(1)
	else:
		play_anim(0)

	move_and_slide()

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
	if body.is_in_group("dialogue"):
		body.show_dialogue()
