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

var is_docked = false

func _ready():
	_setup_swap_lines()

	bucket_color_edit.connect("text_changed", self, "_on_bucket_property_changed")
	bucket_outline_edit.connect("text_changed", self, "_on_bucket_property_changed")
	bucket_texture_edit.connect("text_changed", self, "_on_bucket_property_changed")

	$VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/ApplyButton.connect("pressed", self, "_on_ApplyBucket_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/ClearButton.connect("pressed", self, "_on_ClearBucket_pressed")

	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/RecolorButton.connect("pressed", self, "_on_RecolorButton_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/ClearButton.connect("pressed", self, "_on_ClearSwap_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/AutofillButton.connect("pressed", self, "_on_AutofillSwap_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header/RandomizeButton.connect("pressed", self, "_on_RandomizeSwap_pressed")

func set_docked(docked: bool):
	is_docked = docked

func _setup_swap_lines():
	for i in range(9):
		var line = recolor_line_scene.instance()
		line.name = "Line" + str(i+1)
		swap_lines_container.add_child(line)

func get_color_preview_icon(color_index: int) -> ImageTexture:
	var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if not pet_node: return null

	if pet_node.has_method("generate_color_icon"):
		return pet_node.generate_color_icon(color_index)

	return null

func _on_bucket_property_changed(new_text):
	var color_idx = int(bucket_color_edit.text)
	var icon = get_color_preview_icon(color_idx)
	if icon:
		bucket_color_icon.texture = icon
	else:
		bucket_color_icon.texture = null

	var outline_idx = int(bucket_outline_edit.text)
	var o_icon = get_color_preview_icon(outline_idx)
	if o_icon:
		bucket_outline_icon.texture = o_icon
	else:
		bucket_outline_icon.texture = null

	var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if pet_node and bucket_texture_edit.text != "":
		var tex_idx = int(bucket_texture_edit.text)
		if pet_node.lnz and pet_node.lnz.texture_list:
			var tex = pet_node.load_texture_from_list(tex_idx, pet_node.lnz.texture_list)
			bucket_texture_icon.texture = tex
	else:
		bucket_texture_icon.texture = null

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
		var before_color = l.get_node("BeforeColor").text
		var before_texture = l.get_node("BeforeTexture").text
		var after_color = l.get_node("AfterColor").text
		var after_texture = l.get_node("AfterTexture").text
		var is_ramp = l.get_node("ColorRampCheck").pressed

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
		l.get_node("BeforeColor").text = ""
		l.get_node("BeforeTexture").text = ""
		l.get_node("AfterColor").text = ""
		l.get_node("AfterTexture").text = ""

	for cb in color_swap_check_container.get_children():
		if cb is CheckBox or cb is Button:
			if cb.has_method("set_pressed"):
				cb.pressed = true

	var check_container_2 = color_swap_check_container.get_parent().get_node("CheckContainer2")
	if check_container_2:
		for cb in check_container_2.get_children():
			if cb is CheckBox:
				cb.pressed = true

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

	var lines = swap_lines_container.get_children()

	for i in range(lines.size()):
		var line_node = lines[i]
		if i < sorted_pairs.size():
			var pair = sorted_pairs[i].key.split(",")
			line_node.get_node("BeforeColor").text = pair[0]
			line_node.get_node("BeforeTexture").text = pair[1]
			line_node.get_node("AfterColor").text = ""
			line_node.get_node("AfterTexture").text = ""
		else:
			line_node.get_node("BeforeColor").text = ""
			line_node.get_node("BeforeTexture").text = ""
			line_node.get_node("AfterColor").text = ""
			line_node.get_node("AfterTexture").text = ""

func _process_section_for_autofill(lnz_text_edit, section_name, color_idx, texture_idx, pair_counts):
	var bounds = lnz_text_edit._get_section_bounds(section_name)
	if bounds.empty(): return

	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var parts = lnz_text_edit._split_line(line)
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
		var after_color_edit = l.get_node("AfterColor")
		var after_texture_edit = l.get_node("AfterTexture")
		var is_ramp = l.get_node("ColorRampCheck").pressed

		var random_color
		if is_ramp:
			random_color = (randi() % 14 + 1) * 10
		else:
			random_color = randi() % (215 - 10 + 1) + 10

		after_color_edit.text = str(random_color)

		var random_texture = randi() % (max_texture_id + 1)
		after_texture_edit.text = str(random_texture)

func _find_max_texture_for_randomize(lnz_text_edit, section_name, texture_idx, current_max):
	var bounds = lnz_text_edit._get_section_bounds(section_name)
	if bounds.empty(): return current_max

	var new_max = current_max
	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var parts = lnz_text_edit._split_line(line)
		if parts.size() > texture_idx:
			var texture_str = parts[texture_idx]
			if texture_str.is_valid_integer():
				var texture_id = int(texture_str)
				if texture_id > new_max:
					new_max = texture_id
	return new_max
