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

onready var apply_changes_button = get_node("../../PetViewContainer/VBoxContainer/HelperContainer/VBoxContainer/ApplyChangesButton")

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

func save_backup():
	if not is_user_file:
		return
	var file = File.new()
	var backup_path = filepath.replace(".lnz", "_backup.lnz")
	file.open(backup_path, File.WRITE)
	file.store_string(text)
	file.close()
	emit_signal("file_backed_up")

func save_file():
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

func _get_section_bounds(section_tag: String) -> Dictionary:
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		return {}
	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	return {"start": start_line, "end": end_line}

func _detect_delimiter(start_line: int, end_line: int) -> String:
	for i in range(end_line - 1, start_line - 1, -1):
		var line = get_line(i).strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.find("\t") != -1:
			return "\t"
		elif line.find(", ") != -1:
			return ", "
		elif line.find(",") != -1:
			return ","
		else:
			return " "
	return " "

func _split_and_clean(line: String, delim: String) -> Array:
	var parts = line.split(delim, false)
	for i in range(parts.size()):
		parts[i] = parts[i].strip_edges()
	return parts

func _update_fields(parts: Array, updates: Dictionary, sep: String) -> String:
	var new_parts = []
	for i in range(parts.size()):
		if updates.has(i):
			new_parts.append(updates[i])
		else:
			new_parts.append(parts[i])
	return new_parts.join(sep)

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
	insert_text_at_cursor(text)

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
	if left_ball_index < 67:
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
	if right_ball_index < 67:
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
	save_file()
	emit_signal("file_saved", filepath)

func _on_Tree_backup_file():
	save_backup()

func _wrap_angle_deg(a: int) -> int:
	var ang = ((a % 360) + 360) % 360
	if ang > 180:
		ang -= 360
	return ang

func _on_HeadShotButton_pressed():
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
	var bounds = _get_section_bounds("[Linez]")
	var start_line = bounds["start"]
	var end_line = bounds["end"]

	if start_line == -1:
		print("[LNZ EDIT] No [Linez] section found")
		return

	var delim = _detect_delimiter(start_line, end_line)
	var sep = delim

	var insert_line = end_line
	while insert_line > start_line and get_line(insert_line - 1).strip_edges() == "":
		insert_line -= 1

	var new_line = "%s%s%s%s0%s-1%s-1%s-1%s95%s95%s-1%s0\n" % [
		str(start_ball), sep,
		str(end_ball), sep,
		sep, sep, sep, sep, sep, sep, sep
	]

	_insert_text_at_cursor_at_line(insert_line, new_line)
	cursor_set_line(insert_line)
	cursor_set_column(0)
	center_viewport_to_cursor()
	save_file()

# Create Addballz (+ Linez)
func _on_ToolsMenu_add_ball(reference_ball, also_connect_line := false):
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	if reference_ball == null:
		print("[LNZ EDIT] No reference ball given")
		return

	var ball_no = reference_ball.ball_no
	var lnz = pet_node.lnz

	var lnz_size := 20  # fallback

	if reference_ball != null:
		var ref_no = reference_ball.ball_no
		var is_addball_ref = ref_no >= 67 or reference_ball.is_in_group("addballs")

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

	var addball_no = 67 + _count_section_entries("[Add Ball]") - 1

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
	var i = 0
	while true:
		var line = get_line(start_line + i).strip_edges()
		if line.begins_with("[") or line == "":
			break
		i += 1
	return i

func _find_insertion_line(start_line: int, end_line: int) -> int:
	var i = end_line
	while i > start_line and get_line(i - 1).strip_edges() == "":
		i -= 1
	return i

# Deletes an addball and references, or marks a base ball for omission
func _on_ToolsMenu_delete_ball(ball_no: int):
	var is_addball = ball_no > KeyBallsData.max_base_ball_num
	if is_addball:
		var line_no = find_line_in_addball_section(ball_no - 67)
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

#####

# v1 Delete Addballz
# func _on_Node_addball_deleted(ball_no):
# 	# remove the addball line
# 	var line_no = find_line_in_addball_section(ball_no - 67)
# 	select(line_no, 0, line_no + 1, 0)
# 	cut()
	
# 	# all the addballs after this have now been renumbered
# 	# so we need to correct the linez, omissions, projections, paintballz
# 	# linez
# 	var section_find = search('[Linez]', 0, 0, 0)
# 	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
# 	var i = 0
# 	while true:
# 		var line = get_line(start_of_section + i).lstrip(" ")
# 		# ignore comments for now
# 		if line.begins_with("[") or line.empty():
# 			break
		
# 		# var parsed_line = r.search_all(line)
# 		var delimiters = [", ", ",", "\t", " "]
# 		var parsed_line = []
# 		for delim in delimiters:
# 			if line.split(delim).size() > 2:
# 				parsed_line = line.split(delim, false)
# 				break

# 		var start_ball = int(parsed_line[0])
# 		var end_ball = int(parsed_line[1])
# 		if start_ball == ball_no or end_ball == ball_no:
# 			select(start_of_section + i, 0, start_of_section + i + 1, 0)
# 			cut()
# 			continue
# 		if start_ball > ball_no or end_ball > ball_no:
# 			var replaced_line = ""
# 			if start_ball > ball_no:
# 				start_ball -= 1
# 			if end_ball > ball_no:
# 				end_ball -= 1
# 			replaced_line += str(start_ball) + " " + str(end_ball) + " "
# 			var start_of_rest = parsed_line[2].get_start()
# 			replaced_line += line.substr(start_of_rest)
# 			set_line(start_of_section + i, replaced_line)
# 		i += 1
	
# 	# omissions
# 	section_find = search('[Omissions]', 0, 0, 0)
# 	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
# 	i = 0
# 	while true:
# 		var line = get_line(start_of_section + i).lstrip(" ")
# 		# ignore comments for now
# 		if line.begins_with("[") or line.empty():
# 			break
# 		if int(line) == ball_no:
# 			select(start_of_section + i, 0, start_of_section + i + 1, 0)
# 			cut()
# 			continue
# 		elif int(line) > ball_no:
# 			var replace_line = str(int(line) - 1)
# 			set_line(start_of_section + i, replace_line)
# 		i += 1
	
# 	# projections
# 	section_find = search('[Project Ball]', 0, 0, 0)
# 	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
# 	i = 0
# 	while true:
# 		var line = get_line(start_of_section + i).lstrip(" ")
# 		# ignore comments for now
# 		if line.begins_with("[") or line.empty():
# 			break
		
# 		# var parsed_line = r.search_all(line)
# 		var delimiters = [", ", ",", "\t", " "]
# 		var parsed_line = []
# 		for delim in delimiters:
# 			if line.split(delim).size() > 2:
# 				parsed_line = line.split(delim, false)
# 				break

# 		var move_ball_no = int(parsed_line[1])
# 		if move_ball_no == ball_no:
# 			select(start_of_section + i, 0, start_of_section + i + 1, 0)
# 			cut()
# 			continue
# 		elif move_ball_no > ball_no:
# 			var replace_line = "%s %s %s" % [parsed_line[0], str(move_ball_no - 1), line.substr(parsed_line[2].get_start())]
# 			set_line(start_of_section + i, replace_line)
# 		i += 1
		
# 	# paintballz
# 	section_find = search('[Paint Ballz]', 0, 0, 0)
# 	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
# 	i = 0
# 	while true:
# 		var line = get_line(start_of_section + i).lstrip(" ")
# 		# ignore comments for now
# 		if line.begins_with("[") or line.empty():
# 			break
		
# 		var split = line.split(" ", false, 1)
# 		var base_ball_no = int(split[0])
# 		if base_ball_no == ball_no:
# 			select(start_of_section + i, 0, start_of_section + i + 1, 0)
# 			cut()
# 			continue
# 		elif base_ball_no > ball_no:
# 			var replace_line = "%s %s" % [str(base_ball_no), split[1]]
# 			set_line(start_of_section + i, replace_line)
# 		i += 1
		
# 	save_file()

func _on_Node_ball_selected(section, ball_no, is_addball, max_addball_no):
	# need to find line number for the ball
	var actual_start_point
	if section == Section.Section.BALL:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - max_addball_no)
		else:
			actual_start_point = find_line_in_ball_section(ball_no)
	elif section == Section.Section.MOVE:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - max_addball_no)
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
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.nose_cat)
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.nose_dog)
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
		
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
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
		if intended_part != "NOSE":
			balls_to_exclude.append_array(KeyBallsData.nose_cat)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
		if intended_part != "NOSE":
			balls_to_exclude.append_array(KeyBallsData.nose_dog)
		
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

func _on_ToolsMenu_copy_l_to_r():
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
	var ball_no = 67
	var balls_to_add_temp = []
	var new_ball_count = 67
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
			for item in parsed_line:
				if p == 0:
					final_line += str(get_corresponding_right_ball(move_ball_no)) + " "
				elif p == 1:
					final_line += str(int(item) * -1.0) + " "
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
					final_line += str(float(item) * -1.0) +  " "
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

func _on_LnzTextEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_Q:
		#if in the balls or addballs section, use line number
		var nearest_section_start = search("[", SEARCH_BACKWARDS, cursor_get_line(), 0)
		var nearest_section = get_line(nearest_section_start[SEARCH_RESULT_LINE])
		if nearest_section == "[Ballz Info]":
			var line_number = cursor_get_line() - nearest_section_start[SEARCH_RESULT_LINE] - 1
			emit_signal("find_ball", line_number)
		elif nearest_section == "[Add Ball]":
			var line_number = cursor_get_line() - nearest_section_start[SEARCH_RESULT_LINE] + 66
			emit_signal("find_ball", line_number)
		else:
			emit_signal("find_ball", int(get_word_under_cursor()))

func _on_ToolsMenu_recolor(all_recolor_info: Dictionary):
	save_backup()
	
	var recolor_info = all_recolor_info.recolors
	
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.nose_cat)
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.nose_dog)
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
	
	if all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var section_find = search('[Ballz Info]', 0, 0, 0)
		var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
		var i = 0
		while true:
			if i in balls_to_exclude:
				i += 1
				continue
			var line = get_line(start_of_section + i).lstrip(" ")
			if line.begins_with("[") or i > get_line_count():
				break
			if line.begins_with(";") or line.empty():
				i += 1
				continue
			# here the first number is color and second is outline col
			
			# var parsed_line = r.search_all(line)
			var delimiters = [", ", ",", "\t", " "]
			var parsed_line = []
			for delim in delimiters:
				if line.split(delim).size() > 2:
					parsed_line = line.split(delim, false)
					break

			var color = parsed_line[0]
			var outline_color = parsed_line[1]
			if (recolor_info.has(color) and all_recolor_info.balls_on) or (recolor_info.has(outline_color) and all_recolor_info.ball_outlines_on):
				var n = 0
				var final_line = ""
				for r_item in parsed_line:
					var item = r_item
					if n == 0 and recolor_info.has(item) and all_recolor_info.balls_on:
						final_line += recolor_info[color] + " "
					elif n == 1 and recolor_info.has(item) and all_recolor_info.ball_outlines_on:
						final_line += recolor_info[outline_color] + " "
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
			if line.begins_with("[") or i > get_line_count():
				break
			if line.begins_with(";") or line.empty():
				i += 1
				continue
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
			var color = parsed_line[4]
			var outline_color = parsed_line[5]
			if (recolor_info.has(color) and all_recolor_info.balls_on) or (recolor_info.has(outline_color) and all_recolor_info.ball_outlines_on):
				var n = 0
				var final_line = ""
				for r_item in parsed_line:
					var item = r_item
					if n == 4 and recolor_info.has(item) and all_recolor_info.balls_on:
						final_line += recolor_info[color] + " "
					elif n == 5 and recolor_info.has(item) and all_recolor_info.ball_outlines_on:
						final_line += recolor_info[outline_color] + " "
					else:
						final_line += item + " "
					n += 1
				set_line(start_of_section + i, final_line)
			i += 1
			
	if all_recolor_info.paintballs_on:
		var section_find = search('[Paint Ballz]', 0, 0, 0)
		var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
		var i = 0
		while true:
			if i + KeyBallsData.max_base_ball_num in balls_to_exclude:
				i += 1
				continue
			var line = get_line(start_of_section + i).lstrip(" ")
			if line.begins_with("[") or i > get_line_count():
				break
			if line.begins_with(";") or line.empty():
				i += 1
				continue
			# here the sixth number is color

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
			var color = parsed_line[5]
			if recolor_info.has(color):
				var n = 0
				var final_line = ""
				for r_item in parsed_line:
					var item = r_item
					if n == 5:
						final_line += recolor_info[color] + " "
					else:
						final_line += item + " "
					n += 1
				set_line(start_of_section + i, final_line)
			i += 1
		
	if all_recolor_info.lines_on:
		var section_find = search('[Linez]', 0, 0, 0)
		var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
		var i = 0
		while true:
			var line = get_line(start_of_section + i).lstrip(" ")
			# ignore comments for now
			if line.begins_with("[") or line.empty() or i > get_line_count():
				break

			# var parsed_line = r.search_all(line)
			var delimiters = [", ", ",", "\t", " "]
			var parsed_line = []
			for delim in delimiters:
				if line.split(delim).size() > 2:
					parsed_line = line.split(delim, false)
					break

			var mainColor = parsed_line[3]
			var lColor = parsed_line[4]
			var rColor = parsed_line[5]
			if recolor_info.has(mainColor) or recolor_info.has(lColor) or recolor_info.has(rColor):
				var n = 0
				var final_line = ""
				for item in parsed_line:
					if n == 3 and recolor_info.has(mainColor):
						final_line += recolor_info[mainColor] + " "
					elif n == 4 and recolor_info.has(lColor):
						final_line += recolor_info[lColor] + " "
					elif n == 5 and recolor_info.has(rColor):
						final_line += recolor_info[rColor] + " "
					else:
						final_line += item + " "
					n += 1
				set_line(start_of_section + i, final_line)
			i += 1
	save_file()

func _on_ToolsMenu_move_head(x, y, z):
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

func _on_Node_ball_translation_changed(ball_no: int, new_pos: Vector3):
	save_backup()
	var max_base_ball_no = KeyBallsData.max_base_ball_num
	var is_addball = ball_no > max_base_ball_no

	var section_tag = "[Move]"
	if is_addball:
		section_tag = "[Add Ball]"
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return
	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]

	var delim = " "
	for i in range(end_line - 1, start_line - 1, -1):
		var line = get_line(i).strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.find("\t") != -1:
			delim = "\t"
		elif line.find(", ") != -1:
			delim = ", "
		elif line.find(",") != -1:
			delim = ","
		else:
			delim = " "
		break

	var sep = delim


	if is_addball:
		var idx = ball_no - max_base_ball_no
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			if count == idx:
				var parts = raw.split(delim, false)
				for j in range(parts.size()):
					parts[j] = parts[j].strip_edges()
				if parts.size() >= 4:
					parts[1] = str(parts[1].to_int() + new_pos.x)
					parts[2] = str(parts[2].to_int() + new_pos.y)
					parts[3] = str(parts[3].to_int() + new_pos.z)
					var new_line = parts.join(sep)
					set_line(i, new_line)
					print("[LNZ EDIT] Updating [Add Ball] line %d: %s" % [i, new_line])
				break
			count += 1
	else:
		var updated = false
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			var parts = raw.split(delim, false)
			for j in range(parts.size()):
				parts[j] = parts[j].strip_edges()
			if parts.size() >= 4 and parts[0].to_int() == ball_no:
				parts[1] = str(parts[1].to_int() + new_pos.x)
				parts[2] = str(parts[2].to_int() + new_pos.y)
				parts[3] = str(parts[3].to_int() + new_pos.z)
				var new_line = parts.join(sep)
				set_line(i, new_line)
				print("[LNZ EDIT] Summed [Move] line at %d: %s" % [i, new_line])
				updated = true
				break
		if not updated:
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

func _on_Node_ball_resized(ball_no: int, size_dif: int):
	save_backup()
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

	var delim = " "
	for i in range(end_line - 1, start_line - 1, -1):
		var line = get_line(i).strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.find("\t") != -1:
			delim = "\t"
		elif line.find(", ") != -1:
			delim = ", "
		elif line.find(",") != -1:
			delim = ","
		else:
			delim = " "
		break

	var sep = delim

	if is_addball:
		var addball_index = ball_no - max_base_ball_no
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			if count == addball_index:
				var parts = raw.split(delim, false)
				for j in range(parts.size()):
					parts[j] = parts[j].strip_edges()
				if parts.size() > size_field_index:
					var old_size = parts[size_field_index].to_int()
					var new_size = size_dif
					print("[LNZ EDIT] [Add Ball] Resizing ball %d at line %d" % [ball_no, i])
					print("[LNZ EDIT] Old size = %d → New size = %d" % [old_size, new_size])
					parts[size_field_index] = str(new_size)
					var new_line = parts.join(sep)
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
				var parts = raw.split(delim, false)
				for j in range(parts.size()):
					parts[j] = parts[j].strip_edges()
				if parts.size() > size_field_index:
					var old_size = parts[size_field_index].to_int()
					var new_size = size_dif
					print("[LNZ EDIT] [Ballz Info] Resizing ball %d at line %d" % [ball_no, i])
					print("[LNZ EDIT] Old size = %d → New size = %d" % [old_size, new_size])
					parts[size_field_index] = str(new_size)
					var new_line = parts.join(sep)
					set_line(i, new_line)
					print("[LNZ EDIT] Updated line: %s" % new_line)
					save_file()
					return
				else:
					print("[LNZ EDIT] Line has too few fields for resizing ball %d" % ball_no)
					return
			count += 1
		print("[LNZ EDIT] Ball %d not found in [Ballz Info]" % ball_no)
