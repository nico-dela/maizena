extends RefCounted

static var _web_touch_cached: int = -1


static func is_touch_primary() -> bool:
	if OS.has_feature("mobile"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		return _web_has_touch()
	return false


static func _web_has_touch() -> bool:
	if _web_touch_cached >= 0:
		return _web_touch_cached == 1
	var result: Variant = JavaScriptBridge.eval("'ontouchstart' in window")
	_web_touch_cached = 1 if bool(result) else 0
	return _web_touch_cached == 1
