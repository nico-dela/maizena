extends Node

var world_state: Node = null
var world_rng := RandomNumberGenerator.new()

func _ready():
	world_state = get_node_or_null("/root/WorldState")
	world_rng.randomize()
	apply_decay_stage()
	apply_absence_mutation()

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
