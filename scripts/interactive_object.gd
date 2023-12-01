extends Node2D

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_manager_dialogue_ended)

func show_dialogue():
	var current_node = get_node(".")
	var node_name = current_node.get_name()
	
	if node_name == "cartel_sanjin":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/cartel_sanjin.dialogue"), "start")
	elif node_name == "boji":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/boji.dialogue"), "start")
	elif node_name == "hi":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/hi.dialogue"), "start")
	elif node_name == "bollo":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/bollo.dialogue"), "start")
	elif node_name == "spinetto":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/spinetto.dialogue"), "start")
	elif node_name == "silueto_1":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/silueto_1.dialogue"), "start")
	elif node_name == "silueto_2":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/silueto_2.dialogue"), "start")
	elif node_name == "michis":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/michis.dialogue"), "start")
	elif node_name == "kaeru":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/kaeru.dialogue"), "start")
	elif node_name == "ranancio":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/ranancio.dialogue"), "start")
	elif node_name == "el_viejo":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/el_viejo.dialogue"), "start")
	elif node_name == "bicicleta":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/bicicleta.dialogue"), "start")
	elif node_name == "cartel_bollo":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/cartel_bollo.dialogue"), "start")
	elif node_name == "cartel_laboratorio":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/cartel_laboratorio.dialogue"), "start")
	elif node_name == "laboratorio":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/laboratorio.dialogue"), "start")
	elif node_name == "cartel_arboles":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/cartel_arboles.dialogue"), "start")
	elif node_name == "cartel_pantano":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/cartel_pantano.dialogue"), "start")
	elif node_name == "piedra_grieta":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/piedra_grieta.dialogue"), "start")
	elif node_name == "templo_sapos":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/templo_sapos.dialogue"), "start")
	elif node_name == "orbe_electrico":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/orbe_electrico.dialogue"), "start")
	elif node_name == "cartel_aldea":
		DialogueManager.show_dialogue_balloon(load("res://dialogues/cartel_aldea.dialogue"), "start")
	
	global.shown_dialogue = true
	
func _on_dialogue_manager_dialogue_ended(_resource: DialogueResource):
	global.shown_dialogue = false
