extends Control

const PlayerSettingsRes := preload("res://scripts/ui/player_settings.gd")
const VolumeIcons := preload("res://scripts/ui/volume_icons.gd")
const SCREEN_MARGIN := 14.0

@onready var _btn: Button = $Button

var _icon_on: ImageTexture
var _icon_muted: ImageTexture


func _ready() -> void:
	add_to_group("sound_toggle")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_on = VolumeIcons.speaker_on()
	_icon_muted = VolumeIcons.speaker_muted()
	_btn.pressed.connect(_on_pressed)
	_btn.text = ""
	_btn.expand_icon = true
	_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn.focus_mode = Control.FOCUS_NONE
	ViewportLayout.layout_changed.connect(_apply_layout)
	_apply_layout()
	_update_label()


func _apply_layout() -> void:
	ViewportLayout.refresh()
	var s := ViewportLayout.effective_ui_scale()
	var layout := ViewportLayout.visible_layout_size()
	var margin_right := ViewportLayout.screen_margin_right(SCREEN_MARGIN)
	var margin_bottom := ViewportLayout.screen_margin_bottom(SCREEN_MARGIN)
	var btn_size := clampf(44.0 * s, 36.0, 56.0)
	_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = -margin_right
	offset_bottom = -margin_bottom
	offset_left = -margin_right - btn_size
	offset_top = -margin_bottom - btn_size

	var settings := get_tree().get_first_node_in_group("settings_menu")
	if settings != null and settings.has_node("Button"):
		var settings_btn: Control = settings.get_node("Button")
		var settings_rect := settings_btn.get_global_rect()
		var self_rect := Rect2(
			layout.x - margin_right - btn_size,
			layout.y - margin_bottom - btn_size,
			btn_size,
			btn_size
		)
		if self_rect.intersects(settings_rect):
			offset_top -= settings_rect.size.y + 8.0 * s
			offset_bottom -= settings_rect.size.y + 8.0 * s


func _on_pressed() -> void:
	var settings := PlayerSettingsRes.load_all()
	var muted := not bool(settings.get("master_muted", false))
	PlayerSettingsRes.save_partial({"master_muted": muted})
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, muted)
	if not muted:
		var music := get_tree().get_first_node_in_group("music_manager")
		if music != null and music.has_method("unlock_and_play"):
			music.unlock_and_play()
	_update_label()
	var settings_menu := get_tree().get_first_node_in_group("settings_menu")
	if settings_menu != null and settings_menu.has_method("refresh_mute_from_settings"):
		settings_menu.refresh_mute_from_settings()


func _update_label() -> void:
	var muted := bool(PlayerSettingsRes.load_all().get("master_muted", false))
	_btn.text = ""
	_btn.icon = _icon_muted if muted else _icon_on
