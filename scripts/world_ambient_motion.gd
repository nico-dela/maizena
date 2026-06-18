extends Node2D

const AMBIENT_NODE_NAMES := [
	"orbe_electrico",
	"cartel_pantano",
	"templo_sapos",
	"ranancio",
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 18
	_rng.randomize()
	call_deferred("_build_ambient")


func _build_ambient() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for node_name in AMBIENT_NODE_NAMES:
		var target := _find_node_by_name(root, node_name)
		if target == null:
			continue
		var pos: Vector2 = target.global_position
		_add_sparkles(pos + Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-20.0, -6.0)))
		if node_name in ["cartel_pantano", "templo_sapos", "ranancio"]:
			_add_ripples(pos + Vector2(0.0, 10.0))


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found:
			return found
	return null


func _add_sparkles(world_pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.amount = 4
	particles.lifetime = 2.4
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 35.0
	particles.gravity = Vector2(0.0, -8.0)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 10.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	particles.color = Color(0.95, 0.92, 0.55, 0.65)
	add_child(particles)
	particles.global_position = world_pos


func _add_ripples(world_pos: Vector2) -> void:
	var ripple := Sprite2D.new()
	ripple.texture = _make_ripple_texture()
	ripple.centered = true
	ripple.modulate = Color(1.0, 1.0, 1.0, 0.35)
	add_child(ripple)
	ripple.global_position = world_pos

	var tween := create_tween().set_loops()
	tween.tween_property(ripple, "scale", Vector2(1.35, 1.35), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ripple, "modulate:a", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ripple, "scale", Vector2(0.85, 0.85), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ripple, "modulate:a", 0.38, 0.9).set_trans(Tween.TRANS_SINE)


func _make_ripple_texture() -> ImageTexture:
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for x in range(16):
		for y in range(8):
			var dx := absf(x - 7.5) / 7.5
			var dy := absf(y - 4.0) / 4.0
			if dy < 0.55 and dx < 0.95:
				var edge := clampf(1.0 - absf(dx - 0.75) * 6.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, edge * 0.9))
	var tex := ImageTexture.create_from_image(img)
	return tex
