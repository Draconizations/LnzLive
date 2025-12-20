extends CanvasLayer
## LineModeSettings.gd
## Manages the UI panel and logic for the Line Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel to the bottom center of the viewport
## 2. Show and hide the panel
## 3. Retrieve all current line properties (e.g., fuzz, color, thickness) set by the user

const SETTINGS_PATH = "user://settings.cfg"
var _is_loading_settings = false

func _ready():
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	_connect_settings_signals()
	load_settings()

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

	properties["apply_fuzz"] = find_node("ReplaceFuzz").pressed
	properties["apply_color"] = find_node("ReplaceColor").pressed
	properties["apply_left_outline"] = find_node("ReplaceLeftOutlineColor").pressed
	properties["apply_right_outline"] = find_node("ReplaceRightOutlineColor").pressed
	properties["apply_start_thick"] = find_node("ReplaceStartThickness").pressed
	properties["apply_end_thick"] = find_node("ReplaceEndThickness").pressed
	properties["apply_outline_type"] = find_node("ReplaceOutlineType").pressed
	properties["apply_draw_order"] = find_node("ReplaceDrawOrder").pressed
	return properties

func _connect_settings_signals():
	find_node("Fuzz").connect("value_changed", self, "_on_setting_changed")
	find_node("Color").connect("text_changed", self, "_on_setting_changed")
	find_node("LeftOutlineColor").connect("text_changed", self, "_on_setting_changed")
	find_node("RightOutlineColor").connect("text_changed", self, "_on_setting_changed")
	find_node("StartThickness").connect("value_changed", self, "_on_setting_changed")
	find_node("EndThickness").connect("value_changed", self, "_on_setting_changed")
	find_node("OutlineType").connect("value_changed", self, "_on_setting_changed")
	find_node("DrawOrder").connect("value_changed", self, "_on_setting_changed")

	find_node("ReplaceFuzz").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceColor").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceLeftOutlineColor").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceRightOutlineColor").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceStartThickness").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceEndThickness").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceOutlineType").connect("toggled", self, "_on_setting_changed")
	find_node("ReplaceDrawOrder").connect("toggled", self, "_on_setting_changed")

	var reset_btn = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _on_setting_changed(_arg = null):
	if _is_loading_settings:
		return
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("LineProperties", "fuzz", find_node("Fuzz").value)
	config.set_value("LineProperties", "color", find_node("Color").text)
	config.set_value("LineProperties", "left_outline_color", find_node("LeftOutlineColor").text)
	config.set_value("LineProperties", "right_outline_color", find_node("RightOutlineColor").text)
	config.set_value("LineProperties", "start_thickness", find_node("StartThickness").value)
	config.set_value("LineProperties", "end_thickness", find_node("EndThickness").value)
	config.set_value("LineProperties", "outline_type", find_node("OutlineType").value)
	config.set_value("LineProperties", "draw_order", find_node("DrawOrder").value)

	config.set_value("LineProperties", "replace_fuzz", find_node("ReplaceFuzz").pressed)
	config.set_value("LineProperties", "replace_color", find_node("ReplaceColor").pressed)
	config.set_value("LineProperties", "replace_left_outline_color", find_node("ReplaceLeftOutlineColor").pressed)
	config.set_value("LineProperties", "replace_right_outline_color", find_node("ReplaceRightOutlineColor").pressed)
	config.set_value("LineProperties", "replace_start_thickness", find_node("ReplaceStartThickness").pressed)
	config.set_value("LineProperties", "replace_end_thickness", find_node("ReplaceEndThickness").pressed)
	config.set_value("LineProperties", "replace_outline_type", find_node("ReplaceOutlineType").pressed)
	config.set_value("LineProperties", "replace_draw_order", find_node("ReplaceDrawOrder").pressed)

	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving LineMode settings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	find_node("Fuzz").value = config.get_value("LineProperties", "fuzz", 0)
	find_node("Color").text = config.get_value("LineProperties", "color", "-1")
	find_node("LeftOutlineColor").text = config.get_value("LineProperties", "left_outline_color", "-1")
	find_node("RightOutlineColor").text = config.get_value("LineProperties", "right_outline_color", "-1")
	find_node("StartThickness").value = config.get_value("LineProperties", "start_thickness", 100)
	find_node("EndThickness").value = config.get_value("LineProperties", "end_thickness", 100)
	find_node("OutlineType").value = config.get_value("LineProperties", "outline_type", 0)
	find_node("DrawOrder").value = config.get_value("LineProperties", "draw_order", 0)

	find_node("ReplaceFuzz").pressed = config.get_value("LineProperties", "replace_fuzz", true)
	find_node("ReplaceColor").pressed = config.get_value("LineProperties", "replace_color", true)
	find_node("ReplaceLeftOutlineColor").pressed = config.get_value("LineProperties", "replace_left_outline_color", true)
	find_node("ReplaceRightOutlineColor").pressed = config.get_value("LineProperties", "replace_right_outline_color", true)
	find_node("ReplaceStartThickness").pressed = config.get_value("LineProperties", "replace_start_thickness", true)
	find_node("ReplaceEndThickness").pressed = config.get_value("LineProperties", "replace_end_thickness", true)
	find_node("ReplaceOutlineType").pressed = config.get_value("LineProperties", "replace_outline_type", true)
	find_node("ReplaceDrawOrder").pressed = config.get_value("LineProperties", "replace_draw_order", true)

	_is_loading_settings = false

func _on_reset_defaults_pressed():
	_is_loading_settings = true

	find_node("Fuzz").value = 0
	find_node("Color").text = "-1"
	find_node("LeftOutlineColor").text = "-1"
	find_node("RightOutlineColor").text = "-1"
	find_node("StartThickness").value = 100
	find_node("EndThickness").value = 100
	find_node("OutlineType").value = 0
	find_node("DrawOrder").value = 0

	find_node("ReplaceFuzz").pressed = true
	find_node("ReplaceColor").pressed = true
	find_node("ReplaceLeftOutlineColor").pressed = true
	find_node("ReplaceRightOutlineColor").pressed = true
	find_node("ReplaceStartThickness").pressed = true
	find_node("ReplaceEndThickness").pressed = true
	find_node("ReplaceOutlineType").pressed = true
	find_node("ReplaceDrawOrder").pressed = true

	_is_loading_settings = false
	save_settings()
