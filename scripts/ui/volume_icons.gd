extends RefCounted
## Tiny nearest-neighbor speaker icons (PixelOperator has no emoji glyphs).


static func speaker_on() -> ImageTexture:
	return _build(false)


static func speaker_muted() -> ImageTexture:
	return _build(true)


static func _build(muted: bool) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.75, 0.92, 1.0, 1.0)
	# Speaker body (trapezoid-ish).
	_fill_rect(img, 2, 6, 4, 10, ink)
	_fill_rect(img, 5, 4, 8, 12, ink)
	if muted:
		# X over the cone.
		_put(img, 9, 5, ink)
		_put(img, 10, 6, ink)
		_put(img, 11, 7, ink)
		_put(img, 12, 8, ink)
		_put(img, 13, 9, ink)
		_put(img, 9, 9, ink)
		_put(img, 10, 8, ink)
		_put(img, 11, 7, ink)
		_put(img, 12, 6, ink)
		_put(img, 13, 5, ink)
	else:
		# Sound waves.
		_put(img, 10, 5, ink)
		_put(img, 10, 10, ink)
		_put(img, 11, 6, ink)
		_put(img, 11, 9, ink)
		_put(img, 12, 4, ink)
		_put(img, 12, 7, ink)
		_put(img, 12, 8, ink)
		_put(img, 12, 11, ink)
		_put(img, 13, 5, ink)
		_put(img, 13, 6, ink)
		_put(img, 13, 9, ink)
		_put(img, 13, 10, ink)
	var tex := ImageTexture.create_from_image(img)
	return tex


static func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			_put(img, x, y, c)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)
