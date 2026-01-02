extends WindowDialog

signal delimiter_changed(new_delimiter_name)
signal background_color_changed(new_color)
signal shrink_changed(new_value)
signal stretch_mode_changed(new_mode)
signal stretch_aspect_changed(new_aspect)
signal max_history_changed(new_val)

onready var delimiter_option = $VBoxContainer/DelimiterHBox/OptionButton
onready var bg_color_picker = $VBoxContainer/BgColorHBox/ColorPickerButton
onready var shrink_spinbox = $VBoxContainer/ShrinkHBox/SpinBox
onready var max_history_spinbox = $VBoxContainer/MaxHistoryHBox/SpinBox
onready var stretch_mode_option = $VBoxContainer/StretchModeHBox/OptionButton
onready var stretch_aspect_option = $VBoxContainer/StretchAspectHBox/OptionButton

var delimiter_map = {
	0: "comma_space",
	1: "comma",
	2: "comma_tab",
	3: "tab",
	4: "space",
	5: "auto-detect"
}

var reverse_delimiter_map = {
	"comma_space": 0,
	"comma": 1,
	"comma_tab": 2,
	"tab": 3,
	"space": 4,
	"auto-detect": 5
}

func _ready():
	_setup_options()

	delimiter_option.connect("item_selected", self, "_on_delimiter_selected")
	bg_color_picker.connect("color_changed", self, "_on_bg_color_changed")
	shrink_spinbox.connect("value_changed", self, "_on_shrink_changed")
	max_history_spinbox.connect("value_changed", self, "_on_max_history_changed")
	stretch_mode_option.connect("item_selected", self, "_on_stretch_mode_selected")
	stretch_aspect_option.connect("item_selected", self, "_on_stretch_aspect_selected")

func _setup_options():
	delimiter_option.clear()

	delimiter_option.add_item("comma-space (X, Y)", 0)
	delimiter_option.set_item_disabled(0, false)

	delimiter_option.add_item("comma (X,Y)", 1)
	delimiter_option.set_item_disabled(1, false)

	delimiter_option.add_item("comma-tab (X, Y)", 2)
	delimiter_option.set_item_disabled(2, false)

	delimiter_option.add_item("tab (X	Y)", 3)
	delimiter_option.set_item_disabled(3, false)

	delimiter_option.add_item("space (X Y)", 4)
	delimiter_option.set_item_disabled(4, false)

	delimiter_option.add_item("auto-detect", 5)
	delimiter_option.set_item_disabled(5, false)

	stretch_mode_option.add_item("Disabled", SceneTree.STRETCH_MODE_DISABLED)
	stretch_mode_option.add_item("2D", SceneTree.STRETCH_MODE_2D)
	stretch_mode_option.add_item("Viewport", SceneTree.STRETCH_MODE_VIEWPORT)

	stretch_aspect_option.add_item("Ignore", SceneTree.STRETCH_ASPECT_IGNORE)
	stretch_aspect_option.add_item("Keep", SceneTree.STRETCH_ASPECT_KEEP)
	stretch_aspect_option.add_item("Keep Width", SceneTree.STRETCH_ASPECT_KEEP_WIDTH)
	stretch_aspect_option.add_item("Keep Height", SceneTree.STRETCH_ASPECT_KEEP_HEIGHT)
	stretch_aspect_option.add_item("Expand", SceneTree.STRETCH_ASPECT_EXPAND)

func init_settings(current_delim_name, current_bg_color, current_shrink, current_max_history, current_stretch_mode, current_stretch_aspect):
	var delim_idx = reverse_delimiter_map.get(current_delim_name, 5)

	if delimiter_option.is_item_disabled(delim_idx):
		delim_idx = 5
		emit_signal("delimiter_changed", "auto-detect")
	
	delimiter_option.selected = delim_idx

	bg_color_picker.color = current_bg_color
	shrink_spinbox.value = current_shrink
	max_history_spinbox.value = current_max_history

	_select_option_by_id(stretch_mode_option, current_stretch_mode)
	_select_option_by_id(stretch_aspect_option, current_stretch_aspect)

func _select_option_by_id(opt_btn: OptionButton, id: int):
	for i in range(opt_btn.get_item_count()):
		if opt_btn.get_item_id(i) == id:
			opt_btn.select(i)
			return
	if opt_btn.get_item_count() > 0:
		opt_btn.select(0)

func _on_delimiter_selected(index):
	emit_signal("delimiter_changed", delimiter_map[index])

func _on_bg_color_changed(color):
	emit_signal("background_color_changed", color)

func _on_shrink_changed(value):
	emit_signal("shrink_changed", value)

func _on_max_history_changed(value):
	emit_signal("max_history_changed", value)

func _on_stretch_mode_selected(index):
	emit_signal("stretch_mode_changed", stretch_mode_option.get_item_id(index))

func _on_stretch_aspect_selected(index):
	emit_signal("stretch_aspect_changed", stretch_aspect_option.get_item_id(index))
