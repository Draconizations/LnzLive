extends TextEdit

# LnzTextEdit.gd – syncs the LNZ text file with the 3D pet editor
# - Loads and saves .lnz files
# - Creates automatic backups before overwriting
# - Preserves scroll and cursor positions across edits
# - Listens for visual editor events
# - Finds and updates the corresponding LNZ sections
# - Handles batch recolor and mirror‐copy operations
# - Emits signals for file_saved, file_backed_up, and find_ball actions

var is_user_file = false
var filepath: String
var r = RegEx.new()

signal file_saved(filepath)
signal find_ball(ball_no)
signal file_backed_up()

var min_font_size = 16

onready var apply_changes_button = get_node("../../../PetViewContainer/VBoxContainer/HelperContainer/VBoxContainer/ApplyChangesButton")

onready var frame_slider = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/FrameSlider"
) as HSlider

onready var camera_holder = get_tree().root.get_node(
	"Root/SceneRoot/ViewportContainer/Viewport/CameraHolder"
) as Spatial

func _ready():
	wrap_enabled = false
	r.compile("[-.\\d]+")
	apply_changes_button.connect("pressed", self, "_on_ApplyChangesButton_pressed")
	
	add_color_region("[","]",Color(0.247119, 0.691406, 0.691406),false)
	add_color_region(";","",Color(0.168627, 0.45098, 0.45098),false)

	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var signals = [
		"ball_resized",
		"addball_created",
		"line_created"
		]
	for s in signals:
		if not pet_node.is_connected(s, self, "_on_Node_" + s):
			pet_node.connect(s, self, "_on_Node_" + s)

	var file_tree = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/Tree")
	if file_tree and not file_tree.is_connected("palette_selected", self, "_on_palette_selected"):
		file_tree.connect("palette_selected", self, "_on_palette_selected")
	if file_tree and not file_tree.is_connected("example_file_selected", self, "_on_example_file_selected"):
		file_tree.connect("example_file_selected", self, "_on_example_file_selected")

func _load_file(filepath: String, user_flag: bool):
	var file = File.new()
	file.open(filepath, File.READ)
	var contents = file.get_as_text()
	file.close()
	self.filepath = filepath
	is_user_file = user_flag
	_set_text_preserve(contents)

func _on_example_file_selected(filepath):
	_load_file(filepath, false)

func _on_user_file_selected(filepath):
	if filepath == null:
		return
	_load_file(filepath, true)

func _unhandled_key_input(event):
	if Input.is_key_pressed(KEY_CONTROL) and event.pressed and event.scancode == KEY_S:
		save_file()

func _set_text_preserve(new_text: String):
	var old_v = get_v_scroll()
	var old_h = get_h_scroll()
	var old_l = cursor_get_line()
	var old_c = cursor_get_column()
	text = new_text
	set_v_scroll(old_v)
	set_h_scroll(old_h)
	cursor_set_line(old_l)
	cursor_set_column(old_c)

func _on_IncreaseFontButton_pressed():
	var font = get_font("font")
	if font:
		font.size += 2
		# Rerender to apply font changes
		_set_text_preserve(get_text())

func _on_DecreaseFontButton_pressed():
	var font = get_font("font")
	if font:
		font.size = max(min_font_size, font.size - 2)
		_set_text_preserve(get_text())

func save_backup():
	if not is_user_file:
		return

	var dir = Directory.new()
	var base_path = filepath.trim_suffix(".lnz")
	var backup_path1 = base_path + "_backup_1.lnz"
	var backup_path2 = base_path + "_backup_2.lnz"
	var backup_path3 = base_path + "_backup_3.lnz"

	# Rotate backups: 2 -> 3, 1 -> 2
	if dir.file_exists(backup_path2):
		if dir.file_exists(backup_path3):
			dir.remove(backup_path3)
		dir.rename(backup_path2, backup_path3)

	if dir.file_exists(backup_path1):
		dir.rename(backup_path1, backup_path2)

	# Create new backup
	var file = File.new()
	file.open(backup_path1, File.WRITE)
	file.store_string(text)
	file.close()
	emit_signal("file_backed_up")

func save_file():
	if filepath == null or filepath.empty():
		var dir = Directory.new()
		var base_path = "user://resources/"
		dir.open("user://")
		dir.make_dir_recursive("resources") 
		
		var default_name = "unnamed.lnz"
		var possible_file_name = base_path + default_name
		var counter = 1
		
		while dir.file_exists(possible_file_name):
			possible_file_name = base_path + "unnamed_" + str(OS.get_unix_time()) + ".lnz"
			counter += 1
		
		filepath = possible_file_name
		is_user_file = true

	if is_user_file:
		var dir = Directory.new()
		dir.open("user://")
		dir.make_dir("resources")
		var file = File.new()
		file.open(filepath, File.WRITE)
		file.store_string(text)
		file.close()
	else:
		var dir = Directory.new()
		dir.open("user://")
		dir.make_dir("resources")
		var possible_file_name = filepath.replace("res://", "user://")
		var file = File.new()
		if file.file_exists(possible_file_name):
			possible_file_name = possible_file_name.replace(".lnz", str(OS.get_unix_time()) + ".lnz")
		file.open(possible_file_name, File.WRITE)
		file.store_string(text)
		file.close()
		filepath = possible_file_name
		is_user_file = true

	emit_signal("file_saved", filepath)
	_set_text_preserve(get_text())
	print("Saved LNZ and Applied Changes!")

# TBD fix all delimiter handling...

func _get_section_bounds(section_tag: String) -> Dictionary:
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		return {}
	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var next_sec_search = search("[", 0, start_line, 0)
	var end_line
	if next_sec_search.empty():
		end_line = get_line_count()
	else:
		end_line = next_sec_search[SEARCH_RESULT_LINE]
	return {"start": start_line, "end": end_line}

func _split_line(line: String) -> Array:
	var regex = RegEx.new()
	regex.compile("[\\s,]+")
	var cleaned_line = line.strip_edges()
	var normalized_line = regex.sub(cleaned_line, " ", true)
	var parts = normalized_line.split(" ", false)
	return parts

func _detect_delimiter(start_line: int, end_line: int) -> String:
	# Define join strings and the patterns to find them
	# Check for most complex (comma + whitespace) first
	var delim_counts = {
		", ": 0,  # "comma-space", "comma-tab", "comma-multispace"
		",": 0,   # "comma"
		"\t": 0,  # "tab"
		" ": 0    # "space", "multispace"
	}
	var lines_scanned = 0
	
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue
		lines_scanned += 1
		
		var data_part = line.split(";", false)[0] # Only check data part

		# Check in order of specificity
		if data_part.find(",\t") != -1 or data_part.find(", ") != -1:
			# Catches comma-tab, comma-space, comma-multispace
			delim_counts[", "] += 1
		elif data_part.find(",") != -1:
			# Catches comma-only
			delim_counts[","] += 1
		elif data_part.find("\t") != -1:
			# Catches tab
			delim_counts["\t"] += 1
		elif data_part.find(" ") != -1:
			# Catches space, multispace
			if data_part.split(" ", false).size() > 1:
				delim_counts[" "] += 1

	if lines_scanned == 0:
		return " " # Default joiner

	var most_frequent_delim = " "
	var max_count = 0

	# Iterate in the same priority order to select the winner
	for delim in [", ", ",", "\t", " "]:
		if delim_counts[delim] > max_count:
			max_count = delim_counts[delim]
			most_frequent_delim = delim

	return most_frequent_delim

func _split_and_clean(line: String, p_delimiter: String = "") -> Array:
	var line_parts = line.split(";")
	var data_part = line_parts[0].strip_edges()

	return _split_line(data_part)

func _update_fields(parts: Array, updates: Dictionary, sep: String) -> String:
	var new_parts = []
	for i in range(parts.size()):
		if updates.has(i):
			new_parts.append(updates[i])
		else:
			new_parts.append(parts[i])
	return _join_array(new_parts, sep)

func _join_array(parts: Array, delimiter: String) -> String:
	var result = ""
	for i in range(parts.size()):
		result += str(parts[i])
		if i < parts.size() - 1:
			result += delimiter
	return result

func _for_each_line_in_section(tag: String, callback):
	var bounds = _get_section_bounds(tag)
	if bounds.empty():
		return
	for i in range(bounds["start"], bounds["end"]):
		var line = get_line(i)
		if line.strip_edges() == "" or line.begins_with(";"):
			continue
		callback.call(i, line)

func _insert_text_at_cursor_at_line(line: int, text: String):
	cursor_set_line(line)
	cursor_set_column(0)
	select(line, 0, line, 0) # clear selection
	insert_text_at_cursor(text)

# Helper for multi-delimiter line splitting
func _smart_split(line: String) -> PoolStringArray:
	var delimiters = [", ", ",", "\t", " "]
	for delim in delimiters:
		var split = line.split(delim, false)
		if split.size() >= 3:
			return split
	return PoolStringArray()

# Manual insert at line (workaround for Godot 3.x lacking built-in insert_line)
func _insert_text_at_line(line_no: int, text: String):
	var result = ""
	var total_lines = get_line_count()
	for i in range(total_lines):
		if i == line_no:
			result += text.strip_edges() + "\n"
		result += get_line(i) + "\n"
	if line_no >= total_lines:
		result += text.strip_edges() + "\n"
	set_text(result.strip_edges())

func find_line_in_ball_section(ball_no):
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_point = section_find[SEARCH_RESULT_LINE] + 1
	return find_line_in_ball_or_addball_section(ball_no, start_point)
	
func find_line_in_addball_section(ball_no):
	var section_find = search('[Add Ball]', 0, 0, 0)
	var start_point = section_find[SEARCH_RESULT_LINE] + 1
	return find_line_in_ball_or_addball_section(ball_no, start_point)
	
func find_line_in_move_section(ball_no):
	var section_find = search('[Move]', 0, 0, 0)
	var current_line = cursor_get_line()
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search('[', 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	var start_point
	if current_line >= start_of_section and current_line < end_of_section:
		start_point = current_line
	else:
		start_point = start_of_section
	var i = 0
	while true:
		var looped = start_point + i
		var line = get_line(looped).lstrip(" ")
		if line.begins_with("["):
			if start_point == start_of_section:
				return start_of_section - 1
			else:
				start_point = start_of_section
				i = 0
				continue
		if line.begins_with(str(ball_no) + " "):
			break
		i += 1
	return start_point + i

func find_line_in_project_section(ball_no):
	var section_find = search('[Project Ball]', 0, 0, 0)
	var current_line = cursor_get_line()
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search('[', 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	var start_point
	if current_line >= start_of_section and current_line < end_of_section:
		start_point = current_line + 1
	else:
		start_point = start_of_section
	var i = 0
	while true:
		var looped = start_point + i
		var line = get_line(looped).lstrip(" ")
		var parsed_line = r.search_all(line)
		if line.begins_with("["):
			if start_point == start_of_section:
				return start_of_section - 1
			else:
				start_point = start_of_section
				i = 0
				continue
		if parsed_line.size() > 1 and parsed_line[1].get_string() == str(ball_no):
			break
		
		i += 1
	return start_point + i
	
func find_line_in_linez_section(ball_no):
	var section_find = search('[Linez]', 0, 0, 0)
	var current_line = cursor_get_line()
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search('[', 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	var start_point
	if current_line >= start_of_section and current_line < end_of_section:
		start_point = current_line + 1
	else:
		start_point = start_of_section
	var i = 0
	while true:
		var looped = start_point + i
		var line = get_line(looped).lstrip(" ")

		if line.begins_with(";"):
			i += 1
			continue
			
		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if line.begins_with("["):
			if start_point == start_of_section:
				return start_of_section - 1
			else:
				start_point = start_of_section
				i = 0
				continue
		if parsed_line[0] == str(ball_no) or parsed_line[1] == str(ball_no):
			break
		
		i += 1
	return start_point + i

func find_line_in_ball_or_addball_section(ball_no, start_point):
	var line = get_line(start_point)
	while true:
		if !line.lstrip(" ").begins_with(";"):
			break
		start_point += 1
		line = get_line(start_point)
	var i = 0
	var j = -1
	while true:
		line = get_line(start_point + i)
		if !line.lstrip(" ").begins_with(";"):
			j += 1
		if j == ball_no:
			break;
		i += 1
	return start_point + i

func get_corresponding_right_ball(left_ball_index):
	if left_ball_index < KeyBallsData.max_base_ball_num:
		if KeyBallsData.species == KeyBallsData.Species.CAT:
			if left_ball_index in [8, 9]:
				return left_ball_index + 2
			elif left_ball_index in [16, 17, 18] or left_ball_index in [49, 50, 51] or left_ball_index in [57, 58, 59]: # finger, toe, whisker
				return left_ball_index + 3
			else:
				return left_ball_index + 1
		else:
			return left_ball_index + 24
	else:
		return ball_map[ball_map[left_ball_index].corresponding_ball].new_ball_no
		
func get_corresponding_left_ball(right_ball_index):
	if right_ball_index < KeyBallsData.max_base_ball_num:
		if KeyBallsData.species == KeyBallsData.Species.CAT:
			if right_ball_index in [10, 11]:
				return right_ball_index - 2
			elif right_ball_index in [19, 20, 21] or right_ball_index in [52, 53, 54] or right_ball_index in [60, 61, 62]: # finger, toe, whisker
				return right_ball_index - 3
			else:
				return right_ball_index - 1
		else:
			return right_ball_index - 24
	else:
		return ball_map[ball_map[right_ball_index].corresponding_ball].new_ball_no

var ball_map = {}

func _on_ApplyChangesButton_pressed():
	save_backup()
	save_file()

func _on_apply_paintballz():
	save_backup()
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var pending_paintballs = pet_node._pending_paintballs_data

	if pending_paintballs.size() > 0:
		var is_babyz = pet_node.lnz.species == KeyBallsData.Species.BABY
		var bounds = _get_section_bounds("[Paint Ballz]")
		var insert_line_num

		if bounds.empty():
			var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
			var all_lines = get_text().split("\n")
			all_lines.insert(first_section, "[Paint Ballz]")
			all_lines.insert(first_section + 1, "")
			text = all_lines.join("\n")
			_set_text_preserve(text)
			bounds = _get_section_bounds("[Paint Ballz]")

		insert_line_num = bounds["start"]
		var j = 0
		while insert_line_num + j < bounds["end"]:
			var line = get_line(insert_line_num + j).strip_edges()
			if line.begins_with(";"):
				j += 1
				continue
			break
		insert_line_num += j

		var delim = _detect_delimiter(bounds["start"], bounds["end"])
		var new_paintball_lines = ""

		var paintball_lines_list = []
		for i in range(pending_paintballs.size() - 1, -1, -1):
			var paintball_info = pending_paintballs[i]
			var relative_pos_lnz = paintball_info.relative_pos_lnz

			var paintball_line = str(paintball_info.base_ball_no) + delim
			paintball_line += str(paintball_info.diameter) + delim
			paintball_line += str(round(relative_pos_lnz.x)) + delim
			paintball_line += str(round(relative_pos_lnz.y)) + delim
			paintball_line += str(round(relative_pos_lnz.z)) + delim
			paintball_line += str(paintball_info.color) + delim
			paintball_line += str(paintball_info.outline_color) + delim
			paintball_line += str(paintball_info.fuzz) + delim
			paintball_line += str(paintball_info.outline_type) + delim
			paintball_line += str(paintball_info.group) + delim
			paintball_line += str(paintball_info.texture) + delim
			paintball_line += str(int(!paintball_info.anchored))
			paintball_lines_list.append(paintball_line)

		if is_babyz:
			for rep in range(1, 6):
				for line in paintball_lines_list:
					new_paintball_lines += line + " ;rep" + str(rep) + "\n"
		else:
			for line in paintball_lines_list:
				new_paintball_lines += line + "\n"

		_insert_text_at_cursor_at_line(insert_line_num, new_paintball_lines)
		pet_node.clear_pending_paintballs()
	
	save_backup()

	save_file()

	var pet_view_container = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pet_view_container.close_paintball_on_apply:
		pet_view_container.close_paintball_mode()

func _on_Tree_backup_file():
	save_backup()

func _wrap_angle_deg(a: int) -> int:
	var ang = ((a % 360) + 360) % 360
	if ang > 180:
		ang -= 360
	return ang

func _on_palette_selected(filename_without_extension):
	save_backup()
	var bounds = _get_section_bounds("[Palette]")
	var new_line = filename_without_extension

	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Palette]")
		all_lines.insert(first_section + 1, new_line)
		text = all_lines.join("\n")
		_set_text_preserve(text)
	else:
		var start_line = bounds["start"]
		var end_line = bounds["end"]
		var found_palette_line = false
		for i in range(start_line, end_line):
			var line = get_line(i).strip_edges()
			if line.begins_with(""):
				set_line(i, new_line)
				found_palette_line = true
				break
		
		if not found_palette_line:
			var insert_line = _find_insertion_line(start_line, end_line)
			_insert_text_at_cursor_at_line(insert_line, new_line)
	
	save_file()

func _on_HeadShotButton_pressed():
	save_backup()
	var local_frame = int(frame_slider.value)
	var cam_e = camera_holder.rotation_degrees   # x=pitch, y=yaw, z=roll

	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var anim_idx = pet_node.current_animation
	var start_idx = pet_node.bhd.animation_ranges[anim_idx].actual_start
	var global_frame = start_idx + local_frame
	
	var raw_yaw  = -int(cam_e.y)
	var raw_roll = -int(cam_e.z)
	var raw_tilt = -int(cam_e.x)

	var yaw  = _wrap_angle_deg(raw_yaw)
	var roll = _wrap_angle_deg(raw_roll)
	var tilt = _wrap_angle_deg(raw_tilt)

	var shot_lines = [
		str(global_frame),
		str(yaw),
		str(roll),
		str(tilt)
	]

	var shot_labels = ["frame number", "rotation", "roll", "tilt"]
	for i in range(shot_lines.size()):
		var s = shot_lines[i]
		while s.length() < 24:
			s += " "
		shot_lines[i] = s + shot_labels[i]

	var bounds = _get_section_bounds("[Head Shot]")
	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Head Shot]")
		var temp = ""
		for line in all_lines:
			temp += line + "\n"
		_set_text_preserve(temp)
		bounds = _get_section_bounds("[Head Shot]")

	var lines = get_text().split("\n")

	var before_lines = []
	for i in range(bounds["start"]):
		before_lines.append(lines[i])

	var tail_lines = []
	var head_block_len = shot_lines.size()
	for i in range(bounds["start"] + head_block_len, bounds["end"]):
		tail_lines.append(lines[i])

	for i in range(min(3, tail_lines.size())):
		tail_lines[i] = "0"

	var tail_labels = [
		"head rotation",
		"head tilt",
		"head cock",
		"R / L eyelid height",
		"R / L eyelid tilt",
		"(X, Y) eye target"
	]

	for i in range(min(tail_labels.size(), tail_lines.size())):
		var raw = tail_lines[i]
		var num = ""
		for c in raw:
			if c.is_valid_integer() or c == "," or c == "-" or c == " ":
				num += c
			else:
				break
		num = num.strip_edges()
		while num.length() < 24:
			num += " "
		tail_lines[i] = num + tail_labels[i]

	var after_lines = []
	for i in range(bounds["end"], lines.size()):
		after_lines.append(lines[i])

	var new_text = ""
	for line in before_lines:
		new_text += line + "\n"
	for line in shot_lines:
		new_text += line + "\n"
	for line in tail_lines:
		new_text += line + "\n"
	for line in after_lines:
		new_text += line + "\n"

	_set_text_preserve(new_text)
	save_file()

# Connect by Linez
func _on_Node_line_created(start_ball, end_ball):
	save_backup()
	var bounds = _get_section_bounds("[Linez]")
	var start_line = bounds["start"]
	var end_line = bounds["end"]

	if start_line == -1:
		print("[LNZ EDIT] No [Linez] section found")
		# You might want to create the section if it doesn't exist.
		# For now, just returning.
		return

	var delim = _detect_delimiter(start_line, end_line)
	var sep = delim

	var line_mode_settings = get_tree().root.get_node("Root/SceneRoot/LineModeSettings")
	var props = line_mode_settings.get_properties()

	# Search for an existing line
	var line_updated = false
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line == "" or line.begins_with(";"):
			continue

		var parts = _split_and_clean(line)
		if parts.size() < 2:
			continue

		var b1 = int(parts[0])
		var b2 = int(parts[1])

		if (b1 == start_ball and b2 == end_ball) or (b1 == end_ball and b2 == start_ball):
			if parts.size() < 10:
				parts.resize(10)
			parts[2] = str(props.fuzz)
			parts[3] = str(props.color)
			parts[4] = str(props.left_outline_color)
			parts[5] = str(props.right_outline_color)
			parts[6] = str(props.start_thickness)
			parts[7] = str(props.end_thickness)
			parts[8] = str(props.outline_type)
			parts[9] = str(props.draw_order)

			set_line(i, parts.join(sep))
			line_updated = true
			break

	if not line_updated:
		var insert_line = end_line
		while insert_line > start_line and get_line(insert_line - 1).strip_edges() == "":
			insert_line -= 1

		var new_line_parts = [
			str(start_ball),
			str(end_ball),
			str(props.fuzz),
			str(props.color),
			str(props.left_outline_color),
			str(props.right_outline_color),
			str(props.start_thickness),
			str(props.end_thickness),
			str(props.outline_type),
			str(props.draw_order)
		]
		var new_line = ""
		for i in range(new_line_parts.size()):
			new_line += new_line_parts[i]
			if i < new_line_parts.size() - 1:
				new_line += sep
		new_line += "\n"

		_insert_text_at_cursor_at_line(insert_line, new_line)
		cursor_set_line(insert_line)
		cursor_set_column(0)
		center_viewport_to_cursor()

	save_file()

# Create Addballz (+ Linez)
func _on_ToolsMenu_add_ball(reference_ball, also_connect_line := false):
	save_backup()
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	if reference_ball == null:
		print("[LNZ EDIT] No reference ball given")
		return

	var ball_no = reference_ball.ball_no
	var lnz = pet_node.lnz

	var lnz_size := 20  # fallback

	if reference_ball != null:
		var ref_no = reference_ball.ball_no
		var is_addball_ref = ref_no >= KeyBallsData.max_base_ball_num or reference_ball.is_in_group("addballs")

		if is_addball_ref and lnz.addballs.has(ref_no):
			var ref_ab = lnz.addballs[ref_no]
			var s = 0

			if typeof(ref_ab) == TYPE_DICTIONARY:
				if ref_ab.has("ball_size"):
					s = int(ref_ab["ball_size"])
				elif ref_ab.has("size"):
					s = int(ref_ab["size"])
			else:
				if "ball_size" in ref_ab:
					s = int(ref_ab.ball_size)
				elif "size" in ref_ab:
					s = int(ref_ab.size)

			if s > 0:
				lnz_size = s
			elif reference_ball.has_method("set_ball_size"):
				lnz_size = int(round(reference_ball.ball_size))
		elif reference_ball.has_method("set_ball_size"):
			lnz_size = int(round(reference_ball.ball_size))

	var addball_data = lnz.addballs.get(ball_no, null)
	var ball_data = lnz.balls.get(ball_no, null)

	var fuzz_amount = 0
	if addball_data != null:
		fuzz_amount = addball_data.fuzz
	elif ball_data != null:
		fuzz_amount = ball_data.fuzz

	var texture_id = -1
	if addball_data != null:
		texture_id = addball_data.texture_id
	elif ball_data != null:
		texture_id = ball_data.texture_id

	var real_base_ball = ball_no
	if reference_ball.base_ball_no != -1:
		real_base_ball = reference_ball.base_ball_no

	var new_pos = Vector3(0, 0, 0)
	if reference_ball.base_ball_no != -1 and addball_data != null:
		new_pos = addball_data.position - Vector3(0, 0, 0)

	var bodyarea = 1
	if KeyBallsData.bodyarea_map.has(real_base_ball):
		bodyarea = KeyBallsData.bodyarea_map[real_base_ball]
	else:
		print("Missing bodyarea for ball", real_base_ball)
	
	var section_find = search("[Add Ball]", 0, 0, 0)
	if section_find.empty():
		print("[LNZ EDIT] No [Add Ball] section found")
		return
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	var delim = _detect_delimiter(start_line, end_line)
	var insert_line = _find_insertion_line(start_line, end_line)

	var fields = [
		str(real_base_ball),
		str(int(new_pos.x)),
		str(int(new_pos.y)),
		str(int(new_pos.z)),
		str(reference_ball.color_index),
		str(reference_ball.outline_color_index),
		"0",
		str(fuzz_amount),
		"0",
		str(reference_ball.old_outline),
		str(lnz_size),
		str(bodyarea),
		"0",
		str(texture_id)
	]

	var line_text = ""
	for i in range(fields.size()):
		line_text += fields[i]
		if i < fields.size() - 1:
			line_text += delim
	line_text += "\n"

	_insert_text_at_cursor_at_line(insert_line, line_text)
	cursor_set_line(insert_line)
	cursor_set_column(0)
	center_viewport_to_cursor()

	var addball_no = KeyBallsData.max_base_ball_num + _count_section_entries("[Add Ball]") - 1

	if also_connect_line:
		_on_Node_line_created(addball_no, reference_ball.ball_no)

	var pvc = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pvc and pvc.has_method("schedule_autodrag_for_addball"):
		pvc.schedule_autodrag_for_addball(addball_no)

	save_file()

func _count_section_entries(section_name: String) -> int:
	var section_find = search(section_name, 0, 0, 0)
	if section_find.empty():
		return 0
		
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var entry_count = 0
	var current_line_num = start_line
	
	while current_line_num < get_line_count():
		var line = get_line(current_line_num).strip_edges()
		
		if line.begins_with("["):
			break
		
		if line == "" or line.begins_with(";"):
			current_line_num += 1
			continue
		
		entry_count += 1
		current_line_num += 1
		
	return entry_count

func _find_insertion_line(start_line: int, end_line: int) -> int:
	var i = end_line
	while i > start_line and get_line(i - 1).strip_edges() == "":
		i -= 1
	return i

# Deletes an addball and references, or marks a base ball for omission
func _on_ToolsMenu_delete_ball(ball_no: int):
	save_backup()
	var is_addball = ball_no > KeyBallsData.max_base_ball_num
	if is_addball:
		var line_no = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		if line_no != -1:
			select(line_no, 0, line_no + 1, 0)
			cut()
		_update_all_references(ball_no)
	else:
		_mark_base_ball_omitted(ball_no)

	save_file()

# Handles [Linez], [Omissions], [Project Ball], [Paint Ballz]
func _update_all_references(ball_no: int):
	_update_pairwise_section("[Linez]", ball_no)
	_update_single_number_section("[Omissions]", ball_no)
	_update_project_ball_section("[Project Ball]", ball_no)
	_update_paintballz_section("[Paint Ballz]", ball_no)

# Inserts a base ball into [Omissions] if not present
func _mark_base_ball_omitted(ball_no: int):
	var section = search("[Omissions]", 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1

	# Scan section first to avoid modifying it while iterating
	var already_omitted = false
	var end = get_line_count()
	for i in range(start, end):
		var line = get_line(i).strip_edges()
		if line.begins_with("[") or line == "":
			break
		if int(line) == ball_no:
			already_omitted = true
			break

	if not already_omitted:
		_insert_text_at_line(start, str(ball_no) + "\n")

# Generic for [Linez] with start/end ball pair
func _update_pairwise_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var tokens = _smart_split(line)
		var b1 = int(tokens[0])
		var b2 = int(tokens[1])
		if b1 == ball_no or b2 == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		if b1 > ball_no: b1 -= 1
		if b2 > ball_no: b2 -= 1
		var rest = ""
		for j in range(2, tokens.size()):
			if j > 2:
				rest += " "
			rest += tokens[j]

		set_line(start + i, "%s %s %s" % [b1, b2, rest])
		i += 1

# Generic for single-number lists like [Omissions]
func _update_single_number_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var val = int(line)
		if val == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif val > ball_no:
			set_line(start + i, str(val - 1))
		i += 1

# Specific for [Project Ball] where 2nd token is ball_no
func _update_project_ball_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var tokens = _smart_split(line)
		var move_ball = int(tokens[1])
		if move_ball == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif move_ball > ball_no:
			var rest = line.substr(tokens[2].get_start())
			set_line(start + i, "%s %s %s" % [tokens[0], str(move_ball - 1), rest])
		i += 1

# Specific for [Paint Ballz] where 1st token is base ball number
func _update_paintballz_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var split = line.split(" ", false, 1)
		var b = int(split[0])
		if b == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif b > ball_no:
			set_line(start + i, "%s %s" % [str(b - 1), split[1]])
		i += 1

func _on_Node_ball_selected(section, ball_no, is_addball, max_addball_no):
	# need to find line number for the ball
	var actual_start_point
	if section == Section.Section.BALL:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		else:
			actual_start_point = find_line_in_ball_section(ball_no)
	elif section == Section.Section.MOVE:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		else:
			actual_start_point = find_line_in_move_section(ball_no)
	elif section == Section.Section.PROJECT:
		actual_start_point = find_line_in_project_section(ball_no)
	elif section == Section.Section.LINE:
		actual_start_point = find_line_in_linez_section(ball_no)
	if actual_start_point == -1:
		return
	cursor_set_line(actual_start_point)
	cursor_set_column(0)
	center_viewport_to_cursor()

func _on_ToolsMenu_color_entire_pet(color_index, outline_color_index):
	save_backup()
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.nose_cat)
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
	elif species == KeyBallsData.Species.DOG:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.nose_dog)
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_bab)
		balls_to_exclude.append_array(KeyBallsData.eyebrow_bab)
		
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		if i in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		# here the first number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 0 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 1 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	
	section_find = search('[Add Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	while true:
		if i + KeyBallsData.max_base_ball_num in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		# here the fifth number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if parsed_line.size() == 0 or int(parsed_line[0]) in balls_to_exclude:
			i += 1
			continue
		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 4 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 5 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	save_file()


func _on_ToolsMenu_color_part_pet(core_ball_nos, color_index, outline_color_index, intended_part):
	save_backup()
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
		if intended_part != "NOSE":
			balls_to_exclude.append_array(KeyBallsData.nose_cat)
	elif species == KeyBallsData.Species.DOG:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
		if intended_part != "NOSE":
			balls_to_exclude.append_array(KeyBallsData.nose_dog)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_bab)
		
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		if i in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		if !(i in core_ball_nos):
			i += 1
			continue
		# here the first number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 0 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 1 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	
	section_find = search('[Add Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	while true:
		if i + KeyBallsData.max_base_ball_num in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		# here the fifth number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if parsed_line.size() == 0 or int(parsed_line[0]) in balls_to_exclude:
			i += 1
			continue
		if !(int(parsed_line[0]) in core_ball_nos):
			i+=1
			continue
		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 4 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 5 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	save_file()

#####

func _find_mirrored_ball(ball_no: int) -> int:
    if ball_no >= KeyBallsData.max_base_ball_num:
        return ball_no
        
    var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
    var species = pet_node.lnz.species 
    var symmetry_dict = {}

    if species == KeyBallsData.Species.CAT:
        symmetry_dict = KeyBallsData.cat_body_part_symmetry
    elif species == KeyBallsData.Species.DOG:
        symmetry_dict = KeyBallsData.dog_body_part_symmetry
    elif species == KeyBallsData.Species.BABY:
        symmetry_dict = KeyBallsData.baby_body_part_symmetry
    else:
        return ball_no

    for main_part in symmetry_dict:
        for sub_part in symmetry_dict[main_part]:
            var part_info = symmetry_dict[main_part][sub_part]
            if part_info.has("left") and part_info.has("right"):
                var index = part_info.left.find(ball_no)
                if index != -1 and index < part_info.right.size():
                    return part_info.right[index]
                
                index = part_info.right.find(ball_no)
                if index != -1 and index < part_info.left.size():
                    return part_info.left[index]
    
    var left_balls = []
    if species == KeyBallsData.Species.CAT:
        left_balls = KeyBallsData.symmetry_mode_hide_balls_cat
    elif species == KeyBallsData.Species.DOG:
        left_balls = KeyBallsData.symmetry_mode_hide_balls_dog
    elif species == KeyBallsData.Species.BABY:
        left_balls = KeyBallsData.symmetry_mode_hide_balls_bab
        
    if ball_no in left_balls:
        return get_corresponding_right_ball(ball_no)

    return ball_no

func _on_ToolsMenu_copy_l_to_r(selected_ball_no: int = -1):
    if selected_ball_no == -1:
        _mirror_l_to_r_full()
    else:
        _mirror_l_to_r_ball(selected_ball_no)

func _mirror_l_to_r_full():
	save_backup()
	
	# build up ball map
	ball_map = {}
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	var left_balls_list = []
	var right_balls_list = []
	var middle_balls_list = []
	if KeyBallsData.species == KeyBallsData.Species.CAT:
		left_balls_list = KeyBallsData.symmetry_mode_hide_balls_cat.duplicate()
		right_balls_list = KeyBallsData.symmetry_mode_right_balls_cat.duplicate()
	else:
		left_balls_list = KeyBallsData.symmetry_mode_hide_balls_dog.duplicate()
		right_balls_list = KeyBallsData.symmetry_mode_right_balls_dog.duplicate()
	if left_balls_list.size() != right_balls_list.size():
		print("you made a mistake")
	for n in range(0,66):
		if !(n in left_balls_list or n in right_balls_list):
			middle_balls_list.append(n)
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		# ignore comments for now
		if line.begins_with("["):
			break
		if i in left_balls_list or i in middle_balls_list:
			var d = {line = line, new_ball_no = i}
			if i in left_balls_list:
				# var parsed_line = r.search_all(line)
				var delimiters = [", ", ",", "\t", " "]
				var parsed_line = []
				for delim in delimiters:
					if line.split(delim).size() > 2:
						parsed_line = line.split(delim, false)
						break
				
				var mirrored_line = ""
				if parsed_line[4] in ["0", "-2"]: # outline needs to be mirrored
					var p = 0
					for item in parsed_line:
						if p == 4: #outline type
							if item == "0":
								mirrored_line += "-2 "
							else:
								mirrored_line += "0 "
						else:
							mirrored_line += item + " "
						p += 1
				else:
					mirrored_line = line
				d.corresponding_ball = get_corresponding_right_ball(i)
				set_line(start_of_section + d.corresponding_ball, mirrored_line)
				ball_map[d.corresponding_ball] = {line = mirrored_line, corresponding_ball = i, new_ball_no = d.corresponding_ball}
			else:
				d.corresponding_ball = null
			ball_map[i] = d
		i += 1
		
	# now the ball map has all the core balls in
	# lets set up the addballs
	
	section_find = search('[Add Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	var ball_no = KeyBallsData.max_base_ball_num
	var balls_to_add_temp = []
	var new_ball_count = KeyBallsData.max_base_ball_num
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		# ignore comments for now
		if line.begins_with("[") or line.empty():
			break
		if ball_no <= 76:
			# utility addball, keep
			ball_map[ball_no] = {line = line, new_ball_no = new_ball_count}
			new_ball_count += 1
		else:
			var base_ball = int(line.split(" ", false, 1)[0])
			if base_ball in left_balls_list:
				left_balls_list.append(ball_no)
				ball_map[ball_no] = {line = line, new_ball_no = new_ball_count}
				new_ball_count += 1
				var corresponding_right_ball = get_corresponding_right_ball(base_ball)

				# var parsed_line = r.search_all(line)
				var delimiters = [", ", ",", "\t", " "]
				var parsed_line = []
				for delim in delimiters:
					if line.split(delim).size() > 2:
						parsed_line = line.split(delim, false)
						break

				var p = 0
				var new_right_ball_line = ""
				for item in parsed_line:
					if p == 0:
						new_right_ball_line += str(corresponding_right_ball) + " "
					elif p == 1: # reverse x value
						new_right_ball_line += str(int(item) * -1.0) + " "
					elif p == 9 and item in ["0", "-2"]: # outline
						if item == "0":
							new_right_ball_line += "-2 "
						else:
							new_right_ball_line += "0 "
					else:
						new_right_ball_line += item + " "
					p+=1
				balls_to_add_temp.append({line = new_right_ball_line, corresponding_ball = ball_no})
			elif base_ball in middle_balls_list:
				# var parsed_line = r.search_all(line)
				var delimiters = [", ", ",", "\t", " "]
				var parsed_line = []
				for delim in delimiters:
					if line.split(delim).size() > 2:
						parsed_line = line.split(delim, false)
						break

				var x_pos = int(parsed_line[1])
				if x_pos > 0.0: #left ball
					ball_map[ball_no] = {line = line, new_ball_no = new_ball_count}
					new_ball_count += 1
					left_balls_list.append(ball_no)
					var p = 0
					var new_right_ball_line = ""
					for item in parsed_line:
						if p == 1: # reverse x value
							new_right_ball_line += str(int(item) * -1.0) + " "
						elif p == 9 and item in ["0", "-2"]: # outline
							if item == "0":
								new_right_ball_line += "-2 "
							else:
								new_right_ball_line += "0 "
						else:
							new_right_ball_line += item + " "
						p+=1
					balls_to_add_temp.append({line = new_right_ball_line, corresponding_ball = ball_no})
				elif x_pos < 0.0: # right ball
					pass
					# do nothing
				else: # middle ball
					ball_map[ball_no] = {line = line, new_ball_no = new_ball_count}
					new_ball_count += 1
					middle_balls_list.append(ball_no)
		i+=1
		ball_no+=1
	var add_count = ball_map.keys().max() + 1
	for b in balls_to_add_temp:
		b.new_ball_no = new_ball_count
		ball_map[add_count] = b
		ball_map[b.corresponding_ball].corresponding_ball = add_count
		add_count += 1
		new_ball_count += 1
	
	var lines_in_addball_section = i
		
	# lines
	
	section_find = search('[Linez]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	var lines_list = []
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		# ignore comments for now
		if line.begins_with("[") or line.empty():
			break

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var start_ball = int(parsed_line[0])
		var end_ball = int(parsed_line[1])
		if start_ball in left_balls_list or end_ball in left_balls_list:
			var final_line = ""
			if !ball_map.has(start_ball) or !ball_map.has(end_ball): # the ball got removed
				pass
			else:
				var final_start_ball = ball_map[start_ball].new_ball_no
				var additional_start_ball
				if start_ball in left_balls_list:
					additional_start_ball = get_corresponding_right_ball(start_ball)
				var final_end_ball = ball_map[end_ball].new_ball_no
				var additional_end_ball
				if end_ball in left_balls_list:
					additional_end_ball = get_corresponding_right_ball(end_ball)
				if additional_end_ball != null or additional_start_ball != null:
					if additional_end_ball == null:
						additional_end_ball = final_end_ball
					elif additional_start_ball == null:
						additional_start_ball = final_start_ball
					var p = 0
					for item in parsed_line:
						if p == 0:
							final_line += str(additional_start_ball) + " "
						elif p == 1:
							final_line += str(additional_end_ball) + " "
						else:
							final_line += item + " "
						p+=1
					lines_list.append(final_line)
					final_line = ""
				var p = 0
				for item in parsed_line:
					if p == 0:
						final_line += str(final_start_ball) + " "
					elif p == 1:
						final_line += str(final_end_ball) + " "
					else:
						final_line += item + " "
					p+=1
				lines_list.append(final_line)
		elif start_ball in middle_balls_list and end_ball in middle_balls_list:
			var final_line = ""
			if !ball_map.has(start_ball) or !ball_map.has(end_ball): # the ball got removed
				pass
			else:
				var final_start_ball = ball_map[start_ball].new_ball_no
				var final_end_ball = ball_map[end_ball].new_ball_no
				var p = 0
				for item in parsed_line:
					if p == 0:
						final_line += str(final_start_ball) + " "
					elif p == 1:
						final_line += str(final_end_ball) + " "
					else:
						final_line += item + " "
					p+=1
				lines_list.append(final_line)
		i += 1
	
	var lines_in_linez_section = i
	
	# deal with moves. only need to care about base balls
	section_find = search('[Move]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	var moves_list = []
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		# ignore comments for now
		if line.begins_with("[") or line.empty():
			break
			
		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var move_ball_no = int(parsed_line[0])
		if move_ball_no in left_balls_list:
			moves_list.append(line)
			var final_line = ""
			var p = 0
			
			var has_anchor = parsed_line.size() > 4
			var new_anchor = -1
			if has_anchor:
			  var old_anchor = parsed_line[4].to_int()
			  new_anchor = _find_mirrored_ball(old_anchor)
			
			for item in parsed_line:
				if p == 0:
					final_line += str(get_corresponding_right_ball(move_ball_no)) + " "
				elif p == 1:
					final_line += str(int(item) * -1.0) + " "
				elif p == 4 and has_anchor:
					final_line += str(new_anchor) + " "
				else:
					final_line += item + " "
				p += 1
			moves_list.append(final_line)
		elif move_ball_no in middle_balls_list:
			moves_list.append(line)
		i += 1
		
	var lines_in_move_section = i
	
	# projections
	section_find = search('[Project Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	var projections_list = []
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		# ignore comments for now
		if line.begins_with("[") or line.empty():
			break
			
		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break
		
		var base_ball_no = int(parsed_line[0])
		var move_ball_no = int(parsed_line[1])
		if move_ball_no in left_balls_list:
			if move_ball_no > 66:
				var new_ball_no = ball_map[move_ball_no].new_ball_no
				var final_line = ""
				var p = 0
				for item in parsed_line:
					if p == 0:
						final_line += str(ball_map[base_ball_no].new_ball_no) + " "
					elif p == 1:
						final_line += str(ball_map[move_ball_no].new_ball_no) + " "
					else:
						final_line += item + " "
					p += 1
				projections_list.append(final_line)
			else:
				projections_list.append(line)
			var final_line = ""
			var p = 0
			for item in parsed_line:
				if p == 0:
					if base_ball_no in left_balls_list:
						final_line += str(get_corresponding_right_ball(base_ball_no)) + " "
					elif !base_ball_no in middle_balls_list: #right ball!
						final_line += str(get_corresponding_left_ball(base_ball_no)) + " "
					else:
						final_line += str(ball_map[base_ball_no].new_ball_no) + " "
				elif p == 1:
					if move_ball_no in left_balls_list:
						final_line += str(get_corresponding_right_ball(move_ball_no)) + " "
					else:
						final_line += str(ball_map[move_ball_no].new_ball_no) + " "
				else:
					final_line += item + " "
				p += 1
			projections_list.append(final_line)
		elif move_ball_no in middle_balls_list:
			var final_line = ""
			var p = 0
			for item in parsed_line:
				if p == 0:
					if base_ball_no in left_balls_list:
						final_line += str(get_corresponding_right_ball(base_ball_no)) + " "
					elif !base_ball_no in middle_balls_list: #right ball!
						final_line += str(get_corresponding_left_ball(base_ball_no)) + " "
					else:
						final_line += str(ball_map[base_ball_no].new_ball_no) + " "
				elif p == 1:
					final_line += str(ball_map[move_ball_no].new_ball_no) + " "
				else:
					final_line += item
				p += 1
			projections_list.append(final_line)
		i += 1
		
	var lines_in_projections_section = i
	
	# paintballs
	section_find = search('[Paint Ballz]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	var paintballs_list = []
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		# ignore comments for now
		if line.begins_with("[") or line.empty():
			break
			
		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var base_ball_no = int(parsed_line[0])
		if base_ball_no in left_balls_list:
			var new_base_ball_no = ball_map[base_ball_no].new_ball_no
			# add original line
			var final_line = ""
			var p = 0
			for item in parsed_line:
				if p == 0:
					final_line += str(new_base_ball_no) + " "
				else:
					final_line += item + " "
				p += 1
			paintballs_list.append(final_line)
			# add flipped line
			final_line = ""
			p = 0
			for item in parsed_line:
				if p == 0:
					final_line += str(get_corresponding_right_ball(base_ball_no)) + " "
				elif p == 2:
					final_line += str(float(item) * -1.0) + " "
				else:
					final_line += item + " "
				p += 1
			paintballs_list.append(final_line)
		elif base_ball_no in middle_balls_list:
			var x_pos = float(parsed_line[2])
			if x_pos < 0.0: # right ball do nothing
				pass
			else:
				var new_base_ball_no = ball_map[base_ball_no].new_ball_no
				# add original line
				var final_line = ""
				var p = 0
				for item in parsed_line:
					if p == 0:
						final_line += str(new_base_ball_no) + " "
					else:
						final_line += item + " "
					p += 1
				paintballs_list.append(final_line)
				if x_pos > 0.0: # left side
					final_line = ""
					p = 0
					for item in parsed_line:
						if p == 0:
							final_line += str(new_base_ball_no) + " "
						elif p == 2:
							final_line += str(x_pos * -1.0) + " "
						else:
							final_line += item + " "
						p += 1
					paintballs_list.append(final_line)
		i += 1
	
	var lines_in_paintball_section = i
	
	# remove all the addball lines!
	# in a really moronic way
	section_find = search('[Add Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	select(start_of_section, 0, start_of_section + lines_in_addball_section - 1, 999)
	cut()
	cursor_set_line(start_of_section)
	cursor_set_column(0)
	var final_text = ""
	for k in ball_map:
		if k > 66:
			final_text += ball_map[k].line + "\n"
	final_text = final_text.strip_edges()
	insert_text_at_cursor(final_text)
	
	# remove all the linez lines!
	# in a really moronic way
	section_find = search('[Linez]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	select(start_of_section, 0, start_of_section + lines_in_linez_section - 1, 999)
	cut()
	cursor_set_line(start_of_section)
	cursor_set_column(0)
	final_text = ""
	for k in lines_list:
		final_text += k + "\n"
	final_text = final_text.strip_edges()
	insert_text_at_cursor(final_text)
	
	# remove all the moves lines!
	# in a really moronic way
	section_find = search('[Move]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	select(start_of_section, 0, start_of_section + lines_in_move_section - 1, 999)
	cut()
	cursor_set_line(start_of_section)
	cursor_set_column(0)
	final_text = ""
	for k in moves_list:
		final_text += k + "\n"
	final_text = final_text.strip_edges()
	insert_text_at_cursor(final_text)
	
	# remove all the projections lines!
	# in a really moronic way
	section_find = search('[Project Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	select(start_of_section, 0, start_of_section + lines_in_projections_section - 1, 999)
	cut()
	cursor_set_line(start_of_section)
	cursor_set_column(0)
	final_text = ""
	for k in projections_list:
		final_text += k + "\n"
	final_text = final_text.strip_edges()
	insert_text_at_cursor(final_text)

	# remove all the paintballs lines!
	# in a really moronic way
	section_find = search('[Paint Ballz]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	select(start_of_section, 0, start_of_section + lines_in_paintball_section - 1, 999)
	cut()
	cursor_set_line(start_of_section)
	cursor_set_column(0)
	final_text = ""
	for k in paintballs_list:
		final_text += k + "\n"
	final_text = final_text.strip_edges()
	insert_text_at_cursor(final_text)
	
	ball_map = {}
	
	save_file()

func _mirror_l_to_r_ball(target_ball_no: int):
	save_backup()
	
	if target_ball_no >= KeyBallsData.max_base_ball_num:
		print("[LNZ EDIT] Copy L to R is only supported for base balls (0-%d)." % (KeyBallsData.max_base_ball_num - 1))
		return
		
	var mirrored_ball_no = _find_mirrored_ball(target_ball_no)
	
	var is_mirrored = mirrored_ball_no != target_ball_no
	if !is_mirrored:
		print("[LNZ EDIT] Ball #%d is a middle ball or non-symmetrical. Skipping all but [Ballz Info] and [Paintballz] for L to R mirror." % target_ball_no)

	var mirrored_addball_lines = []
	var temp_addball_map = {}

	# [Ballz Info]
	var ballz_bounds = _get_section_bounds("[Ballz Info]")
	var line_index = find_line_in_ball_section(target_ball_no)
	if line_index != -1:
		var delim = _detect_delimiter(ballz_bounds["start"], ballz_bounds["end"])
		var line = get_line(line_index)
		var parts = _split_and_clean(line, delim)
		
		var new_parts = Array(parts)
		
		# Mirror outline type (0 <-> -2)
		if new_parts.size() > 4:
			if new_parts[4] == "0":
				new_parts[4] = "-2"
			elif new_parts[4] == "-2":
				new_parts[4] = "0"

		var new_line = _join_array(new_parts, delim)
		var mirrored_line_index = find_line_in_ball_section(mirrored_ball_no)
		if mirrored_line_index != -1:
			set_line(mirrored_line_index, new_line)

	# [Add Ball]
	if is_mirrored:
		var addball_bounds = _get_section_bounds("[Add Ball]")
		if !addball_bounds.empty():
			var addball_start = addball_bounds["start"]
			var addball_end = addball_bounds["end"]
			var delim = _detect_delimiter(addball_start, addball_end)
			var addball_count = 0
			var current_addball_no = KeyBallsData.max_base_ball_num
			
			var lines_in_addball_section = []
			for i in range(addball_start, addball_end):
				lines_in_addball_section.append({
					"line_num": i,
					"line": get_line(i)
				})
			
			var max_ball_no = KeyBallsData.max_base_ball_num + _count_section_entries("[Add Ball]")
			var new_addball_no = max_ball_no
			
			for entry in lines_in_addball_section:
				var line = entry.line.strip_edges()
				if line.empty() or line.begins_with(";"):
					continue
				
				var parts = _split_and_clean(line, delim)
				
				if parts.size() < 1:
					continue
				
				var base_ball = parts[0].to_int()
				
				if base_ball == target_ball_no:
					var new_parts = Array(parts)
					
					new_parts[0] = str(mirrored_ball_no)
					
					if new_parts.size() > 1:
						new_parts[1] = str(new_parts[1].to_float() * -1.0)
					
					if new_parts.size() > 9:
						if new_parts[9] == "0":
							new_parts[9] = "-2"
						elif new_parts[9] == "-2":
							new_parts[9] = "0"
							
					var new_line_text = _join_array(new_parts, delim)
					
					mirrored_addball_lines.append(new_line_text)
					
					var old_addball_index = current_addball_no
					temp_addball_map[old_addball_index] = new_addball_no
					new_addball_no += 1
					
				current_addball_no += 1
				
			if !mirrored_addball_lines.empty():
				var insert_line = _find_insertion_line(addball_start, addball_end)
				_insert_text_at_cursor_at_line(insert_line, _join_array(mirrored_addball_lines, "\n") + "\n")
		
	# Build list of all left-side balls associated with mirror operation
	var associated_left_balls = [target_ball_no]
	for old_addball_no in temp_addball_map.keys():
		associated_left_balls.append(old_addball_no)
	
	# [Paint Ballz]
	var paintball_bounds = _get_section_bounds("[Paint Ballz]")
	var new_paintball_lines = []
	if !paintball_bounds.empty():
		var p_start = paintball_bounds["start"]
		var p_end = paintball_bounds["end"]
		var delim = _detect_delimiter(p_start, p_end)
		
		for i in range(p_start, p_end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"):
				continue
			
			var parts = _split_and_clean(line, delim)
			if parts.size() < 6:
				continue
			
			var base_ball = parts[0].to_int()
			
			if base_ball == target_ball_no:
				var new_parts = Array(parts)
				
				new_parts[0] = str(mirrored_ball_no)
				
				new_parts[2] = str(new_parts[2].to_float() * -1.0)
				
				new_paintball_lines.append(_join_array(new_parts, delim))
		
		# Insert new mirrored paintball lines
		if !new_paintball_lines.empty():
			var insert_line = _find_insertion_line(p_start, p_end)
			_insert_text_at_cursor_at_line(insert_line, _join_array(new_paintball_lines, "\n") + "\n")

	# [Move]
	if is_mirrored:
		var move_bounds = _get_section_bounds("[Move]")
		var final_move_lines = {}
		var new_mirrored_line = ""
		var target_line_found = false
		var lines_to_remove = []

		if !move_bounds.empty():
			var m_start = move_bounds["start"]
			var m_end = move_bounds["end"]
			var delim = _detect_delimiter(m_start, m_end)
			
			for i in range(m_start, m_end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";"):
					final_move_lines[i] = line + "\n"
					continue
				
				var parts = _split_and_clean(line, delim)
				if parts.size() < 4:
					final_move_lines[i] = line + "\n"
					continue
				
				var move_ball = parts[0].to_int()
				
				if move_ball == target_ball_no:
					target_line_found = true
					final_move_lines[i] = line + "\n"

					var new_parts = Array(parts)
					var anchor_ball = -1
					var has_anchor = parts.size() > 4
					
					new_parts[0] = str(mirrored_ball_no)
					new_parts[1] = str(new_parts[1].to_float() * -1.0) 
					
					if has_anchor:
						anchor_ball = parts[4].to_int()
						new_parts[4] = str(_find_mirrored_ball(anchor_ball))
					
					new_mirrored_line = _join_array(new_parts, delim) + "\n"
					
					lines_to_remove.append(mirrored_ball_no)
				
				elif move_ball == mirrored_ball_no:
					lines_to_remove.append(move_ball)
					
				elif lines_to_remove.has(move_ball):
					pass
				
				else:
					final_move_lines[i] = line + "\n"

			if target_line_found:
				var removal_start_line = -1
				var removal_end_line = -1
				
				for i in range(m_start, m_end):
					var line = get_line(i).strip_edges()
					if line.empty() or line.begins_with(";"):
						continue
					
					var parts = _split_and_clean(line, delim)
					if parts.size() < 4:
						continue
					
					var move_ball = parts[0].to_int()
					
					if move_ball == mirrored_ball_no:
						if removal_start_line == -1:
							removal_start_line = i
						removal_end_line = i
				
				if removal_start_line != -1:
					select(removal_start_line, 0, removal_end_line + 1, 0)
					cut()
					m_end = search("[", 0, m_start, 0)[SEARCH_RESULT_LINE]
					if m_end == -1:
						m_end = get_line_count()
			
				if !new_mirrored_line.empty():
					var insert_line_index = find_line_in_move_section(target_ball_no)
					if insert_line_index != -1:
						_insert_text_at_cursor_at_line(insert_line_index + 1, new_mirrored_line)
					else:
						var insert_line = _find_insertion_line(m_start, m_end)
						_insert_text_at_cursor_at_line(insert_line, new_mirrored_line)

	# [Linez]
	if is_mirrored:
		var linez_bounds = _get_section_bounds("[Linez]")
		var final_linez_lines_data = {} # Key: "start,end" (sorted), Value: line_text (data only)

		if !linez_bounds.empty():
			var l_start = linez_bounds["start"]
			var l_end = linez_bounds["end"]
			var delim = _detect_delimiter(l_start, l_end)
			
			# --- Pass 1: Collect and Process ALL lines ---
			for i in range(l_start, l_end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["):
					continue
				
				var data_part = line.split(";", false)[0].strip_edges()
				var parts = _split_and_clean(data_part, delim)
				
				if parts.size() < 2:
					continue
				
				var start_ball = parts[0].to_int()
				var end_ball = parts[1].to_int()
				var line_key_asc = "%d,%d" % [min(start_ball, end_ball), max(start_ball, end_ball)]
				
				var line_text = _join_array(parts, delim)
				
				if final_linez_lines_data.has(line_key_asc):
					continue

				# Preserve original line
				final_linez_lines_data[line_key_asc] = line_text

				# If this line involves ANY associated left ball (base ball OR its addballs), create the mirrored line.
				if associated_left_balls.has(start_ball) or associated_left_balls.has(end_ball):

					var new_parts = Array(parts) 
					
					var current_start_ball = start_ball
					var mirrored_start_ball = start_ball
					
					if current_start_ball == target_ball_no:
						mirrored_start_ball = mirrored_ball_no # L base ball -> R base ball
					elif temp_addball_map.has(current_start_ball):
						mirrored_start_ball = temp_addball_map[current_start_ball] # map old L addball index to new R addball index
					elif current_start_ball < KeyBallsData.max_base_ball_num:
						mirrored_start_ball = _find_mirrored_ball(current_start_ball) # Other symmetrical base ball -> its mirror
					
					new_parts[0] = str(mirrored_start_ball)
					
					# --- Handle End Ball ---
					var current_end_ball = end_ball
					var mirrored_end_ball = end_ball
					
					if current_end_ball == target_ball_no:
						mirrored_end_ball = mirrored_ball_no # L base ball -> R base ball
					elif temp_addball_map.has(current_end_ball):
						mirrored_end_ball = temp_addball_map[current_end_ball] # map old L addball index to new R addball index
					elif current_end_ball < KeyBallsData.max_base_ball_num:
						mirrored_end_ball = _find_mirrored_ball(current_end_ball) # Other symmetrical base ball -> its mirror
						
					new_parts[1] = str(mirrored_end_ball)
					
					# Mirror the outline type (Field 8)
					if new_parts.size() > 8:
						if new_parts[8] == "0":
							new_parts[8] = "-2"
						elif new_parts[8] == "-2":
							new_parts[8] = "0"
					
					var mirrored_data_line = _join_array(new_parts, delim)
					
					# Create the key for the mirrored line (must be sorted)
					var m_start_ball = new_parts[0].to_int()
					var m_end_ball = new_parts[1].to_int()
					var mirrored_key_asc = "%d,%d" % [min(m_start_ball, m_end_ball), max(m_start_ball, m_end_ball)]

					# Add the mirrored line to the set if it doesn't exist
					if !final_linez_lines_data.has(mirrored_key_asc):
						final_linez_lines_data[mirrored_key_asc] = mirrored_data_line
			
			# --- Pass 2: Replace Section Content ---
			var lines_to_write = []
			
			# Preserve original lines order first (approximate)
			var seen_keys = []
			for i in range(l_start, l_end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["):
					continue
				
				var data_part = line.split(";", false)[0].strip_edges()
				var parts = _split_and_clean(data_part, delim)
				if parts.size() < 2: continue
				
				var start_ball = parts[0].to_int()
				var end_ball = parts[1].to_int()
				var line_key_asc = "%d,%d" % [min(start_ball, end_ball), max(start_ball, end_ball)]
				
				if !seen_keys.has(line_key_asc) and final_linez_lines_data.has(line_key_asc):
					lines_to_write.append(final_linez_lines_data[line_key_asc])
					seen_keys.append(line_key_asc)
			
			# Add any newly created mirrored lines that were not already in the original set
			for key in final_linez_lines_data.keys():
				if !seen_keys.has(key):
					lines_to_write.append(final_linez_lines_data[key])

			# Clear existing lines (and comments/blanks between start/end)
			if l_start < l_end:
				select(l_start, 0, l_end, 0)
				cut()

			var final_text = ""
			if lines_to_write.size() > 0:
				final_text = _join_array(lines_to_write, "\n") + "\n"
			
			_insert_text_at_cursor_at_line(l_start, final_text)
		
	print("[LNZ EDIT] Successfully performed selective L to R mirror for ball #%d." % target_ball_no)

	save_file()

func apply_preset_to_ball(ball_no, properties, do_save = true):
	if do_save:
		save_backup()
	var is_addball = ball_no > KeyBallsData.max_base_ball_num

	var section_tag = "[Ballz Info]"
	if is_addball:
		section_tag = "[Add Ball]"

	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return

	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]

	var line_index = -1
	if is_addball:
		line_index = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
	else:
		line_index = find_line_in_ball_section(ball_no)

	if line_index != -1:
		var delim = _detect_delimiter(start_line, end_line)
		var line = get_line(line_index)
		var parts = _split_and_clean(line)

		if is_addball:
			if properties.has("color_index"): parts[4] = str(properties.color_index)
			if properties.has("outline_color_index"): parts[5] = str(properties.outline_color_index)
			if properties.has("fuzz"): parts[7] = str(properties.fuzz)
			if properties.has("outline"): parts[9] = str(properties.outline)
			if properties.has("size"): parts[10] = str(properties.size)
			if properties.has("group"): parts[8] = str(properties.group)
			if properties.has("texture_id"): parts[13] = str(properties.texture_id)
		else:
			if properties.has("color_index"): parts[0] = str(properties.color_index)
			if properties.has("outline_color_index"): parts[1] = str(properties.outline_color_index)
			if properties.has("fuzz"): parts[3] = str(properties.fuzz)
			if properties.has("outline"): parts[4] = str(properties.outline)
			if properties.has("size"): parts[5] = str(properties.size)
			if properties.has("group"): parts[6] = str(properties.group)
			if properties.has("texture_id"): parts[7] = str(properties.texture_id)

		var new_line = ""
		for i in range(parts.size()):
			new_line += parts[i]
			if i < parts.size() - 1:
				new_line += delim

		set_line(line_index, new_line)
		if do_save:
			save_file()


#func _add_or_update_override(section_name, ball_no, values, value_indices):
#	var section_find = search(section_name, 0, 0, 0)
#	var start_line
#	var end_line
#
#	if section_find.empty():
#		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
#		var all_lines = get_text().split("\n")
#		all_lines.insert(first_section, section_name)
#		all_lines.insert(first_section + 1, "")
#		text = all_lines.join("\n")
#		_set_text_preserve(text)
#		section_find = search(section_name, 0, 0, 0)
#
#	start_line = section_find[SEARCH_RESULT_LINE] + 1
#	end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
#	if end_line == -1:
#		end_line = get_line_count()
#
#	var delim = _detect_delimiter(start_line, end_line)
#	var line_updated = false
#	for i in range(start_line, end_line):
#		var line = get_line(i).strip_edges()
#		if line.begins_with(str(ball_no) + delim):
#			var parts = _split_and_clean(line, delim)
#			var max_index = value_indices.max()
#			while parts.size() <= max_index:
#				parts.append("0")
#
#			var value_idx = 0
#			for target_idx in value_indices:
#				parts[target_idx] = str(values[value_idx])
#				value_idx += 1
#
#			set_line(i, parts.join(delim))
#			line_updated = true
#			break
#
#	if not line_updated:
#		var max_index = 0
#		if value_indices.size() > 0:
#			max_index = value_indices.max()
#
#		var new_parts = []
#		new_parts.resize(max_index + 1)
#		for i in range(new_parts.size()):
#			new_parts[i] = "0"
#		new_parts[0] = str(ball_no)
#
#		var value_idx = 0
#		for target_idx in value_indices:
#			if value_idx < values.size():
#				new_parts[target_idx] = str(values[value_idx])
#				value_idx += 1
#
#		var new_line = new_parts.join(delim)
#		var insert_line = _find_insertion_line(start_line, end_line)
#		_insert_text_at_cursor_at_line(insert_line, new_line + "\n")

func write_preset_to_ball(ball_no, properties, _write_target, should_override):
	var applied_something = false
	if properties.get("apply_ballz", true):
		apply_preset_to_ball(ball_no, properties, false)
		applied_something = true

	if properties.get("apply_paintballz", true) and properties.has("paintballz"):
		var paintballz = properties.paintballz
		if paintballz.size() > 0:
			applied_something = true
			var bounds = _get_section_bounds("[Paint Ballz]")
			var insert_line_num

			if bounds.empty():
				var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
				var all_lines = get_text().split("\n")
				all_lines.insert(first_section, "[Paint Ballz]")
				all_lines.insert(first_section + 1, "")
				text = all_lines.join("\n")
				_set_text_preserve(text)
				bounds = _get_section_bounds("[Paint Ballz]")

			insert_line_num = bounds["start"]
			var j = 0
			while insert_line_num + j < bounds["end"]:
				var line = get_line(insert_line_num + j).strip_edges()
				if line.begins_with(";"):
					j += 1
					continue
				break
			insert_line_num += j

			var delim = _detect_delimiter(bounds["start"], bounds["end"])
			var new_paintball_lines = ""
			for paintball_info in paintballz:
				var pos = paintball_info.position
				var paintball_line = str(ball_no) + delim
				paintball_line += str(paintball_info.size) + delim
				paintball_line += str(pos.x) + delim
				paintball_line += str(pos.y) + delim
				paintball_line += str(pos.z) + delim
				paintball_line += str(paintball_info.color_index) + delim
				paintball_line += str(paintball_info.outline_color_index) + delim
				paintball_line += str(paintball_info.fuzz) + delim
				paintball_line += str(paintball_info.outline) + delim
				paintball_line += "0" + delim # group, not in use for paintballz
				paintball_line += str(paintball_info.texture_id) + delim
				paintball_line += str(paintball_info.anchored)

				new_paintball_lines += paintball_line + "\n"

			_insert_text_at_cursor_at_line(insert_line_num, new_paintball_lines)

	if applied_something:
		save_file()


func _on_LnzTextEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_Q:
		var nearest_section_start = search("[", SEARCH_BACKWARDS, cursor_get_line(), 0)
		
		if nearest_section_start.empty():
			emit_signal("find_ball", int(get_word_under_cursor()))
			return
		
		var nearest_section_line = nearest_section_start[SEARCH_RESULT_LINE]
		var nearest_section = get_line(nearest_section_line)
		
		var ball_no = -1
		
		if nearest_section == "[Ballz Info]":
			ball_no = _get_ball_no_from_line_index(cursor_get_line(), "[Ballz Info]")
		elif nearest_section == "[Add Ball]":
			ball_no = _get_ball_no_from_line_index(cursor_get_line(), "[Add Ball]")
		else:
			var word = get_word_under_cursor()
			if word.is_valid_integer():
				ball_no = int(word)

		if ball_no != -1:
			emit_signal("find_ball", ball_no)

func _get_ball_no_from_line_index(target_line_index: int, section_tag: String) -> int:
	var section_find = search(section_tag, 0, 0, 0)
	if section_find.empty():
		return -1
	
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	if end_line == -1:
		end_line = get_line_count()

	var ball_counter = -1
	for i in range(start_line, end_line):
		var line = get_line(i).lstrip(" ")
		if line.begins_with(";") or line.empty() or line.begins_with("["):
			continue
		
		ball_counter += 1
		
		if i == target_line_index:
			if section_tag == "[Add Ball]":
				# Offset addball numbers by max_base_ball_num
				return ball_counter + KeyBallsData.max_base_ball_num
			else:
				return ball_counter
				
	return -1

func _on_ToolsMenu_recolor(all_recolor_info: Dictionary):
	save_backup()
	
	var recolor_rules = all_recolor_info.recolors
	
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.nose_cat)
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
	elif species == KeyBallsData.Species.DOG:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.nose_dog)
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_bab)

	if all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var section_find = search('[Ballz Info]', 0, 0, 0)
		if section_find:
			var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break
				
				var line = get_line(current_line_num)
				if line.begins_with("["): break

				if i in balls_to_exclude or line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue

				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 8:
					i += 1
					continue
				
				var color = parsed_line[0]
				var outline_color = parsed_line[1]
				var texture = parsed_line[7]
				var updates = {}

				for rule in recolor_rules:
					var color_match = rule.before_color.empty() or rule.before_color == color
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					
					if all_recolor_info.balls_on and color_match and texture_match:
						if not rule.after_color.empty():
							updates[0] = rule.after_color
						if not rule.after_texture.empty():
							updates[7] = rule.after_texture
						break

				for rule in recolor_rules:
					var outline_color_match = rule.before_color.empty() or rule.before_color == outline_color
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if all_recolor_info.ball_outlines_on and outline_color_match and texture_match:
						if not rule.after_color.empty():
							updates[1] = rule.after_color
						break
				
				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)
				
				i += 1

	if all_recolor_info.paintballs_on or all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var addball_find = search('[Add Ball]', 0, 0, 0)
		var paintball_find = search('[Paint Ballz]', 0, 0, 0)

		if addball_find and (all_recolor_info.balls_on or all_recolor_info.ball_outlines_on):
			var start_of_section = addball_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break
				
				var line = get_line(current_line_num)
				if line.begins_with("["): break
				
				if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue

				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 14 or int(parsed_line[0]) in balls_to_exclude:
					i += 1
					continue
				
				var color = parsed_line[4]
				var outline_color = parsed_line[5]
				var texture = parsed_line[13]
				var updates = {}

				for rule in recolor_rules:
					var color_match = rule.before_color.empty() or rule.before_color == color
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture

					if all_recolor_info.balls_on and color_match and texture_match:
						if not rule.after_color.empty():
							updates[4] = rule.after_color
						if not rule.after_texture.empty():
							updates[13] = rule.after_texture
						break
				
				for rule in recolor_rules:
					var outline_color_match = rule.before_color.empty() or rule.before_color == outline_color
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if all_recolor_info.ball_outlines_on and outline_color_match and texture_match:
						if not rule.after_color.empty():
							updates[5] = rule.after_color
						break

				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)
				
				i += 1

		if paintball_find and all_recolor_info.paintballs_on:
			var start_of_section = paintball_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break

				var line = get_line(current_line_num)
				if line.begins_with("["): break

				if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue
				
				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 11 or int(parsed_line[0]) in balls_to_exclude:
					i += 1
					continue

				var color = parsed_line[5]
				var texture = parsed_line[10]
				var updates = {}
				
				for rule in recolor_rules:
					var color_match = rule.before_color.empty() or rule.before_color == color
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture

					if color_match and texture_match:
						if not rule.after_color.empty():
							updates[5] = rule.after_color
						if not rule.after_texture.empty():
							updates[10] = rule.after_texture
						break

				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)

				i += 1

	if all_recolor_info.lines_on:
		var section_find = search('[Linez]', 0, 0, 0)
		if section_find:
			var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break
				
				var line = get_line(current_line_num)
				if line.begins_with("["): break
				
				if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue

				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 6:
					i += 1
					continue
				
				var mainColor = parsed_line[3]
				var lColor = parsed_line[4]
				var rColor = parsed_line[5]
				var updates = {}
				
				for rule in recolor_rules:
					# Lines don't have textures, so skip rules that specify one
					if not rule.before_texture.empty():
						continue
					if rule.before_color.empty() or rule.before_color == mainColor:
						if not rule.after_color.empty():
							updates[3] = rule.after_color
						break
				for rule in recolor_rules:
					if not rule.before_texture.empty():
						continue
					if rule.before_color.empty() or rule.before_color == lColor:
						if not rule.after_color.empty():
							updates[4] = rule.after_color
						break
				for rule in recolor_rules:
					if not rule.before_texture.empty():
						continue
					if rule.before_color.empty() or rule.before_color == rColor:
						if not rule.after_color.empty():
							updates[5] = rule.after_color
						break
				
				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)

				i += 1

	var section_find = search('[256 Eyelid Color]', 0, 0, 0)
	if section_find:
		var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
		var i = 0
		while true:
			var current_line_num = start_of_section + i
			if current_line_num >= get_line_count(): break
			
			var line = get_line(current_line_num)
			if line.begins_with("["): break
			
			if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
				i += 1
				continue

			var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
			var parsed_line = _split_and_clean(line, delimiter)
			
			if parsed_line.size() < 2:
				i += 1
				continue
			
			var l_color = parsed_line[0]
			var r_color = parsed_line[1]
			var updates = {}
			
			for rule in recolor_rules:
				if not rule.before_texture.empty():
					continue
				if rule.before_color.empty() or rule.before_color == l_color:
					if not rule.after_color.empty():
						updates[0] = rule.after_color
					break
			for rule in recolor_rules:
				if not rule.before_texture.empty():
					continue
				if rule.before_color.empty() or rule.before_color == r_color:
					if not rule.after_color.empty():
						updates[1] = rule.after_color
					break
			
			if not updates.empty():
				var final_line = _update_fields(parsed_line, updates, delimiter)
				set_line(current_line_num, final_line)

			i += 1
				
	save_file()

func _on_ToolsMenu_move_head(x, y, z):
	save_backup()
	var head_balls: Array
	if KeyBallsData.species == KeyBallsData.Species.CAT:
		head_balls = KeyBallsData.head_ext_cat.duplicate()
	else:
		head_balls = KeyBallsData.head_ext_dog.duplicate()
	var section_find = search('[Move]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";") or line.empty():
			i += 1
			continue
		elif line.begins_with("["):
			break
			
		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if !(parsed_line[0].to_int() in head_balls):
			i += 1
			continue
		head_balls.erase(parsed_line[0].to_int())
		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 1:
				final_line += str(item.to_int() + x) + " "
			elif n == 2:
				final_line += str(item.to_int() + y) + " "
			elif n == 3:
				final_line += str(item.to_int() + z) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	
	# now insert any we missed
	for b in head_balls:
		cursor_set_line(start_of_section + i)
		cursor_set_column(0)
		insert_text_at_cursor(str(b) + " " + str(x) + " " + str(y) + " " + str(z) + "\n")
	
	save_file()

func get_project_ball_section() -> Array:
	var projections = []
	var bounds = _get_section_bounds("[Project Ball]")
	if bounds.empty():
		return projections

	var start_line = bounds["start"]
	var end_line = bounds["end"]

	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue

		var comment = ""
		if line.find(";") != -1:
			comment = line.substr(line.find(";") + 1).strip_edges()
			line = line.substr(0, line.find(";")).strip_edges()

		var parts = _split_and_clean(line)
		if parts.empty():
			continue

		if parts.size() >= 3:
			if parts.size() == 3:
				var amount = int(parts[2])
				projections.append({
					"fixed_ball": int(parts[0]),
					"project_ball": int(parts[1]),
					"min_projection": amount - 50,
					"max_projection": amount + 50,
					"comment": comment
				})
			elif parts.size() >= 4:
				projections.append({
					"fixed_ball": int(parts[0]),
					"project_ball": int(parts[1]),
					"min_projection": int(parts[2]),
					"max_projection": int(parts[3]),
					"comment": comment
				})
	return projections

func write_project_ball_section(projections: Array):
	save_backup()
	var bounds = _get_section_bounds("[Project Ball]")
	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Project Ball]")
		all_lines.insert(first_section + 1, "")
		text = all_lines.join("\n")
		_set_text_preserve(text)
		bounds = _get_section_bounds("[Project Ball]")

	var start_line = bounds["start"]
	var end_line = bounds["end"]

	var existing_lines = []
	if start_line < end_line:
		for i in range(start_line, end_line):
			existing_lines.append(get_line(i))

	var output_lines = existing_lines.duplicate()
	var new_lines_to_prepend = []
	var processed_indices = []

	for proj in projections:
		var found_match = false
		for i in range(existing_lines.size()):
			var line = existing_lines[i]
			var line_strip = line.strip_edges()
			if line_strip.empty() or line_strip.begins_with(";"):
				continue

			var line_parts = line_strip.split(";")
			var data_part = line_parts[0].strip_edges()
			var parts = _split_and_clean(data_part)

			# var parts = []
			# var delim = " " # Default to space
			
			# if data_part.find(",") != -1:
			# 	parts = data_part.split(",", false)
			# 	delim = ","
			# elif data_part.find("\t") != -1:
			# 	parts = data_part.split("\t", false)
			# 	delim = "\t"
			# else:
			# 	parts = data_part.split(" ", false)
			# 	delim = " "

			# for j in range(parts.size()):
			# 	parts[j] = parts[j].strip_edges()

			if parts.size() >= 2 and parts[0] == str(proj.fixed_ball) and parts[1] == str(proj.project_ball):
				var line_text = str(proj.fixed_ball) + " " + str(proj.project_ball) + " " + str(proj.value)
				if proj.has("comment") and not proj.comment.empty():
					line_text += " ;" + proj.comment
				output_lines[i] = line_text
				processed_indices.append(i)
				found_match = true
				break

		if not found_match:
			var line_text = str(proj.fixed_ball) + " " + str(proj.project_ball) + " " + str(proj.value)
			if proj.has("comment") and not proj.comment.empty():
				line_text += " ;" + proj.comment
			new_lines_to_prepend.append(line_text)

	# Clear existing lines
	if start_line < end_line:
		select(start_line, 0, end_line, 0)
		cut()

	var final_text = ""
	for line in new_lines_to_prepend:
		final_text += line + "\n"
	for line in output_lines:
		final_text += line + "\n"

	_insert_text_at_cursor_at_line(start_line, final_text)
	save_file()

func update_lnz_section_one_value(section_name, val1):
	var bounds = _get_section_bounds(section_name)
	if bounds.empty():
		print("Section not found: " + section_name)
		return

	var start_line = bounds["start"]
	set_line(start_line, str(val1))

func update_lnz_section_two_values(section_name, val1, val2):
	var bounds = _get_section_bounds(section_name)
	if bounds.empty():
		print("Section not found: " + section_name)
		return

	var start_line = bounds["start"]
	var delim = _detect_delimiter(start_line, bounds.end)
	var new_line = str(val1) + delim + str(val2)
	set_line(start_line, new_line)

func _on_Node_ball_resized(ball_no: int, size_dif: int):
	var max_base_ball_no = KeyBallsData.max_base_ball_num
	var is_addball = ball_no > max_base_ball_no

	var section_tag = "[Ballz Info]"
	var size_field_index = 5  # 6th field is size
	if is_addball:
		section_tag = "[Add Ball]"
		size_field_index = 10  # 11th field is size for addballs

	print("[LNZ EDIT] Resizing ball %d from section %s with size_dif = %d" % [ball_no, section_tag, size_dif])

	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return

	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]

	if end_line == -1:
		end_line = get_line_count()

	if is_addball:
		var addball_index = ball_no - max_base_ball_no
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			if count == addball_index:
				var parts = _split_and_clean(raw)
				if parts.size() > size_field_index:
					var old_size = parts[size_field_index].to_int()
					var new_size = size_dif
					print("[LNZ EDIT] [Add Ball] Resizing ball %d at line %d" % [ball_no, i])
					print("[LNZ EDIT] Old size = %d → New size = %d" % [old_size, new_size])
					parts[size_field_index] = str(new_size)
					var new_line = _join_array(parts, " ")
					set_line(i, new_line)
					print("[LNZ EDIT] Updated line: %s" % new_line)
					save_file()
					return
			count += 1
		print("[LNZ EDIT] No matching [Add Ball] line found for ball %d" % ball_no)
	else:
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			#print("[LNZ EDIT] Scanning line %d (count = %d): %s" % [i, count, raw])
			#print("[LNZ EDIT] Count reached = %d, looking for ball_no = %d" % [count, ball_no])
			if count == ball_no:
				var parts = _split_and_clean(raw)
				if parts.size() > size_field_index:
					var old_size = parts[size_field_index].to_int()
					var new_size = size_dif
					print("[LNZ EDIT] [Ballz Info] Resizing ball %d at line %d" % [ball_no, i])
					print("[LNZ EDIT] Old size = %d → New size = %d" % [old_size, new_size])
					parts[size_field_index] = str(new_size)
					var new_line = _join_array(parts, " ")
					set_line(i, new_line)
					print("[LNZ EDIT] Updated line: %s" % new_line)
					save_file()
					return
				else:
					print("[LNZ EDIT] Line has too few fields for resizing ball %d" % ball_no)
					return
			count += 1
		print("[LNZ EDIT] Ball %d not found in [Ballz Info]" % ball_no)

func _on_Node_ball_translation_changed(ball_no: int, new_pos: Vector3):
	save_backup()
	var is_addball = ball_no > KeyBallsData.max_base_ball_num

	var section_tag = "[Move]"
	if is_addball:
		section_tag = "[Add Ball]"
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return
	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	if end_line == -1:
		end_line = get_line_count()

	if is_addball:
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		var moved_ball_node = pet_node.ball_map.get(ball_no)
		if moved_ball_node:
			var base_ball_no = moved_ball_node.base_ball_no
			var base_ball_node = pet_node.ball_map.get(base_ball_no)
			if base_ball_node:
				var new_relative_pos = moved_ball_node.global_transform.origin - base_ball_node.global_transform.origin
				new_relative_pos /= (pet_node.pixel_world_size * (pet_node.lnz.scales.x / 255.0))
				new_relative_pos.y *= -1.0

				var idx = ball_no - KeyBallsData.max_base_ball_num
				var count = 0
				for i in range(start_line, end_line):
					var raw = get_line(i).strip_edges()
					if raw == "" or raw.begins_with(";"):
						continue
					if count == idx:
						var parts = _split_and_clean(raw)
						if parts.size() >= 4:
							parts[1] = str(round(new_relative_pos.x))
							parts[2] = str(round(new_relative_pos.y))
							parts[3] = str(round(new_relative_pos.z))
							var new_line = _join_array(parts, " ")
							set_line(i, new_line)
						break
					count += 1
	else:
		var updated = false
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			var parts = _split_and_clean(raw)
			if parts.size() >= 4 and parts[0].to_int() == ball_no:
				parts[1] = str(parts[1].to_int() + new_pos.x)
				parts[2] = str(parts[2].to_int() + new_pos.y)
				parts[3] = str(parts[3].to_int() + new_pos.z)
				var new_line = _join_array(parts, " ")
				set_line(i, new_line)
				print("[LNZ EDIT] Summed [Move] line at %d: %s" % [i, new_line])
				updated = true
				break
		if not updated:
			var sep = " "
			var line_txt = "%d%s%d%s%d%s%d" % [
				ball_no, sep,
				new_pos.x, sep,
				new_pos.y, sep,
				new_pos.z
			]
			var insert_at = end_line
			while insert_at > start_line and get_line(insert_at - 1).strip_edges() == "":
				insert_at -= 1
			_insert_text_at_cursor_at_line(insert_at, line_txt + "\n")
			print("[LNZ EDIT] Inserting new [Move] line at %d: %s" % [insert_at, line_txt])
	save_file()
