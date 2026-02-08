extends CharacterBody2D

const SPEED = 100.0
var current_dir = "none"
var anim_dict = {
	"right": {"flip_h": false, "walk": "side_walk", "idle": "side_idle"},
	"left": {"flip_h": true, "walk": "side_walk", "idle": "side_idle"},
	"down": {"flip_h": true, "walk": "front_walk", "idle": "front_idle"},
	"up": {"flip_h": true, "walk": "back_walk", "idle": "back_idle"}
}

# Añade esta variable para referencia al menú
var settings_menu = null

func _ready():
	$AnimatedSprite2D.play("front_idle")
	# Obtener referencia al nodo Settings en la escena
	settings_menu = get_tree().root.find_child("Settings", true, false)

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
		update_current_dir()
		play_anim(1)
	else:
		play_anim(0)

	move_and_slide()

# El resto del script se mantiene igual...
func update_current_dir():
	if velocity.x > 0:
		current_dir = "right"
	elif velocity.x < 0:
		current_dir = "left"
	elif velocity.y > 0:
		current_dir = "down"
	elif velocity.y < 0:
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
