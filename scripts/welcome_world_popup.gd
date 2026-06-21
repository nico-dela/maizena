extends CanvasLayer

const FONT: FontFile = preload("res://assets/ui/PixelOperator8.ttf")

const BASE_CARD_MIN := Vector2(160, 168)
const PORTRAIT_FONT_MUL := 1.42
const PORTRAIT_CARD_MUL := 1.28
const LANDSCAPE_FONT_MUL := 1.2
const LANDSCAPE_CARD_MUL := 1.18
const PHONE_LANDSCAPE_HEIGHT := 500.0
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
const RESIDUE_MAX := 80

@onready var header_label: RichTextLabel = $CenterRoot/Report/Margin/VBox/HeaderLabel
@onready var report_panel: PanelContainer = $CenterRoot/Report
@onready var report_margin: MarginContainer = $CenterRoot/Report/Margin
@onready var report_vbox: VBoxContainer = $CenterRoot/Report/Margin/VBox
@onready var infographic_root: VBoxContainer = $CenterRoot/Report/Margin/VBox/Scroll/InfographicRoot
@onready var scroll_container: ScrollContainer = $CenterRoot/Report/Margin/VBox/Scroll
@onready var close_btn: Button = $CenterRoot/Report/Margin/VBox/CloseButton

var _song_val: Label
var _radio_footer: Label
var _era_val: Label
var _field_bar: ProgressBar
var _field_note: Label
var _saturation_footer: Label
var _npc_val: Label

const NPC_SKIP_PREFIXES := ["cartel_"]
const NPC_SKIP_NAMES := ["laboratorio", "templo_sapos", "orbe_electrico", "piedra_grieta", "bicicleta"]
const NPC_DISPLAY_NAMES := {
	"bollo": "Bollo",
	"boji": "Boji",
	"hi": "Hi",
	"spinetto": "Spinetto",
	"silueto_1": "Silueto",
	"silueto_2": "Silueto",
	"michis": "Michis",
	"kaeru": "Kaeru",
	"ranancio": "Ranancio",
	"el_viejo": "El Viejo",
}

var _mark_seen_on_close := false
var _card_style: StyleBoxFlat
var _infographic_grid: GridContainer
var _footer_link: LinkButton
var _footer_spacer: Control
var _applied_layout_scale := 1.0
var _applied_portrait := false


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
	_applied_layout_scale = ViewportLayout.effective_ui_scale()
	_applied_portrait = ViewportLayout.is_portrait
	_apply_responsive_layout()
	ViewportLayout.layout_changed.connect(_on_viewport_layout_changed)

	await get_tree().process_frame
	await get_tree().process_frame

	call_deferred("open_welcome", false)


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


func _is_phone_landscape() -> bool:
	return not ViewportLayout.is_portrait and ViewportLayout.visible_layout_size().y < PHONE_LANDSCAPE_HEIGHT


func _layout_font_mul() -> float:
	if ViewportLayout.is_portrait:
		return PORTRAIT_FONT_MUL
	if _is_phone_landscape():
		return LANDSCAPE_FONT_MUL
	return 1.0


func _layout_card_mul() -> float:
	if ViewportLayout.is_portrait:
		return PORTRAIT_CARD_MUL
	if _is_phone_landscape():
		return LANDSCAPE_CARD_MUL
	return 1.0


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
	header_label.text = (
		"[center][color=#72cce8]Las noticias[/color] "
		+ "[color=#e85050]/[/color][color=#e8c840]/[/color][color=#5080e8]/[/color] "
		+ "[color=#f07828]Maizena.tv[/color][/center]"
	)


func _setup_footer_links() -> void:
	var link := LinkButton.new()
	link.text = "Seguinos en las redes"
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.add_theme_font_override("font", FONT)
	link.add_theme_font_size_override("font_size", _scaled_news_font(16))
	link.add_theme_color_override("font_color", Color(0.45, 0.80, 0.91, 1.0))
	link.add_theme_color_override("font_hover_color", Color(0.65, 0.92, 1.0, 1.0))
	link.focus_mode = Control.FOCUS_NONE
	link.pressed.connect(_on_linktree_pressed)
	_footer_link = link

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_spacer = spacer

	var vbox := close_btn.get_parent()
	vbox.add_child(link)
	vbox.add_child(spacer)
	vbox.move_child(link, close_btn.get_index())
	vbox.move_child(spacer, close_btn.get_index())


func _on_linktree_pressed() -> void:
	_open_external_url(LINKTREE_URL)


func _open_external_url(url: String) -> void:
	OS.shell_open(url)


func _build_infographic_ui() -> void:
	var grid := GridContainer.new()
	var portrait := ViewportLayout.is_portrait
	grid.columns = 1 if portrait else 2
	var grid_sep := int(round((18.0 if portrait else 12.0) * _font_boost()))
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

	var era := _add_news_card(
		grid,
		COLOR_ORANGE,
		"En esta isla el tiempo pasa en Eras",
		"como la cantidad de semanas desde que lanzamos el disco 'Una banda de cosas tiradas'"
	)
	_era_val = era["value"]

	_field_bar = _add_saturation_card(grid)

	var npc := _add_news_card(
		grid,
		COLOR_CORAL,
		"A esta hora están en la isla:",
		"podés interactuar con ellxs y tratar de entenderlos. Se van y vuelven según el rato del día"
	)
	_npc_val = npc["value"]


func _card_style_for_layout() -> StyleBoxFlat:
	var sb := _make_card_stylebox()
	var boost := _font_boost()
	var margin := int(round((18.0 if ViewportLayout.is_portrait else 12.0) * boost))
	sb.content_margin_left = margin
	sb.content_margin_top = int(round((14.0 if ViewportLayout.is_portrait else 10.0) * boost))
	sb.content_margin_right = margin
	sb.content_margin_bottom = int(round((14.0 if ViewportLayout.is_portrait else 10.0) * boost))
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
		value_font_size = 30 if ViewportLayout.is_portrait else 24
	var header_size := 16 if ViewportLayout.is_portrait else 12
	var footer_size := 14 if ViewportLayout.is_portrait else 11

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style_for_layout())
	var card_scale := _font_boost() * _layout_card_mul()
	panel.custom_minimum_size = BASE_CARD_MIN * card_scale
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round((10.0 if ViewportLayout.is_portrait else 8.0) * _font_boost())))
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


func _add_saturation_card(grid: GridContainer) -> ProgressBar:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style_for_layout())
	var card_scale := _font_boost() * _layout_card_mul()
	panel.custom_minimum_size = BASE_CARD_MIN * card_scale
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round((8.0 if ViewportLayout.is_portrait else 6.0) * _font_boost())))
	panel.add_child(v)

	var header := _lbl(16 if ViewportLayout.is_portrait else 12, COLOR_GREEN)
	header.text = "El indice de saturación de cosas en este momento es:"
	v.add_child(header)

	var hint := _lbl(14 if ViewportLayout.is_portrait else 11, Color(0.72, 0.78, 0.86, 1.0))
	hint.text = "Cosas / tope"
	v.add_child(hint)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, maxi(18, _scaled_news_font(18)))
	bar.max_value = float(RESIDUE_MAX)
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

	var cap := _lbl(28 if ViewportLayout.is_portrait else 22, COLOR_VALUE, true)
	cap.text = "0 / %d" % RESIDUE_MAX
	v.add_child(cap)
	_field_note = cap

	var footer := _lbl(14 if ViewportLayout.is_portrait else 11, COLOR_GREEN)
	footer.text = _saturation_message(0)
	v.add_child(footer)
	_saturation_footer = footer

	grid.add_child(panel)
	return bar


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
	close_btn.add_theme_stylebox_override("focus", sb_n)


	close_btn.add_theme_font_size_override("font_size", _scaled_news_font(22))


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
	_era_val = null
	_field_bar = null
	_field_note = null
	_saturation_footer = null
	_npc_val = null


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

	if portrait:
		var panel_w := layout.x * 0.98
		var panel_h := layout.y * 0.95
		report_panel.offset_left = -panel_w * 0.5
		report_panel.offset_right = panel_w * 0.5
		report_panel.offset_top = -panel_h * 0.5
		report_panel.offset_bottom = panel_h * 0.5
	elif _is_phone_landscape():
		var panel_w := layout.x * 0.92
		var panel_h := layout.y * 0.85
		report_panel.offset_left = -panel_w * 0.5
		report_panel.offset_right = panel_w * 0.5
		report_panel.offset_top = -panel_h * 0.5
		report_panel.offset_bottom = panel_h * 0.5
	else:
		var panel_w := minf(720.0, layout.x * 0.94)
		var panel_h := minf(600.0, layout.y * 0.88)
		report_panel.offset_left = -panel_w * 0.5
		report_panel.offset_right = panel_w * 0.5
		report_panel.offset_top = -panel_h * 0.5
		report_panel.offset_bottom = panel_h * 0.5

	var outer_m := int(round((12.0 if portrait else (10.0 if _is_phone_landscape() else 6.0)) * boost))
	report_margin.add_theme_constant_override("margin_left", outer_m)
	report_margin.add_theme_constant_override("margin_right", outer_m)
	report_margin.add_theme_constant_override("margin_top", int(round((8.0 if portrait else 4.0) * boost)))
	report_margin.add_theme_constant_override("margin_bottom", int(round((8.0 if portrait else 4.0) * boost)))
	report_vbox.add_theme_constant_override("separation", int(round((16.0 if portrait else 12.0) * boost)))

	if header_label != null:
		header_label.custom_minimum_size.y = float(_scaled_news_font(28 if portrait else 20))
		header_label.add_theme_font_size_override("normal_font_size", _scaled_news_font(28 if portrait else 20))
	if close_btn != null:
		close_btn.add_theme_font_size_override("font_size", _scaled_news_font(28 if portrait else 22))
		close_btn.custom_minimum_size.y = maxf(56.0, 44.0 * boost)
	if _footer_link != null:
		_footer_link.add_theme_font_size_override("font_size", _scaled_news_font(20 if portrait else 16))
	if _footer_spacer != null:
		_footer_spacer.custom_minimum_size.y = maxf(28.0, (44.0 if portrait else 20.0) * boost)
	if scroll_container != null:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if infographic_root != null:
		infographic_root.custom_minimum_size.x = 0.0 if portrait else 320.0
	if _infographic_grid != null:
		_infographic_grid.columns = 1 if portrait else 2


func is_blocking() -> bool:
	return visible


func open_welcome(mark_seen_when_closed: bool) -> void:
	_mark_seen_on_close = mark_seen_when_closed
	ViewportLayout.refresh()
	if _needs_infographic_rebuild():
		_rebuild_infographic()
	elif _song_val == null:
		_rebuild_infographic()
	_apply_responsive_layout()
	_refresh_infographic()
	visible = true
	show()
	call_deferred("_apply_responsive_layout")


func open_from_button() -> void:
	open_welcome(false)


func open_from_settings() -> void:
	open_welcome(false)


func _on_close_pressed() -> void:
	hide()
	if _mark_seen_on_close:
		MaizenaMeta.mark_welcome_seen()
	_mark_seen_on_close = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
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

	var mm := get_tree().get_first_node_in_group("music_manager")
	var song_title := "…"
	var song_key := -1
	if mm != null:
		song_title = mm.get_current_song_title()
		song_key = mm.get_current_song_key()

	var plays := 0
	if song_key >= 0:
		plays = MaizenaMeta.count_song_plays_in_recent_eras(song_key)

	var things := MaizenaMeta.get_visible_residue_count()
	var era := MaizenaMeta.get_current_era_number()

	_song_val.text = song_title
	_radio_footer.text = "Esta canción ya sonó en el archipiélago %d veces" % plays

	if era < 1:
		_era_val.text = "Estamos en Pre-Era"
	else:
		_era_val.text = "Estamos en la Era %d" % era

	_field_bar.value = float(things)
	_field_note.text = "%d / %d" % [things, RESIDUE_MAX]
	_saturation_footer.text = _saturation_message(things)

	if _npc_val != null:
		_npc_val.text = _get_visible_npc_text()


func _saturation_message(things: int) -> String:
	var ratio := float(things) / float(RESIDUE_MAX)
	if ratio >= 0.82:
		return "Al borde de la explosión: el archipiélago está a reventar."
	if ratio >= 0.6:
		return "Saturación alta: cada rincón tiene algo tirado."
	if ratio >= 0.35:
		return "Saturación media: el paisaje se va llenando."
	return "Saturación baja: todavía hay aire entre las cosas."


func _get_visible_npc_text() -> String:
	var names: Array[String] = []
	var world := get_tree().root.get_node_or_null("MainScene/World")
	if world == null:
		world = get_tree().get_first_node_in_group("world")
	var objects: Node = null
	if world != null:
		objects = world.get_node_or_null("InteractiveObjects")

	if objects != null:
		for child in objects.get_children():
			if not _is_trackable_npc(child):
				continue
			if not child.visible:
				continue
			var display := _format_npc_name(str(child.name))
			if display.is_empty() or names.has(display):
				continue
			names.append(display)

	if names.is_empty():
		return "Nadie en pantalla ahora"
	return ", ".join(names)


func _is_trackable_npc(node: Node) -> bool:
	var node_name := str(node.name)
	for prefix in NPC_SKIP_PREFIXES:
		if node_name.begins_with(prefix):
			return false
	if node_name in NPC_SKIP_NAMES:
		return false
	return node is StaticBody2D or node.has_method("set_active")


func _format_npc_name(node_name: String) -> String:
	if NPC_DISPLAY_NAMES.has(node_name):
		return NPC_DISPLAY_NAMES[node_name]
	if node_name.begins_with("silueto"):
		return "Silueto"
	return node_name.capitalize().replace("_", " ")
