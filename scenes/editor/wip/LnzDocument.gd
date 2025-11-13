extends Node
class_name LnzDocument

# LnzDocument.gd - builds model of LNZ data from LNZ text
# - Parses LNZ text once into a "lossless" model
# - Serializes model back to text preserving user structure, comments, and formatting
# - Contains all logic (mirroring, coloring, deleting)
# - Single source of LNZ truth for LnzLive
# (replacing lnz_parser eventually)

enum LineType {
	TYPE_DATA,      # A line with parsable data
	TYPE_COMMENT,   # A line that *starts* with a comment
	TYPE_EMPTY,     # A line with only whitespace
	TYPE_HEADER     # A section header line, e.g., [Ballz Info]
}

signal pre_document_update   # Emitted *before* the model is changed
signal document_updated    # Emitted *after* the model has changed
signal document_parsed     # Emitted when a new file is loaded and parsed
signal file_saved(filepath)  # Emitted after a successful save
signal file_backed_up      # Emitted after a backup

var current_filepath: String = ""
var is_user_file: bool = false

var document_root = {
	"preamble_lines": [],     # Array[LineObject]
	"section_order": [],      # PoolStringArray
	"sections": {}            # Dictionary { "SectionName": SectionObject }
}

var header_regex: RegEx = RegEx.new()
var comment_regex: RegEx = RegEx.new()
var data_regex: RegEx = RegEx.new() # For finding numbers

func _ready() -> void:
	# Regex to find [Section Name]
	header_regex.compile("^\\[(.+)\\]")
	# Regex to find lines that are just comments
	comment_regex.compile("^\\s*;.*")
	# Regex to parse numbers, similar to original parser
	data_regex.compile("[-.\\d]+")

	# Connect to the global signal bus
	GlobalSignals.connect("apply_changes_pressed", self, "_on_apply_changes_pressed")
	GlobalSignals.connect("save_file_pressed", self, "save_file")
	GlobalSignals.connect("backup_file_pressed", self, "save_backup")
	GlobalSignals.connect("user_file_selected", self, "_on_user_file_selected")
	GlobalSignals.connect("example_file_selected", self, "_on_example_file_selected")
	
	# Connect to visual editor signals
	GlobalSignals.connect("visual_ball_resized", self, "set_ball_size")
	GlobalSignals.connect("visual_ball_moved", self, "set_ball_translation")
	GlobalSignals.connect("visual_line_created", self, "create_line")
	GlobalSignals.connect("visual_apply_paintballz", self, "_on_apply_paintballz") # Keep internal logic
	
	# Connect to Tools Menu signals
	GlobalSignals.connect("tool_delete_ball", self, "delete_ball")
	GlobalSignals.connect("tool_add_ball", self, "_on_add_ball_tool") # Needs node access
	GlobalSignals.connect("tool_color_pet", self, "color_entire_pet")
	GlobalSignals.connect("tool_color_part", self, "color_part")
	GlobalSignals.connect("tool_recolor", self, "recolor_from_map")
	GlobalSignals.connect("tool_move_head", self, "move_head")
	GlobalSignals.connect("tool_copy_l_to_r", self, "mirror_l_to_r")
	GlobalSignals.connect("tool_palette_selected", self, "set_palette")
	GlobalSignals.connect("tool_apply_preset", self, "apply_preset_to_ball")
	
	GlobalSignals.connect("project_ball_data_updated", self, "write_project_ball_section")
	GlobalSignals.connect("headshot_button_pressed", self, "_on_headshot_button_pressed") # Needs scene access


# --- LNZ Parser ---

"""
Parses the entire LNZ text into the full-fidelity `document_root` model.
This function reads the file once and preserves all comments,
whitespace, and formatting.
"""
func parse_from_text(full_text: String) -> void:
	var new_doc = {
		"preamble_lines": [],
		"section_order": PoolStringArray(),
		"sections": {}
	}
	
	var current_section_object: Dictionary = null
	var lines: Array = full_text.split("\n")
	
	for i in range(lines.size()):
		var line: String = lines[i]
		var line_object: Dictionary
		
		# 1. Check for [Header]
		var header_match = header_regex.search(line)
		if header_match:
			var section_name: String = header_match.get_string(1).strip_edges()
			# Handle potential duplicate sections by appending a number
			var unique_name = section_name
			var counter = 2
			while new_doc.sections.has(unique_name):
				unique_name = section_name + "_" + str(counter)
				counter += 1

			var section_object: Dictionary = {
				"name": unique_name,
				"raw_header": line,
				"lines": []
			}
			
			new_doc.sections[unique_name] = section_object
			new_doc.section_order.append(unique_name)
			current_section_object = section_object
			continue # Don't add header *as a line* to its own section

		# 2. Check for Empty Line
		elif line.strip_edges().empty():
			line_object = {
				"type": LineType.TYPE_EMPTY,
				"raw_text": line,
				"parsed_data": null
			}

		# 3. Check for Full-Line Comment
		elif comment_regex.search(line):
			line_object = {
				"type": LineType.TYPE_COMMENT,
				"raw_text": line,
				"parsed_data": null
			}

		# 4. Else, it's a Data Line
		else:
			line_object = {
				"type": LineType.TYPE_DATA,
				"raw_text": line,
				"parsed_data": _parse_data_line(line)
			}
			
		# Add the new LineObject to the correct place
		if current_section_object == null:
			# This line is in the "preamble" before any sections
			new_doc.preamble_lines.append(line_object)
		else:
			# This line is inside the current section
			current_section_object.lines.append(line_object)
			
	# Replace the old document and notify all listeners
	self.document_root = new_doc
	emit_signal("document_parsed")
	print("[LnzDocument] Parsed new text into full-fidelity model.")


"""
Parses a single line of data into its constituent parts.
Returns the 'parsed_data' dictionary for a LineObject.
"""
func _parse_data_line(line: String) -> Dictionary:
	var lstripped: String = line.lstrip(" \t")
	var leading_whitespace: String = line.substr(0, line.length() - lstripped.length())
	
	var comment_parts: Array = lstripped.split(";", false, 1)
	var data_part: String = comment_parts[0].rstrip(" \t")
	var trailing_comment = ""
	if comment_parts.size() > 1:
		trailing_comment = comment_parts[1] # Keep whitespace for fidelity
		
	var split_result: Dictionary = _detect_delimiter_and_split(data_part)
	
	return {
		"parts": PoolStringArray(split_result.parts),
		"delimiter": split_result.delimiter,
		"leading_whitespace": leading_whitespace,
		"trailing_comment": trailing_comment
	}

"""
Finds the most likely delimiter in a data string and splits it.
"""
func _detect_delimiter_and_split(data_part: String) -> Dictionary:
	# Use a regex to normalize delimiters and then split
	# This is more robust than the original _split_line
	var regex = RegEx.new()
	regex.compile("[\\s,]+")
	var normalized_line = regex.sub(data_part.strip_edges(), " ", true)
	var parts = normalized_line.split(" ", false)
	
	# Try to guess the original delimiter for serialization
	var original_delimiter = " "
	if data_part.find(", ") != -1:
		original_delimiter = ", "
	elif data_part.find(",") != -1:
		original_delimiter = ","
	elif data_part.find("\t") != -1:
		original_delimiter = "\t"
	
	return { "parts": parts, "delimiter": original_delimiter }

# --- LNZ Serializer ---

"""
Serializes the `document_root` model back into a complete LNZ text string.
This function preserves comments, whitespace, and file structure.
"""
func serialize_to_text() -> String:
	var text_lines: Array = []
	
	# 1. Add Preamble Lines
	for line_obj in document_root.preamble_lines:
		text_lines.append(_serialize_line(line_obj))
		
	# 2. Add Sections in their Original Order
	for section_name in document_root.section_order:
		if not document_root.sections.has(section_name):
			continue
			
		var section_obj: Dictionary = document_root.sections[section_name]
		
		# Add the raw header
		text_lines.append(section_obj.raw_header)
		
		# Add all lines within that section
		for line_obj in section_obj.lines:
			text_lines.append(_serialize_line(line_obj))
	
	return text_lines.join("\n")

"""
Helper to serialize a single LineObject back to text.
"""
func _serialize_line(line_obj: Dictionary) -> String:
	var type = line_obj.type
	
	# For non-data, just return the raw text to preserve it
	if type == LineType.EMPTY or type == LineType.COMMENT:
		return line_obj.raw_text
	
	elif type == LineType.DATA:
		# Reconstruct the data line from its parts for 100% fidelity
		var data: Dictionary = line_obj.parsed_data
		var new_line: String = data.leading_whitespace
		new_line += data.parts.join(data.delimiter)
		
		if not data.trailing_comment.empty():
			new_line += " ;" + data.trailing_comment
			
		return new_line
	
	# Fallback for unknown or header (though headers aren't in .lines)
	return line_obj.raw_text

# --- File I/O ---

func _on_user_file_selected(filepath: String) -> void:
	if filepath == null or filepath.empty():
		return
	_load_file(filepath, true)

func _on_example_file_selected(filepath: String) -> void:
	if filepath == null or filepath.empty():
		return
	_load_file(filepath, false)

func _load_file(filepath: String, user_flag: bool) -> void:
	var file = File.new()
	if not file.file_exists(filepath):
		printerr("File not found: " + filepath)
		return
		
	file.open(filepath, File.READ)
	var contents = file.get_as_text()
	file.close()
	
	self.current_filepath = filepath
	self.is_user_file = user_flag
	
	parse_from_text(contents) # This will emit "document_parsed"

func save_backup() -> void:
	if not is_user_file or current_filepath.empty():
		return

	var dir = Directory.new()
	var base_path = current_filepath.trim_suffix(".lnz")
	var backup_path1 = base_path + "_backup_1.lnz"
	var backup_path2 = base_path + "_backup_2.lnz"
	var backup_path3 = base_path + "_backup_3.lnz"

	if dir.file_exists(backup_path2):
		if dir.file_exists(backup_path3):
			dir.remove(backup_path3)
		dir.rename(backup_path2, backup_path3)

	if dir.file_exists(backup_path1):
		dir.rename(backup_path1, backup_path2)

	var file = File.new()
	var new_text = serialize_to_text()
	file.open(backup_path1, File.WRITE)
	file.store_string(new_text)
	file.close()
	
	emit_signal("file_backed_up")
	print("[LnzDocument] File backed up.")

func save_file() -> void:
	if current_filepath == null or current_filepath.empty():
		# Handle saving a new, unnamed file
		var dir = Directory.new()
		var base_path = "user://resources/"
		dir.open("user://")
		dir.make_dir_recursive("resources")
		current_filepath = base_path + "unnamed_" + str(OS.get_unix_time()) + ".lnz"
		is_user_file = true
	
	var save_path = current_filepath
	
	if not is_user_file:
		# Save "res://" files to "user://" to avoid overwriting examples
		save_path = current_filepath.replace("res://", "user://")
		var dir = Directory.new()
		if dir.file_exists(save_path):
			save_path = save_path.replace(".lnz", str(OS.get_unix_time()) + ".lnz")
		
		# Update state to reflect new user file
		current_filepath = save_path
		is_user_file = true

	# Perform the save
	var new_text = serialize_to_text()
	var file = File.new()
	var err = file.open(save_path, File.WRITE)
	if err != OK:
		printerr("Failed to open file for writing: " + save_path)
		return

	file.store_string(new_text)
	file.close()
	
	emit_signal("file_saved", current_filepath)
	print("[LnzDocument] File saved to: " + save_path)
	
	# Re-parse the saved text to ensure model is 100% in sync
	# with what's on disk (and update LnzTextEdit view)
	parse_from_text(new_text)

# --- Global Signal Handlers ---

func _on_apply_changes_pressed() -> void:
	# This signal comes from LnzTextEdit. We need its text.
	# We can't get it directly. LnzTextEdit must call parse_from_text.
	# This connection is a placeholder; LnzTextEdit will call.
	printerr("LnzDocument: _on_apply_changes_pressed should not be connected.")
	pass

# --- Getters ---

"""
Finds the Nth data line in a section.
"""
func _get_data_line_from_section(section_name: String, data_index: int) -> Dictionary:
	if not document_root.sections.has(section_name):
		return null
		
	var section_obj: Dictionary = document_root.sections[section_name]
	var data_counter = 0
	
	for line_obj in section_obj.lines:
		if line_obj.type == LineType.TYPE_DATA:
			if data_counter == data_index:
				return line_obj
			data_counter += 1
			
	return null

"""
Gets *all* data lines from a section.
"""
func _get_all_data_lines(section_name: String) -> Array:
	var lines_out: Array = []
	if not document_root.sections.has(section_name):
		return lines_out
	
	var section_obj: Dictionary = document_root.sections[section_name]
	for line_obj in section_obj.lines:
		if line_obj.type == LineType.TYPE_DATA:
			lines_out.append(line_obj)
	return lines_out

"""
Counts the number of data entries in a section.
"""
func _count_section_entries(section_name: String) -> int:
	if not document_root.sections.has(section_name):
		return 0
	
	var data_counter = 0
	var section_obj: Dictionary = document_root.sections[section_name]
	for line_obj in section_obj.lines:
		if line_obj.type == LineType.TYPE_DATA:
			data_counter += 1
	return data_counter

"""
Maps a line number from the text editor to a ball number.
"""
func get_ball_no_from_line(target_line_number: int) -> int:
	var line_counter = 0
	
	# Check preamble
	for line_obj in document_root.preamble_lines:
		if line_counter == target_line_number: return -1 # Preamble
		line_counter += 1

	# Check sections
	for section_name in document_root.section_order:
		var section_obj = document_root.sections[section_name]
		
		# Check header line
		if line_counter == target_line_number: return -1 # Header
		line_counter += 1
		
		var data_index = 0
		for line_obj in section_obj.lines:
			if line_counter == target_line_number:
				# This is the line!
				if line_obj.type != LineType.TYPE_DATA:
					return -1 # It's a comment or empty line
				
				if section_name == "Ballz Info":
					return data_index
				if section_name == "Add Ball":
					# This assumes KeyBallsData is available or we get max_base_ball_num
					var max_base_ball_num = _count_section_entries("Ballz Info")
					return data_index + max_base_ball_num
				
				# For other sections, return the first data part
				return int(line_obj.parsed_data.parts[0])
				
			if line_obj.type == LineType.TYPE_DATA:
				data_index += 1
			
			line_counter += 1
			
	return -1 # Not found

# ---Setters ---

"""
Sets a specific property for a line object and marks document as dirty.
"""
func _set_line_property(line_obj: Dictionary, part_index: int, new_value: String) -> bool:
	if not line_obj or line_obj.type != LineType.TYPE_DATA:
		return false
		
	var parts: PoolStringArray = line_obj.parsed_data.parts
	
	# Ensure parts array is long enough
	if parts.size() <= part_index:
		parts.resize(part_index + 1)
		# Fill with "0"
		for i in range(parts.size()):
			if parts[i] == null: parts[i] = "0"

	if parts[part_index] == new_value:
		return false # No change

	emit_signal("pre_document_update")
	parts[part_index] = new_value
	emit_signal("document_updated")
	return true

"""
Sets the size of a ball in [Ballz Info] or [Add Ball].
"""
func set_ball_size(ball_no: int, new_size: int) -> void:
	save_backup()
	var max_base_ball_num = _count_section_entries("Ballz Info")
	var line_obj: Dictionary
	var size_index: int
	
	if ball_no >= max_base_ball_num:
		# It's an Add Ball
		line_obj = _get_data_line_from_section("Add Ball", ball_no - max_base_ball_num)
		size_index = 10 # 11th field is size
	else:
		# It's a Base Ball
		line_obj = _get_data_line_from_section("Ballz Info", ball_no)
		size_index = 5 # 6th field is size
	
	if _set_line_property(line_obj, size_index, str(new_size)):
		save_file() # Save after modification

"""
Sets the translation of a ball ([Move] or [Add Ball]).
"""
func set_ball_translation(ball_no: int, pos_delta: Vector3) -> void:
	save_backup()
	var max_base_ball_num = _count_section_entries("Ballz Info")
	
	if ball_no >= max_base_ball_num:
		# It's an Add Ball, modify [Add Ball] section
		var line_obj = _get_data_line_from_section("Add Ball", ball_no - max_base_ball_num)
		if not line_obj: return

		emit_signal("pre_document_update")
		var parts = line_obj.parsed_data.parts
		parts[1] = str(int(parts[1]) + pos_delta.x)
		parts[2] = str(int(parts[2]) + pos_delta.y)
		parts[3] = str(int(parts[3]) + pos_delta.z)
		emit_signal("document_updated")
		
	else:
		# It's a Base Ball, modify [Move] section
		var move_section = document_root.sections.get("Move")
		if not move_section: 
			printerr("No [Move] section found!")
			return

		var line_found = false
		for line_obj in move_section.lines:
			if line_obj.type == LineType.TYPE_DATA:
				var parts = line_obj.parsed_data.parts
				if parts.size() > 0 and int(parts[0]) == ball_no:
					# Found it, update it
					emit_signal("pre_document_update")
					parts[1] = str(int(parts[1]) + pos_delta.x)
					parts[2] = str(int(parts[2]) + pos_delta.y)
					parts[3] = str(int(parts[3]) + pos_delta.z)
					emit_signal("document_updated")
					line_found = true
					break
		
		if not line_found:
			# No line found, create a new one
			var new_parts = PoolStringArray([
				str(ball_no), str(int(pos_delta.x)), str(int(pos_delta.y)), str(int(pos_delta.z))
			])
			var new_line_obj = {
				"type": LineType.TYPE_DATA,
				"raw_text": "", # Will be generated by serializer
				"parsed_data": {
					"parts": new_parts,
					"delimiter": " ",
					"leading_whitespace": "",
					"trailing_comment": ""
				}
			}
			emit_signal("pre_document_update")
			move_section.lines.append(new_line_obj)
			emit_signal("document_updated")
	
	save_file()

"""
Deletes a ball (AddBall) or marks for omission (BaseBall).
"""
func delete_ball(ball_no: int) -> void:
	save_backup()
	var max_base_ball_num = _count_section_entries("Ballz Info")
	
	if ball_no >= max_base_ball_num:
		# Delete AddBall
		var addball_section = document_root.sections.get("Add Ball")
		if not addball_section: return
		
		var data_index = ball_no - max_base_ball_num
		var data_counter = 0
		
		emit_signal("pre_document_update")
		for i in range(addball_section.lines.size() - 1, -1, -1):
			var line_obj = addball_section.lines[i]
			if line_obj.type == LineType.TYPE_DATA:
				if data_counter == data_index:
					addball_section.lines.remove(i)
					_remap_ball_indices(ball_no, -1)
					break
				data_counter += 1
		emit_signal("document_updated")
		
	else:
		# Omit BaseBall
		var omissions_section = document_root.sections.get("Omissions")
		if not omissions_section:
			_create_section("Omissions") # Create if not found
			omissions_section = document_root.sections.get("Omissions")
		
		# Check if already omitted
		for line_obj in omissions_section.lines:
			if line_obj.type == LineType.TYPE_DATA and int(line_obj.parsed_data.parts[0]) == ball_no:
				return # Already omitted
		
		# Add new omission line
		var new_line_obj = {
			"type": LineType.TYPE_DATA, "raw_text": "",
			"parsed_data": {
				"parts": PoolStringArray([str(ball_no)]),
				"delimiter": " ", "leading_whitespace": "", "trailing_comment": ""
			}
		}
		emit_signal("pre_document_update")
		omissions_section.lines.append(new_line_obj)
		emit_signal("document_updated")
	
	save_file()

"""
Internal helper to remap all ball indices after an AddBall deletion.
"""
func _remap_ball_indices(deleted_ball_no: int, increment: int) -> void:
	# This function iterates through *all* sections and decrements ball indices
	# higher than deleted_ball_no.
	
	var sections_to_remap = [
		"Add Ball", "Linez", "Omissions", "Project Ball", "Paint Ballz"
		# Add any other sections that reference ball numbers
	]
	
	for section_name in sections_to_remap:
		var section_obj = document_root.sections.get(section_name)
		if not section_obj: continue
		
		for line_obj in section_obj.lines:
			if line_obj.type != LineType.TYPE_DATA: continue
			
			var parts = line_obj.parsed_data.parts
			var indices_to_check = []
			
			# Define which parts of the line are ball numbers
			match section_name:
				"Add Ball": indices_to_check = [0] # base ball
				"Linez": indices_to_check = [0, 1] # start, end
				"Omissions": indices_to_check = [0]
				"Project Ball": indices_to_check = [0, 1]
				"Paint Ballz": indices_to_check = [0]
			
			var line_was_modified = false
			for index in indices_to_check:
				if parts.size() > index:
					var ball_num = int(parts[index])
					if ball_num > deleted_ball_no:
						parts[index] = str(ball_num + increment)
						line_was_modified = true
					elif ball_num == deleted_ball_no:
						# This line references the ball that was deleted.
						# We should delete this line.
						# (For simplicity, we'll mark it for deletion)
						line_obj.type = LineType.TYPE_COMMENT # Hack: turn to comment
						line_obj.raw_text = "; DELETED_REF " + line_obj.raw_text
						line_was_modified = false # No longer a data line
						break
			
			if line_was_modified:
				# This is inefficient, should bundle updates
				# emit_signal("document_updated") 
				pass
	
	# TODO: Clean up lines marked for deletion
	pass

# --- Other Logic ---
# TBD all other functions (mirror, color, etc.) need to be refactored
# in the same way, operating on `document_root` and emitting signals.

func color_entire_pet(color_index: String, outline_color_index: String) -> void:
	if color_index.empty() and outline_color_index.empty():
		return
		
	save_backup()
	emit_signal("pre_document_update")
	
	var ballz_info = _get_all_data_lines("Ballz Info")
	for line_obj in ballz_info:
		# TODO: Add exclusion logic for eyes, etc.
		var parts = line_obj.parsed_data.parts
		if !color_index.empty(): parts[0] = color_index
		if !outline_color_index.empty(): parts[1] = outline_color_index

	var add_ball = _get_all_data_lines("Add Ball")
	for line_obj in add_ball:
		# TODO: Add exclusion logic
		var parts = line_obj.parsed_data.parts
		if !color_index.empty(): parts[4] = color_index
		if !outline_color_index.empty(): parts[5] = outline_color_index

	emit_signal("document_updated")
	save_file()

# --- Scene Tree Callers ---
# These are harder to move, as they read from UI/Scene nodes.
# They should be refactored to take the data they need as arguments.

func _on_headshot_button_pressed() -> void:
	# This function needs data from the scene (camera, slider).
	# The UI node (e.g., ToolsMenu) should get this data
	# and pass it to a new function here.
	
	# Example:
	# func set_headshot(frame, yaw, roll, tilt):
	#   ... logic ...
	
	print("Headshot logic needs refactoring to pass in scene data.")
	pass

func _on_add_ball_tool(reference_ball: Spatial, also_connect_line := false) -> void:
	# This function is complex as it reads state from the 3D node.
	# This logic might need to live *partially* in the 3D node,
	# which then calls a simpler API here, e.g.:
	# LnzDocument.create_addball(base_ball_no, pos, color, size, ...)
	print("Add Ball logic needs significant refactoring.")
	pass

func _on_apply_paintballz() -> void:
	# Same as above. The Pet Node should get its pending paintballs
	# and pass them as pure data to a new function here.
	print("Apply Paintballz logic needs refactoring.")
	pass

# --- Functions To-Do ---

func create_line(start_ball, end_ball): pass
func color_part(ball_nos, color, outline_color, part_name): pass
func recolor_from_map(recolor_info): pass
func move_head(x, y, z): pass
func mirror_l_to_r(selected_ball_no): 
	print("Mirror L-R logic needs to be refactored for new model.")
	pass
func set_palette(palette_name): pass
func apply_preset_to_ball(ball_no, properties, write_target, should_override): pass
func write_project_ball_section(projections_array): pass

func _create_section(section_name: String) -> void:
	if document_root.sections.has(section_name):
		return # Already exists
		
	var section_object: Dictionary = {
		"name": section_name,
		"raw_header": "[" + section_name + "]",
		"lines": []
	}
	
	emit_signal("pre_document_update")
	document_root.sections[section_name] = section_object
	document_root.section_order.append(section_name)
	emit_signal("document_updated")