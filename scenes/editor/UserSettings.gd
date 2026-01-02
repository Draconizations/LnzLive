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
onready var file_tree = get_tree().get_root().get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")

onready var settings_dialog = get_node("UserSettingsDialog")
onready var user_settings_btn = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/UserSettingsButton")
onready var lnz_text_edit = get_node("HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")

var _cached_window_size = Vector2(1024, 600)
var _cached_window_pos = Vector2()
var preferred_delimiter = "comma_space"

var max_history_size = 25
var stretch_mode = SceneTree.STRETCH_MODE_2D
var stretch_aspect = SceneTree.STRETCH_ASPECT_EXPAND

func _ready():
	_cached_window_size = OS.window_size
	_cached_window_pos = OS.window_position
	
	shrink_spinner.connect("value_changed", self, "_on_shrink_changed")

	load_settings()
	
	color_picker.connect("color_changed", self, "_on_color_changed")

	if user_settings_btn:
		user_settings_btn.connect("pressed", self, "_on_user_settings_pressed")

	if settings_dialog:
		settings_dialog.connect("delimiter_changed", self, "_on_delimiter_changed")
		settings_dialog.connect("background_color_changed", self, "_on_color_changed")
		settings_dialog.connect("shrink_changed", self, "_on_shrink_changed")
		settings_dialog.connect("max_history_changed", self, "_on_max_history_changed")
		settings_dialog.connect("stretch_mode_changed", self, "_on_stretch_mode_changed")
		settings_dialog.connect("stretch_aspect_changed", self, "_on_stretch_aspect_changed")

func _on_user_settings_pressed():
	settings_dialog.init_settings(preferred_delimiter, color_rect.color, shrink_spinner.value, max_history_size, stretch_mode, stretch_aspect)
	settings_dialog.popup_centered()

func _on_delimiter_changed(new_delim):
	preferred_delimiter = new_delim
	save_settings()

func _on_max_history_changed(new_val):
	max_history_size = int(new_val)
	if lnz_text_edit:
		lnz_text_edit.max_history_size = max_history_size
	save_settings()

func _on_stretch_mode_changed(new_mode):
	stretch_mode = new_mode
	_apply_screen_shrink(shrink_spinner.value)
	save_settings()

func _on_stretch_aspect_changed(new_aspect):
	stretch_aspect = new_aspect
	_apply_screen_shrink(shrink_spinner.value)
	save_settings()

func get_preferred_delimiter() -> String:
	var delims = {
		"comma_space": ", ",
		"comma": ",",
		"comma_tab": ",\t",
		"tab": "\t",
		"space": " "
	}
	return delims.get(preferred_delimiter, "auto")

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
	config.set_value("Display", "stretch_mode", stretch_mode)
	config.set_value("Display", "stretch_aspect", stretch_aspect)
	
	config.set_value("LNZOptions", "preferred_delimiter", preferred_delimiter)
	config.set_value("LNZOptions", "max_history_size", max_history_size)
	
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
		
		stretch_mode = config.get_value("Display", "stretch_mode", SceneTree.STRETCH_MODE_2D)
		stretch_aspect = config.get_value("Display", "stretch_aspect", SceneTree.STRETCH_ASPECT_EXPAND)
		
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

		preferred_delimiter = config.get_value("LNZOptions", "preferred_delimiter", "auto-detect")
		max_history_size = config.get_value("LNZOptions", "max_history_size", 50)
		if lnz_text_edit:
			lnz_text_edit.max_history_size = max_history_size

	else:
		OS.center_window()
		color_rect.color = default_color
		color_picker.color = default_color
		if lnz_text_edit:
			lnz_text_edit.max_history_size = 50

func _on_color_changed(new_color: Color):
	color_rect.color = new_color
	if color_picker.color != new_color:
		color_picker.color = new_color
	save_settings()

func _on_shrink_changed(value):
	_apply_screen_shrink(value)
	if shrink_spinner.value != value:
		shrink_spinner.value = value
	save_settings()

func _apply_screen_shrink(shrink_value):
	var base_size = Vector2(ProjectSettings.get_setting("display/window/size/width"), ProjectSettings.get_setting("display/window/size/height"))
	
	get_tree().set_screen_stretch(
		stretch_mode, 
		stretch_aspect, 
		base_size, 
		shrink_value
	)
