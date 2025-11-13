extends CanvasLayer
## PresetSettings.gd
## Manages the UI panel and logic for the Preset Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel, connect all UI signals, and set up the paintball list (Tree)
## 2. Retrieve and set the full set of preset properties for the ball and its paintballz
## 3. Parse raw text input into structured paintball data for the list
## 4. Handle advanced list transformations (mirroring and custom/preset rotation)
## 5. Emit the `eyedropper_toggled(is_on)` signal to activate the sampling tool

signal eyedropper_toggled(is_on)

onready var paintballz_text_edit = find_node("PaintballzTextEdit")
onready var set_paintballz_button = find_node("SetPaintballzButton")
onready var paintballz_tree = find_node("PaintballzTree")
onready var roll_spinbox = find_node("RollSpinBox")
onready var pitch_spinbox = find_node("PitchSpinBox")
onready var yaw_spinbox = find_node("YawSpinBox")

const PaintBallData = preload("res://data_classes/paintball_data.gd")

func _ready():
	find_node("EyedropperToggle").connect("toggled", self, "_on_EyedropperToggle_toggled")
	set_paintballz_button.connect("pressed", self, "_on_SetPaintballzButton_pressed")

	# Mirror buttons
	find_node("MirrorXButton").connect("pressed", self, "_on_MirrorXButton_pressed")
	find_node("MirrorYButton").connect("pressed", self, "_on_MirrorYButton_pressed")
	find_node("MirrorZButton").connect("pressed", self, "_on_MirrorZButton_pressed")

	# Preset rotation buttons
	var axes = ["Roll", "Pitch", "Yaw"]
	var angles = [-180, -120, -60, -30, 30, 60, 120, 180]
	for axis in axes:
		for angle in angles:
			var angle_sign
			if angle > 0:
				angle_sign = "P"
			else:
				angle_sign = "M"
			var button_name = "Button" + axis + angle_sign + str(abs(angle))
			var button = find_node(button_name)
			button.connect("pressed", self, "_on_preset_rotation_pressed", [axis.to_lower(), angle])

	find_node("CustomRotateButton").connect("pressed", self, "_on_CustomRotateButton_pressed")

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

func _split_and_clean_paintball(line: String) -> Array:
	var line_parts = line.split(";", false, 1)
	var data_part = line_parts[0].strip_edges()

	var delimiters = [", ", ",", "\t", " "]
	for delim in delimiters:
		var parts = data_part.split(delim, false)
		if parts.size() >= 11:
			var cleaned_parts = []
			for part in parts:
				cleaned_parts.append(part.strip_edges())
			return cleaned_parts
	return []

func _on_SetPaintballzButton_pressed():
	var text = paintballz_text_edit.text
	var lines = text.split("\n")
	paintballz_tree.clear()
	var root = paintballz_tree.create_item()
	for line in lines:
		if line.empty() or line.begins_with(";") or line.begins_with("#") or line.begins_with("["):
			continue

		var parts = _split_and_clean_paintball(line)
		if parts.empty():
			printerr("Could not parse paintball preset line: ", line)
			continue

		var item = paintballz_tree.create_item(root)
		item.set_text(0, parts[0]) # Base
		item.set_text(1, parts[1]) # Size
		item.set_text(2, parts[2]) # Pos X
		item.set_text(3, parts[3]) # Pos Y
		item.set_text(4, parts[4]) # Pos Z
		item.set_text(5, parts[5]) # Color
		item.set_text(6, parts[6]) # Outline Color
		item.set_text(7, parts[7]) # Fuzz
		item.set_text(8, parts[8]) # Outline
		item.set_text(9, parts[10]) # Texture (skip group at index 9)

		if parts.size() > 11:
			item.set_text(10, parts[11]) # Anchored
		else:
			item.set_text(10, "0")

const SizeMode = {
	SET = 0,
	SUM = 1,
	TRUE = 2
}

func get_properties():
	var properties = {}
	properties["size"] = int(round(find_node("Size").value))
	properties["fuzz"] = find_node("Fuzz").value
	properties["outline"] = find_node("Outline").value
	properties["color_index"] = find_node("Color").text.to_int()
	properties["outline_color_index"] = find_node("OutlineColor").text.to_int()
	properties["texture_id"] = find_node("Texture").value
	properties["group"] = find_node("Group").value
	if find_node("SizeSetToggle").pressed:
		properties["size_mode"] = SizeMode.SET
	elif find_node("SizeSumToggle").pressed:
		properties["size_mode"] = SizeMode.SUM
	else:
		properties["size_mode"] = SizeMode.TRUE
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

	var size_mode = properties.get("size_mode", SizeMode.TRUE)
	find_node("SizeSetToggle").pressed = size_mode == SizeMode.SET
	find_node("SizeSumToggle").pressed = size_mode == SizeMode.SUM
	find_node("SizeTrueToggle").pressed = size_mode == SizeMode.TRUE

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

func _on_MirrorXButton_pressed():
	_mirror_paintballz("x")

func _on_MirrorYButton_pressed():
	_mirror_paintballz("y")

func _on_MirrorZButton_pressed():
	_mirror_paintballz("z")

func _mirror_paintballz(axis):
	var root = paintballz_tree.get_root()
	if not root:
		return

	var item = root.get_children()
	while item:
		var pos = Vector3(item.get_text(2).to_float(), item.get_text(3).to_float(), item.get_text(4).to_float())
		if axis == "x":
			pos.x = -pos.x
		elif axis == "y":
			pos.y = -pos.y
		elif axis == "z":
			pos.z = -pos.z

		item.set_text(2, str(pos.x))
		item.set_text(3, str(pos.y))
		item.set_text(4, str(pos.z))
		item = item.get_next()

func _on_preset_rotation_pressed(axis, angle_degrees):
	var roll = 0.0
	var pitch = 0.0
	var yaw = 0.0
	var angle_rad = deg2rad(angle_degrees)

	if axis == "roll":
		roll = angle_rad
	elif axis == "pitch":
		pitch = angle_rad
	elif axis == "yaw":
		yaw = angle_rad

	_perform_rotation(roll, pitch, yaw)

func _on_CustomRotateButton_pressed():
	var roll = deg2rad(roll_spinbox.value)
	var pitch = deg2rad(pitch_spinbox.value)
	var yaw = deg2rad(yaw_spinbox.value)
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
