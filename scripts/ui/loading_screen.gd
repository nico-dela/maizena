extends Control

const MAIN_SCENE := "res://scenes/boot/main_scene.tscn"
const MIN_DISPLAY_SEC := 1.4

const PHRASES: Array[String] = [
	"Es que nadie me enseño a vivir",
	"Todo lo que necesito es pequeño",
	"El viento sobre mi cara, mientras voy para mi casa",
	"Toda la gente se quiere ir a dormir",
	"Podemos hacer sapitos por ahi",
]

const PORTRAIT_LOADING_FONT_MUL := 1.22

const FONT_TITLE := 34
const FONT_BODY := 16
const FONT_SMALL := 14
const ORIENTATION_HINT := "Girá la pantalla en horizontal para una mejor experiencia de juego."

@onready var margin: MarginContainer = $Margin
@onready var main_vbox: VBoxContainer = $Margin/VBox
@onready var main_block: VBoxContainer = $Margin/VBox/MainBlock
@onready var top_spacer: Control = $Margin/VBox/MainBlock/TopSpacer
@onready var bottom_spacer: Control = $Margin/VBox/MainBlock/BottomSpacer
@onready var content: VBoxContainer = $Margin/VBox/MainBlock/Content
@onready var progress_row: VBoxContainer = $Margin/VBox/MainBlock/Content/ProgressRow
@onready var progress_bar: ProgressBar = $Margin/VBox/MainBlock/Content/ProgressRow/ProgressBar
@onready var status_label: Label = $Margin/VBox/MainBlock/Content/ProgressRow/StatusLabel
@onready var orientation_hint_label: Label = $Margin/VBox/MainBlock/Content/ProgressRow/OrientationHint
@onready var tip_label: Label = $Margin/VBox/MainBlock/Content/TipLabel
@onready var title_label: Label = $Margin/VBox/MainBlock/Content/Title
@onready var location_label: Label = $Margin/VBox/LocationLabel
@onready var copyright_label: Label = $Margin/VBox/CopyrightLabel
@onready var map_preview_frame: PanelContainer = $Margin/VBox/MainBlock/Content/MapPreviewWrap/MapPreviewFrame
@onready var map_preview_aspect: AspectRatioContainer = $Margin/VBox/MainBlock/Content/MapPreviewWrap/MapPreviewFrame/MapPreviewAspect
@onready var map_preview: TextureRect = $Margin/VBox/MainBlock/Content/MapPreviewWrap/MapPreviewFrame/MapPreviewAspect/MapPreview

var _started_at := 0.0
var _loaded_scene: PackedScene = null
var _map_frame_style: StyleBoxFlat
var _is_web := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_at = _now_sec()
	_is_web = OS.has_feature("web")
	tip_label.text = PHRASES[randi() % PHRASES.size()]
	ViewportLayout.refresh()
	_apply_responsive_layout()
	ViewportLayout.layout_changed.connect(_apply_responsive_layout)
	set_process(true)

	if _is_web:
		call_deferred("_begin_web_loading")
		return

	var err := ResourceLoader.load_threaded_request(MAIN_SCENE)
	if err != OK:
		push_error("LoadingScreen: no se pudo iniciar la carga (%s)" % err)
		_loaded_scene = ResourceLoader.load(MAIN_SCENE) as PackedScene


func _begin_web_loading() -> void:
	_hide_html_loader()
	_apply_responsive_layout()
	await get_tree().process_frame
	_started_at = _now_sec()
	_load_main_on_web()


func _load_main_on_web() -> void:
	# En Web, load_threaded_request puede quedar colgado en THREAD_LOAD_IN_PROGRESS.
	_loaded_scene = ResourceLoader.load(MAIN_SCENE) as PackedScene
	if _loaded_scene == null:
		push_error("LoadingScreen: falló la carga web de %s" % MAIN_SCENE)
		get_tree().change_scene_to_file(MAIN_SCENE)


func _hide_html_loader() -> void:
	if not _is_web:
		return
	JavaScriptBridge.eval(
		"if (typeof window.maizenaHideLoader === 'function') { window.maizenaHideLoader(); }"
	)


func _process(_delta: float) -> void:
	if _is_web:
		_process_web_display()
		return

	var load_ratio := 1.0 if _loaded_scene != null else 0.0
	if _loaded_scene == null:
		var progress_array: Array = []
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress_array)
		load_ratio = float(progress_array[0]) if progress_array.size() > 0 else 0.0
		match status:
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("LoadingScreen: carga fallida de %s (status %s)" % [MAIN_SCENE, status])
				_loaded_scene = ResourceLoader.load(MAIN_SCENE) as PackedScene
				load_ratio = 1.0 if _loaded_scene != null else 0.0
			ResourceLoader.THREAD_LOAD_LOADED:
				load_ratio = 1.0
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


func _process_web_display() -> void:
	if _loaded_scene == null:
		progress_bar.value = 5.0
		status_label.text = "Cargando…"
		return

	var elapsed := _now_sec() - _started_at
	var time_ratio := clampf(elapsed / MIN_DISPLAY_SEC, 0.0, 1.0)
	progress_bar.value = time_ratio * 100.0
	status_label.text = "Cargando…" if time_ratio < 1.0 else "Listo"

	if elapsed >= MIN_DISPLAY_SEC:
		set_process(false)
		call_deferred("_finish_loading")


func _finish_loading() -> void:
	if _loaded_scene == null:
		return
	get_tree().change_scene_to_packed(_loaded_scene)


func _now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_node_ready():
		ViewportLayout.refresh()
		_apply_responsive_layout()


func _canvas_stretch() -> float:
	var layout_size: Vector2 = ViewportLayout.visible_layout_size()
	var window := DisplayServer.window_get_size()
	if window.x < 1 or window.y < 1 or layout_size.x < 1.0 or layout_size.y < 1.0:
		return 1.0
	return maxf(minf(float(window.x) / layout_size.x, float(window.y) / layout_size.y), 0.001)


func _loading_size_boost() -> float:
	## Compensa stretch bajo (ventanas anchas/bajas con aspect expand).
	## No agranda tipografía en pantallas altas donde el stretch ya es ~1.
	var stretch := _canvas_stretch()
	return clampf(0.75 / stretch, 1.0, 2.1)


func _loading_font(base: int) -> int:
	var scaled := float(base) * ViewportLayout.effective_ui_scale() * _loading_size_boost()
	if ViewportLayout.is_portrait:
		scaled *= PORTRAIT_LOADING_FONT_MUL
	return maxi(1, int(round(scaled)))


func _apply_responsive_layout() -> void:
	var layout_size: Vector2 = ViewportLayout.visible_layout_size()
	var portrait := ViewportLayout.is_portrait
	var ui_boost := ViewportLayout.effective_ui_scale()
	var size_boost := _loading_size_boost()
	var stretch := _canvas_stretch()
	var window := DisplayServer.window_get_size()

	var content_w := minf(layout_size.x * (0.92 if portrait else 0.84), layout_size.x * 0.96)
	content.custom_minimum_size.x = content_w

	# Tamaño en pantalla (~42% alto landscape / ~38% portrait), convertido a unidades de canvas.
	var map_screen: float
	if portrait:
		map_screen = minf(float(window.x) * 0.72, float(window.y) * 0.38)
	else:
		map_screen = float(window.y) * 0.42
	var logo_side := clampf(map_screen / stretch, 220.0 if portrait else 240.0, 560.0 if portrait else 520.0)
	map_preview_aspect.custom_minimum_size = Vector2(logo_side, logo_side)
	map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if map_preview_frame != null:
		var frame_pad := int(round((12.0 if portrait else 8.0) * ui_boost * size_boost))
		if _map_frame_style == null:
			var base := map_preview_frame.get_theme_stylebox("panel") as StyleBoxFlat
			_map_frame_style = base.duplicate() as StyleBoxFlat if base else StyleBoxFlat.new()
		_map_frame_style.content_margin_left = frame_pad
		_map_frame_style.content_margin_top = frame_pad
		_map_frame_style.content_margin_right = frame_pad
		_map_frame_style.content_margin_bottom = frame_pad
		_map_frame_style.set_border_width_all(maxi(2, int(round(3.0 * ui_boost * size_boost))))
		_map_frame_style.set_corner_radius_all(maxi(6, int(round(8.0 * ui_boost * size_boost))))
		map_preview_frame.add_theme_stylebox_override("panel", _map_frame_style)

	progress_bar.custom_minimum_size.y = maxi(22, int(round((30.0 if portrait else 22.0) * ui_boost * size_boost)))
	progress_row.add_theme_constant_override("separation", int(round((14.0 if portrait else 8.0) * ui_boost * size_boost)))
	main_vbox.add_theme_constant_override("separation", int(round((12.0 if portrait else 10.0) * ui_boost * size_boost)))
	content.add_theme_constant_override("separation", int(round((22.0 if portrait else 18.0) * ui_boost * size_boost)))

	if top_spacer != null:
		top_spacer.custom_minimum_size.y = 0.0
		top_spacer.size_flags_stretch_ratio = 1.0
	if bottom_spacer != null:
		bottom_spacer.custom_minimum_size.y = 0.0
		bottom_spacer.size_flags_stretch_ratio = 1.0 if portrait else 1.4

	var margin_base := 12.0 if portrait else 32.0
	var margin_scaled := int(round(margin_base * ui_boost))
	margin.add_theme_constant_override("margin_left", int(round(ViewportLayout.screen_margin_left(float(margin_scaled)))))
	margin.add_theme_constant_override("margin_right", int(round(ViewportLayout.screen_margin_right(float(margin_scaled)))))
	margin.add_theme_constant_override(
		"margin_top",
		int(round(ViewportLayout.screen_margin_top((14.0 if portrait else 28.0) * ui_boost)))
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		int(round(ViewportLayout.screen_margin_bottom((10.0 if portrait else 20.0) * ui_boost)))
	)

	title_label.add_theme_font_size_override("font_size", _loading_font(FONT_TITLE + (6 if portrait else 0)))
	status_label.add_theme_font_size_override("font_size", _loading_font(FONT_BODY + (2 if portrait else 0)))
	orientation_hint_label.text = ORIENTATION_HINT
	orientation_hint_label.visible = portrait
	orientation_hint_label.add_theme_font_size_override("font_size", _loading_font(FONT_SMALL))
	tip_label.add_theme_font_size_override("font_size", _loading_font(FONT_SMALL))
	location_label.add_theme_font_size_override("font_size", _loading_font(FONT_SMALL))
	copyright_label.add_theme_font_size_override("font_size", _loading_font(FONT_SMALL))
