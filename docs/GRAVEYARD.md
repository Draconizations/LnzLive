Function graveyard after major refactors...


```

# v1 before refactor
# func generate_balls(all_ball_data: Dictionary, species: int, texture_list: Array, palette, new_create: bool, no_texture_rotate := []):
# 	var ball_data = all_ball_data.balls
# 	var addball_data = all_ball_data.addballs
# 	var paintball_data = all_ball_data.paintballs
# 	var omissions = all_ball_data.omissions

# 	var ball_lookup = {}
# 	for k in ball_data:
# 		ball_lookup[k] = ball_data[k]
# 	for k in addball_data:
# 		ball_lookup[k] = addball_data[k]

# 	var root = get_root()
# 	var balls_parent = root.get_node("petholder/balls")
# 	var paintballs_parent = root.get_node("petholder/paintballs")
# 	var addballs_parent = root.get_node("petholder/addballs")

# 	# Figure out belly position
# 	var belly_position

# 	if species == KeyBallsData.Species.DOG:
# 		belly_position = ball_data[KeyBallsData.belly_dog].position
# 	elif species == KeyBallsData.Species.CAT:
# 		belly_position = ball_data[KeyBallsData.belly_cat].position
# 	elif species == KeyBallsData.Species.BABY:
# 		belly_position = ball_data[KeyBallsData.belly_bab].position
# 	else:
# 		if ball_data.size() > 0:
# 			belly_position = ball_data[ball_data.keys()[0]].position
# 		else:
# 			belly_position = Vector3.ZERO

# 	belly_position.y *= -1
# 	belly_position *= pixel_world_size

# 	# If we're creating everything fresh, clear out old visuals
# 	if new_create:
# 		for c in balls_parent.get_children():
# 			# balls_parent.remove_child(c)
# 			c.queue_free()
# 		for c in paintballs_parent.get_children():
# 			# paintballs_parent.remove_child(c)
# 			c.queue_free()
# 		for c in addballs_parent.get_children():
# 			# addballs_parent.remove_child(c)
# 			c.queue_free()

# 		ball_map.clear()

# 		for key in ball_data:
# 			ball_map[key] = ball_scene.instance()
# 		for key in addball_data:
# 			ball_map[key] = ball_scene.instance()
		
# 		paintball_map.clear()
# 		eyelid_dir_map.clear()

# 	# Identify eyes so we can handle them like paintballs if needed
# 	var eyes = {}
# 	if lnz != null and not lnz.custom_eyes.empty():
# 		eyes = lnz.custom_eyes
# 		print("[INFO] dog_generator: using custom eyes mapping: ", eyes)
# 	else:
# 		if species == KeyBallsData.Species.DOG:
# 			eyes = KeyBallsData.eyes_dog
# 		elif species == KeyBallsData.Species.CAT:
# 			eyes = KeyBallsData.eyes_cat
# 		else:
# 			eyes = KeyBallsData.eyes_bab

# 	# Generate base ballz
# 	for key in ball_data:
# 		var ball = ball_data[key]
# 		var visual_ball

# 		# If the ball key is in the "eyes" dictionary, treat it like a paintball
# 		if key in eyes:
# 			var base_key = eyes[key]

# 			if not ball_lookup.has(base_key):
# 				continue

# 			var base_def = ball_lookup[base_key]
# 			var base_no = base_def.ball_no
# 			var base_node = ball_map.get(base_no)

# 			if new_create:
# 				visual_ball = paintball_scene.instance()
# 				visual_ball.add_to_group("balls")
# 				visual_ball.ball_no = ball.ball_no
# 				visual_ball.z_add = 10
# 				visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
# 				visual_ball.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
# 				visual_ball.connect("ball_selected", self, "signal_ball_selected")
# 				visual_ball.set_species(species, is_babyz_mode)

# 				if base_node:
# 					base_node.add_child(visual_ball)
# 					visual_ball.set_surface_normal(Vector3(0, 0, -1))
# 				else:
# 					paintballs_parent.add_child(visual_ball)
# 					visual_ball.set_surface_normal(Vector3(0, 0, -1))
				
# 				visual_ball.set_owner(root)
# 			else:
# 				visual_ball = ball_map[key]

# 			# Parent ball so we know its center
# 			var base_ball = ball_lookup[eyes[key]]
# 			visual_ball.base_ball_size = base_ball.size
			
# 			var base_pos = base_ball.position
# 			base_pos.y *= -1.0
# 			base_pos *= pixel_world_size
# 			visual_ball.base_ball_position = base_pos

# 			if base_node:
# 				var radius = (base_ball.size / 2.0) * pixel_world_size
				
# 				visual_ball.transform.origin = Vector3(0, 0, -radius)
# 			else:
# 				var pos = ball.position
# 				pos.y *= -1.0
# 				visual_ball.transform.origin = pos * pixel_world_size

# 			if new_create:
# 				if ball.texture_id >= 0 and ball.texture_id < texture_list.size():
# 					var tex_info_eye = texture_list[ball.texture_id]
# 					var tex_load_eye = load_texture_from_list(ball.texture_id, texture_list)
# 					if tex_load_eye:
# 						visual_ball.texture = tex_load_eye
# 						visual_ball.transparent_color = texture_list[ball.texture_id].transparent_color
# 						if tex_info_eye.has("texture_size") and tex_info_eye.texture_size != null:
# 							visual_ball.texture_size = tex_info_eye.texture_size
# 				visual_ball.color_index = ball.color_index
# 				visual_ball.outline_color_index = ball.outline_color_index
# 				visual_ball.ball_size = get_real_ball_size(ball.size)
# 				visual_ball.outline = ball.outline
# 				visual_ball.fuzz_amount = clamp(ball.fuzz / 2, 0, 5)
# 				visual_ball.palette = palette

# 				var shader_mat = visual_ball.get_node("MeshInstance").material_override
# 				var is_atlas = shader_mat.get_shader_param("is_atlas")
# 				shader_mat.set_shader_param("should_quantize", is_babyz_mode and not is_atlas)

# 				if no_texture_rotate.has(int(key)):
# 					visual_ball.set_tile_texture(false)

# 			visual_ball.rotation_degrees = ball.rotation

# 			# Initialize eyelid properties
# 			if base_node:
# 				# Mirror sign by world X: left eye x<0 = -1, right = +1
# 				var eye_dir = 1.0
# 				if base_node.global_transform.origin.x < 0:
# 					eye_dir = -1.0
# 				eyelid_dir_map[base_no] = eye_dir

# 				# Initialize eyelids
# 				if eyelid_mode == 1:
# 					# “none”, turn off the lid
# 					base_node.set_eyelid_color(-1)
# 				else:
# 					# color + tilt by eye_dir * EYELID_TILTS
# 					base_node.set_eyelid_color(lnz.eyelid_color)
# 					var tilt_rad = deg2rad(EYELID_TILTS[eyelid_mode])
# 					base_node.set_eyelid_rotation(eye_dir * tilt_rad)

# 				if lnz.eyelash_lengths.size() > 0:
# 					base_node.set_eyelash_lengths(lnz.eyelash_lengths)
# 					base_node.set_eyelash_angle(lnz.eyelash_angle)
# 					base_node.set_eyelash_spacing(lnz.eyelash_spacing)

# 					var lash_col = (
# 						lnz.eyelash_color
# 						if lnz.eyelash_color != -1
# 						else lnz.eyelid_color
# 					)
# 					base_node.set_eyelash_color(lash_col)

# 			ball_map[ball.ball_no] = visual_ball

# 		else:
# 			if new_create:
# 				visual_ball = ball_scene.instance()
# 				visual_ball.add_to_group("balls")
# 				visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
# 				visual_ball.connect("ball_mouse_exit", self, "signal_ball_mouse_exit")
# 				visual_ball.connect("ball_selected", self, "signal_ball_selected")

# 				balls_parent.add_child(visual_ball)
# 				visual_ball.set_owner(root)

# 				var skip_texture_rotation = no_texture_rotate.has(int(key))
# 				visual_ball.set_tile_texture(!skip_texture_rotation)

# 				#visual_ball.species = species
# 				visual_ball.set_species(species, is_babyz_mode)

# 			else:
# 				visual_ball = ball_map[key]

# 			visual_ball.ball_no = ball.ball_no
# 			visual_ball.pet_center = belly_position

# 			var pos_n = ball.position
# 			pos_n.y *= -1.0
# 			visual_ball.transform.origin = pos_n * pixel_world_size

# 			if new_create:
# 				if ball.texture_id >= 0 and ball.texture_id < texture_list.size():
# 					var tex_info_base = texture_list[ball.texture_id]
# 					var text_load_base = load_texture_from_list(ball.texture_id, texture_list)
# 					if text_load_base:
# 						visual_ball.texture = text_load_base
# 						visual_ball.transparent_color = tex_info_base.transparent_color
# 						if tex_info_base.has("texture_size") and tex_info_base.texture_size != null:
# 							visual_ball.texture_size = tex_info_base.texture_size
# 				visual_ball.color_index = ball.color_index
# 				visual_ball.outline_color_index = ball.outline_color_index
# 				visual_ball.ball_size = get_real_ball_size(ball.size)
# 				visual_ball.outline = ball.outline
# 				visual_ball.fuzz_amount = clamp(ball.fuzz / 2, 0, 5)
# 				visual_ball.palette = palette

# 			visual_ball.rotation_degrees = ball.rotation
# 			ball_map[ball.ball_no] = visual_ball

# 		# Handle omissions
# 		var is_omitted = omissions.has(key)
# 		if key in eyes and omissions.has(eyes[key]):
# 			is_omitted = true

# 		if is_omitted:
# 			ball_map[ball.ball_no].omitted = true

# 			if draw_omitted_balls:
# 				ball_map[ball.ball_no].visible_override = true
# 			else:
# 				ball_map[ball.ball_no].visible_override = false
# 				#ball_map[ball.ball_no].visible = false
# 		else:
# 			# Respect user toggles
# 			if !draw_balls:
# 				ball_map[ball.ball_no].visible_override = false

# 	# Declare addballz
# 	for key in addball_data:
# 		var add_ball = addball_data[key]
# 		var add_visual_ball

# 		if new_create:
# 			add_visual_ball = ball_scene.instance()
# 			add_visual_ball.ball_no = add_ball.ball_no
# 			ball_map[add_ball.ball_no] = add_visual_ball
# 		else:
# 			add_visual_ball = ball_map.get(key, null)

# 	# Generate addballz
# 	for key in addball_data:
# 		var add_ball = addball_data[key]
# 		var add_visual_ball = ball_map[key]

# 		if add_visual_ball == null:
# 			continue

# 		if new_create:
# 			var parent_node = ball_map.get(add_ball.base)
# 			if parent_node:
# 				parent_node.add_child(add_visual_ball)
# 			else:
# 				addballs_parent.add_child(add_visual_ball)

# 			add_visual_ball.set_owner(root)
# 			add_visual_ball.add_to_group("addballs")
# 			add_visual_ball.z_add = add_ball.size / 10.0
# 			add_visual_ball.ball_size = add_ball.size
# 			add_visual_ball.connect("ball_mouse_enter", self, "signal_ball_mouse_enter")
# 			add_visual_ball.connect("ball_selected", self, "signal_ball_selected")
# 			add_visual_ball.connect("ball_deleted", self, "signal_ball_deleted")

# 			var skip_texture_rotation = no_texture_rotate.has(int(key))
# 			add_visual_ball.set_tile_texture(!skip_texture_rotation)

# 			#add_visual_ball.species = species
# 			add_visual_ball.set_species(species, is_babyz_mode)

# 		var add_pos = add_ball.position
# 		add_pos.y *= -1.0
# 		add_visual_ball.transform.origin = add_pos * pixel_world_size

# 		if new_create:
# 			add_visual_ball.outline = add_ball.outline
# 			add_visual_ball.fuzz_amount = clamp(add_ball.fuzz / 2, 0, 5)
# 			add_visual_ball.ball_no = add_ball.ball_no
# 			add_visual_ball.base_ball_no = add_ball.base
# 			add_visual_ball.outline_color_index = add_ball.outline_color_index
# 			if add_ball.texture_id >= 0 and add_ball.texture_id < texture_list.size():
# 				var tex_info_add = texture_list[add_ball.texture_id]
# 				var text_load_add = load_texture_from_list(add_ball.texture_id, texture_list)
# 				if text_load_add:
# 					add_visual_ball.texture = text_load_add
# 					add_visual_ball.transparent_color = tex_info_add.transparent_color
# 					if tex_info_add.has("texture_size") and tex_info_add.texture_size != null:
# 						add_visual_ball.texture_size = tex_info_add.texture_size
# 			add_visual_ball.color_index = add_ball.color_index
# 			add_visual_ball.palette = palette

# 		ball_map[add_ball.ball_no] = add_visual_ball

# 		var is_special_ball = is_special_baby_ball(species, add_ball.ball_no)
# 		if is_special_ball:
# 			add_visual_ball.add_to_group("special_balls")
# 			add_visual_ball.visible = draw_special_balls
# 		# else:
# 		# 	add_visual_ball.visible = draw_addballs

# 		# If user hid addballs globally or if omitted
# 		if !draw_addballs:
# 			add_visual_ball.visible_override = false
# 		if omissions.has(key):
# 			add_visual_ball.omitted = true
# 			if draw_omitted_balls:
# 				add_visual_ball.visible_override = true
# 			else:
# 				add_visual_ball.visible_override = false
# 				add_visual_ball.visible = false

# 	# Generate paintballz

# 	# Merge base ball + addball data so we can locate the base size
# 	var merged_dict = {}
	
# 	for v in ball_data:
# 		merged_dict[v] = ball_data[v]

# 	for v in addball_data:
# 		merged_dict[v] = addball_data[v]

# 	for key in paintball_data:
# 		if !ball_map.has(key):
# 			continue

# 		var base_ball = merged_dict[key]
# 		var paint_list: Array = paintball_data[key]
# 		paint_list.invert()  # preserve layered order

# 		var count = 0
# 		for paintball in paint_list:
# 			var final_size = base_ball.size * (paintball.size / 100.0)
# 			final_size -= 1 - fmod(final_size, 2)

# 			var pb_visual_ball: Spatial
# 			if new_create:
# 				pb_visual_ball = paintball_scene.instance()
# 			else:
# 				pb_visual_ball = paintball_map[key][count]

# 			if new_create:
# 				ball_map[key].add_child(pb_visual_ball)
# 				pb_visual_ball.set_owner(root)
# 				pb_visual_ball.add_to_group("paintballs")
# 				pb_visual_ball.connect(
# 					"paintball_mouse_enter", self, "signal_paintball_mouse_enter"
# 				)
# 				pb_visual_ball.connect("paintball_mouse_exit", self, "signal_paintball_mouse_exit")

# 				#pb_visual_ball.species = species
# 				pb_visual_ball.set_species(species, is_babyz_mode)

# 				####
# 				# normalised_position (direction from ball center) to shader
# 				var pb_normal = paintball.normalised_position
# 				pb_normal.y *= -1.0
# 				pb_visual_ball.set_surface_normal(pb_normal)
# 				####

# 				if paintball.texture_id >= 0 and paintball.texture_id < texture_list.size():
# 					var tex_info_pb = texture_list[paintball.texture_id]
# 					var tex_load_pb = load_texture_from_list(paintball.texture_id, texture_list)
# 					if tex_load_pb:
# 						pb_visual_ball.texture = tex_load_pb
# 						pb_visual_ball.transparent_color = tex_info_pb.transparent_color
# 						if tex_info_pb.has("texture_size") and tex_info_pb.texture_size != null:
# 							pb_visual_ball.texture_size = tex_info_pb.texture_size
# 				pb_visual_ball.color_index = paintball.color_index
# 				pb_visual_ball.palette = palette
# 			else:
# 				pb_visual_ball = paintball_map[key][count]

# 			pb_visual_ball.base_ball_position = ball_map[key].global_transform.origin
# 			pb_visual_ball.transform.origin = (
# 				paintball.normalised_position
# 				* Vector3(1, -1, 1)
# 				* (base_ball.size / 2.0)
# 				* pixel_world_size
# 			)
# 			pb_visual_ball.ball_size = final_size
# 			pb_visual_ball.base_ball_size = base_ball.size
# 			pb_visual_ball.outline_color_index = paintball.outline_color_index
# 			pb_visual_ball.outline = paintball.outline
# 			pb_visual_ball.fuzz_amount = clamp(paintball.fuzz / 2, 0, 5)
# 			var base_z = ball_map[key].z_add if "z_add" in ball_map[key] else 0.0
# 			pb_visual_ball.z_add = (base_z * 20.0) + 10.0 + float(count)
# 			pb_visual_ball.base_ball_no = paintball.base

# 			if omissions.has(key):
# 				if draw_omitted_balls:
# 					pb_visual_ball.visible_override = true
# 				else:
# 					pb_visual_ball.visible_override = false
# 					pb_visual_ball.visible = false
# 			elif !draw_paintballs:
# 				pb_visual_ball.visible_override = false

# 			if !draw_paintballs:
# 				pb_visual_ball.visible_override = false

# 			var ar = paintball_map.get(key, [])
# 			if new_create:
# 				ar.append(pb_visual_ball)
# 				paintball_map[key] = ar

# 			count += 1

# 	for ball_no in ball_map.keys():
# 		var node = ball_map[ball_no]
# 		if node and node is Spatial:
# 			_orig_world_pos[ball_no] = node.global_transform.origin
# 			#print("[INFO] dog_generator: munge_balls: saved raw WORLD position for ball %d: %s" % [ball_no, _orig_world_pos[ball_no]])

```


```
# too many draw calls

# func _draw_axis_gizmos(reference_ball: Spatial):
# 	if not is_instance_valid(reference_ball):
# 		return

# 	var hotkey_x = Input.is_key_pressed(KEY_X)
# 	var hotkey_y = Input.is_key_pressed(KEY_Y)
# 	var hotkey_z = Input.is_key_pressed(KEY_Z)
# 	var any_hotkey = hotkey_x or hotkey_y or hotkey_z

# 	var ui_active_x = false
# 	var ui_active_y = false
# 	var ui_active_z = false

# 	if move_mode and is_instance_valid(move_mode_settings_instance):
# 		match move_mode_settings_instance.current_constraint_mode:
# 			"LockX": ui_active_x = true
# 			"LockY": ui_active_y = true
# 			"LockZ": ui_active_z = true
# 			"LockXY":
# 				ui_active_x = true
# 				ui_active_y = true
# 			"LockXZ":
# 				ui_active_x = true
# 				ui_active_z = true
# 			"LockYZ":
# 				ui_active_y = true
# 				ui_active_z = true
# 			"Free":
# 				ui_active_x = false
# 				ui_active_y = false
# 				ui_active_z = false

# 	var show_x = hotkey_x if any_hotkey else ui_active_x
# 	var show_y = hotkey_y if any_hotkey else ui_active_y
# 	var show_z = hotkey_z if any_hotkey else ui_active_z

# 	if not is_dragging and not any_hotkey:
# 		return

# 	var origin_3d = reference_ball.global_transform.origin
# 	if camera.is_position_behind(origin_3d):
# 		return

# 	var origin_2d_raw = camera.unproject_position(origin_3d)
# 	var origin_2d = (origin_2d_raw - Vector2(500, 500)) * tex.rect_scale + (rect_size / 2.0)

# 	var length = 150.0
# 	var width = 2.0

# 	if show_x:
# 		_draw_gizmo_line(origin_3d, Vector3(1, 0, 0), Color.red, origin_2d, length, width, "X", false)
# 	if show_y:
# 		_draw_gizmo_line(origin_3d, Vector3(0, 1, 0), Color.green, origin_2d, length, width, "Y", true)
# 	if show_z:
# 		_draw_gizmo_line(origin_3d, Vector3(0, 0, 1), Color.blue, origin_2d, length, width, "Z", false)

# func _get_projected_end_point(origin_3d: Vector3, dir_3d: Vector3, origin_2d: Vector2, length: float) -> Vector2:
# 	var target_3d = origin_3d + (dir_3d * 0.1)
# 	var target_2d_raw = camera.unproject_position(target_3d)
# 	var target_2d = (target_2d_raw - Vector2(500, 500)) * tex.rect_scale + (rect_size / 2.0)

# 	var dir_2d = (target_2d - origin_2d).normalized()
# 	return origin_2d + (dir_2d * length)

# func _draw_axis_label(pos: Vector2, text: String, color: Color):
# 	var font = get_font("font")
# 	var text_size = font.get_string_size(text)
# 	var text_pos = pos - (text_size / 2.0) + Vector2(0, -10)

# 	draw_string(font, text_pos + Vector2(1, 1), text, Color.black)
# 	draw_string(font, text_pos, text, color)

# func _draw_gizmo_line(origin_3d: Vector3, axis_dir: Vector3, color: Color, origin_2d: Vector2, length: float, width: float, label: String, invert_labels: bool):
# 	var pos_end = _get_projected_end_point(origin_3d, axis_dir, origin_2d, length)
# 	var neg_end = _get_projected_end_point(origin_3d, -axis_dir, origin_2d, length)

# 	var pos_label = "-" + label if invert_labels else label
# 	var neg_label = label if invert_labels else "-" + label

# 	draw_line(origin_2d, pos_end, color, width, true)
# 	_draw_axis_label(pos_end, pos_label, color)

# 	draw_line(origin_2d, neg_end, color, width, true)
# 	_draw_axis_label(neg_end, neg_label, color)
```


```
# NOTE: DEFUNCT
# func _on_ToolsMenu_move_head(x, y, z):
# 	save_backup()
# 	var head_balls: Array
# 	if KeyBallsData.species == KeyBallsData.Species.CAT:
# 		head_balls = KeyBallsData.head_ext_cat.duplicate()
# 	else:
# 		head_balls = KeyBallsData.head_ext_dog.duplicate()
# 	var section_find = search('[Move]', 0, 0, 0)
# 	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
# 	var i = 0
# 	while true:
# 		var line = get_line(start_of_section + i).lstrip(" ")
# 		if line.begins_with(";") or line.empty():
# 			i += 1
# 			continue
# 		elif line.begins_with("["):
# 			break
			
# 		var delimiters = [", ", ",", "\t", " "]
# 		var parsed_line = []
# 		for delim in delimiters:
# 			if line.split(delim).size() > 2:
# 				parsed_line = line.split(delim, false)
# 				break

# 		if !(parsed_line[0].to_int() in head_balls):
# 			i += 1
# 			continue
# 		head_balls.erase(parsed_line[0].to_int())
# 		var n = 0
# 		var final_line = ""
# 		for r_item in parsed_line:
# 			var item = r_item
# 			if n == 1:
# 				final_line += str(item.to_int() + x) + " "
# 			elif n == 2:
# 				final_line += str(item.to_int() + y) + " "
# 			elif n == 3:
# 				final_line += str(item.to_int() + z) + " "
# 			else:
# 				final_line += item + " "
# 			n += 1
# 		set_line(start_of_section + i, final_line)
# 		i += 1
	
# 	# now insert any we missed
# 	for b in head_balls:
# 		cursor_set_line(start_of_section + i)
# 		cursor_set_column(0)
# 		insert_text_at_cursor(str(b) + " " + str(x) + " " + str(y) + " " + str(z) + "\n")
	
# 	save_file()

```

```
# NOTE: NOT IMPLEMENTED
# func _add_or_update_override(section_name, ball_no, values, value_indices):
# 	var section_find = search(section_name, 0, 0, 0)
# 	var start_line
# 	var end_line

# 	if section_find.empty():
# 		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
# 		var all_lines = get_text().split("\n")
# 		all_lines.insert(first_section, section_name)
# 		all_lines.insert(first_section + 1, "")
# 		text = all_lines.join("\n")
# 		_set_text_preserve(text)
# 		section_find = search(section_name, 0, 0, 0)

# 	start_line = section_find[SEARCH_RESULT_LINE] + 1
# 	end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
# 	if end_line == -1:
# 		end_line = get_line_count()

# 	var delim = _detect_delimiter(start_line, end_line)
# 	var line_updated = false
# 	for i in range(start_line, end_line):
# 		var line = get_line(i).strip_edges()
# 		if line.begins_with(str(ball_no) + delim):
# 			var parts = split_line(line)
# 			var max_index = value_indices.max()
# 			while parts.size() <= max_index:
# 				parts.append("0")

# 			var value_idx = 0
# 			for target_idx in value_indices:
# 				parts[target_idx] = str(values[value_idx])
# 				value_idx += 1

# 			set_line(i, parts.join(delim))
# 			line_updated = true
# 			break

# 	if not line_updated:
# 		var max_index = 0
# 		if value_indices.size() > 0:
# 			max_index = value_indices.max()

# 		var new_parts = []
# 		new_parts.resize(max_index + 1)
# 		for i in range(new_parts.size()):
# 			new_parts[i] = "0"
# 		new_parts[0] = str(ball_no)

# 		var value_idx = 0
# 		for target_idx in value_indices:
# 			if value_idx < values.size():
# 				new_parts[target_idx] = str(values[value_idx])
# 				value_idx += 1

# 		var new_line = new_parts.join(delim)
# 		var insert_line = _find_insertion_line(start_line, end_line)
# 		_insert_text_at_cursor_at_line(insert_line, new_line + "\n")

# NOTE: CHECK IF USED ANYMORE
# Inserts a base ball into [Omissions] if not present
# func _mark_base_ball_omitted(ball_no: int):
# 	var section = search("[Omissions]", 0, 0, 0)
# 	var start = section[SEARCH_RESULT_LINE] + 1

# 	# Scan section first to avoid modifying it while iterating
# 	var already_omitted = false
# 	var end = get_line_count()
# 	for i in range(start, end):
# 		var line = get_line(i).strip_edges()
# 		if line.begins_with("[") or line == "":
# 			break
# 		if int(line) == ball_no:
# 			already_omitted = true
# 			break

# 	if not already_omitted:
# 		_insert_text_at_line(start, str(ball_no) + "\n")
```

```
func collate_base_ball_data():
	var t_start = OS.get_ticks_msec()

	var ball_data_map = {}
	for ball in balls:
		ball_data_map[ball.ball_no] = ball
	return ball_data_map
	
	print("[TIME] dog_generator: collate_base_ball_data took " + str(OS.get_ticks_msec() - t_start) + "ms")
```