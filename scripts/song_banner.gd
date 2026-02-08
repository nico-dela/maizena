extends Control

@export var show_time := 3.0
@export var slide_distance := 40.0
@export var title_color := Color.RED  # Puedes cambiarlo desde Inspector

@onready var label: RichTextLabel = $PanelContainer/RichTextLabel

var _tween: Tween

func _ready():
	# Configuración inicial del RichTextLabel
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	
	visible = false
	await get_tree().process_frame

	var music_manager = get_tree().get_first_node_in_group("music_manager")
	assert(music_manager != null, "No se encontró MusicManager en grupo 'music_manager'")

	music_manager.song_changed.connect(show_song)

func show_song(title: String):
	# Usar BBCode con color personalizado
	label.text = "Estas escuchando: [color=#F23049]" + title + "[/color]"
	
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

# Función opcional para cambiar color dinámicamente
func set_title_color(color: Color):
	title_color = color
