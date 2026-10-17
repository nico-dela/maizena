extends Node2D

## Faroles cálidos para que la noche no aplaste la ciudad.

const LAMP_POSITIONS: Array[Vector2] = [
	Vector2(224, 488),
	Vector2(268, 545),
	Vector2(392, 552),
	Vector2(496, 300),
	Vector2(614, 500),
	Vector2(868, 543),
	Vector2(248, 784),
	Vector2(416, 792),
	Vector2(1150, 580),
]

## Índices fijos: siempre los mismos faroles fallan.
const FLICKER_INDICES: Array[int] = [2, 7]

const ORB_POSITION := Vector2(633, 656)
const ORB_COLOR := Color(0.48, 0.7, 1.0)
const ORB_ENERGY := 0.7

const LAMP_ENERGY := 0.55
const BULB_COLOR := Color(1.0, 0.86, 0.45)

var _flickers: Array[FlickerLamp] = []


func _ready() -> void:
	var glow := _falloff_texture(48, 3.4)
	var bulb := _falloff_texture(8, 1.2)
	for i in LAMP_POSITIONS.size():
		var pos := LAMP_POSITIONS[i]
		var lamp := PointLight2D.new()
		lamp.position = pos
		lamp.texture = glow
		lamp.texture_scale = 1.35
		lamp.color = Color(1.0, 0.72, 0.38)
		lamp.energy = LAMP_ENERGY
		lamp.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(lamp)

		var glass := Sprite2D.new()
		glass.position = pos + Vector2(0, -6)
		glass.texture = bulb
		glass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glass.modulate = BULB_COLOR
		glass.z_index = 2
		add_child(glass)

		if i in FLICKER_INDICES:
			_track_flicker(lamp, glass)
	_add_orb(glow)


func _add_orb(glow: Texture2D) -> void:
	var lamp := PointLight2D.new()
	lamp.position = ORB_POSITION
	lamp.texture = glow
	lamp.texture_scale = 1.5
	lamp.color = ORB_COLOR
	lamp.energy = ORB_ENERGY
	lamp.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(lamp)


func _process(delta: float) -> void:
	for lamp in _flickers:
		lamp.rest -= delta
		if lamp.rest > 0.0:
			continue
		_step_flicker(lamp)


func _track_flicker(light: PointLight2D, glass: Sprite2D) -> void:
	var lamp := FlickerLamp.new()
	lamp.light = light
	lamp.glass = glass
	lamp.rest = randf_range(0.2, 1.6)
	_flickers.append(lamp)


func _step_flicker(lamp: FlickerLamp) -> void:
	if lamp.dim:
		_set_brightness(lamp, 1.0)
		lamp.dim = false
		lamp.rest = randf_range(0.25, 1.6)
		return
	var stutter := randf() < 0.4
	_set_brightness(lamp, 0.15 if stutter else 0.0)
	lamp.dim = true
	lamp.rest = randf_range(0.04, 0.12) if stutter else randf_range(0.06, 0.22)


func _set_brightness(lamp: FlickerLamp, amount: float) -> void:
	lamp.light.energy = LAMP_ENERGY * amount
	lamp.glass.modulate = BULB_COLOR
	lamp.glass.modulate.a = amount


func _falloff_texture(size: int, power: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for x in size:
		for y in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, power)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


class FlickerLamp:
	var light: PointLight2D
	var glass: Sprite2D
	var rest: float
	var dim: bool = false
