extends Control

@onready var label: Label = $Label

func _ready():
	_apply_platform_style()
	update_era()
	
	# Actualizar cada minuto por si cambia el día
	var timer := Timer.new()
	timer.wait_time = 60.0
	timer.autostart = true
	timer.timeout.connect(update_era)
	add_child(timer)

func _apply_platform_style():
	# En desktop usamos una escala mas chica para no invadir la vista.
	if OS.has_feature("mobile"):
		return
	if not label:
		return
	if label.label_settings:
		label.label_settings.font_size = 28

func update_era():
	var era_number := MaizenaMeta.get_current_era_number()
	if era_number < 1:
		label.text = "Pre-Era"
		return
	label.text = "Era: %d" % era_number
