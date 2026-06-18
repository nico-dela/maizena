extends Control

const MAIN_SCENE := "res://scenes/main_scene.tscn"
const MIN_DISPLAY_SEC := 1.4

const TIPS: Array[String] = [
	"Explorá el archipiélago a tu ritmo.",
	"Algunos personajes solo aparecen a ciertas horas.",
	"La música cambia sola. Dejala sonar.",
	"En web, la primera carga puede tardar un poco más.",
]

@onready var margin: MarginContainer = $Margin
@onready var main_vbox: VBoxContainer = $Margin/VBox
@onready var content: VBoxContainer = $Margin/VBox/MainBlock/Content
@onready var progress_bar: ProgressBar = $Margin/VBox/MainBlock/Content/ProgressRow/ProgressBar
@onready var status_label: Label = $Margin/VBox/MainBlock/Content/ProgressRow/StatusLabel
@onready var tip_label: Label = $Margin/VBox/MainBlock/Content/TipLabel
@onready var title_label: Label = $Margin/VBox/MainBlock/Content/Title
@onready var location_label: Label = $Margin/VBox/LocationLabel
@onready var copyright_label: Label = $Margin/VBox/CopyrightLabel
@onready var logo_aspect: AspectRatioContainer = $Margin/VBox/MainBlock/Content/LogoWrap/LogoAspect
@onready var logo: TextureRect = $Margin/VBox/MainBlock/Content/LogoWrap/LogoAspect/Logo

var _started_at := 0.0
var _loaded_scene: PackedScene = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at = _now_sec()
	tip_label.text = TIPS[randi() % TIPS.size()]
	ViewportLayout.refresh()
	_apply_responsive_layout()
	ViewportLayout.layout_changed.connect(_apply_responsive_layout)

	var err := ResourceLoader.load_threaded_request(MAIN_SCENE)
	if err != OK:
		push_error("LoadingScreen: no se pudo iniciar la carga (%s)" % err)
		get_tree().change_scene_to_file(MAIN_SCENE)


func _process(_delta: float) -> void:
	var progress_array: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress_array)
	var load_ratio := float(progress_array[0]) if progress_array.size() > 0 else 0.0

	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			push_error("LoadingScreen: carga fallida de %s" % MAIN_SCENE)
			set_process(false)
			get_tree().change_scene_to_file(MAIN_SCENE)
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			load_ratio = 1.0
			if _loaded_scene == null:
				_loaded_scene = ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene

	var elapsed := _now_sec() - _started_at
	var time_ratio := clampf(elapsed / MIN_DISPLAY_SEC, 0.0, 1.0)
	var visual_ratio := load_ratio
	if _loaded_scene != null:
		visual_ratio = maxf(load_ratio, time_ratio)

	progress_bar.value = visual_ratio * 100.0
	status_label.text = "Cargando…" if visual_ratio < 1.0 else "Listo"

	if _loaded_scene != null and elapsed >= MIN_DISPLAY_SEC:
		set_process(false)
		get_tree().change_scene_to_packed(_loaded_scene)


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_node_ready():
		ViewportLayout.refresh()
		_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var layout_size: Vector2 = ViewportLayout.visible_layout_size()
	var portrait := ViewportLayout.is_portrait
	var ui_boost := ViewportLayout.effective_ui_scale()

	var content_w := minf((520.0 if portrait else 420.0) * ui_boost, layout_size.x * 0.94)
	content.custom_minimum_size.x = content_w

	var logo_ratio := 0.58 if portrait else 0.36
	var logo_max := 460.0 if portrait else 280.0
	var logo_min := 220.0 if portrait else 170.0
	var logo_side := clampf(layout_size.x * logo_ratio, logo_min, logo_max)
	logo_aspect.custom_minimum_size = Vector2(logo_side, logo_side)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	progress_bar.custom_minimum_size.y = maxi(16, int(round((22.0 if portrait else 18.0) * ui_boost)))
	main_vbox.add_theme_constant_override("separation", int(round((14.0 if portrait else 10.0) * ui_boost)))
	content.add_theme_constant_override("separation", int(round((24.0 if portrait else 18.0) * ui_boost)))

	var margin_base := 20.0 if portrait else 32.0
	var margin_scaled := int(round(margin_base * ui_boost))
	margin.add_theme_constant_override("margin_left", margin_scaled)
	margin.add_theme_constant_override("margin_right", margin_scaled)
	margin.add_theme_constant_override("margin_top", int(round((28.0 if portrait else 40.0) * ui_boost)))
	margin.add_theme_constant_override("margin_bottom", int(round((20.0 if portrait else 28.0) * ui_boost)))

	title_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(40 if portrait else 34))
	status_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(20 if portrait else 16))
	tip_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(18 if portrait else 14))
	location_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16 if portrait else 14))
	copyright_label.add_theme_font_size_override("font_size", ViewportLayout.scaled_font(16 if portrait else 14))
