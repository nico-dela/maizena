extends CharacterBody2D

const SPEED = 100.0
var current_dir = "none"
var anim_dict = {
	"right": {"flip_h": false, "walk": "side_walk", "idle": "side_idle"},
	"left": {"flip_h": true, "walk": "side_walk", "idle": "side_idle"},
	"down": {"flip_h": true, "walk": "front_walk", "idle": "front_idle"},
	"up": {"flip_h": true, "walk": "back_walk", "idle": "back_idle"}
}

func _ready():
	$AnimatedSprite2D.play("front_idle")

func _physics_process(delta):
	player_movement(delta)

func player_movement(_delta):
	if !global.shown_dialogue:
		velocity = Vector2.ZERO
		if Input.is_action_pressed("ui_right"):
			current_dir = "right"
			velocity.x = SPEED
		elif Input.is_action_pressed("ui_left"):
			current_dir = "left"
			velocity.x = -SPEED
		elif Input.is_action_pressed("ui_down"):
			current_dir = "down"
			velocity.y = SPEED
		elif Input.is_action_pressed("ui_up"):
			current_dir = "up"
			velocity.y = -SPEED

		if velocity != Vector2.ZERO:
			play_anim(1)
		else:
			play_anim(0)
	else:
		velocity = Vector2.ZERO
		play_anim(0)

	move_and_slide()

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
