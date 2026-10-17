extends Node2D

## Luciérnagas sobre el bosque. La niebla de exploración sigue siendo el velo del mapa.


func _ready() -> void:
	var width := 640.0
	var height := 640.0
	var world := get_parent()
	if world != null and world.get("camera_limit_right") != null:
		width = maxf(float(world.camera_limit_right), 64.0)
		height = maxf(float(world.camera_limit_bottom), 64.0)

	var flies := CPUParticles2D.new()
	flies.texture = _glow_texture()
	flies.amount = 24
	flies.lifetime = 3.8
	flies.one_shot = false
	flies.explosiveness = 0.0
	flies.randomness = 0.8
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.position = Vector2(width * 0.5, height * 0.5)
	flies.emission_rect_extents = Vector2(width * 0.46, height * 0.46)
	flies.direction = Vector2(0.2, -0.15)
	flies.spread = 180.0
	flies.gravity = Vector2(0, -2)
	flies.initial_velocity_min = 4.0
	flies.initial_velocity_max = 14.0
	flies.scale_amount_min = 0.35
	flies.scale_amount_max = 0.8
	flies.color = Color(2.4, 3.0, 1.1, 1.0)
	flies.z_index = 2
	add_child(flies)


func _glow_texture() -> Texture2D:
	var size := 8
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for x in size:
		for y in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)
