extends Reference
class_name LnzParser
## lnz_parser.gd
## A data class that parses entries from LNZ data

var r = RegEx.new()
var str_r = RegEx.new()

class VariationBlock:
	var id: int
	var name: String
	var section: String
	var start_line: int
	var lines: Array = []

	func _init(p_id, p_name, p_section, p_start_line):
		id = p_id
		name = p_name
		section = p_section
		start_line = p_start_line

class VirtualFileLineReader:
	var _lines: Array
	var _cursor: int = 0

	func _init(lines: Array):
		_lines = lines

	func get_line() -> String:
		if _cursor < _lines.size():
			var line = _lines[_cursor]
			_cursor += 1
			return line
		return ""

	func eof_reached() -> bool:
		return _cursor >= _lines.size()

	func seek(pos: int):
		if pos == 0:
			_cursor = 0
		else:
			print("Warning: VirtualFileLineReader only supports seek(0)")

	func get_position() -> int:
		return _cursor

	func get_len() -> int:
		return _lines.size()

var species = 0
var scales = Vector2(255, 255)
var eyelid_color = 244
var leg_extensions = Vector2(0, 0)
var body_extension = 0
var face_extension = 0
var ear_extension = 0
var head_enlargement = Vector2(100, 0)
var foot_enlargement = Vector2(100, 0)
var moves = []
var balls = {}
var lines = []
var polygons = []
var addballs = {}
var paintballs = {}
var omissions = {}
var project_ball = []
var texture_list = []
var no_texture_rotate = []
var palette = null

var sections_map = {}

var whisker_connections = []

var custom_eyes = {}

var eyelash_lengths = []
var eyelash_angle   = 0
var eyelash_spacing = 0
var eyelash_color   = -1

var z_shade_slope = 100

var file_path

func _init(file_path):
	if file_path == null:
		return
	
	self.file_path = file_path
	r.compile("[-.\\d]+")
	str_r.compile("[\\S]+")
	
	var file = File.new()
	if file.file_exists(file_path):
		file.open(file_path, File.READ)
	else:
		print("File not found: " + file_path)
		return

	# # Load base data
	# get_texture_list(file)
	# get_no_texture_rotate(file)
	# get_palette(file)
	# get_species(file)
	# get_default_scales(file)
	# get_leg_extensions(file)
	# get_body_extension(file)
	# get_face_extension(file)
	# get_ear_extension(file)
	# get_head_enlargement(file)
	# get_feet_enlargement(file)
	# get_omissions(file)
	# get_lines(file)
	# get_polygons(file)
	# get_balls(file)
	# get_addballs(file)

	# # Apply overrides after loading base data
	# get_ball_size_override(file)
	# get_fuzz_override(file)
	# get_add_ball_override(file)
	# get_color_info_override(file)
	# get_outline_color_override(file)

	# # Additional parsing for project balls and moves
	# get_project_balls(file)
	# parse_paintballs(file)
	# parse_moves(file)

	# # Rendering options
	# get_eyelid_color(file)
	# get_eyelash_info(file)
	# get_whiskers(file)
	# get_z_shade_slope(file)
	
	_scan_file(file)
	file.close()

func _scan_file(file: File):
	sections_map = {}
	var current_section = "Header"
	var current_var_id = 0
	var line_number = 0

	var var_regex = RegEx.new()
	var_regex.compile("^#(\\d+)(.*)")

	_ensure_block(current_section, 0, 0)

	while !file.eof_reached():
		var line = file.get_line()
		var line_stripped = line.strip_edges()

		if line_stripped.begins_with("["):
			var end_bracket = line_stripped.find("]")
			if end_bracket != -1:
				current_section = line_stripped.substr(1, end_bracket - 1)
				current_var_id = 0
				_ensure_block(current_section, current_var_id, line_number)
		elif line.begins_with("#"):
			var match_res = var_regex.search(line_stripped)
			if match_res:
				current_var_id = int(match_res.get_string(1))
				var var_name = match_res.get_string(2).strip_edges()
				if var_name.begins_with("-"):
					var_name = var_name.substr(1).strip_edges()

				_ensure_block(current_section, current_var_id, line_number, var_name)
			else:
				# Just a comment or unrecognized
				_append_line(current_section, current_var_id, line)
		else:
			_append_line(current_section, current_var_id, line)

		line_number += 1

func _ensure_block(section, id, start_line, custom_name = ""):
	if !sections_map.has(section):
		sections_map[section] = {}
	if !sections_map[section].has(id):
		var name = "Base" if id == 0 else "Variation " + str(id)
		if custom_name != "":
			name = custom_name
		sections_map[section][id] = VariationBlock.new(id, name, section, start_line)
	elif custom_name != "":
		# Update name if we found it later (though scanning is linear so this case is rare/redundant)
		sections_map[section][id].name = custom_name

func _append_line(section, id, line):
	if sections_map.has(section) and sections_map[section].has(id):
		sections_map[section][id].lines.append(line)

func get_next_section(file: File, section_name: String):
	file.seek(0)
	var this_line = ""
	while !this_line.begins_with("[" + section_name + "]") and !file.eof_reached():
		this_line = file.get_line()
	if file.eof_reached():
		return false
	return true

func compile_section(section_name: String, active_ids: Array) -> VirtualFileLineReader:
	var compiled_lines = []
	
	if sections_map.has(section_name):
		var section_dict = sections_map[section_name]

		if section_dict.has(0):
			compiled_lines.append_array(section_dict[0].lines)

		for id in active_ids:
			if id != 0 and section_dict.has(id):
				compiled_lines.append_array(section_dict[id].lines)

	return VirtualFileLineReader.new(compiled_lines)

func get_parsed_lines(reader, keys: Array):
	var return_array = []
	while true:
		var line = reader.get_line().dedent()
		if line.empty() and reader.eof_reached():
			break
		if line.begins_with("[") or line.begins_with("#2"): # Should not happen in compiled section usually
			break
		if line.empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		
		var data_only = line.split(";")[0] 
		var parsed = r.search_all(data_only) 

		if parsed.size() == 0:
			continue
		var dict = {}
		for i in range(keys.size()):
			if i < parsed.size():
				dict[keys[i]] = int(parsed[i].get_string())
		return_array.append(dict)
	return return_array

func get_parsed_line_strings(reader, keys: Array):
	var return_array = []
	while true:
		var line = reader.get_line().dedent()
		if line.empty() and reader.eof_reached():
			break
		if line.begins_with("[") or line.begins_with("#2"):
			break
		if line.empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		var parsed = str_r.search_all(line)
		var dict = {}
		var i = 0
		for key in keys:
			if i < parsed.size():
				dict[key] = parsed[i].get_string()
				i += 1
			else:
				dict[key] = ""
		return_array.append(dict)
	return return_array

func get_species():
	var reader = compile_section("Species", [0])
	var parsed_lines = get_parsed_lines(reader, ["species"])
	if parsed_lines.size() == 0:
		print("[Species] not found. Looking for [Default Linez File] as a fallback.")
		reader = compile_section("Default Linez File", [0])
		var path_line = reader.get_line().strip_edges()
		var lower_path = path_line.to_lower()
		if "dog" in lower_path:
			print("[STATUS] lnz_parser: get_species: detected [Default Linez File] path contained 'dog'. Setting species to Dogz (Species = 2)")
			species = 2
		elif "cat" in lower_path:
			print("[STATUS] lnz_parser: get_species: detected [Default Linez File] path contained 'cat'. Setting species to Catz (Species = 1)")
			species = 1
		elif "baby" in lower_path:
			print("[STATUS] lnz_parser: get_species: detected [Default Linez File] path contained 'baby'. Setting species to Babyz (Species = 3)")
			species = 3
		else:
			print("[STATUS] lnz_parser: get_species: could not determine species from file")
			species = 0
	else:
		species = parsed_lines[0].species
		if species == 1:
			print("[STATUS] lnz_parser: get_species: detected [Species]: Catz (Species = " + str(species) + ")")
		elif species == 2:
			print("[STATUS] lnz_parser: get_species: detected [Species]: Dogz (Species = " + str(species) + ")")
		elif species == 3:
			print("[STATUS] lnz_parser: get_species: detected [Species]: Babyz (Species = " + str(species) + ")")
		else:
			print("[STATUS] lnz_parser: get_species: no detected [Species]: ??? (Species = " + str(species) + ")")	

func get_texture_list(reader):
	var parsed_lines = get_parsed_line_strings(reader, ["filepath", "transparent_color", "width", "height"])
	for line in parsed_lines:
		var filename = line.filepath.get_file()
		var texture_size = null

		if line.has("width") and line.has("height"):
			var width = float(line.width) if line.width.is_valid_float() else 256
			var height = float(line.height) if line.height.is_valid_float() else 256
			if width != null and height != null:
				texture_size = Vector2(width, height)

		texture_list.append({filename = filename, transparent_color = line.transparent_color, texture_size = texture_size})

func get_no_texture_rotate(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball_no"])
	no_texture_rotate = []
	for line in parsed_lines:
		no_texture_rotate.append(line.ball_no)

func get_palette(reader):
	var raw_line = reader.get_line().strip_edges()
	
	while raw_line.empty() or raw_line.begins_with(";"):
		if reader.eof_reached():
			break
		raw_line = reader.get_line().strip_edges()
	
	if not raw_line.empty():
		palette = raw_line + ".png"
	else:
		palette = null

func parse_paintballs(reader):
	while true:
		var line = reader.get_line()
		if line.empty() and reader.eof_reached():
			break
		if line.begins_with("[") or line.begins_with("#2"):
			break
		if line.empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		var split_line = r.search_all(line)
		if split_line.size() < 11:
			continue
		var base = int(split_line[0].get_string())
		var diameter = int(split_line[1].get_string())
		var position = Vector3(
			float(split_line[2].get_string()),
			float(split_line[3].get_string()),
			float(split_line[4].get_string())
		)
		var color = int(split_line[5].get_string())
		var outline_color = int(split_line[6].get_string()) if int(split_line[6].get_string()) != -1 else 0
		var fuzz = int(split_line[7].get_string())
		var outline = int(split_line[8].get_string())
		var texture = int(split_line[10].get_string())
		var anchored = int(split_line[11].get_string()) if split_line.size() > 11 else 0

		var paintball = PaintBallData.new(base, diameter, position, color, outline_color, outline, fuzz, 0, texture, anchored)
		var pb_array = self.paintballs.get(base, [])
		pb_array.append(paintball)
		self.paintballs[base] = pb_array

func parse_moves(reader):
	while true:
		var raw = reader.get_line()
		var line = raw.strip_edges()
		if line.empty() and reader.eof_reached():
			break
		if line.begins_with("["):
			break
		if line == "" or line.empty():
			continue
		if line.begins_with(";") or line.begins_with("#"):
			continue
		var split_line = r.search_all(line)
		if split_line.size() < 4:
			continue
		var base = int(split_line[0].get_string())
		var position = Vector3(
			int(split_line[1].get_string()),
			int(split_line[2].get_string()),
			int(split_line[3].get_string())
		)
		var relative_to = int(split_line[4].get_string()) if split_line.size() > 4 else base
		moves.append({"ball_no": base, "position": position, "relative_to": relative_to})
		
func get_project_balls(reader):
	var parsed_lines = get_parsed_lines(reader, ["fixed_ball", "project_ball", "amount"])
	for line in parsed_lines:
		var amount = line.amount
		project_ball.append({
			"fixed_ball": line.fixed_ball,
			"project_ball": line.project_ball,
			"min_projection": amount - 50,
			"max_projection": amount + 50,
			"comment": ""
		})

func get_eyes(reader):
	# Row 1: Left Eye Base, Right Eye Base
	# Row 2: Left Iris, Right Iris
	var parsed_lines = get_parsed_lines(reader, ["left", "right"])
	
	if parsed_lines.size() >= 2:
		custom_eyes.clear()
		var eyeL = parsed_lines[0].left
		var eyeR = parsed_lines[0].right
		var irisL = parsed_lines[1].left
		var irisR = parsed_lines[1].right
		
		custom_eyes[irisL] = eyeL
		custom_eyes[irisR] = eyeR
		
		print("[STATUS] lnz_parser: get_eyes: parsed custom eyes mapping: ", custom_eyes)

func get_whiskers(reader):
	if reader.get_len() == 0:
		if species == KeyBallsData.Species.CAT:
			KeyBallsData.species = KeyBallsData.Species.CAT 
			var jowlL = KeyBallsData.get_ball_id_by_name("jowlL")
			var jowlR = KeyBallsData.get_ball_id_by_name("jowlR")
			
			if jowlL != -1 and jowlR != -1:
				var whiskers = KeyBallsData.cat_body_part_symmetry.Head.Whiskers
				for w in whiskers.left:
					whisker_connections.append({"start": w, "end": jowlL})
				for w in whiskers.right:
					whisker_connections.append({"start": w, "end": jowlR})
		return
	
	while true:
		var line = reader.get_line().dedent()
		if line.empty() and reader.eof_reached():
			break
		if line.begins_with("["):
			break
		if line.empty() or line.begins_with(";") or line.begins_with("#"):
			continue
			
		var parsed = r.search_all(line)
		if parsed.size() >= 2:
			var jowl_ball = int(parsed[0].get_string())
			var whisker_ball = int(parsed[1].get_string())
			whisker_connections.append({"start": whisker_ball, "end": jowl_ball})

func get_eyelid_color(reader):
	var parsed_lines = get_parsed_lines(reader, ["color", "group"])
	if parsed_lines.size() > 0:
		eyelid_color = parsed_lines[0]["color"]
	else:
		eyelid_color = 244

func get_eyelash_info(reader):
	if reader.get_len() == 0:
		return
	
	var raw_lines = []
	while true:
		var line = reader.get_line().strip_edges()
		if line.empty() and reader.eof_reached():
			break
		if line.begins_with("["):
			break
		if line.empty() or line.begins_with(";") or line.begins_with("#") or line.begins_with("="):
			continue
		raw_lines.append(line)

	if raw_lines.size() >= 4:
		var all_lengths = LnzLiveUtils.parse_flexible_integers(raw_lines[0])
		eyelash_lengths = []
		for val in all_lengths:
			if val == -1: break
			eyelash_lengths.append(val)
		
		var angle_vals = LnzLiveUtils.parse_flexible_integers(raw_lines[1])
		eyelash_angle = angle_vals[0] if angle_vals.size() > 0 else 15
		
		var spacing_vals = LnzLiveUtils.parse_flexible_integers(raw_lines[2])
		eyelash_spacing = spacing_vals[0] if spacing_vals.size() > 0 else 50
		
		var color_vals = LnzLiveUtils.parse_flexible_integers(raw_lines[3])
		eyelash_color = color_vals[0] if color_vals.size() > 0 else 244
		
	print("[STATUS] lnz_parser: get_eyelash_info: parsed eyelash info: ", eyelash_lengths, " with angle: ", eyelash_angle)

func get_balls(reader):
	var parsed_lines = get_parsed_lines(reader, ["color", "outline_color", "speckle", "fuzz", "outline", "size", "group", "texture"])
	if parsed_lines.size() == 0:
		print("[ERROR] lnz_parser: get_balls: no [Ballz Info] found")
	var i = 0
	for line in parsed_lines:
		var bd = BallData.new(
			line.size, 
			Vector3.ZERO, 
			i, 
			Vector3.ZERO,
			line.color,
			line.outline_color, 
			line.outline, 
			line.fuzz, 
			0.0, 
			line.group, 
			line.texture)
		self.balls[i] = bd
		#print("[STATUS] lnz_parser: get_balls: added ball " + str(i) + " with size " + str(line.size))
		i += 1

func get_addballs(reader):
	var parsed_lines = get_parsed_lines(
		reader,
		[
			"base",
			"x",
			"y",
			"z",
			"color",
			"outline_color",
			"speckle",
			"fuzz",
			"group",
			"outline",
			"size",
			"body_area",
			"add_group",
			"texture",
			"anchor_ball"
		]
	)

	var max_ball_num = 0
	if balls.size() > 0:
		max_ball_num = balls.keys().max() + 1

	for line in parsed_lines:
		var pos = Vector3(line.x, line.y, line.z)
		var ball = AddBallData.new(
			line.base,
			max_ball_num,
			line.size,
			pos,
			line.color,
			line.outline_color,
			line.outline,
			line.fuzz,
			0,
			line.group,
			line.body_area,
			line.get("texture", -1),
			line.get("add_group", 0),
			line.get("anchor_ball", -1)
		)
		addballs[max_ball_num] = ball
		max_ball_num += 1

func get_default_scales(reader):
	var parsed_lines = get_parsed_lines(reader, ["scale"])
	if parsed_lines.size() > 0:
		scales = Vector2(parsed_lines[0].scale, parsed_lines[1].scale)
	
func get_leg_extensions(reader):
	var parsed_lines = get_parsed_lines(reader, ["extension"])
	if parsed_lines.size() > 0:
		leg_extensions = Vector2(parsed_lines[0].extension, parsed_lines[1].extension)
	
func get_body_extension(reader):
	var parsed_lines = get_parsed_lines(reader, ["extension"])
	if parsed_lines.size() > 0:
		body_extension = parsed_lines[0].extension
	
func get_face_extension(reader):
	var parsed_lines = get_parsed_lines(reader, ["extension"])
	if parsed_lines.size() > 0:
		face_extension = parsed_lines[0].extension

func get_ear_extension(reader):
	var parsed_lines = get_parsed_lines(reader, ["extension"])
	if parsed_lines.size() > 0:
		ear_extension = parsed_lines[0].extension
	
func get_head_enlargement(reader):
	var parsed_lines = get_parsed_lines(reader, ["scale"])
	if parsed_lines.size() > 0:
		head_enlargement = Vector2(parsed_lines[0].scale, parsed_lines[1].scale)
	
func get_feet_enlargement(reader):
	var parsed_lines = get_parsed_lines(reader, ["scale"])
	if parsed_lines.size() > 0:
		foot_enlargement = Vector2(parsed_lines[0].scale, parsed_lines[1].scale)
	
func get_omissions(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball_no"])
	omissions = {}
	for line in parsed_lines:
		omissions[line.ball_no] = true
		
func get_lines(reader):
	var parsed_lines = get_parsed_lines(reader, ["start", "end", "fuzz", "color", "l_color", "r_color", "start_thickness", "end_thickness", "full_outline", "draw_order"])
	for line in parsed_lines:
		var full_outline = line.get("full_outline", -1)
		var draw_order = line.get("draw_order", -1)
		var line_data = LineData.new(
			line.start,
			line.end,
			line.start_thickness,
			line.end_thickness,
			line.fuzz, line.color,
			line.l_color,
			line.r_color,
			full_outline,
			draw_order)
		lines.append(line_data)

func get_polygons(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball1", "ball2", "ball3", "ball4", "color", "l_edge_color", "r_edge_color", "fuzz", "texture"])
	for line in parsed_lines:
		var poly_data = PolyData.new(
			line.ball1,
			line.ball2,
			line.ball3,
			line.ball4,
			line.color,
			line.l_edge_color,
			line.r_edge_color,
			line.fuzz,
			line.texture
		)
		polygons.append(poly_data)

func get_ball_size_override(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball", "size"])
	for line in parsed_lines:
		if balls.has(line.ball):
			balls[line.ball].size = line.size
		elif addballs.has(line.ball):
			addballs[line.ball].size = line.size
		else:
			print("[WARNING] lnz_parser: get_ball_size_override: size override attempted for non-existent ball ", line.ball)

func get_color_info_override(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball", "color", "group", "texture"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "color_index" in ball_data:
				ball_data.color_index = line.color
			if "group" in ball_data and line.has("group"):
				ball_data.group = line.group
			if "texture_id" in ball_data and line.has("texture"):
				ball_data.texture_id = line.texture
		elif addballs.has(line.ball):
			var ball_data = addballs[line.ball]
			if "color" in ball_data:
				ball_data.color = line.color
			if "group" in ball_data and line.has("group"):
				ball_data.group = line.group
			if "texture_id" in ball_data and line.has("texture"):
				ball_data.texture_id = line.texture
		else:
			print("[WARNING] lnz_parser: get_color_info_override: color override attempted for non-existent ball ", line.ball)

func get_outline_color_override(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball", "outline_color"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "outline_color_index" in ball_data:
				ball_data.outline_color_index = line.outline_color
		elif addballs.has(line.ball):
			var ball_data = addballs[line.ball]
			if "outline_color" in ball_data:
				ball_data.outline_color = line.outline_color
		else:
			print("[WARNING] lnz_parser: get_outline_color_override: outline color override attempted for non-existent ball ", line.ball)

func get_fuzz_override(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball", "fuzz"])
	for line in parsed_lines:
		if balls.has(line.ball):
			var ball_data = balls[line.ball]
			if "fuzz" in ball_data:
				ball_data.fuzz = line.fuzz
		elif addballs.has(line.ball):
			var ball_data = addballs[line.ball]
			if "fuzz" in ball_data:
				ball_data.fuzz = line.fuzz
		else:
			print("[WARNING] lnz_parser: get_fuzz_override: fuzz override attempted for non-existent ball ", line.ball)

func get_add_ball_override(reader):
	var parsed_lines = get_parsed_lines(reader, ["ball", "x", "y", "z"])
	for line in parsed_lines:
		if addballs.has(line.ball):
			addballs[line.ball].position = Vector3(line.x, line.y, line.z)
		else:
			print("[WARNING] lnz_parser: get_add_ball_override: add ball override attempted for non-existent ball ", line.ball)

func get_z_shade_slope(reader):
	if reader.get_len() > 0:
		var parsed_lines = get_parsed_lines(reader, ["slope"])
		if parsed_lines.size() > 0:
			z_shade_slope = int(parsed_lines[0].slope)
