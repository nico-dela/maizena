extends SceneTree
## Restaura nodos de sistemas desde world.scn de HEAD sobre el mapa actual.

const CURRENT_SCENE := "res://scenes/world.scn"
const REFERENCE_SCENE := "res://tools/_world_head_reference.scn"
const OUTPUT_SCENE := "res://scenes/world.scn"

const SYSTEM_NODE_NAMES := [
	"CanvasModulate",
	"WeatherVisualSystem",
	"ResidueSystem",
	"WorldAutonomySystem",
	"NpcPresenceSystem",
	"InteractiveObjects",
]


func _initialize() -> void:
	var current_packed := load(CURRENT_SCENE) as PackedScene
	var ref_packed := load(REFERENCE_SCENE) as PackedScene
	if current_packed == null or ref_packed == null:
		push_error("No se pudieron cargar escenas de merge")
		quit(1)
		return

	var current := current_packed.instantiate()
	var reference := ref_packed.instantiate()

	_apply_world_script(current, reference)

	for sys_name in SYSTEM_NODE_NAMES:
		var existing := current.get_node_or_null(sys_name)
		if existing:
			existing.queue_free()
		var ref_node := reference.get_node_or_null(sys_name)
		if ref_node == null:
			push_warning("Referencia sin nodo: %s" % sys_name)
			continue
		var dup := ref_node.duplicate(Node.DUPLICATE_USE_INSTANTIATION | Node.DUPLICATE_SIGNALS)
		dup.name = sys_name
		current.add_child(dup)

	var exported := PackedScene.new()
	var pack_err := exported.pack(current)
	current.free()
	reference.free()
	if pack_err != OK:
		push_error("No se pudo empaquetar escena mergeada")
		quit(1)
		return

	var err := ResourceSaver.save(exported, OUTPUT_SCENE)
	if err != OK:
		push_error("No se pudo guardar %s" % OUTPUT_SCENE)
		quit(1)
		return

	print("OK merged systems -> %s" % OUTPUT_SCENE)
	quit()


func _apply_world_script(current: Node, reference: Node) -> void:
	var ref_script: Script = reference.get_script()
	if ref_script:
		current.set_script(ref_script)
