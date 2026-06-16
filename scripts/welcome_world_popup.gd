extends CanvasLayer

const FONT: FontFile = preload("res://assets/ui/PixelOperator8.ttf")

@onready var infographic_root: VBoxContainer = $CenterRoot/Report/Margin/VBox/Scroll/InfographicRoot
@onready var close_btn: Button = $CenterRoot/Report/Margin/VBox/CloseButton

var _song_val: Label
var _plays_val: Label
var _field_bar: ProgressBar
var _field_note: Label
var _era_val: Label
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


func _ready() -> void:
	_promote_if_nested_under_canvas_layer()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	hide()
	_card_style = _make_card_stylebox()
	_style_close_button()
	close_btn.pressed.connect(_on_close_pressed)
	_build_infographic_ui()

	await get_tree().process_frame
	await get_tree().process_frame

	call_deferred("open_welcome", false)


func _promote_if_nested_under_canvas_layer() -> void:
	# Un CanvasLayer hijo de otro CanvasLayer suele quedar sin tamaño → popup invisible.
	var p := get_parent()
	if p is CanvasLayer:
		var host: Node = p.get_parent()
		if host != null:
			p.remove_child(self)
			host.add_child(self)
			host.move_child(self, -1)


func _make_card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.11, 0.16, 0.78)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.28, 0.55, 0.72, 0.55)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	return sb


func _lbl(size: int, color: Color, outline := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
		l.add_theme_constant_override("outline_size", 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_infographic_ui() -> void:
	if infographic_root.get_child_count() > 0:
		return

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infographic_root.add_child(grid)

	_song_val = _add_stat_card(grid, "♫", "Radio", "Título actual")
	_plays_val = _add_stat_card(
		grid,
		"↻",
		"REPETICIONES",
		"Veces que sonó la canción de radio (últ. %d eras)" % MaizenaMeta.get_recent_era_window()
	)
	_field_bar = _add_field_card(grid)
	_era_val = _add_stat_card(grid, "◷", "ERA", "Semanas desde el lanzamiento del disco")
	_add_npc_full_width_row(infographic_root)


func _add_npc_full_width_row(parent: VBoxContainer) -> void:
	# Fuera de la grilla 2×2: evita una celda suelta más baja y distinta a las demás.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style.duplicate())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 96)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)

	var g := _lbl(22, Color(0.45, 0.88, 1.0, 1.0), true)
	g.text = "◎"
	g.custom_minimum_size = Vector2(36, 32)
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(g)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)

	var tag_l := _lbl(13, Color(0.62, 0.78, 0.9, 1.0))
	tag_l.text = "NPCs"
	col.add_child(tag_l)

	var hint_l := _lbl(11, Color(0.45, 0.55, 0.62, 1.0))
	hint_l.text = "Visibles en el mapa ahora"
	col.add_child(hint_l)

	var val := _lbl(20, Color(0.95, 0.97, 1.0, 1.0), true)
	val.text = "—"
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(val)
	_npc_val = val

	parent.add_child(panel)


func _add_stat_card(grid: GridContainer, glyph: String, tag: String, hint: String, value_font_size: int = 20) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style.duplicate())
	panel.custom_minimum_size = Vector2(148, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)

	var g := _lbl(20, Color(0.45, 0.88, 1.0, 1.0), true)
	g.text = glyph
	g.custom_minimum_size = Vector2(32, 28)
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(g)

	var tag_l := _lbl(13, Color(0.62, 0.78, 0.9, 1.0))
	tag_l.text = tag
	tag_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(tag_l)

	if not hint.is_empty():
		var hint_l := _lbl(11, Color(0.45, 0.55, 0.62, 1.0))
		hint_l.text = hint
		v.add_child(hint_l)

	var val := _lbl(value_font_size, Color(0.95, 0.97, 1.0, 1.0), true)
	val.text = "—"
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(val)

	grid.add_child(panel)
	return val


func _add_field_card(grid: GridContainer) -> ProgressBar:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style.duplicate())
	panel.custom_minimum_size = Vector2(148, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)

	var g := _lbl(20, Color(0.45, 0.88, 1.0, 1.0), true)
	g.text = "▣"
	g.custom_minimum_size = Vector2(32, 28)
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(g)

	var t := _lbl(13, Color(0.62, 0.78, 0.9, 1.0))
	t.text = "SATURACIÓN"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(t)

	var h := _lbl(11, Color(0.45, 0.55, 0.62, 1.0))
	h.text = "Cosas / tope"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(h)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 80.0
	bar.value = 0.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.75, 0.95, 0.85)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.07, 0.1, 0.9)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)

	var cap := _lbl(18, Color(0.95, 0.97, 1.0, 1.0), true)
	cap.text = "0 / 80"
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(cap)
	_field_note = cap

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


func is_blocking() -> bool:
	return visible


func open_welcome(mark_seen_when_closed: bool) -> void:
	_mark_seen_on_close = mark_seen_when_closed
	_refresh_infographic()
	visible = true
	show()


func open_from_button() -> void:
	open_welcome(false)


func open_from_settings() -> void:
	open_welcome(false)


func _on_close_pressed() -> void:
	hide()
	if _mark_seen_on_close:
		MaizenaMeta.mark_welcome_seen()
	_mark_seen_on_close = false


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
	_plays_val.text = "%d veces\n«%s»" % [plays, song_title]

	_field_bar.value = float(things)
	_field_note.text = "%d / 80" % things

	if era < 1:
		_era_val.text = "Pre-Era"
	else:
		_era_val.text = "Era %d" % era

	if _npc_val != null:
		_npc_val.text = _get_visible_npc_text()


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
