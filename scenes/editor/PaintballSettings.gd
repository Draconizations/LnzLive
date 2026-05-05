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

#var _preview_ball_rotation = Vector3.ZERO
#var _is_dragging_preview = false
#var _last_mouse_pos = Vector2.ZERO

onready var paintballz_tree = find_node("PaintballzTree")
#onready var preview_container = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer
#onready var preview_viewport = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer/Viewport
#onready var preview_world = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer/Viewport/PreviewWorld
#onready var preview_camera = $VBoxContainer/TabContainer/Design/GridContainer/PreviewContainer/Viewport/PreviewWorld/Camera

#var ball_scene = preload("res://Ball.tscn")
#var paintball_scene = preload("res://Paintball.tscn")

var dog_generator = null
var default_palette = LnzLiveUtils.DEFAULT_PALETTE
var active_palette = default_palette

onready var preloader = get_tree().root.get_node("Root/ResourcePreloader")

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

	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_palette_changed")

	_connect_settings_signals()
	_connect_design_signals()

#	preview_viewport.size = preview_container.rect_size

#	var preview_container = find_node("PreviewContainer")
#	preview_container.connect("gui_input", self, "_on_PreviewContainer_gui_input")

	find_node("BrushSpaceSlider").connect("value_changed", self, "_on_brush_space_changed")

	_setup_slots_tree()
	load_settings()

#	call_deferred("update_preview")

#func _on_PreviewContainer_gui_input(event):
#	if event is InputEventMouseButton:
#		if event.button_index == BUTTON_LEFT:
#			_is_dragging_preview = event.pressed
#			_last_mouse_pos = event.position
#
#	elif event is InputEventMouseMotion and _is_dragging_preview:
#		var diff = event.position - _last_mouse_pos
#		_preview_ball_rotation.y += diff.x * 0.01
#		_preview_ball_rotation.x += diff.y * 0.01
#		_last_mouse_pos = event.position
#		update_preview()

func _on_ApplyButton_pressed():
	print("[STATUS] PaintballSettings: apply_paintballz signal emitted")
	emit_signal("apply_paintballz")

func _on_ClearButton_pressed():
	print("[STATUS] PaintballSettings: clear_paintballz signal emitted")
	emit_signal("clear_paintballz")

func _on_DeleteModeCheckBox_toggled(is_on):
	print("[STATUS] PaintballSettings: delete_mode_toggled signal emitted, is_on: %s" % is_on)
	emit_signal("delete_mode_toggled", is_on)

func _on_palette_changed(palette_name = ""):
	if not dog_generator or not dog_generator.current_palette_texture:
		return
		
	var img = dog_generator.current_palette_texture.get_data()
	img.lock()
	
	var img_width = img.get_width()
	var img_height = img.get_height()
	
	for slot in design_color_slots:
		# Parse the color string (e.g. "105" or "105, 95") and grab the first index
		var color_list = LnzLiveUtils.parse_number_list(str(slot.color))
		if color_list and color_list.size() > 0:
			var index = int(color_list[0])
			
			var x = index % img_width
			var y = index / img_width
			
			if x < img_width and y < img_height:
				slot.display_color = img.get_pixel(x, y)
	
	img.unlock()
	
	_refresh_slot_buttons()
	find_node("DesignCanvas").update()

func is_design_mode_active():
	return find_node("TabContainer").current_tab == 1

#func _on_TabContainer_tab_changed(tab):
#	if tab == 1:
##		update_preview()

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

func export_paintball_json():
	print("[STATUS] PaintballSettings: started exporting paintball JSON (HTML5 feature: %s)" % OS.has_feature("HTML5"))
	if OS.has_feature("HTML5"):
		var settings_dict = get_properties()
		var json_string = JSON.print(settings_dict, "  ")
		var filename = "LnzLive_paintball-mode_settings_" + str(OS.get_unix_time()) + ".json"
		var base64_content = Marshalls.raw_to_base64(json_string.to_utf8())
		var js_code = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:application/json;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + filename + """');
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
		print("[STATUS] PaintballSettings: triggered web download for %s" % filename)
	else:
		var file_dialog = FileDialog.new()
		file_dialog.window_title = "Export Paintball Preset"
		file_dialog.mode = FileDialog.MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.current_file = "LnzLive_paintball-mode_settings_" + str(OS.get_unix_time()) + ".json"
		file_dialog.connect("file_selected", self, "_save_settings_file")
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _save_settings_file(path):
	var settings_dict = get_properties()
	var json_string = JSON.print(settings_dict, "  ")
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(json_string)
		file.close()
		print("[STATUS] PaintballSettings: exported settings to %s" % path)
	else:
		print("[ERROR] PaintballSettings: failed to open file for writing settings export: %s" % path)

func _on_ImportPresetButton_pressed():
	print("[STATUS] PaintballSettings: import preset button pressed")
	if OS.has_feature("HTML5"):
		var js_code = """
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = '.json';
		input.onchange = e => { 
		   var file = e.target.files[0]; 
		   var reader = new FileReader();
		   reader.readAsText(file,'UTF-8');
		   reader.onload = readerEvent => {
			   var content = readerEvent.target.result;
			   window.godotPaintballImport(content);
		   }
		}
		input.click();
		"""
		var callback = JavaScript.create_callback(self, "_on_web_import_completed")
		JavaScript.get_interface("window").godotPaintballImport = callback
		JavaScript.eval(js_code)
	else:
		var file_dialog = FileDialog.new()
		file_dialog.window_title = "Import Paintball Preset"
		file_dialog.mode = FileDialog.MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.connect("file_selected", self, "_load_preset_file")
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_web_import_completed(args):
	var content = args[0]
	var json_res = JSON.parse(content)
	if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
		print("[STATUS] PaintballSettings: web import parsed successfully, applying dictionary")
		_apply_settings_dict(json_res.result)
	else:
		print("[ERROR] PaintballSettings: web import failed to parse JSON (Error code: %d)" % json_res.error)

func _load_preset_file(path):
	print("[STATUS] PaintballSettings: attempting to load preset from %s" % path)
	var file = File.new()
	if file.open(path, File.READ) == OK:
		var text = file.get_as_text()
		var json_res = JSON.parse(text)
		if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
			print("[STATUS] PaintballSettings: successfully loaded and parsed preset file")
			_apply_settings_dict(json_res.result)
		else:
			print("[ERROR] PaintballSettings: failed to parse JSON preset from %s (Error code: %d)" % [path, json_res.error])
		file.close()
	else:
		print("[ERROR] PaintballSettings: failed to open preset file for reading: %s" % path)

func _apply_settings_dict(data: Dictionary):
	print("[STATUS] PaintballSettings: applying settings dictionary")
	_is_loading_settings = true
	if data.has("diameter_min"): find_node("DiameterMin").value = data["diameter_min"]
	if data.has("diameter_max"): find_node("DiameterMax").value = data["diameter_max"]
	if data.has("tapered"): find_node("Tapered").pressed = data["tapered"]
	if data.has("pixel_mode"): find_node("PixelMode").pressed = data["pixel_mode"]
	if data.has("color"): find_node("Color").text = str(data["color"])
	if data.has("outline_color"): find_node("OutlineColor").text = str(data["outline_color"])
	if data.has("outline_type_min"): find_node("OutlineTypeMin").value = data["outline_type_min"]
	if data.has("outline_type_max"): find_node("OutlineTypeMax").value = data["outline_type_max"]
	if data.has("fuzz_min"): find_node("FuzzMin").value = data["fuzz_min"]
	if data.has("fuzz_max"): find_node("FuzzMax").value = data["fuzz_max"]
	if data.has("texture"): find_node("Texture").text = str(data["texture"])
	if data.has("group"): find_node("Group").value = data["group"]
	if data.has("anchored"): find_node("Anchored").pressed = data["anchored"]
	if data.has("target_mode"): find_node("Target").selected = data["target_mode"]
	if data.has("freeline"): find_node("FreelineCheckBox").pressed = data["freeline"]
	if data.has("spacing"): find_node("Spacing").value = data["spacing"]
	if data.has("jitter"): find_node("Jitter").value = data["jitter"]
	if data.has("ordered"): find_node("Ordered").pressed = data["ordered"]
	if data.has("repeat"): find_node("Repeat").pressed = data["repeat"]
	if data.has("shuffle"): find_node("Shuffle").pressed = data["shuffle"]
	_is_loading_settings = false
	save_settings()

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

func paste_paintball_design(center_dir: Vector3, basis: Basis, ball_no: int, ball_lnz_diameter: float, override_footprint: float = -1.0, design_rotation_angle: float = 0.0, jitter_enabled: bool = true) -> Dictionary:
	print("[STATUS] PaintballSettings: paste_paintball_design started on ball_no: %d" % ball_no)
	var design_canvas = find_node("DesignCanvas")
	var paintballs = design_canvas.design_paintballs
	
	var out_pos = PoolVector3Array()
	var out_diams = PoolIntArray()
	var out_colors = PoolIntArray()
	var out_outlines = PoolIntArray()
	var out_out_types = PoolIntArray()
	var out_fuzz = PoolIntArray()
	var out_group = PoolIntArray()
	var out_tex = PoolIntArray()
	var out_anchored = PoolIntArray()

	var pixel_mode = find_node("DesignPixelMode").pressed
	
	var sampled_scale = rand_range(find_node("DesignTotalDiameter").value, find_node("DesignTotalDiameterMax").value)
	if override_footprint > 0:
		sampled_scale *= override_footprint
	
	var footprint_lnz = 0.0
	if pixel_mode:
		footprint_lnz = sampled_scale
	else:
		footprint_lnz = ball_lnz_diameter * (sampled_scale / 100.0)
	
	var d_jitter = find_node("DesignJitter").value if jitter_enabled else 0.0
	var r_jitter = find_node("RotateJitter").value if jitter_enabled else 0.0
	var s_jitter = find_node("SpreadJitter").value if jitter_enabled else 0.0
	var r_fixed = find_node("RotateFixed").pressed if jitter_enabled else false

	if jitter_enabled and r_jitter > 0:
		if r_fixed:
			design_rotation_angle += deg2rad(r_jitter)
		else:
			design_rotation_angle += deg2rad(rand_range(-r_jitter, r_jitter))

	var rotated_basis = basis.rotated(center_dir, design_rotation_angle)
	var tangent_x = rotated_basis.x
	var tangent_y = rotated_basis.z

	var spread_offset = Vector3.ZERO
	if jitter_enabled and s_jitter > 0:
		var s_scale = (footprint_lnz / 2.0) * (s_jitter / 100.0)
		spread_offset = tangent_x * rand_range(-s_scale, s_scale) + tangent_y * rand_range(-s_scale, s_scale)

	var ball_lnz_diam_safe = max(1.0, ball_lnz_diameter)

	for pb in paintballs:
		if pb.color_slot - 1 >= design_color_slots.size():
			print("[WARNING] PaintballSettings: paste_paintball_design skipped pb due to invalid color_slot reference: %d" % pb.color_slot)
			continue
		var slot_data = design_color_slots[pb.color_slot - 1]

		var dx = pb.x * (footprint_lnz / 2.0)
		var dy = -pb.y * (footprint_lnz / 2.0)
		if d_jitter > 0:
			var j_amt = (d_jitter / 100.0) * (footprint_lnz / 2.0)
			dx += rand_range(-j_amt, j_amt)
			dy += rand_range(-j_amt, j_amt)

		var pos_on_plane = center_dir * (ball_lnz_diameter * 0.5) + tangent_x * dx + tangent_y * dy + spread_offset
		out_pos.append(pos_on_plane.normalized())

		var slot_scale = float(slot_data.get("scale", 100)) / 100.0
		var pb_size_units = footprint_lnz * (float(pb.diameter) / 100.0) * slot_scale
		
		if d_jitter > 0:
			pb_size_units *= (1.0 + rand_range(-d_jitter/100.0, d_jitter/100.0))
		
		var final_pb_percentage = (pb_size_units / ball_lnz_diam_safe) * 100.0
		out_diams.append(int(max(1, round(final_pb_percentage))))

		var color_list = LnzLiveUtils.parse_number_list(slot_data.color)
		out_colors.append(color_list[randi() % color_list.size()] if color_list else 0)
		
		var out_col_list = LnzLiveUtils.parse_number_list(slot_data.outline_color)
		out_outlines.append(int(out_col_list[0]) if out_col_list else 244)
		
		var tex_list = LnzLiveUtils.parse_number_list(slot_data.texture, true)
		out_tex.append(int(tex_list[0]) if tex_list else 0)

		out_out_types.append(int(slot_data.outline_type))
		out_fuzz.append(int(slot_data.get("fuzz", 0)))
		out_group.append(int(slot_data.get("group", 0)))
		out_anchored.append(1 if slot_data.get("anchored", true) else 0)

	print("[STATUS] PaintballSettings: paste_paintball_design finished processing %d paintballs" % out_pos.size())
	return {
		"positions": out_pos, 
		"diameters": out_diams, 
		"colors": out_colors,
		"outlines": out_outlines, 
		"outline_types": out_out_types, 
		"fuzzes": out_fuzz,
		"groups": out_group, 
		"textures": out_tex, 
		"anchored": out_anchored
	}

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

	var export_btn = find_node("ExportSettingsButton")
	if export_btn: export_btn.connect("pressed", self, "export_paintball_json")
	var import_btn = find_node("ImportSettingsButton")
	if import_btn: import_btn.connect("pressed", self, "_on_ImportPresetButton_pressed")

	var reset_btn = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _connect_design_signals():
	find_node("DesignCanvas").connect("design_changed", self, "_on_setting_changed")
	find_node("ClearGridButton").connect("pressed", find_node("DesignCanvas"), "clear")
	find_node("BrushSizeSlider").connect("value_changed", self, "_on_brush_size_changed")
	find_node("DesignTotalDiameter").connect("value_changed", self, "_on_setting_changed")
	find_node("DesignTotalDiameterMax").connect("value_changed", self, "_on_setting_changed")
	find_node("RotateFixed").connect("toggled", self, "_on_setting_changed")
	find_node("DesignPixelMode").connect("toggled", self, "_on_setting_changed")

	find_node("AddSlotButton").connect("pressed", self, "_on_AddSlotButton_pressed")
	find_node("RemoveSlotButton").connect("pressed", self, "_on_RemoveSlotButton_pressed")

	find_node("MirrorX").connect("toggled", self, "_on_design_tool_toggled")
	find_node("MirrorY").connect("toggled", self, "_on_design_tool_toggled")
	find_node("CanvasEraser").connect("toggled", self, "_on_design_tool_toggled")
	find_node("ImportPatternButton").connect("pressed", self, "_on_import_pattern_pressed")
	find_node("ExportPatternButton").connect("pressed", self, "_on_export_pattern_pressed")
	find_node("DesignJitter").connect("value_changed", self, "_on_setting_changed")
	find_node("RotateJitter").connect("value_changed", self, "_on_setting_changed")
	find_node("SpreadJitter").connect("value_changed", self, "_on_setting_changed")

	# find_node("ImportTatButton").connect("pressed", self, "_on_import_tat_pressed")
	find_node("PatternInfoButton").connect("pressed", self, "_on_pattern_info_pressed")
	find_node("PatternInfoDialog").find_node("CloseButton").connect("pressed", self, "_on_info_close_pressed")

	var tree = find_node("SlotsTree")
	tree.connect("item_edited", self, "_on_SlotsTree_item_edited")
	tree.connect("cell_selected", self, "_on_SlotsTree_cell_selected")
	tree.connect("item_selected", self, "_on_SlotsTree_cell_selected")

func _on_design_tool_toggled(_arg):
	var canvas = find_node("DesignCanvas")
	canvas.mirror_x = find_node("MirrorX").pressed
	canvas.mirror_y = find_node("MirrorY").pressed
	canvas.eraser_mode = find_node("CanvasEraser").pressed
	canvas.update()
	save_settings()

func _on_pattern_info_pressed():
	find_node("PatternInfoDialog").popup_centered()

func _on_info_close_pressed():
	find_node("PatternInfoDialog").hide()

func _on_import_pattern_pressed():
	if OS.has_feature("HTML5"):
		print("[WARNING] PaintballSettings: importing patterns is not yet supported in web version")
		JavaScript.eval("window.alert('Importing patterns is not yet supported in web version.');")
		return

	var file_dialog = FileDialog.new()
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json ; JSON Pattern"]
	file_dialog.connect("file_selected", self, "_load_pattern_file")
	file_dialog.connect("popup_hide", file_dialog, "queue_free")
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)

func _load_pattern_file(path):
	print("[STATUS] PaintballSettings: attempting to load pattern from %s" % path)
	var file = File.new()
	if file.open(path, File.READ) == OK:
		var text = file.get_as_text()
		var json_res = JSON.parse(text)
		if json_res.error == OK:
			var data = json_res.result
			if data.has("paintballs") and data.has("slots"):
				find_node("DesignCanvas").design_paintballs = data.paintballs

				if data.slots is Array:
					design_color_slots.clear()
					for s in data.slots:
						if s.has("display_color_r"):
							s["display_color"] = Color(s["display_color_r"], s["display_color_g"], s["display_color_b"])
							s.erase("display_color_r")
							s.erase("display_color_g")
							s.erase("display_color_b")
						design_color_slots.append(s)

				if data.has("info"):
					var info = data["info"]
					find_node("PatternInfoDialog").find_node("AuthorEdit").text = info.get("author", "")
					find_node("PatternInfoDialog").find_node("WebsiteEdit").text = info.get("website", "")
					find_node("PatternInfoDialog").find_node("DescEdit").text = info.get("description", "")

				_refresh_slot_buttons()
				find_node("DesignCanvas").update()
				find_node("DesignCanvas").emit_signal("design_changed")
				print("[STATUS] PaintballSettings: loaded and applied pattern from %s" % path)
		else:
			print("[ERROR] PaintballSettings: failed to parse JSON pattern from %s" % path)
		file.close()
	else:
		print("[ERROR] PaintballSettings: failed to open pattern file for reading: %s" % path)
	
	_on_palette_changed()

func _on_clear_design_pressed():
	print("[STATUS] PaintballSettings: design canvas cleared")
	find_node("DesignCanvas").clear()
	
	design_color_slots = [
		{
			"color": "105",
			"outline_color": "244",
			"texture": "0",
			"outline_type": -1,
			"fuzz": 0,
			"group": 0,
			"anchored": true,
			"scale": 100,
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
			"scale": 100,
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
			"scale": 100,
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
			"scale": 100,
			"display_color": Color(0, 0, 1)
		}
	]
	
	# find_node("PatternInfoDialog").find_node("AuthorEdit").text = ""
	# find_node("PatternInfoDialog").find_node("WebsiteEdit").text = ""
	# find_node("PatternInfoDialog").find_node("DescEdit").text = ""
	
	_refresh_slot_buttons()
	find_node("DesignCanvas").emit_signal("design_changed")
	_on_palette_changed()

func _on_export_pattern_pressed():
	var author = find_node("PatternInfoDialog").find_node("AuthorEdit").text.strip_edges()
	var filename = "LnzLive_paintball-mode_design_"
	if not author.empty():
		filename += author.replace(" ", "_") + "_"
	filename += str(OS.get_unix_time()) + ".json"

	print("[STATUS] PaintballSettings: generating export for pattern, filename: %s" % filename)
	if OS.has_feature("HTML5"):
		var data = _get_pattern_data_dict()
		var json_string = JSON.print(data, "\t")
		var base64_content = Marshalls.raw_to_base64(json_string.to_utf8())
		var js_code = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:application/json;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + filename + """');
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
		print("[STATUS] PaintballSettings: pattern download triggered via web bridge")
	else:
		var file_dialog = FileDialog.new()
		file_dialog.window_title = "Export Stamp Pattern"
		file_dialog.mode = FileDialog.MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Pattern"]
		file_dialog.current_file = filename
		file_dialog.connect("file_selected", self, "_save_pattern_file")
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _get_pattern_data_dict() -> Dictionary:
	var data = {
		"header": "LnzLive Stampz Design",
		"info": {
			"time_generated": OS.get_datetime(),
			"author": find_node("PatternInfoDialog").find_node("AuthorEdit").text,
			"website": find_node("PatternInfoDialog").find_node("WebsiteEdit").text,
			"description": find_node("PatternInfoDialog").find_node("DescEdit").text
		},
		"paintballs": find_node("DesignCanvas").design_paintballs,
		"slots": []
	}

	for s in design_color_slots:
		var slot_copy = s.duplicate()
		if slot_copy.has("display_color") and slot_copy["display_color"] is Color:
			var col = slot_copy["display_color"]
			slot_copy["display_color_r"] = col.r
			slot_copy["display_color_g"] = col.g
			slot_copy["display_color_b"] = col.b
			slot_copy.erase("display_color")
		data.slots.append(slot_copy)
	return data

func _save_pattern_file(path):
	var data = _get_pattern_data_dict()
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(JSON.print(data, "\t"))
		file.close()
		print("[STATUS] PaintballSettings: saved pattern file to %s" % path)
	else:
		print("[ERROR] PaintballSettings: failed to open file for saving pattern to %s" % path)

func _on_brush_size_changed(value):
	find_node("DesignCanvas").brush_size = value
	find_node("BrushSizeLabel").text = "Brush Size (" + str(value) + "%)"

func _on_brush_space_changed(value):
	find_node("DesignCanvas").brush_spacing = value
	find_node("BrushSpaceLabel").text = "Brush Spacing (" + str(value) + "%)"

func _refresh_slot_buttons():
	_populate_slots_tree()
	find_node("DesignCanvas").slot_data_ref = design_color_slots
	find_node("DesignCanvas").update()

func _setup_slots_tree():
	var tree = find_node("SlotsTree")
	tree.set_column_titles_visible(true)
	tree.columns = 9
	tree.set_column_title(0, "Color")
	tree.set_column_title(1, "Col")
	tree.set_column_title(2, "OutCol")
	tree.set_column_title(3, "Tex")
	tree.set_column_title(4, "Out")
	tree.set_column_title(5, "Fuzz")
	tree.set_column_title(6, "Grp")
	tree.set_column_title(7, "Anc")
	tree.set_column_title(8, "Scale")

	tree.set_column_expand(0, false)
	tree.set_column_min_width(0, 40)

	tree.set_column_expand(7, false)
	tree.set_column_min_width(7, 30)

	tree.set_column_expand(8, false)
	tree.set_column_min_width(8, 60)

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
		var icon = _create_color_icon(slot.color)
		if icon:
			var img_data = icon.get_data()
			img_data.lock()
			slot.display_color = img_data.get_pixel(0, 0)
			img_data.unlock()
			item.set_icon(0, icon)
		else:
			var default_icon = _create_color_icon(slot.display_color)
			item.set_icon(0, default_icon)
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

		# Col 8: Scale (Range %)
		item.set_cell_mode(8, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(8, 1, 500, 1)
		item.set_range(8, slot.get("scale", 100))
		item.set_editable(8, true)

		item.set_metadata(0, i)

func get_color_preview_icon(color_index: int) -> ImageTexture:
	var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if not pet_node: return null
	if pet_node.has_method("generate_color_icon"):
		return pet_node.generate_color_icon(color_index)
	return null

func _create_color_icon(color_str) -> Texture:
	if typeof(color_str) == TYPE_COLOR:
		var img = Image.new()
		img.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(color_str)
		var tex = ImageTexture.new()
		tex.create_from_image(img)
		return tex

	var color_list = LnzLiveUtils.parse_number_list(str(color_str))
	if color_list and color_list.size() > 0:
		var icon = get_color_preview_icon(color_list[0])
		if icon:
			return icon

	# Fallback
	var img = Image.new()
	img.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.white)
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
	design_color_slots[idx].scale = int(item.get_range(8))

	if col == 1:
		var new_icon = _create_color_icon(design_color_slots[idx].color)
		item.set_icon(0, new_icon)
		if new_icon:
			var img_data = new_icon.get_data()
			img_data.lock()
			design_color_slots[idx].display_color = img_data.get_pixel(0, 0)
			img_data.unlock()
			item.set_icon(0, new_icon)

	save_settings()
	_on_palette_changed()
#	update_preview()

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
	print("[STATUS] PaintballSettings: adding new color slot")
	var new_slot = {
		"color": "255",
		"outline_color": "244",
		"texture": "0",
		"outline_type": -1,
		"fuzz": 0,
		"group": 0,
		"anchored": true,
		"scale": 100,
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
		print("[WARNING] PaintballSettings: cannot remove slot, minimum of 1 slot required")
		return

	print("[STATUS] PaintballSettings: removing color slot index %d" % idx)
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

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("[WARNING] PaintballSettings: error loading existing settings config for save: ", err)
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
	config.set_value("DesignMode", "design_total_diameter", find_node("DesignTotalDiameter").value)
	config.set_value("DesignMode", "design_total_diameter_max", find_node("DesignTotalDiameterMax").value)
	config.set_value("DesignMode", "design_pixel_mode", find_node("DesignPixelMode").pressed)
	config.set_value("DesignMode", "color_slots_v2", design_color_slots)

	config.set_value("DesignMode", "mirror_x", find_node("MirrorX").pressed)
	config.set_value("DesignMode", "mirror_y", find_node("MirrorY").pressed)
	config.set_value("DesignMode", "canvas_eraser", find_node("CanvasEraser").pressed)
	config.set_value("DesignMode", "design_jitter", find_node("DesignJitter").value)
	config.set_value("DesignMode", "rotate_jitter", find_node("RotateJitter").value)
	config.set_value("DesignMode", "rotate_fixed", find_node("RotateFixed").pressed)
	config.set_value("DesignMode", "spread_jitter", find_node("SpreadJitter").value)

	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("[ERROR] PaintballSettings: failed to save config to %s (Error: %s)" % [SETTINGS_PATH, save_err])
	else:
		pass # Optionally enable for super noisy debug: print("[STATUS] PaintballSettings: configuration auto-saved")

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		print("[WARNING] PaintballSettings: could not load config from %s, using defaults (Error: %d)" % [SETTINGS_PATH, err])
		return

	print("[STATUS] PaintballSettings: loading settings configuration")
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
	find_node("DesignTotalDiameter").value = config.get_value("DesignMode", "design_total_diameter", 20.0)
	find_node("DesignTotalDiameterMax").value = config.get_value("DesignMode", "design_total_diameter_max", 30.0)
	find_node("DesignPixelMode").pressed = config.get_value("DesignMode", "design_pixel_mode", false)
	find_node("DesignCanvas").brush_size = find_node("BrushSizeSlider").value
	find_node("BrushSizeLabel").text = "Brush Size (" + str(find_node("BrushSizeSlider").value) + "%)"
	find_node("BrushSpaceLabel").text = "Brush Spacing (" + str(find_node("BrushSpaceSlider").value) + "%)"


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

	find_node("MirrorX").pressed = config.get_value("DesignMode", "mirror_x", false)
	find_node("MirrorY").pressed = config.get_value("DesignMode", "mirror_y", false)
	find_node("CanvasEraser").pressed = config.get_value("DesignMode", "canvas_eraser", false)
	find_node("DesignJitter").value = config.get_value("DesignMode", "design_jitter", 0.0)
	find_node("RotateJitter").value = config.get_value("DesignMode", "rotate_jitter", 0.0)
	find_node("RotateFixed").pressed = config.get_value("DesignMode", "rotate_fixed", false)
	find_node("SpreadJitter").value = config.get_value("DesignMode", "spread_jitter", 0.0)

	_on_design_tool_toggled(null)

	_refresh_slot_buttons()
	_is_loading_settings = false
	_on_palette_changed()

func _on_reset_defaults_pressed():
	print("[STATUS] PaintballSettings: resetting to default settings")
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

	find_node("MirrorX").pressed = false
	find_node("MirrorY").pressed = false
	find_node("CanvasEraser").pressed = false
	find_node("DesignJitter").value = 0.0
	find_node("RotateFixed").pressed = false

	find_node("DesignCanvas").clear()
	find_node("BrushSizeSlider").value = 30.0
	find_node("DesignTotalDiameter").value = 20.0
	find_node("DesignTotalDiameterMax").value = 30.0
	find_node("DesignPixelMode").pressed = false

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
	_on_design_tool_toggled(null)

	_is_loading_settings = false
	save_settings()
	_on_palette_changed()
