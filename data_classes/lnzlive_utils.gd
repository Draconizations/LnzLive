extends Reference
class_name LnzLiveUtils

const DEFAULT_PALETTE = preload("res://resources/textures/petzpalette.png")
const BABYZ_PALETTE   = preload("res://resources/palettes/babyz_palette.png")

const ICON_EYE_NEUTRAL = preload("res://resources/icons/ico_eyelid_neutral.png")
const ICON_EYE_NOLID = preload("res://resources/icons/ico_eyelid_nolid.png")
const ICON_EYE_ANGRY = preload("res://resources/icons/ico_eyelid_angry.png")
const ICON_EYE_SCARED = preload("res://resources/icons/ico_eyelid_scared.png")

static func parse_number_list(s: String, allow_negatives: bool = false) -> Array:
	var result = []
	var parts = s.split(",", false)
	
	var range_regex = RegEx.new()
	range_regex.compile("^\\s*(-?\\d+)\\s*-\\s*(-?\\d+)\\s*$")
	
	for part in parts:
		var this_match = range_regex.search(part)
		
		if this_match:
			var start = this_match.get_string(1).to_int()
			var end = this_match.get_string(2).to_int()
			
			if not allow_negatives and (start < 0 or end < 0):
				continue
			
			var step = 1 if end >= start else -1
			
			for i in range(start, end + step, step):
				result.append(i)

		elif part.strip_edges().is_valid_integer():
			var val = part.strip_edges().to_int()
			
			if allow_negatives or val >= 0:
				result.append(val)
			
	return result

static func parse_flexible_integers(s: String) -> Array:
	var result = []
	var regex = RegEx.new()
	regex.compile("-?\\d+") 
	
	var matches = regex.search_all(s)
	for m in matches:
		result.append(m.get_string().to_int())
	
	return result

static func update_color_list_previews(container: Container, text: String, palette_colors: Array, max_previews: int = 8):
	if not is_instance_valid(container): return
	for child in container.get_children():
		child.queue_free()

	if palette_colors.empty():
		return

	var parsed = parse_number_list(text)
	var count = min(parsed.size(), max_previews)

	for i in range(count):
		var color_idx = parsed[i]
		var c = Color.white
		if color_idx >= 0 and color_idx < palette_colors.size():
			c = palette_colors[color_idx]

		var rect = ColorRect.new()
		rect.rect_min_size = Vector2(16, 16)
		rect.color = c

		var border = ReferenceRect.new()
		border.editor_only = false
		border.border_color = Color(0, 0, 0, 0.5) if c.v > 0.5 else Color(1, 1, 1, 0.5)
		border.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		rect.add_child(border)

		container.add_child(rect)

	if parsed.size() > max_previews:
		var label = Label.new()
		label.text = "+" + str(parsed.size() - max_previews)
		container.add_child(label)

static func get_ramp_color(current_color_str: String, rule):
    if not rule.get("is_ramp") or \
       not current_color_str.is_valid_integer() or \
       not str(rule.before_color).is_valid_integer() or \
       not str(rule.after_color).is_valid_integer():
        return null

    var current_color: int = int(current_color_str)
    var before_color: int = int(rule.before_color)
    var after_color: int = int(rule.after_color)

    if current_color < 10 or current_color > 199 or \
       before_color < 10 or before_color > 199:
        return null

    var current_base: int = (current_color / 10) * 10
    var before_base: int = (before_color / 10) * 10

    if current_base != before_base:
        return null

    if after_color >= 10 and after_color <= 199:
        var offset: int = current_color - current_base
        var after_base: int = (after_color / 10) * 10
        return str(after_base + offset)
    else:
        return str(after_color)


# func _get_ramp_color(current_color_str: String, rule):
# 	# Rule must be a ramp rule with valid before/after colors
# 	if not rule.is_ramp or rule.before_color.empty() or rule.after_color.empty():
# 		return null

# 	# All colors involved must be valid numbers
# 	if not current_color_str.is_valid_integer() or \
# 	   not rule.before_color.is_valid_integer() or \
# 	   not rule.after_color.is_valid_integer():
# 		return null

# 	var current_color: int = int(current_color_str)
# 	var before_color: int = int(rule.before_color)
# 	var after_color: int = int(rule.after_color)

# 	# Ramp ranges are 10-199
# 	if current_color < 10 or current_color > 199:
# 		return null
# 	if before_color < 10 or before_color > 199:
# 		return null

# 	# Find the base of the 10-unit ramp range (e.g., 62 -> 60)
# 	var current_base: int = int(current_color / 10) * 10
# 	var before_base: int = int(before_color / 10) * 10

# 	# Check if the current color is in the same ramp range as the rule's "before" color
# 	if current_base != before_base:
# 		return null # Not in the same ramp, this rule doesn't apply

# 	if after_color >= 10 and after_color <= 199:
# 		# "After" color is *also* in a ramp range (10-199)
# 		# Map to the corresponding color in the "after" ramp
# 		# e.g., Rule: 62 -> 55. Current: 60.
# 		# offset = 60 - 60 = 0
# 		# after_base = 50
# 		# new_color = 50 + 0 = 50
# 		var offset: int = current_color - current_base
# 		var after_base: int = int(after_color / 10) * 10
# 		var new_color: int = after_base + offset
# 		return str(new_color)
# 	else:
# 		# "After" color is *outside* ramp ranges (e.g., 244)
# 		# Map all colors in the "before" range to this single "after" color
# 		# e.g., Rule: 62 -> 244. Current: 60.
# 		# new_color = 244
# 		return str(after_color)


### SPATIAL UTILITIES ###
static func get_basis_from_normal(normal_vec: Vector3) -> Basis:
	var basis_y = normal_vec.normalized()
	var cross_vec = Vector3.UP.cross(basis_y)

	if cross_vec.length_squared() < 0.0001:
		cross_vec = Vector3.RIGHT.cross(basis_y)
	
	var basis_x = cross_vec.normalized()
	var basis_z = basis_y.cross(basis_x).normalized()
	
	return Basis(basis_x, basis_y, basis_z)

static func intersect_ray_with_plane(ray_origin: Vector3, ray_dir: Vector3, plane_normal: Vector3, plane_point: Vector3) -> Object:
	var denom = plane_normal.dot(ray_dir)
	if abs(denom) < 0.0001:
		return null
	var d = plane_normal.dot(plane_point - ray_origin) / denom
	return ray_origin + ray_dir * d

static func flip_camera_view(camera_node: Camera):
	var camera_transform = camera_node.transform
	camera_transform.basis.x *= -1
	camera_node.transform = camera_transform

### COORDINATE CONVERSIONS ###
static func world_to_lnz_delta(world_delta: Vector3, pixel_world_size: float, engine_scale: float) -> Vector3:
	var lnz_scale = engine_scale / 255.0
	var lnz_delta_raw = world_delta / (pixel_world_size * lnz_scale)
	lnz_delta_raw.y *= -1.0 # Invert Y for LNZ format
	return Vector3(round(lnz_delta_raw.x), round(lnz_delta_raw.y), round(lnz_delta_raw.z))

static func lnz_to_world_delta(lnz_delta: Vector3, pixel_world_size: float, engine_scale: float) -> Vector3:
	var lnz_scale = engine_scale / 255.0
	var world_delta = lnz_delta
	world_delta.y *= -1.0 # Invert Y back to world format
	return world_delta * (pixel_world_size * lnz_scale)

### SIZE CONVERSIONS ###
static func visual_size_to_lnz_size(target_visual: float, is_addball: bool, engine_scale: float, bhd_size: int = 0, enl_x: float = 100.0, enl_y: float = 0.0) -> int:
	var req_total = (target_visual / (engine_scale / 255.0)) + 2.0
	
	if not is_addball:
		req_total = (req_total - enl_y) / (enl_x / 100.0)
		
	return int(round(req_total - bhd_size))

static func snap_visual_size(target_visual: float, is_addball: bool, engine_scale: float, bhd_size: int = 0, enl_x: float = 100.0, enl_y: float = 0.0) -> float:
	var final_lnz = visual_size_to_lnz_size(target_visual, is_addball, engine_scale, bhd_size, enl_x, enl_y)
	var current_base_size = bhd_size + final_lnz
	
	if not is_addball:
		current_base_size = floor(current_base_size * (enl_x / 100.0)) + enl_y
		
	var offset = 2.0
	var snapped = round((current_base_size - offset) * (engine_scale / 255.0))
	snapped -= 1.0 - fmod(snapped, 2.0) # Apply LNZ's native snapping behavior
	return snapped

### PATTERN & PAINTBALL UTILITIES ###
static func generate_surface_walk(start_pos: Vector3, center: Vector3, step_scale_radius: float, steps: int, walk_spread: float) -> Array:
	var path: Array = []
	var curr_pos: Vector3 = start_pos
	var actual_dist: float = (start_pos - center).length()
	if actual_dist == 0:
		actual_dist = 1.0
		curr_pos = center + Vector3.UP
		
	var dir: Vector3 = Vector3(rand_range(-1.0, 1.0), rand_range(-1.0, 1.0), rand_range(-1.0, 1.0)).normalized()
	
	for _s in range(steps):
		var normal = (curr_pos - center).normalized()
		var tangent = (dir - normal * dir.dot(normal)).normalized()
		
		dir = (tangent + Vector3(rand_range(-0.5, 0.5), rand_range(-0.5, 0.5), rand_range(-0.5, 0.5))).normalized()
		
		var step_dist = step_scale_radius * rand_range(1.0, 2.5) * walk_spread
		curr_pos += tangent * step_dist
		curr_pos = center + (curr_pos - center).normalized() * actual_dist
		
		path.append(curr_pos)
		
	return path

static func calculate_gray_scott_grid(size: int, iterations: int, diff_a: float, diff_b: float, feed: float, kill: float, timestep: float) -> Array:
	var grid = []
	grid.resize(size * size)
	for i in range(size * size): grid[i] = {"a": 1.0, "b": 0.0}
	grid[(size/2) * size + (size/2)].b = 1.0
	
	for _t in range(iterations):
		var next = []
		next.resize(size * size)
		for x in range(1, size - 1):
			for y in range(1, size - 1):
				var i = y * size + x
				var a = grid[i].a
				var b = grid[i].b
				var lp_a = (grid[i-1].a + grid[i+1].a + grid[i-size].a + grid[i+size].a) - 4 * a
				var lp_b = (grid[i-1].b + grid[i+1].b + grid[i-size].b + grid[i+size].b) - 4 * b
				var r = a * b * b
				next[i] = {
					"a": clamp(a + (diff_a * lp_a - r + feed * (1 - a)) * timestep, 0.0, 1.0),
					"b": clamp(b + (diff_b * lp_b + r - (kill + feed) * b) * timestep, 0.0, 1.0)
				}
		for i in range(size * size): 
			if next[i] != null: 
				grid[i] = next[i]
	return grid

static func parse_lsystem_rules(rules_text: String) -> Dictionary:
	var rules = {}
	var lines = rules_text.split("\n", false)
	for line in lines:
		var parts = line.split("=", false, 1)
		if parts.size() == 2:
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			if not key.empty():
				rules[key] = value
	return rules

static func generate_lsystem_string(axiom: String, rules: Dictionary, iterations: int) -> String:
	var current_string = axiom
	for _i in range(iterations):
		var new_string = ""
		for char_idx in range(current_string.length()):
			var current_char = current_string[char_idx]
			if rules.has(current_char):
				new_string += rules[current_char]
			else:
				new_string += current_char
		current_string = new_string
	return current_string

static func generate_random_lsystem() -> Dictionary:
	var variables = ["F", "G", "A", "B", "X"]
	var constants = ["+", "-"]
	var all_chars = variables + constants

	var axiom = variables[randi() % variables.size()]
	var rules = {}
	var num_rules = 2 + randi() % 2 
	
	variables.shuffle()
	
	for i in range(num_rules):
		var key = variables[i]
		var value = ""
		var value_length = 3 + randi() % 5
		
		var current_len = 0
		while current_len < value_length:
			if randf() < 0.2 and current_len < value_length - 2:
				value += "[" + all_chars[randi() % all_chars.size()] + "]"
				current_len += 3
			else:
				value += all_chars[randi() % all_chars.size()]
				current_len += 1
		
		rules[key] = value

	var rule_lines = []
	for key in rules:
		rule_lines.append(key + "=" + rules[key])
	var rules_text = PoolStringArray(rule_lines).join("\n")

	return {"axiom": axiom, "rules_text": rules_text}

### IMAGE/MASKING UTILITIES ###
static func compute_distance_transform(mask: Array, size: int) -> Array:
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

static func clear_mask_circle(mask: Array, size: int, cx: int, cy: int, radius: float) -> int:
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