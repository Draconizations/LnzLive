extends Panel

const SETTINGS_PATH = "user://settings.cfg"

signal texture_rotation_mode_changed(mode)
signal texture_rotation_input_changed(input_vec)
signal texture_affected_by_size_changed(is_affected)
signal texture_affected_by_rotation_changed(is_affected)
signal texture_use_quadrants_changed(is_using) # NEW

var _pending_mode = 1
var _pending_input_vec = Vector2.ZERO
var _pending_affected_by_size = true
var _pending_affected_by_rotation = false
var _pending_use_quadrants = false # NEW

onready var mode_option = $MarginContainer/VBoxContainer/ModeOptionButton
onready var input_x_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/InputX
onready var input_y_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/InputY
onready var size_checkbox = $MarginContainer/VBoxContainer/HBoxContainer2/SizeCheckBox
onready var rotation_checkbox = $MarginContainer/VBoxContainer/HBoxContainer2/RotationCheckBox
onready var quadrants_checkbox = $MarginContainer/VBoxContainer/HBoxContainer3/QuadrantsCheckBox # NEW

func _ready():
	mode_option.connect("item_selected", self, "_on_mode_selected")
	input_x_spinbox.connect("value_changed", self, "_on_input_changed")
	input_y_spinbox.connect("value_changed", self, "_on_input_changed")
	size_checkbox.connect("toggled", self, "_on_size_toggled")
	rotation_checkbox.connect("toggled", self, "_on_rotation_toggled")
	quadrants_checkbox.connect("toggled", self, "_on_quadrants_toggled") # NEW

	mode_option.selected = _pending_mode
	input_x_spinbox.value = _pending_input_vec.x
	input_y_spinbox.value = _pending_input_vec.y
	size_checkbox.pressed = _pending_affected_by_size
	rotation_checkbox.pressed = _pending_affected_by_rotation
	quadrants_checkbox.pressed = _pending_use_quadrants # NEW

func set_settings(
	mode: int, input_vec: Vector2, affected_by_size: bool, affected_by_rotation: bool, use_quadrants: bool = false
):
	_pending_mode = mode
	_pending_input_vec = input_vec
	_pending_affected_by_size = affected_by_size
	_pending_affected_by_rotation = affected_by_rotation
	_pending_use_quadrants = use_quadrants # NEW
	if is_inside_tree():
		mode_option.selected = mode
		input_x_spinbox.value = input_vec.x
		input_y_spinbox.value = input_vec.y
		size_checkbox.pressed = affected_by_size
		rotation_checkbox.pressed = affected_by_rotation
		quadrants_checkbox.pressed = use_quadrants # NEW

func _save_self_settings():
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("LNZOptions", "shader_texture_rotation_mode", mode_option.selected)
	config.set_value("LNZOptions", "shader_texture_rotation_input", Vector2(input_x_spinbox.value, input_y_spinbox.value))
	config.set_value("LNZOptions", "shader_texture_affected_by_size", size_checkbox.pressed)
	config.set_value("LNZOptions", "shader_texture_affected_by_rotation", rotation_checkbox.pressed)
	config.set_value("LNZOptions", "shader_texture_use_quadrants", quadrants_checkbox.pressed) # NEW
	config.save(SETTINGS_PATH)

func get_use_quadrants() -> bool:
	return quadrants_checkbox.pressed

func _on_quadrants_toggled(is_on):
	emit_signal("texture_use_quadrants_changed", is_on)
	_save_self_settings()
	
func get_mode() -> int:
	return mode_option.selected

func get_input_vec() -> Vector2:
	return Vector2(input_x_spinbox.value, input_y_spinbox.value)

func get_affected_by_size() -> bool:
	return size_checkbox.pressed

func get_affected_by_rotation() -> bool:
	return rotation_checkbox.pressed

func _on_mode_selected(index):
	emit_signal("texture_rotation_mode_changed", index)
	_save_self_settings()

func _on_input_changed(_value):
	var input_vec = Vector2(input_x_spinbox.value, input_y_spinbox.value)
	emit_signal("texture_rotation_input_changed", input_vec)
	_save_self_settings()

func _on_size_toggled(is_on):
	emit_signal("texture_affected_by_size_changed", is_on)
	_save_self_settings()

func _on_rotation_toggled(is_on):
	emit_signal("texture_affected_by_rotation_changed", is_on)
	_save_self_settings()

func _on_CloseButton_pressed():
	hide()

func popup_centered():
	var viewport_size = get_viewport_rect().size
	var panel_size = rect_size
	rect_global_position = (viewport_size - panel_size) / 2
	show()
	raise()
