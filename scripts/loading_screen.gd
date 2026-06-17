extends Control

const MAIN_SCENE := "res://scenes/main_scene.tscn"
const MIN_DISPLAY_SEC := 1.4

const TIPS: Array[String] = [
	"Explorá el archipiélago a tu ritmo.",
	"Algunos personajes solo aparecen a ciertas horas.",
	"La música cambia sola. Dejala sonar.",
	"En web, la primera carga puede tardar un poco más.",
]

@onready var progress_bar: ProgressBar = $Margin/VBox/MainBlock/Content/ProgressRow/ProgressBar
@onready var status_label: Label = $Margin/VBox/MainBlock/Content/ProgressRow/StatusLabel
@onready var tip_label: Label = $Margin/VBox/MainBlock/Content/TipLabel
@onready var logo_aspect: AspectRatioContainer = $Margin/VBox/MainBlock/Content/LogoWrap/LogoAspect
@onready var logo: TextureRect = $Margin/VBox/MainBlock/Content/LogoWrap/LogoAspect/Logo

var _started_at := 0.0
var _loaded_scene: PackedScene = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at = _now_sec()
	tip_label.text = TIPS[randi() % TIPS.size()]
	_fit_logo_size()

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


func _fit_logo_size() -> void:
	var viewport_width := get_viewport_rect().size.x
	var logo_side := clampf(viewport_width * 0.34, 180.0, 260.0)
	logo_aspect.custom_minimum_size = Vector2(logo_side, logo_side)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_node_ready():
		_fit_logo_size()
