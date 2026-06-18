extends Control

signal recolor(recolor_info)
signal apply_bucket(ball_no, properties)
signal apply_batch_bucket(changes)

onready var swap_scroll = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/ScrollContainer
onready var swap_lines_container = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/ScrollContainer/RecolorLines
onready var bucket_container = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer

onready var color_swap_check_container = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/CheckContainer

onready var bucket_color_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/ColorEdit
onready var bucket_outline_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/OutlineEdit
onready var bucket_type_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/TypeEdit
onready var bucket_fuzz_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/FuzzEdit
onready var bucket_texture_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/TextureEdit

onready var bucket_color_icon = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/ColorIcon
onready var bucket_outline_icon = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/OutlineIcon
onready var bucket_texture_icon = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/TextureIcon

var recolor_line_scene = preload("res://scenes/editor/RecolorLine.tscn")
var queued_bucket_changes = {} # ball_no -> properties

var dog_generator = null
var cached_palette_colors = []

var is_docked = false

func _ready():
	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_palette_changed")

	_setup_swap_lines()

	_setup_grid_preview(bucket_color_edit, bucket_color_icon, "BucketColor")
	_setup_grid_preview(bucket_outline_edit, bucket_outline_icon, "BucketOutline")

	bucket_texture_edit.connect("text_changed", self, "_on_bucket_property_changed")

	$VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/ApplyButton.connect("pressed", self, "_on_ApplyBucket_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/ClearButton.connect("pressed", self, "_on_ClearBucket_pressed")

	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/RecolorButton.connect("pressed", self, "_on_RecolorButton_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/AddButton.connect("pressed", self, "_on_AddSwap_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/ClearButton.connect("pressed", self, "_on_ClearSwap_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/AutofillButton.connect("pressed", self, "_on_AutofillSwap_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/RandomizeButton.connect("pressed", self, "_on_RandomizeSwap_pressed")

	_on_palette_changed()

func set_docked(docked: bool):
	is_docked = docked

func _setup_swap_lines():
	for i in range(3):
		_add_swap_line()

func _add_swap_line() -> Control:
	var line = recolor_line_scene.instance()
	swap_lines_container.add_child(line)
	var id = line.get_instance_id()
	line.name = "Line_" + str(id)
	
	var before_color = line.get_node("BeforeColor")
	var after_color = line.get_node("AfterColor")
	
	_setup_preview_wrapper(before_color, "BeforeColor_" + str(id))
	_setup_preview_wrapper(after_color, "AfterColor_" + str(id))
	
	var remove_btn = line.get_node_or_null("RemoveButton")
	if remove_btn:
		remove_btn.connect("pressed", self, "_on_remove_line_pressed", [line])

	return line

func _on_AddSwap_pressed():
	_add_swap_line()

func _on_remove_line_pressed(line: Control):
	if swap_lines_container.get_child_count() > 1:
		line.queue_free()
	else:
		line.find_node("BeforeColor", true, false).text = ""
		line.find_node("BeforeTexture", true, false).text = ""
		line.find_node("AfterColor", true, false).text = ""
		line.find_node("AfterTexture", true, false).text = ""
		line.find_node("ColorRampCheck", true, false).pressed = false
		_refresh_all_previews()

func _on_bucket_property_changed(new_text):
	var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if pet_node and bucket_texture_edit.text != "":
		var tex_idx = int(bucket_texture_edit.text)
		if pet_node.lnz and pet_node.lnz.texture_list:
			var tex = pet_node.load_texture_from_list(tex_idx, pet_node.lnz.texture_list)
			bucket_texture_icon.texture = tex
	else:
		bucket_texture_icon.texture = null

func _setup_preview_wrapper(le: LineEdit, le_name: String):
	if not le: return
	var parent = le.get_parent()

	var hbox = HBoxContainer.new()
	hbox.name = le_name + "Wrapper"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pos = le.get_index()
	var orig_owner = le.owner
	
	parent.remove_child(le)
	parent.add_child(hbox)
	
	if orig_owner != null:
		hbox.owner = orig_owner
	
	parent.move_child(hbox, pos)

	hbox.add_child(le)
	if orig_owner != null:
		le.owner = orig_owner
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var preview_container = HBoxContainer.new()
	preview_container.name = le_name + "_Preview"
	hbox.add_child(preview_container)
	if orig_owner != null:
		preview_container.owner = orig_owner

	if not le.is_connected("text_changed", self, "_on_color_list_text_changed"):
		le.connect("text_changed", self, "_on_color_list_text_changed", [preview_container])

func _setup_grid_preview(le: LineEdit, icon_node: TextureRect, le_name: String):
	if not is_instance_valid(icon_node): return
	var parent = icon_node.get_parent()
	var pos = icon_node.get_index()
	var orig_owner = icon_node.owner
	
	var preview_container = HBoxContainer.new()
	preview_container.name = le_name + "_Preview"
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	parent.add_child(preview_container)
	parent.move_child(preview_container, pos)
	
	if orig_owner != null:
		preview_container.owner = orig_owner
		
	icon_node.queue_free() 
	
	if not le.is_connected("text_changed", self, "_on_color_list_text_changed"):
		le.connect("text_changed", self, "_on_color_list_text_changed", [preview_container])

func _on_color_list_text_changed(new_text: String, container: Container):
	LnzLiveUtils.update_color_list_previews(container, new_text, cached_palette_colors)

func _refresh_all_previews():
	var grid = bucket_color_edit.get_parent()
	
	var bucket_c_prev = grid.get_node_or_null("BucketColor_Preview")
	if bucket_c_prev: _on_color_list_text_changed(bucket_color_edit.text, bucket_c_prev)
	
	var bucket_o_prev = grid.get_node_or_null("BucketOutline_Preview")
	if bucket_o_prev: _on_color_list_text_changed(bucket_outline_edit.text, bucket_o_prev)
	
	for i in range(swap_lines_container.get_child_count()):
		var line = swap_lines_container.get_child(i)
		if line.is_queued_for_deletion(): continue
		var id = line.name.replace("Line_", "")
		
		var bc = line.get_node_or_null("BeforeColor_" + str(id) + "Wrapper/BeforeColor")
		var bc_prev = line.get_node_or_null("BeforeColor_" + str(id) + "Wrapper/BeforeColor_" + str(id) + "_Preview")
		if bc and bc_prev: _on_color_list_text_changed(bc.text, bc_prev)

		var ac = line.get_node_or_null("AfterColor_" + str(id) + "Wrapper/AfterColor")
		var ac_prev = line.get_node_or_null("AfterColor_" + str(id) + "Wrapper/AfterColor_" + str(id) + "_Preview")
		if ac and ac_prev: _on_color_list_text_changed(ac.text, ac_prev)

func _on_palette_changed(palette_name = ""):
	if not dog_generator or not dog_generator.current_palette_texture:
		return
		
	var img = dog_generator.current_palette_texture.get_data()
	if img == null:
		return
		
	img.lock()
	var img_width = img.get_width()
	var img_height = img.get_height()
	
	cached_palette_colors.clear()
	for i in range(256):
		var x = i % img_width
		var y = i / img_width
		if x < img_width and y < img_height:
			cached_palette_colors.append(img.get_pixel(x, y))
		else:
			cached_palette_colors.append(Color.black)
			
	img.unlock()
	_refresh_all_previews()

func queue_bucket_change(ball_node):
	if not is_instance_valid(ball_node): return
	var ball_no = ball_node.ball_no

	var props = {
		"apply_ballz": true,
		"apply_paintballz": false
	}

	if bucket_color_edit.text != "": props["color_index"] = int(bucket_color_edit.text)
	if bucket_outline_edit.text != "": props["outline_color_index"] = int(bucket_outline_edit.text)
	if bucket_type_edit.text != "": props["outline"] = int(bucket_type_edit.text)
	if bucket_fuzz_edit.text != "": props["fuzz"] = int(bucket_fuzz_edit.text)
	if bucket_texture_edit.text != "": props["texture_id"] = int(bucket_texture_edit.text)

	queued_bucket_changes[ball_no] = props

	if props.has("color_index"): ball_node.color_index = props.color_index
	if props.has("outline_color_index"): ball_node.outline_color_index = props.outline_color_index
	if props.has("outline"): ball_node.outline = props.outline
	if props.has("fuzz"): ball_node.fuzz_amount = props.fuzz
	if props.has("texture_id"):
		var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
		if pet_node and pet_node.lnz and pet_node.lnz.texture_list:
			var tex = pet_node.load_texture_from_list(props.texture_id, pet_node.lnz.texture_list)
			if tex: ball_node.texture = tex

	if ball_node.has_method("update_ball"):
		ball_node.update_ball()

func _on_ClearBucket_pressed():
	clear_buckets()

func clear_buckets():
	var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if pet_node and pet_node.has_method("restore_ball_visual_states"):
		pet_node.restore_ball_visual_states(queued_bucket_changes.keys())
	
	queued_bucket_changes.clear()

func _on_ApplyBucket_pressed():
	if not queued_bucket_changes.empty():
		emit_signal("apply_batch_bucket", queued_bucket_changes.duplicate())
		queued_bucket_changes.clear()

func _on_RecolorButton_pressed():
	if not queued_bucket_changes.empty():
		_on_ApplyBucket_pressed()

	var lines = swap_lines_container.get_children()
	var recolor_info = {recolors = []}
	for l in lines:
		if l.is_queued_for_deletion(): continue
		var before_color = l.find_node("BeforeColor", true, false).text
		var before_texture = l.find_node("BeforeTexture", true, false).text
		var after_color = l.find_node("AfterColor", true, false).text
		var after_texture = l.find_node("AfterTexture", true, false).text
		var is_ramp = l.find_node("ColorRampCheck", true, false).pressed

		if before_color.empty() and before_texture.empty():
			continue
		if after_color.empty() and after_texture.empty():
			continue

		recolor_info.recolors.append({
			"before_color": before_color,
			"before_texture": before_texture,
			"after_color": after_color,
			"after_texture": after_texture,
			"is_ramp": is_ramp
		})

	var balls_on = color_swap_check_container.get_node("Balls").pressed
	var ball_outlines_on = color_swap_check_container.get_node("Ball outlines").pressed
	var paintballs_on = color_swap_check_container.get_node("Paintballs").pressed
	var lines_on = color_swap_check_container.get_node("Lines").pressed

	var polygons_on = color_swap_check_container.get_parent().get_node("CheckContainer2/Polygons").pressed

	recolor_info.balls_on = balls_on
	recolor_info.ball_outlines_on = ball_outlines_on
	recolor_info.paintballs_on = paintballs_on
	recolor_info.lines_on = lines_on
	recolor_info.polygons_on = polygons_on

	emit_signal("recolor", recolor_info)

func _on_ClearSwap_pressed():
	var lines = swap_lines_container.get_children()
	for l in lines:
		if l.is_queued_for_deletion(): continue
		l.find_node("BeforeColor", true, false).text = ""
		l.find_node("BeforeTexture", true, false).text = ""
		l.find_node("AfterColor", true, false).text = ""
		l.find_node("AfterTexture", true, false).text = ""
		l.find_node("ColorRampCheck", true, false).pressed = false

	for cb in color_swap_check_container.get_children():
		if cb is CheckBox or cb is Button:
			if cb.has_method("set_pressed"):
				cb.pressed = true

	var check_container_2 = color_swap_check_container.get_parent().get_node("CheckContainer2")
	if check_container_2:
		for cb in check_container_2.get_children():
			if cb is CheckBox:
				cb.pressed = true
				
	_refresh_all_previews()

func _on_AutofillSwap_pressed():
	var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if not is_instance_valid(lnz_text_edit): return

	var pair_counts = {}
	_process_section_for_autofill(lnz_text_edit, "[Ballz Info]", 0, 7, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Add Ball]", 4, 13, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Paint Ballz]", 5, 10, pair_counts)

	var sorted_pairs = []
	for key in pair_counts:
		sorted_pairs.append({"key": key, "count": pair_counts[key]})

	sorted_pairs.sort_custom(self, "_sort_by_count")

	var needed_lines = sorted_pairs.size()
	if needed_lines == 0:
		needed_lines = 1
		
	var lines = swap_lines_container.get_children()
	
	# Add if missing
	while lines.size() < needed_lines:
		var l = _add_swap_line()
		lines.append(l)
		
	# Remove if too many
	while lines.size() > needed_lines:
		var l = lines.pop_back()
		l.queue_free()

	for i in range(lines.size()):
		var line_node = lines[i]
		if line_node.is_queued_for_deletion(): continue
		if i < sorted_pairs.size():
			var pair = sorted_pairs[i].key.split(",")
			line_node.find_node("BeforeColor", true, false).text = pair[0]
			line_node.find_node("BeforeTexture", true, false).text = pair[1]
			line_node.find_node("AfterColor", true, false).text = ""
			line_node.find_node("AfterTexture", true, false).text = ""
		else:
			line_node.find_node("BeforeColor", true, false).text = ""
			line_node.find_node("BeforeTexture", true, false).text = ""
			line_node.find_node("AfterColor", true, false).text = ""
			line_node.find_node("AfterTexture", true, false).text = ""
			
		line_node.find_node("ColorRampCheck", true, false).pressed = false
		
	_refresh_all_previews()

func _process_section_for_autofill(lnz_text_edit, section_name, color_idx, texture_idx, pair_counts):
	var bounds = lnz_text_edit.get_section_bounds(section_name)
	if bounds.empty(): return

	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var parts = lnz_text_edit.split_line(line)
		if parts.size() > max(color_idx, texture_idx):
			var color = parts[color_idx]
			var texture = parts[texture_idx]
			var key = color + "," + texture
			if not pair_counts.has(key): pair_counts[key] = 0
			pair_counts[key] += 1

func _sort_by_count(a, b):
	return a.count > b.count

func _on_RandomizeSwap_pressed():
	randomize()
	var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if not is_instance_valid(lnz_text_edit): return

	var max_texture_id = -1
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Ballz Info]", 7, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Add Ball]", 13, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Paint Ballz]", 10, max_texture_id)

	if max_texture_id == -1: max_texture_id = 0

	var lines = swap_lines_container.get_children()

	for l in lines:
		if l.is_queued_for_deletion(): continue
		var after_color_edit = l.find_node("AfterColor", true, false)
		var after_texture_edit = l.find_node("AfterTexture", true, false)
		var is_ramp = l.find_node("ColorRampCheck", true, false).pressed

		var random_color
		if is_ramp:
			random_color = (randi() % 14 + 1) * 10
		else:
			random_color = randi() % (215 - 10 + 1) + 10

		after_color_edit.text = str(random_color)

		var random_texture = randi() % (max_texture_id + 1)
		after_texture_edit.text = str(random_texture)

	_refresh_all_previews()

func _find_max_texture_for_randomize(lnz_text_edit, section_name, texture_idx, current_max):
	var bounds = lnz_text_edit.get_section_bounds(section_name)
	if bounds.empty(): return current_max

	var new_max = current_max
	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var parts = lnz_text_edit.split_line(line)
		if parts.size() > texture_idx:
			var texture_str = parts[texture_idx]
			if texture_str.is_valid_integer():
				var texture_id = int(texture_str)
				if texture_id > new_max:
					new_max = texture_id
	return new_max