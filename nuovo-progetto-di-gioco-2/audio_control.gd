extends HSlider

@export var audio_bus_name: String
var audio_bus_id

func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	await get_tree().process_frame
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var saved = config.get_value("audio", audio_bus_name, 1.0)
		set_value_no_signal(saved)  # ← non triggera _on_value_changed
		AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(saved))



func _on_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)
	# Salva automaticamente ogni volta che cambi il volume
	var config = ConfigFile.new()
	config.load("user://settings.cfg")  # carica eventuali altri settings già salvati
	config.set_value("audio", audio_bus_name, value)
	config.save("user://settings.cfg")
