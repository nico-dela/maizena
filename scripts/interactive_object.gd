extends StaticBody2D

@export var dialogue: DialogueResource
@export var start_node := "start"

# Configuración de horarios
# Cada diccionario puede tener:
# - start: hora de inicio (ej: 8.5 = 8:30)
# - end: hora de fin (ej: 17.0 = 17:00)
# - probability: 0.0 a 1.0 (0% a 100%)
@export var spawn_schedules: Array[Dictionary] = [
	{"start": 8.0, "end": 12.0, "probability": 0.3},   # 30% por la mañana
	{"start": 14.0, "end": 18.0, "probability": 0.5},  # 50% por la tarde
	{"start": 20.0, "end": 23.0, "probability": 0.2}   # 20% por la noche
]

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

var is_active: bool = false
var time_system: TimeOfDaySystem
var rng = RandomNumberGenerator.new()
var original_modulate: Color

func _ready():
	original_modulate = modulate
	
	# Empezar invisible por defecto
	visible = false
	if collision:
		collision.disabled = true
	
	# Si no tiene diálogo, no aparece nunca y listo
	if not dialogue:
		return  # Ya está invisible, no hacemos más
	
	# Buscar el sistema de tiempo
	await get_tree().process_frame
	time_system = get_tree().get_first_node_in_group("time_system")
	
	if time_system:
		time_system.time_updated.connect(_on_time_updated)
		# Evaluar inmediatamente al iniciar
		_evaluate_appearance(time_system.current_time)
	else:
		print("ERROR: No se encontró TimeOfDaySystem en ", name)
		# Si no hay sistema de tiempo, aparecer por defecto
		set_active(true)
	
	rng.randomize()

func _on_time_updated(current_hour: float, _is_day: bool):
	_evaluate_appearance(current_hour)

func _evaluate_appearance(current_hour: float):
	var should_appear = false
	
	# Si no hay horarios configurados, aparecer siempre
	if spawn_schedules.is_empty():
		set_active(true)
		return
	
	# Revisar todos los horarios configurados
	for schedule in spawn_schedules:
		var start = schedule.get("start", 8.0)
		var end = schedule.get("end", 20.0)
		var prob = schedule.get("probability", 1.0)
		
		var in_schedule = false
		if start <= end:
			# Horario normal (ej: 8:00 - 20:00)
			in_schedule = current_hour >= start and current_hour < end
		else:
			# Horario que cruza medianoche (ej: 22:00 - 6:00)
			in_schedule = current_hour >= start or current_hour < end
		
		if in_schedule:
			# Aplicar probabilidad independiente para cada NPC
			if rng.randf() < prob:
				should_appear = true
				break
	
	set_active(should_appear)

func set_active(active: bool):
	if is_active == active:
		return
	
	is_active = active
	
	# Desaparecer completamente de la escena
	visible = active
	
	if collision:
		collision.disabled = not active
	
	# Controlar la animación SOLO si existe
	if animated_sprite and animated_sprite.sprite_frames:
		if active:
			# Verificar si hay animaciones disponibles
			var anim_names = animated_sprite.sprite_frames.get_animation_names()
			if not anim_names.is_empty():
				# Usar la primera animación disponible
				animated_sprite.animation = anim_names[0]
				animated_sprite.play()
			else:
				# Si no hay animaciones, solo mostrar el primer frame
				animated_sprite.frame = 0
				animated_sprite.visible = true
		else:
			animated_sprite.stop()
			animated_sprite.visible = false  # <-- AÑADIR ESTO
	
	# Animación de fade al aparecer/desaparecer
	if active:
		modulate = Color.TRANSPARENT
		var tween = create_tween()
		tween.tween_property(self, "modulate", original_modulate, 0.5)
	else:
		modulate = original_modulate
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)

func show_dialogue():
	if is_active and dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, start_node)
