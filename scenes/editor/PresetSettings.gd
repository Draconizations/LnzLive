extends CanvasLayer

signal eyedropper_toggled(is_on)

onready var paintballz_text_edit = find_node("PaintballzTextEdit")
onready var set_paintballz_button = find_node("SetPaintballzButton")
onready var paintballz_tree = find_node("PaintballzTree")
onready var roll_spinbox = find_node("RollSpinBox")
onready var pitch_spinbox = find_node("PitchSpinBox")
onready var yaw_spinbox = find_node("YawSpinBox")
onready var button_reset_timer = find_node("ButtonResetTimer")

const PaintBallData = preload("res://data_classes/paintball_data.gd")
var r = RegEx.new()
var original_button_texts = {}

func _ready():
	r.compile("[-.\\d]+")
	find_node("EyedropperToggle").connect("toggled", self, "_on_EyedropperToggle_toggled")
	set_paintballz_button.connect("pressed", self, "_on_SetPaintballzButton_pressed")
	find_node("RotateTopButton").connect("pressed", self, "_on_RotateTopButton_pressed")
	find_node("RotateBottomButton").connect("pressed", self, "_on_RotateBottomButton_pressed")
	find_node("RotateFrontButton").connect("pressed", self, "_on_RotateFrontButton_pressed")
	find_node("RotateBackButton").connect("pressed", self, "_on_RotateBackButton_pressed")
	find_node("RotateLeftButton").connect("pressed", self, "_on_RotateLeftButton_pressed")
	find_node("RotateRightButton").connect("pressed", self, "_on_RotateRightButton_pressed")
	find_node("CustomRotateButton").connect("pressed", self, "_on_CustomRotateButton_pressed")
	button_reset_timer.connect("timeout", self, "_on_ButtonResetTimer_timeout")

	original_button_texts = {
		"top": find_node("RotateTopButton").text,
		"bottom": find_node("RotateBottomButton").text,
		"front": find_node("RotateFrontButton").text,
		"back": find_node("RotateBackButton").text,
		"left": find_node("RotateLeftButton").text,
		"right": find_node("RotateRightButton").text
	}

	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	panel.margin_left = (viewport_size.x - panel_size.x) / 2
	panel.margin_right = panel.margin_left + panel_size.x
	panel.margin_top = viewport_size.y - panel_size.y - 10
	panel.margin_bottom = panel.margin_top + panel_size.y

	paintballz_tree.columns = 11
	paintballz_tree.set_column_titles_visible(true)
	paintballz_tree.set_column_title(0, "Base")
	paintballz_tree.set_column_title(1, "Size")
	paintballz_tree.set_column_title(2, "Pos X")
	paintballz_tree.set_column_title(3, "Pos Y")
	paintballz_tree.set_column_title(4, "Pos Z")
	paintballz_tree.set_column_title(5, "Color")
	paintballz_tree.set_column_title(6, "Outline Color")
	paintballz_tree.set_column_title(7, "Fuzz")
	paintballz_tree.set_column_title(8, "Outline")
	paintballz_tree.set_column_title(9, "Texture")
	paintballz_tree.set_column_title(10, "Anchored")

func _on_EyedropperToggle_toggled(is_on):
    emit_signal("eyedropper_toggled", is_on)

func show():
    $Panel.show()

func hide():
    $Panel.hide()

func _on_SetPaintballzButton_pressed():
	var text = paintballz_text_edit.text
	var lines = text.split("\n")
	paintballz_tree.clear()
	var root = paintballz_tree.create_item()
	for line in lines:
		if line.empty() or line.begins_with(";") or line.begins_with("#") or line.begins_with("["):
			continue
		var parsed = r.search_all(line)
		if parsed.size() < 11:
			continue

		var item = paintballz_tree.create_item(root)
		item.set_text(0, parsed[0].get_string())
		item.set_text(1, parsed[1].get_string())
		item.set_text(2, parsed[2].get_string())
		item.set_text(3, parsed[3].get_string())
		item.set_text(4, parsed[4].get_string())
		item.set_text(5, parsed[5].get_string())
		item.set_text(6, parsed[6].get_string())
		item.set_text(7, parsed[7].get_string())
		item.set_text(8, parsed[8].get_string())
		item.set_text(9, parsed[10].get_string()) # there is a gap in the lnz format
		if parsed.size() > 11:
			item.set_text(10, parsed[11].get_string())
		else:
			item.set_text(10, "0")

func get_properties():
	var properties = {}
	properties["size"] = find_node("Size").value
	properties["fuzz"] = find_node("Fuzz").value
	properties["outline"] = find_node("Outline").value
	properties["color_index"] = find_node("Color").text.to_int()
	properties["outline_color_index"] = find_node("OutlineColor").text.to_int()
	properties["texture_id"] = find_node("Texture").value
	properties["group"] = find_node("Group").value
	properties["size_is_additive"] = find_node("SizeAddToggle").pressed
	properties["apply_ballz"] = find_node("ApplyBallzPresetToggle").pressed
	properties["apply_paintballz"] = find_node("ApplyPaintballzPresetToggle").pressed

	var paintballz = []
	var root = paintballz_tree.get_root()
	if root:
		var item = root.get_children()
		while item:
			var paintball_data = {
				"base": item.get_text(0).to_int(),
				"size": item.get_text(1).to_int(),
				"position": Vector3(item.get_text(2).to_float(), item.get_text(3).to_float(), item.get_text(4).to_float()),
				"color_index": item.get_text(5).to_int(),
				"outline_color_index": item.get_text(6).to_int(),
				"fuzz": item.get_text(7).to_int(),
				"outline": item.get_text(8).to_int(),
				"texture_id": item.get_text(9).to_int(),
				"anchored": item.get_text(10).to_int()
			}
			paintballz.append(paintball_data)
			item = item.get_next()
	properties["paintballz"] = paintballz

	return properties

func set_properties(properties):
	find_node("Size").value = properties.get("size", 10)
	find_node("Fuzz").value = properties.get("fuzz", 0)
	find_node("Outline").value = properties.get("outline", -1)
	find_node("Color").text = str(properties.get("color_index", 0))
	find_node("OutlineColor").text = str(properties.get("outline_color_index", 0))
	find_node("Texture").value = properties.get("texture_id", -1)
	find_node("Group").value = properties.get("group", -1)

	paintballz_tree.clear()
	if properties.has("paintballz"):
		var paintballz = properties.paintballz
		var root = paintballz_tree.create_item()
		for p_data in paintballz:
			var item = paintballz_tree.create_item(root)
			item.set_text(0, str(p_data.base))
			item.set_text(1, str(p_data.size))
			var pos = p_data.position
			item.set_text(2, str(pos.x))
			item.set_text(3, str(pos.y))
			item.set_text(4, str(pos.z))
			item.set_text(5, str(p_data.color_index))
			item.set_text(6, str(p_data.outline_color_index))
			item.set_text(7, str(p_data.fuzz))
			item.set_text(8, str(p_data.outline))
			item.set_text(9, str(p_data.texture_id))
			item.set_text(10, str(p_data.anchored))

func _on_RotateTopButton_pressed():
	_rotate_paintballz("top")

func _on_RotateBottomButton_pressed():
	_rotate_paintballz("bottom")

func _on_RotateFrontButton_pressed():
	_rotate_paintballz("front")

func _on_RotateBackButton_pressed():
	_rotate_paintballz("back")

func _on_RotateLeftButton_pressed():
	_rotate_paintballz("left")

func _on_RotateRightButton_pressed():
	_rotate_paintballz("right")

func _on_CustomRotateButton_pressed():
	var roll = deg2rad(roll_spinbox.value)
	var pitch = deg2rad(pitch_spinbox.value)
	var yaw = deg2rad(yaw_spinbox.value)
	_perform_rotation(roll, pitch, yaw)

func _rotate_paintballz(view_name):
	var yaw = 0.0
	var pitch = 0.0
	var roll = 0.0
	var button = null
	var text = ""

	match view_name:
		"front":
			pitch = PI
			button = find_node("RotateFrontButton")
			text = "P+180"
		"back":
			button = find_node("RotateBackButton")
			text = "No change"
		"top":
			roll = -PI / 2
			pitch = PI
			button = find_node("RotateTopButton")
			text = "R-90, P+180"
		"bottom":
			roll = PI / 2
			pitch = PI
			button = find_node("RotateBottomButton")
			text = "R+90, P+180"
		"left":
			pitch = PI / 2
			button = find_node("RotateLeftButton")
			text = "P+90"
		"right":
			pitch = -PI / 2
			button = find_node("RotateRightButton")
			text = "P-90"

	if button:
		button.text = text
		button_reset_timer.start()

	_perform_rotation(roll, pitch, yaw)

func _perform_rotation(roll, pitch, yaw):
	var basis_yaw = Basis(Vector3.FORWARD, yaw)
	var basis_pitch = Basis(Vector3.UP, pitch)
	var basis_roll = Basis(Vector3.RIGHT, roll)

	var final_basis = basis_roll * basis_pitch * basis_yaw

	var root = paintballz_tree.get_root()
	if not root:
		return

	var item = root.get_children()
	while item:
		var pos = Vector3(item.get_text(2).to_float(), item.get_text(3).to_float(), item.get_text(4).to_float())
		var new_pos = final_basis.xform(pos)
		item.set_text(2, str(new_pos.x))
		item.set_text(3, str(new_pos.y))
		item.set_text(4, str(new_pos.z))
		item = item.get_next()

func _on_ButtonResetTimer_timeout():
	for key in original_button_texts:
		var button_name = "Rotate" + key.capitalize() + "Button"
		find_node(button_name).text = original_button_texts[key]
