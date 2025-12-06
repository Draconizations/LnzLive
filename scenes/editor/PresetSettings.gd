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

onready var panel = $Panel
onready var scroll_vbox = $Panel/VBoxContainer/ScrollContainer/VBoxContainer
onready var paintballz_text_edit = scroll_vbox.get_node("RawLnzContainer/PaintballzTextEdit")
onready var set_paintballz_button = scroll_vbox.get_node("RawLnzContainer/SetPaintballzButton")
onready var show_raw_button = scroll_vbox.get_node("ShowRawButton")
onready var raw_lnz_container = scroll_vbox.get_node("RawLnzContainer")
onready var paintballz_tree = scroll_vbox.get_node("PaintballzTree")

onready var preview_viewport = scroll_vbox.get_node("PreviewContainer/Viewport")
onready var preview_camera = scroll_vbox.get_node("PreviewContainer/Viewport/PreviewWorld/Camera")
onready var preview_world = scroll_vbox.get_node("PreviewContainer/Viewport/PreviewWorld")

var ball_scene = preload("res://Ball.tscn")
var paintball_scene = preload("res://Paintball.tscn")
var default_palette = preload("res://resources/palettes/petz_palette.png")
var active_palette = default_palette
onready var preloader = get_tree().root.get_node("Root/ResourcePreloader")
var ball_texture_list = []

onready var eyedropper_toggle = scroll_vbox.get_node("ToolsContainer/EyedropperToggle")
onready var include_paintballz_chk = scroll_vbox.get_node("IncludeContainer/IncludePaintballzCheckBox")
onready var scale_paintballz_chk = scroll_vbox.get_node("IncludeContainer/ScalePaintballzCheckBox")

onready var base_properties_grid = scroll_vbox.get_node("BasePropertiesGrid")
onready var include_size_chk = base_properties_grid.get_node("IncludeSizeCheckBox")
onready var include_color_chk = base_properties_grid.get_node("IncludeColorCheckBox")
onready var include_outline_color_chk = base_properties_grid.get_node("IncludeOutlineColorCheckBox")
onready var include_outline_chk = base_properties_grid.get_node("IncludeOutlineCheckBox")
onready var include_fuzz_chk = base_properties_grid.get_node("IncludeFuzzCheckBox")
onready var include_texture_chk = base_properties_grid.get_node("IncludeTextureCheckBox")

onready var size_spinbox = base_properties_grid.get_node("SizeContainer/SizeSpinBox")
onready var size_mode_option = base_properties_grid.get_node("SizeContainer/SizeModeOption")

onready var color_edit = base_properties_grid.get_node("ColorLineEdit")
onready var outline_color_edit = base_properties_grid.get_node("OutlineColorLineEdit")
onready var outline_spinbox = base_properties_grid.get_node("OutlineSpinBox")
onready var fuzz_spinbox = base_properties_grid.get_node("FuzzSpinBox")
onready var texture_spinbox = base_properties_grid.get_node("TextureSpinBox")

onready var roll_spinbox = scroll_vbox.get_node("CustomRotationContainer/RollSpinBox")
onready var pitch_spinbox = scroll_vbox.get_node("CustomRotationContainer/PitchSpinBox")
onready var yaw_spinbox = scroll_vbox.get_node("CustomRotationContainer/YawSpinBox")

onready var size_scale_spin = scroll_vbox.get_node("ScaleSettingsGrid/SizeScaleSpinBox")
onready var pos_scale_spin = scroll_vbox.get_node("ScaleSettingsGrid/PosScaleSpinBox")
onready var link_scale_chk = scroll_vbox.get_node("ScaleSettingsGrid/LinkScaleCheckBox")

onready var mirror_x_btn = scroll_vbox.get_node("MirrorGrid/MirrorXButton")
onready var mirror_y_btn = scroll_vbox.get_node("MirrorGrid/MirrorYButton")
onready var mirror_z_btn = scroll_vbox.get_node("MirrorGrid/MirrorZButton")

var _base_paintballz_data = []
var _ignore_ui_changes = false
var source_ball_reference_size = 10

const SizeMode = {
	SET = 0,
	SUM = 1,
	TRUE = 2
}

func _ready():
	eyedropper_toggle.connect("toggled", self, "_on_EyedropperToggle_toggled")

	set_paintballz_button.connect("pressed", self, "_on_SetPaintballzButton_pressed")
	show_raw_button.connect("pressed", self, "_on_ShowRawButton_pressed")

	mirror_x_btn.connect("pressed", self, "_on_MirrorButton_pressed", ["x"])
	mirror_y_btn.connect("pressed", self, "_on_MirrorButton_pressed", ["y"])
	mirror_z_btn.connect("pressed", self, "_on_MirrorButton_pressed", ["z"])

	size_spinbox.connect("value_changed", self, "_on_property_changed")
	size_mode_option.connect("item_selected", self, "_on_property_changed")
	color_edit.connect("text_changed", self, "_on_property_changed")
	outline_color_edit.connect("text_changed", self, "_on_property_changed")
	outline_spinbox.connect("value_changed", self, "_on_property_changed")
	fuzz_spinbox.connect("value_changed", self, "_on_property_changed")
	texture_spinbox.connect("value_changed", self, "_on_property_changed")

	include_size_chk.connect("toggled", self, "_on_property_changed")
	include_color_chk.connect("toggled", self, "_on_property_changed")
	include_outline_color_chk.connect("toggled", self, "_on_property_changed")
	include_outline_chk.connect("toggled", self, "_on_property_changed")
	include_fuzz_chk.connect("toggled", self, "_on_property_changed")
	include_texture_chk.connect("toggled", self, "_on_property_changed")

	roll_spinbox.connect("value_changed", self, "_on_rotation_changed")
	pitch_spinbox.connect("value_changed", self, "_on_rotation_changed")
	yaw_spinbox.connect("value_changed", self, "_on_rotation_changed")

	size_scale_spin.connect("value_changed", self, "_on_scale_changed", [true])
	pos_scale_spin.connect("value_changed", self, "_on_scale_changed", [false])
	link_scale_chk.connect("toggled", self, "_on_property_changed") 

	paintballz_tree.columns = 11
	paintballz_tree.set_column_titles_visible(true)
	paintballz_tree.set_column_title(0, "Ball")
	paintballz_tree.set_column_title(1, "Dia")
	paintballz_tree.set_column_title(2, "X")
	paintballz_tree.set_column_title(3, "Y")
	paintballz_tree.set_column_title(4, "Z")
	paintballz_tree.set_column_title(5, "Col")
	paintballz_tree.set_column_title(6, "OutCol")
	paintballz_tree.set_column_title(7, "Fuzz")
	paintballz_tree.set_column_title(8, "Out")
	paintballz_tree.set_column_title(9, "Tex")
	paintballz_tree.set_column_title(10, "Anc")

	paintballz_tree.connect("item_edited", self, "_on_Tree_item_edited")

	# var viewport_size = get_viewport().size
	# var panel = $Panel
	# var panel_size = panel.rect_size
	# panel.margin_left = (viewport_size.x - panel_size.x) / 2
	# panel.margin_right = panel.margin_left + panel_size.x
	# panel.margin_top = viewport_size.y - panel_size.y - 10
	# panel.margin_bottom = panel.margin_top + panel_size.y
	
	var viewport_size = get_viewport().size
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	active_palette = default_palette

	update_preview()

func show():
	panel.show()

func hide():
	panel.hide()

func set_texture_list(list):
	ball_texture_list = list
	if ball_texture_list.size() > 0:
		texture_spinbox.max_value = ball_texture_list.size() - 1
	update_preview()

func set_palette(palette_name):
	var pal_texture = null
	
	if palette_name != null and str(palette_name) != "":
		var user_res_path = "user://resources/palettes/" + palette_name
		var res_res_path = "res://resources/palettes/" + palette_name
		
		if ResourceLoader.exists(user_res_path):
			pal_texture = ResourceLoader.load(user_res_path)
		elif ResourceLoader.exists(res_res_path):
			pal_texture = ResourceLoader.load(res_res_path)
		elif preloader and preloader.has_resource("palette_" + palette_name.to_lower()):
			pal_texture = preloader.get_resource("palette_" + palette_name.to_lower())
	
	if pal_texture:
		active_palette = pal_texture
	else:
		active_palette = default_palette
		
	update_preview()

func sync_camera(main_camera_transform: Transform):
	if preview_camera and is_instance_valid(preview_camera):
		var rot = main_camera_transform.basis.get_euler()

		var dist = 3.0
		var pos = main_camera_transform.basis.xform(Vector3(0, 0, dist))

		preview_camera.transform.origin = pos
		preview_camera.look_at(Vector3.ZERO, Vector3.UP)

func _on_EyedropperToggle_toggled(is_on):
	emit_signal("eyedropper_toggled", is_on)

func _on_ShowRawButton_pressed():
	raw_lnz_container.visible = !raw_lnz_container.visible

func _on_property_changed(_val = null):
	if _ignore_ui_changes: return
	update_preview()

func _on_Tree_item_edited():
	_base_paintballz_data.clear()
	var root = paintballz_tree.get_root()
	if root:
		var item = root.get_children()
		while item:
			var p_data = _read_item_data(item)
			_base_paintballz_data.append(p_data)
			item = item.get_next()

	_reset_rotation_spinboxes()
	update_preview()

func _reset_rotation_spinboxes():
	_ignore_ui_changes = true
	roll_spinbox.value = 0
	pitch_spinbox.value = 0
	yaw_spinbox.value = 0
	_ignore_ui_changes = false

func _read_item_data(item: TreeItem) -> Dictionary:
	return {
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

func _on_scale_changed(value, is_size_control):
	if _ignore_ui_changes: return
	
	if link_scale_chk.pressed:
		_ignore_ui_changes = true
		if is_size_control:
			pos_scale_spin.value = value
		else:
			size_scale_spin.value = value
		_ignore_ui_changes = false
		
	update_preview()

func _on_rotation_changed(_val):
	if _ignore_ui_changes: return
	_apply_rotation_to_tree()
	update_preview()

func _apply_rotation_to_tree():
	_ignore_ui_changes = true

	var roll = deg2rad(roll_spinbox.value)
	var pitch = deg2rad(pitch_spinbox.value)
	var yaw = deg2rad(yaw_spinbox.value)

	var basis = Basis(Vector3(roll, pitch, yaw))

	paintballz_tree.clear()
	var root = paintballz_tree.create_item()

	for p_data in _base_paintballz_data:
		var new_pos = basis.xform(p_data.position)

		var item = paintballz_tree.create_item(root)
		_setup_tree_item(item, p_data, new_pos)

	_ignore_ui_changes = false

func _on_MirrorButton_pressed(axis):
	for p_data in _base_paintballz_data:
		if axis == "x": p_data.position.x *= -1
		if axis == "y": p_data.position.y *= -1
		if axis == "z": p_data.position.z *= -1

	_reset_rotation_spinboxes()

	_populate_tree_from_base()
	update_preview()

func _populate_tree_from_base():
	paintballz_tree.clear()
	var root = paintballz_tree.create_item()
	for p_data in _base_paintballz_data:
		var item = paintballz_tree.create_item(root)
		_setup_tree_item(item, p_data, p_data.position)

func _setup_tree_item(item: TreeItem, p_data: Dictionary, pos: Vector3):
	item.set_text(0, str(p_data.base))
	item.set_text(1, str(p_data.size))
	item.set_text(2, str(pos.x))
	item.set_text(3, str(pos.y))
	item.set_text(4, str(pos.z))
	item.set_text(5, str(p_data.color_index))
	item.set_text(6, str(p_data.outline_color_index))
	item.set_text(7, str(p_data.fuzz))
	item.set_text(8, str(p_data.outline))
	item.set_text(9, str(p_data.texture_id))
	item.set_text(10, str(p_data.anchored))

	for i in range(11):
		item.set_editable(i, true)

func _on_SetPaintballzButton_pressed():
	var text = paintballz_text_edit.text
	var lines = text.split("\n")

	_base_paintballz_data.clear()

	for line in lines:
		if line.empty() or line.begins_with(";") or line.begins_with("#") or line.begins_with("["):
			continue

		var parts = _split_and_clean_paintball(line)
		
		if parts.size() < 9:
			continue

		var has_group_column = parts.size() >= 12
		
		var tex_index = 10 if has_group_column else 9
		var anchor_index = 11 if has_group_column else 10

		var p_data = {
			"base": parts[0].to_int(),
			"size": parts[1].to_int(),
			"position": Vector3(parts[2].to_float(), parts[3].to_float(), parts[4].to_float()),
			"color_index": parts[5].to_int(),
			"outline_color_index": parts[6].to_int(),
			"fuzz": parts[7].to_int(),
			"outline": parts[8].to_int(),
			"texture_id": parts[tex_index].to_int() if parts.size() > tex_index else -1,
			"anchored": parts[anchor_index].to_int() if parts.size() > anchor_index else 0
		}
		_base_paintballz_data.append(p_data)

	_reset_rotation_spinboxes()
	_populate_tree_from_base()
	update_preview()

func _split_and_clean_paintball(line: String) -> Array:
	var line_parts = line.split(";", false, 1)
	var data_part = line_parts[0].strip_edges()

	data_part = data_part.replace(",", " ")
	data_part = data_part.replace("\t", " ")

	var parts = data_part.split(" ", false)
	
	var cleaned_parts = []
	for part in parts:
		cleaned_parts.append(part.strip_edges())
		
	return cleaned_parts

func _load_texture(texture_filename: String) -> Texture:
	var texture = null
	var base_name = texture_filename.get_basename()
	var extension = texture_filename.get_extension()
	var filename_variants = []
	filename_variants.append(texture_filename)
	filename_variants.append(texture_filename.to_upper())
	filename_variants.append(texture_filename.to_lower())
	filename_variants.append(base_name + "." + extension.to_upper())
	filename_variants.append(base_name + "." + extension.to_lower())
	filename_variants.append(base_name.to_upper() + "." + extension)
	filename_variants.append(base_name.to_lower() + "." + extension)
	filename_variants.append(base_name.to_upper() + "." + extension.to_upper())
	filename_variants.append(base_name.to_lower() + "." + extension.to_lower())

	var deduped = []
	for v in filename_variants:
		if not (v in deduped):
			deduped.append(v)
	filename_variants = deduped

	for variant in filename_variants:
		var resource_path = "res://resources/textures/" + variant
		var user_resource_path = "user://resources/textures/" + variant

		if ResourceLoader.exists(resource_path):
			texture = ResourceLoader.load(resource_path)
			break
		elif ResourceLoader.exists(user_resource_path):
			texture = ResourceLoader.load(user_resource_path)
			break

	return texture

func update_preview():
	for child in preview_world.get_children():
		if child.name.begins_with("PreviewBall") or child.name.begins_with("Paintball") or child.is_in_group("preview_objects"):
			child.free()

	var base_visual_ball = ball_scene.instance()
	base_visual_ball.add_to_group("preview_objects")
	preview_world.add_child(base_visual_ball)

	var base_size = size_spinbox.value
	if base_size < 1: base_size = 1

	base_visual_ball.ball_size = base_size

	if include_color_chk.pressed:
		base_visual_ball.color_index = color_edit.text.to_int()
	else:
		base_visual_ball.color_index = 0

	if include_outline_color_chk.pressed:
		base_visual_ball.outline_color_index = outline_color_edit.text.to_int()
	else:
		base_visual_ball.outline_color_index = 0

	if include_outline_chk.pressed:
		base_visual_ball.outline = int(outline_spinbox.value)
	else:
		base_visual_ball.outline = -1

	if include_fuzz_chk.pressed:
		base_visual_ball.fuzz_amount = int(fuzz_spinbox.value)
	else:
		base_visual_ball.fuzz_amount = 0

	base_visual_ball.palette = active_palette

	if include_texture_chk.pressed:
		var tex_id = int(texture_spinbox.value)
		if tex_id >= 0 and tex_id < ball_texture_list.size():
			var tex_info = ball_texture_list[tex_id]
			var path = ""
			if typeof(tex_info) == TYPE_DICTIONARY and tex_info.has("filename"):
				path = tex_info.filename

			if not path.empty():
				var loaded_tex = _load_texture(path)
				if loaded_tex:
					base_visual_ball.texture = loaded_tex
					if tex_info.has("transparent_color"):
						base_visual_ball.transparent_color = tex_info.transparent_color
					if tex_info.has("texture_size") and tex_info.texture_size != null:
						base_visual_ball.texture_size = tex_info.texture_size

	base_visual_ball.transform.origin = Vector3.ZERO

	if include_paintballz_chk.pressed:
		var root = paintballz_tree.get_root()
		if root:
			var paintballs_from_tree = []
			var item = root.get_children()
			while item:
				var size = item.get_text(1).to_int()
				var pos = Vector3(item.get_text(2).to_float(), item.get_text(3).to_float(), item.get_text(4).to_float())
				var col = item.get_text(5).to_int()
				var out_col = item.get_text(6).to_int()
				var fuzz = item.get_text(7).to_int()
				var outline = item.get_text(8).to_int()
				var tex_id = item.get_text(9).to_int()

				paintballs_from_tree.append({
					"size": size,
					"pos": pos,
					"col": col,
					"out_col": out_col,
					"fuzz": fuzz,
					"outline": outline,
					"tex_id": tex_id
				})

				item = item.get_next()

			paintballs_from_tree.invert()

			var z_add_counter = 0.0
			for pb_data in paintballs_from_tree:
				var size = pb_data.size
				var pos = pb_data.pos
				var col = pb_data.col
				var out_col = pb_data.out_col
				var fuzz = pb_data.fuzz
				var outline = pb_data.outline
				var tex_id = pb_data.tex_id

				var pb_visual = paintball_scene.instance()
				base_visual_ball.add_child(pb_visual)

				var s_scale = size_scale_spin.value
				var p_scale = pos_scale_spin.value

				var final_size = float(base_size) * (float(size) / 100.0) * s_scale
				final_size -= 1.0 - fmod(final_size, 2.0)

				pb_visual.ball_size = final_size
				pb_visual.base_ball_size = base_size
				pb_visual.color_index = col
				pb_visual.outline_color_index = out_col
				pb_visual.outline = outline
				pb_visual.fuzz_amount = fuzz
				pb_visual.palette = active_palette

				pb_visual.z_add = z_add_counter
				z_add_counter += 1.0

				pb_visual.base_ball_position = Vector3.ZERO

				if tex_id >= 0 and tex_id < ball_texture_list.size():
					var tex_info = ball_texture_list[tex_id]
					var path = ""
					if typeof(tex_info) == TYPE_DICTIONARY and tex_info.has("filename"):
						path = tex_info.filename

					if not path.empty():
						var loaded_tex = _load_texture(path)
						if loaded_tex:
							pb_visual.texture = loaded_tex
							if tex_info.has("transparent_color"):
								pb_visual.transparent_color = tex_info.transparent_color
							if tex_info.has("texture_size") and tex_info.texture_size != null:
								pb_visual.texture_size = tex_info.texture_size

				var pixel_world_size = 0.002
				var pb_pos = pos * Vector3(1, -1, 1) * (float(base_size) / 2.0) * pixel_world_size * p_scale

				pb_visual.transform.origin = pb_pos

func is_eyedropper_active():
	return eyedropper_toggle.pressed

func get_properties():
	var properties = {}

	if include_size_chk.pressed:
		properties["size"] = int(round(size_spinbox.value))
		properties["size_mode"] = size_mode_option.selected

	if include_color_chk.pressed:
		properties["color_index"] = color_edit.text.to_int()
	if include_outline_color_chk.pressed:
		properties["outline_color_index"] = outline_color_edit.text.to_int()
	if include_outline_chk.pressed:
		properties["outline"] = int(outline_spinbox.value)
	if include_fuzz_chk.pressed:
		properties["fuzz"] = int(fuzz_spinbox.value)
	if include_texture_chk.pressed:
		properties["texture_id"] = int(texture_spinbox.value)

	properties["apply_ballz"] = true
	properties["apply_paintballz"] = include_paintballz_chk.pressed
	properties["scale_paintballz"] = scale_paintballz_chk.pressed

	properties["paintball_size_scale"] = size_scale_spin.value
	properties["paintball_pos_scale"] = pos_scale_spin.value

	if include_paintballz_chk.pressed:
		var paintballz = []
		var root = paintballz_tree.get_root()
		if root:
			var item = root.get_children()
			while item:
				var p_data = _read_item_data(item)
				paintballz.append(p_data)
				item = item.get_next()
		properties["paintballz"] = paintballz

	return properties

func set_properties(properties):
	_ignore_ui_changes = true

	if properties.has("size"):
		size_spinbox.value = properties.size
		source_ball_reference_size = properties.size

	if properties.has("color_index"):
		color_edit.text = str(properties.color_index)
	if properties.has("outline_color_index"):
		outline_color_edit.text = str(properties.outline_color_index)
	if properties.has("outline"):
		outline_spinbox.value = properties.outline
	if properties.has("fuzz"):
		fuzz_spinbox.value = properties.fuzz
	if properties.has("texture_id"):
		texture_spinbox.value = properties.texture_id

	roll_spinbox.value = 0
	pitch_spinbox.value = 0
	yaw_spinbox.value = 0

	if properties.has("paintball_size_scale"):
		size_scale_spin.value = properties.paintball_size_scale
	else:
		size_scale_spin.value = 1.0

	if properties.has("paintball_pos_scale"):
		pos_scale_spin.value = properties.paintball_pos_scale
	else:
		pos_scale_spin.value = 1.0

	_base_paintballz_data.clear()

	if properties.has("paintballz"):
		for pb in properties.paintballz:
			if typeof(pb) == TYPE_OBJECT:
				_base_paintballz_data.append(_convert_lnz_object_to_dict(pb))
			elif typeof(pb) == TYPE_DICTIONARY:
				_base_paintballz_data.append(pb.duplicate())

	_populate_tree_from_base()

	_ignore_ui_changes = false
	update_preview()

func _convert_lnz_object_to_dict(obj) -> Dictionary:
	return {
		"base": obj.base,
		"size": obj.size,
		"position": obj.normalised_position,
		"color_index": obj.color_index,
		"outline_color_index": obj.outline_color_index,
		"fuzz": obj.fuzz,
		"outline": obj.outline,
		"texture_id": obj.texture_id,
		"anchored": obj.anchored
	}
