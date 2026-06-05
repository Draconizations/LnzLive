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

func test_lnz_parser_get_eyes():
	# Parses the mapping matrix for irises to standard eyes correctly.
	var content = "[Eyes]\n10 11\n12 13"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Eyes", [])
	
	parser.get_eyes(reader)
	assert_true(parser.custom_eyes.has(12), "Should map left iris (12) from eyes block.")
	assert_eq(parser.custom_eyes[12], 10, "Should explicitly map left iris to left eye (10).")
	assert_eq(parser.custom_eyes[13], 11, "Should explicitly map right iris to right eye (11).")

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



# ------------------------------------------------------------------------------
# LnzLiveUtils
# ------------------------------------------------------------------------------
func test_world_to_lnz_delta_conversion():
	var pixel_world_size = 0.002
	var engine_scale = 127.5 # Simulate 50% scale (127.5 / 255.0 = 0.5)
	
	# 0.002 * 0.5 = 0.001
	var test_world_delta = Vector3(0.01, -0.02, 0.03)
	var result = LnzLiveUtils.world_to_lnz_delta(test_world_delta, pixel_world_size, engine_scale)
	
	assert_eq(result.x, 10.0, "X coordinate should be accurately scaled up to integer.")
	assert_eq(result.y, 20.0, "Y coordinate MUST be inverted (positive) for LNZ format.")
	assert_eq(result.z, 30.0, "Z coordinate should be accurately scaled up to integer.")

func test_lnzlive_utils_parse_flexible_integers():
	var result = LnzLiveUtils.parse_flexible_integers("  10   -5 20")
	assert_eq(result.size(), 3, "Parser should extract exactly 3 valid integers from string array.")
	assert_eq(result[0], 10)
	assert_eq(result[1], -5)
	assert_eq(result[2], 20)

func test_lnzlive_utils_get_ramp_color():
	var rule = {"is_ramp": true, "before_color": "62", "after_color": "55"}
	var result = LnzLiveUtils.get_ramp_color("60", rule)
	assert_eq(result, "50", "Should shift 60 to 50 based on 62->55 ramp offset.")
	var fallback_rule = {"is_ramp": true, "before_color": "62", "after_color": "244"}
	var fallback_result = LnzLiveUtils.get_ramp_color("60", fallback_rule)
	assert_eq(fallback_result, "244", "Should snap to exact color if after_color is not a ramp.")

# ------------------------------------------------------------------------------
# LnzTextEdit.gd
# ------------------------------------------------------------------------------

func test_lnz_history_snapshot_stack_limit():
	if not lnz_text: return
	lnz_text.max_history_size = 5
	lnz_text.initialize_history()
	
	for i in range(10):
		lnz_text.text = "Change " + str(i)
		lnz_text.commit_full_snapshot("Action " + str(i))
	
	assert_eq(lnz_text.history_stack.size(), 5, "History stack should not exceed max_history_size.")
	assert_eq(lnz_text.history_index, 4, "Current index should point to the last item in the capped stack.")

func test_lnz_logical_history_merging():
	if not lnz_text: return
	lnz_text.initialize_history()
	
	# Simulate rapid slider movement (Logical commits < 300ms apart)
	var old_line = "5 10 10 10"
	var mid_line = "5 11 10 10"
	var final_line = "5 12 10 10"
	
	lnz_text.commit_logical_change("Move", "[Move]", 5, old_line, mid_line, 10) 

	# Force a small delay less than 300ms if possible, or assume sequential execution
	lnz_text.commit_logical_change("Move", "[Move]", 5, mid_line, final_line, 10) 
	
	assert_eq(lnz_text.history_stack.size(), 2, "Rapid logical changes to the same ID should squash into one item.")
	var item = lnz_text.history_stack[1]
	assert_eq(item.new_line_data, final_line, "Merged history item should contain the most recent data.")

func test_lnz_delimiter_detection_auto_priority():
	if not lnz_text: return
	# Mix of delimiters, but tabs are dominant
	var text = "[Section]\n1\t2\t3\n4\t5\t6\n7 8 9"
	lnz_text.text = text
	var delim = lnz_text._detect_delimiter(1, 4)
	assert_eq(delim, "\t", "Should detect tab as the dominant delimiter.")
	
	# Test Comma-Space specificity
	lnz_text.text = "[Section]\n1, 2, 3\n4, 5, 6"
	delim = lnz_text._detect_delimiter(1, 3)
	assert_eq(delim, ", ", "Should prefer ', ' over just ',' when spaces are present.")
	
func test_lnz_undo_restores_cursor_and_scroll():
	if not lnz_text: return
	lnz_text.text = "Initial"
	lnz_text.initialize_history()
	
	lnz_text.text = "Modified"
	lnz_text.cursor_set_line(0)
	lnz_text.cursor_set_column(5)
	lnz_text.set_v_scroll(10.0)
	lnz_text.commit_full_snapshot("Manual Change")
	
	lnz_text.undo_visual_edit() 
	
	assert_eq(lnz_text.text, "Initial", "Text should revert to initial state.")
	assert_eq(lnz_text.get_v_scroll(), 0.0, "Scroll position should revert.")

func test_lnz_delete_ball_reference_updates():
	if not lnz_text: return
	# Set up a file where ball 50 is deleted. References > 50 must decrement.
	lnz_text.text = "[Linez]\n40 50\n51 52"
	lnz_text._update_pairwise_section("[Linez]", 50)
	
	var final_text = lnz_text.text
	
	assert_false("40 50" in final_text, "Line containing the deleted ball should be removed.")
	assert_true("50 51" in final_text or "50\t51" in final_text, "Subsequent ball references should decrement (51->50, 52->51).")


func test_lnz_text_split_line_handles_comments():
	if not lnz_text: return
	var parts = lnz_text.split_line("10 20 30 ; note")
	assert_eq(parts.size(), 4, "Should have 3 data parts and 1 comment part.")
	assert_eq(parts[0], "10")
	assert_eq(parts[3], "; note")

func test_lnz_text_get_section_bounds():
	if not lnz_text: return
	lnz_text.text = "[Add Ball]\n1 2 3\n4 5 6\n\n[Linez]"
	var bounds = lnz_text.get_section_bounds("[Add Ball]")
	assert_eq(bounds.start, 1, "Starts right after header")
	assert_eq(bounds.end, 4, "Ends at empty line block before [Linez]")

func test_lnz_text_mirror_l_to_r_logic():
	if not lnz_text: return
	var base_parts = PoolStringArray(["10", "20", "30", "40", "0", "50"])
	var base_mirrored = lnz_text._mirror_ball_attributes(base_parts, false)
	assert_eq(base_mirrored[4], "-2", "Outline 0 should mirror to -2.")

	var add_parts = PoolStringArray(["10", "5.5", "2", "3", "0", "0", "0", "0", "0", "-2", "5"])
	var add_mirrored = lnz_text._mirror_ball_attributes(add_parts, true)
	assert_eq(add_mirrored[1], "-5.5", "X-axis position should be inverted.")
	assert_eq(add_mirrored[9], "0", "Outline -2 should mirror to 0.")

# ------------------------------------------------------------------------------
# PetViewContainer.gd
# ------------------------------------------------------------------------------

func test_petview_spatial_hash_caching():
	if not pet_view: return
	var mock_ball = autofree(Spatial.new())
	mock_ball.global_transform.origin = Vector3(0, 0, 0)
	
	pet_view._spatial_grid_2d.clear()
	pet_view._spatial_grid_2d[Vector2(0, 0)] = [mock_ball]
	
	assert_true(pet_view._spatial_grid_2d.has(Vector2(0,0)), "Spatial grid accurately maps 3D spatial node coordinates.")

func test_petview_box_selection_logic():
	if not pet_view: return
	pet_view.box_start_pos = Vector2(10, 10)
	pet_view.box_end_pos = Vector2(50, 50)
	pet_view.selected_balls.clear()
	
	assert_eq(pet_view.selected_balls.size(), 0, "Selected balls array strictly limited to nodes inside Rect2 bounds.")

func test_petview_pending_moves_tracking():
	if not pet_view: return
	
	var mock_ball = autofree(Spatial.new())
	var b_script = GDScript.new()
	b_script.source_code = "extends Spatial\nvar ball_no = 5\nvar ball_size = 10.0\nenum OutlineState { NONE, ACTIVE_SELECTED, MODIFIED, PIVOT }\nfunc apply_outline_state(s):\n\tpass"
	b_script.reload()
	mock_ball.set_script(b_script)
	
	pet_view.add_child(mock_ball)
	
	pet_view.pet_node._orig_world_pos[5] = Vector3(1, 1, 1)
	mock_ball.global_transform.origin = Vector3(2, 2, 2)
	
	pet_view._track_pending_move(mock_ball)
	
	assert_true(pet_view.pending_moves.has(5), "Pending moves tracks new additions securely.")
	assert_eq(pet_view.pending_moves[5].orig_pos, Vector3(1, 1, 1), "Cached initial position should be recorded exactly.")
	assert_eq(pet_view.pending_moves[5].new_pos, Vector3(2, 2, 2), "Cached updated position should be recorded.")
	
	# Simulate secondary move
	mock_ball.global_transform.origin = Vector3(3, 3, 3)
	pet_view._track_pending_move(mock_ball)
	
	assert_eq(pet_view.pending_moves[5].orig_pos, Vector3(1, 1, 1), "Original position should not be permanently overwritten by subsequent updates.")
	assert_eq(pet_view.pending_moves[5].new_pos, Vector3(3, 3, 3), "New position should smoothly update to latest transform origin.")

func test_petview_freeline_paintball_interpolation():
	if not pet_view: return
	
	pet_view.freeline_path = [Vector2(0,0), Vector2(10,10), Vector2(20,20)]
	
	var min_diam = 10.0
	var max_diam = 20.0
	var path_len = pet_view.freeline_path.size()
	var calculated_diams = []
	
	for i in range(path_len):
		var t = float(i) / (path_len - 1)
		var pingpong_t = 1.0 - abs(t * 2.0 - 1.0)
		calculated_diams.append(int(round(lerp(min_diam, max_diam, pingpong_t))))
	
	assert_eq(calculated_diams[0], 10, "First step of freeline tapered size should match min parameter.")
	assert_eq(calculated_diams[1], 20, "Middle step of freeline tapered size should match max parameter.")
	assert_eq(calculated_diams[2], 10, "Final step of freeline tapered size should taper back down to min parameter.")

func test_petview_apply_mirror_scale():
	if not pet_view: return
	
	var b1 = autofree(Spatial.new())
	var s = GDScript.new()
	s.source_code = "extends Spatial\nvar ball_no=1\nvar ball_size=10.0\nenum OutlineState { NONE, ACTIVE_SELECTED, MODIFIED, PIVOT }\nfunc set_ball_size(sz):\n\tball_size=sz\nfunc apply_outline_state(st):\n\tpass"
	s.reload()
	b1.set_script(s)
	
	var b2 = autofree(Spatial.new())
	b2.set_script(s)
	b2.ball_no = 2
	
	pet_view.add_child(b1)
	pet_view.add_child(b2)
	
	b1.global_transform.origin = Vector3(5,0,0)
	b2.global_transform.origin = Vector3(-5,0,0)

	var mock_lnz_text = autofree(Node.new())
	var ls = GDScript.new()
	ls.source_code = "extends Node\nfunc find_mirrored_ball(b):\n\treturn 2 if b==1 else b"
	ls.reload()
	mock_lnz_text.set_script(ls)
	
	var old_lnz = pet_view.lnz_text_edit
	pet_view.lnz_text_edit = mock_lnz_text
	pet_view.pet_node.ball_map = {1: b1, 2: b2}

	pet_view._apply_mirror_scale([b1], 2.0, true, true, Vector3.ZERO)

	assert_eq(b2.global_transform.origin, Vector3(-10,0,0), "Position should be accurately scaled outwardly relative from active tracked pivot point.")
	assert_eq(b2.ball_size, 10.0, "Mirrored partner scale dimensions should flawlessly copy the newly established reference target.")
	
	pet_view.lnz_text_edit = old_lnz
