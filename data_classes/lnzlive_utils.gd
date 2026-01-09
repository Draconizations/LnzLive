extends Reference
class_name LnzLiveUtils

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

