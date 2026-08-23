extends Control

@export var show_time := 3.0
@export var slide_distance := 40.0

const BASE_FONT_SIZE := 38
const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

@onready var label: RichTextLabel = $PanelContainer/RichTextLabel

var _tween: Tween
var _pending_title := ""
var _watching_onboarding := false


func _ready() -> void:
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false

	visible = false

	var music_manager = get_tree().get_first_node_in_group("music_manager")
	if music_manager == null:
		await get_tree().process_frame
		music_manager = get_tree().get_first_node_in_group("music_manager")
	if music_manager == null:
		push_error("No se encontró MusicManager en grupo 'music_manager'")
		return

	music_manager.song_changed.connect(show_song)
	_apply_viewport_layout()
	ViewportLayout.layout_changed.connect(_apply_viewport_layout)


func _process(_delta: float) -> void:
	if not _watching_onboarding or _pending_title.is_empty():
		return
	if _onboarding_blocks_banner():
		return
	var title := _pending_title
	_pending_title = ""
	_watching_onboarding = false
	_play_banner(title)


func _apply_viewport_layout() -> void:
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_size_override("normal_font_size", ViewportLayout.scaled_font(BASE_FONT_SIZE))
	slide_distance = 40.0 * ViewportLayout.effective_ui_scale()


func show_song(title: String) -> void:
	if _onboarding_blocks_banner():
		_pending_title = title
		_watching_onboarding = true
		return
	_play_banner(title)


func _onboarding_blocks_banner() -> bool:
	var tutorial := get_tree().get_first_node_in_group("movement_tutorial")
	if tutorial != null and tutorial.has_method("is_blocking") and tutorial.call("is_blocking"):
		return true
	var welcome := get_tree().get_first_node_in_group("welcome_popup")
	if welcome != null and welcome.has_method("is_blocking") and welcome.call("is_blocking"):
		return true
	return false


func _play_banner(title: String) -> void:
	label.text = "Reproduciendo: [color=#F23049]" + title.to_upper() + "[/color]"

	position.y -= slide_distance
	modulate.a = 0.0
	visible = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(self, "position:y", position.y + slide_distance, 0.3)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

	_tween.tween_interval(show_time)

	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)

	_tween.finished.connect(func() -> void:
		visible = false
	)
