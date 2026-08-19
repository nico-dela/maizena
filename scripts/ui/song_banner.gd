extends Control

@export var show_time := 3.0
@export var slide_distance := 40.0

const BASE_FONT_SIZE := 38
const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

@onready var label: RichTextLabel = $PanelContainer/RichTextLabel

var _tween: Tween

func _ready():
	# Configuración inicial del RichTextLabel
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


func _apply_viewport_layout() -> void:
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_size_override("normal_font_size", ViewportLayout.scaled_font(BASE_FONT_SIZE))
	slide_distance = 40.0 * ViewportLayout.effective_ui_scale()

func show_song(title: String):
	# Usar BBCode con color personalizado
	label.text = "Reproduciendo: [color=#F23049]" + title.to_upper() + "[/color]"
	
	# Resetear posición y opacidad antes de animar
	position.y -= slide_distance
	modulate.a = 0.0
	visible = true

	# Cancelar tween anterior si existe
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)

	# Animación de entrada
	_tween.tween_property(self, "position:y", position.y + slide_distance, 0.3)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

	# Mantener visible
	_tween.tween_interval(show_time)

	# Animación de salida
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)

	_tween.finished.connect(func():
		visible = false
	)
