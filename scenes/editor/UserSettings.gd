extends Control
## UserSettings.gd
## Manages user-specific global settings and UI interactions
## 1. Handles changes to the 3D viewport's background color by connecting the ColorPickerButton to a background ColorRect
## 2. Calls populate_colors() on the viewer popup to ensure the current pet's palette is displayed before showing the popup
## 3. Saves user settings in config file

const SETTINGS_PATH = "user://settings.cfg"

onready var color_picker = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/BackgroundColorPickerButton")
onready var color_rect = get_node("BackgroundColorRect")
onready var view_palette_button = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton")
onready var shrink_spinner = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ShrinkSpinBox")
onready var file_tree = get_tree().get_root().get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/Tree")
var _cached_window_size = Vector2(1024, 600)
var _cached_window_pos = Vector2()

func _ready():
	_cached_window_size = OS.window_size
	_cached_window_pos = OS.window_position
	
	shrink_spinner.connect("value_changed", self, "_on_shrink_changed")

	load_settings()
	
	color_picker.connect("color_changed", self, "_on_color_changed")

func _process(_delta):
	if not OS.window_fullscreen and not OS.window_maximized:
		_cached_window_size = OS.window_size
		_cached_window_pos = OS.window_position

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_settings()

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)

	config.set_value("Display", "fullscreen", OS.window_fullscreen)
	config.set_value("Display", "maximized", OS.window_maximized)
	config.set_value("Display", "window_size", _cached_window_size)
	config.set_value("Display", "window_position", _cached_window_pos)
	config.set_value("Display", "background_color", color_rect.color)
	config.set_value("Display", "shrink", shrink_spinner.value)
	
	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving window settings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	var default_color = Color( 0.168627, 0.45098, 0.45098, 1 )
	
	if err == OK:
		var bg_color = config.get_value("Display", "background_color", default_color)
		color_rect.color = bg_color
		color_picker.color = bg_color

		var saved_shrink = config.get_value("Display", "shrink", 1)
		shrink_spinner.value = saved_shrink
		_apply_screen_shrink(saved_shrink)

		var saved_size = config.get_value("Display", "window_size", null)
		var saved_pos = config.get_value("Display", "window_position", null)
		
		if saved_size:
			OS.window_size = saved_size
			_cached_window_size = saved_size
		
		if saved_pos:
			OS.window_position = saved_pos
			_cached_window_pos = saved_pos
		else:
			OS.center_window()

		var is_maximized = config.get_value("Display", "maximized", false)
		var is_fullscreen = config.get_value("Display", "fullscreen", false)
		
		if is_fullscreen:
			OS.window_fullscreen = true
		elif is_maximized:
			OS.window_maximized = true

	else:
		OS.center_window()
		color_rect.color = default_color
		color_picker.color = default_color

func _on_color_changed(new_color: Color):
	color_rect.color = new_color

func _on_shrink_changed(value):
	_apply_screen_shrink(value)

func _apply_screen_shrink(shrink_value):
	var base_size = Vector2(ProjectSettings.get_setting("display/window/size/width"), ProjectSettings.get_setting("display/window/size/height"))
	
	get_tree().set_screen_stretch(
		SceneTree.STRETCH_MODE_2D, 
		SceneTree.STRETCH_ASPECT_EXPAND, 
		base_size, 
		shrink_value
	)
