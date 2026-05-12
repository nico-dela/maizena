extends CanvasLayer

signal finished(victory: bool)

@onready var player_fighter: ColorRect = $Root/Arena/PlayerFighter
@onready var enemy_fighter: ColorRect = $Root/Arena/EnemyFighter
@onready var status_label: Label = $Root/Top/Status
@onready var player_hp_label: Label = $Root/Top/PlayerHP
@onready var enemy_hp_label: Label = $Root/Top/EnemyHP
@onready var btn_left: Button = $Root/Controls/MoveLeft
@onready var btn_right: Button = $Root/Controls/MoveRight
@onready var btn_punch: Button = $Root/Controls/Punch
@onready var btn_kick: Button = $Root/Controls/Kick
@onready var btn_guard: Button = $Root/Controls/Guard
@onready var btn_exit: Button = $Root/Top/Exit
@onready var controls: Control = $Root/Controls
@onready var arena: Panel = $Root/Arena
@onready var countdown_label: Label = $Root/Countdown
@onready var punch_cd_bar: ProgressBar = $Root/Controls/PunchCooldown
@onready var kick_cd_bar: ProgressBar = $Root/Controls/KickCooldown
@onready var tutorial_panel: Panel = $Root/TutorialPanel
@onready var btn_start: Button = $Root/TutorialPanel/StartButton

const PLAYER_SPEED := 240.0
const ENEMY_SPEED := 150.0
const ARENA_LEFT := 60.0
const ARENA_RIGHT := 740.0
const HIT_RANGE := 85.0

var player_hp := 100
var enemy_hp := 100
var player_attack_cooldown := 0.0
var punch_cooldown_max := 0.45
var kick_cooldown_max := 0.75
var enemy_attack_cooldown := 0.0
var enemy_decision_timer := 0.0
var is_guarding := false
var fight_ended := false
var fight_started := false
var punch_ready_prev := true
var kick_ready_prev := true

var touch_move_left := false
var touch_move_right := false
var touch_punch := false
var touch_kick := false
var touch_guard := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_fighter.position = Vector2(130, 220)
	enemy_fighter.position = Vector2(610, 220)
	punch_cd_bar.max_value = 1.0
	punch_cd_bar.value = 1.0
	kick_cd_bar.max_value = 1.0
	kick_cd_bar.value = 1.0
	_update_hud()
	_update_cooldown_ui()

	btn_left.button_down.connect(func(): touch_move_left = true)
	btn_left.button_up.connect(func(): touch_move_left = false)
	btn_right.button_down.connect(func(): touch_move_right = true)
	btn_right.button_up.connect(func(): touch_move_right = false)
	btn_punch.button_down.connect(func(): touch_punch = true)
	btn_punch.button_up.connect(func(): touch_punch = false)
	btn_kick.button_down.connect(func(): touch_kick = true)
	btn_kick.button_up.connect(func(): touch_kick = false)
	btn_guard.button_down.connect(func(): touch_guard = true)
	btn_guard.button_up.connect(func(): touch_guard = false)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_start.pressed.connect(_on_start_pressed)

	countdown_label.hide()
	controls.hide()
	tutorial_panel.show()
	status_label.text = "Lee el instructivo y presiona EMPEZAR."

func _process(delta: float):
	if fight_ended:
		return

	if not fight_started:
		return

	player_attack_cooldown = max(player_attack_cooldown - delta, 0.0)
	enemy_attack_cooldown = max(enemy_attack_cooldown - delta, 0.0)
	enemy_decision_timer = max(enemy_decision_timer - delta, 0.0)
	_update_cooldown_ui()

	_handle_player_input(delta)
	_handle_enemy(delta)
	_check_end()

func _input(event: InputEvent):
	if fight_ended:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()

func _handle_player_input(delta: float):
	var move_axis := 0.0
	if Input.is_action_pressed("ui_left") or touch_move_left:
		move_axis -= 1.0
	if Input.is_action_pressed("ui_right") or touch_move_right:
		move_axis += 1.0

	if move_axis != 0.0:
		player_fighter.position.x = clamp(player_fighter.position.x + move_axis * PLAYER_SPEED * delta, ARENA_LEFT, ARENA_RIGHT)

	is_guarding = Input.is_key_pressed(KEY_SHIFT) or touch_guard

	if (Input.is_key_pressed(KEY_SPACE) or touch_punch) and player_attack_cooldown <= 0.0:
		_try_player_attack(10, punch_cooldown_max, "Golpeaste.")
		touch_punch = false
	elif (Input.is_key_pressed(KEY_ENTER) or touch_kick) and player_attack_cooldown <= 0.0:
		_try_player_attack(16, kick_cooldown_max, "Patada fuerte.")
		touch_kick = false

func _try_player_attack(damage: int, cooldown: float, msg: String):
	player_attack_cooldown = cooldown
	if abs(player_fighter.position.x - enemy_fighter.position.x) <= HIT_RANGE:
		enemy_hp = max(enemy_hp - damage, 0)
		enemy_fighter.position.x = clamp(enemy_fighter.position.x + 14.0, ARENA_LEFT, ARENA_RIGHT)
		_hit_feedback(enemy_fighter, Color(1.0, 0.85, 0.85, 1.0))
		status_label.text = msg
	else:
		status_label.text = "Fallaste el golpe."
	_update_hud()

func _handle_enemy(delta: float):
	var distance := enemy_fighter.position.x - player_fighter.position.x
	if abs(distance) > HIT_RANGE - 10.0:
		var dir: float = sign(-distance)
		enemy_fighter.position.x = clamp(enemy_fighter.position.x + dir * ENEMY_SPEED * delta, ARENA_LEFT, ARENA_RIGHT)

	if enemy_decision_timer > 0.0:
		return
	enemy_decision_timer = randf_range(0.35, 0.85)

	if enemy_attack_cooldown > 0.0:
		return
	if abs(player_fighter.position.x - enemy_fighter.position.x) > HIT_RANGE:
		return

	enemy_attack_cooldown = randf_range(0.55, 1.05)
	var incoming := randi_range(8, 14)
	if is_guarding:
		incoming = int(round(incoming * 0.35))
		status_label.text = "Bloqueaste parte del ataque."
	else:
		status_label.text = "Bollo te golpeo."
	player_hp = max(player_hp - incoming, 0)
	player_fighter.position.x = clamp(player_fighter.position.x - 11.0, ARENA_LEFT, ARENA_RIGHT)
	_hit_feedback(player_fighter, Color(0.85, 1.0, 0.9, 1.0))
	_update_hud()

func _check_end():
	if enemy_hp <= 0:
		_end_fight(true, "Ganaste. Bollo aprendio lo basico.")
	elif player_hp <= 0:
		_end_fight(false, "Perdiste. Puedes volver a intentarlo.")

func _end_fight(victory: bool, msg: String):
	fight_ended = true
	status_label.text = msg
	await get_tree().create_timer(1.2, true, false, true).timeout
	finished.emit(victory)
	queue_free()

func _update_hud():
	player_hp_label.text = "Sanjin HP: %d" % player_hp
	enemy_hp_label.text = "Bollo HP: %d" % enemy_hp

func _hit_feedback(target: CanvasItem, flash_color: Color):
	var tween := create_tween()
	tween.tween_property(target, "modulate", flash_color, 0.06)
	tween.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.1)

	var shake := create_tween()
	var base := arena.position
	shake.tween_property(arena, "position", base + Vector2(-4, 0), 0.03)
	shake.tween_property(arena, "position", base + Vector2(4, 0), 0.03)
	shake.tween_property(arena, "position", base, 0.04)

func _on_exit_pressed():
	if fight_ended:
		return
	_end_fight(false, "Entrenamiento cancelado.")

func _start_countdown():
	countdown_label.show()
	countdown_label.text = "3"
	await get_tree().create_timer(0.55, true, false, true).timeout
	countdown_label.text = "2"
	await get_tree().create_timer(0.55, true, false, true).timeout
	countdown_label.text = "1"
	await get_tree().create_timer(0.55, true, false, true).timeout
	countdown_label.text = "FIGHT"
	await get_tree().create_timer(0.35, true, false, true).timeout
	countdown_label.hide()
	status_label.text = "Pelea!"
	fight_started = true

func _update_cooldown_ui():
	var punch_ratio := 1.0
	var kick_ratio := 1.0

	if player_attack_cooldown > 0.0:
		if player_attack_cooldown > punch_cooldown_max:
			kick_ratio = clamp(1.0 - player_attack_cooldown / kick_cooldown_max, 0.0, 1.0)
			punch_ratio = 0.0
		else:
			punch_ratio = clamp(1.0 - player_attack_cooldown / punch_cooldown_max, 0.0, 1.0)
			kick_ratio = 1.0

	punch_cd_bar.value = punch_ratio
	kick_cd_bar.value = kick_ratio
	btn_punch.modulate = Color(1, 1, 1, 1) if punch_ratio >= 0.99 else Color(0.55, 0.55, 0.6, 1)
	btn_kick.modulate = Color(1, 1, 1, 1) if kick_ratio >= 0.99 else Color(0.55, 0.55, 0.6, 1)

	var punch_ready := punch_ratio >= 0.99
	var kick_ready := kick_ratio >= 0.99
	if punch_ready and not punch_ready_prev:
		_blink_ready(btn_punch)
	if kick_ready and not kick_ready_prev:
		_blink_ready(btn_kick)
	punch_ready_prev = punch_ready
	kick_ready_prev = kick_ready

func _blink_ready(button: Button):
	var tween := create_tween()
	tween.tween_property(button, "modulate", Color(1.0, 1.0, 0.55, 1.0), 0.08)
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.09)

func _on_start_pressed():
	tutorial_panel.hide()
	controls.show()
	_start_countdown()
