extends Control

@onready var label: Label = $Label

# Definí el martes que será la Era 1
# Formato ISO: año, mes, día
var era_start_date := {
	"year": 2023,
	"month": 12,
	"day": 02   # Asegurate que sea martes real
}

func _ready():
	update_era()
	
	# Actualizar cada minuto por si cambia el día
	var timer := Timer.new()
	timer.wait_time = 60.0
	timer.autostart = true
	timer.timeout.connect(update_era)
	add_child(timer)

func update_era():
	var now = Time.get_datetime_dict_from_system()
	
	var start_unix = Time.get_unix_time_from_datetime_dict(era_start_date)
	var now_unix = Time.get_unix_time_from_datetime_dict(now)
	
	var seconds_passed = now_unix - start_unix
	var days_passed = int(seconds_passed / 86400.0)
	
	if days_passed < 0:
		label.text = "Pre-Era"
		return
	
	var era_number = int(days_passed / 7.0) + 1
	
	label.text = "Era: %d" % era_number
