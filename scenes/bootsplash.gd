extends Control

const SETTINGS_PATH = "user://settings.cfg"

func _ready():
	print("Booting up LnzLive... debug mode is enabled, and messages will appear here, usually in the following format:")
	print("- [STATUS]: nothing wrong! just informational messages")
	print("- [WARNING]: non-critical issue, should still work but may cause other issues")
	print("- [ERROR]: critical failure, might cause crash")
	print("Please copy and share these messages if you run into any issues running LnzLive!")
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
