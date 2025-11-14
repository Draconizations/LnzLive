extends CanvasLayer
## AutoPaintballerSettings.gd
## Manages panel UI and logic for the Auto Paintballer tool
## This script controls procedural generation of paintballz
## 1. Gathers all selected properties
## 2. Generates a list of `PaintBallData` objects
## 3. Emits `randomize_auto_paintballz` signal for the `dog_generator` to queue and display
## 4. Commits to applying and clearing of queued paintballz

enum Distribution {
	UNIFORM,            # 00
	SPIRAL,             # 01
	STAR,               # 02
	BANDS,              # 03
	NOISE_FIELD,        # 04
	GRID,               # 05
	CHECKERBOARD,       # 06
	RANDOM_WALK,        # 07
	CLUSTERED,          # 08
	POLE_FOCUSED,       # 09
	EQUATOR_FOCUSED,    # 10
	HALFIE,             # 11
	BULLSEYE,           # 12
	LEOPARD,            # 13
	RAINBOW,            # 14
	STRIPES,            # 15
	FRACTAL,            # 16
	VORONOI,            # 17
	WAVE                # 18
}

enum FractalPreset { CUSTOM, DRAGON_CURVE, SIERPINSKI, BARNSLEY_FERN }

const ALLOWED_FRACTAL_CHARS = "FGABX+-[]"

signal randomize_auto_paintballz(paintballz)

signal apply_auto_paintballz

signal clear_auto_paintballz

onready var params_container = find_node("ParamsContainer")

var _ordered_color_index = 0
var _ordered_outline_color_index = 0
var _ordered_texture_index = 0
var _ordered_ball_index = 0

func _ready():
	find_node("RandomizeButton").connect("pressed", self, "_on_RandomizeButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("Distribution").connect("item_selected", self, "_on_Distribution_item_selected")
	find_node("UseSeed").connect("toggled", self, "_on_UseSeed_toggled")

	find_node("FractalPreset").connect("item_selected", self, "_on_FractalPreset_item_selected")
	find_node("FractalAxiom").connect("text_changed", self, "_on_FractalAxiom_text_changed")

	find_node("RandomSystemButton").connect("pressed", self, "_on_RandomSystemButton_pressed")
	
	get_viewport().connect("size_changed", self, "_on_viewport_size_changed")
	_on_viewport_size_changed()
	_on_Distribution_item_selected(0)

	_on_FractalPreset_item_selected(find_node("FractalPreset").selected)


func _on_UseSeed_toggled(button_pressed):
	var seed_edit = find_node("Seed")
	seed_edit.editable = button_pressed

func _on_RandomSystemButton_pressed():
	var axiom_edit = find_node("FractalAxiom")
	var rules_edit = find_node("FractalRules")
	var angle_edit = find_node("FractalAngle")
	
	var random_system = _generate_random_lsystem()
	axiom_edit.text = random_system.axiom
	rules_edit.text = random_system.rules_text
	angle_edit.value = [30, 45, 60, 90, 120][randi() % 5]

func _on_FractalPreset_item_selected(index):
	var axiom_edit = find_node("FractalAxiom")
	var rules_edit = find_node("FractalRules")
	var angle_edit = find_node("FractalAngle")
	var random_button = find_node("RandomSystemButton")

	axiom_edit.editable = false
	rules_edit.readonly = true
	random_button.hide()
	
	match index:
		FractalPreset.DRAGON_CURVE:
			axiom_edit.text = "F"
			rules_edit.text = "F=F+G\nG=F-G"
			angle_edit.value = 90.0
		FractalPreset.SIERPINSKI:
			axiom_edit.text = "A"
			rules_edit.text = "A=B-A-B\nB=A+B+A"
			angle_edit.value = 60.0
		FractalPreset.BARNSLEY_FERN:
			axiom_edit.text = "X"
			rules_edit.text = "X=F+[[X]-X]-F[-FX]+X\nF=FF"
			angle_edit.value = 25.0
		FractalPreset.CUSTOM:
			axiom_edit.editable = true
			rules_edit.readonly = false
			random_button.show()
			pass

func _on_FractalAxiom_text_changed(new_text: String):
	var axiom_edit = find_node("FractalAxiom")
	var sanitized_text = ""
	
	for current_char in new_text:
		if ALLOWED_FRACTAL_CHARS.find(current_char) != -1:
			sanitized_text += current_char
			
	if sanitized_text != new_text:
		var cursor_pos = axiom_edit.caret_position
		axiom_edit.text = sanitized_text
		axiom_edit.caret_position = min(cursor_pos, sanitized_text.length())

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

	var description_label = find_node("DescriptionLabel")
	var description = ""

	match index:
		Distribution.UNIFORM:
			description = "Randomly places spots over ballz."
		Distribution.SPIRAL:
			description = "Arranges spots in a spiral pattern."
		Distribution.STAR:
			description = "Creates star-shaped patterns. 'Spots' is the number of stars. 'Point Count' and 'Ray Length' control the shape."
		Distribution.BANDS: # 03: Consolidated Bands
			description = "Creates bands of spots. 'Bands' controls the number of bands. Use 'Direction' to choose horizontal or vertical alignment."
		Distribution.NOISE_FIELD: # 04: Noise
			description = "Places spots organically based on simplex noise."
		Distribution.GRID: # 05
			description = "Arranges spots in a grid. 'Grid Size' controls the density."
		Distribution.CHECKERBOARD: # 06
			description = "Arranges spots in a checkerboard pattern. 'Grid Size' controls the density."
		Distribution.RANDOM_WALK: # 07
			description = "Creates a meandering path of spots."
		Distribution.CLUSTERED: # 08
			description = "Groups spots into clusters. 'Clusters' controls the number of groups."
		Distribution.POLE_FOCUSED: # 09
			description = "Concentrates spots around the top and bottom of ballz."
		Distribution.EQUATOR_FOCUSED: # 10
			description = "Concentrates spots around the equator of ballz."
		Distribution.HALFIE: # 11
			description = "Restricts spots to one half of the surface. 'Axis' and 'Side' control which half."
		Distribution.BULLSEYE: # 12
			description = "Creates bullseye patterns. 'Spots' is the number of bullseyes. 'Rings' controls the number of rings in each."
		Distribution.LEOPARD: # 13
			description = "Creates leopard-like spots. 'Spots' is the number of leopard spots. Parameters control the shape and completeness of the spots."
		Distribution.RAINBOW: # 14
			description = "Creates rainbow arcs. 'Spots' is the number of rainbows. Parameters control the shape of the arcs."
		Distribution.STRIPES: # 15
			description = "Generates natural Turing patterns like stripes and blotches using Gray-Scott reaction-diffusion. Feed/Kill rates determine density and Diffusion controls feature size."
		Distribution.FRACTAL: # 16
			description = "Generates fractal patterns using an L-system."
		Distribution.VORONOI: # 17: Voronoi
			description = "Creates patterns based on cellular boundaries. 'Cells' controls the density of the pattern, and 'Edge Size' controls the thickness of the lines."
		Distribution.WAVE: # 18: Wave
			description = "Generates wave-like or banded patterns using spherical harmonics. 'Degree (L)' controls vertical frequency and 'Order (M)' controls horizontal frequency."


	description_label.bbcode_text = description

	match index:
		Distribution.SPIRAL: # 1
			params_container.get_node("SpiralTurnsContainer").show()
		Distribution.STAR: # 2
			params_container.get_node("StarPointsContainer").show()
			params_container.get_node("RayLengthContainer").show()
		Distribution.BANDS: # 3: Consolidated Bands
			params_container.get_node("BandsContainer").show()
		Distribution.NOISE_FIELD: # 4: Noise
			params_container.get_node("NoiseContainer").show()
		Distribution.GRID, Distribution.CHECKERBOARD: # 5, 6
			params_container.get_node("GridSizeContainer").show()
		Distribution.CLUSTERED: # 8
			params_container.get_node("NumClustersContainer").show()
		Distribution.HALFIE: # 11
			params_container.get_node("HalfieContainer").show()
		Distribution.BULLSEYE: # 12
			params_container.get_node("BullseyeContainer").show()
		Distribution.LEOPARD: # 13
			params_container.get_node("LeopardContainer").show()
		Distribution.RAINBOW: # 14
			params_container.get_node("RainbowContainer").show()
		Distribution.STRIPES: # 15
			params_container.get_node("StripesContainer").show()
		Distribution.FRACTAL: # 16
			params_container.get_node("FractalContainer").show()
		Distribution.VORONOI: # 17: New Voronoi
			params_container.get_node("VoronoiContainer").show()
		Distribution.WAVE: # 18: New Wave
			params_container.get_node("WaveContainer").show()


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
		push_warning("Could not parse [Texture List] so using default.")
		texture_list.append(-1)
	elif texture_list.empty():
		texture_list.append(-1)

	var paintballz = []
	var distribution_mode = properties.distribution

	var seed_edit = find_node("Seed")
	if properties.use_seed:
		if properties.seed.is_valid_integer():
			seed(int(properties.seed))
		else:
			push_warning("Invalid seed value. Using a random seed.")
			seed(OS.get_ticks_usec())
	else:
		var new_seed = OS.get_ticks_usec()
		seed(new_seed)
		seed_edit.text = str(new_seed)

	_ordered_color_index = 0
	_ordered_outline_color_index = 0
	_ordered_texture_index = 0
	_ordered_ball_index = 0

	match distribution_mode:
		Distribution.FRACTAL: # 16
			paintballz = _generate_fractal_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
		Distribution.NOISE_FIELD: # 04: Noise 
			paintballz = _generate_noise_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
		Distribution.VORONOI: # 17: Voronoi
			paintballz = _generate_voronoi_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
		Distribution.WAVE: # 18: New Wave (Spherical Harmonics)
			paintballz = _generate_wave_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
		Distribution.RANDOM_WALK: # 7
			for ball_index in affected_ballz:

				var num_spots_per_ball = int(properties.num_spots) / int(affected_ballz.size())
				var spots_remainder = int(properties.num_spots) % int(affected_ballz.size())
				
				if ball_index == affected_ballz.back():
					num_spots_per_ball += spots_remainder
				
				var last_pos = Vector3()
				
				for i in range(num_spots_per_ball):
					var position = Vector3()
					if i == 0:
						position = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
					else:
						var offset = Vector3(rand_range(-0.2, 0.2), rand_range(-0.2, 0.2), rand_range(-0.2, 0.2))
						position = (last_pos + offset).normalized()
					
					var size = rand_range(properties.size_min, properties.size_max)

					var paintball = _create_paintball(
						position, size, properties, affected_ballz, color_list, outline_color_list, texture_list
					)
					paintballz.append(paintball)
					last_pos = position
		Distribution.CLUSTERED: # 8
			for ball_index in affected_ballz:
				var cluster_center = Vector3()
				
				var num_spots_per_ball = int(properties.num_spots) / int(affected_ballz.size())
				var spots_remainder = int(properties.num_spots) % int(affected_ballz.size())
				
				if ball_index == affected_ballz.back():
					num_spots_per_ball += spots_remainder
				
				for i in range(num_spots_per_ball):
					var num_clusters = properties.num_clusters
					if num_clusters > 0:
						var cluster_size = num_spots_per_ball / num_clusters
						if cluster_size > 0 and i % int(cluster_size) == 0:
							cluster_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
						var offset = Vector3(rand_range(-0.3, 0.3), rand_range(-0.3, 0.3), rand_range(-0.3, 0.3))
						var position = (cluster_center + offset).normalized()

						var size = rand_range(properties.size_min, properties.size_max)
						
						var paintball = _create_paintball(
							position, size, properties, affected_ballz, color_list, outline_color_list, texture_list
						)
						paintballz.append(paintball)
		Distribution.STAR: # 2
			var num_stars = properties.num_spots
			var num_points = int(properties.star_points)
			var point_size = int(properties.star_point_size)
			var ray_length = properties.ray_length

			if num_points <= 1 or ray_length <= 0:
				return

			for i in range(num_stars):
				var star_color
				var star_outline_color
				if properties.ordered:
					star_color = color_list[_ordered_color_index % color_list.size()]
					_ordered_color_index += 1
					star_outline_color = outline_color_list[_ordered_outline_color_index % outline_color_list.size()]
					_ordered_outline_color_index += 1
				else:
					star_color = color_list[randi() % color_list.size()]
					star_outline_color = outline_color_list[randi() % outline_color_list.size()]
				
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

						var paintball = _create_paintball(
							pos.normalized(), final_size, properties, affected_ballz, [star_color], [star_outline_color], texture_list
						)
						paintballz.append(paintball)
		Distribution.BULLSEYE: # 12
			var num_targets = properties.num_spots
			var num_rings = properties.num_rings
			
			if num_rings <= 0 or color_list.size() == 0:
				return

			for i in range(num_targets):
				var target_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
				var start_size = rand_range(properties.size_min, properties.size_max)

				for r in range(num_rings):
					var ring_size = start_size * (1.0 - float(r) / num_rings)
					var ring_color = color_list[r % color_list.size()]
					
					var paintball = _create_paintball(
						target_center, ring_size, properties, affected_ballz, [ring_color], outline_color_list, texture_list
					)
					paintballz.append(paintball)
		Distribution.STRIPES: # 15
			var feed_rate = properties.stripe_feed_rate
			var kill_rate = properties.stripe_kill_rate
			var diffusion_rate = properties.stripe_diffusion
			var timestep = properties.stripe_timestep

			var grid_size = 32
			var grid = []
			grid.resize(grid_size * grid_size)
			for i in range(grid_size * grid_size):
				grid[i] = {"a": 1.0, "b": 0.0}

			var center = grid_size / 2
			grid[center * grid_size + center].b = 1.0

			for time in range(100):
				var next_grid = []
				next_grid.resize(grid_size * grid_size)
				for i in range(grid_size * grid_size):
					next_grid[i] = grid[i].duplicate()

				for x in range(1, grid_size - 1):
					for y in range(1, grid_size - 1):
						var i = y * grid_size + x
						var a = grid[i].a
						var b = grid[i].b

						var laplace_a = (grid[i-1].a + grid[i+1].a + grid[i-grid_size].a + grid[i+grid_size].a) - 4 * a
						var laplace_b = (grid[i-1].b + grid[i+1].b + grid[i-grid_size].b + grid[i+grid_size].b) - 4 * b

						var reaction = a * b * b
						var next_a = a + (diffusion_rate * laplace_a - reaction + feed_rate * (1.0 - a)) * timestep
						var next_b = b + (0.5 * diffusion_rate * laplace_b + reaction - (kill_rate + feed_rate) * b) * timestep

						next_grid[i].a = clamp(next_a, 0, 1)
						next_grid[i].b = clamp(next_b, 0, 1)
				grid = next_grid

			for i in range(properties.num_spots):
				var u = randf()
				var v = randf()
				
				var grid_x = int(u * (grid_size - 1))
				var grid_y = int(v * (grid_size - 1))
				
				var cell = grid[grid_y * grid_size + grid_x]

				if cell.b > 0.5:
					var theta = u * 2 * PI
					var phi = acos(clamp(2 * v - 1, -1.0, 1.0))
					var x = sin(phi) * cos(theta)
					var y = sin(phi) * sin(theta)
					var z = cos(phi)
					var pos = Vector3(x,y,z)

					var size = rand_range(properties.size_min, properties.size_max)
					
					var paintball = _create_paintball(
						pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
					)
					paintballz.append(paintball)
		Distribution.LEOPARD: # 13
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

						var paintball = _create_paintball(
							pos, paintball_size, properties, affected_ballz, [color_outline], outline_color_list, texture_list
						)
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
						
						var paintball = _create_paintball(
							pos, paintball_size, properties, affected_ballz, [color_fill], outline_color_list, texture_list
						)
						paintballz.append(paintball)

					var inner_dots = randi() % 3 + 1
					for j in range(inner_dots):
						var random_radius = randf() * spot_angle_rad * 0.7
						var random_angle = rand_range(0, TAU)

						var direction = (basis.x * cos(random_angle) + basis.z * sin(random_angle))
						var pos = spot_center.slerp(spot_center + direction.normalized(), random_radius)

						var paintball = _create_paintball(
							pos, paintball_size * 0.6, properties, affected_ballz, [color_outline], outline_color_list, texture_list
						)
						paintballz.append(paintball)
		Distribution.RAINBOW: # 14
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
						
						var paintball = _create_paintball(
							pos, paintball_size, properties, affected_ballz, [current_color], outline_color_list, texture_list
						)
						paintballz.append(paintball)
		_: # All other simple modes (UNIFORM, SPIRAL, BANDS, GRID, CHECKERBOARD, FOCUSED, HALFIE)
			for i in range(properties.num_spots):
				var size = rand_range(properties.size_min, properties.size_max)
				var position = Vector3()

				if distribution_mode == Distribution.UNIFORM: # 0
					position = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
				elif distribution_mode == Distribution.SPIRAL: # 1
					var turns = properties.spiral_turns
					var angle = i * (2 * PI * turns / properties.num_spots)
					var y = lerp(-1, 1, float(i) / properties.num_spots)
					var r = sqrt(1 - y*y)
					var x = r * cos(angle)
					var z = r * sin(angle)
					position = Vector3(x, y, z)
				elif distribution_mode == Distribution.BANDS: # 3: Consolidated Bands
					var num_bands = properties.num_bands
					if num_bands > 0:
						var band_angle = deg2rad(properties.band_angle)
						var band_offset = properties.band_offset
						var band_spacing = properties.band_spacing
						var is_vertical = properties.band_direction == 1 # 0=Horizontal, 1=Vertical

						var band_index = floor(i * num_bands / properties.num_spots)
						var total_width = (num_bands - 1) * band_spacing
						var band_pos = lerp(-total_width / 2.0, total_width / 2.0, float(band_index) / max(1, num_bands - 1))

						band_pos += band_offset

						var y = band_pos
						var angle = rand_range(0, TAU)
						var r = sqrt(max(0, 1.0 - y*y))
						var x = r * cos(angle)
						var z = r * sin(angle)

						var p = Vector3(x, y, z)

						if is_vertical:
							p = Vector3(y, x, z) # Swap coordinates for vertical alignment

						p = p.rotated(Vector3.FORWARD, band_angle)
						position = p
				elif distribution_mode == Distribution.GRID: # 5
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
				elif distribution_mode == Distribution.CHECKERBOARD: # 6
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
										
										var p = _create_paintball(
											Vector3(x,y,z), size, properties, affected_ballz, color_list, outline_color_list, texture_list
										)
										paintballz.append(p)
						continue 
				elif distribution_mode == Distribution.POLE_FOCUSED: # 9
					var y = 1.0 - pow(randf(), 2)
					if randf() > 0.5:
						y = -y
					var angle = rand_range(0, 2 * PI)
					var r = sqrt(1 - y*y)
					var x = r * cos(angle)
					var z = r * sin(angle)
					position = Vector3(x, y, z)
				elif distribution_mode == Distribution.EQUATOR_FOCUSED: # 10
					var y = rand_range(-0.2, 0.2)
					var angle = rand_range(0, 2 * PI)
					var r = sqrt(1 - y*y)
					var x = r * cos(angle)
					var z = r * sin(angle)
					position = Vector3(x, y, z)
				elif distribution_mode == Distribution.HALFIE: # 11
					var axis = properties.halfie_axis
					var side = properties.halfie_side
					var p = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
					if side == 0: # Positive
						p[axis] = abs(p[axis])
					else: # Negative
						p[axis] = -abs(p[axis])
					position = p.normalized()

				var paintball = _create_paintball(
					position, size, properties, affected_ballz, color_list, outline_color_list, texture_list
				)
				paintballz.append(paintball)

	emit_signal("randomize_auto_paintballz", paintballz)

func _create_paintball(pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list):
	var ball_no
	var color
	var outline_color
	var texture

	if properties.ordered:
		ball_no = affected_ballz[_ordered_ball_index % affected_ballz.size()]
		_ordered_ball_index += 1
		color = color_list[_ordered_color_index % color_list.size()]
		_ordered_color_index += 1
		outline_color = outline_color_list[_ordered_outline_color_index % outline_color_list.size()]
		_ordered_outline_color_index += 1
		texture = texture_list[_ordered_texture_index % texture_list.size()]
		_ordered_texture_index += 1
	else:
		ball_no = affected_ballz[randi() % affected_ballz.size()]
		color = color_list[randi() % color_list.size()]
		outline_color = outline_color_list[randi() % outline_color_list.size()]
		texture = texture_list[randi() % texture_list.size()]

	return PaintBallData.new(
		ball_no,
		size,
		pos,
		color,
		outline_color,
		floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
		floor(rand_range(properties.fuzz_min, properties.fuzz_max)),
		0, # z_add
		texture,
		1 if properties.anchored else 0,
		properties.group
	)

# 17: Voronoi / Cell Pattern Generator
func _generate_voronoi_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
	var paintballz = []
	var num_cells = int(properties.voronoi_cells)
	var edge_size = properties.voronoi_edge_size
	
	if num_cells < 2: return []
	
	var cell_centers = []
	for i in range(num_cells):
		cell_centers.append(Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized())

	for i in range(properties.num_spots * 2): # Try twice as many random points to find spots on edges
		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		
		# 1. Find the two closest cell centers to 'pos'
		var closest_centers = []
		for center in cell_centers:
			closest_centers.append({"center": center, "dist_sq": pos.distance_squared_to(center)})
		
		closest_centers.sort_custom(self, "_sort_by_dist_sq")
		
		var D1_sq = closest_centers[0].dist_sq
		var D2_sq = closest_centers[1].dist_sq
		
		# Edge Condition: Small difference between D1 and D2 means the point is near the boundary.
		var center_dist_diff = abs(D1_sq - D2_sq)
		
		# Normalize difference
		var edge_value = center_dist_diff / max(0.001, D1_sq + D2_sq)
		
		# Place spot if close to the boundary defined by edge_size
		if edge_value < edge_size: 
			var size = rand_range(properties.size_min, properties.size_max)
			
			var paintball = _create_paintball(
				pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
			)
			paintballz.append(paintball)
			
			if paintballz.size() >= properties.num_spots:
				break
			
	return paintballz
	
func _sort_by_dist_sq(a, b):
	return a.dist_sq < b.dist_sq

# 18: Wave (Spherical Harmonics) Generator
func _generate_wave_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
	var paintballz = []
	var L = int(properties.wave_degree_l) # Degree (Vertical Frequency)
	var M = int(properties.wave_order_m)  # Order (Horizontal Frequency)
	var threshold = properties.wave_threshold
	
	# Clamp M to L
	M = min(M, L) 
	
	if L < 0 or M < 0: return []
	
	for i in range(properties.num_spots * 2): # Try twice as many random points
		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		
		var x = pos.x
		var y = pos.y
		var z = pos.z
		
		# Spherical Coordinates:
		var cos_theta = clamp(y, -1.0, 1.0) # Cosine of the polar angle (elevation)
		var sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta))
		var phi = atan2(z, x) # Azimuthal angle (longitude)
		
		var P_lm = 0.0 # Associated Legendre Polynomial P_l^m(cos(theta))
		
		# --- Associated Legendre Polynomial P_l^m(x) (Limited to L=3 for practical implementation) ---
		if L == 0:
			P_lm = 1.0
		elif L == 1:
			if M == 0: P_lm = cos_theta
			elif M == 1: P_lm = sin_theta
		elif L == 2:
			if M == 0: P_lm = 0.5 * (3.0 * cos_theta * cos_theta - 1.0)
			elif M == 1: P_lm = 3.0 * cos_theta * sin_theta
			elif M == 2: P_lm = 3.0 * sin_theta * sin_theta
		elif L == 3:
			if M == 0: P_lm = 0.5 * (5.0 * pow(cos_theta, 3) - 3.0 * cos_theta)
			elif M == 1: P_lm = 1.5 * (5.0 * cos_theta * cos_theta - 1.0) * sin_theta
			elif M == 2: P_lm = 15.0 * cos_theta * sin_theta * sin_theta
			elif M == 3: P_lm = 15.0 * pow(sin_theta, 3)
		else: # For L > 3, we default to the highest implemented value to avoid math complexity
			L = 3
			M = min(M, L)
			
		# The Real Spherical Harmonic is proportional to P_l^m(cos(theta)) * cos(m * phi)
		var Y_lm = P_lm * cos(M * phi)
		
		# Map value Y_lm (typically [-1, 1]) to [0, 1] density
		var density = (Y_lm + 1.0) / 2.0
		
		if density > threshold:
			var size = rand_range(properties.size_min, properties.size_max)
			
			var paintball = _create_paintball(
				pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
			)
			paintballz.append(paintball)
			
			if paintballz.size() >= properties.num_spots:
				break

	return paintballz

# 04: Noise Field Generator
func _generate_noise_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
	var paintballz = []
	var noise = OpenSimplexNoise.new()
	
	# Use parameters from UI
	noise.seed = randi()
	noise.period = properties.noise_scale
	noise.octaves = int(properties.noise_octaves)
	var threshold = properties.noise_threshold
	
	for i in range(properties.num_spots * 2): # Try twice as many random points to find spots above threshold
		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		
		# Get 3D noise value
		var noise_value = noise.get_noise_3d(pos.x, pos.y, pos.z)
		
		# Normalize noise from [-1, 1] to [0, 1]
		var density = (noise_value + 1.0) / 2.0
		
		if density > threshold:
			var size = rand_range(properties.size_min, properties.size_max)
			
			var paintball = _create_paintball(
				pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
			)
			paintballz.append(paintball)
			
			if paintballz.size() >= properties.num_spots:
				break
				
	return paintballz


# --- Existing Helper Functions (Trimmed) ---

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

func _generate_fractal_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
	var paintballz = []
	var axiom = ""
	var rules = {}

	match properties.fractal_preset:
		FractalPreset.DRAGON_CURVE:
			axiom = "F"
			rules = {"F": "F+G", "G": "F-G"}
		FractalPreset.SIERPINSKI:
			axiom = "A"
			rules = {"A": "B-A-B", "B": "A+B+A"}
		FractalPreset.BARNSLEY_FERN:
			axiom = "X"
			rules = {"X": "F+[[X]-X]-F[-FX]+X", "F": "FF"}
		_: # Default to Custom
			axiom = properties.fractal_axiom
			rules = _parse_lsystem_rules(properties.fractal_rules)
	
	if axiom.empty() or rules.empty():
		push_warning("Fractal generation failed: Axiom or Rules are not defined.")
		return []

	var fractal_string = _generate_lsystem_string(axiom, rules, properties.fractal_iterations)
	
	var start_pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	if start_pos.length_squared() == 0: start_pos = Vector3.FORWARD
	
	var basis = _get_basis_from_normal(start_pos)
	var turtle_state = {"pos": start_pos, "heading": basis.x}
	var state_stack = []

	var paintball_size = rand_range(properties.size_min, properties.size_max)
	var step_angle_rad = atan(paintball_size * 0.02) * 0.9

	for command in fractal_string:
		match command:
			"F", "G", "A", "B": # Draw forward
				var move_axis = turtle_state.heading.cross(turtle_state.pos).normalized()
				if move_axis.length_squared() > 0:
					turtle_state.pos = turtle_state.pos.rotated(move_axis, step_angle_rad)
					turtle_state.heading = turtle_state.heading.rotated(move_axis, step_angle_rad)
					
					var paintball = _create_paintball(
						turtle_state.pos,
						paintball_size,
						properties, affected_ballz, color_list, outline_color_list, texture_list
					)
					paintballz.append(paintball)
			"+": # Turn Right
				var turn_axis = turtle_state.pos
				turtle_state.heading = turtle_state.heading.rotated(turn_axis, deg2rad(-properties.fractal_angle))
			"-": # Turn Left
				var turn_axis = turtle_state.pos
				turtle_state.heading = turtle_state.heading.rotated(turn_axis, deg2rad(properties.fractal_angle))
			"[": # Push state
				state_stack.append(turtle_state.duplicate(true))
			"]": # Pop state
				if not state_stack.empty():
					turtle_state = state_stack.pop_back()
	return paintballz

func _parse_lsystem_rules(rules_text: String) -> Dictionary:
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

func _generate_lsystem_string(axiom, rules, iterations):
	var current_string = axiom
	for i in range(iterations):
		var new_string = ""
		for char_idx in range(current_string.length()):
			var current_char = current_string[char_idx]
			if rules.has(current_char):
				new_string += rules[current_char]
			else:
				new_string += current_char
		current_string = new_string
	return current_string

func _generate_random_lsystem() -> Dictionary:
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

func get_properties():
	var properties = {}
	properties["affected_ballz"] = find_node("AffectedBallz").text
	properties["distribution"] = find_node("Distribution").selected
	properties["num_spots"] = find_node("NumSpots").value
	properties["spiral_turns"] = find_node("SpiralTurns").value
	properties["star_points"] = find_node("StarPoints").value
	properties["star_point_size"] = find_node("StarPointSize").value
	# Consolidated Bands
	properties["num_bands"] = find_node("NumBands").value
	properties["band_spacing"] = find_node("BandSpacing").value
	properties["band_offset"] = find_node("BandOffset").value
	properties["band_angle"] = find_node("BandAngle").value
	properties["band_direction"] = find_node("BandDirection").selected # New for Bands
	# New Modes
	properties["noise_scale"] = find_node("NoiseScale").value
	properties["noise_threshold"] = find_node("NoiseThreshold").value
	properties["noise_octaves"] = find_node("NoiseOctaves").value
	properties["voronoi_cells"] = find_node("VoronoiCells").value
	properties["voronoi_edge_size"] = find_node("VoronoiEdgeSize").value
	properties["wave_degree_l"] = find_node("WaveDegreeL").value
	properties["wave_order_m"] = find_node("WaveOrderM").value
	properties["wave_threshold"] = find_node("WaveThreshold").value
	
	properties["grid_size"] = find_node("GridSize").value
	properties["num_clusters"] = find_node("NumClusters").value
	properties["ray_length"] = find_node("RayLength").value
	properties["stripe_feed_rate"] = find_node("StripeFeedRate").value
	properties["stripe_kill_rate"] = find_node("StripeKillRate").value
	properties["stripe_diffusion"] = find_node("StripeDiffusion").value
	properties["stripe_timestep"] = find_node("StripeTimestep").value
	properties["leopard_radius_min"] = find_node("LeopardRadiusMin").value
	properties["leopard_radius_max"] = find_node("LeopardRadiusMax").value
	properties["leopard_irregularity"] = find_node("LeopardIrregularity").value
	properties["leopard_completeness"] = find_node("LeopardCompleteness").value
	properties["leopard_use_paired_colors"] = find_node("LeopardPairedColors").pressed
	properties["rainbow_angle"] = find_node("RainbowAngle").value
	properties["rainbow_curvature"] = find_node("RainbowCurvature").value
	properties["rainbow_width"] = find_node("RainbowWidth").value
	properties["rainbow_length"] = find_node("RainbowLength").value
	properties["fractal_iterations"] = find_node("FractalIterations").value
	properties["fractal_angle"] = find_node("FractalAngle").value
	properties["fractal_preset"] = find_node("FractalPreset").selected
	properties["fractal_axiom"] = find_node("FractalAxiom").text
	properties["fractal_rules"] = find_node("FractalRules").text
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
	properties["ordered"] = find_node("Ordered").pressed
	properties["use_seed"] = find_node("UseSeed").pressed
	properties["seed"] = find_node("Seed").text
	return properties