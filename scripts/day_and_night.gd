extends CanvasLayer

var current_hour = Time.get_time_dict_from_system().hour

func _ready():
	if current_hour >= 8 and current_hour < 18:
		# Día
		$ColorRect.color = Color(0, 0, 0, 0)
	else:
		# Noche
		$ColorRect.color = Color(0, 0, 0, 0.4)
