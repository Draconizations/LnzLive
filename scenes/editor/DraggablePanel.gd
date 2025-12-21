class_name DraggablePanel
extends Panel
## DraggablePanel.gd
## 1. Allows a `Panel` or `PanelContainer` node be clicked and dragged
## 2. Saves last position that panels have been dragged but not off-screen

const SETTINGS_PATH = "user://settings.cfg"
const CONFIG_SECTION = "PanelPositions"

var dragging = false
var drag_start = Vector2()
var is_docked = false

var dock_button: Button
var close_button: Button
var original_rect_size: Vector2

func _ready():
	get_viewport().connect("size_changed", self, "_on_viewport_resized")

	dock_button = Button.new()
	dock_button.text = "Undock"
	dock_button.connect("pressed", self, "_on_dock_button_pressed")
	add_child(dock_button)
	dock_button.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT)
	dock_button.margin_right = -10
	dock_button.margin_top = 5
	dock_button.margin_left = -70
	dock_button.margin_bottom = 25

	close_button = Button.new()
	close_button.text = "x"
	close_button.connect("pressed", self, "_on_close_button_pressed")
	add_child(close_button)
	close_button.set_anchors_and_margins_preset(Control.PRESET_TOP_RIGHT)
	close_button.margin_right = -5
	close_button.margin_top = 5
	close_button.margin_left = -25
	close_button.margin_bottom = 25

	update_buttons()

func _gui_input(event):
	if is_docked:
		return

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
	if is_docked:
		return

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
		if config.has_section_key(CONFIG_SECTION, self.name):
			rect_global_position = config.get_value(CONFIG_SECTION, self.name)
		else:
			rect_global_position = default_pos
	else:
		rect_global_position = default_pos

	rect_global_position = _get_clamped_position()

func _on_viewport_resized():
	if not is_docked:
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

func _on_dock_button_pressed():
	var sidebars = get_tree().get_nodes_in_group("SidebarController")
	if sidebars.size() > 0:
		var sidebar = sidebars[0]
		if is_docked:
			sidebar.undock_panel(self)
		else:
			sidebar.dock_panel(self)
	else:
		var root = get_tree().root
		var sidebar = _find_sidebar_recursive(root)
		if sidebar:
			if is_docked:
				sidebar.undock_panel(self)
			else:
				sidebar.dock_panel(self)
		else:
			print("SidebarController not found")

func _on_close_button_pressed():
	if not is_docked:
		_on_dock_button_pressed()

func _find_sidebar_recursive(node):
	if node.has_method("dock_panel"):
		return node
	for child in node.get_children():
		var res = _find_sidebar_recursive(child)
		if res:
			return res
	return null

func set_docked(docked: bool):
	if docked:
		original_rect_size = rect_size
		is_docked = true
		dragging = false
		set_anchors_and_margins_preset(Control.PRESET_WIDE)
	else:
		is_docked = false
		set_anchors_and_margins_preset(Control.PRESET_TOP_LEFT)

		if original_rect_size != Vector2.ZERO:
			rect_size = original_rect_size
		else:
			rect_size = Vector2(300, 350)

		size_flags_horizontal = SIZE_FILL
		size_flags_vertical = SIZE_FILL

		restore_position(rect_global_position)

	update_buttons()

func update_buttons():
	if is_docked:
		if dock_button:
			dock_button.text = "Undock"
			dock_button.visible = true
		if close_button:
			close_button.visible = false
	else:
		if dock_button:
			dock_button.visible = false
		if close_button:
			close_button.visible = true
