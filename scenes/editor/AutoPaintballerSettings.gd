extends DraggablePanel
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
signal affected_list_changed(ball_ids)
signal unselect_all

onready var params_container = find_node("ParamsContainer")
onready var pet_node = get_tree().root.get_node("Root/PetRoot/Node")

var _is_loading_settings = false

var _ordered_color_index = 0
var _ordered_outline_color_index = 0
var _ordered_texture_index = 0
var _ordered_ball_index = 0

func _ready():
	var viewport_size = get_viewport().size
	var panel = self
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	
	find_node("RandomizeButton").connect("pressed", self, "_on_RandomizeButton_pressed")
	find_node("AffectedBallz").connect("text_changed", self, "_on_AffectedBallz_text_changed")
	find_node("UnselectButton").connect("pressed", self, "_on_UnselectButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("SurpriseButton").connect("pressed", self, "_on_SurpriseButton_pressed")
	find_node("Distribution").connect("item_selected", self, "_on_Distribution_item_selected")
	find_node("UseSeed").connect("toggled", self, "_on_UseSeed_toggled")

	find_node("FractalPreset").connect("item_selected", self, "_on_FractalPreset_item_selected")
	find_node("FractalAxiom").connect("text_changed", self, "_on_FractalAxiom_text_changed")

	find_node("RandomSystemButton").connect("pressed", self, "_on_RandomSystemButton_pressed")
	
	_on_Distribution_item_selected(0)

	_on_FractalPreset_item_selected(find_node("FractalPreset").selected)

	_connect_settings_signals()
	load_settings()

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

func _on_AffectedBallz_text_changed(new_text):
	var ids = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("affected_list_changed", ids)

func _on_Distribution_item_selected(index):
	for child in params_container.get_children():
		child.hide()

	var description_label = find_node("DescriptionLabel")
	var description = ""

	match index:
		Distribution.UNIFORM: # 00
			description = "Randomly places spots over ballz."
		Distribution.SPIRAL: # 01
			description = "Arranges spots in a spiral pattern."
		Distribution.STAR: # 02
			description = "Creates star-shaped patterns. 'Spots' is the number of stars. 'Point Count' and 'Ray Length' control the shape."
		Distribution.BANDS: # 03
			description = "Creates bands of spots. 'Bands' controls the number of bands. Use 'Direction' to choose horizontal or vertical alignment."
		Distribution.NOISE_FIELD: # 04
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
			description = "Creates leopard-like spots. 'Spots' is the number of leopard spots. Requires at least 2 colors (outer and inner). Parameters control the shape and completeness of the spots."
		Distribution.RAINBOW: # 14
			description = "Creates rainbow arcs. 'Spots' is the number of rainbows. Parameters control the shape of the arcs."
		Distribution.STRIPES: # 15
			description = "Generates natural Turing patterns like stripes and blotches using Gray-Scott reaction-diffusion. Feed/Kill rates determine density and Diffusion controls feature size."
		Distribution.FRACTAL: # 16
			description = "Generates fractal patterns using an L-system."
		Distribution.VORONOI: # 17
			description = "Creates patterns based on cellular boundaries. 'Cells' controls the density of the pattern, and 'Edge Size' controls the thickness of the lines."
		Distribution.WAVE: # 18
			description = "Generates wave-like or banded patterns using spherical harmonics. 'Degree (L)' controls vertical frequency and 'Order (M)' controls horizontal frequency."


	description_label.bbcode_text = description

	match index:
		Distribution.SPIRAL: # 01
			params_container.get_node("SpiralTurnsContainer").show()
		Distribution.STAR: # 02
			params_container.get_node("StarPointsContainer").show()
			params_container.get_node("RayLengthContainer").show()
		Distribution.BANDS: # 03
			params_container.get_node("BandsContainer").show()
		Distribution.NOISE_FIELD: # 04
			params_container.get_node("NoiseContainer").show()
		Distribution.GRID, Distribution.CHECKERBOARD: # 05, 06
			params_container.get_node("GridSizeContainer").show()
		Distribution.CLUSTERED: # 08
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
		Distribution.VORONOI: # 17
			params_container.get_node("VoronoiContainer").show()
		Distribution.WAVE: # 18
			params_container.get_node("WaveContainer").show()


func _on_RandomizeButton_pressed():
	var properties = get_properties()
	var affected_ballz = LnzLiveUtils.parse_number_list(properties.affected_ballz)
	if affected_ballz.empty():
		return

	var color_list = LnzLiveUtils.parse_number_list(properties.color_list)
	if color_list.empty():
		return

	var outline_color_list = LnzLiveUtils.parse_number_list(properties.outline_color_list)
	if outline_color_list.empty():
		return

	var texture_list_str = properties.texture_list
	var texture_list = LnzLiveUtils.parse_number_list(texture_list_str, true) # Allow negatives
	if texture_list.empty() and not texture_list_str.strip_edges().empty():
		push_warning("Could not parse [Texture List] so using default.")
		texture_list.append(-1)
	elif texture_list.empty():
		texture_list.append(-1)

	var paintballz = []
	var distribution_mode = properties.distribution

	var base_seed = int(properties.seed) if (properties.use_seed and properties.seed.is_valid_integer()) else OS.get_ticks_usec()
	if !properties.use_seed: find_node("Seed").text = str(base_seed)

	var global_data = null
	if distribution_mode == Distribution.STRIPES:
		global_data = _calculate_gray_scott_grid(properties)

	for b_idx in range(affected_ballz.size()):
		var current_ball = affected_ballz[b_idx]

		seed(base_seed + (b_idx * 13)) 

		var num_spots = int(properties.num_spots)
		var spots_per_ball = num_spots / affected_ballz.size()
		if b_idx < (num_spots % affected_ballz.size()):
			spots_per_ball += 1

		match distribution_mode:
			Distribution.FRACTAL:
				paintballz += _generate_fractal_pattern(properties, current_ball, color_list, outline_color_list, texture_list)
			Distribution.NOISE_FIELD:
				paintballz += _generate_noise_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.VORONOI:
				paintballz += _generate_voronoi_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.WAVE:
				paintballz += _generate_wave_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.STRIPES:
				paintballz += _generate_stripes_pattern(properties, current_ball, spots_per_ball, global_data, color_list, outline_color_list, texture_list)
			Distribution.STAR:
				paintballz += _generate_star_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.LEOPARD:
				paintballz += _generate_leopard_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.BULLSEYE:
				paintballz += _generate_bullseye_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.RAINBOW:
				paintballz += _generate_rainbow_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.RANDOM_WALK:
				paintballz += _generate_random_walk(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			Distribution.CLUSTERED:
				paintballz += _generate_clustered_pattern(properties, current_ball, spots_per_ball, color_list, outline_color_list, texture_list)
			_: 
				paintballz += _generate_simple_pattern(properties, current_ball, spots_per_ball, b_idx, affected_ballz.size(), color_list, outline_color_list, texture_list)

	emit_signal("randomize_auto_paintballz", paintballz)

# UNIFORM, SPIRAL, BANDS, POLE, EQUATOR, HALFIE, GRID, CHECKERBOARD
func _generate_simple_pattern(p, ball_no, spots, b_idx, total_balls, color_list, outline_color_list, texture_list):
	var paintballz = []
	var mode = p.distribution
	for i in range(spots):
		var pos = Vector3.UP
		var size = rand_range(p.size_min, p.size_max)
		
		if mode == Distribution.UNIFORM:
			pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		elif mode == Distribution.SPIRAL:
			var angle = i * (TAU * p.spiral_turns / spots)
			var y = lerp(-1, 1, float(i) / spots)
			var r = sqrt(max(0, 1 - y*y))
			pos = Vector3(r * cos(angle), y, r * sin(angle))
		elif mode == Distribution.BANDS:
			var band_idx = floor(i * p.num_bands / spots)
			var y = lerp(-p.band_spacing, p.band_spacing, float(band_idx)/max(1, p.num_bands-1)) + p.band_offset
			var r = sqrt(max(0, 1 - y*y))
			var a = randf() * TAU
			pos = Vector3(r * cos(a), y, r * sin(a))
			if p.band_direction == 1: pos = Vector3(pos.y, pos.x, pos.z)
			pos = pos.rotated(Vector3.FORWARD, deg2rad(p.band_angle))
		elif mode == Distribution.POLE_FOCUSED:
			var y = (1.0 - pow(randf(), 2)) * (1 if randf() > 0.5 else -1)
			var a = randf() * TAU
			var r = sqrt(max(0, 1-y*y))
			pos = Vector3(r * cos(a), y, r * sin(a))
		elif mode == Distribution.EQUATOR_FOCUSED:
			var y = rand_range(-0.15, 0.15)
			var a = randf() * TAU
			pos = Vector3(sqrt(1-y*y)*cos(a), y, sqrt(1-y*y)*sin(a))
		elif mode == Distribution.HALFIE:
			pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			pos[p.halfie_axis] = abs(pos[p.halfie_axis]) * (1 if p.halfie_side == 0 else -1)
			pos = pos.normalized()
		elif mode == Distribution.GRID:
			var gs = p.grid_size
			var u = float(i % int(gs)) / gs
			var v = float(i / int(gs)) / gs
			var theta = u * TAU
			var phi = acos(clamp(2 * v - 1, -1, 1))
			pos = Vector3(sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta))
		elif mode == Distribution.CHECKERBOARD:
			var gs = int(p.grid_size)
			var valid_found = false
			var attempts = 0
			while not valid_found and attempts < 100:
				attempts += 1
				var u_idx = randi() % gs
				var v_idx = randi() % gs
				if (u_idx + v_idx) % 2 == 1:
					var u = (u_idx + randf()) / gs
					var v = (v_idx + randf()) / gs
					var theta = u * TAU
					var phi = acos(clamp(2 * v - 1, -1, 1))
					pos = Vector3(sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta))
					valid_found = true

		paintballz.append(_create_paintball(pos, size, ball_no, p, color_list, outline_color_list, texture_list))
	return paintballz

func _generate_star_pattern(properties, ball_no, num_stars, color_list, outline_color_list, texture_list):
	var paintballz = []
	var num_points = int(properties.star_points)
	var ray_length = int(properties.ray_length)
	if num_points <= 1 or ray_length <= 0: return []

	for i in range(num_stars):
		var star_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var basis = _get_basis_from_normal(star_center)
		var star_color = [color_list[randi() % color_list.size()]]
		var star_outline = [outline_color_list[randi() % outline_color_list.size()]]
		var base_size = rand_range(properties.size_min, properties.size_max)

		for p in range(num_points):
			var angle = (float(p) / num_points) * TAU
			var tangent_dir = (basis.x * cos(angle) + basis.z * sin(angle))
			var tip = star_center.slerp(star_center + tangent_dir, properties.ray_length * 0.1).normalized()

			for j in range(ray_length):
				var pos = star_center.slerp(tip, float(j + 1) / ray_length).normalized()
				var progress = float(j) / ray_length
				var final_size = lerp(base_size, properties.star_point_size, progress)

				paintballz.append(_create_paintball(pos, final_size, ball_no, properties, star_color, star_outline, texture_list))
	return paintballz

# XX: Leopard Generator
func _generate_leopard_pattern(properties, ball_no, num_spots, color_list, outline_color_list, texture_list):
	var paintballz = []
	if color_list.size() < 2: return []

	for i in range(num_spots):
		var spot_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var basis = _get_basis_from_normal(spot_center)
		var spot_radius = rand_range(properties.leopard_radius_min, properties.leopard_radius_max)
		var pb_size = rand_range(properties.size_min, properties.size_max)
		
		var c_out = color_list[randi() % color_list.size()]
		var c_in = color_list[randi() % color_list.size()]
		while c_in == c_out and color_list.size() > 1: c_in = color_list[randi() % color_list.size()]

		# Outline ring
		for j in range(20):
			if randf() > properties.leopard_completeness: continue
			var r = spot_radius * rand_range(1.0 - properties.leopard_irregularity, 1.0 + properties.leopard_irregularity)
			var angle = (float(j) / 20.0) * TAU
			var dir = (basis.x * cos(angle) + basis.z * sin(angle))
			var pos = spot_center.slerp(spot_center + dir, r).normalized()
			paintballz.append(_create_paintball(pos, pb_size, ball_no, properties, [c_out], outline_color_list, texture_list))
		
		# Inner fill
		for j in range(15):
			var r = sqrt(randf()) * spot_radius * 0.8
			var angle = randf() * TAU
			var dir = (basis.x * cos(angle) + basis.z * sin(angle))
			var pos = spot_center.slerp(spot_center + dir, r).normalized()
			paintballz.append(_create_paintball(pos, pb_size * 0.9, ball_no, properties, [c_in], outline_color_list, texture_list))
	return paintballz

func _calculate_gray_scott_grid(properties):
	var size = 32
	var grid = []
	grid.resize(size * size)
	for i in range(size * size): grid[i] = {"a": 1.0, "b": 0.0}
	grid[(size/2) * size + (size/2)].b = 1.0
	
	for t in range(100):
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
					"a": clamp(a + (properties.diffusion_a * lp_a - r + properties.stripe_feed_rate * (1 - a)) * properties.stripe_timestep, 0, 1),
					"b": clamp(b + (properties.diffusion_b * lp_b + r - (properties.stripe_kill_rate + properties.stripe_feed_rate) * b) * properties.stripe_timestep, 0, 1)
				}
		for i in range(size * size): if next[i]: grid[i] = next[i]
	return grid

func _generate_stripes_pattern(properties, ball_no, spots_to_make, grid, color_list, outline_color_list, texture_list):
	var paintballz = []
	var offset_u = randf() # Unique UV offset per ball to vary sampling
	var offset_v = randf()
	
	var attempts = 0
	while paintballz.size() < spots_to_make and attempts < spots_to_make * 20:
		attempts += 1
		var u = fmod(randf() + offset_u, 1.0)
		var v = fmod(randf() + offset_v, 1.0)
		var gx = int(u * 31)
		var gy = int(v * 31)
		if grid[gy * 32 + gx].b > 0.4:
			var theta = u * TAU
			var phi = acos(clamp(2 * v - 1, -1, 1))
			var pos = Vector3(sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta))
			paintballz.append(_create_paintball(pos, rand_range(properties.size_min, properties.size_max), ball_no, properties, color_list, outline_color_list, texture_list))
	return paintballz

# XX: Random Walk Generator
func _generate_random_walk(p, ball_no, spots, color_list, outline_color_list, texture_list):
	var paintballz = []
	var last = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	for i in range(spots):
		var step = Vector3(rand_range(-0.3, 0.3), rand_range(-0.3, 0.3), rand_range(-0.3, 0.3))
		last = (last + step).normalized()
		paintballz.append(_create_paintball(last, rand_range(p.size_min, p.size_max), ball_no, p, color_list, outline_color_list, texture_list))
	return paintballz

# XX: Cluster Generator
func _generate_clustered_pattern(p, ball_no, spots, color_list, outline_color_list, texture_list):
	var paintballz = []
	var clusters = []
	for i in range(int(p.num_clusters)): clusters.append(Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized())
	for i in range(spots):
		var center = clusters[randi() % clusters.size()]
		var pos = (center + Vector3(rand_range(-0.4, 0.4), rand_range(-0.4, 0.4), rand_range(-0.4, 0.4))).normalized()
		paintballz.append(_create_paintball(pos, rand_range(p.size_min, p.size_max), ball_no, p, color_list, outline_color_list, texture_list))
	return paintballz

# XX: Bullseye Generator
func _generate_bullseye_pattern(p, ball_no, num_targets, color_list, outline_color_list, texture_list):
	var paintballz = []
	for i in range(num_targets):
		var center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var base_size = rand_range(p.size_min, p.size_max)
		for r in range(int(p.num_rings)):
			var size = base_size * (1.0 - float(r) / p.num_rings)
			var color = [color_list[r % color_list.size()]]
			paintballz.append(_create_paintball(center, size, ball_no, p, color, outline_color_list, texture_list))
	return paintballz

# XX: Rainbow Generator
func _generate_rainbow_pattern(p, ball_no, num_rainbows, color_list, outline_color_list, texture_list):
	var paintballz = []
	for i in range(num_rainbows):
		var start = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var basis = _get_basis_from_normal(start)
		var rot_axis = basis.x.slerp(start, p.rainbow_curvature).rotated(start, deg2rad(p.rainbow_angle))
		var pb_size = rand_range(p.size_min, p.size_max)
		
		for c_idx in range(color_list.size()):
			var off_dist = (float(c_idx) - (color_list.size()-1)/2.0) * p.rainbow_width
			var band_start = start.rotated(rot_axis.cross(start).normalized(), atan(off_dist * 0.05))
			var steps = int(20 * p.rainbow_length)
			for s in range(steps):
				var pos = band_start.rotated(rot_axis, (float(s)/steps) * PI * p.rainbow_length)
				paintballz.append(_create_paintball(pos.normalized(), pb_size, ball_no, p, [color_list[c_idx]], outline_color_list, texture_list))
	return paintballz

# 17: Voronoi / Cell Pattern Generator
func _generate_voronoi_pattern(properties, ball_no, spots_to_make, color_list, outline_color_list, texture_list):
	var paintballz = []
	var centers = []
	for i in range(int(properties.voronoi_cells)):
		centers.append(Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized())

	var attempts = 0
	while paintballz.size() < spots_to_make and attempts < spots_to_make * 10:
		attempts += 1
		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var dists = []
		for c in centers: dists.append(pos.distance_squared_to(c))
		dists.sort()
		
		var edge_val = (dists[1] - dists[0]) / (dists[0] + dists[1] + 0.001)
		if edge_val < properties.voronoi_edge_size:
			var size = rand_range(properties.size_min, properties.size_max)
			paintballz.append(_create_paintball(pos, size, ball_no, properties, color_list, outline_color_list, texture_list))
	return paintballz

# func _generate_voronoi_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
# 	var paintballz = []
# 	var num_cells = int(properties.voronoi_cells)
# 	var edge_size = properties.voronoi_edge_size
	
# 	if num_cells < 2: return []
	
# 	var cell_centers = []
# 	for i in range(num_cells):
# 		cell_centers.append(Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized())

# 	for i in range(properties.num_spots * 2): # Try twice as many random points to find spots on edges
# 		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		
# 		# Find the two closest cell centers to 'pos'
# 		var closest_centers = []
# 		for center in cell_centers:
# 			closest_centers.append({"center": center, "dist_sq": pos.distance_squared_to(center)})
		
# 		closest_centers.sort_custom(self, "_sort_by_dist_sq")
		
# 		var D1_sq = closest_centers[0].dist_sq
# 		var D2_sq = closest_centers[1].dist_sq
		
# 		# Edge Condition: Small difference between D1 and D2 means the point is near the boundary.
# 		var center_dist_diff = abs(D1_sq - D2_sq)
		
# 		# Normalize difference
# 		var edge_value = center_dist_diff / max(0.001, D1_sq + D2_sq)
		
# 		# Place spot if close to the boundary defined by edge_size
# 		if edge_value < edge_size: 
# 			var size = rand_range(properties.size_min, properties.size_max)
			
# 			var paintball = _create_paintball(
# 				pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 			)
# 			paintballz.append(paintball)
			
# 			if paintballz.size() >= properties.num_spots:
# 				break
			
# 	return paintballz
	
# func _sort_by_dist_sq(a, b):
# 	return a.dist_sq < b.dist_sq

# 18: Wave (Spherical Harmonics) Generator
func _generate_wave_pattern(properties, ball_no, spots_to_make, color_list, outline_color_list, texture_list):
	var paintballz = []
	var L = int(properties.wave_degree_l)
	var M = min(int(properties.wave_order_m), L)
	
	var attempts = 0
	while paintballz.size() < spots_to_make and attempts < spots_to_make * 10:
		attempts += 1
		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		var cos_theta = clamp(pos.y, -1.0, 1.0)
		var sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta))
		var phi = atan2(pos.z, pos.x)
		
		var p_lm = 1.0
		if L == 1: p_lm = cos_theta if M == 0 else sin_theta
		elif L == 2:
			if M == 0: p_lm = 0.5 * (3 * cos_theta * cos_theta - 1)
			elif M == 1: p_lm = 3 * cos_theta * sin_theta
			else: p_lm = 3 * sin_theta * sin_theta
		elif L >= 3:
			if M == 0: p_lm = 0.5 * (5 * pow(cos_theta, 3) - 3 * cos_theta)
			elif M == 1: p_lm = 1.5 * (5 * cos_theta * cos_theta - 1) * sin_theta
			elif M == 2: p_lm = 15 * cos_theta * sin_theta * sin_theta
			else: p_lm = 15 * pow(sin_theta, 3)

		var val = (p_lm * cos(M * phi) + 1.0) / 2.0
		if val > properties.wave_threshold:
			var size = rand_range(properties.size_min, properties.size_max)
			paintballz.append(_create_paintball(pos, size, ball_no, properties, color_list, outline_color_list, texture_list))
	return paintballz

# func _generate_wave_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
# 	var paintballz = []
# 	var L = int(properties.wave_degree_l) # Degree (Vertical Frequency)
# 	var M = int(properties.wave_order_m)  # Order (Horizontal Frequency)
# 	var threshold = properties.wave_threshold
	
# 	# Clamp M to L
# 	M = min(M, L) 
	
# 	if L < 0 or M < 0: return []
	
# 	for i in range(properties.num_spots * 2): # Try twice as many random points
# 		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		
# 		var x = pos.x
# 		var y = pos.y
# 		var z = pos.z
		
# 		# Spherical Coordinates:
# 		var cos_theta = clamp(y, -1.0, 1.0) # Cosine of the polar angle (elevation)
# 		var sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta))
# 		var phi = atan2(z, x) # Azimuthal angle (longitude)
		
# 		var P_lm = 0.0 
		
# 		# --- Associated Legendre Polynomial P_l^m(x) (max L=3) ---
# 		if L == 0:
# 			P_lm = 1.0
# 		elif L == 1:
# 			if M == 0: P_lm = cos_theta
# 			elif M == 1: P_lm = sin_theta
# 		elif L == 2:
# 			if M == 0: P_lm = 0.5 * (3.0 * cos_theta * cos_theta - 1.0)
# 			elif M == 1: P_lm = 3.0 * cos_theta * sin_theta
# 			elif M == 2: P_lm = 3.0 * sin_theta * sin_theta
# 		elif L == 3:
# 			if M == 0: P_lm = 0.5 * (5.0 * pow(cos_theta, 3) - 3.0 * cos_theta)
# 			elif M == 1: P_lm = 1.5 * (5.0 * cos_theta * cos_theta - 1.0) * sin_theta
# 			elif M == 2: P_lm = 15.0 * cos_theta * sin_theta * sin_theta
# 			elif M == 3: P_lm = 15.0 * pow(sin_theta, 3)
# 		else: # For L > 3, we default to the highest implemented value to avoid math complexity
# 			L = 3
# 			M = min(M, L)
			
# 		# The Real Spherical Harmonic is proportional to P_l^m(cos(theta)) * cos(m * phi)
# 		var Y_lm = P_lm * cos(M * phi)
		
# 		# Map value Y_lm (typically [-1, 1]) to [0, 1] density
# 		var density = (Y_lm + 1.0) / 2.0
		
# 		if density > threshold:
# 			var size = rand_range(properties.size_min, properties.size_max)
			
# 			var paintball = _create_paintball(
# 				pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 			)
# 			paintballz.append(paintball)
			
# 			if paintballz.size() >= properties.num_spots:
# 				break

# 	return paintballz

# 04: Noise Field Generator
func _generate_noise_pattern(p, ball_no, spots, color_list, outline_color_list, texture_list):
	var pbs = []
	var noise = OpenSimplexNoise.new(); noise.seed = randi(); noise.period = p.noise_scale
	var attempts = 0
	while pbs.size() < spots and attempts < spots * 15:
		attempts += 1
		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		if (noise.get_noise_3d(pos.x, pos.y, pos.z) + 1.0) / 2.0 > p.noise_threshold:
			var pb = _create_paintball(pos, rand_range(p.size_min, p.size_max), ball_no, p, color_list, outline_color_list, texture_list)
			if pb: pbs.append(pb)
	return pbs

# func _generate_noise_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
# 	var paintballz = []
# 	var noise = OpenSimplexNoise.new()
	
# 	noise.seed = randi()
# 	noise.period = properties.noise_scale
# 	noise.octaves = int(properties.noise_octaves)
# 	var threshold = properties.noise_threshold
	
# 	for i in range(properties.num_spots * 2):
# 		var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
		
# 		# Get 3D noise value
# 		var noise_value = noise.get_noise_3d(pos.x, pos.y, pos.z)
		
# 		# Normalize noise from [-1, 1] to [0, 1]
# 		var density = (noise_value + 1.0) / 2.0
		
# 		if density > threshold:
# 			var size = rand_range(properties.size_min, properties.size_max)
			
# 			var paintball = _create_paintball(
# 				pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 			)
# 			paintballz.append(paintball)
			
# 			if paintballz.size() >= properties.num_spots:
# 				break
				
# 	return paintballz

# 16: L-System Fractal Generator
func _generate_fractal_pattern(p, ball_no, color_list, outline_color_list, texture_list):
	var axiom = p.fractal_axiom
	var rules = _parse_lsystem_rules(p.fractal_rules)
	if p.fractal_preset == FractalPreset.DRAGON_CURVE:
		axiom = "F"
		rules = {"F": "F+G", "G": "F-G"}
	elif p.fractal_preset == FractalPreset.SIERPINSKI:
		axiom = "A"
		rules = {"A": "B-A-B", "B": "A+B+A"}
	elif p.fractal_preset == FractalPreset.BARNSLEY_FERN:
		axiom = "X"
		rules = {"X": "F+[[X]-X]-F[-FX]+X", "F": "FF"}
	
	var s = _generate_lsystem_string(axiom, rules, int(p.fractal_iterations))
	var pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
	var basis = _get_basis_from_normal(pos)
	var state = {"pos": pos, "heading": basis.x}
	var stack = []
	var pbs = []
	var size = rand_range(p.size_min, p.size_max)
	var step = atan(size * 0.02)
	
	for cmd in s:
		match cmd:
			"F", "G", "A", "B":
				var axis = state.heading.cross(state.pos).normalized()
				state.pos = state.pos.rotated(axis, step).normalized()
				state.heading = state.heading.rotated(axis, step).normalized()
				pbs.append(_create_paintball(state.pos, size, ball_no, p, color_list, outline_color_list, texture_list))
			"+": state.heading = state.heading.rotated(state.pos, deg2rad(-p.fractal_angle))
			"-": state.heading = state.heading.rotated(state.pos, deg2rad(p.fractal_angle))
			"[": stack.append(state.duplicate())
			"]": if !stack.empty(): state = stack.pop_back()
	return pbs

# func _generate_fractal_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list):
# 	var paintballz = []
# 	var axiom = ""
# 	var rules = {}

# 	match properties.fractal_preset:
# 		FractalPreset.DRAGON_CURVE:
# 			axiom = "F"
# 			rules = {"F": "F+G", "G": "F-G"}
# 		FractalPreset.SIERPINSKI:
# 			axiom = "A"
# 			rules = {"A": "B-A-B", "B": "A+B+A"}
# 		FractalPreset.BARNSLEY_FERN:
# 			axiom = "X"
# 			rules = {"X": "F+[[X]-X]-F[-FX]+X", "F": "FF"}
# 		_: # Default to Custom
# 			axiom = properties.fractal_axiom
# 			rules = _parse_lsystem_rules(properties.fractal_rules)
	
# 	if axiom.empty() or rules.empty():
# 		push_warning("Fractal generation failed: Axiom or Rules are not defined.")
# 		return []

# 	var fractal_string = _generate_lsystem_string(axiom, rules, properties.fractal_iterations)
	
# 	var start_pos = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 	if start_pos.length_squared() == 0: start_pos = Vector3.FORWARD
	
# 	var basis = _get_basis_from_normal(start_pos)
# 	var turtle_state = {"pos": start_pos, "heading": basis.x}
# 	var state_stack = []

# 	var paintball_size = rand_range(properties.size_min, properties.size_max)
# 	var step_angle_rad = atan(paintball_size * 0.02) * 0.9

# 	for command in fractal_string:
# 		match command:
# 			"F", "G", "A", "B": # Draw forward
# 				var move_axis = turtle_state.heading.cross(turtle_state.pos).normalized()
# 				if move_axis.length_squared() > 0:
# 					turtle_state.pos = turtle_state.pos.rotated(move_axis, step_angle_rad)
# 					turtle_state.heading = turtle_state.heading.rotated(move_axis, step_angle_rad)
					
# 					var paintball = _create_paintball(
# 						turtle_state.pos,
# 						paintball_size,
# 						properties, affected_ballz, color_list, outline_color_list, texture_list
# 					)
# 					paintballz.append(paintball)
# 			"+": # Turn Right
# 				var turn_axis = turtle_state.pos
# 				turtle_state.heading = turtle_state.heading.rotated(turn_axis, deg2rad(-properties.fractal_angle))
# 			"-": # Turn Left
# 				var turn_axis = turtle_state.pos
# 				turtle_state.heading = turtle_state.heading.rotated(turn_axis, deg2rad(properties.fractal_angle))
# 			"[": # Push state
# 				state_stack.append(turtle_state.duplicate(true))
# 			"]": # Pop state
# 				if not state_stack.empty():
# 					turtle_state = state_stack.pop_back()
# 	return paintballz

func _on_ApplyButton_pressed():
	emit_signal("apply_auto_paintballz")

func _on_ClearButton_pressed():
	emit_signal("clear_auto_paintballz")

# func show():
# 	$Panel.show()

# func hide():
# 	$Panel.hide()

func _create_paintball(pos, size, ball_no, properties, color_list, outline_color_list, texture_list):
	if not properties is Dictionary:
		push_error("AutoPaintballer: properties must be a Dictionary.")
		return null

	var color
	var outline_color
	var texture
	var is_ordered = properties.get("ordered", false)

	if is_ordered:
		color = color_list[_ordered_color_index % color_list.size()]
		_ordered_color_index += 1
		outline_color = outline_color_list[_ordered_outline_color_index % outline_color_list.size()]
		_ordered_outline_color_index += 1
		texture = texture_list[_ordered_texture_index % texture_list.size()]
		_ordered_texture_index += 1
	else:
		color = color_list[randi() % color_list.size()]
		outline_color = outline_color_list[randi() % outline_color_list.size()]
		texture = texture_list[randi() % texture_list.size()]

	var final_diameter = size

	if properties.get("pixel_mode", false):
		var visual_base = pet_node.ball_map.get(ball_no)
		if visual_base:
			var base_pixel_size = visual_base.ball_size 
			final_diameter = (size / base_pixel_size) * 100.0

	var pb = PaintBallData.new(
		ball_no, int(round(final_diameter)), pos, color, outline_color,
		floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
		floor(rand_range(properties.fuzz_min, properties.fuzz_max)),
		0, texture, 1 if properties.anchored else 0, properties.group
	)
	
	if "pixel_mode" in pb:
		pb.pixel_mode = properties.get("pixel_mode", false)
	
	return pb

# func _create_paintball(pos, size, ball_no, properties, color_list, outline_color_list, texture_list):
# 	var color
# 	var outline_color
# 	var texture

# 	if properties.ordered:
# 		color = color_list[_ordered_color_index % color_list.size()]
# 		_ordered_color_index += 1
# 		outline_color = outline_color_list[_ordered_outline_color_index % outline_color_list.size()]
# 		_ordered_outline_color_index += 1
# 		texture = texture_list[_ordered_texture_index % texture_list.size()]
# 		_ordered_texture_index += 1
# 	else:
# 		color = color_list[randi() % color_list.size()]
# 		outline_color = outline_color_list[randi() % outline_color_list.size()]
# 		texture = texture_list[randi() % texture_list.size()]

# 	return PaintBallData.new(
# 		ball_no, size, pos, color, outline_color,
# 		floor(rand_range(properties.outline_type_min, properties.outline_type_max)),
# 		floor(rand_range(properties.fuzz_min, properties.fuzz_max)),
# 		0, texture, 1 if properties.anchored else 0, properties.group
# 	)

func _get_basis_from_normal(normal_vec):
	var basis_y = normal_vec.normalized()
	var cross_vec = Vector3.UP.cross(basis_y)

	if cross_vec.length_squared() < 0.0001:
		cross_vec = Vector3.RIGHT.cross(basis_y)
	
	var basis_x = cross_vec.normalized()
	var basis_z = basis_y.cross(basis_x).normalized()
	
	return Basis(basis_x, basis_y, basis_z)


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
	properties["num_bands"] = find_node("NumBands").value
	properties["band_spacing"] = find_node("BandSpacing").value
	properties["band_offset"] = find_node("BandOffset").value
	properties["band_angle"] = find_node("BandAngle").value
	properties["band_direction"] = find_node("BandDirection").selected # New for Bands
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
	properties["diffusion_b"] = find_node("DiffusionActivator").value
	properties["diffusion_a"] = find_node("DiffusionInhibitor").value
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
	properties["pixel_mode"] = find_node("PixelMode").pressed
	return properties

func add_affected_ball(ball_no: int):
	var line_edit = find_node("AffectedBallz")
	var current_text = line_edit.text
	var current_list = LnzLiveUtils.parse_number_list(current_text)

	if ball_no in current_list:
		return

	if current_text.strip_edges() == "":
		line_edit.text = str(ball_no)
	else:
		line_edit.text += "," + str(ball_no)
		
	_on_AffectedBallz_text_changed(line_edit.text)

func update_selected_balls_text(ball_ids: Array):
	var affected_edit = find_node("AffectedBallz")
	if not affected_edit or affected_edit.has_focus():
		return

	if ball_ids.empty():
		affected_edit.text = ""
		return

	ball_ids.sort()
	var start = ball_ids[0]
	var prev = start
	var ranges = []
	
	for i in range(1, ball_ids.size()):
		var curr = ball_ids[i]
		if curr == prev + 1:
			prev = curr
		else:
			if start == prev:
				ranges.append(str(start))
			else:
				ranges.append(str(start) + "-" + str(prev))
			start = curr
			prev = curr
			
	if start == prev:
		ranges.append(str(start))
	else:
		ranges.append(str(start) + "-" + str(prev))
		
	affected_edit.text = PoolStringArray(ranges).join(",")
	_on_AffectedBallz_text_changed(affected_edit.text)

func _on_UnselectButton_pressed():
	emit_signal("unselect_all")

func _connect_settings_signals():
	find_node("AffectedBallz").connect("text_changed", self, "_on_setting_changed")
	find_node("ColorList").connect("text_changed", self, "_on_setting_changed")
	find_node("OutlineColorList").connect("text_changed", self, "_on_setting_changed")
	find_node("TextureList").connect("text_changed", self, "_on_setting_changed")
	find_node("FractalAxiom").connect("text_changed", self, "_on_setting_changed")
	find_node("Seed").connect("text_changed", self, "_on_setting_changed")

	find_node("FractalRules").connect("text_changed", self, "_on_setting_changed")

	find_node("Distribution").connect("item_selected", self, "_on_setting_changed")
	find_node("BandDirection").connect("item_selected", self, "_on_setting_changed")
	find_node("FractalPreset").connect("item_selected", self, "_on_setting_changed")
	find_node("HalfieAxis").connect("item_selected", self, "_on_setting_changed")
	find_node("HalfieSide").connect("item_selected", self, "_on_setting_changed")

	find_node("Ordered").connect("toggled", self, "_on_setting_changed")
	find_node("UseSeed").connect("toggled", self, "_on_setting_changed")
	find_node("Anchored").connect("toggled", self, "_on_setting_changed")
	find_node("LeopardPairedColors").connect("toggled", self, "_on_setting_changed")

	_connect_spinboxes_recursive(self)

	var reset_btn = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _connect_spinboxes_recursive(node):
	for child in node.get_children():
		if child is SpinBox:
			child.connect("value_changed", self, "_on_setting_changed")
		_connect_spinboxes_recursive(child)

func _on_setting_changed(_arg = null):
	if _is_loading_settings:
		return
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		return

	var p = get_properties()
	
	for key in p.keys():
		config.set_value("AutoPaintballer", key, p[key])

	var save_err = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving AutoPaintballerSettings: ", save_err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	_is_loading_settings = true

	find_node("AffectedBallz").text = config.get_value("AutoPaintballer", "affected_ballz", "")
	find_node("Distribution").selected = config.get_value("AutoPaintballer", "distribution", 0)
	find_node("NumSpots").value = config.get_value("AutoPaintballer", "num_spots", 25.0)
	find_node("Ordered").pressed = config.get_value("AutoPaintballer", "ordered", false)
	find_node("UseSeed").pressed = config.get_value("AutoPaintballer", "use_seed", false)
	find_node("Seed").text = config.get_value("AutoPaintballer", "seed", "")

	find_node("SizeMin").value = config.get_value("AutoPaintballer", "size_min", 10.0)
	find_node("SizeMax").value = config.get_value("AutoPaintballer", "size_max", 20.0)
	find_node("PixelMode").pressed = config.get_value("AutoPaintballer", "pixel_mode", false)
	find_node("ColorList").text = config.get_value("AutoPaintballer", "color_list", "")
	find_node("TextureList").text = config.get_value("AutoPaintballer", "texture_list", "0")
	find_node("OutlineColorList").text = config.get_value("AutoPaintballer", "outline_color_list", "244")
	find_node("OutlineTypeMin").value = config.get_value("AutoPaintballer", "outline_type_min", -1.0)
	find_node("OutlineTypeMax").value = config.get_value("AutoPaintballer", "outline_type_max", -1.0)
	find_node("FuzzMin").value = config.get_value("AutoPaintballer", "fuzz_min", 0.0)
	find_node("FuzzMax").value = config.get_value("AutoPaintballer", "fuzz_max", 0.0)
	find_node("Group").value = config.get_value("AutoPaintballer", "group", 0.0)
	find_node("Anchored").pressed = config.get_value("AutoPaintballer", "anchored", true)

	find_node("SpiralTurns").value = config.get_value("AutoPaintballer", "spiral_turns", 5.0)
	find_node("StarPointSize").value = config.get_value("AutoPaintballer", "star_point_size", 4.0)
	find_node("StarPoints").value = config.get_value("AutoPaintballer", "star_points", 5.0)
	find_node("RayLength").value = config.get_value("AutoPaintballer", "ray_length", 4.0)
	find_node("RainbowAngle").value = config.get_value("AutoPaintballer", "rainbow_angle", 0.0)
	find_node("RainbowCurvature").value = config.get_value("AutoPaintballer", "rainbow_curvature", 0.0)
	find_node("RainbowWidth").value = config.get_value("AutoPaintballer", "rainbow_width", 0.5)
	find_node("RainbowLength").value = config.get_value("AutoPaintballer", "rainbow_length", 1.0)

	find_node("BandDirection").selected = config.get_value("AutoPaintballer", "band_direction", 0)
	find_node("NumBands").value = config.get_value("AutoPaintballer", "num_bands", 5.0)
	find_node("BandSpacing").value = config.get_value("AutoPaintballer", "band_spacing", 0.5)
	find_node("BandOffset").value = config.get_value("AutoPaintballer", "band_offset", 0.0)
	find_node("BandAngle").value = config.get_value("AutoPaintballer", "band_angle", 0.0)
	find_node("GridSize").value = config.get_value("AutoPaintballer", "grid_size", 5.0)
	find_node("NumClusters").value = config.get_value("AutoPaintballer", "num_clusters", 3.0)
	find_node("NumRings").value = config.get_value("AutoPaintballer", "num_rings", 3.0)

	find_node("NoiseScale").value = config.get_value("AutoPaintballer", "noise_scale", 10.0)
	find_node("NoiseThreshold").value = config.get_value("AutoPaintballer", "noise_threshold", 0.5)
	find_node("NoiseOctaves").value = config.get_value("AutoPaintballer", "noise_octaves", 3.0)
	find_node("VoronoiCells").value = config.get_value("AutoPaintballer", "voronoi_cells", 5.0)
	find_node("VoronoiEdgeSize").value = config.get_value("AutoPaintballer", "voronoi_edge_size", 0.05)
	find_node("WaveDegreeL").value = config.get_value("AutoPaintballer", "wave_degree_l", 2.0)
	find_node("WaveOrderM").value = config.get_value("AutoPaintballer", "wave_order_m", 1.0)
	find_node("WaveThreshold").value = config.get_value("AutoPaintballer", "wave_threshold", 0.6)

	find_node("StripeFeedRate").value = config.get_value("AutoPaintballer", "stripe_feed_rate", 0.07)
	find_node("StripeKillRate").value = config.get_value("AutoPaintballer", "stripe_kill_rate", 0.05)
	find_node("DiffusionActivator").value = config.get_value("AutoPaintballer", "diffusion_b", 0.5)
	find_node("DiffusionInhibitor").value = config.get_value("AutoPaintballer", "diffusion_a", 1.0)
	find_node("StripeTimestep").value = config.get_value("AutoPaintballer", "stripe_timestep", 1.0)

	find_node("LeopardRadiusMin").value = config.get_value("AutoPaintballer", "leopard_radius_min", 0.05)
	find_node("LeopardRadiusMax").value = config.get_value("AutoPaintballer", "leopard_radius_max", 0.1)
	find_node("LeopardIrregularity").value = config.get_value("AutoPaintballer", "leopard_irregularity", 0.3)
	find_node("LeopardCompleteness").value = config.get_value("AutoPaintballer", "leopard_completeness", 0.75)
	find_node("LeopardPairedColors").pressed = config.get_value("AutoPaintballer", "leopard_use_paired_colors", false)

	find_node("FractalIterations").value = config.get_value("AutoPaintballer", "fractal_iterations", 5.0)
	find_node("FractalAngle").value = config.get_value("AutoPaintballer", "fractal_angle", 90.0)
	find_node("FractalPreset").selected = config.get_value("AutoPaintballer", "fractal_preset", 0)
	find_node("FractalAxiom").text = config.get_value("AutoPaintballer", "fractal_axiom", "F")
	find_node("FractalRules").text = config.get_value("AutoPaintballer", "fractal_rules", "")

	find_node("HalfieAxis").selected = config.get_value("AutoPaintballer", "halfie_axis", 0)
	find_node("HalfieSide").selected = config.get_value("AutoPaintballer", "halfie_side", 0)

	_on_Distribution_item_selected(find_node("Distribution").selected)
	_on_FractalPreset_item_selected(find_node("FractalPreset").selected)
	_on_UseSeed_toggled(find_node("UseSeed").pressed)

	_is_loading_settings = false

func _on_reset_defaults_pressed():
	_is_loading_settings = true

	find_node("AffectedBallz").text = ""
	find_node("Distribution").selected = 0
	find_node("NumSpots").value = 25.0
	find_node("Ordered").pressed = false
	find_node("UseSeed").pressed = false
	find_node("Seed").text = ""

	find_node("SizeMin").value = 10.0
	find_node("SizeMax").value = 20.0
	find_node("ColorList").text = ""
	find_node("TextureList").text = "0"
	find_node("OutlineColorList").text = "244"
	find_node("OutlineTypeMin").value = -1.0
	find_node("OutlineTypeMax").value = -1.0
	find_node("FuzzMin").value = 0.0
	find_node("FuzzMax").value = 0.0
	find_node("Group").value = 0.0
	find_node("Anchored").pressed = true

	find_node("WaveDegreeL").value = 2.0
	find_node("WaveOrderM").value = 1.0
	find_node("WaveThreshold").value = 0.6
	find_node("VoronoiCells").value = 5.0
	find_node("VoronoiEdgeSize").value = 0.05

	find_node("NoiseScale").value = 10.0
	find_node("NoiseThreshold").value = 0.5
	find_node("NoiseOctaves").value = 3.0
	find_node("FractalPreset").selected = 0
	find_node("FractalAxiom").text = ""
	find_node("FractalRules").text = ""
	find_node("FractalIterations").value = 5.0
	find_node("FractalAngle").value = 90.0

	find_node("SpiralTurns").value = 5.0
	find_node("StarPointSize").value = 4.0
	find_node("StarPoints").value = 5.0
	find_node("RayLength").value = 4.0

	find_node("RainbowAngle").value = 0.0
	find_node("RainbowCurvature").value = 0.0
	find_node("RainbowWidth").value = 0.5
	find_node("RainbowLength").value = 1.0
	find_node("BandDirection").selected = 0
	find_node("NumBands").value = 5.0
	find_node("BandSpacing").value = 0.5
	find_node("BandOffset").value = 0.0
	find_node("BandAngle").value = 0.0

	find_node("GridSize").value = 5.0
	find_node("NumClusters").value = 3.0
	find_node("NumRings").value = 3.0

	find_node("StripeFeedRate").value = 0.07
	find_node("StripeKillRate").value = 0.05
	find_node("DiffusionActivator").value = 0.5
	find_node("DiffusionInhibitor").value = 1.0
	find_node("StripeTimestep").value = 1.0

	find_node("LeopardRadiusMin").value = 0.05
	find_node("LeopardRadiusMax").value = 0.1
	find_node("LeopardIrregularity").value = 0.3
	find_node("LeopardCompleteness").value = 0.75
	find_node("LeopardPairedColors").pressed = false

	find_node("HalfieAxis").selected = 0
	find_node("HalfieSide").selected = 0

	_on_Distribution_item_selected(0)
	_on_FractalPreset_item_selected(0)
	_on_UseSeed_toggled(false)

	_is_loading_settings = false
	save_settings()

func _on_SurpriseButton_pressed():
	_is_loading_settings = true

	var total_modes = Distribution.size()
	var random_mode = randi() % total_modes
	find_node("Distribution").selected = random_mode
	_on_Distribution_item_selected(random_mode)

	if random_mode == Distribution.RAINBOW or random_mode == Distribution.FRACTAL:
		find_node("NumSpots").value = (randi() % 2) + 1
	elif random_mode == Distribution.STAR:
		find_node("NumSpots").value = (randi() % 40) + 1
	elif random_mode == Distribution.LEOPARD:
		find_node("NumSpots").value = (randi() % 50) + 1
	else:
		find_node("NumSpots").value = int(rand_range(20, 150))
	
	var size_base = rand_range(2, 12)
	find_node("SizeMin").value = size_base
	find_node("SizeMax").value = min(50, size_base + rand_range(5, 25))
	
	find_node("PixelMode").pressed = randf() > 0.5

	if randf() > 0.6: 
		var fuzz_base = randi() % 4
		find_node("FuzzMin").value = fuzz_base
		find_node("FuzzMax").value = int(min(5, fuzz_base + randi() % 3))
	else:
		find_node("FuzzMin").value = 0
		find_node("FuzzMax").value = 0

	find_node("ColorList").text = _generate_surprise_color_string()
	find_node("TextureList").text = _generate_surprise_texture_string()
	find_node("OutlineColorList").text = _get_random_static_accent()
	
	var out_type = -1
	if randf() < 0.3:
		out_type = randi() % 4 - 2 
	find_node("OutlineTypeMin").value = out_type
	find_node("OutlineTypeMax").value = out_type

	_randomize_mode_params(random_mode)

	_is_loading_settings = false
	save_settings()
	_on_RandomizeButton_pressed()

func _randomize_mode_params(mode):
	match mode:
		Distribution.FRACTAL:
			if randf() > 0.4:
				find_node("FractalPreset").selected = FractalPreset.CUSTOM
				_on_FractalPreset_item_selected(FractalPreset.CUSTOM)
				_on_RandomSystemButton_pressed()
			else:
				var preset = (randi() % 3) + 1
				find_node("FractalPreset").selected = preset
				_on_FractalPreset_item_selected(preset)
			
			find_node("FractalIterations").value = (randi() % 3) + 2
			
		Distribution.SPIRAL:
			find_node("SpiralTurns").value = rand_range(1.0, 15.0) 
		Distribution.STAR:
			find_node("StarPoints").value = randi() % 7 + 3
			find_node("StarPointSize").value = rand_range(2.0, 8.0)
			find_node("RayLength").value = randi() % 6 + 2
		Distribution.BANDS:
			find_node("BandDirection").selected = randi() % 2
			find_node("NumBands").value = randi() % 8 + 2
			find_node("BandSpacing").value = rand_range(0.1, 0.8)
			find_node("BandOffset").value = rand_range(-0.5, 0.5)
			find_node("BandAngle").value = [0, 45, 90, 135][randi() % 4]
		Distribution.NOISE_FIELD:
			find_node("NoiseScale").value = rand_range(2.0, 20.0)
			find_node("NoiseThreshold").value = rand_range(0.3, 0.7)
			find_node("NoiseOctaves").value = randi() % 4 + 1
		Distribution.GRID, Distribution.CHECKERBOARD:
			find_node("GridSize").value = randi() % 10 + 3
		Distribution.CLUSTERED:
			find_node("NumClusters").value = randi() % 5 + 1
		Distribution.BULLSEYE:
			find_node("NumRings").value = randi() % 5 + 2
		Distribution.LEOPARD:
			find_node("LeopardRadiusMin").value = rand_range(0.02, 0.08)
			find_node("LeopardRadiusMax").value = rand_range(0.09, 0.2) 
			find_node("LeopardIrregularity").value = rand_range(0.1, 0.5)
			find_node("LeopardCompleteness").value = rand_range(0.4, 1.0) 
			find_node("LeopardPairedColors").pressed = randf() > 0.5
		Distribution.RAINBOW:
			find_node("RainbowAngle").value = rand_range(-180, 180)
			find_node("RainbowCurvature").value = rand_range(0.0, 1.0)
			find_node("RainbowWidth").value = rand_range(0.5, 5.0)
			find_node("RainbowLength").value = rand_range(0.5, 2.5)
		Distribution.STRIPES:
			find_node("StripeFeedRate").value = rand_range(0.01, 0.09) 
			find_node("StripeKillRate").value = rand_range(0.03, 0.07) 
			find_node("StripeTimestep").value = 1.0
		Distribution.VORONOI:
			find_node("VoronoiCells").value = randi() % 12 + 3 
			find_node("VoronoiEdgeSize").value = rand_range(0.01, 0.1) 
		Distribution.WAVE:
			find_node("WaveDegreeL").value = randi() % 4 
			find_node("WaveOrderM").value = randi() % 4 
			find_node("WaveThreshold").value = rand_range(0.4, 0.8)

func _generate_surprise_color_string() -> String:
	var parts = []
	for i in range(randi() % 3 + 1):
		var base = (randi() % 19 + 1) * 10 
		parts.append(str(base) + "-" + str(base + 9))
	if randf() > 0.4:
		for i in range(randi() % 3 + 1):
			parts.append(_get_random_static_accent())
	return PoolStringArray(parts).join(",")

func _generate_surprise_texture_string() -> String:
	var parts = []
	var max_tex = 0
	if pet_node and pet_node.lnz and pet_node.lnz.texture_list:
		max_tex = int(pet_node.lnz.texture_list.size())
	if randf() > 0.6: 
		parts.append("-1")
	if max_tex > 0:
		if randf() > 0.3:
			var tex_start = randi() % max_tex
			if randf() > 0.7 and tex_start < max_tex - 1:
				var remaining = int(max_tex - 1 - tex_start)
				var range_width = (randi() % int(min(3, remaining))) + 1
				parts.append(str(tex_start) + "-" + str(tex_start + range_width))
			else:
				parts.append(str(tex_start))
	else:
		if parts.empty(): 
			parts.append("0")
	return PoolStringArray(parts).join(",")

func _get_random_static_accent() -> String:
	if randf() > 0.4:
		return "244"
	return str(randi() % (214 - 150 + 1) + 150)

# OLD FXN with embedded generators
# func _on_RandomizeButton_pressed():
# 	var properties = get_properties()
# 	var affected_ballz = LnzLiveUtils.parse_number_list(properties.affected_ballz)
# 	if affected_ballz.empty():
# 		return

# 	var color_list = LnzLiveUtils.parse_number_list(properties.color_list)
# 	if color_list.empty():
# 		return

# 	var outline_color_list = LnzLiveUtils.parse_number_list(properties.outline_color_list)
# 	if outline_color_list.empty():
# 		return

# 	var texture_list_str = properties.texture_list
# 	var texture_list = LnzLiveUtils.parse_number_list(texture_list_str, true) # Allow negatives
# 	if texture_list.empty() and not texture_list_str.strip_edges().empty():
# 		push_warning("Could not parse [Texture List] so using default.")
# 		texture_list.append(-1)
# 	elif texture_list.empty():
# 		texture_list.append(-1)

# 	var paintballz = []
# 	var distribution_mode = properties.distribution

# 	var seed_edit = find_node("Seed")
# 	if properties.use_seed:
# 		if properties.seed.is_valid_integer():
# 			seed(int(properties.seed))
# 		else:
# 			push_warning("Invalid seed value. Using a random seed.")
# 			seed(OS.get_ticks_usec())
# 	else:
# 		var new_seed = OS.get_ticks_usec()
# 		seed(new_seed)
# 		seed_edit.text = str(new_seed)

# 	_ordered_color_index = 0
# 	_ordered_outline_color_index = 0
# 	_ordered_texture_index = 0
# 	_ordered_ball_index = 0

# 	match distribution_mode:
# 		Distribution.FRACTAL: # 16
# 			paintballz = _generate_fractal_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
# 		Distribution.NOISE_FIELD: # 04: Noise 
# 			paintballz = _generate_noise_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
# 		Distribution.VORONOI: # 17: Voronoi
# 			paintballz = _generate_voronoi_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
# 		Distribution.WAVE: # 18: Wave (Spherical Harmonics)
# 			paintballz = _generate_wave_pattern(properties, affected_ballz, color_list, outline_color_list, texture_list)
# 		Distribution.RANDOM_WALK: # 7
# 			for ball_index in affected_ballz:

# 				var num_spots_per_ball = int(properties.num_spots) / int(affected_ballz.size())
# 				var spots_remainder = int(properties.num_spots) % int(affected_ballz.size())
				
# 				if ball_index == affected_ballz.back():
# 					num_spots_per_ball += spots_remainder
				
# 				var last_pos = Vector3()
				
# 				for i in range(num_spots_per_ball):
# 					var position = Vector3()
# 					if i == 0:
# 						position = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 					else:
# 						var offset = Vector3(rand_range(-0.2, 0.2), rand_range(-0.2, 0.2), rand_range(-0.2, 0.2))
# 						position = (last_pos + offset).normalized()
					
# 					var size = rand_range(properties.size_min, properties.size_max)

# 					var paintball = _create_paintball(
# 						position, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 					)
# 					paintballz.append(paintball)
# 					last_pos = position
# 		Distribution.CLUSTERED: # 8
# 			for ball_index in affected_ballz:
# 				var cluster_center = Vector3()
				
# 				var num_spots_per_ball = int(properties.num_spots) / int(affected_ballz.size())
# 				var spots_remainder = int(properties.num_spots) % int(affected_ballz.size())
				
# 				if ball_index == affected_ballz.back():
# 					num_spots_per_ball += spots_remainder
				
# 				for i in range(num_spots_per_ball):
# 					var num_clusters = properties.num_clusters
# 					if num_clusters > 0:
# 						var cluster_size = num_spots_per_ball / num_clusters
# 						if cluster_size > 0 and i % int(cluster_size) == 0:
# 							cluster_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 						var offset = Vector3(rand_range(-0.3, 0.3), rand_range(-0.3, 0.3), rand_range(-0.3, 0.3))
# 						var position = (cluster_center + offset).normalized()

# 						var size = rand_range(properties.size_min, properties.size_max)
						
# 						var paintball = _create_paintball(
# 							position, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 						)
# 						paintballz.append(paintball)
# 		Distribution.STAR: # 2
# 			var num_stars = properties.num_spots
# 			var num_points = int(properties.star_points)
# 			var point_size = int(properties.star_point_size)
# 			var ray_length = properties.ray_length

# 			if num_points <= 1 or ray_length <= 0:
# 				return

# 			for i in range(num_stars):
# 				var star_color
# 				var star_outline_color
# 				if properties.ordered:
# 					star_color = color_list[_ordered_color_index % color_list.size()]
# 					_ordered_color_index += 1
# 					star_outline_color = outline_color_list[_ordered_outline_color_index % outline_color_list.size()]
# 					_ordered_outline_color_index += 1
# 				else:
# 					star_color = color_list[randi() % color_list.size()]
# 					star_outline_color = outline_color_list[randi() % outline_color_list.size()]
				
# 				var star_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
				
# 				var basis = _get_basis_from_normal(star_center)
				
# 				for p in range(num_points):
# 					var angle = (float(p) / num_points) * 2 * PI
# 					var tangent_dir = (basis.x * cos(angle) + basis.z * sin(angle))
					
# 					var ray_angle_factor = 0.1
# 					var tip = star_center.slerp(star_center + tangent_dir, ray_length * ray_angle_factor).normalized()

# 					var ray_base_size = rand_range(properties.size_min, properties.size_max)

# 					for j in range(int(ray_length)):
# 						var pos = star_center.slerp(tip, float(j + 1) / ray_length)
						
# 						var progress = float(j) / ray_length
# 						var progressive_size = lerp(ray_base_size, point_size, progress)
# 						var final_size = max(progressive_size, point_size)

# 						var paintball = _create_paintball(
# 							pos.normalized(), final_size, properties, affected_ballz, [star_color], [star_outline_color], texture_list
# 						)
# 						paintballz.append(paintball)
# 		Distribution.BULLSEYE: # 12
# 			var num_targets = properties.num_spots
# 			var num_rings = properties.num_rings
			
# 			if num_rings <= 0 or color_list.size() == 0:
# 				return

# 			for i in range(num_targets):
# 				var target_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 				var start_size = rand_range(properties.size_min, properties.size_max)

# 				for r in range(num_rings):
# 					var ring_size = start_size * (1.0 - float(r) / num_rings)
# 					var ring_color = color_list[r % color_list.size()]
					
# 					var paintball = _create_paintball(
# 						target_center, ring_size, properties, affected_ballz, [ring_color], outline_color_list, texture_list
# 					)
# 					paintballz.append(paintball)
# 		Distribution.STRIPES: # 15
# 			var feed_rate = properties.stripe_feed_rate
# 			var kill_rate = properties.stripe_kill_rate
# 			var timestep = properties.stripe_timestep

# 			var diffusion_a = properties.diffusion_a
# 			var diffusion_b = properties.diffusion_b

# 			var grid_size = 32
# 			var grid = []
# 			grid.resize(grid_size * grid_size)
# 			for i in range(grid_size * grid_size):
# 				grid[i] = {"a": 1.0, "b": 0.0}

# 			var center = grid_size / 2
# 			grid[center * grid_size + center].b = 1.0

# 			for time in range(100):
# 				var next_grid = []
# 				next_grid.resize(grid_size * grid_size)
# 				for i in range(grid_size * grid_size):
# 					next_grid[i] = grid[i].duplicate()

# 				for x in range(1, grid_size - 1):
# 					for y in range(1, grid_size - 1):
# 						var i = y * grid_size + x
# 						var a = grid[i].a
# 						var b = grid[i].b

# 						var laplace_a = (grid[i-1].a + grid[i+1].a + grid[i-grid_size].a + grid[i+grid_size].a) - 4 * a
# 						var laplace_b = (grid[i-1].b + grid[i+1].b + grid[i-grid_size].b + grid[i+grid_size].b) - 4 * b

# 						var reaction = a * b * b
# 						var next_a = a + (diffusion_a * laplace_a - reaction + feed_rate * (1.0 - a)) * timestep
# 						var next_b = b + (diffusion_b * laplace_b + reaction - (kill_rate + feed_rate) * b) * timestep

# 						next_grid[i].a = clamp(next_a, 0, 1)
# 						next_grid[i].b = clamp(next_b, 0, 1)
# 				grid = next_grid

# 			for i in range(properties.num_spots):
# 				var u = randf()
# 				var v = randf()
				
# 				var grid_x = int(u * (grid_size - 1))
# 				var grid_y = int(v * (grid_size - 1))
				
# 				var cell = grid[grid_y * grid_size + grid_x]

# 				if cell.b > 0.5:
# 					var theta = u * 2 * PI
# 					var phi = acos(clamp(2 * v - 1, -1.0, 1.0))
# 					var x = sin(phi) * cos(theta)
# 					var y = sin(phi) * sin(theta)
# 					var z = cos(phi)
# 					var pos = Vector3(x,y,z)

# 					var size = rand_range(properties.size_min, properties.size_max)
					
# 					var paintball = _create_paintball(
# 						pos, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 					)
# 					paintballz.append(paintball)
# 		Distribution.LEOPARD: # 13
# 				if color_list.size() < 2:
# 					push_warning("Leopard mode requires at least 2 colors (outer and inner)")
# 					return

# 				var color_pairs = []
# 				if properties.leopard_use_paired_colors:
# 					for i in range(0, color_list.size() - 1, 2):
# 						color_pairs.append([color_list[i], color_list[i+1]])
# 					if color_pairs.empty():
# 						push_warning("Paired Colors enabled, but no valid outer/inner pairs were found")
# 						return

# 				var spot_noise = OpenSimplexNoise.new()
# 				spot_noise.seed = randi()
# 				spot_noise.period = 2.0

# 				var num_spots_to_make = properties.num_spots
# 				for i in range(num_spots_to_make):
# 					var spot_center = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 					if spot_center.length_squared() == 0: spot_center = Vector3.UP
					
# 					var basis = _get_basis_from_normal(spot_center)
					
# 					var spot_angle_rad = rand_range(properties.leopard_radius_min, properties.leopard_radius_max)
					
# 					var paintball_size = rand_range(properties.size_min, properties.size_max)

# 					var color_outline = 0
# 					var color_fill = 0
# 					if properties.leopard_use_paired_colors:
# 						var chosen_pair = color_pairs[randi() % color_pairs.size()]
# 						color_outline = chosen_pair[0]
# 						color_fill = chosen_pair[1]
# 					else:
# 						color_outline = color_list[randi() % color_list.size()]
# 						color_fill = color_list[randi() % color_list.size()]
# 						while color_fill == color_outline:
# 							color_fill = color_list[randi() % color_list.size()]

# 					var outline_points = 20
# 					for j in range(outline_points):
# 						if randf() > properties.leopard_completeness:
# 							continue
						
# 						var irregularity = properties.leopard_irregularity
# 						var current_radius = spot_angle_rad * rand_range(1.0 - irregularity, 1.0 + irregularity)
						
# 						var circle_angle = (float(j) / outline_points) * TAU
# 						var direction = (basis.x * cos(circle_angle) + basis.z * sin(circle_angle))
# 						var pos = spot_center.slerp(spot_center + direction.normalized(), current_radius)

# 						var paintball = _create_paintball(
# 							pos, paintball_size, properties, affected_ballz, [color_outline], outline_color_list, texture_list
# 						)
# 						paintballz.append(paintball)

# 					var fill_points = 25
# 					for j in range(fill_points):
# 						var random_radius = sqrt(randf())
# 						var random_angle = rand_range(0, TAU)
						
# 						var noise_val = spot_noise.get_noise_1d(random_angle * spot_noise.period)
# 						var noise_radius = random_radius * (0.7 + 0.3 * noise_val)
						
# 						var fill_radius_rad = noise_radius * spot_angle_rad

# 						var direction = (basis.x * cos(random_angle) + basis.z * sin(random_angle))
# 						var pos = spot_center.slerp(spot_center + direction.normalized(), fill_radius_rad)
						
# 						var paintball = _create_paintball(
# 							pos, paintball_size, properties, affected_ballz, [color_fill], outline_color_list, texture_list
# 						)
# 						paintballz.append(paintball)

# 					var inner_dots = randi() % 3 + 1
# 					for j in range(inner_dots):
# 						var random_radius = randf() * spot_angle_rad * 0.7
# 						var random_angle = rand_range(0, TAU)

# 						var direction = (basis.x * cos(random_angle) + basis.z * sin(random_angle))
# 						var pos = spot_center.slerp(spot_center + direction.normalized(), random_radius)

# 						var paintball = _create_paintball(
# 							pos, paintball_size * 0.6, properties, affected_ballz, [color_outline], outline_color_list, texture_list
# 						)
# 						paintballz.append(paintball)
# 		Distribution.RAINBOW: # 14
# 			var num_rainbows = properties.num_spots
			
# 			for i in range(num_rainbows):
# 				var paintball_size = rand_range(properties.size_min, properties.size_max)
				
# 				var arc_start = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 				if arc_start.length_squared() == 0: arc_start = Vector3.FORWARD
				
# 				var basis = _get_basis_from_normal(arc_start)
				
# 				var arc_direction = basis.x
				
# 				var rotation_axis = arc_start.cross(arc_direction).normalized()
				
# 				rotation_axis = rotation_axis.slerp(arc_start, properties.rainbow_curvature)
				
# 				rotation_axis = rotation_axis.rotated(arc_start, deg2rad(properties.rainbow_angle))

# 				for color_index in range(color_list.size()):
# 					var current_color = color_list[color_index]
					
# 					var offset_axis = rotation_axis.cross(arc_start).normalized()
# 					var offset_dist = (float(color_index) - float(color_list.size() - 1) / 2.0) * properties.rainbow_width
# 					var band_offset_rad = atan(offset_dist * paintball_size * 0.1)
					
# 					var band_start = arc_start.rotated(offset_axis, band_offset_rad)
# 					var band_axis = rotation_axis.rotated(offset_axis, band_offset_rad)

# 					var arc_length_rad = PI * properties.rainbow_length
					
# 					var num_paintballs_in_line = 0
# 					var angular_diameter = 2 * atan(paintball_size * 0.01)
# 					if angular_diameter > 0:
# 						num_paintballs_in_line = floor(arc_length_rad / (angular_diameter * 0.9))

# 					for p_idx in range(num_paintballs_in_line):
# 						var step_angle = (float(p_idx) / max(1, num_paintballs_in_line - 1)) * arc_length_rad
# 						var pos = band_start.rotated(band_axis, step_angle)
						
# 						var paintball = _create_paintball(
# 							pos, paintball_size, properties, affected_ballz, [current_color], outline_color_list, texture_list
# 						)
# 						paintballz.append(paintball)
# 		_: # All other simple modes (UNIFORM, SPIRAL, BANDS, GRID, CHECKERBOARD, FOCUSED, HALFIE)
# 			for i in range(properties.num_spots):
# 				var size = rand_range(properties.size_min, properties.size_max)
# 				var position = Vector3()

# 				if distribution_mode == Distribution.UNIFORM: # 0
# 					position = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 				elif distribution_mode == Distribution.SPIRAL: # 1
# 					var turns = properties.spiral_turns
# 					var angle = i * (2 * PI * turns / properties.num_spots)
# 					var y = lerp(-1, 1, float(i) / properties.num_spots)
# 					var r = sqrt(1 - y*y)
# 					var x = r * cos(angle)
# 					var z = r * sin(angle)
# 					position = Vector3(x, y, z)
# 				elif distribution_mode == Distribution.BANDS: # 3: Consolidated Bands
# 					var num_bands = properties.num_bands
# 					if num_bands > 0:
# 						var band_angle = deg2rad(properties.band_angle)
# 						var band_offset = properties.band_offset
# 						var band_spacing = properties.band_spacing
# 						var is_vertical = properties.band_direction == 1 # 0=Horizontal, 1=Vertical

# 						var band_index = floor(i * num_bands / properties.num_spots)
# 						var total_width = (num_bands - 1) * band_spacing
# 						var band_pos = lerp(-total_width / 2.0, total_width / 2.0, float(band_index) / max(1, num_bands - 1))

# 						band_pos += band_offset

# 						var y = band_pos
# 						var angle = rand_range(0, TAU)
# 						var r = sqrt(max(0, 1.0 - y*y))
# 						var x = r * cos(angle)
# 						var z = r * sin(angle)

# 						var p = Vector3(x, y, z)

# 						if is_vertical:
# 							p = Vector3(y, x, z) # Swap coordinates for vertical alignment

# 						p = p.rotated(Vector3.FORWARD, band_angle)
# 						position = p
# 				elif distribution_mode == Distribution.GRID: # 5
# 					var grid_size = properties.grid_size
# 					if grid_size > 0:
# 						var u = float(i % int(grid_size)) / grid_size
# 						var v = float(floor(i / grid_size)) / grid_size
# 						var theta = u * 2 * PI
# 						var acos_arg = clamp(2 * v - 1, -1.0, 1.0)
# 						var phi = acos(acos_arg)
# 						var x = sin(phi) * cos(theta)
# 						var y = sin(phi) * sin(theta)
# 						var z = cos(phi)
# 						position = Vector3(x, y, z)
# 				elif distribution_mode == Distribution.CHECKERBOARD: # 6
# 					var grid_size = int(properties.grid_size)
# 					if grid_size > 0 and properties.num_spots > 0:
# 						var num_on_squares = ceil(grid_size * grid_size / 2.0)
# 						var spots_per_square = int(ceil(properties.num_spots / num_on_squares))

# 						for v_idx in range(grid_size):
# 							for u_idx in range(grid_size):
# 								if (u_idx + v_idx) % 2 == 1:
# 									for _j in range(spots_per_square):
# 										var u_start = float(u_idx) / grid_size
# 										var u_end = float(u_idx + 1) / grid_size
# 										var v_start = float(v_idx) / grid_size
# 										var v_end = float(v_idx + 1) / grid_size

# 										var rand_u = rand_range(u_start, u_end)
# 										var rand_v = rand_range(v_start, v_end)

# 										var theta = rand_u * TAU
# 										var cos_phi = lerp(1.0, -1.0, rand_v)
# 										var phi = acos(cos_phi)
										
# 										var x = sin(phi) * cos(theta)
# 										var z = sin(phi) * sin(theta)
# 										var y = cos(phi)
										
# 										var p = _create_paintball(
# 											Vector3(x,y,z), size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 										)
# 										paintballz.append(p)
# 						continue 
# 				elif distribution_mode == Distribution.POLE_FOCUSED: # 9
# 					var y = 1.0 - pow(randf(), 2)
# 					if randf() > 0.5:
# 						y = -y
# 					var angle = rand_range(0, 2 * PI)
# 					var r = sqrt(1 - y*y)
# 					var x = r * cos(angle)
# 					var z = r * sin(angle)
# 					position = Vector3(x, y, z)
# 				elif distribution_mode == Distribution.EQUATOR_FOCUSED: # 10
# 					var y = rand_range(-0.2, 0.2)
# 					var angle = rand_range(0, 2 * PI)
# 					var r = sqrt(1 - y*y)
# 					var x = r * cos(angle)
# 					var z = r * sin(angle)
# 					position = Vector3(x, y, z)
# 				elif distribution_mode == Distribution.HALFIE: # 11
# 					var axis = properties.halfie_axis
# 					var side = properties.halfie_side
# 					var p = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
# 					if side == 0: # Positive
# 						p[axis] = abs(p[axis])
# 					else: # Negative
# 						p[axis] = -abs(p[axis])
# 					position = p.normalized()

# 				var paintball = _create_paintball(
# 					position, size, properties, affected_ballz, color_list, outline_color_list, texture_list
# 				)
# 				paintballz.append(paintball)

# 	emit_signal("randomize_auto_paintballz", paintballz)