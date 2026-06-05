extends GutTest

var editor_scene = load("res://scenes/editor/editor.tscn")
var editor_instance: Node

var pet_node: Node
var file_tree: Tree
var lnz_text: TextEdit
var pet_view: Control

func before_all():
	editor_instance = editor_scene.instance()
	editor_instance.name = "Root" 
	get_tree().root.add_child(editor_instance)
	
	yield(get_tree(), "idle_frame")
	
	pet_node = editor_instance.get_node_or_null("PetRoot/Node")
	file_tree = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
	lnz_text = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	pet_view = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	
	assert_not_null(pet_node, "Failed to resolve pet_node")
	assert_not_null(file_tree, "Failed to resolve file_tree")
	assert_not_null(lnz_text, "Failed to resolve lnz_text")
	assert_not_null(pet_view, "Failed to resolve pet_view")
	
	if KeyBallsData.max_base_ball_num == null:
		KeyBallsData.max_base_ball_num = 67
	
	if is_instance_valid(pet_node):
			pet_node.set("pixel_world_size", 0.002)

func before_each():
	_reset_editor_state()

func after_all():
	if is_instance_valid(editor_instance):
		editor_instance.queue_free()
		yield(get_tree(), "idle_frame")

func _reset_editor_state():
	if lnz_text:
		lnz_text.text = ""
		if lnz_text.has_method("initialize_history"):
			lnz_text.initialize_history()

	if pet_view:
		if "selected_ball" in pet_view:
			if typeof(pet_view.selected_ball) == TYPE_ARRAY:
				pet_view.selected_ball.clear()
			else:
				pet_view.selected_ball = -1
				
		if "selected_balls" in pet_view:
			pet_view.selected_balls.clear()

	if pet_node:
		if pet_node.has_method("clear_balls"):
			pet_node.clear_balls()
		else:
			var petholder = pet_node.get_node_or_null("petholder")
			if petholder:
				for category in petholder.get_children():
					for child in category.get_children():
						child.free()

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
func _create_temp_lnz(content: String) -> String:
	var path = "user://gut_temp_test.lnz"
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(content)
	f.close()
	return path

# ------------------------------------------------------------------------------
# FileTree.gd
# ------------------------------------------------------------------------------
func test_filetree_expanded_states():
	if not file_tree.examples:
		file_tree.examples = file_tree.create_item()
	if not file_tree.local_storage:
		file_tree.local_storage = file_tree.create_item()
	
	var mock_states = {
		"Examples": false,
		"Local Storage": true
	}
	
	file_tree.set_expanded_states(mock_states)
	
	assert_true(file_tree.examples.collapsed, "Examples should be collapsed.")
	assert_false(file_tree.local_storage.collapsed, "Local Storage should be expanded.")
	
	var retrieved_states = file_tree.get_expanded_states()
	assert_false(retrieved_states["Examples"], "Getter should return false for Examples.")
	assert_true(retrieved_states["Local Storage"], "Getter should return true for Local Storage.")

func test_filetree_convert_bmp_invalid_file():
	# Attempting to convert a non-existent BMP
	var result = file_tree.convert_bmp_to_palette_png("user://does_not_exist_ever.bmp", "user://")
	assert_false(result, "Conversion should safely fail and return false for non-existent files.")

# ------------------------------------------------------------------------------
# lnz_parser.gd
# ------------------------------------------------------------------------------

func test_lnz_scan_base_and_variations():
	# Correctly grouping data into base and variation blocks
	var content = "[Ballz Info]\n10 10 10\n#1 Variation1\n20 20 20\n[Linez]\n1 2"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	
	assert_true(parser.sections_map.has("Ballz Info"), "Should parse Ballz Info section.")
	assert_true(parser.sections_map["Ballz Info"].has(0), "Should generate base variation (0).")
	assert_true(parser.sections_map["Ballz Info"].has(1), "Should detect variation 1.")
	
	var base_lines = parser.sections_map["Ballz Info"][0].lines
	assert_eq(base_lines[0], "10 10 10", "Base lines should be assigned to ID 0.")
	
	var var1_lines = parser.sections_map["Ballz Info"][1].lines
	assert_eq(var1_lines[0], "20 20 20", "Variation lines should be assigned to ID 1.")

func test_lnz_compile_section_merging():
	# Ensure requesting specific variations merges them with base data
	var content = "[Section]\nBaseData\n#1 Var1\nData1\n#2 Var2\nData2"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	
	# Compile with base and variation 2
	var reader = parser.compile_section("Section", [2])
	assert_eq(reader.get_len(), 2, "Reader should contain exactly 2 lines.")
	assert_eq(reader.get_line(), "BaseData", "Base data should always be included.")
	assert_eq(reader.get_line(), "Data2", "Active variation data should be appended.")

func test_lnz_get_parsed_lines_ignores_invalid_and_comments():
	# Empty lines, comments, and unparseable garbage should be ignored
	var content = "[TestSection]\n; This is a comment\n\n10 20 30\n# Ignored\n40 50 60\n\t  \n"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("TestSection", [])
	
	var parsed = parser.get_parsed_lines(reader, ["a", "b", "c"])
	assert_eq(parsed.size(), 2, "Should cleanly skip comments and empty spaces to find 2 valid lines.")
	assert_eq(parsed[0]["a"], 10)
	assert_eq(parsed[1]["c"], 60)

func test_lnz_species_fallback_detection():
	# The file lacks a [Species] block, fallback to parsing [Default Linez File]
	var content = "[Default Linez File]\nC:\\Petz\\Dogz\\Dalmatian.dog"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	
	parser.get_species()
	assert_eq(parser.species, 2, "Should fallback to Dogz (Species = 2) based on default file path string matching.")

func test_lnz_parse_paintballs_invalid_length():
	# Paintballs require at least 11 columns to parse correctly.
	var content = "[Paint Ballz]\n; Not enough data\n1 2 3 4 5 6\n; Valid\n1 2 3 4 5 6 7 8 9 10 11 12"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Paint Ballz", [])
	
	parser.parse_paintballs(reader)
	
	assert_true(parser.paintballs.has(1), "Should successfully parse the valid paintball.")
	assert_eq(parser.paintballs[1].size(), 1, "Should gracefully skip the invalid short line without throwing index errors.")

func test_lnz_get_whiskers_standard_parsing():
	# Standard whisker definitions
	var content = "[Whiskers]\n10 11\n12 13"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Whiskers", [])
	
	parser.get_whiskers(reader)
	assert_eq(parser.whisker_connections.size(), 2, "Should map exactly 2 whisker connections.")
	assert_eq(parser.whisker_connections[0]["start"], 11, "Whisker start index should match.")
	assert_eq(parser.whisker_connections[0]["end"], 10, "Whisker end index should match.")

func test_lnz_parse_moves():
	# Move section with and without 'relative_to' column
	var content = "[Move]\n5 10 20 30 15\n8 0 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Move", [])
	
	parser.parse_moves(reader)
	assert_eq(parser.moves.size(), 2, "Should parse all valid moves.")
	assert_eq(parser.moves[0]["relative_to"], 15, "Should pick up relative_to column when present.")
	assert_eq(parser.moves[1]["relative_to"], 8, "Should fallback relative_to equal to base ball when column is missing.")

# ------------------------------------------------------------------------------
# dog_generator.gd
# ------------------------------------------------------------------------------
func test_apply_sizes_scaling_math():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	var mock_lnz = autofree(LnzParser.new(null))
	mock_lnz.scales = Vector2(127.5, 127.5)
	
	var mock_ball = autofree(Node.new())
	var b_script = GDScript.new()
	b_script.source_code = "extends Node\nvar size = 50.0\nvar position = Vector3(10, 20, 30)"
	b_script.reload()
	mock_ball.set_script(b_script)
	
	var all_balls = {
		"balls": { 1: mock_ball },
		"addballs": {},
		"paintballs": {}
	}
	
	var result = dog_gen.apply_sizes(all_balls, mock_lnz)
	var processed_ball = result.balls[1]
	
	assert_eq(processed_ball.size, 23.0, "Ball size should be accurately scaled and adjusted by the fmod formula.")
	assert_eq(processed_ball.position, Vector3(5.0, 10.0, 15.0), "Ball position should be correctly scaled down by 50%.")

func test_apply_movement_with_rotation_math():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Imagine a move instruction to shift a ball +10 units forward on the Z axis
	var vector_to_move = Vector3(0, 0, 10)
	# ...but the base ball is rotated 90 degrees around the Y axis (Yaw)
	var base_rotation = Vector3(0, 90, 0) 
	
	var result = dog_gen.apply_movement_with_rotation(vector_to_move, base_rotation)
	
	# If we point forward (+Z) but rotate 90 degrees to the right, the resulting
	# position should now lie entirely on the X axis.
	assert_almost_eq(result.x, 10.0, 0.01, "Vector should rotate 90 degrees to align with X axis.")
	assert_almost_eq(result.z, 0.0, 0.01, "Z axis magnitude should become 0 after 90 degree rotation.")

func test_hide_ball_state_synchronization():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Mock a 3D visual node with the expected set_hidden interface
	var mock_visual_node = autofree(Node.new())
	var v_script = GDScript.new()
	v_script.source_code = "extends Node\nvar is_hidden = false\nfunc set_hidden(val):\n\tis_hidden = val"
	v_script.reload()
	mock_visual_node.set_script(v_script)
	
	# Inject it directly into the generator's state
	dog_gen.ball_map = { 15: mock_visual_node }
	
	# Execute
	dog_gen.hide_ball(15)
	
	# Verify internal array tracking and visual method calling
	assert_true(dog_gen.is_hidden_ball(15), "Generator should track ball 15 as hidden internally.")
	assert_true(mock_visual_node.is_hidden, "Generator should successfully call set_hidden(true) on the visual node.")
	
	# Execute reverse
	dog_gen.unhide_all_balls()
	
	# Verify cleanup
	assert_false(dog_gen.is_hidden_ball(15), "Internal tracking array should be cleared.")
	assert_false(mock_visual_node.is_hidden, "Visual node should be restored to visible.")

func test_is_special_ball_detection():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Mock the dictionary that LnzParser normally provides to dictate add_groups
	var mock_lnz = autofree(LnzParser.new(null))
	mock_lnz.addballs = {
		120: {"add_group": 1},
		137: {"add_group": 2},
		119: {"add_group": 0}
	}
	dog_gen.lnz = mock_lnz
	
	# Should evaluate as true if it exists in addballs AND add_group != 0
	assert_true(dog_gen.is_special_ball(3, 120), "Ball 120 has add_group 1, should be special.")
	assert_true(dog_gen.is_special_ball(3, 137), "Ball 137 has add_group 2, should be special.")
	
	# Edge cases
	assert_false(dog_gen.is_special_ball(3, 119), "Ball 119 has add_group 0, should not be special.")
	assert_false(dog_gen.is_special_ball(3, 50), "Ball 50 is not an addball, should be false.")

func test_update_whisker_position_geometry():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Mock the 3D nodes needed for the math
	var start_node = autofree(Spatial.new())
	var end_node = autofree(Spatial.new())
	var visual_line = autofree(Spatial.new())
	
	add_child(start_node)
	add_child(end_node)
	add_child(visual_line)
	
	# Duck-type the custom properties the line expects
	var line_script = GDScript.new()
	line_script.source_code = "extends Spatial\nvar ball_world_pos1 = Vector3.ZERO\nvar ball_world_pos2 = Vector3.ZERO"
	line_script.reload()
	visual_line.set_script(line_script)
	
	# Now that they are in the tree, setting global_transform will stick
	start_node.global_transform.origin = Vector3(0, 0, 0)
	end_node.global_transform.origin = Vector3(0, 0, 10)
	
	# Run the geometry calculator
	dog_gen._update_whisker_position(visual_line, start_node, end_node)
	
	# Verify math
	assert_eq(visual_line.ball_world_pos1, Vector3(0, 0, 0), "Start position should be saved.")
	assert_eq(visual_line.ball_world_pos2, Vector3(0, 0, 10), "End position should be saved.")
	
	# Distance between (0,0,0) and (0,0,10) is exactly 10
	assert_almost_eq(visual_line.scale.y, 10.0, 0.01, "Line scale should exactly match the distance between nodes.")
	
	# Note: look_at_from_position sets the origin to the midpoint
	assert_eq(visual_line.global_transform.origin, Vector3(0, 0, 5), "Line origin should be exactly in the middle of the two nodes.")

func test_update_eyelids_mirrored_angles():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Create mock balls that can receive the angle data
	var b_script = GDScript.new()
	b_script.source_code = "extends Node\nvar angle = 0.0\nvar color = 0\nfunc set_eyelid_rotation(a):\n\tangle = a\nfunc set_eyelid_color(c):\n\tcolor = c\nfunc set_eyelash_lengths(l):\n\tpass\nfunc set_eyelash_angle(a):\n\tpass\nfunc set_eyelash_spacing(s):\n\tpass\nfunc set_eyelash_color(c):\n\tpass"
	b_script.reload()
	
	var left_eye = autofree(Node.new())
	left_eye.set_script(b_script)
	
	var right_eye = autofree(Node.new())
	right_eye.set_script(b_script)
	
	# Mock the LnzParser data required for the function
	var mock_lnz = autofree(LnzParser.new(null))
	mock_lnz.eyelid_color = 100
	mock_lnz.eyelash_lengths = []
	dog_gen.lnz = mock_lnz
	
	# Inject the state tracking
	dog_gen.ball_map = { 10: left_eye, 11: right_eye }
	# -1.0 means invert the angle (e.g. left eye), 1.0 means keep it (right eye)
	dog_gen.eyelid_dir_map = { 10: -1.0, 11: 1.0 } 
	dog_gen.eyelid_mode = 0 # 0 = Normal mode (applies color and tilt)
	
	# Execute a 30 degree tilt
	dog_gen._update_eyelids(30.0)
	
	# Verify math and logic
	var expected_rads = deg2rad(30.0)
	assert_eq(left_eye.color, 100, "Left eye should receive the LNZ eyelid color.")
	assert_almost_eq(left_eye.angle, -expected_rads, 0.001, "Left eye should receive a negative (inverted) radian angle.")
	assert_almost_eq(right_eye.angle, expected_rads, 0.001, "Right eye should receive a positive radian angle.")

func test_generate_color_icon_creates_valid_texture():
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Create a tiny 2x1 mock palette texture to sample from
	var mock_img = Image.new()
	mock_img.create(2, 1, false, Image.FORMAT_RGBA8)
	mock_img.lock()
	mock_img.set_pixel(0, 0, Color.red)
	mock_img.set_pixel(1, 0, Color.blue)
	mock_img.unlock()
	
	var mock_tex = ImageTexture.new()
	mock_tex.create_from_image(mock_img)
	dog_gen.current_palette_texture = mock_tex
	
	# Execute
	var result_icon = dog_gen.generate_color_icon(1) # Grab index 1 (blue)
	
	# Verify
	assert_not_null(result_icon, "Should successfully generate a texture.")
	assert_eq(result_icon.get_width(), 16, "Icon should be exactly 16 pixels wide.")
	assert_eq(result_icon.get_height(), 16, "Icon should be exactly 16 pixels high.")
	
	# Verify it grabbed the correct color
	var result_img = result_icon.get_data()
	result_img.lock()
	var sampled_color = result_img.get_pixel(0, 0)
	result_img.unlock()
	
	assert_eq(sampled_color, Color.blue, "The generated 16x16 icon should be filled with the sampled color.")
	
	# Test out of bounds
	assert_null(dog_gen.generate_color_icon(256), "Should return null if requested index is outside the 0-255 range.")

# # ------------------------------------------------------------------------------
# # LnzTextEdit.gd
# # ------------------------------------------------------------------------------

# func test_lnz_history_snapshot_stack_limit():
# 	if not lnz_text: return
# 	lnz_text.max_history_size = 5
# 	lnz_text.initialize_history()
	
# 	for i in range(10):
# 		lnz_text.text = "Change " + str(i)
# 		lnz_text.commit_full_snapshot("Action " + str(i))
	
# 	assert_eq(lnz_text.history_stack.size(), 5, "History stack should not exceed max_history_size.")
# 	assert_eq(lnz_text.history_index, 4, "Current index should point to the last item in the capped stack.")

# func test_lnz_logical_history_merging():
# 	lnz_text.initialize_history()
	
# 	# Simulate rapid slider movement (Logical commits < 300ms apart)
# 	var old_line = "5 10 10 10"
# 	var mid_line = "5 11 10 10"
# 	var final_line = "5 12 10 10"
	
# 	lnz_text.commit_logical_change("Move", "[Move]", 5, old_line, mid_line, 10) 
# 	# Force a small delay less than 300ms if possible, or assume sequential execution
# 	lnz_text.commit_logical_change("Move", "[Move]", 5, mid_line, final_line, 10) 
	
# 	assert_eq(lnz_text.history_stack.size(), 2, "Rapid logical changes to the same ID should squash into one item.")
# 	var item = lnz_text.history_stack[1]
# 	assert_eq(item.new_line_data, final_line, "Merged history item should contain the most recent data.")

# func test_lnz_section_bookmark_navigation():
# 	lnz_text.text = "[Ballz Info]\n1,2,3\n\n[Linez]\n0 1\n\n[Move]\n5 0 0 0"
# 	lnz_text._update_section_bookmarks()
	
# 	assert_eq(lnz_text.bookmarks.size(), 3, "Should identify 3 sections.")
# 	assert_eq(lnz_text.get_next_section_line_idx(1), 3, "From line 1, next section ([Linez]) is at index 3.")
# 	assert_eq(lnz_text.get_prev_section_line_idx(5), 3, "From line 5, previous section ([Linez]) is at index 3.")
# 	assert_eq(lnz_text.get_next_section_line_idx(10), -1, "Should return -1 if no further sections exist.")

# func test_lnz_delimiter_detection_auto_priority():
# 	# Mix of delimiters, but tabs are dominant
# 	var text = "[Section]\n1\t2\t3\n4\t5\t6\n7 8 9"
# 	lnz_text.text = text
# 	var delim = lnz_text._detect_delimiter(1, 4)
# 	assert_eq(delim, "\t", "Should detect tab as the dominant delimiter.")
	
# 	# Test Comma-Space specificity
# 	lnz_text.text = "[Section]\n1, 2, 3\n4, 5, 6"
# 	delim = lnz_text._detect_delimiter(1, 3)
# 	assert_eq(delim, ", ", "Should prefer ', ' over just ',' when spaces are present.")
	
# func test_lnz_undo_restores_cursor_and_scroll():
# 	lnz_text.text = "Initial"
# 	lnz_text.initialize_history()
	
# 	lnz_text.text = "Modified"
# 	lnz_text.cursor_set_line(0)
# 	lnz_text.cursor_set_column(5)
# 	lnz_text.set_v_scroll(10.0)
# 	lnz_text.commit_full_snapshot("Manual Change")
	
# 	lnz_text.undo_visual_edit() 
	
# 	assert_eq(lnz_text.text, "Initial", "Text should revert to initial state.")
# 	assert_eq(lnz_text.get_v_scroll(), 0.0, "Scroll position should revert.")

# func test_lnz_delete_ball_reference_updates():
# 	# Set up a file where ball 50 is deleted. References > 50 must decrement.
# 	lnz_text.text = "[Linez]\n40 50\n51 52"
# 	lnz_text._update_pairwise_section("[Linez]", 50)
	
# 	var line1 = lnz_text.get_line(1).strip_edges()
# 	var line2 = lnz_text.get_line(2).strip_edges()
	
# 	assert_false("40 50" in lnz_text.text, "Line containing the deleted ball should be removed.")
# 	assert_true("50 51" in line2 or "50\t51" in line2, "Subsequent ball references should decrement (51->50, 52->51).")

# ------------------------------------------------------------------------------
# PetViewContainer.gd
# ------------------------------------------------------------------------------
func test_world_to_lnz_delta_conversion():
	# 1. Setup our target constants/variables explicitly for the utility function
	# Simulating your previous mock values:
	var pixel_world_size = 0.002
	var engine_scale = 127.5 # Simulate 50% scale (127.5 / 255.0 = 0.5)
	
	# 2. Execute the static coordinate conversion utility
	# Math breakdown: world_delta / (pixel_world_size * (engine_scale / 255.0))
	# Divisor = 0.002 * 0.5 = 0.001
	var test_world_delta = Vector3(0.01, -0.02, 0.03)
	var result = LnzLiveUtils.world_to_lnz_delta(test_world_delta, pixel_world_size, engine_scale)
	
	# 3. Verify: X and Z divide by 0.001. Y must be explicitly inverted by the formula.
	assert_eq(result.x, 10.0, "X coordinate should be accurately scaled up to integer.")
	assert_eq(result.y, 20.0, "Y coordinate MUST be inverted (positive) for LNZ format.")
	assert_eq(result.z, 30.0, "Z coordinate should be accurately scaled up to integer.")

# func test_dog_generator_munge_balls_applies_movements():
#   Verify that `munge_balls` appropriately transforms base ball coordinates 
#   by integrating `lnz.moves` and custom rotations correctly.
#
# func test_dog_generator_add_pending_paintball():
#   Test that `add_pending_paintball` successfully instantiates a visual paintball,
#   attaches it to the parent, and correctly appends the data to `_pending_paintballs_data`.
#
# func test_dog_generator_symmetrize_skeleton():
#   Test that `symmetrize_skeleton` effectively mirrors the appropriate indices 
#   over the X-axis for T-Pose calculations based on `KeyBallsData` symmetry structures.
#
# func test_dog_generator_apply_extensions():
#   Provide mocked body/leg extensions in `lnz.leg_extensions` and `lnz.body_extension`
#   and assert that `apply_extensions` correctly offsets the designated body part balls.
#
# func test_lnzlive_utils_parse_flexible_integers():
#   Test `LnzLiveUtils.parse_flexible_integers` with poorly formatted LNZ strings
#   like "  10   -5 20" to ensure it extracts exactly [10, -5, 20].
#
# func test_lnzlive_utils_get_ramp_color():
#   Test `LnzLiveUtils.get_ramp_color` for logic that shifts colors dynamically
#   up or down a 10-step palette ramp based on user painting operations.
#
# func test_lnz_parser_get_eyes():
#   Test that custom iris and eyelid mappings correctly populate `lnz.custom_eyes` 
#   when given a valid `[Eyes]` section.
# ------------------------------------------------------------------------------