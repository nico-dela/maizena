extends SceneTree

## Copies YATI-imported map scenes from .godot/imported/ into scenes/world/maps/
## so Web export can load them without the YATI editor importer.
##
## Usage (after editing .tmx in Tiled and reimporting in Godot):
##   godot --headless --path . --script tools/bake_yati_maps.gd

const OUTPUT_DIR := "res://scenes/world/maps"

const MAPS: Array[Dictionary] = [
	{
		"tmx": "res://assets/art/maps/web_maizena_rpg/Bosque encantado 1.tmx",
		"output": "res://scenes/world/maps/bosque_encantado_map.tscn",
	},
	{
		"tmx": "res://assets/art/maps/web_maizena_rpg/Ciudad.tmx",
		"output": "res://scenes/world/maps/ciudad_map.tscn",
	},
	{
		"tmx": "res://assets/art/maps/web_maizena_rpg/Pantano Sur.tmx",
		"output": "res://scenes/world/maps/pantano_sur_map.tscn",
	},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var failed := false
	for entry: Dictionary in MAPS:
		var source_path := _resolve_imported_scene(entry.tmx)
		if source_path.is_empty():
			push_error("No se encontró escena importada para %s" % entry.tmx)
			failed = true
			continue

		var packed := ResourceLoader.load(source_path) as PackedScene
		if packed == null:
			push_error("No se pudo cargar %s" % source_path)
			failed = true
			continue

		var err := ResourceSaver.save(packed, entry.output)
		if err != OK:
			push_error("No se pudo guardar %s (%s)" % [entry.output, error_string(err)])
			failed = true
			continue

		print("OK %s <- %s" % [entry.output, source_path])

	if failed:
		quit(1)
		return

	print("Listo. Escenas horneadas en %s" % OUTPUT_DIR)
	quit()


func _resolve_imported_scene(tmx_path: String) -> String:
	var import_path := "%s.import" % tmx_path
	if not FileAccess.file_exists(import_path):
		return ""

	var dest_path := _read_dest_file(import_path)
	if dest_path.is_empty():
		return ""

	if FileAccess.file_exists(dest_path):
		return dest_path

	# Fallback: remap path from .import [remap] section.
	var remap_path := _read_remap_path(import_path)
	if remap_path.is_empty():
		return ""

	return remap_path if FileAccess.file_exists(remap_path) else ""


func _read_dest_file(import_path: String) -> String:
	var text := FileAccess.get_file_as_string(import_path)
	var in_deps := false
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed == "[deps]":
			in_deps = true
			continue
		if trimmed.begins_with("[") and trimmed != "[deps]":
			in_deps = false
		if in_deps and trimmed.begins_with("dest_files="):
			var start := trimmed.find('"')
			var end := trimmed.rfind('"')
			if start >= 0 and end > start:
				return trimmed.substr(start + 1, end - start - 1)
	return ""


func _read_remap_path(import_path: String) -> String:
	var text := FileAccess.get_file_as_string(import_path)
	var in_remap := false
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed == "[remap]":
			in_remap = true
			continue
		if trimmed.begins_with("[") and trimmed != "[remap]":
			in_remap = false
		if in_remap and trimmed.begins_with("path="):
			return trimmed.substr(5).strip_edges().trim_prefix('"').trim_suffix('"')
	return ""
