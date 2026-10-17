extends RefCounted

## Banghó CRT laptop (export feature "crt"). Web and desktop defaults stay 1216×1024.
##
## VGA converters accept 640×480. Stretch stays canvas_items with aspect keep.
## Integer scale is intentionally off: 1216×1024 does not divide 640×480 (~1.9),
## so an integer scale would letterbox a smaller buffer and blur the HUD.
## The scan-readable piece is the QR card, not a global nearest scale of the UI.
##
## On that machine: Windows display scaling 100%, browser fullscreen at 640×480
## or 800×600. Export with the "Web CRT" preset (build/crt_web), not the Netlify one.

const WINDOW_SIZE := Vector2i(640, 480)


static func active() -> bool:
	return OS.has_feature("crt")


static func apply_display() -> void:
	if not active():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		tree.root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	DisplayServer.window_set_size(WINDOW_SIZE)
	var screen := DisplayServer.screen_get_size()
	if screen.x >= WINDOW_SIZE.x and screen.y >= WINDOW_SIZE.y:
		@warning_ignore("integer_division")
		DisplayServer.window_set_position((screen - WINDOW_SIZE) / 2)
