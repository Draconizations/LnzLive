extends Control
## UserSettings.gd
## Manages user-specific global settings and UI interactions
## 1. Handles changes to the 3D viewport's background color by connecting the ColorPickerButton to a background ColorRect
## 2. Triggers the display of the PaletteViewerPopup when the "View Palette" button is pressed
## 3. Calls populate_colors() on the viewer popup to ensure the current pet's palette is displayed before showing the popup

onready var color_picker = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/BackgroundColorPickerButton")
onready var color_rect = get_node("BackgroundColorRect")
onready var view_palette_button = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton")
onready var palette_viewer_popup = get_node("PaletteViewerPopup")

onready var file_tree = get_tree().get_root().get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/Tree")

func _ready():
	color_picker.connect("color_changed", self, "_on_color_changed")
	view_palette_button.connect("pressed", self, "_on_ViewPaletteButton_pressed")
	file_tree.connect("palette_selected", palette_viewer_popup, "_on_palette_selected")

func _on_color_changed(new_color: Color):
	color_rect.color = new_color

func _on_ViewPaletteButton_pressed():
	palette_viewer_popup.populate_colors()
	palette_viewer_popup.show()
