extends CanvasLayer

signal apply_paintballz
signal delete_mode_toggled(is_on)

func _ready():
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("DeleteModeCheckBox").connect("toggled", self, "_on_DeleteModeCheckBox_toggled")
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	panel.margin_left = (viewport_size.x - panel_size.x) / 2
	panel.margin_right = panel.margin_left + panel_size.x
	panel.margin_top = viewport_size.y - panel_size.y - 10
	panel.margin_bottom = panel.margin_top + panel_size.y

func _on_ApplyButton_pressed():
	emit_signal("apply_paintballz")

func _on_DeleteModeCheckBox_toggled(is_on):
	emit_signal("delete_mode_toggled", is_on)

func show():
	$Panel.show()

func hide():
	$Panel.hide()

func get_properties():
	var properties = {}
	properties["diameter"] = find_node("Diameter").value
	properties["color"] = find_node("Color").text.to_int()
	properties["outline_color"] = find_node("OutlineColor").text.to_int()
	properties["outline_type"] = find_node("OutlineType").value
	properties["fuzz"] = find_node("Fuzz").value
	properties["texture"] = find_node("Texture").value
	properties["group"] = find_node("Group").value
	properties["anchored"] = find_node("Anchored").pressed
	properties["target_mode"] = find_node("Target").selected
	return properties
