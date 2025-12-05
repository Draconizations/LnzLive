extends Panel
## DraggablePanel.gd
## Attach script to a `Panel` or `PanelContainer` node to allow the user
## to click and drag it around the screen

const SETTINGS_PATH = "user://settings.cfg"
const CONFIG_SECTION = "PanelPositions"

var dragging = false
var drag_start = Vector2()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = get_global_mouse_position() - rect_global_position
			else:
				dragging = false
				save_position()
				
	elif event is InputEventMouseMotion and dragging:
		rect_global_position = get_global_mouse_position() - drag_start

func save_position():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		
	config.set_value(CONFIG_SECTION, self.name, rect_global_position)
	
	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving panel position: ", save_err)

func restore_position(default_pos: Vector2):
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		var saved_pos = config.get_value(CONFIG_SECTION, self.name, null)
		if saved_pos:
			rect_global_position = saved_pos
		else:
			rect_global_position = default_pos
	else:
		rect_global_position = default_pos