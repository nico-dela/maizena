extends CanvasLayer

const FONT: FontFile = preload("res://assets/art/ui/PixelOperator8.ttf")

const BASE_CARD_MIN := Vector2(160, 168)
const PORTRAIT_FONT_MUL := 1.42
const PORTRAIT_CARD_MUL := 1.28
const REBUILD_SCALE_THRESHOLD := 0.18

const LINKTREE_URL := (
	"https://linktr.ee/Maizena.ar"
	+ "?utm_source=linktree_profile_share"
	+ "&ltsid=b3b06901-f163-41f8-8a51-02a7c653954e"
)

const COLOR_YELLOW := Color(0.95, 0.82, 0.28, 1.0)
const COLOR_ORANGE := Color(0.98, 0.58, 0.22, 1.0)
const COLOR_GREEN := Color(0.45, 0.9, 0.48, 1.0)
const COLOR_CORAL := Color(0.96, 0.45, 0.42, 1.0)
const COLOR_VALUE := Color(0.98, 0.98, 1.0, 1.0)

const BACKDROP_WAIT_MS := 2500

enum PopupView { NEWS, CREDITS, QR }

const QR_TEXTURE: Texture2D = preload("res://assets/art/ui/linktree_qr.png")
const UNKNOWN_SONG_ICON: Texture2D = preload("res://assets/art/ui/unknown_song.png")

const HEADER_NEWS := (
	"[center][color=#72cce8]Las noticias[/color] "
	+ "[color=#e85050]/[/color][color=#e8c840]/[/color][color=#5080e8]/[/color] "
	+ "[color=#f07828]Maizena.tv[/color][/center]"
)
const HEADER_CREDITS := (
	"[center][color=#72cce8]Créditos[/color] "
	+ "[color=#f07828]Maizena.tv[/color][/center]"
)
const HEADER_QR := (
	"[center][color=#72cce8]Seguinos[/color] "
	+ "[color=#f07828]Maizena.tv[/color][/center]"
)

const CREDIT_SONG_TITLES := [
	"Colores",
	"Resaka",
	"Todo lo que necesito",
	"Los amigos",
]

@onready var dim_overlay: ColorRect = $CenterRoot/Dim
@onready var header_label: RichTextLabel = $CenterRoot/Report/Margin/VBox/HeaderLabel
@onready var report_panel: PanelContainer = $CenterRoot/Report
@onready var report_margin: MarginContainer = $CenterRoot/Report/Margin
@onready var report_vbox: VBoxContainer = $CenterRoot/Report/Margin/VBox
@onready var infographic_root: VBoxContainer = $CenterRoot/Report/Margin/VBox/Scroll/InfographicRoot
@onready var scroll_container: ScrollContainer = $CenterRoot/Report/Margin/VBox/Scroll
@onready var close_btn: Button = $CenterRoot/Report/Margin/VBox/CloseButton

var _song_val: Label
var _radio_footer: Label
var _hallazgos_rows: VBoxContainer
var _hallazgos_footer: Label
var _era_val: Label
var _quest_val: Label
var _quest_footer: Label
var _field_bar: ProgressBar
var _field_note: Label
var _saturation_footer: Label

var _mark_seen_on_close := false
var _card_style: StyleBoxFlat
var _infographic_grid: GridContainer
var _footer_links_box: HBoxContainer
var _footer_link: LinkButton
var _footer_separator: Label
var _footer_spacer: Control
var _credits_root: VBoxContainer
var _qr_root: VBoxContainer
var _qr_image: TextureRect
var _credits_nav_btn: LinkButton
var _current_view := PopupView.NEWS
var _applied_layout_scale := 1.0
var _applied_portrait := false
var _session_auto_open_pending := true
var _news_scroll_hold := 0.0


func _ready() -> void:
	_promote_if_nested_under_canvas_layer()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	hide()
	_card_style = _make_card_stylebox()
	_setup_header()
	_style_close_button()
	_setup_footer_links()
	close_btn.pressed.connect(_on_close_pressed)
	_build_infographic_ui()
	_build_credits_ui()
	_build_qr_ui()
	_show_news_view()
	_applied_layout_scale = ViewportLayout.effective_ui_scale()
	_applied_portrait = ViewportLayout.is_portrait
	_apply_responsive_layout()
	ViewportLayout.layout_changed.connect(_on_viewport_layout_changed)
	call_deferred("_connect_song_changes")

	if OS.has_feature("booth"):
		_session_auto_open_pending = false
		return
	call_deferred("_auto_open_when_backdrop_ready")


func _connect_song_changes() -> void:
	var mm := get_tree().get_first_node_in_group("music_manager")
	if mm == null or not mm.has_signal("song_changed"):
		return
	if not mm.song_changed.is_connected(_on_radio_song_changed):
		mm.song_changed.connect(_on_radio_song_changed)


func _on_radio_song_changed(_title: String) -> void:
	if not visible:
		return
	_refresh_radio_card()


func _auto_open_when_backdrop_ready() -> void:
	await _wait_for_movement_tutorial()
	await _wait_for_stable_backdrop()
	open_welcome(false)


func _wait_for_movement_tutorial() -> void:
	while true:
		var tutorial := get_tree().get_first_node_in_group("movement_tutorial")
		if tutorial == null or not tutorial.has_method("is_blocking"):
			break
		if not tutorial.call("is_blocking"):
			break
		await get_tree().process_frame


func _wait_for_stable_backdrop() -> void:
	var weather := get_node_or_null("/root/CordobaWeather")
	var deadline := Time.get_ticks_msec() + BACKDROP_WAIT_MS
	while weather != null and not weather.is_available:
		if Time.get_ticks_msec() >= deadline:
			break
		await get_tree().process_frame

	var time_system := get_tree().get_first_node_in_group("time_system")
	if time_system != null and time_system.has_method("update_time_color"):
		time_system.update_time_color()

	await get_tree().process_frame
	await get_tree().process_frame


func _promote_if_nested_under_canvas_layer() -> void:
	var p := get_parent()
	if p is CanvasLayer:
		var host: Node = p.get_parent()
		if host != null:
			p.remove_child(self)
			host.add_child(self)
			host.move_child(self, -1)


func _make_card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.14, 0.98)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.82, 0.96, 0.82)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_top = 10
	sb.content_margin_right = 12
	sb.content_margin_bottom = 10
	return sb


func _font_boost() -> float:
	return ViewportLayout.effective_ui_scale()


func _layout_font_mul() -> float:
	return PORTRAIT_FONT_MUL


func _layout_card_mul() -> float:
	return PORTRAIT_CARD_MUL


func _scaled_news_font(base: int) -> int:
	var size := float(base) * _font_boost() * _layout_font_mul()
	return maxi(1, int(round(size)))


func _lbl(base_size: int, color: Color, outline := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", _scaled_news_font(base_size))
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
		l.add_theme_constant_override("outline_size", 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _setup_header() -> void:
	header_label.bbcode_enabled = true
	header_label.fit_content = true
	header_label.scroll_active = false
	header_label.add_theme_font_override("normal_font", FONT)
	header_label.add_theme_font_size_override("normal_font_size", _scaled_news_font(20))
	header_label.text = HEADER_NEWS


func _make_footer_link(text: String, callback: Callable) -> LinkButton:
	var link := LinkButton.new()
	link.text = text
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.add_theme_font_override("font", FONT)
	link.add_theme_font_size_override("font_size", _scaled_news_font(16))
	link.add_theme_color_override("font_color", Color(0.45, 0.80, 0.91, 1.0))
	link.add_theme_color_override("font_hover_color", Color(0.65, 0.92, 1.0, 1.0))
	link.focus_mode = Control.FOCUS_ALL
	link.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.16, 0.28, 0.4, 0.98)
	focus.border_color = Color(0.85, 0.98, 1.0, 1.0)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.content_margin_left = 8
	focus.content_margin_right = 8
	focus.content_margin_top = 4
	focus.content_margin_bottom = 4
	link.add_theme_stylebox_override("focus", focus)
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	link.pressed.connect(callback)
	return link


func _apply_footer_link_layout(link: LinkButton, _portrait: bool) -> void:
	if link == null:
		return
	link.add_theme_font_size_override("font_size", _scaled_news_font(18))
	link.custom_minimum_size.y = maxf(36.0, 28.0 * _font_boost())


func _make_footer_separator() -> Label:
	var sep := Label.new()
	sep.text = "·"
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.add_theme_font_override("font", FONT)
	sep.add_theme_color_override("font_color", Color(0.38, 0.58, 0.72, 0.85))
	return sep


func _apply_footer_separator_layout(sep: Label, _portrait: bool) -> void:
	if sep == null:
		return
	sep.add_theme_font_size_override("font_size", _scaled_news_font(20))
	sep.custom_minimum_size.x = maxf(12.0, 10.0 * _font_boost())


func _setup_footer_links() -> void:
	var links_box := HBoxContainer.new()
	links_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	links_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links_box.add_theme_constant_override("separation", int(round(10.0 * _font_boost())))
	_footer_links_box = links_box

	_footer_link = _make_footer_link("Seguinos en las redes", _on_linktree_pressed)
	_footer_separator = _make_footer_separator()
	_credits_nav_btn = _make_footer_link("Créditos", _on_credits_nav_pressed)
	links_box.add_child(_footer_link)
	links_box.add_child(_footer_separator)
	links_box.add_child(_credits_nav_btn)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_spacer = spacer

	var vbox := close_btn.get_parent()
	vbox.add_child(links_box)
	vbox.add_child(spacer)
	vbox.move_child(links_box, close_btn.get_index())
	vbox.move_child(spacer, close_btn.get_index())
	_wire_news_focus()


func _on_linktree_pressed() -> void:
	if OS.has_feature("web"):
		OS.shell_open(LINKTREE_URL)
		return
	if _current_view == PopupView.QR:
		_show_news_view()
	else:
		_show_qr_view()


func _build_qr_ui() -> void:
	var root := VBoxContainer.new()
	root.visible = false
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", int(round(14.0 * _font_boost())))
	scroll_container.add_child(root)
	_qr_root = root

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.WHITE
	frame_style.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", frame_style)
	root.add_child(frame)

	var image := TextureRect.new()
	image.texture = QR_TEXTURE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(image)
	_qr_image = image

	var caption := _lbl(16, COLOR_VALUE)
	caption.text = "Escaneá con el celular para entrar a las redes."
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(caption)
	_apply_qr_size()


func _apply_qr_size() -> void:
	if _qr_image == null:
		return
	var layout := ViewportLayout.visible_layout_size()
	var side := clampf(minf(layout.x, layout.y) * 0.46, 180.0, 420.0)
	_qr_image.custom_minimum_size = Vector2(side, side)


func _show_qr_view() -> void:
	_current_view = PopupView.QR
	header_label.text = HEADER_QR
	infographic_root.visible = false
	if _credits_root != null:
		_credits_root.visible = false
	if _qr_root != null:
		_qr_root.visible = true
	if _footer_link != null:
		_footer_link.text = "Volver a las noticias"
	if scroll_container != null:
		scroll_container.scroll_vertical = 0
	_apply_qr_size()


func _open_qr() -> void:
	open_welcome(false)
	_show_qr_view()


func _build_credits_ui() -> void:
	var root := VBoxContainer.new()
	root.visible = false
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", int(round(14.0 * _font_boost())))
	scroll_container.add_child(root)
	_credits_root = root

	_add_credits_block(
		root,
		COLOR_ORANGE,
		"Proyecto",
		"Archipiélago Maizena. Las cosas · La Casa Mutante."
	)
	_add_credits_block(
		root,
		COLOR_YELLOW,
		"Desarrollo digital",
		"Una obra digital desarrollada por Kumo Estudio."
	)
	_add_credits_block(
		root,
		COLOR_GREEN,
		"Equipo",
		"Tobias Gencarelli, Candela Gencarelli, Nicolas de la Cruz."
	)
	_add_credits_block(
		root,
		COLOR_CORAL,
		"Música",
		" · ".join(CREDIT_SONG_TITLES)
	)
	_add_credits_block(
		root,
		COLOR_ORANGE,
		"Comunidad",
		(
			"MAIZENA es un proyecto de La Casa Mutante, financiado por nosotres mismos, "
			+ "confiando en la comunidad."
		)
	)

	var footer := _lbl(14, COLOR_VALUE)
	footer.text = "Córdoba, Argentina · © 2026 Kumo Estudio"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(footer)


func _add_credits_block(
	parent: VBoxContainer,
	accent: Color,
	title: String,
	body: String
) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style_for_layout())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(8.0 * _font_boost())))
	panel.add_child(v)

	var header := _lbl(16, accent)
	header.text = title
	v.add_child(header)

	var body_lbl := _lbl(14, COLOR_VALUE)
	body_lbl.text = body
	v.add_child(body_lbl)

	parent.add_child(panel)


func _show_news_view() -> void:
	_current_view = PopupView.NEWS
	header_label.text = HEADER_NEWS
	infographic_root.visible = true
	if _credits_root != null:
		_credits_root.visible = false
	if _qr_root != null:
		_qr_root.visible = false
	if _footer_link != null:
		_footer_link.text = "Seguinos en las redes"
	if _credits_nav_btn != null:
		_credits_nav_btn.text = "Créditos"
	if scroll_container != null:
		scroll_container.scroll_vertical = 0


func _show_credits_view() -> void:
	_current_view = PopupView.CREDITS
	header_label.text = HEADER_CREDITS
	infographic_root.visible = false
	if _qr_root != null:
		_qr_root.visible = false
	if _credits_root != null:
		_credits_root.visible = true
	if _footer_link != null:
		_footer_link.text = "Seguinos en las redes"
	if _credits_nav_btn != null:
		_credits_nav_btn.text = "Volver a las noticias"
	if scroll_container != null:
		scroll_container.scroll_vertical = 0


func _on_credits_nav_pressed() -> void:
	if _current_view == PopupView.CREDITS:
		_show_news_view()
	else:
		_show_credits_view()


func _build_infographic_ui() -> void:
	var grid := GridContainer.new()
	var portrait := ViewportLayout.is_portrait
	grid.columns = 1 if portrait else 2
	var grid_sep := int(round(18.0 * _font_boost()))
	grid.add_theme_constant_override("h_separation", grid_sep)
	grid.add_theme_constant_override("v_separation", grid_sep)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infographic_root.add_child(grid)
	_infographic_grid = grid

	var radio := _add_news_card(
		grid,
		COLOR_YELLOW,
		"En la radio ahora está sonando:",
		"Esta canción ya sonó en el archipiélago 0 veces"
	)
	_song_val = radio["value"]
	_radio_footer = radio["footer"]

	var quest := _add_news_card(
		grid,
		COLOR_GREEN,
		"Misión secundaria",
		"Cuando alguien te pida ayuda, va a aparecer acá.",
		22
	)
	_quest_val = quest["value"]
	_quest_footer = quest["footer"]

	var hallazgos := _add_hallazgos_card(grid)
	_hallazgos_rows = hallazgos["rows"]
	_hallazgos_footer = hallazgos["footer"]

	var era := _add_news_card(
		grid,
		COLOR_ORANGE,
		"En esta isla el tiempo pasa en Eras",
		"semanas desde que el archipiélago empezó a contar Eras, mientras Maizena arma Las cosas"
	)
	_era_val = era["value"]
	_add_saturation_card(grid)


func _card_style_for_layout() -> StyleBoxFlat:
	var sb := _make_card_stylebox()
	var boost := _font_boost()
	var margin := int(round(18.0 * boost))
	sb.content_margin_left = margin
	sb.content_margin_top = int(round(14.0 * boost))
	sb.content_margin_right = margin
	sb.content_margin_bottom = int(round(14.0 * boost))
	sb.set_border_width_all(maxi(2, int(round(2.0 * boost))))
	sb.set_corner_radius_all(maxi(6, int(round(8.0 * boost))))
	return sb


func _add_news_card(
	grid: GridContainer,
	accent: Color,
	header_text: String,
	footer_text: String,
	value_font_size: int = -1
) -> Dictionary:
	if value_font_size < 0:
		value_font_size = 30
	var header_size := 16
	var footer_size := 14

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style_for_layout())
	var card_scale := _font_boost() * _layout_card_mul()
	panel.custom_minimum_size = BASE_CARD_MIN * card_scale
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(10.0 * _font_boost())))
	panel.add_child(v)

	var header := _lbl(header_size, accent)
	header.text = header_text
	v.add_child(header)

	var val := _lbl(value_font_size, COLOR_VALUE, true)
	val.text = "—"
	val.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(val)

	var footer := _lbl(footer_size, accent)
	footer.text = footer_text
	v.add_child(footer)

	grid.add_child(panel)
	return {"value": val, "footer": footer}


func _add_saturation_card(grid: GridContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style_for_layout())
	var card_scale := _font_boost() * _layout_card_mul()
	panel.custom_minimum_size = BASE_CARD_MIN * card_scale
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(8.0 * _font_boost())))
	panel.add_child(v)

	var header := _lbl(16, COLOR_GREEN)
	header.text = "El indice de saturación de cosas en este momento es:"
	v.add_child(header)

	var hint := _lbl(14, Color(0.72, 0.78, 0.86, 1.0))
	hint.text = "Cosas / tope"
	v.add_child(hint)

	var cap := int(WorldState.RESIDUE_CAP)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, maxi(18, _scaled_news_font(18)))
	bar.max_value = float(cap)
	bar.value = 0.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.28, 0.78, 0.98, 0.95)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.07, 0.1, 0.95)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)
	_field_bar = bar

	var note := _lbl(28, COLOR_VALUE, true)
	note.text = "0 / %d" % cap
	v.add_child(note)
	_field_note = note

	var footer := _lbl(14, COLOR_GREEN)
	footer.text = _saturation_message(0)
	v.add_child(footer)
	_saturation_footer = footer
	grid.add_child(panel)


func _saturation_message(things: int) -> String:
	var cap := int(WorldState.RESIDUE_CAP)
	if things >= cap:
		return "El archipiélago no da más. Hay que empezar de cero."
	var ratio := float(things) / float(cap)
	if ratio >= 0.66:
		return "Saturación alta: cada rincón tiene algo tirado."
	if ratio >= 0.33:
		return "Saturación media: el paisaje se va llenando."
	return "Saturación baja: todavía hay aire entre las cosas."


func _add_hallazgos_card(grid: GridContainer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style_for_layout())
	var card_scale := _font_boost() * _layout_card_mul()
	panel.custom_minimum_size = BASE_CARD_MIN * card_scale
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(8.0 * _font_boost())))
	panel.add_child(v)

	var header := _lbl(16, COLOR_YELLOW)
	header.text = "Hallazgos"
	v.add_child(header)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(round(6.0 * _font_boost())))
	v.add_child(rows)

	var footer := _lbl(14, COLOR_YELLOW)
	footer.text = "Te faltan 0 objetos que guardan una canción."
	v.add_child(footer)

	grid.add_child(panel)
	return {"rows": rows, "footer": footer}


func _fill_hallazgos() -> void:
	if _hallazgos_rows == null:
		return
	for child in _hallazgos_rows.get_children():
		_hallazgos_rows.remove_child(child)
		child.free()

	var mm := get_tree().get_first_node_in_group("music_manager")
	var icon_size := maxi(16, _scaled_news_font(16))
	for relic in SongRelics.RELICS:
		var song_id := int(relic.get("song_id", -1))
		var found := MaizenaMeta.has_collected_song(song_id)
		if found:
			var title := ""
			if mm != null and mm.has_method("get_song_title"):
				title = str(mm.call("get_song_title", song_id))
			var line := _lbl(14, COLOR_VALUE)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			line.text = title
			_hallazgos_rows.add_child(line)
		else:
			var icon := TextureRect.new()
			icon.texture = UNKNOWN_SONG_ICON
			icon.custom_minimum_size = Vector2(icon_size, icon_size)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_hallazgos_rows.add_child(icon)

	if _hallazgos_footer == null:
		return
	var missing := MaizenaMeta.missing_relic_count()
	if missing <= 0:
		_hallazgos_footer.text = "Ya no falta ninguna canción."
	else:
		_hallazgos_footer.text = "Te faltan %d objetos que guardan una canción." % missing


func _style_close_button() -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.2, 0.3, 0.88)
	sb_n.set_corner_radius_all(5)
	sb_n.set_border_width_all(1)
	sb_n.border_color = Color(0.42, 0.76, 0.94, 0.5)
	var sb_h := sb_n.duplicate()
	sb_h.bg_color = Color(0.16, 0.26, 0.38, 0.95)
	close_btn.add_theme_stylebox_override("normal", sb_n)
	close_btn.add_theme_stylebox_override("hover", sb_h)
	close_btn.add_theme_stylebox_override("pressed", sb_h)
	var sb_f := sb_n.duplicate() as StyleBoxFlat
	sb_f.set_border_width_all(3)
	sb_f.border_color = Color(0.85, 0.98, 1.0, 1.0)
	sb_f.bg_color = Color(0.16, 0.28, 0.4, 0.98)
	close_btn.add_theme_stylebox_override("focus", sb_f)
	close_btn.focus_mode = Control.FOCUS_ALL

	close_btn.add_theme_font_size_override("font_size", _scaled_news_font(22))
	_apply_close_button_padding(_font_boost())


func _apply_close_button_padding(boost: float) -> void:
	if close_btn == null:
		return
	var pad_v := int(round(10.0 * boost))
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := close_btn.get_theme_stylebox(state) as StyleBoxFlat
		if sb == null:
			continue
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v


func _on_viewport_layout_changed() -> void:
	_apply_responsive_layout()
	if _needs_infographic_rebuild():
		_rebuild_infographic()


func _needs_infographic_rebuild() -> bool:
	if infographic_root == null:
		return false
	if _infographic_grid == null or not is_instance_valid(_infographic_grid):
		return true
	if _applied_portrait != ViewportLayout.is_portrait:
		return true
	return absf(_applied_layout_scale - ViewportLayout.effective_ui_scale()) >= REBUILD_SCALE_THRESHOLD


func _clear_infographic_children() -> void:
	if infographic_root == null:
		return
	for child in infographic_root.get_children():
		infographic_root.remove_child(child)
		child.free()
	_infographic_grid = null
	_song_val = null
	_radio_footer = null
	_hallazgos_rows = null
	_hallazgos_footer = null
	_era_val = null
	_quest_val = null
	_quest_footer = null
	_field_bar = null
	_field_note = null
	_saturation_footer = null


func _rebuild_infographic() -> void:
	if infographic_root == null:
		return
	_clear_infographic_children()
	_applied_layout_scale = ViewportLayout.effective_ui_scale()
	_applied_portrait = ViewportLayout.is_portrait
	_build_infographic_ui()
	if visible:
		_refresh_infographic()


func _apply_responsive_layout() -> void:
	if report_panel == null:
		return
	ViewportLayout.refresh()
	var layout: Vector2 = ViewportLayout.visible_layout_size()
	var portrait := ViewportLayout.is_portrait
	var boost := _font_boost()

	var panel_w := layout.x * (0.98 if portrait else 0.96)
	var panel_h := layout.y * (0.95 if portrait else 0.92)
	report_panel.offset_left = -panel_w * 0.5
	report_panel.offset_right = panel_w * 0.5
	report_panel.offset_top = -panel_h * 0.5
	report_panel.offset_bottom = panel_h * 0.5

	var outer_m := int(round(12.0 * boost))
	report_margin.add_theme_constant_override("margin_left", outer_m)
	report_margin.add_theme_constant_override("margin_right", outer_m)
	report_margin.add_theme_constant_override("margin_top", int(round(8.0 * boost)))
	report_margin.add_theme_constant_override("margin_bottom", int(round(6.0 * boost)))
	report_vbox.add_theme_constant_override("separation", int(round(8.0 * boost)))

	if header_label != null:
		header_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header_label.custom_minimum_size.y = float(_scaled_news_font(22))
		header_label.add_theme_font_size_override("normal_font_size", _scaled_news_font(22))
	if scroll_container != null:
		scroll_container.custom_minimum_size.y = 0
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_stretch_ratio = 12.0
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if close_btn != null:
		close_btn.size_flags_vertical = Control.SIZE_SHRINK_END
		close_btn.add_theme_font_size_override("font_size", _scaled_news_font(20))
		close_btn.custom_minimum_size.y = maxf(52.0, 40.0 * boost)
		_apply_close_button_padding(boost)
	if _footer_links_box != null:
		_footer_links_box.size_flags_vertical = Control.SIZE_SHRINK_END
		_footer_links_box.add_theme_constant_override(
			"separation",
			int(round(12.0 * boost))
		)
		var link_h := maxf(36.0, 28.0 * boost)
		_footer_links_box.custom_minimum_size.y = link_h
		_apply_footer_separator_layout(_footer_separator, portrait)
	if _footer_link != null:
		_footer_link.visible = true
		_apply_footer_link_layout(_footer_link, portrait)
	if _credits_nav_btn != null:
		_credits_nav_btn.visible = true
		_apply_footer_link_layout(_credits_nav_btn, portrait)
	if _footer_spacer != null:
		_footer_spacer.size_flags_vertical = Control.SIZE_SHRINK_END
		_footer_spacer.custom_minimum_size.y = maxf(4.0, 6.0 * boost)
	_apply_qr_size()
	if infographic_root != null:
		infographic_root.custom_minimum_size.x = 0.0 if portrait else 320.0
	if _infographic_grid != null:
		_infographic_grid.columns = 1 if portrait else 2


func is_blocking() -> bool:
	return visible or _session_auto_open_pending


func open_welcome(mark_seen_when_closed: bool) -> void:
	_session_auto_open_pending = false
	_mark_seen_on_close = mark_seen_when_closed
	_show_news_view()
	if dim_overlay != null:
		dim_overlay.color = Color(0.02, 0.04, 0.08, 0.52)
	ViewportLayout.refresh()
	if _needs_infographic_rebuild():
		_rebuild_infographic()
	elif _song_val == null:
		_rebuild_infographic()
	_apply_responsive_layout()
	_refresh_infographic()
	_sync_backdrop_before_show()
	visible = true
	show()
	_wire_news_focus()
	call_deferred("_apply_responsive_layout")
	call_deferred("_focus_news_start")


func _sync_backdrop_before_show() -> void:
	var time_system := get_tree().get_first_node_in_group("time_system")
	if time_system != null and time_system.has_method("update_time_color"):
		time_system.update_time_color()
	var weather_visual := get_tree().get_first_node_in_group("weather_visual_system")
	if weather_visual != null and weather_visual.has_method("refresh_backdrop"):
		weather_visual.refresh_backdrop()


func open_from_button() -> void:
	open_welcome(false)


func open_from_settings() -> void:
	open_welcome(false)


func _on_close_pressed() -> void:
	hide()
	_news_scroll_hold = 0.0
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	if _mark_seen_on_close:
		MaizenaMeta.mark_welcome_seen()
	_mark_seen_on_close = false
	get_tree().paused = false
	var music := get_tree().get_first_node_in_group("music_manager")
	if music != null and music.has_method("unlock_and_play"):
		music.unlock_and_play()
	_notify_presence_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("booth"):
		_handle_booth_qr(event)
		return
	if event.is_action_pressed("ui_world_news") and _can_toggle_news():
		if visible:
			_on_close_pressed()
		else:
			open_from_button()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _current_view == PopupView.CREDITS:
			_show_news_view()
		else:
			_on_close_pressed()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or scroll_container == null or not scroll_container.has_focus():
		_news_scroll_hold = 0.0
		return
	var direction := 0
	if Input.is_action_pressed("ui_down"):
		direction = 1
	elif Input.is_action_pressed("ui_up"):
		direction = -1
	if direction == 0:
		_news_scroll_hold = 0.0
		return
	_news_scroll_hold += delta
	if _news_scroll_hold < 0.28:
		return
	if not _scroll_news(direction):
		_news_scroll_hold = 0.0
		if direction > 0 and _footer_link != null:
			_footer_link.grab_focus()
		return
	_news_scroll_hold = 0.16


func _wire_news_focus() -> void:
	if scroll_container == null or close_btn == null:
		return
	if _footer_link == null or _credits_nav_btn == null:
		return
	if not scroll_container.gui_input.is_connected(_on_news_scroll_input):
		scroll_container.gui_input.connect(_on_news_scroll_input)
	var list_focus := StyleBoxFlat.new()
	list_focus.bg_color = Color(0, 0, 0, 0)
	list_focus.border_color = Color(0.85, 0.98, 1.0, 0.9)
	list_focus.set_border_width_all(2)
	list_focus.set_corner_radius_all(6)
	scroll_container.add_theme_stylebox_override("focus", list_focus)
	_point_focus(scroll_container, scroll_container, _footer_link, scroll_container, scroll_container)
	_point_focus(_footer_link, scroll_container, close_btn, _footer_link, _credits_nav_btn)
	_point_focus(_credits_nav_btn, scroll_container, close_btn, _footer_link, _credits_nav_btn)
	_point_focus(close_btn, _footer_link, close_btn, close_btn, close_btn)


func _point_focus(control: Control, top: Control, bottom: Control, left: Control, right: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.focus_neighbor_top = control.get_path_to(top)
	control.focus_neighbor_bottom = control.get_path_to(bottom)
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)


func _focus_news_start() -> void:
	if not visible or scroll_container == null:
		return
	scroll_container.grab_focus()


func _on_news_scroll_input(event: InputEvent) -> void:
	if not scroll_container.has_focus():
		return
	var direction := 0
	if event.is_action_pressed("ui_down"):
		direction = 1
	elif event.is_action_pressed("ui_up"):
		direction = -1
	else:
		return
	if direction < 0:
		_scroll_news(direction)
		scroll_container.accept_event()
		_news_scroll_hold = 0.0
		return
	if _scroll_news(direction):
		scroll_container.accept_event()
		_news_scroll_hold = 0.0


func _scroll_news(direction: int) -> bool:
	var bar := scroll_container.get_v_scroll_bar()
	if bar == null:
		return false
	var limit := int(bar.max_value - bar.page)
	if limit <= 0:
		return false
	var step := maxi(48, int(scroll_container.size.y * 0.35))
	var before := scroll_container.scroll_vertical
	var next := clampi(before + direction * step, 0, limit)
	if next == before:
		return false
	scroll_container.scroll_vertical = next
	return true


func _handle_booth_qr(event: InputEvent) -> void:
	if not _can_toggle_news():
		return
	var tutorial := get_tree().get_first_node_in_group("movement_tutorial")
	if tutorial != null and tutorial.has_method("is_blocking") and tutorial.call("is_blocking"):
		return
	if event.is_action_pressed("ui_menu"):
		if visible:
			_on_close_pressed()
		else:
			_open_qr()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _can_toggle_news() -> bool:
	if GameState.bollo_training_active:
		return false
	if DialogueController.input_locked:
		return false
	var sm := get_tree().get_first_node_in_group("settings_menu")
	if sm != null and sm.get("is_open"):
		return false
	return true


func _refresh_infographic() -> void:
	if _song_val == null:
		_rebuild_infographic()
	if _song_val == null:
		return

	_refresh_radio_card()
	_fill_hallazgos()
	_fill_saturation()

	var era := MaizenaMeta.get_current_era_number()

	if era < 1:
		_era_val.text = "Estamos en Pre-Era"
	else:
		_era_val.text = "Estamos en la Era %d" % era
	_fill_side_quest()


func _refresh_radio_card() -> void:
	if _song_val == null or _radio_footer == null:
		return
	var mm := get_tree().get_first_node_in_group("music_manager")
	var song_title := "…"
	var song_key := -1
	if mm != null:
		song_title = mm.get_current_song_title()
		song_key = mm.get_current_song_key()
	var plays := 0
	if song_key >= 0:
		plays = MaizenaMeta.count_song_plays_in_recent_eras(song_key)
	_song_val.text = song_title
	var radio_line := "Esta canción ya sonó en el archipiélago %d veces" % plays
	if MaizenaMeta.missing_relic_count() > 0:
		radio_line += "\nLa radio tiene huecos."
	_radio_footer.text = radio_line


func _fill_saturation() -> void:
	if _field_bar == null or _field_note == null or _saturation_footer == null:
		return
	var things := MaizenaMeta.get_visible_residue_count()
	var cap := int(WorldState.RESIDUE_CAP)
	_field_bar.max_value = float(cap)
	_field_bar.value = float(things)
	_field_note.text = "%d / %d" % [things, cap]
	_saturation_footer.text = _saturation_message(things)


func _fill_side_quest() -> void:
	if _quest_val == null or _quest_footer == null:
		return
	var quest: Dictionary = GameState.mision_secundaria_activa()
	var titulo := str(quest.get("titulo", ""))
	if titulo.is_empty():
		_quest_val.text = "Ninguna"
		_quest_footer.text = "Cuando alguien te pida ayuda, va a aparecer acá."
		return
	_quest_val.text = titulo
	_quest_footer.text = str(quest.get("detalle", ""))


func _notify_presence_refresh() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var world := root.get_node_or_null("NewWorld")
	if world == null:
		return
	var presence := world.get_node_or_null("NpcPresenceSystem")
	if presence != null and presence.has_method("refresh_presence"):
		presence.call("refresh_presence")
