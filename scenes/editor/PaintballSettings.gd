extends DraggablePanel
## PaintballSettings.gd
## Manages the UI panel and logic for the Paintball Mode settings
## This script controls the visibility of the settings panel and provides methods to:
## 1. Initialize the panel to the bottom center of the viewport and connect UI signals
## 2. Show and hide the panel
## 3. Retrieve all current paintball properties (e.g., diameter, color, fuzz)
## 4. Emit the `apply_paintballz` signal when the "Apply" button is pressed
## 5. Emit the `delete_mode_toggled(is_on)` signal when the checkbox is toggled

signal apply_paintballz
signal clear_paintballz
signal delete_mode_toggled(is_on)

var _is_loading_settings = false

onready var paintballz_tree = find_node("PaintballzTree")
onready var preview_viewport = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer/Viewport
onready var preview_world = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer/Viewport/PreviewWorld
onready var preview_camera = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer/Viewport/PreviewWorld/Camera

var ball_scene = preload("res://Ball.tscn")
var paintball_scene = preload("res://Paintball.tscn")
var default_palette = preload("res://resources/palettes/petz_palette.png")
var active_palette = default_palette

onready var preloader = get_tree().root.get_node("Root/ResourcePreloader")
var ball_texture_list = []

var design_color_slots = [
	{
		"color": "105",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(1, 1, 0)
	},
	{
		"color": "95",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(1, 0, 0)
	},
	{
		"color": "145",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(0, 1, 0)
	},
	{
		"color": "155",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(0, 0, 1)
	}
]

const DESIGN_CANVAS_SIZE = 200.0

func _ready():
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("EraserCheckBox").connect("toggled", self, "_on_DeleteModeCheckBox_toggled")

	var viewport_size = get_viewport().size
	var panel = self
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	_connect_settings_signals()
	_connect_design_signals()

	preview_viewport.size = Vector2(200, 200)

	_setup_slots_tree()
	load_settings()

	call_deferred("update_preview")

func _on_ApplyButton_pressed():
	emit_signal("apply_paintballz")

func _on_ClearButton_pressed():
	emit_signal("clear_paintballz")

func _on_DeleteModeCheckBox_toggled(is_on):
	emit_signal("delete_mode_toggled", is_on)

func is_design_mode_active():
	return find_node("TabContainer").current_tab == 1

func _on_TabContainer_tab_changed(tab):
	if tab == 1:
		update_preview()

func get_properties():
	var properties = {}
	properties["diameter_min"] = find_node("DiameterMin").value
	properties["diameter_max"] = find_node("DiameterMax").value
	properties["tapered"] = find_node("Tapered").pressed
	properties["pixel_mode"] = find_node("PixelMode").pressed
	properties["color"] = find_node("Color").text
	properties["outline_color"] = find_node("OutlineColor").text
	properties["outline_type_min"] = find_node("OutlineTypeMin").value
	properties["outline_type_max"] = find_node("OutlineTypeMax").value
	properties["fuzz_min"] = find_node("FuzzMin").value
	properties["fuzz_max"] = find_node("FuzzMax").value
	properties["texture"] = find_node("Texture").text
	properties["group"] = find_node("Group").value
	properties["anchored"] = find_node("Anchored").pressed
	properties["target_mode"] = find_node("Target").selected
	properties["freeline"] = find_node("FreelineCheckBox").pressed
	properties["spacing"] = find_node("Spacing").value
	properties["jitter"] = find_node("Jitter").value
	properties["ordered"] = find_node("Ordered").pressed
	properties["repeat"] = find_node("Repeat").pressed
	properties["shuffle"] = find_node("Shuffle").pressed
	return properties

func _compute_distance_transform(mask: Array, size: int) -> Array:
	var dists = []
	dists.resize(size * size)
	for i in range(dists.size()):
		if not mask[i]:
			dists[i] = 0.0
			continue
		
		var x = i % size
		var y = i / size
		var min_d = 100.0
		for my in range(size):
			for mx in range(size):
				if not mask[my * size + mx]:
					var d = sqrt(pow(x - mx, 2) + pow(y - my, 2))
					if d < min_d: min_d = d

		min_d = min(min_d, min(x + 0.5, min(y + 0.5, min(size - 1 - x + 0.5, size - 1 - y + 0.5))))
		dists[i] = min_d
	return dists

func _clear_mask_circle(mask: Array, size: int, cx: int, cy: int, radius: float) -> int:
	var cleared = 0
	for y in range(size):
		for x in range(size):
			var idx = y * size + x
			if mask[idx]:
				var d = sqrt(pow(x - cx, 2) + pow(y - cy, 2))
				if d <= radius:
					mask[idx] = false
					cleared += 1
	return cleared

func paste_paintball_design(center_dir: Vector3, basis: Basis, ball_no: int, ball_lnz_diameter: float) -> Array:
	var design_canvas = find_node("DesignCanvas")
	var paintballs = design_canvas.design_paintballs
	var output = []

	var footprint_percent = find_node("DiameterMax").value

	var footprint_lnz = ball_lnz_diameter * (footprint_percent / 100.0)

	var tangent_x = basis.x
	var tangent_y = basis.z

	for pb in paintballs:

		if pb.color_slot - 1 >= design_color_slots.size():
			continue

		var dx = pb.x * (footprint_lnz / 2.0)
		var dy = -pb.y * (footprint_lnz / 2.0)

		var pos_on_plane = center_dir * (ball_lnz_diameter * 0.5) + tangent_x * dx + tangent_y * dy

		var slot_data = design_color_slots[pb.color_slot - 1]
		var color_list = LnzLiveUtils.parse_number_list(slot_data.color)

		var ratio = float(pb.diameter) / DESIGN_CANVAS_SIZE
		var pb_diam_lnz = footprint_lnz * ratio

		var pb_info = {
			"base_ball_no": ball_no,
			"pos_normalized": pos_on_plane.normalized(),
			"diameter": int(max(1, pb_diam_lnz)),
			"color": color_list[randi() % color_list.size()] if color_list else 0,
			"outline_color": int(LnzLiveUtils.parse_number_list(slot_data.outline_color)[0]) if slot_data.outline_color else 244,
			"outline_type": int(slot_data.outline_type),
			"fuzz": int(slot_data.get("fuzz", 0)),
			"group": int(slot_data.get("group", 0)),
			"texture": int(LnzLiveUtils.parse_number_list(slot_data.texture, true)[0]),
			"anchored": 1 if slot_data.get("anchored", true) else 0
		}
		output.append(pb_info)

	return output

func _connect_settings_signals():
	find_node("DiameterMin").connect("value_changed", self, "_on_setting_changed")
	find_node("DiameterMax").connect("value_changed", self, "_on_setting_changed")
	find_node("Tapered").connect("toggled", self, "_on_setting_changed")
	find_node("PixelMode").connect("toggled", self, "_on_setting_changed")
	find_node("Color").connect("text_changed", self, "_on_setting_changed")
	find_node("OutlineColor").connect("text_changed", self, "_on_setting_changed")
	find_node("OutlineTypeMin").connect("value_changed", self, "_on_setting_changed")
	find_node("OutlineTypeMax").connect("value_changed", self, "_on_setting_changed")
	find_node("FuzzMin").connect("value_changed", self, "_on_setting_changed")
	find_node("FuzzMax").connect("value_changed", self, "_on_setting_changed")
	find_node("Texture").connect("text_changed", self, "_on_setting_changed")
	find_node("Group").connect("value_changed", self, "_on_setting_changed")
	find_node("Anchored").connect("toggled", self, "_on_setting_changed")
	find_node("Target").connect("item_selected", self, "_on_setting_changed")
	find_node("FreelineCheckBox").connect("toggled", self, "_on_setting_changed")
	find_node("Spacing").connect("value_changed", self, "_on_setting_changed")
	find_node("Jitter").connect("value_changed", self, "_on_setting_changed")
	find_node("Ordered").connect("toggled", self, "_on_setting_changed")
	find_node("Repeat").connect("toggled", self, "_on_setting_changed")
	find_node("Shuffle").connect("toggled", self, "_on_setting_changed")
	find_node("EraserCheckBox").connect("toggled", self, "_on_setting_changed")

	var reset_btn = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _connect_design_signals():
	find_node("DesignCanvas").connect("design_changed", self, "_on_setting_changed")
	find_node("ClearGridButton").connect("pressed", find_node("DesignCanvas"), "clear")
	find_node("BrushSizeSlider").connect("value_changed", self, "_on_brush_size_changed")

	find_node("AddSlotButton").connect("pressed", self, "_on_AddSlotButton_pressed")
	find_node("RemoveSlotButton").connect("pressed", self, "_on_RemoveSlotButton_pressed")

	var tree = find_node("SlotsTree")
	tree.connect("item_edited", self, "_on_SlotsTree_item_edited")
	tree.connect("cell_selected", self, "_on_SlotsTree_cell_selected")
	tree.connect("item_selected", self, "_on_SlotsTree_cell_selected")

func _on_brush_size_changed(value):
	find_node("DesignCanvas").brush_size = value

func _refresh_slot_buttons():
	_populate_slots_tree()
	find_node("DesignCanvas").slot_data_ref = design_color_slots
	find_node("DesignCanvas").update()

func _setup_slots_tree():
	var tree = find_node("SlotsTree")
	tree.set_column_titles_visible(true)
	tree.columns = 8
	tree.set_column_title(0, "Color")
	tree.set_column_title(1, "Col")
	tree.set_column_title(2, "OutCol")
	tree.set_column_title(3, "Tex")
	tree.set_column_title(4, "Out")
	tree.set_column_title(5, "Fuzz")
	tree.set_column_title(6, "Grp")
	tree.set_column_title(7, "Anc")

	tree.set_column_expand(0, false)
	tree.set_column_min_width(0, 40)

	tree.set_column_expand(7, false)
	tree.set_column_min_width(7, 30)

func _populate_slots_tree():
	var tree = find_node("SlotsTree")
	tree.clear()
	var root = tree.create_item()

	for i in range(design_color_slots.size()):
		var slot = design_color_slots[i]
		var item = tree.create_item(root)

		# Col 0: Display Color
		item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
		# TreeItem doesn't support easy bg color per cell
		var icon = _create_color_icon(slot.display_color)
		item.set_icon(0, icon)
		item.set_editable(0, true)

		# Col 1: LNZ Color (String)
		item.set_text(1, str(slot.color))
		item.set_editable(1, true)

		# Col 2: Outline Color (String)
		item.set_text(2, str(slot.outline_color))
		item.set_editable(2, true)

		# Col 3: Texture (String)
		item.set_text(3, str(slot.texture))
		item.set_editable(3, true)

		# Col 4: Outline Type (Range)
		item.set_cell_mode(4, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(4, -2, 10, 1)
		item.set_range(4, slot.outline_type)
		item.set_editable(4, true)

		# Col 5: Fuzz (Range)
		item.set_cell_mode(5, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(5, 0, 100, 1)
		item.set_range(5, slot.get("fuzz", 0))
		item.set_editable(5, true)

		# Col 6: Group (Range)
		item.set_cell_mode(6, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(6, -1, 100, 1)
		item.set_range(6, slot.get("group", 0))
		item.set_editable(6, true)

		# Col 7: Anchored (Check)
		item.set_cell_mode(7, TreeItem.CELL_MODE_CHECK)
		item.set_checked(7, slot.get("anchored", true))
		item.set_editable(7, true)

		item.set_metadata(0, i)

func _create_color_icon(color: Color) -> Texture:
	var img = Image.new()
	img.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	return tex

func _on_SlotsTree_item_edited():
	if _is_loading_settings: return

	var tree = find_node("SlotsTree")
	var item = tree.get_edited()
	if not item: return

	var idx = item.get_metadata(0)
	if idx < 0 or idx >= design_color_slots.size(): return

	var col = tree.get_selected_column()

	design_color_slots[idx].color = item.get_text(1)
	design_color_slots[idx].outline_color = item.get_text(2)
	design_color_slots[idx].texture = item.get_text(3)
	design_color_slots[idx].outline_type = int(item.get_range(4))
	design_color_slots[idx].fuzz = int(item.get_range(5))
	design_color_slots[idx].group = int(item.get_range(6))
	design_color_slots[idx].anchored = item.is_checked(7)

	save_settings()
	update_preview()

func _on_SlotsTree_cell_selected():
	var tree = find_node("SlotsTree")
	var item = tree.get_selected()
	if not item: return

	var idx = item.get_metadata(0)
	var col = tree.get_selected_column()

	var canvas = find_node("DesignCanvas")
	if canvas:
		canvas.current_color_slot = idx + 1

	if col == 0:
		var picker_popup = PopupPanel.new()
		picker_popup.rect_size = Vector2(300, 400)
		var picker = ColorPicker.new()
		picker.color = design_color_slots[idx].display_color
		picker.connect("color_changed", self, "_on_slot_display_color_changed", [idx, item])
		picker_popup.add_child(picker)
		add_child(picker_popup)
		picker_popup.popup_centered()
		picker_popup.connect("popup_hide", picker_popup, "queue_free")

func _on_slot_display_color_changed(color, idx, item):
	if idx >= 0 and idx < design_color_slots.size():
		design_color_slots[idx].display_color = color
		item.set_icon(0, _create_color_icon(color))
		find_node("DesignCanvas").update()
		save_settings()

func _on_AddSlotButton_pressed():
	var new_slot = {
		"color": "255",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"display_color": Color(randf(), randf(), randf())
	}
	design_color_slots.append(new_slot)
	_refresh_slot_buttons()
	save_settings()

func _on_RemoveSlotButton_pressed():
	var tree = find_node("SlotsTree")
	var item = tree.get_selected()
	if not item: return

	var idx = item.get_metadata(0)
	if design_color_slots.size() <= 1:
		return

	design_color_slots.remove(idx)

	var canvas = find_node("DesignCanvas")
	var to_remove = []
	for i in range(canvas.design_paintballs.size()):
		var pb = canvas.design_paintballs[i]
		if pb.color_slot == idx + 1:
			to_remove.append(i)
		elif pb.color_slot > idx + 1:
			pb.color_slot -= 1

	to_remove.invert()
	for i in to_remove:
		canvas.design_paintballs.remove(i)

	_refresh_slot_buttons()
	canvas.update()
	save_settings()

func _on_setting_changed(_arg = null):
	if _is_loading_settings:
		return
	save_settings()
	update_preview()

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

func sync_camera(main_camera_transform: Transform):
	if preview_camera and is_instance_valid(preview_camera):
		var rot = main_camera_transform.basis.get_euler()

		var dist = 3.0
		var pos = main_camera_transform.basis.xform(Vector3(0, 0, dist))

		preview_camera.transform.origin = pos
		preview_camera.look_at(Vector3.ZERO, Vector3.UP)

func update_preview():
	if not preview_viewport or not preview_world: 
		print("DEBUG: Preview nodes missing!") 
		return

	preview_camera.projection = Camera.PROJECTION_ORTHOGONAL
	preview_camera.size = 1.2 
	preview_camera.far = 100.0

	for child in preview_world.get_children():
		if child.is_in_group("preview_objects") or child.name.begins_with("Paintball"):
			child.free()

	var base_visual_ball = ball_scene.instance()
	base_visual_ball.add_to_group("preview_objects")
	preview_world.add_child(base_visual_ball)
	print("DEBUG: Instanced Base Ball: ", base_visual_ball.name)

	var base_size = 50 
	base_visual_ball.ball_size = base_size
	base_visual_ball.color_index = 244
	base_visual_ball.palette = active_palette
	base_visual_ball.transform.origin = Vector3.ZERO

	base_visual_ball.visible = true
	base_visual_ball.transform.origin = Vector3.ZERO

	var center_dir = Vector3(0, 0, 1) 
	var basis = Basis() 
	var pb_list = paste_paintball_design(center_dir, basis, 0, float(base_size))

	var z_add_counter = 0.0
	for pb_data in pb_list:
		var pb_visual = paintball_scene.instance()
		base_visual_ball.add_child(pb_visual)

		pb_visual.base_ball_size = base_size
		pb_visual.color_index = pb_data.color
		pb_visual.outline_color_index = pb_data.outline_color
		pb_visual.outline = pb_data.outline_type
		pb_visual.fuzz_amount = pb_data.fuzz
		pb_visual.palette = active_palette
		pb_visual.z_add = z_add_counter
		z_add_counter += 1.0

		var pixel_world_size = 0.002
		var radius = float(base_size) / 2.0
		
		var pb_pos = pb_data.pos_normalized * Vector3(1, -1, 1) * radius * pixel_world_size
		
		pb_visual.transform.origin = pb_pos

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("PaintballProperties", "diameter_min", find_node("DiameterMin").value)
	config.set_value("PaintballProperties", "diameter_max", find_node("DiameterMax").value)
	config.set_value("PaintballProperties", "tapered", find_node("Tapered").pressed)
	config.set_value("PaintballProperties", "pixel_mode", find_node("PixelMode").pressed)
	config.set_value("PaintballProperties", "color", find_node("Color").text)
	config.set_value("PaintballProperties", "outline_color", find_node("OutlineColor").text)
	config.set_value("PaintballProperties", "outline_type_min", find_node("OutlineTypeMin").value)
	config.set_value("PaintballProperties", "outline_type_max", find_node("OutlineTypeMax").value)
	config.set_value("PaintballProperties", "fuzz_min", find_node("FuzzMin").value)
	config.set_value("PaintballProperties", "fuzz_max", find_node("FuzzMax").value)
	config.set_value("PaintballProperties", "texture", find_node("Texture").text)
	config.set_value("PaintballProperties", "group", find_node("Group").value)
	config.set_value("PaintballProperties", "anchored", find_node("Anchored").pressed)
	config.set_value("PaintballProperties", "target", find_node("Target").selected)
	config.set_value("PaintballProperties", "freeline", find_node("FreelineCheckBox").pressed)
	config.set_value("PaintballProperties", "spacing", find_node("Spacing").value)
	config.set_value("PaintballProperties", "jitter", find_node("Jitter").value)
	config.set_value("PaintballProperties", "ordered", find_node("Ordered").pressed)
	config.set_value("PaintballProperties", "repeat", find_node("Repeat").pressed)
	config.set_value("PaintballProperties", "shuffle", find_node("Shuffle").pressed)
	config.set_value("PaintballProperties", "eraser", find_node("EraserCheckBox").pressed)

	config.set_value("DesignMode", "design_paintballs", find_node("DesignCanvas").design_paintballs)
	config.set_value("DesignMode", "brush_size", find_node("BrushSizeSlider").value)
	config.set_value("DesignMode", "color_slots_v2", design_color_slots)

	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving PaintballSettings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	find_node("DiameterMin").value = config.get_value("PaintballProperties", "diameter_min", 10.0)
	find_node("DiameterMax").value = config.get_value("PaintballProperties", "diameter_max", 20.0)
	find_node("Tapered").pressed = config.get_value("PaintballProperties", "tapered", false)
	find_node("PixelMode").pressed = config.get_value("PaintballProperties", "pixel_mode", false)
	find_node("Color").text = config.get_value("PaintballProperties", "color", "")
	find_node("OutlineColor").text = config.get_value("PaintballProperties", "outline_color", "244")
	find_node("OutlineTypeMin").value = config.get_value("PaintballProperties", "outline_type_min", -1.0)
	find_node("OutlineTypeMax").value = config.get_value("PaintballProperties", "outline_type_max", -1.0)
	find_node("FuzzMin").value = config.get_value("PaintballProperties", "fuzz_min", 0.0)
	find_node("FuzzMax").value = config.get_value("PaintballProperties", "fuzz_max", 0.0)
	find_node("Texture").text = config.get_value("PaintballProperties", "texture", "0")
	find_node("Group").value = config.get_value("PaintballProperties", "group", 0.0)
	find_node("Anchored").pressed = config.get_value("PaintballProperties", "anchored", true)
	find_node("Target").selected = config.get_value("PaintballProperties", "target", 0)
	find_node("FreelineCheckBox").pressed = config.get_value("PaintballProperties", "freeline", false)
	find_node("Spacing").value = config.get_value("PaintballProperties", "spacing", 5.0)
	find_node("Jitter").value = config.get_value("PaintballProperties", "jitter", 0.0)
	find_node("Ordered").pressed = config.get_value("PaintballProperties", "ordered", false)
	find_node("Repeat").pressed = config.get_value("PaintballProperties", "repeat", false)
	find_node("Shuffle").pressed = config.get_value("PaintballProperties", "shuffle", false)
	find_node("EraserCheckBox").pressed = config.get_value("PaintballProperties", "eraser", false)

	var loaded_paintballs = config.get_value("DesignMode", "design_paintballs", [])
	if loaded_paintballs.size() > 0:
		var canvas = find_node("DesignCanvas")
		canvas.design_paintballs = loaded_paintballs
		canvas.update()
		canvas.emit_signal("design_changed")

	find_node("BrushSizeSlider").value = config.get_value("DesignMode", "brush_size", 30.0)
	find_node("DesignCanvas").brush_size = find_node("BrushSizeSlider").value

	var loaded_slots_v2 = config.get_value("DesignMode", "color_slots_v2", [])
	if loaded_slots_v2.size() > 0:
		design_color_slots = loaded_slots_v2
	else:
		var loaded_slots = config.get_value("DesignMode", "color_slots", [])
		if loaded_slots.size() == 4:
			for i in range(4):
				var old_slot = loaded_slots[i]
				design_color_slots[i].color = old_slot.color
				design_color_slots[i].outline_color = old_slot.outline_color
				design_color_slots[i].texture = old_slot.texture
				design_color_slots[i].outline_type = old_slot.outline_type

	_refresh_slot_buttons()
	_is_loading_settings = false

func _on_reset_defaults_pressed():
	_is_loading_settings = true

	find_node("DiameterMin").value = 10.0
	find_node("DiameterMax").value = 20.0
	find_node("Tapered").pressed = false
	find_node("PixelMode").pressed = false
	find_node("Color").text = ""
	find_node("OutlineColor").text = "244"
	find_node("OutlineTypeMin").value = -1.0
	find_node("OutlineTypeMax").value = -1.0
	find_node("FuzzMin").value = 0.0
	find_node("FuzzMax").value = 0.0
	find_node("Texture").text = "0"
	find_node("Group").value = 0.0
	find_node("Anchored").pressed = true
	find_node("Target").selected = 0
	find_node("FreelineCheckBox").pressed = false
	find_node("Spacing").value = 5.0
	find_node("Jitter").value = 0.0
	find_node("Ordered").pressed = false
	find_node("Repeat").pressed = false
	find_node("Shuffle").pressed = false
	find_node("EraserCheckBox").pressed = false

	find_node("DesignCanvas").clear()
	find_node("BrushSizeSlider").value = 30.0

	design_color_slots = [
		{
			"color": "105",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(1, 1, 0)
		},
		{
			"color": "95",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(1, 0, 0)
		},
		{
			"color": "145",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(0, 1, 0)
		},
		{
			"color": "155",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"display_color": Color(0, 0, 1)
		}
	]
	_refresh_slot_buttons()

	_is_loading_settings = false
	save_settings()
