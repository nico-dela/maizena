extends Node2D

var dialoguePaths : Dictionary = {
	"cartel_sanjin": "res://dialogues/cartel_sanjin.dialogue",
	"boji": "res://dialogues/boji.dialogue",
	"hi": "res://dialogues/hi.dialogue",
	"bollo": "res://dialogues/bollo.dialogue",
	"spinetto": "res://dialogues/spinetto.dialogue",
	"silueto_1": "res://dialogues/silueto_1.dialogue",
	"silueto_2": "res://dialogues/silueto_2.dialogue",
	"michis": "res://dialogues/michis.dialogue",
	"kaeru": "res://dialogues/kaeru.dialogue",
	"ranancio": "res://dialogues/ranancio.dialogue",
	"el_viejo": "res://dialogues/el_viejo.dialogue",
	"bicicleta": "res://dialogues/bicicleta.dialogue",
	"cartel_bollo": "res://dialogues/cartel_bollo.dialogue",
	"cartel_laboratorio": "res://dialogues/cartel_laboratorio.dialogue",
	"laboratorio": "res://dialogues/laboratorio.dialogue",
	"cartel_arboles": "res://dialogues/cartel_arboles.dialogue",
	"cartel_pantano": "res://dialogues/cartel_pantano.dialogue",
	"piedra_grieta": "res://dialogues/piedra_grieta.dialogue",
	"templo_sapos": "res://dialogues/templo_sapos.dialogue",
	"orbe_electrico": "res://dialogues/orbe_electrico.dialogue",
	"cartel_aldea": "res://dialogues/cartel_aldea.dialogue"
}

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_manager_dialogue_ended)

func show_dialogue() -> void:
	var current_node = get_node(".")
	var node_name = current_node.get_name()

	if dialoguePaths.has(node_name):
		DialogueManager.show_dialogue_balloon(load(dialoguePaths[node_name]), "start")

	global.shown_dialogue = true

func _on_dialogue_manager_dialogue_ended(_resource: DialogueResource) -> void:
	global.shown_dialogue = false
