extends CanvasLayer

signal eyedropper_toggled(is_on)

func _ready():
    find_node("EyedropperToggle").connect("toggled", self, "_on_EyedropperToggle_toggled")
    var viewport_size = get_viewport().size
    var panel = $Panel
    var panel_size = panel.rect_size
    panel.margin_left = (viewport_size.x - panel_size.x) / 2
    panel.margin_right = panel.margin_left + panel_size.x
    panel.margin_top = viewport_size.y - panel_size.y - 10
    panel.margin_bottom = panel.margin_top + panel_size.y

func _on_EyedropperToggle_toggled(is_on):
    emit_signal("eyedropper_toggled", is_on)

func show():
    $Panel.show()

func hide():
    $Panel.hide()

func get_properties():
    var properties = {}
    properties["size"] = find_node("Size").value
    properties["fuzz"] = find_node("Fuzz").value
    properties["outline"] = find_node("Outline").value
    properties["color_index"] = find_node("Color").text.to_int()
    properties["outline_color_index"] = find_node("OutlineColor").text.to_int()
    properties["texture_id"] = find_node("Texture").value
    properties["group"] = find_node("Group").value
    properties["size_is_additive"] = find_node("SizeAddToggle").pressed
    return properties

func set_properties(properties):
    find_node("Size").value = properties.get("size", 10)
    find_node("Fuzz").value = properties.get("fuzz", 0)
    find_node("Outline").value = properties.get("outline", -1)
    find_node("Color").text = str(properties.get("color_index", 0))
    find_node("OutlineColor").text = str(properties.get("outline_color_index", 0))
    find_node("Texture").value = properties.get("texture_id", -1)
    find_node("Group").value = properties.get("group", -1)
