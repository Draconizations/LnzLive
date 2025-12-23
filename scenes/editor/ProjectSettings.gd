extends DraggablePanel
## ProjectSettings.gd
## Manages the UI panel and logic for the Project Mode settings
## This script combines two key LNZ editing features:
## 1. Project Ball Editor (`[Project Ball]`)
## Controls a Tree UI for creating and editing ball projections. It provides methods to:
## - Load: Copy existing projections from the LNZ or load defaults based on species
## - Edit: Add, remove, reorder, lock, and edit projection values (Fixed/Project Ball, Min/Max/Value)
## - Randomize: Generate random projection values within the defined Min/Max range, respecting locked or mirrored projections
## - Apply: Gather all projections (and auto-generate symmetrical mirrors if needed) and emit the `apply_projections` signal
## 2. Body Proportion Randomizer
## Manages UI spinboxes for defining Min/Max ranges for LNZ body proportion sections (e.g., `[Leg Extension]`, `[Head Enlargement]`)
## and emits the `randomize_body_proportions` signal to apply random values within those ranges

signal apply_projections(projections)
signal randomize_body_proportions(settings)

var _is_loading_settings = false

onready var projections_tree = find_node("ProjectionsTree")

func _ready():
	# Connect signals
	find_node("AddButton").connect("pressed", self, "_on_AddButton_pressed")
	find_node("RemoveButton").connect("pressed", self, "_on_RemoveButton_pressed")
	find_node("ClearAllButton").connect("pressed", self, "_on_ClearAllButton_pressed")
	find_node("RestoreDefaultsButton").connect("pressed", self, "_on_RestoreDefaultsButton_pressed")
	find_node("CopyFromLNZButton").connect("pressed", self, "_on_CopyFromLNZButton_pressed")
	find_node("RandomizeProjectionsButton").connect("pressed", self, "_on_RandomizeProjectionsButton_pressed")
	find_node("RandomizeBodyButton").connect("pressed", self, "_on_RandomizeBodyButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("MoveUpButton").connect("pressed", self, "_on_MoveUpButton_pressed")
	find_node("MoveDownButton").connect("pressed", self, "_on_MoveDownButton_pressed")
	projections_tree.connect("item_edited", self, "_on_ProjectionsTree_item_edited")
	projections_tree.connect("button_pressed", self, "_on_ProjectionsTree_button_pressed")
	projections_tree.connect("column_title_pressed", self, "_on_ProjectionsTree_column_title_pressed")

	# Setup Tree
	projections_tree.set_column_titles_visible(true)
	projections_tree.set_column_title(0, "Fixed")
	projections_tree.set_column_title(1, "Project")
	projections_tree.set_column_title(2, "Min")
	projections_tree.set_column_title(3, "Max")
	projections_tree.set_column_title(4, "Value")
	projections_tree.set_column_title(5, "Lock")
	projections_tree.set_column_title(6, "Mirror")
	projections_tree.set_column_title(7, "Label")
	projections_tree.set_column_title(8, "")

	# Hide by default
	hide()

	var viewport_size = get_viewport().size
	var panel = self
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)

	_connect_settings_signals()
	load_settings()

func _populate_projections_tree():
	projections_tree.clear()
	var root = projections_tree.create_item()

	var species_key = ""
	var species = KeyBallsData.species
	if species == KeyBallsData.Species.DOG:
		species_key = "dog"
	elif species == KeyBallsData.Species.CAT:
		species_key = "cat"
	elif species == KeyBallsData.Species.BABY:
		species_key = "bab"

	if KeyBallsData.projection_standards.has(species_key):
		var standards = KeyBallsData.projection_standards[species_key]
		for proj_data in standards:
			var item = projections_tree.create_item(root)
			item.set_editable(0, true)
			item.set_editable(1, true)
			item.set_editable(2, true)
			item.set_editable(3, true)
			item.set_editable(4, true)
			item.set_cell_mode(5, TreeItem.CELL_MODE_CHECK)
			item.set_editable(5, true)
			item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
			item.set_editable(6, true)
			item.set_editable(7, true)
			# item.add_button(8, load("res://resources/icons/ico_tool_eraser_2x.png"), 0)

			item.set_text(0, str(proj_data.fixed_ball))
			item.set_text(1, str(proj_data.project_ball))
			item.set_text(2, str(proj_data.min_projection))
			item.set_text(3, str(proj_data.max_projection))
			item.set_text(4, "0")
			item.set_checked(5, false)
			item.set_checked(6, false)
			item.set_text(7, proj_data.comment)

func _on_AddButton_pressed():
	var root = projections_tree.get_root()
	if not root:
		root = projections_tree.create_item()
	var item = projections_tree.create_item(root)
	item.set_editable(0, true)
	item.set_editable(1, true)
	item.set_editable(2, true)
	item.set_editable(3, true)
	item.set_editable(4, true)
	item.set_cell_mode(5, TreeItem.CELL_MODE_CHECK)
	item.set_editable(5, true)
	item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
	item.set_editable(6, true)
	item.set_editable(7, true)
	# item.add_button(8, load("res://resources/icons/ico_tool_eraser_2x.png"), 0)

	item.set_text(0, "0")
	item.set_text(1, "0")
	item.set_text(2, "0")
	item.set_text(3, "100")
	item.set_text(4, "0")
	item.set_checked(5, false)
	item.set_checked(6, false)
	item.set_text(7, "comment")

func _on_RemoveButton_pressed():
	var selected = projections_tree.get_selected()
	if selected:
		selected.free()

func _swap_tree_items(item1, item2):
	for i in range(projections_tree.columns):
		var text1 = item1.get_text(i)
		var text2 = item2.get_text(i)
		item1.set_text(i, text2)
		item2.set_text(i, text1)

		if item1.get_cell_mode(i) == TreeItem.CELL_MODE_CHECK:
			var checked1 = item1.is_checked(i)
			var checked2 = item2.is_checked(i)
			item1.set_checked(i, checked2)
			item2.set_checked(i, checked1)

func _on_MoveUpButton_pressed():
	var selected = projections_tree.get_selected()
	if selected and selected.get_prev():
		_swap_tree_items(selected, selected.get_prev())
		projections_tree.select(selected.get_prev(), 0)

func _on_MoveDownButton_pressed():
	var selected = projections_tree.get_selected()
	if selected and selected.get_next():
		_swap_tree_items(selected, selected.get_next())
		projections_tree.select(selected.get_next(), 0)

func _on_ClearAllButton_pressed():
	projections_tree.clear()
	projections_tree.create_item() # Create root

func _on_RestoreDefaultsButton_pressed():
	_populate_projections_tree()

func _on_CopyFromLNZButton_pressed():
	var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/LnzTextEdit")
	var projections = lnz_text_edit.get_project_ball_section()

	projections_tree.clear()
	var root = projections_tree.create_item()

	for proj_data in projections:
		var item = projections_tree.create_item(root)
		item.set_editable(0, true)
		item.set_editable(1, true)
		item.set_editable(2, true)
		item.set_editable(3, true)
		item.set_editable(4, true)
		item.set_cell_mode(5, TreeItem.CELL_MODE_CHECK)
		item.set_editable(5, true)
		item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
		item.set_editable(6, true)
		item.set_editable(7, true)
		# item.add_button(8, load("res://resources/icons/ico_tool_eraser_2x.png"), 0)

		item.set_text(0, str(proj_data.fixed_ball))
		item.set_text(1, str(proj_data.project_ball))
		item.set_text(2, str(proj_data.min_projection))
		item.set_text(3, str(proj_data.max_projection))
		item.set_text(4, str( (proj_data.min_projection + proj_data.max_projection) / 2) )
		item.set_checked(5, false)
		item.set_checked(6, false)
		item.set_text(7, proj_data.comment)


func _on_ProjectionsTree_button_pressed(item, column, id):
	if column == 8: # Delete button
		item.free()

func _on_ProjectionsTree_item_edited():
	# This is mainly to handle the checkbox
	var item = projections_tree.get_edited()
	var column = projections_tree.get_edited_column()
	if column == 5 or column == 6: # Lock or Mirrored checkbox
		# The checked state is automatically updated by the tree
		pass

func _on_RandomizeProjectionsButton_pressed():
	randomize()
	var root = projections_tree.get_root()
	if not root:
		return

	var species = KeyBallsData.species
	var symmetry_dict = null
	if species == KeyBallsData.Species.DOG:
		symmetry_dict = KeyBallsData.dog_body_part_symmetry
	elif species == KeyBallsData.Species.CAT:
		symmetry_dict = KeyBallsData.cat_body_part_symmetry
	elif species == KeyBallsData.Species.BABY:
		symmetry_dict = KeyBallsData.baby_body_part_symmetry

	var processed_items = []
	var all_items = []
	var item = root.get_children()
	while item:
		all_items.append(item)
		item = item.get_next()

	for item_a in all_items:
		if item_a in processed_items:
			continue

		if not item_a.is_checked(5): # if not locked
			var min_proj = item_a.get_text(2).to_int()
			var max_proj = item_a.get_text(3).to_int()
			var random_val = 0
			if min_proj < max_proj:
				random_val = randi() % (max_proj - min_proj + 1) + min_proj
			else:
				random_val = min_proj
			item_a.set_text(4, str(random_val))

		processed_items.append(item_a)

		if not symmetry_dict:
			continue

		# Find and update the mirror
		var fixed_a = item_a.get_text(0).to_int()
		var proj_a = item_a.get_text(1).to_int()

		var mirrored_fixed = KeyBallsData.get_mirrored_ball(fixed_a, symmetry_dict)
		var mirrored_proj = KeyBallsData.get_mirrored_ball(proj_a, symmetry_dict)

		if mirrored_fixed == -1: mirrored_fixed = fixed_a
		if mirrored_proj == -1: mirrored_proj = proj_a

		for item_b in all_items:
			if item_b in processed_items:
				continue

			var fixed_b = item_b.get_text(0).to_int()
			var proj_b = item_b.get_text(1).to_int()

			var is_mirror = (fixed_b == mirrored_fixed and proj_b == mirrored_proj)
			var is_swapped_mirror = (fixed_b == mirrored_proj and proj_b == mirrored_fixed)

			if is_mirror or is_swapped_mirror:
				if not item_b.is_checked(5): # if not locked
					item_b.set_text(4, item_a.get_text(4))
				processed_items.append(item_b)
				break

func _on_RandomizeBodyButton_pressed():
	var settings = {
		"leg_ext_1": { "min": find_node("LegExt1MinSpinBox").value, "max": find_node("LegExt1MaxSpinBox").value },
		"leg_ext_2": { "min": find_node("LegExt2MinSpinBox").value, "max": find_node("LegExt2MaxSpinBox").value },
		"head_enl_1": { "min": find_node("HeadEnl1MinSpinBox").value, "max": find_node("HeadEnl1MaxSpinBox").value },
		"head_enl_2": { "min": find_node("HeadEnl2MinSpinBox").value, "max": find_node("HeadEnl2MaxSpinBox").value },
		"feet_enl_1": { "min": find_node("FeetEnl1MinSpinBox").value, "max": find_node("FeetEnl1MaxSpinBox").value },
		"feet_enl_2": { "min": find_node("FeetEnl2MinSpinBox").value, "max": find_node("FeetEnl2MaxSpinBox").value },
		"scales_1": { "min": find_node("Scales1MinSpinBox").value, "max": find_node("Scales1MaxSpinBox").value },
		"scales_2": { "min": find_node("Scales2MinSpinBox").value, "max": find_node("Scales2MaxSpinBox").value },
		"body_ext": { "min": find_node("BodyExtMinSpinBox").value, "max": find_node("BodyExtMaxSpinBox").value },
		"face_ext": { "min": find_node("FaceExtMinSpinBox").value, "max": find_node("FaceExtMaxSpinBox").value },
		"ear_ext": { "min": find_node("EarExtMinSpinBox").value, "max": find_node("EarExtMaxSpinBox").value }
	}
	emit_signal("randomize_body_proportions", settings)

func _on_ApplyButton_pressed():
	var root = projections_tree.get_root()
	if not root:
		return

	var species = KeyBallsData.species
	var symmetry_dict = null
	if species == KeyBallsData.Species.DOG:
		symmetry_dict = KeyBallsData.dog_body_part_symmetry
	elif species == KeyBallsData.Species.CAT:
		symmetry_dict = KeyBallsData.cat_body_part_symmetry
	elif species == KeyBallsData.Species.BABY:
		symmetry_dict = KeyBallsData.baby_body_part_symmetry

	var lnz_projections = []
	
	# Scan to see which projections already exist
	var existing_pairs = {}
	var item = root.get_children()
	while item:
		var fixed = item.get_text(0).to_int()
		var project = item.get_text(1).to_int()
		var key = Vector2(min(fixed, project), max(fixed, project))
		existing_pairs[key] = true
		item = item.get_next()

	# Build list of projections
	item = root.get_children()
	while item:
		var fixed_ball = item.get_text(0).to_int()
		var project_ball = item.get_text(1).to_int()
		
		var proj = {
			"fixed_ball": fixed_ball,
			"project_ball": project_ball,
			"value": item.get_text(4).to_int(),
			"comment": item.get_text(7)
		}
		lnz_projections.append(proj)

		# If mirrored, create the mirrored version and add ONLY if it doesn't already exist as a separate entry
		if item.is_checked(6) and symmetry_dict:
			var mirrored_fixed_raw = KeyBallsData.get_mirrored_ball(proj.fixed_ball, symmetry_dict)
			var mirrored_project_raw = KeyBallsData.get_mirrored_ball(proj.project_ball, symmetry_dict)

			# If a ball doesn't have a mirror, it mirrors to itself
			var mirrored_fixed = mirrored_fixed_raw if mirrored_fixed_raw != -1 else proj.fixed_ball
			var mirrored_project = mirrored_project_raw if mirrored_project_raw != -1 else proj.project_ball
			
			# Check if the mirrored pair is the same as the original
			var is_self_mirrored = (mirrored_fixed == proj.fixed_ball) and (mirrored_project == proj.project_ball)
			
			if not is_self_mirrored:
				var mirror_key = Vector2(min(mirrored_fixed, mirrored_project), max(mirrored_fixed, mirrored_project))
				
				# If this mirrored pair was NOT found in our initial scan, add it
				if not existing_pairs.has(mirror_key):
					var mirrored_proj = {
						"fixed_ball": mirrored_fixed,
						"project_ball": mirrored_project,
						"value": proj.value,
						"comment": proj.comment
					}
					lnz_projections.append(mirrored_proj)
					# Add it to the set so it doesn't get added again by another mirror check
					existing_pairs[mirror_key] = true

		item = item.get_next()

	emit_signal("apply_projections", lnz_projections)


# func show():
# 	# Re-populate options in case species has changed since _ready()
# 	_populate_projections_tree()
# 	panel.show()

# func hide():
# 	panel.hide()

func _on_ProjectionsTree_column_title_pressed(column_index):
	if column_index == 5 or column_index == 6: # Lock or Mirror
		var root = projections_tree.get_root()
		if not root:
			return

		var item = root.get_children()
		if not item:
			return

		# Determine target state: if any are unchecked, check all. Otherwise, uncheck all.
		var target_state = false
		var current_item = item
		while current_item:
			if not current_item.is_checked(column_index):
				target_state = true
				break
			current_item = current_item.get_next()

		# Apply the target state to all items
		current_item = item
		while current_item:
			current_item.set_checked(column_index, target_state)
			current_item = current_item.get_next()

func _connect_settings_signals():
	var spinners = [
		"LegExt1MinSpinBox", "LegExt1MaxSpinBox",
		"LegExt2MinSpinBox", "LegExt2MaxSpinBox",
		"HeadEnl1MinSpinBox", "HeadEnl1MaxSpinBox",
		"HeadEnl2MinSpinBox", "HeadEnl2MaxSpinBox",
		"FeetEnl1MinSpinBox", "FeetEnl1MaxSpinBox",
		"FeetEnl2MinSpinBox", "FeetEnl2MaxSpinBox",
		"Scales1MinSpinBox", "Scales1MaxSpinBox",
		"Scales2MinSpinBox", "Scales2MaxSpinBox",
		"BodyExtMinSpinBox", "BodyExtMaxSpinBox",
		"FaceExtMinSpinBox", "FaceExtMaxSpinBox",
		"EarExtMinSpinBox", "EarExtMaxSpinBox"
	]

	for s in spinners:
		find_node(s).connect("value_changed", self, "_on_setting_changed")

	var reset_btn = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _on_setting_changed(_arg = null):
	if _is_loading_settings:
		return
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("ProjectProperties", "leg_ext_1_min", find_node("LegExt1MinSpinBox").value)
	config.set_value("ProjectProperties", "leg_ext_1_max", find_node("LegExt1MaxSpinBox").value)
	config.set_value("ProjectProperties", "leg_ext_2_min", find_node("LegExt2MinSpinBox").value)
	config.set_value("ProjectProperties", "leg_ext_2_max", find_node("LegExt2MaxSpinBox").value)

	config.set_value("ProjectProperties", "head_enl_1_min", find_node("HeadEnl1MinSpinBox").value)
	config.set_value("ProjectProperties", "head_enl_1_max", find_node("HeadEnl1MaxSpinBox").value)
	config.set_value("ProjectProperties", "head_enl_2_min", find_node("HeadEnl2MinSpinBox").value)
	config.set_value("ProjectProperties", "head_enl_2_max", find_node("HeadEnl2MaxSpinBox").value)

	config.set_value("ProjectProperties", "feet_enl_1_min", find_node("FeetEnl1MinSpinBox").value)
	config.set_value("ProjectProperties", "feet_enl_1_max", find_node("FeetEnl1MaxSpinBox").value)
	config.set_value("ProjectProperties", "feet_enl_2_min", find_node("FeetEnl2MinSpinBox").value)
	config.set_value("ProjectProperties", "feet_enl_2_max", find_node("FeetEnl2MaxSpinBox").value)

	config.set_value("ProjectProperties", "scales_1_min", find_node("Scales1MinSpinBox").value)
	config.set_value("ProjectProperties", "scales_1_max", find_node("Scales1MaxSpinBox").value)
	config.set_value("ProjectProperties", "scales_2_min", find_node("Scales2MinSpinBox").value)
	config.set_value("ProjectProperties", "scales_2_max", find_node("Scales2MaxSpinBox").value)

	config.set_value("ProjectProperties", "body_ext_min", find_node("BodyExtMinSpinBox").value)
	config.set_value("ProjectProperties", "body_ext_max", find_node("BodyExtMaxSpinBox").value)

	config.set_value("ProjectProperties", "face_ext_min", find_node("FaceExtMinSpinBox").value)
	config.set_value("ProjectProperties", "face_ext_max", find_node("FaceExtMaxSpinBox").value)

	config.set_value("ProjectProperties", "ear_ext_min", find_node("EarExtMinSpinBox").value)
	config.set_value("ProjectProperties", "ear_ext_max", find_node("EarExtMaxSpinBox").value)

	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving ProjectSettings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	find_node("LegExt1MinSpinBox").value = config.get_value("ProjectProperties", "leg_ext_1_min", -30.0)
	find_node("LegExt1MaxSpinBox").value = config.get_value("ProjectProperties", "leg_ext_1_max", 30.0)
	find_node("LegExt2MinSpinBox").value = config.get_value("ProjectProperties", "leg_ext_2_min", -30.0)
	find_node("LegExt2MaxSpinBox").value = config.get_value("ProjectProperties", "leg_ext_2_max", 30.0)

	find_node("HeadEnl1MinSpinBox").value = config.get_value("ProjectProperties", "head_enl_1_min", 100.0)
	find_node("HeadEnl1MaxSpinBox").value = config.get_value("ProjectProperties", "head_enl_1_max", 120.0)
	find_node("HeadEnl2MinSpinBox").value = config.get_value("ProjectProperties", "head_enl_2_min", 0.0)
	find_node("HeadEnl2MaxSpinBox").value = config.get_value("ProjectProperties", "head_enl_2_max", 0.0)

	find_node("FeetEnl1MinSpinBox").value = config.get_value("ProjectProperties", "feet_enl_1_min", 50.0)
	find_node("FeetEnl1MaxSpinBox").value = config.get_value("ProjectProperties", "feet_enl_1_max", 150.0)
	find_node("FeetEnl2MinSpinBox").value = config.get_value("ProjectProperties", "feet_enl_2_min", 0.0)
	find_node("FeetEnl2MaxSpinBox").value = config.get_value("ProjectProperties", "feet_enl_2_max", 20.0)

	find_node("Scales1MinSpinBox").value = config.get_value("ProjectProperties", "scales_1_min", 120.0)
	find_node("Scales1MaxSpinBox").value = config.get_value("ProjectProperties", "scales_1_max", 120.0)
	find_node("Scales2MinSpinBox").value = config.get_value("ProjectProperties", "scales_2_min", 100.0)
	find_node("Scales2MaxSpinBox").value = config.get_value("ProjectProperties", "scales_2_max", 100.0)

	find_node("BodyExtMinSpinBox").value = config.get_value("ProjectProperties", "body_ext_min", -20.0)
	find_node("BodyExtMaxSpinBox").value = config.get_value("ProjectProperties", "body_ext_max", 60.0)

	find_node("FaceExtMinSpinBox").value = config.get_value("ProjectProperties", "face_ext_min", -30.0)
	find_node("FaceExtMaxSpinBox").value = config.get_value("ProjectProperties", "face_ext_max", 30.0)

	find_node("EarExtMinSpinBox").value = config.get_value("ProjectProperties", "ear_ext_min", 50.0)
	find_node("EarExtMaxSpinBox").value = config.get_value("ProjectProperties", "ear_ext_max", 100.0)

	_is_loading_settings = false

func _on_reset_defaults_pressed():
	_is_loading_settings = true

	find_node("LegExt1MinSpinBox").value = -30.0
	find_node("LegExt1MaxSpinBox").value = 30.0
	find_node("LegExt2MinSpinBox").value = -30.0
	find_node("LegExt2MaxSpinBox").value = 30.0

	find_node("HeadEnl1MinSpinBox").value = 100.0
	find_node("HeadEnl1MaxSpinBox").value = 120.0
	find_node("HeadEnl2MinSpinBox").value = 0.0
	find_node("HeadEnl2MaxSpinBox").value = 0.0

	find_node("FeetEnl1MinSpinBox").value = 50.0
	find_node("FeetEnl1MaxSpinBox").value = 150.0
	find_node("FeetEnl2MinSpinBox").value = 0.0
	find_node("FeetEnl2MaxSpinBox").value = 20.0

	find_node("Scales1MinSpinBox").value = 120.0
	find_node("Scales1MaxSpinBox").value = 120.0
	find_node("Scales2MinSpinBox").value = 100.0
	find_node("Scales2MaxSpinBox").value = 100.0

	find_node("BodyExtMinSpinBox").value = -20.0
	find_node("BodyExtMaxSpinBox").value = 60.0

	find_node("FaceExtMinSpinBox").value = -30.0
	find_node("FaceExtMaxSpinBox").value = 30.0

	find_node("EarExtMinSpinBox").value = 50.0
	find_node("EarExtMaxSpinBox").value = 100.0

	_is_loading_settings = false
	save_settings()
