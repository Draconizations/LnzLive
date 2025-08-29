extends CanvasLayer

func _ready():
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	panel.margin_left = (viewport_size.x - panel_size.x) / 2
	panel.margin_right = panel.margin_left + panel_size.x
	panel.margin_top = viewport_size.y - panel_size.y - 10
	panel.margin_bottom = panel.margin_top + panel_size.y

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
