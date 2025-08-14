extends Control

onready var color_picker = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/BackgroundColorPickerButton")
onready var color_rect = get_node("BackgroundColorRect")
onready var view_palette_button = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton")
onready var palette_viewer_popup = get_node("PaletteViewerPopup")


func _ready():
	color_picker.connect("color_changed", self, "_on_color_changed")
	view_palette_button.connect("pressed", self, "_on_ViewPaletteButton_pressed")

func _on_color_changed(new_color: Color):
	color_rect.color = new_color

func _on_ViewPaletteButton_pressed():
	palette_viewer_popup.populate_colors()
	palette_viewer_popup.popup_centered_minsize()