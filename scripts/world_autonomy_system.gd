extends Node

const RARE_SILENCE_CHANCE := 0.04

var world_state: Node = null
var world_rng := RandomNumberGenerator.new()
var ambient_player_a: AudioStreamPlayer2D
var ambient_player_b: AudioStreamPlayer2D
var ambient_timer := 0.0

const EVENT_TRACKS := {
	"hum_3am": preload("res://assets/soundtrack/Resaka.ogg"),
	"distant_knock": preload("res://assets/soundtrack/Grua.ogg"),
	"ghost_pass": preload("res://assets/soundtrack/Colores.ogg")
}

func _ready():
	world_state = get_node_or_null("/root/WorldState")
	world_rng.randomize()
	_build_ambient_players()
	apply_decay_stage()
	apply_absence_mutation()
	set_process(true)

func _process(delta: float):
	if not world_state:
		return

	ambient_timer += delta
	if ambient_timer >= 14.0:
		ambient_timer = 0.0
		_run_ambient_cycle()

func _build_ambient_players():
	ambient_player_a = AudioStreamPlayer2D.new()
	ambient_player_a.name = "AmbientOffscreenA"
	ambient_player_a.position = Vector2(-920, -980)
	ambient_player_a.volume_db = -22.0
	add_child(ambient_player_a)

	ambient_player_b = AudioStreamPlayer2D.new()
	ambient_player_b.name = "AmbientOffscreenB"
	ambient_player_b.position = Vector2(680, -120)
	ambient_player_b.volume_db = -20.0
	add_child(ambient_player_b)

func _run_ambient_cycle():
	var hour := float(world_state.current_hour)
	var presence := float(world_state.get_presence_multiplier())
	var anti_anxiety_factor: float = clamp(1.25 / max(presence, 0.25), 0.4, 2.2)

	if hour >= 2.8 and hour < 3.4:
		_try_play_offscreen("hum_3am", ambient_player_a, 0.18 * anti_anxiety_factor, -18.0)
	elif hour >= 19.0 and hour < 23.0:
		_try_play_offscreen("distant_knock", ambient_player_b, 0.14 * anti_anxiety_factor, -20.0)
	elif hour >= 5.2 and hour < 6.6:
		_try_play_offscreen("ghost_pass", ambient_player_a, 0.10 * anti_anxiety_factor, -23.0)

	if world_rng.randf() < RARE_SILENCE_CHANCE * anti_anxiety_factor:
		_trigger_rare_silence()

func _try_play_offscreen(event_key: String, player: AudioStreamPlayer2D, chance: float, volume_db: float):
	if player.playing:
		return
	if world_rng.randf() > chance:
		return

	player.stream = EVENT_TRACKS[event_key]
	player.volume_db = volume_db
	player.pitch_scale = world_rng.randf_range(0.88, 1.08)
	player.play()

func _trigger_rare_silence():
	var music_manager = get_tree().get_first_node_in_group("music_manager")
	if not music_manager:
		return
	var player = music_manager.get_node_or_null("AudioStreamPlayer2D")
	if not player:
		return

	var original_db: float = player.volume_db
	player.volume_db = -80.0
	var timer := get_tree().create_timer(world_rng.randf_range(4.0, 8.0))
	timer.timeout.connect(func():
		if is_instance_valid(player):
			player.volume_db = original_db
	)

func apply_absence_mutation():
	if not world_state:
		return
	if int(world_state.absent_days) < 2:
		return
	if int(world_state.last_absence_mutation_day) == int(world_state.world_day):
		return

	var candidates: Array[Node] = []
	for node_name in ["ranancio", "el_viejo", "silueto_1", "silueto_2", "boji", "spinetto"]:
		var node := get_node_or_null("../InteractiveObjects/%s" % node_name)
		if node:
			candidates.append(node)

	candidates.shuffle()
	var unseen_impact := int(world_state.consume_unseen_events(2))
	var mut_count: int = clamp(1 + unseen_impact, 1, 3)
	for i in range(min(mut_count, candidates.size())):
		var target = candidates[i]
		var drift := Vector2(world_rng.randf_range(-48.0, 48.0), world_rng.randf_range(-28.0, 28.0))
		target.position += drift
		target.modulate = target.modulate.darkened(world_rng.randf_range(0.05, 0.18))

	world_state.last_absence_mutation_day = int(world_state.world_day)

func apply_decay_stage():
	if not world_state:
		return

	var stage: int = clamp(int(world_state.decay_level / 12), 0, 3)
	var objects := get_node_or_null("../InteractiveObjects")
	if not objects:
		return

	for child in objects.get_children():
		if not child.name.begins_with("cartel_"):
			continue
		var sprite: AnimatedSprite2D = child.get_node_or_null("AnimatedSprite2D")
		var collision: CollisionShape2D = child.get_node_or_null("CollisionShape2D")
		if not sprite:
			continue

		match stage:
			0:
				sprite.modulate = Color(1, 1, 1, 1)
				if collision:
					collision.disabled = false
			1:
				sprite.modulate = Color(0.88, 0.86, 0.8, 0.95)
			2:
				sprite.modulate = Color(0.72, 0.68, 0.62, 0.82)
				sprite.rotation = world_rng.randf_range(-0.05, 0.05)
			3:
				sprite.modulate = Color(0.52, 0.5, 0.46, 0.65)
				sprite.rotation = world_rng.randf_range(-0.12, 0.12)
				if collision and world_rng.randf() < 0.35:
					collision.disabled = true
