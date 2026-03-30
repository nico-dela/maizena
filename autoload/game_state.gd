extends Node

var quest_hambre_active := false
var quest_hambre_completed := false
var tiene_comida := false

func buscar_comida():
	quest_hambre_active = true
	tiene_comida = false

func agarrar_comida():
	tiene_comida = true

func completar_comida():
	quest_hambre_active = false
	quest_hambre_completed = true
	tiene_comida = false
