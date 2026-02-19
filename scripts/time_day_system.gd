extends Node
class_name TimeOfDaySystem

signal time_updated(current_hour: float, is_day: bool)

# Colores para cada hora (puedes ajustarlos)
var time_colors = {
	"morning": Color(1.0, 1.0, 0.9),     # Amarillo suave
	"day": Color(1.0, 1.0, 1.0),         # Normal (blanco)
	"evening": Color(1.0, 0.8, 0.7),     # Naranja/rojizo
	"night": Color(0.3, 0.4, 0.8, 0.7),  # Azul oscuro semi-transparente
	"midnight": Color(0.2, 0.2, 0.5, 0.8) # Azul muy oscuro
}

@onready var canvas_modulate: CanvasModulate = get_node("CanvasModulate")

# Sistema de tiempo
var current_time: float = 8.0  # Se establecerá con la hora real
var time_speed: float = 0.0    # Por defecto, tiempo estático (no avanza automáticamente)
var use_real_time: bool = true # Usar hora real del sistema

func _ready():
	add_to_group("time_system")
	
	if not canvas_modulate:
		# Crear dinámicamente si no existe
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		get_node("..").call_deferred("add_child", canvas_modulate)
	
	# Obtener hora actual del sistema
	get_current_system_time()
	
	update_time_color()
	
	# Si queremos que el tiempo avance en tiempo real
	if time_speed > 0:
		set_process(true)
	else:
		set_process(false)

func _process(delta):
	if time_speed > 0:
		# Avanzar tiempo de juego (no tiempo real)
		advance_time(delta)
		update_time_color()
	elif use_real_time:
		# Actualizar con hora real del sistema periódicamente
		update_with_real_time()

func get_current_system_time():
	# Obtener fecha y hora actual del sistema
	var datetime = Time.get_datetime_dict_from_system()
	
	# Extraer hora y minuto
	var hour = datetime.hour
	var minute = datetime.minute
	var second = datetime.second
	
	# Convertir a formato decimal (ej: 14:30:00 = 14.5)
	current_time = float(hour) + float(minute) / 60.0 + float(second) / 3600.0
	
	return current_time

func update_with_real_time():
	# Obtener hora actual del sistema
	var datetime = Time.get_datetime_dict_from_system()
	var new_time = float(datetime.hour) + float(datetime.minute) / 60.0
	
	# Solo actualizar si la hora cambió
	if abs(new_time - current_time) >= 1.0 / 60.0:  # Si cambió al menos 1 minuto
		current_time = new_time
		update_time_color()
		#print("Hora actualizada: %.2f" % current_time)

func advance_time(delta: float):
	# Avanzar tiempo del juego (no tiempo real)
	current_time += delta * time_speed / 60.0  # Convertir a minutos
	if current_time >= 24.0:
		current_time = 0.0

func update_time_color():
	emit_signal("time_updated", current_time, is_daytime())
	var color: Color
	
	if current_time >= 5.0 and current_time < 8.0:
		# Amanecer (5:00 - 8:00)
		var t = (current_time - 5.0) / 3.0
		color = lerp(time_colors["midnight"], time_colors["morning"], t)
		
	elif current_time >= 8.0 and current_time < 17.0:
		# Día (8:00 - 17:00)
		color = time_colors["day"]
		
	elif current_time >= 17.0 and current_time < 20.0:
		# Atardecer (17:00 - 20:00)
		var t = (current_time - 17.0) / 3.0
		color = lerp(time_colors["day"], time_colors["evening"], t)
		
	elif current_time >= 20.0 or current_time < 5.0:
		# Noche (20:00 - 5:00)
		if current_time >= 20.0:
			var t = (current_time - 20.0) / 2.0
			color = lerp(time_colors["evening"], time_colors["night"], min(t, 1.0))
		else:
			var t = current_time / 5.0
			color = lerp(time_colors["midnight"], time_colors["night"], t)
	
	# Aplicar con suavizado
	if canvas_modulate:
		canvas_modulate.color = color

# Funciones para cambiar tiempo manualmente
func set_time(hour: float, minute: float = 0.0):
	current_time = hour + minute / 60.0
	use_real_time = false  # Desactivar tiempo real al cambiar manualmente
	update_time_color()
	print("Hora establecida manualmente: %.2f" % current_time)

func set_time_of_day(time_name: String):
	var colors = {
		"morning": time_colors["morning"],
		"day": time_colors["day"],
		"evening": time_colors["evening"],
		"night": time_colors["night"],
		"midnight": time_colors["midnight"]
	}
	
	if colors.has(time_name) and canvas_modulate:
		canvas_modulate.color = colors[time_name]
		use_real_time = false  # Desactivar tiempo real
		
		# Establecer hora aproximada para ese momento del día
		match time_name:
			"morning":
				current_time = 6.0
			"day":
				current_time = 12.0
			"evening":
				current_time = 18.0
			"night":
				current_time = 22.0
			"midnight":
				current_time = 0.0
		
		print("Establecido: %s (%.2f)" % [time_name, current_time])

# Funciones para controlar el comportamiento del tiempo
func enable_real_time():
	"""Activar sincronización con hora real del sistema"""
	use_real_time = true
	time_speed = 0.0  # Desactivar avance automático
	get_current_system_time()
	update_time_color()
	print("Tiempo real activado")

func enable_game_time(speed: float = 60.0):
	"""Activar tiempo de juego que avanza automáticamente"""
	use_real_time = false
	time_speed = speed
	set_process(true)
	print("Tiempo de juego activado (velocidad: %.1f)" % speed)

func pause_time():
	"""Pausar el avance del tiempo"""
	time_speed = 0.0
	set_process(false)
	print("Tiempo pausado")

# Para debug/control
#func _input(event):
	## R - Activar hora real del sistema
	#if event.is_action_pressed("ui_accept"):
		#enable_real_time()
	#
	## G - Activar tiempo de juego
	#elif event.is_action_pressed("ui_focus_next"):
		#enable_game_time(60.0)
	#
	## P - Pausar tiempo
	#elif event.is_action_pressed("ui_cancel"):
		#pause_time()
	#
	## Teclas 1-5 - Momentos del día
	#elif event.is_action_pressed("ui_1"):
		#set_time_of_day("morning")
	#elif event.is_action_pressed("ui_2"):
		#set_time_of_day("day")
	#elif event.is_action_pressed("ui_3"):
		#set_time_of_day("evening")
	#elif event.is_action_pressed("ui_4"):
		#set_time_of_day("night")
	#elif event.is_action_pressed("ui_5"):
		#set_time_of_day("midnight")
	#
	## Flechas + Ctrl - Ajustar hora manualmente
	#elif event.is_action_pressed("ui_right") and Input.is_key_pressed(KEY_CTRL):
		#set_time(current_time + 1.0)
	#elif event.is_action_pressed("ui_left") and Input.is_key_pressed(KEY_CTRL):
		#set_time(current_time - 1.0)

# Función para obtener hora formateada
func get_formatted_time() -> String:
	var hour = int(current_time)
	var minute = int((current_time - hour) * 60)
	return "%02d:%02d" % [hour, minute]

# Función para verificar si es de día/noche
func is_daytime() -> bool:
	return current_time >= 6.0 and current_time < 18.0

func is_nighttime() -> bool:
	return not is_daytime()

# Señal para otros sistemas
#signal time_updated(hour: float, formatted_time: String)
