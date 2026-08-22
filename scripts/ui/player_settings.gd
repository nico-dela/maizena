extends RefCounted

const SAVE_PATH := "user://player_settings.json"
const DEFAULT_VOLUME_PERCENT := 90
const DEFAULT_PLAY_IN_BACKGROUND := false
const DEFAULT_MASTER_MUTED := false
const DEFAULT_JOYSTICK_SCALE := 1.0

const VOLUME_MIN_DB := -40.0
const VOLUME_MAX_DB := 0.0
const JOYSTICK_SCALE_MIN := 0.75
const JOYSTICK_SCALE_MAX := 1.5


static func default_volume_db() -> float:
	return lerpf(VOLUME_MIN_DB, VOLUME_MAX_DB, float(DEFAULT_VOLUME_PERCENT) / 100.0)


static func load_all() -> Dictionary:
	var data := {
		"play_in_background": DEFAULT_PLAY_IN_BACKGROUND,
		"master_muted": DEFAULT_MASTER_MUTED,
		"master_volume_db": default_volume_db(),
		"joystick_scale": DEFAULT_JOYSTICK_SCALE,
	}
	if not FileAccess.file_exists(SAVE_PATH):
		return data

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return data

	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return data

	_migrate_legacy_keys(parsed, data)

	if parsed.has("play_in_background"):
		data["play_in_background"] = bool(parsed["play_in_background"])
	if parsed.has("master_muted"):
		data["master_muted"] = bool(parsed["master_muted"])
	if parsed.has("master_volume_db"):
		data["master_volume_db"] = clampf(
			float(parsed["master_volume_db"]),
			VOLUME_MIN_DB,
			VOLUME_MAX_DB
		)
	if parsed.has("joystick_scale"):
		data["joystick_scale"] = clampf(
			float(parsed["joystick_scale"]),
			JOYSTICK_SCALE_MIN,
			JOYSTICK_SCALE_MAX
		)
	return data


static func _migrate_legacy_keys(parsed: Dictionary, data: Dictionary) -> void:
	if not parsed.has("music_enabled"):
		return
	if parsed.has("play_in_background") or parsed.has("master_muted"):
		return
	data["master_muted"] = not bool(parsed["music_enabled"])


static func save_partial(patch: Dictionary) -> void:
	var data := load_all()
	for key in patch:
		data[key] = patch[key]

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return

	f.store_string(
		JSON.stringify({
			"play_in_background": bool(data.get("play_in_background", DEFAULT_PLAY_IN_BACKGROUND)),
			"master_muted": bool(data.get("master_muted", DEFAULT_MASTER_MUTED)),
			"master_volume_db": float(data.get("master_volume_db", default_volume_db())),
			"joystick_scale": clampf(
				float(data.get("joystick_scale", DEFAULT_JOYSTICK_SCALE)),
				JOYSTICK_SCALE_MIN,
				JOYSTICK_SCALE_MAX
			),
		})
	)
