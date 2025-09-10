extends CanvasLayer

signal randomize_auto_paintballz(paintballz)

signal apply_auto_paintballz

signal clear_auto_paintballz

onready var params_container = find_node("ParamsContainer")

func _ready():
	find_node("RandomizeButton").connect("pressed", self, "_on_RandomizeButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("Distribution").connect("item_selected", self, "_on_Distribution_item_selected")
	get_viewport().connect("size_changed", self, "_on_viewport_size_changed")
	_on_viewport_size_changed()
	_on_Distribution_item_selected(0)


func _on_viewport_size_changed():
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	panel.margin_left = (viewport_size.x - panel_size.x) / 2
	panel.margin_right = panel.margin_left + panel_size.x
	panel.margin_top = viewport_size.y - panel_size.y - 10
	panel.margin_bottom = panel.margin_top + panel_size.y

func _on_Distribution_item_selected(index):
	for child in params_container.get_children():
		child.hide()

	match index:
		1: # Spiral
			params_container.get_node("SpiralTurnsContainer").show()
		2: # Star
			params_container.get_node("StarPointsContainer").show()
			params_container.get_node("RayLengthContainer").show()
		3, 4: # Horizontal/Vertical Bands
			params_container.get_node("NumBandsContainer").show()
		5, 6: # Grid/Checkerboard
			params_container.get_node("GridSizeContainer").show()
		8: # Clustered
			params_container.get_node("NumClustersContainer").show()
		11: # Halfie
			params_container.get_node("HalfieContainer").show()
		12: # Bullseye
			params_container.get_node("BullseyeContainer").show()
		13: # Stripes
			params_container.get_node("StripesContainer").show()
		14: # Leopard
			params_container.get_node("LeopardContainer").show()
		15: # Rainbow
			params_container.get_node("RainbowContainer").show()

func _on_RandomizeButton_pressed():
	var properties = get_properties()
	var affected_ballz = _parse_number_list(properties.affected_ballz)
	if affected_ballz.empty():
		return

	var color_list = _parse_number_list(properties.color_list)
	if color_list.empty():
		return

	var outline_color_list = _parse_number_list(properties.outline_color_list)
	if outline_color_list.empty():
		return

	var texture_list_str = properties.texture_list
	var texture_list = _parse_number_list(texture_list_str, true) # Allow negatives
	if texture_list.empty() and not texture_list_str.strip_edges().empty():
		push_warning("Could not parse Texture List. Using default.")
		texture_list.append(-1)
	elif texture_list.empty():
		texture_list.append(-1)

	var paintballz = []
	var distribution_mode = properties.distribution
	var cluster_center = Vector3()

	if distribution_mode == 2: # Star
		var num_stars = properties.num_spots
		var num_points = int(properties.star_points)
		var point_size = int(properties.star_point_size)
		var ray_length = properties.ray_length

		if num_points <= 1 or ray_length <= 0:
			return

		for i in range(num_stars):
			var star_color = color_list[randi() % color_list.size()]
			var star_outline_color = outline_color_list[randi() % outline_color_list.size()]
			var star_ball_index = affected_ballz[randi() % affected_ballz.size()]
			
			var star_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			
			var basis = _get_basis_from_normal(star_center)
			
			for p in range(num_points):
				var angle = (float(p) / num_points) * 2 * PI
				var tangent_dir = (basis.x * cos(angle) + basis.z * sin(angle))
				
				var ray_angle_factor = 0.1
				var tip = star_center.slerp(star_center + tangent_dir, ray_length * ray_angle_factor).normalized()

				var ray_base_size = rand_range(properties.size_min, properties.size_max)

				for j in range(int(ray_length)):
					var pos = star_center.slerp(tip, float(j + 1) / ray_length)
					
					var progress = float(j) / ray_length
					var progressive_size = lerp(ray_base_size, point_size, progress)
					var final_size = max(progressive_size, point_size)

					var paintball = PaintBallData.new(
						star_ball_index,
						final_size,
						pos.normalized(),
						star_color,
						star_outline_color,
						floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
						floor(rand_range(properties.fuzz_min, properties.fuzz_max)),
						0, # z_add
						texture_list[randi() % texture_list.size()],
						1 if properties.anchored else 0,
						properties.group
					)
					paintballz.append(paintball)
	elif distribution_mode == 12: # Bullseye
		var num_targets = properties.num_spots
		var num_rings = properties.num_rings
		
		if num_rings <= 0 or color_list.size() == 0:
			return

		for i in range(num_targets):
			var target_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			var start_size = rand_range(properties.size_min, properties.size_max)
			var ball_index = affected_ballz[randi() % affected_ballz.size()]

			for r in range(num_rings):
				var ring_size = start_size * (1.0 - float(r) / num_rings)
				var ring_color = color_list[r % color_list.size()]
				
				var paintball = PaintBallData.new(
					ball_index,
					ring_size,
					target_center,
					ring_color,
					outline_color_list[randi() % outline_color_list.size()],
					floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
					floor(rand_range(properties.fuzz_min, properties.fuzz_max)),
					0, # z_add
					texture_list[randi() % texture_list.size()],
					1 if properties.anchored else 0,
					properties.group
				)
				paintballz.append(paintball)
	elif distribution_mode == 13: # Stripes
		var noise = OpenSimplexNoise.new()
		noise.seed = randi()
		noise.octaves = 4
		noise.persistence = 0.6

		if properties.stripe_scale > 0:
			noise.period = 48.0 / properties.stripe_scale
		else:
			noise.period = 48.0

		# stripes will be perpendicular to a random axis
		var stripe_axis = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		if stripe_axis.length_squared() == 0:
			stripe_axis = Vector3.UP

		var stripe_frequency = properties.stripe_frequency
		var distortion_amount = properties.stripe_distortion
		var threshold = properties.stripe_thickness

		var generated_count = 0
		# loop until the desired number of paintballz have been generated
		while generated_count < properties.num_spots:
			# generate a random point on the surface of a sphere
			var p = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1))
			if p.length_squared() == 0:
				continue # avoid normalizing a zero-length vector
			p = p.normalized()

			# evenly spaced bands
			var main_val = p.dot(stripe_axis)
			
			# 3D noise value
			var noise_val = noise.get_noise_3d(p.x, p.y, p.z)
			
			# combine base value and noise in a sine wave to create wavy stripes
			var stripe_value = sin(main_val * stripe_frequency + noise_val * distortion_amount)

			# if the calculated value is above the threshold, place a paintball
			if stripe_value > threshold:
				var ball_index = affected_ballz[randi() % affected_ballz.size()]
				var size = rand_range(properties.size_min, properties.size_max)
				var color = color_list[randi() % color_list.size()]
				var outline_color = outline_color_list[randi() % outline_color_list.size()]
				var outline_type = floor(rand_range(properties.outline_type_min, properties.outline_type_max))
				var fuzz = floor(rand_range(properties.fuzz_min, properties.fuzz_max))
				var texture = texture_list[randi() % texture_list.size()]
				var group = properties.group
				
				var paintball = PaintBallData.new(
					ball_index,
					size,
					p,
					color,
					outline_color,
					outline_type,
					fuzz,
					0, # z_add
					texture,
					1 if properties.anchored else 0,
					group
				)
				paintballz.append(paintball)
				generated_count += 1
	elif distribution_mode == 14: # Leopard
			if color_list.size() < 2:
				push_warning("Leopard mode requires at least 2 colors (outer and inner)")
				return

			var color_pairs = []
			if properties.leopard_use_paired_colors:
				for i in range(0, color_list.size() - 1, 2):
					color_pairs.append([color_list[i], color_list[i+1]])
				if color_pairs.empty():
					push_warning("Paired Colors enabled, but no valid outer/inner pairs were found")
					return

			var spot_noise = OpenSimplexNoise.new()
			spot_noise.seed = randi()
			spot_noise.period = 2.0

			var num_spots_to_make = properties.num_spots
			for i in range(num_spots_to_make):
				var spot_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
				if spot_center.length_squared() == 0: spot_center = Vector3.UP
				
				var basis = _get_basis_from_normal(spot_center)
				
				var spot_angle_rad = rand_range(properties.leopard_radius_min, properties.leopard_radius_max)
				
				var paintball_size = rand_range(properties.size_min, properties.size_max)

				var color_outline = 0
				var color_fill = 0
				if properties.leopard_use_paired_colors:
					var chosen_pair = color_pairs[randi() % color_pairs.size()]
					color_outline = chosen_pair[0]
					color_fill = chosen_pair[1]
				else:
					color_outline = color_list[randi() % color_list.size()]
					color_fill = color_list[randi() % color_list.size()]
					while color_fill == color_outline:
						color_fill = color_list[randi() % color_list.size()]

				var outline_points = 20
				for j in range(outline_points):
					if randf() > properties.leopard_completeness:
						continue
					
					var irregularity = properties.leopard_irregularity
					var current_radius = spot_angle_rad * rand_range(1.0 - irregularity, 1.0 + irregularity)
					
					var circle_angle = (float(j) / outline_points) * TAU
					var direction = (basis.x * cos(circle_angle) + basis.z * sin(circle_angle))
					var pos = spot_center.slerp(spot_center + direction.normalized(), current_radius)

					var paintball = PaintBallData.new(affected_ballz[randi() % affected_ballz.size()],
						paintball_size, pos, color_outline,
						outline_color_list[randi() % outline_color_list.size()], floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
						rand_range(properties.fuzz_min, properties.fuzz_max), 0, texture_list[randi() % texture_list.size()],
						1 if properties.anchored else 0, properties.group)
					paintballz.append(paintball)

				var fill_points = 25
				for j in range(fill_points):
					var random_radius = sqrt(randf())
					var random_angle = rand_range(0, TAU)
					
					var noise_val = spot_noise.get_noise_1d(random_angle * spot_noise.period)
					var noise_radius = random_radius * (0.7 + 0.3 * noise_val)
					
					var fill_radius_rad = noise_radius * spot_angle_rad

					var direction = (basis.x * cos(random_angle) + basis.z * sin(random_angle))
					var pos = spot_center.slerp(spot_center + direction.normalized(), fill_radius_rad)
					
					var paintball = PaintBallData.new(affected_ballz[randi() % affected_ballz.size()],
						paintball_size, pos, color_fill,
						outline_color_list[randi() % outline_color_list.size()], floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
						rand_range(properties.fuzz_min, properties.fuzz_max), 0, texture_list[randi() % texture_list.size()],
						1 if properties.anchored else 0, properties.group)
					paintballz.append(paintball)

				var inner_dots = randi() % 3 + 1
				for j in range(inner_dots):
					var random_radius = randf() * spot_angle_rad * 0.7
					var random_angle = rand_range(0, TAU)

					var direction = (basis.x * cos(random_angle) + basis.z * sin(random_angle))
					var pos = spot_center.slerp(spot_center + direction.normalized(), random_radius)

					var paintball = PaintBallData.new(affected_ballz[randi() % affected_ballz.size()],
						paintball_size * 0.6, pos, color_outline,
						outline_color_list[randi() % outline_color_list.size()], floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
						rand_range(properties.fuzz_min, properties.fuzz_max), 0, texture_list[randi() % texture_list.size()],
						1 if properties.anchored else 0, properties.group)
					paintballz.append(paintball)
	elif distribution_mode == 15: # Rainbow
		var num_rainbows = properties.num_spots
		
		for i in range(num_rainbows):
			var paintball_size = rand_range(properties.size_min, properties.size_max)
			
			var arc_start = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			if arc_start.length_squared() == 0: arc_start = Vector3.FORWARD
			
			var basis = _get_basis_from_normal(arc_start)
			
			var arc_direction = basis.x
			
			var rotation_axis = arc_start.cross(arc_direction).normalized()
			
			rotation_axis = rotation_axis.slerp(arc_start, properties.rainbow_curvature)
			
			rotation_axis = rotation_axis.rotated(arc_start, deg2rad(properties.rainbow_angle))

			for color_index in range(color_list.size()):
				var current_color = color_list[color_index]
				
				var offset_axis = rotation_axis.cross(arc_start).normalized()
				var offset_dist = (float(color_index) - float(color_list.size() - 1) / 2.0) * properties.rainbow_width
				var band_offset_rad = atan(offset_dist * paintball_size * 0.1) 
				
				var band_start = arc_start.rotated(offset_axis, band_offset_rad)
				var band_axis = rotation_axis.rotated(offset_axis, band_offset_rad)

				var arc_length_rad = PI * properties.rainbow_length
				
				var num_paintballs_in_line = 0
				var angular_diameter = 2 * atan(paintball_size * 0.01)
				if angular_diameter > 0:
					num_paintballs_in_line = floor(arc_length_rad / (angular_diameter * 0.9))

				for p_idx in range(num_paintballs_in_line):
					var step_angle = (float(p_idx) / max(1, num_paintballs_in_line - 1)) * arc_length_rad
					var pos = band_start.rotated(band_axis, step_angle)
					
					var paintball = PaintBallData.new(
						affected_ballz[randi() % affected_ballz.size()],
						paintball_size, pos, current_color,
						outline_color_list[randi() % outline_color_list.size()],
						floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
						rand_range(properties.fuzz_min, properties.fuzz_max),
						0, # z_add
						texture_list[randi() % texture_list.size()],
						1 if properties.anchored else 0,
						properties.group
					)
					paintballz.append(paintball)
	else:
		for i in range(properties.num_spots):
			var ball_index = affected_ballz[randi() % affected_ballz.size()]
			var size = rand_range(properties.size_min, properties.size_max)
			var color = color_list[randi() % color_list.size()]
			var outline_color = outline_color_list[randi() % outline_color_list.size()]
			var outline_type = floor(rand_range(properties.outline_type_min, properties.outline_type_max))
			var fuzz = floor(rand_range(properties.fuzz_min, properties.fuzz_max))
			var texture = texture_list[randi() % texture_list.size()]
			var group = properties.group

			var position = Vector3()

			if distribution_mode == 0: # Uniform
				position = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			elif distribution_mode == 1: # Spiral
				var turns = properties.spiral_turns
				var angle = i * (2 * PI * turns / properties.num_spots)
				var y = lerp(-1, 1, float(i) / properties.num_spots)
				var r = sqrt(1 - y*y)
				var x = r * cos(angle)
				var z = r * sin(angle)
				position = Vector3(x, y, z)
			elif distribution_mode == 3: # Horizontal Bands
				var num_bands = properties.num_bands
				if num_bands > 0:
					var band_index = floor(i * num_bands / properties.num_spots)
					var y = lerp(-0.8, 0.8, float(band_index) / max(1, num_bands - 1))
					var angle = rand_range(0, TAU)
					var r = sqrt(max(0, 1.0 - y*y))
					var x = r * cos(angle)
					var z = r * sin(angle)
					position = Vector3(x, y, z)
			elif distribution_mode == 4: # Vertical Bands
				var num_bands = properties.num_bands
				if num_bands > 0:
					var band_index = floor(i * num_bands / properties.num_spots)
					var angle = lerp(0, TAU, float(band_index) / max(1, num_bands - 1))
					var y = rand_range(-0.8, 0.8)
					var r = sqrt(max(0, 1.0 - y*y))
					var x = r * cos(angle)
					var z = r * sin(angle)
					position = Vector3(x, y, z)
			elif distribution_mode == 5: # Grid
				var grid_size = properties.grid_size
				if grid_size > 0:
					var u = float(i % int(grid_size)) / grid_size
					var v = float(floor(i / grid_size)) / grid_size
					var theta = u * 2 * PI
					var acos_arg = clamp(2 * v - 1, -1.0, 1.0)
					var phi = acos(acos_arg)
					var x = sin(phi) * cos(theta)
					var y = sin(phi) * sin(theta)
					var z = cos(phi)
					position = Vector3(x, y, z)
			elif distribution_mode == 6: # Checkerboard
				var grid_size = int(properties.grid_size)
				if grid_size > 0 and properties.num_spots > 0:
					var num_on_squares = ceil(grid_size * grid_size / 2.0)
					var spots_per_square = int(ceil(properties.num_spots / num_on_squares))

					for v_idx in range(grid_size):
						for u_idx in range(grid_size):
							if (u_idx + v_idx) % 2 == 1:
								for _j in range(spots_per_square):
									var u_start = float(u_idx) / grid_size
									var u_end = float(u_idx + 1) / grid_size
									var v_start = float(v_idx) / grid_size
									var v_end = float(v_idx + 1) / grid_size

									var rand_u = rand_range(u_start, u_end)
									var rand_v = rand_range(v_start, v_end)

									var theta = rand_u * TAU
									var cos_phi = lerp(1.0, -1.0, rand_v)
									var phi = acos(cos_phi)
									
									var x = sin(phi) * cos(theta)
									var z = sin(phi) * sin(theta)
									var y = cos(phi)
									
									var p_ball_index = affected_ballz[randi() % affected_ballz.size()]
									var p_size = rand_range(properties.size_min, properties.size_max)
									var p_color = color_list[randi() % color_list.size()]
									var p_outline_color = outline_color_list[randi() % outline_color_list.size()]
									var p_outline_type = floor(rand_range(properties.outline_type_min, properties.outline_type_max))
									var p_fuzz = floor(rand_range(properties.fuzz_min, properties.fuzz_max))
									var p_texture = texture_list[randi() % texture_list.size()]
									var p_group = properties.group
									
									var p = PaintBallData.new(
										p_ball_index, p_size, Vector3(x,y,z), p_color, p_outline_color,
										p_outline_type, p_fuzz, 0, p_texture, 1 if properties.anchored else 0, p_group
									)
									paintballz.append(p)
					continue 
			elif distribution_mode == 7: # Random Walk
				if i == 0 or paintballz.size() == 0:
					position = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
				else:
					var last_pos = paintballz[paintballz.size() - 1].position
					var offset = Vector3(rand_range(-0.2, 0.2), rand_range(-0.2, 0.2), rand_range(-0.2, 0.2))
					position = (last_pos + offset).normalized()
			elif distribution_mode == 8: # Clustered
				var num_clusters = properties.num_clusters
				if num_clusters > 0:
					var cluster_size = properties.num_spots / num_clusters
					if cluster_size > 0 and i % int(cluster_size) == 0:
						cluster_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
					var offset = Vector3(rand_range(-0.3, 0.3), rand_range(-0.3, 0.3), rand_range(-0.3, 0.3))
					position = (cluster_center + offset).normalized()
			elif distribution_mode == 9: # Pole-Focused
				var y = 1.0 - pow(randf(), 2)
				if randf() > 0.5:
					y = -y
				var angle = rand_range(0, 2 * PI)
				var r = sqrt(1 - y*y)
				var x = r * cos(angle)
				var z = r * sin(angle)
				position = Vector3(x, y, z)
			elif distribution_mode == 10: # Equator-Focused
				var y = rand_range(-0.2, 0.2)
				var angle = rand_range(0, 2 * PI)
				var r = sqrt(1 - y*y)
				var x = r * cos(angle)
				var z = r * sin(angle)
				position = Vector3(x, y, z)
			elif distribution_mode == 11: # Halfie
				var axis = properties.halfie_axis
				var side = properties.halfie_side
				var p = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
				if side == 0: # Positive
					p[axis] = abs(p[axis])
				else: # Negative
					p[axis] = -abs(p[axis])
				position = p.normalized()

			var paintball = PaintBallData.new(
				ball_index,
				size,
				position,
				color,
				outline_color,
				outline_type,
				fuzz,
				0, # z_add
				texture,
				1 if properties.anchored else 0,
				group
			)
			paintballz.append(paintball)

	emit_signal("randomize_auto_paintballz", paintballz)

func _parse_number_list(s, allow_negatives=false):
	var list = []
	var parts = s.split(",", false)
	for part in parts:
		part = part.strip_edges()
		if "-" in part:
			if part.rfind("-") > 0:
				var range_parts = part.split("-")
				if range_parts.size() == 2:
					var start = range_parts[0].to_int()
					var end = range_parts[1].to_int()
					for i in range(start, end + 1):
						list.append(i)
			elif allow_negatives and part.is_valid_integer():
				list.append(part.to_int())
		elif part.is_valid_integer():
			list.append(part.to_int())
	return list
func _on_ApplyButton_pressed():
	emit_signal("apply_auto_paintballz")

func _on_ClearButton_pressed():
	emit_signal("clear_auto_paintballz")

func show():
	$Panel.show()

func hide():
	$Panel.hide()

func _get_basis_from_normal(normal_vec):
	var basis_y = normal_vec.normalized()
	var cross_vec = Vector3.UP.cross(basis_y)

	if cross_vec.length_squared() < 0.0001:
		cross_vec = Vector3.RIGHT.cross(basis_y)
	
	var basis_x = cross_vec.normalized()
	var basis_z = basis_y.cross(basis_x).normalized()
	
	return Basis(basis_x, basis_y, basis_z)

func get_properties():
	var properties = {}
	properties["affected_ballz"] = find_node("AffectedBallz").text
	properties["distribution"] = find_node("Distribution").selected
	properties["num_spots"] = find_node("NumSpots").value
	properties["spiral_turns"] = find_node("SpiralTurns").value
	properties["star_points"] = find_node("StarPoints").value
	properties["star_point_size"] = find_node("StarPointSize").value
	properties["num_bands"] = find_node("NumBands").value
	properties["grid_size"] = find_node("GridSize").value
	properties["num_clusters"] = find_node("NumClusters").value
	properties["ray_length"] = find_node("RayLength").value
	properties["stripe_frequency"] = find_node("StripeFrequency").value
	properties["stripe_scale"] = find_node("StripeScale").value
	properties["stripe_distortion"] = find_node("StripeDistortion").value
	properties["stripe_thickness"] = find_node("StripeThickness").value
	properties["leopard_radius_min"] = find_node("LeopardRadiusMin").value
	properties["leopard_radius_max"] = find_node("LeopardRadiusMax").value
	properties["leopard_irregularity"] = find_node("LeopardIrregularity").value
	properties["leopard_completeness"] = find_node("LeopardCompleteness").value
	properties["leopard_completeness"] = find_node("LeopardCompleteness").value
	properties["leopard_use_paired_colors"] = find_node("LeopardPairedColors").pressed
	properties["rainbow_angle"] = find_node("RainbowAngle").value
	properties["rainbow_curvature"] = find_node("RainbowCurvature").value
	properties["rainbow_width"] = find_node("RainbowWidth").value
	properties["rainbow_length"] = find_node("RainbowLength").value
	properties["halfie_axis"] = find_node("HalfieAxis").selected
	properties["halfie_axis"] = find_node("HalfieAxis").selected
	properties["halfie_side"] = find_node("HalfieSide").selected
	properties["num_rings"] = find_node("NumRings").value
	properties["size_min"] = find_node("SizeMin").value
	properties["size_max"] = find_node("SizeMax").value
	properties["color_list"] = find_node("ColorList").text
	properties["outline_color_list"] = find_node("OutlineColorList").text
	properties["outline_type_min"] = find_node("OutlineTypeMin").value
	properties["outline_type_max"] = find_node("OutlineTypeMax").value
	properties["fuzz_min"] = find_node("FuzzMin").value
	properties["fuzz_max"] = find_node("FuzzMax").value
	properties["texture_list"] = find_node("TextureList").text
	properties["group"] = find_node("Group").value
	properties["anchored"] = find_node("Anchored").pressed
	return properties