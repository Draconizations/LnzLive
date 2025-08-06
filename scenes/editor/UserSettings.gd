extends Control

onready var color_picker = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/BackgroundColorPickerButton")
onready var color_rect = get_node("BackgroundColorRect")

func _ready():
	color_picker.connect("color_changed", self, "_on_color_changed")

func _on_color_changed(new_color: Color):
	color_rect.color = new_color
