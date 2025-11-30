extends Control

const SETTINGS_PATH = "user://settings.cfg"

func _ready():
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		var screen_pos = config.get_value("Display", "window_position", null)
		var screen_size = config.get_value("Display", "window_size", null)

		if screen_pos:
			OS.window_position = screen_pos
		else:
			OS.center_window()
			
		if screen_size:
			OS.window_size = screen_size

	elif err == ERR_FILE_NOT_FOUND:
		OS.center_window()
	
	else:
		print("Error loading window settings: ", err)
		OS.center_window()

func _on_Timer_timeout():
	get_tree().change_scene("res://scenes/editor/editor.tscn")
