extends CanvasLayer
## LineModeSettings.gd
## Manages the UI panel and logic for the Line Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel to the bottom center of the viewport
## 2. Show and hide the panel
## 3. Retrieve all current line properties (e.g., fuzz, color, thickness) set by the user

func _ready():
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	# var viewport_size = get_viewport().size
	# var panel = $Panel
	# var panel_size = panel.rect_size
	# panel.margin_left = (viewport_size.x - panel_size.x) / 2
	# panel.margin_right = panel.margin_left + panel_size.x
	# panel.margin_top = viewport_size.y - panel_size.y - 10
	# panel.margin_bottom = panel.margin_top + panel_size.y

func show():
	$Panel.show()

func hide():
	$Panel.hide()

func get_properties():
	var properties = {}
	properties["fuzz"] = find_node("Fuzz").value
	properties["color"] = find_node("Color").text.to_int()
	properties["left_outline_color"] = find_node("LeftOutlineColor").text.to_int()
	properties["right_outline_color"] = find_node("RightOutlineColor").text.to_int()
	properties["start_thickness"] = find_node("StartThickness").value
	properties["end_thickness"] = find_node("EndThickness").value
	properties["outline_type"] = find_node("OutlineType").value
	properties["draw_order"] = find_node("DrawOrder").value
	return properties
