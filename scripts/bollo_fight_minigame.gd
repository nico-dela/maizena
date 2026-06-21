extends CanvasLayer

signal finished(victory: bool)

enum UiPhase { TUTORIAL, PLAYER_TURN, ENEMY_TURN, CONFIRM_EXIT, ENDED }

const MAX_HP := 100
const BLOCK_DAMAGE_FACTOR := 0.35
const REST_HEAL := 12
const PUNCH_MISS_CHANCE := 0.18
const KICK_MISS_CHANCE := 0.28
const CRIT_CHANCE := 0.12
const CRIT_MULTIPLIER := 1.5
const ENEMY_MISS_CHANCE := 0.14
const DISTRACTED_MISS_BONUS := 0.22

const MOVES: Array[Dictionary] = [
	{"id": "punch", "name": "Golpe", "damage": 10, "label": "GOLPE", "miss_chance": PUNCH_MISS_CHANCE},
	{"id": "kick", "name": "Patada", "damage": 16, "label": "PATADA", "miss_chance": KICK_MISS_CHANCE},
	{"id": "block", "name": "Bloquear", "damage": 0, "label": "BLOQUEAR"},
	{"id": "rest", "name": "Descansar", "damage": 0, "label": "DESCANSAR", "heal": REST_HEAL},
]

const ENEMY_MOVES: Array[Dictionary] = [
	{"kind": "attack", "name": "Golpe", "damage_min": 8, "damage_max": 10, "weight": 4},
	{"kind": "attack", "name": "Patada", "damage_min": 12, "damage_max": 14, "weight": 3},
	{"kind": "attack", "name": "Embestida", "damage_min": 6, "damage_max": 8, "weight": 2},
	{"kind": "heavy", "name": "Golpe fuerte", "damage_min": 16, "damage_max": 20, "weight": 2},
	{"kind": "dodge", "name": "Esquiva", "weight": 2},
	{"kind": "trip", "name": "Tropiezo", "self_damage": 5, "weight": 2},
	{"kind": "taunt", "name": "Provocación", "weight": 2},
]

const INTRO_PAUSE_SEC := 1.0
const PLAYER_ACTION_PAUSE_SEC := 0.75
const ENEMY_TURN_PAUSE_SEC := 1.1
const BATTLE_DESIGN_LANDSCAPE := Vector2(800.0, 300.0)
const BATTLE_DESIGN_PORTRAIT := Vector2(640.0, 300.0)
const ACTION_PANEL_BASE_H := 196.0

@onready var battle_field: Control = $Root/BattleContent/BattleField
@onready var action_panel: Control = $Root/BattleContent/ActionPanel
@onready var battle_content: Control = $Root/BattleContent
@onready var player_sprite: CanvasItem = $Root/BattleContent/BattleField/PlayerSprite
@onready var enemy_sprite: CanvasItem = $Root/BattleContent/BattleField/EnemySprite
@onready var player_hp_bar: ProgressBar = $Root/BattleContent/BattleField/PlayerHUD/HPBar
@onready var enemy_hp_bar: ProgressBar = $Root/BattleContent/BattleField/EnemyHUD/HPBar
@onready var player_hp_value: Label = $Root/BattleContent/BattleField/PlayerHUD/HPValue
@onready var enemy_hp_value: Label = $Root/BattleContent/BattleField/EnemyHUD/HPValue
@onready var turn_banner: Label = $Root/BattleContent/ActionPanel/TurnBanner
@onready var message_label: Label = $Root/BattleContent/ActionPanel/MessageLabel
@onready var move_grid: GridContainer = $Root/BattleContent/ActionPanel/MoveGrid
@onready var continue_button: Button = $Root/BattleContent/ActionPanel/ContinueButton
@onready var tutorial_panel: Panel = $Root/TutorialPanel
@onready var tutorial_title: Label = $Root/TutorialPanel/Title
@onready var tutorial_instructions: Label = $Root/TutorialPanel/Instructions
@onready var btn_start: Button = $Root/TutorialPanel/StartButton
@onready var btn_exit: Button = $Root/ExitButton
@onready var confirm_exit_panel: Panel = $Root/ConfirmExitPanel
@onready var confirm_message: Label = $Root/ConfirmExitPanel/Message
@onready var btn_confirm_yes: Button = $Root/ConfirmExitPanel/Buttons/ConfirmYes
@onready var btn_confirm_no: Button = $Root/ConfirmExitPanel/Buttons/ConfirmNo

var move_buttons: Array[Button] = []
var ui_phase := UiPhase.TUTORIAL
var player_hp := MAX_HP
var enemy_hp := MAX_HP
var player_blocking := false
var bollo_dodging := false
var player_distracted := false
var rest_used := false
var fight_started := false
var fight_ended := false
var _saved_ui_phase := UiPhase.TUTORIAL
var _focused_move_index := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_hp_bar.max_value = MAX_HP
	enemy_hp_bar.max_value = MAX_HP
	_collect_move_buttons()
	_bind_actions()
	_update_hp_bars()
	_set_ui_phase(UiPhase.TUTORIAL)
	battle_content.hide()
	tutorial_panel.show()
	confirm_exit_panel.hide()
	_apply_viewport_layout()
	ViewportLayout.layout_changed.connect(_apply_viewport_layout)
	call_deferred("_apply_viewport_layout")


func _exit_tree() -> void:
	if GameState.bollo_training_active:
		GameState.bollo_training_active = false
		DialogueController.input_locked = false
		get_tree().paused = false


func _fight_ui_scale() -> float:
	return minf(ViewportLayout.effective_ui_scale(), 2.5)


func _fit_centered_panel(panel: Control, width: float, height: float) -> void:
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5


func _apply_viewport_layout() -> void:
	ViewportLayout.refresh()
	var s := _fight_ui_scale()
	var vp := get_viewport().get_visible_rect().size
	var portrait := ViewportLayout.is_portrait
	var battle_design := BATTLE_DESIGN_PORTRAIT if portrait else BATTLE_DESIGN_LANDSCAPE

	var tutorial_w := minf(680.0, vp.x * 0.96)
	var tutorial_h := minf(400.0, vp.y * (0.58 if portrait else 0.42))
	_fit_centered_panel(tutorial_panel, tutorial_w, tutorial_h)
	tutorial_title.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(26))
	tutorial_instructions.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(15))
	tutorial_instructions.offset_left = 16.0 * s
	tutorial_instructions.offset_right = -16.0 * s
	btn_start.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(20))
	btn_start.custom_minimum_size = Vector2(minf(320.0 * s, tutorial_w - 32.0 * s), maxf(48.0, 44.0 * s))

	var confirm_w := minf(560.0, vp.x * 0.92)
	var confirm_h := 200.0 * s
	_fit_centered_panel(confirm_exit_panel, confirm_w, confirm_h)
	confirm_message.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	btn_confirm_yes.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	btn_confirm_no.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	btn_confirm_yes.custom_minimum_size = Vector2(160.0 * s, 44.0 * s)
	btn_confirm_no.custom_minimum_size = Vector2(160.0 * s, 44.0 * s)

	var exit_w := maxf(108.0, 96.0 * s)
	var exit_h := maxf(36.0, 32.0 * s)
	btn_exit.custom_minimum_size = Vector2(exit_w, exit_h)
	btn_exit.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	var exit_margin_top: float = ViewportLayout.screen_margin_top(12.0)
	var exit_margin_right: float = ViewportLayout.screen_margin_right(12.0)
	btn_exit.offset_left = -exit_margin_right - exit_w
	btn_exit.offset_top = exit_margin_top
	btn_exit.offset_right = -exit_margin_right
	btn_exit.offset_bottom = exit_margin_top + exit_h

	battle_content.offset_top = ViewportLayout.screen_margin_top(maxf(52.0, 40.0 * s))

	var action_panel_h := vp.y * (0.30 if portrait else 0.22)
	action_panel_h = maxf(ACTION_PANEL_BASE_H * s * 0.85, action_panel_h)
	var action_side := 8.0 if portrait else 12.0
	action_panel.offset_left = action_side
	action_panel.offset_right = -action_side
	action_panel.offset_top = -action_panel_h
	action_panel.offset_bottom = -ViewportLayout.screen_margin_bottom(8.0 if portrait else 12.0)
	move_grid.columns = 1 if portrait else 2

	if portrait:
		battle_field.offset_left = -battle_design.x * 0.5
		battle_field.offset_right = battle_design.x * 0.5
		battle_field.offset_top = -280.0
		battle_field.offset_bottom = 40.0
	else:
		battle_field.offset_left = -400.0
		battle_field.offset_right = 400.0
		battle_field.offset_top = -220.0
		battle_field.offset_bottom = 80.0

	var avail_h: float = vp.y - battle_content.offset_top - (exit_margin_top + exit_h) - action_panel_h * 0.5
	avail_h = maxf(avail_h, battle_design.y * 0.55)
	var battle_s := minf(vp.x * 0.96 / battle_design.x, avail_h / battle_design.y)
	if portrait:
		battle_s *= 1.12
	battle_s = clampf(battle_s, 0.55, 2.8)
	battle_content.scale = Vector2(battle_s, battle_s)
	call_deferred("_update_battle_pivot", portrait)

	turn_banner.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(18))
	message_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16))
	continue_button.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(18))
	player_hp_value.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(14))
	enemy_hp_value.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(14))
	for btn in move_buttons:
		btn.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(18))
		btn.custom_minimum_size.y = maxf(56.0, 50.0 * s)


func _update_battle_pivot(portrait: bool = ViewportLayout.is_portrait) -> void:
	if portrait:
		battle_content.pivot_offset = Vector2(battle_content.size.x * 0.5, battle_content.size.y)
	else:
		battle_content.pivot_offset = battle_content.size * 0.5


func _collect_move_buttons() -> void:
	move_buttons.clear()
	for i in move_grid.get_child_count():
		var child := move_grid.get_child(i)
		if child is Button:
			move_buttons.append(child)

func _bind_actions() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_exit.pressed.connect(_request_exit)
	btn_confirm_yes.pressed.connect(_confirm_exit_yes)
	btn_confirm_no.pressed.connect(_confirm_exit_no)
	for i in move_buttons.size():
		var index := i
		move_buttons[i].pressed.connect(func(): _on_move_selected(index))

func _input(event: InputEvent) -> void:
	if fight_ended:
		return
	if not event.is_pressed() or event.is_echo():
		return

	if ui_phase == UiPhase.CONFIRM_EXIT:
		_handle_confirm_exit_input(event)
		return

	if ui_phase == UiPhase.TUTORIAL:
		if event.is_action_pressed("ui_accept"):
			_on_start_pressed()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_request_exit()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_request_exit()
		get_viewport().set_input_as_handled()
		return

	if ui_phase == UiPhase.PLAYER_TURN:
		if event.is_action_pressed("ui_accept"):
			_on_move_selected(_focused_move_index)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left"):
			_focus_move(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_focus_move(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
			_focus_move(-2)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			_focus_move(2)
			get_viewport().set_input_as_handled()
			return
		for i in move_buttons.size():
			var key := KEY_1 + i
			if event is InputEventKey and event.keycode == key:
				_on_move_selected(i)
				get_viewport().set_input_as_handled()
				return

func _handle_confirm_exit_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_confirm_exit_no()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if btn_confirm_no.has_focus():
			_confirm_exit_no()
		else:
			_confirm_exit_yes()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_Y:
			_confirm_exit_yes()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_N:
			_confirm_exit_no()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_LEFT:
			btn_confirm_no.grab_focus()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_RIGHT:
			btn_confirm_yes.grab_focus()
			get_viewport().set_input_as_handled()

func _focus_move(delta: int) -> void:
	if move_buttons.is_empty():
		return
	var attempts := move_buttons.size()
	for _i in attempts:
		_focused_move_index = posmod(_focused_move_index + delta, move_buttons.size())
		if _is_move_available(_focused_move_index):
			move_buttons[_focused_move_index].grab_focus()
			return

func _set_ui_phase(phase: UiPhase) -> void:
	ui_phase = phase
	match phase:
		UiPhase.TUTORIAL:
			tutorial_panel.show()
			battle_content.hide()
			confirm_exit_panel.hide()
		UiPhase.PLAYER_TURN:
			tutorial_panel.hide()
			battle_content.show()
			confirm_exit_panel.hide()
			turn_banner.text = "TU TURNO"
			turn_banner.modulate = Color(0.55, 1.0, 0.65, 1.0)
			message_label.text = "Elige un movimiento."
			continue_button.hide()
			move_grid.show()
			_refresh_move_buttons(true)
			_focused_move_index = _first_available_move_index()
			if _focused_move_index >= 0:
				move_buttons[_focused_move_index].grab_focus()
		UiPhase.ENEMY_TURN:
			move_grid.hide()
			_set_move_buttons_enabled(false)
			continue_button.hide()
			turn_banner.text = "TURNO DE BOLLO"
			turn_banner.modulate = Color(1.0, 0.75, 0.45, 1.0)
		UiPhase.CONFIRM_EXIT:
			confirm_exit_panel.show()
			btn_confirm_no.grab_focus()
		UiPhase.ENDED:
			move_grid.hide()
			continue_button.hide()
			_set_move_buttons_enabled(false)

func _set_move_buttons_enabled(enabled: bool) -> void:
	_refresh_move_buttons(enabled)


func _is_move_available(index: int) -> bool:
	if index < 0 or index >= MOVES.size():
		return false
	if MOVES[index]["id"] == "rest" and rest_used:
		return false
	return true


func _first_available_move_index() -> int:
	for i in move_buttons.size():
		if _is_move_available(i):
			return i
	return 0


func _refresh_move_buttons(enabled: bool) -> void:
	for i in move_buttons.size():
		var button := move_buttons[i]
		var available := _is_move_available(i)
		button.disabled = not enabled or not available
		if i < MOVES.size():
			var label: String = MOVES[i]["label"]
			if MOVES[i]["id"] == "rest" and rest_used:
				button.text = "%s (usado)" % label
			else:
				button.text = "%s (%d)" % [label, i + 1]

func _on_start_pressed() -> void:
	if fight_started or fight_ended:
		return
	fight_started = true
	tutorial_panel.hide()
	battle_content.show()
	_begin_battle()

func _begin_battle() -> void:
	player_hp = MAX_HP
	enemy_hp = MAX_HP
	player_blocking = false
	bollo_dodging = false
	player_distracted = false
	rest_used = false
	_update_hp_bars()
	message_label.text = "¡Combate de entrenamiento!"
	await _battle_pause(INTRO_PAUSE_SEC)
	_player_turn()

func _player_turn() -> void:
	if _check_end():
		return
	player_blocking = false
	_set_ui_phase(UiPhase.PLAYER_TURN)

func _on_move_selected(index: int) -> void:
	if ui_phase != UiPhase.PLAYER_TURN or fight_ended:
		return
	if index < 0 or index >= MOVES.size():
		return
	if not _is_move_available(index):
		return
	_set_move_buttons_enabled(false)
	_resolve_player_move(MOVES[index])

func _resolve_player_move(move: Dictionary) -> void:
	if move["id"] == "block":
		player_blocking = true
		message_label.text = "¡Sanjin se prepara para bloquear!"
	elif move["id"] == "rest":
		rest_used = true
		var healed: int = mini(move.get("heal", REST_HEAL), MAX_HP - player_hp)
		player_hp = mini(player_hp + healed, MAX_HP)
		message_label.text = "¡Sanjin descansó! +%d HP." % healed
		_update_hp_bars(true, false)
	else:
		_resolve_player_attack(move)

	move_grid.hide()
	_set_move_buttons_enabled(false)
	await _battle_pause(PLAYER_ACTION_PAUSE_SEC)
	if _check_end():
		return
	await _enemy_turn()


func _resolve_player_attack(move: Dictionary) -> void:
	var move_name: String = move["name"]

	if bollo_dodging:
		bollo_dodging = false
		message_label.text = "¡Bollo esquivó el %s!" % move_name.to_lower()
		_dodge_feedback(enemy_sprite)
		return

	var miss_chance: float = move.get("miss_chance", 0.15)
	if player_distracted:
		miss_chance += DISTRACTED_MISS_BONUS
		player_distracted = false

	if randf() < miss_chance:
		message_label.text = "¡Sanjin falló el %s!" % move_name.to_lower()
		_miss_feedback(player_sprite)
		return

	var damage: int = move["damage"]
	var is_crit := randf() < CRIT_CHANCE
	if is_crit:
		damage = int(round(float(damage) * CRIT_MULTIPLIER))

	enemy_hp = maxi(enemy_hp - damage, 0)
	if is_crit:
		message_label.text = "¡Golpe crítico! %s -%d HP." % [move_name, damage]
	else:
		message_label.text = "¡Sanjin usó %s! -%d HP." % [move_name, damage]
	_hit_feedback(enemy_sprite, Color(1.0, 0.85, 0.85, 1.0))
	_update_hp_bars(false, true)

func _enemy_turn() -> void:
	if _check_end():
		return
	_set_ui_phase(UiPhase.ENEMY_TURN)
	await get_tree().create_timer(0.35, true, false, true).timeout

	var move := _pick_enemy_move()
	_resolve_enemy_move(move)

	player_blocking = false

	await _battle_pause(ENEMY_TURN_PAUSE_SEC)
	if _check_end():
		return
	_player_turn()


func _resolve_enemy_move(move: Dictionary) -> void:
	var kind: String = move.get("kind", "attack")
	match kind:
		"dodge":
			bollo_dodging = true
			message_label.text = "¡Bollo se concentra para esquivar!"
			_dodge_feedback(enemy_sprite)
		"trip":
			var self_damage: int = move.get("self_damage", 5)
			enemy_hp = maxi(enemy_hp - self_damage, 0)
			message_label.text = "¡Bollo tropezó! -%d HP para Bollo." % self_damage
			_miss_feedback(enemy_sprite)
			_update_hp_bars(false, true)
		"taunt":
			player_distracted = true
			message_label.text = "¡Bollo te provoca! Tu próximo golpe puede fallar."
			_taunt_feedback(enemy_sprite)
		_:
			if randf() < ENEMY_MISS_CHANCE:
				message_label.text = "¡Bollo falló su %s!" % move["name"].to_lower()
				_miss_feedback(enemy_sprite)
				return

			var damage := randi_range(move["damage_min"], move["damage_max"])
			if player_blocking:
				damage = int(round(damage * BLOCK_DAMAGE_FACTOR))
				message_label.text = "¡Bollo usó %s! Bloqueaste. -%d HP." % [move["name"], damage]
			elif kind == "heavy":
				message_label.text = "¡Bollo cargó un %s! -%d HP." % [move["name"], damage]
			else:
				message_label.text = "¡Bollo usó %s! -%d HP." % [move["name"], damage]

			player_hp = maxi(player_hp - damage, 0)
			_hit_feedback(player_sprite, Color(0.85, 1.0, 0.9, 1.0))
			_update_hp_bars(true, false)

func _pick_enemy_move() -> Dictionary:
	var total_weight := 0
	for move in ENEMY_MOVES:
		total_weight += move["weight"]
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for move in ENEMY_MOVES:
		cumulative += move["weight"]
		if roll <= cumulative:
			return move
	return ENEMY_MOVES[0]

func _battle_pause(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _check_end() -> bool:
	if enemy_hp <= 0:
		_end_fight(true, "¡Ganaste! Bollo aprendió lo básico.")
		return true
	if player_hp <= 0:
		_end_fight(false, "Perdiste. Puedes volver a intentarlo.")
		return true
	return false

func _end_fight(victory: bool, msg: String) -> void:
	if fight_ended:
		return
	fight_ended = true
	_set_ui_phase(UiPhase.ENDED)
	message_label.text = msg
	turn_banner.text = "FIN"
	await get_tree().create_timer(1.2, true, false, true).timeout
	finished.emit(victory)
	queue_free()

func _update_hp_bars(animate_player: bool = false, animate_enemy: bool = false) -> void:
	player_hp_value.text = "%d/%d" % [player_hp, MAX_HP]
	enemy_hp_value.text = "%d/%d" % [enemy_hp, MAX_HP]
	if animate_player:
		_tween_hp_bar(player_hp_bar, player_hp)
	else:
		player_hp_bar.value = player_hp
	if animate_enemy:
		_tween_hp_bar(enemy_hp_bar, enemy_hp)
	else:
		enemy_hp_bar.value = enemy_hp
	_apply_hp_bar_color(player_hp_bar, player_hp)
	_apply_hp_bar_color(enemy_hp_bar, enemy_hp)

func _tween_hp_bar(bar: ProgressBar, target_hp: int) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", float(target_hp), 0.45)

func _apply_hp_bar_color(bar: ProgressBar, hp: int) -> void:
	var ratio := float(hp) / float(MAX_HP)
	var fill := StyleBoxFlat.new()
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_right = 2
	fill.corner_radius_bottom_left = 2
	if ratio > 0.5:
		fill.bg_color = Color(0.25, 0.78, 0.35, 1.0)
	elif ratio > 0.25:
		fill.bg_color = Color(0.9, 0.78, 0.2, 1.0)
	else:
		fill.bg_color = Color(0.85, 0.25, 0.25, 1.0)
	bar.add_theme_stylebox_override("fill", fill)

func _hit_feedback(target: CanvasItem, flash_color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", flash_color, 0.06)
	tween.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.12)


func _miss_feedback(target: CanvasItem) -> void:
	var tween := create_tween()
	var base_pos: Vector2 = target.position
	tween.tween_property(target, "modulate", Color(0.75, 0.75, 0.8, 1.0), 0.08)
	tween.parallel().tween_property(target, "position", base_pos + Vector2(-6, 0), 0.06)
	tween.tween_property(target, "position", base_pos + Vector2(6, 0), 0.06)
	tween.tween_property(target, "position", base_pos, 0.06)
	tween.parallel().tween_property(target, "modulate", Color(1, 1, 1, 1), 0.1)


func _dodge_feedback(target: CanvasItem) -> void:
	var tween := create_tween()
	var base_pos: Vector2 = target.position
	tween.tween_property(target, "modulate", Color(0.7, 0.95, 1.0, 1.0), 0.08)
	tween.parallel().tween_property(target, "position", base_pos + Vector2(14, -4), 0.12)
	tween.tween_property(target, "position", base_pos, 0.12)
	tween.parallel().tween_property(target, "modulate", Color(1, 1, 1, 1), 0.1)


func _taunt_feedback(target: CanvasItem) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(1.0, 0.9, 0.55, 1.0), 0.1)
	tween.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.12)

func _request_exit() -> void:
	if fight_ended:
		return
	if ui_phase == UiPhase.CONFIRM_EXIT:
		return
	_saved_ui_phase = ui_phase
	_set_ui_phase(UiPhase.CONFIRM_EXIT)

func _confirm_exit_yes() -> void:
	confirm_exit_panel.hide()
	_end_fight(false, "Entrenamiento cancelado.")

func _confirm_exit_no() -> void:
	confirm_exit_panel.hide()
	ui_phase = _saved_ui_phase
	match _saved_ui_phase:
		UiPhase.TUTORIAL:
			tutorial_panel.show()
			battle_content.hide()
		UiPhase.PLAYER_TURN:
			_set_ui_phase(UiPhase.PLAYER_TURN)
		UiPhase.ENEMY_TURN:
			_set_ui_phase(UiPhase.ENEMY_TURN)
