extends Panel
## DraggablePanel.gd
## 1. Allows a `Panel` or `PanelContainer` node be clicked and dragged
## 2. Saves last position that panels have been dragged but not off-screen

const SETTINGS_PATH = "user://settings.cfg"
const CONFIG_SECTION = "PanelPositions"

var dragging = false
var drag_start = Vector2()

func _ready():
	get_viewport().connect("size_changed", self, "_on_viewport_resized")

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				raise()
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
	
	var safe_pos = _get_clamped_position()
	
	config.set_value(CONFIG_SECTION, self.name, safe_pos)
	
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

	rect_global_position = _get_clamped_position()

func _on_viewport_resized():
	rect_global_position = _get_clamped_position()

func _get_clamped_position() -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var max_x = viewport_size.x - rect_size.x
	var max_y = viewport_size.y - rect_size.y
	
	var current_x = rect_global_position.x
	var current_y = rect_global_position.y
	
	var new_x = clamp(current_x, 0, max(0, max_x))
	var new_y = clamp(current_y, 0, max(0, max_y))
	
	return Vector2(new_x, new_y)
