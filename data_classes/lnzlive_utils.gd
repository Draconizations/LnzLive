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
