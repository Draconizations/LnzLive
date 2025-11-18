extends Control
## UserSettings.gd
## Manages user-specific global settings and UI interactions
## 1. Handles changes to the 3D viewport's background color by connecting the ColorPickerButton to a background ColorRect
## 2. Triggers the display of the PaletteViewerPopup when the "View Palette" button is pressed
## 3. Calls populate_colors() on the viewer popup to ensure the current pet's palette is displayed before showing the popup
## 4. Saves user settings in config file

const SETTINGS_PATH = "user://settings.cfg"

onready var color_picker = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/BackgroundColorPickerButton")
onready var color_rect = get_node("BackgroundColorRect")
onready var view_palette_button = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton")
onready var palette_viewer_popup = get_node("PaletteViewerPopup")

onready var file_tree = get_tree().get_root().get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/Tree")

func _ready():
	load_settings()
	
	color_picker.connect("color_changed", self, "_on_color_changed")
	view_palette_button.connect("pressed", self, "_on_ViewPaletteButton_pressed")
	file_tree.connect("palette_selected", palette_viewer_popup, "_on_palette_selected")

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_settings()

func save_settings():
	var config = ConfigFile.new()

	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)

	config.set_value("Display", "window_position", OS.window_position)
	config.set_value("Display", "window_size", OS.window_size)
	config.set_value("Display", "background_color", color_rect.color) # ADDED
	
	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving window settings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	var default_color = Color( 0.168627, 0.45098, 0.45098, 1 )
	
	if err == OK:
		var screen_pos = config.get_value("Display", "window_position", null)
		var screen_size = config.get_value("Display", "window_size", null)
		var bg_color = config.get_value("Display", "background_color", default_color) # MODIFIED
		
		if screen_pos:
			OS.window_position = screen_pos
		else:
			OS.center_window()
			
		if screen_size:
			OS.window_size = screen_size
		
		color_rect.color = bg_color
		color_picker.color = bg_color

	elif err == ERR_FILE_NOT_FOUND:
		OS.center_window()
		# --- ADDED ---
		color_rect.color = default_color
		color_picker.color = default_color
	
	else:
		print("Error loading window settings: ", err)
		OS.center_window() 
		color_rect.color = default_color
		color_picker.color = default_color

func _on_color_changed(new_color: Color):
	color_rect.color = new_color

func _on_ViewPaletteButton_pressed():
	palette_viewer_popup.populate_colors()
	palette_viewer_popup.show()
