extends Node2D

## Papeles y polvo cruzando la ciudad. Los faroles siguen en city_lights.gd.

const VIEW_PAD_X := 96.0
const VIEW_PAD_Y := 40.0

var _emitters: Array[CPUParticles2D] = []
var _emitting := false


func _ready() -> void:
	_emitters.append(_make_dust())
	_emitters.append(_make_scraps())
	_try_start()


func _process(_delta: float) -> void:
	if _emitting:
		_follow_camera()
	else:
		_try_start()


func _make_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.texture = _speck_texture()
	dust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dust.z_index = 2
	dust.local_coords = false
	dust.emitting = false
	dust.amount = 28
	dust.lifetime = 7.0
	dust.preprocess = 2.0
	dust.explosiveness = 0.0
	dust.randomness = 0.7
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.direction = Vector2(1.0, 0.12)
	dust.spread = 22.0
	dust.gravity = Vector2(4.0, 2.0)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 18.0
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.1
	dust.color = Color(0.86, 0.78, 0.62, 0.28)
	add_child(dust)
	return dust


func _make_scraps() -> CPUParticles2D:
	var scraps := CPUParticles2D.new()
	scraps.texture = _scrap_texture()
	scraps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scraps.z_index = 2
	scraps.local_coords = false
	scraps.emitting = false
	scraps.amount = 14
	scraps.lifetime = 5.5
	scraps.preprocess = 2.0
	scraps.explosiveness = 0.0
	scraps.randomness = 0.45
	scraps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	scraps.direction = Vector2(1.0, 0.18)
	scraps.spread = 10.0
	scraps.gravity = Vector2(6.0, 8.0)
	scraps.initial_velocity_min = 28.0
	scraps.initial_velocity_max = 56.0
	scraps.angular_velocity_min = -70.0
	scraps.angular_velocity_max = 70.0
	scraps.scale_amount_min = 1.0
	scraps.scale_amount_max = 1.6
	scraps.color = Color.WHITE
	scraps.color_initial_ramp = _scrap_ramp()
	add_child(scraps)
	return scraps


func _try_start() -> void:
	if not _follow_camera():
		return
	for emitter in _emitters:
		emitter.emitting = true
	_emitting = true


func _follow_camera() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var half := _view_half(cam)
	var origin := to_local(cam.get_screen_center_position()) + Vector2(-VIEW_PAD_X, 0.0)
	var extents := half + Vector2(VIEW_PAD_X, VIEW_PAD_Y)
	for emitter in _emitters:
		emitter.position = origin
		emitter.emission_rect_extents = extents
	return true


func _view_half(cam: Camera2D) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var zoom := cam.zoom
	return Vector2(
		view.x * 0.5 / maxf(zoom.x, 0.001),
		view.y * 0.5 / maxf(zoom.y, 0.001)
	)


func _speck_texture() -> Texture2D:
	var size := 6
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


func _scrap_texture() -> Texture2D:
	var img := Image.create(6, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _scrap_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.95, 0.90, 0.74, 0.9),
		Color(0.58, 0.66, 0.78, 0.8),
	])
	return ramp
