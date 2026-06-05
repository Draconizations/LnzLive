extends WindowDialog

const SETTINGS_PATH = "user://settings.cfg"

signal texture_rotation_mode_changed(mode)
signal texture_rotation_input_changed(input_vec)
signal texture_affected_by_size_changed(is_affected)
signal texture_affected_by_rotation_changed(is_affected)
signal texture_flat_colors_changed(is_flat)

var _is_loading_settings = false

var _pending_mode = 1
var _pending_input_vec = Vector2.ZERO
var _pending_affected_by_size = true
var _pending_affected_by_rotation = false
var _pending_render_flat_colors = false

onready var mode_option = $MarginContainer/VBoxContainer/ModeOptionButton
onready var input_x_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/InputX
onready var input_y_spinbox = $MarginContainer/VBoxContainer/HBoxContainer/InputY
onready var size_checkbox = $MarginContainer/VBoxContainer/HBoxContainer2/SizeCheckBox
onready var rotation_checkbox = $MarginContainer/VBoxContainer/HBoxContainer2/RotationCheckBox
onready var flat_colors_checkbox = $MarginContainer/VBoxContainer/HBoxContainer3/FlatColorsCheckBox

func _ready():
	# Apply initial pending values before connecting signals
	mode_option.selected = _pending_mode
	input_x_spinbox.value = _pending_input_vec.x
	input_y_spinbox.value = _pending_input_vec.y
	size_checkbox.pressed = _pending_affected_by_size
	rotation_checkbox.pressed = _pending_affected_by_rotation
	flat_colors_checkbox.pressed = _pending_render_flat_colors

	mode_option.connect("item_selected", self, "_on_mode_selected")
	input_x_spinbox.connect("value_changed", self, "_on_input_changed")
	input_y_spinbox.connect("value_changed", self, "_on_input_changed")
	size_checkbox.connect("toggled", self, "_on_size_toggled")
	rotation_checkbox.connect("toggled", self, "_on_rotation_toggled")
	flat_colors_checkbox.connect("toggled", self, "_on_flat_colors_toggled")

	# Load stored values to overwrite defaults
	load_settings()

func get_render_flat_colors() -> bool:
	return flat_colors_checkbox.pressed

func _on_flat_colors_toggled(is_on):
	emit_signal("texture_flat_colors_changed", is_on)
	if not _is_loading_settings:
		save_settings()
	
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
	if not _is_loading_settings:
		save_settings()

func _on_input_changed(_value):
	var input_vec = Vector2(input_x_spinbox.value, input_y_spinbox.value)
	emit_signal("texture_rotation_input_changed", input_vec)
	if not _is_loading_settings:
		save_settings()

func _on_size_toggled(is_on):
	emit_signal("texture_affected_by_size_changed", is_on)
	if not _is_loading_settings:
		save_settings()

func _on_rotation_toggled(is_on):
	emit_signal("texture_affected_by_rotation_changed", is_on)
	if not _is_loading_settings:
		save_settings()

func _on_CloseButton_pressed():
	hide()

func popup_centered(size: Vector2 = Vector2.ZERO):
	.popup_centered(size)
	raise()

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("ShaderProperties", "mode", mode_option.selected)
	config.set_value("ShaderProperties", "input_x", input_x_spinbox.value)
	config.set_value("ShaderProperties", "input_y", input_y_spinbox.value)
	config.set_value("ShaderProperties", "affected_by_size", size_checkbox.pressed)
	config.set_value("ShaderProperties", "affected_by_rotation", rotation_checkbox.pressed)
	config.set_value("ShaderProperties", "flat_colors", flat_colors_checkbox.pressed)

	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving ShaderSettings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	mode_option.selected = config.get_value("ShaderProperties", "mode", 1)
	input_x_spinbox.value = config.get_value("ShaderProperties", "input_x", 0.0)
	input_y_spinbox.value = config.get_value("ShaderProperties", "input_y", 0.0)
	size_checkbox.pressed = config.get_value("ShaderProperties", "affected_by_size", true)
	rotation_checkbox.pressed = config.get_value("ShaderProperties", "affected_by_rotation", false)
	flat_colors_checkbox.pressed = config.get_value("ShaderProperties", "flat_colors", false)

	_is_loading_settings = false
