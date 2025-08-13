extends Control

onready var camera_holder = get_tree().root.get_node("Root/SceneRoot/ViewportContainer/Viewport/CameraHolder") as Spatial
onready var camera = camera_holder.get_node("Camera") as Camera
onready var ball_label = get_tree().root.get_node("Root/SceneRoot/BallLabel")
onready var helper_label = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/HelperContainer/VBoxContainer/HelperLabel")
onready var cube = get_tree().root.get_node("Root/PetRoot/MeshInstance") as Spatial
onready var tex = get_tree().root.get_node("Root/SceneRoot/ViewportContainer") as ViewportContainer
onready var help_popup = get_tree().root.get_node("Root/SceneRoot/HelpPopupDialog") as WindowDialog

var last_selected
var selecting_on = false
var active_selected_ball = null

var is_dragging = false
var drag_ball = null
var drag_offset = Vector3()
var pixel_world_size = 0.002

var drag_started_via_code := false
var pending_autodrag_addball_no := -1

var is_resizing = false
var original_lnz_size = 0
var original_scale = 1.0
var drag_start_pos = Vector2()

var linez_mode = false
var linez_start_ball = null

var paintball_mode = false
var paintball_target_ball = null
onready var paintball_settings_instance = preload("res://scenes/editor/PaintballSettings.tscn").instance()
onready var paintball_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/PaintballModeCheckBox")
onready var line_mode_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/LineModeCheckBox")
onready var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/LnzTextEdit")

var hand_neutral = load("res://resources/icons/ico_hand_neutral_2x.png")
var hand_move = load("res://resources/icons/ico_hand_move_2x.png")
var hand_pinch = load("res://resources/icons/ico_hand_pinch_2x.png")
var hand_stretch = load("res://resources/icons/ico_hand_stretch_2x.png")
var eyedropper = load("res://resources/icons/ico_tool_eyedropper_2x.png")
var smallbrush = load("res://resources/icons/ico_tool_paintbrush_2x.png")
var bigbrush = load("res://resources/icons/ico_tool_brush_2x.png")
var paintbucket = load("res://resources/icons/ico_tool_bucket_2x.png")
var rope = load("res://resources/icons/icon_line_mode.png")

const ZOOM_STEP := 1.2

func _ready():
	set_process_unhandled_key_input(true)
	set_process(true)

	var paintball_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/PaintballModeCheckBox")
	paintball_check_box.connect("toggled", self, "_on_paintball_mode_toggled")
	line_mode_check_box.connect("toggled", self, "_on_line_mode_toggled")

	var tools_menu = get_tree().root.get_node("Root/SceneRoot/ToolsMenu")
	tools_menu.connect("paintball_mode_for_ball_toggled", self, "_on_paintball_mode_for_ball_toggled")

	get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", paintball_settings_instance)
	paintball_settings_instance.connect("apply_paintballz", lnz_text_edit, "_on_apply_paintballz")
	paintball_settings_instance.connect("delete_mode_toggled", self, "_on_delete_mode_toggled")

	Input.set_custom_mouse_cursor(hand_neutral)
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_IBEAM)
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_POINTING_HAND)

	# flip_camera_view()

	helper_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE

func _process(_delta):
	var text = "Welcome to LnzLive!\nHelpful hints will appear here..."

	if linez_mode:
		if is_instance_valid(linez_start_ball):
			text = "Line Mode: Left-click a 2nd ball to end a line.\n"
		else:
			text = "Line Mode: Left-click a 1st ball to start a line.\n"
	elif paintball_mode:
		var delete_mode = paintball_settings_instance.find_node("DeleteModeCheckBox").pressed
		if delete_mode:
			text = "Paintball Mode: Left-click to delete last paintball"
		else:
			text = "Paintball Mode: Left-click to add next paintball"
		
		# Check for mode-specific hotkeys and append
		if Input.is_key_pressed(KEY_SHIFT):
			text += "\nSHIFT+Wheel to change paintball diameter"
		if Input.is_key_pressed(KEY_CONTROL):
			text += "\nCTRL+left-click to delete last paintball"
		
		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			text += "\nPainting on ball " + str(paintball_target_ball.ball_no)
	elif selecting_on:
		text = "Select Mode: when hovering, cycle through...\nZ or B: [Ball Info] or [Add Ball] | X or M: [Move]\nC or P: [Project Ball] | V or L: [Line]"
	else:
		# Default hotkeys when no special mode is active
		if Input.is_key_pressed(KEY_CONTROL):
			text = "Open Tools Menu (CTRL + SPACE)\nApply and Save Changes (CTRL + S)\nFlash Ballz (CTRL + Q)"
		elif Input.is_key_pressed(KEY_SHIFT):
			text = "Move Ball (SHIFT + left-click drag)\nScale Ball (SHIFT + ALT + left-click drag)"
		elif Input.is_key_pressed(KEY_SPACE):
			text = "Pan View (SPACE + left-click drag)"
	
	# Append axis lock info if any is pressed, regardless of mode
	var locks = []
	if Input.is_key_pressed(KEY_X): locks.append("X")
	if Input.is_key_pressed(KEY_Y): locks.append("Y")
	if Input.is_key_pressed(KEY_Z): locks.append("Z")
	if locks.size() > 0:
		if text != "Welcome to LnzLive!\nHelpful hints will appear here...":
			text += " | "
		text += "Axis Lock: " + str(locks)

	helper_label.text = text


func set_active_selected_ball(ball):
	if active_selected_ball and is_instance_valid(active_selected_ball):
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = ball
	active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.ACTIVE_SELECTED)

func clear_active_selected_ball():
	if active_selected_ball and is_instance_valid(active_selected_ball):
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = null

func get_visual_state_for_ball(b):
	if b == active_selected_ball:
		return b.OutlineState.ACTIVE_SELECTED
	return b.OutlineState.NONE

func flip_camera_view():
	var camera_transform = camera.transform
	camera_transform.basis.x *= -1
	camera.transform = camera_transform

func _gui_input(event):
	if paintball_mode and event is InputEventMouseButton and event.shift and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN):
		var diameter_spinbox = paintball_settings_instance.find_node("Diameter")
		if event.button_index == BUTTON_WHEEL_UP:
			diameter_spinbox.value -= 1
		else:
			diameter_spinbox.value += 1
		return

	if paintball_mode and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var delete_mode = paintball_settings_instance.find_node("DeleteModeCheckBox").pressed
		if delete_mode:
			var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
			pet_node.remove_last_pending_paintball()
			return

		var target_ball

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			target_ball = paintball_target_ball
		else:
			var target_mode = paintball_settings_instance.find_node("Target").selected
			if target_mode == 0: # Hovered Ball
				target_ball = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
			else: # Selected Ball
				if active_selected_ball and is_instance_valid(active_selected_ball):
					target_ball = active_selected_ball

		if target_ball:
			var screen_pos = (event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500)
			var from = camera.project_ray_origin(screen_pos)
			var to = from + camera.project_ray_normal(screen_pos) * 10000
			var space_state = camera.get_world().direct_space_state
			var result = space_state.intersect_ray(from, to, [self], 0x7FFFFFFF, true, true)

			if result and result.collider.get_parent() == target_ball:
				var intersection_point = result.position

				var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
				var props = paintball_settings_instance.get_properties()

				var local_relative_pos = target_ball.to_local(intersection_point)
				var world_relative_pos = intersection_point - target_ball.global_transform.origin
				var px_scale = pet_node.pixel_world_size
				var lnz_scale = pet_node.lnz.scales.x / 255.0
				var relative_pos_lnz = world_relative_pos / (px_scale * lnz_scale)
				relative_pos_lnz.y *= -1

				var paintball_info = {
					"base_ball_no": target_ball.ball_no,
					"relative_pos_local": local_relative_pos,
					"relative_pos_lnz": relative_pos_lnz,
					"diameter": props.diameter,
					"color": props.color,
					"outline_color": props.outline_color,
					"outline_type": props.outline_type,
					"fuzz": props.fuzz,
					"texture": props.texture,
					"group": props.group,
					"anchored": props.anchored,
				}

				pet_node.add_pending_paintball(paintball_info)
		return

	# Guard against entering hotkeys into text area when interacting with view container:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var focus_owner := get_focus_owner()
		if focus_owner and focus_owner is TextEdit:
			focus_owner.release_focus()

	# Open Tools Menu via right-click on hovered ball:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		get_tree().set_input_as_handled()
		var tools_menu = get_tree().root.get_node("Root/SceneRoot/ToolsMenu")
		var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if hover:
			tools_menu.selected_visual_ball = hover
		else:
			tools_menu.selected_visual_ball = null
		tools_menu.rect_global_position = get_viewport().get_mouse_position()
		tools_menu.popup()
		return

	# Zoom view using mouse wheel:
	if event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_DOWN:
		tex.rect_pivot_offset = tex.rect_size / 2.0
		tex.rect_scale /= ZOOM_STEP
		return
	elif event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_UP:
		tex.rect_pivot_offset = tex.rect_size / 2.0
		tex.rect_scale *= ZOOM_STEP
		return

	# Begin moving ballz using SHIFT+left-click-drag or resizing ballz using SHIFT+ALT+left-click-drag:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and Input.is_key_pressed(KEY_SHIFT):
		var alt_key = Input.is_key_pressed(KEY_ALT)

		var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if hover:
			drag_ball = hover
			is_dragging = true
			var pet_node = get_tree().root.get_node("Root/PetRoot/Node")

			if alt_key:
				is_resizing = true
				Input.set_custom_mouse_cursor(hand_pinch)
				original_scale = drag_ball.ball_size
				drag_start_pos = event.position
				print("[LNZ EDIT] Started scale drag on ball:", drag_ball.name)
			else:
				print("[LNZ EDIT] Started drag on ball:", drag_ball.name)
				# is_dragging = true
				Input.set_custom_mouse_cursor(hand_move)
				pet_node._orig_world_pos[drag_ball.ball_no] = drag_ball.global_transform.origin
		return
	
	# Update ball position or scale during moving or resizing:
	if event is InputEventMouseMotion and is_dragging and drag_ball:
		if is_resizing:
			var delta = event.position - drag_start_pos
			var change = delta.dot(Vector2(1, -1).normalized()) * 0.5
			if change < 0:
				Input.set_custom_mouse_cursor(hand_pinch)
			else:
				Input.set_custom_mouse_cursor(hand_stretch)
			var new_size = clamp(original_scale + change, 1.0, 100.0)
			drag_ball.set_ball_size(new_size)
		else:
			Input.set_custom_mouse_cursor(hand_move)
			var real_center = rect_position + rect_size / 2.0
			var offset = event.position - real_center
			offset /= tex.rect_scale
			var screen_pos = Vector2(500, 500) + offset
			var ray_o = camera.project_ray_origin(screen_pos)
			var ray_d = camera.project_ray_normal(screen_pos)
			var plane_n = camera.global_transform.basis.z.normalized()
			var plane_p = drag_ball.global_transform.origin
			var intersect = intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)
			if intersect:
				var new_pos = intersect
				var original_pos = drag_ball.global_transform.origin
				if Input.is_key_pressed(KEY_X):
					new_pos.y = original_pos.y
					new_pos.z = original_pos.z
				elif Input.is_key_pressed(KEY_Y):
					new_pos.x = original_pos.x
					new_pos.z = original_pos.z
				elif Input.is_key_pressed(KEY_Z):
					new_pos.x = original_pos.x
					new_pos.y = original_pos.y
				drag_ball.global_transform.origin = new_pos
				#print("Set drag_ball position to: ", new_pos)
		return

	# Finalize drag or resize operation on mouse release:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed and is_dragging and drag_ball:
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		if is_resizing:
			var size_dif = get_lnz_size_difference(original_scale, drag_ball, pet_node)
			pet_node.emit_ball_resize(drag_ball.ball_no, size_dif)
		else:
			print("[LNZ EDIT] Final world pos:", drag_ball.global_transform.origin)
			var lnz_pos = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[LNZ EDIT] Dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_translation(drag_ball.ball_no, lnz_pos)

		is_dragging = false
		is_resizing = false
		Input.set_custom_mouse_cursor(hand_neutral)
		drag_ball = null
		return

	# Select ballz via double-click in Select Mode:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.doubleclick:
		if selecting_on and last_selected_is_valid():
			last_selected.selected()
		return
	
	if linez_mode:
		if _handle_line_mode_input(event):
			return

	# Select ballz via single-click or clear selected ballz:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and selecting_on:
		var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if hover:
			set_active_selected_ball(hover)
		else:
			clear_active_selected_ball()

	# Rotate or pan camera during general mouse motion:
	if event is InputEventMouseMotion and not is_dragging:
		#label.rect_global_position = event.global_position

		var space_and_left = Input.is_key_pressed(KEY_SPACE) and Input.is_mouse_button_pressed(BUTTON_LEFT)
		var middle_drag = Input.is_mouse_button_pressed(BUTTON_MIDDLE)

		if space_and_left or middle_drag:
			var motion = event.relative
			camera.transform.origin.x += motion.x * 0.001 / tex.rect_scale.x
			camera.transform.origin.y += motion.y * 0.001 / tex.rect_scale.x
		elif Input.is_mouse_button_pressed(BUTTON_LEFT):
			var motion = event.relative
			camera_holder.rotation.x += motion.y * 0.01
			camera_holder.rotation.y += motion.x * -0.01

		# Highlight hovered ball in line creation mode:
		if linez_mode and not selecting_on:
			var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
			for b in get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs"):
				if b != linez_start_ball:
					b.apply_outline_state(b.OutlineState.NONE)
			if hover and hover != linez_start_ball:
				hover.apply_outline_state(hover.OutlineState.HOVER)


	# Update hovered ball_label and trigger highlight for selectable ball:
	if selecting_on and not paintball_mode:
		var real_center = rect_position + rect_size / 2.0
		var offset = (event.position - real_center) / tex.rect_scale
		var screen_pos = Vector2(500, 500) + offset

		var from = camera.project_ray_origin(screen_pos)
		var to = from + camera.project_ray_normal(screen_pos) * 950
		var result = camera.get_world().direct_space_state.intersect_ray(from, to, [], 0x7FFFFFFF, false, true)

		if result:
			ball_label.show()
			deal_with_last_selected()
			result.collider.get_parent()._on_Area_mouse_entered()
			last_selected = result.collider.get_parent()
		else:
			deal_with_last_selected()
			last_selected = null
			ball_label.hide()

	# Commit move for auto‑started drags on press, or for manual SHIFT‑drags on release
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and is_dragging and drag_ball:
		var commit_now: bool = (drag_started_via_code and event.pressed) or (not drag_started_via_code and not event.pressed)
		if commit_now:
			var pet_node = get_tree().root.get_node("Root/PetRoot/Node")

			print("[LNZ EDIT] Final world pos:", drag_ball.global_transform.origin)
			var lnz_pos = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[LNZ EDIT] Dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_translation(drag_ball.ball_no, lnz_pos)

			is_dragging = false
			is_resizing = false
			drag_started_via_code = false
			Input.set_custom_mouse_cursor(hand_neutral)
			drag_ball = null
			return

func _unhandled_key_input(event):
	# Open Tools Menu via CTRL+SPACE for last selected ball:
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_SPACE:
		get_tree().set_input_as_handled()
		var tools_menu = get_tree().root.get_node("Root/SceneRoot/ToolsMenu")
		if last_selected_is_valid():
			tools_menu.selected_visual_ball = last_selected
		else:
			tools_menu.selected_visual_ball = null
		tools_menu.rect_global_position = get_viewport().get_mouse_position()
		tools_menu.popup()
		return

	if event.pressed and event.scancode == KEY_L and Input.is_key_pressed(KEY_SHIFT) and last_selected_is_valid():
		linez_mode = true
		linez_start_ball = last_selected
		linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.ACTIVE_SELECTED)
	else:
		if event.pressed and last_selected_is_valid():
			last_selected._input(event)

func intersect_ray_with_plane(ray_origin: Vector3, ray_dir: Vector3, plane_normal: Vector3, plane_point: Vector3) -> Object:
	var denom = plane_normal.dot(ray_dir)
	if abs(denom) < 0.0001:
		return null
	var d = plane_normal.dot(plane_point - ray_origin) / denom
	return ray_origin + ray_dir * d

func last_selected_is_valid():
	return last_selected != null and is_instance_valid(last_selected)

func deal_with_last_selected():
	if last_selected != null and is_instance_valid(last_selected):
		last_selected._on_Area_mouse_exited()
				
func _on_Node_ball_mouse_enter(ball_info):
	ball_label.text = str(ball_info.ball_no)
	ball_label.rect_global_position = get_viewport().get_mouse_position() + Vector2(25,15)
	ball_label.show()

func _on_SelectCheckBox_toggled(button_pressed):
	selecting_on = button_pressed
	if !selecting_on:
		if last_selected_is_valid():
			last_selected._on_Area_mouse_exited()
		last_selected = null
		clear_active_selected_ball()
		ball_label.hide()
		for b in get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs"):
			if b and b.has_method("apply_outline_state"):
				b.apply_outline_state(b.OutlineState.NONE)

func _on_HelpButton_pressed():
	help_popup.popup_centered()

func _on_LnzTextEdit_mouse_entered():
	if last_selected_is_valid():
		last_selected._on_Area_mouse_exited()
	last_selected = null
	ball_label.hide()

func _on_PetViewContainer_resized():
	var size_diff = tex.rect_size / 2.0 - self.rect_size / 2.0
	tex.rect_global_position = self.rect_global_position - size_diff

func _on_PetViewContainer_sort_children():
	_on_PetViewContainer_resized()

func get_ball_under_mouse(screen_pos: Vector2):
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 10000

	var space_state = camera.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [], 0x7FFFFFFF, false, true)

	if result and result.collider:
		var parent = result.collider.get_parent()
		if parent.is_in_group("balls") or parent.is_in_group("addballs"):
			return parent
	return null

func get_lnz_position_from_visual(drag_ball: Spatial, pet_node: Node) -> Vector3:
	# Read current and original world positions
	var current_world = drag_ball.global_transform.origin
	var original_world = pet_node._orig_world_pos.get(drag_ball.ball_no, Vector3.ZERO)
	print("[LNZ EDIT] Ball %d world positions: current=%s, original=%s"
		% [drag_ball.ball_no, current_world, original_world])
	
	# Record movement in world coordinates
	var delta_meters = current_world - original_world

	# Undo pixel_world_size scale then LNZ scales
	var px_scale = pixel_world_size
	var lnz_scale = pet_node.lnz.scales.x / 255.0
	var delta_units = delta_meters / (px_scale * lnz_scale)

	# Flip Y axis to match LNZ coordinate system
	delta_units.y *= -1
	print("[LNZ EDIT] Raw LNZ‐space offset (float): %s" % delta_units)

	# Round to nearest whole LNZ unit
	var lnz_offset = Vector3(
		round(delta_units.x),
		round(delta_units.y),
		round(delta_units.z)
	)
	print("[LNZ EDIT] Rounded LNZ‐space offset (int): %s" % lnz_offset)

	return lnz_offset

func get_lnz_size_difference(original_scale, drag_ball: Spatial, pet_node: Node) -> int:
	var ball_no = drag_ball.ball_no
	var is_addball = ball_no > KeyBallsData.max_base_ball_num

	var lnz_size = 0
	if is_addball:
		if pet_node.lnz.addballs.has(ball_no):
			lnz_size = pet_node.lnz.addballs[ball_no].size
	else:
		if pet_node.lnz.balls.has(ball_no):
			lnz_size = pet_node.lnz.balls[ball_no].size

	var current_visual_diameter = drag_ball.ball_size

	print("Old visual scale: %s" % original_scale)
	print("New visual scale: %s" % current_visual_diameter)

	var pct_delta = drag_ball.ball_size / original_scale
	var size_dif = lnz_size*pct_delta + (current_visual_diameter - original_scale)*pct_delta

	print("[LNZ EDIT] Ball %d original diameter: %d vs adjusted diameter: %d, stored LNZ = %d, updated LNZ = %d"
		% [ball_no, original_scale, current_visual_diameter, lnz_size, size_dif])

	return size_dif

func begin_auto_move_for_ball(ball: Spatial) -> void:
	if not ball: return
	drag_ball = ball
	is_dragging = true
	is_resizing = false
	drag_started_via_code = true
	Input.set_custom_mouse_cursor(hand_move)
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	pet_node._orig_world_pos[ball.ball_no] = ball.global_transform.origin

func schedule_autodrag_for_addball(ball_no: int) -> void:
	pending_autodrag_addball_no = ball_no
	_wait_for_addball_then_autodrag()

func _wait_for_addball_then_autodrag() -> void:
	var tries := 90  # ~1.5s @ 60fps; adjust if your rebuild takes longer
	while tries > 0 and pending_autodrag_addball_no != -1:
		yield(get_tree(), "idle_frame")
		var visual := _find_visual_addball_by_no(pending_autodrag_addball_no)
		if visual:
			begin_auto_move_for_ball(visual)
			pending_autodrag_addball_no = -1
			return
		tries -= 1

func _find_visual_addball_by_no(no: int) -> Spatial:
	for b in get_tree().get_nodes_in_group("addballs"):
		if b.has_method("get"): # safety if some nodes aren't the ball script
			if b.ball_no == no:
				return b
	return null

func _update_paintball_mode_ui():
	if paintball_mode:
		paintball_settings_instance.show()
		Input.set_custom_mouse_cursor(smallbrush)
		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			paintball_settings_instance.find_node("Target").disabled = true
		else:
			paintball_settings_instance.find_node("Target").disabled = false
		mouse_default_cursor_shape = CURSOR_ARROW
	else:
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		if pet_node:
			pet_node.clear_pending_paintballs()

		paintball_settings_instance.hide()
		Input.set_custom_mouse_cursor(hand_neutral)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND

func _on_delete_mode_toggled(is_on):
	if is_on:
		Input.set_custom_mouse_cursor(bigbrush)
	else:
		Input.set_custom_mouse_cursor(smallbrush)

func _on_paintball_mode_for_ball_toggled(ball):
	paintball_target_ball = ball
	set_active_selected_ball(ball)
	paintball_settings_instance.find_node("Target").selected = 1
	if not paintball_check_box.pressed:
		paintball_check_box.pressed = true
	else:
		_update_paintball_mode_ui()

func _on_paintball_mode_toggled(is_on):
	paintball_mode = is_on
	if not is_on:
		paintball_target_ball = null
	else:
		if linez_mode:
			linez_mode = false
			line_mode_check_box.pressed = false
			_on_line_mode_toggled(false)
	_update_paintball_mode_ui()

func _on_line_mode_toggled(is_on):
	linez_mode = is_on
	if is_on:
		Input.set_custom_mouse_cursor(rope)
		if paintball_mode:
			paintball_mode = false
			paintball_check_box.pressed = false
			_on_paintball_mode_toggled(false)
	else:
		if is_instance_valid(linez_start_ball):
			linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
		linez_start_ball = null
		Input.set_custom_mouse_cursor(hand_neutral)

func _handle_line_mode_input(event) -> bool:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if hover:
			if !is_instance_valid(linez_start_ball):
				linez_start_ball = hover
				linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.ACTIVE_SELECTED)
			else:
				if hover != linez_start_ball:
					var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
					pet_node.emit_signal("line_created", linez_start_ball.ball_no, hover.ball_no)
					linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
					linez_start_ball = null
			return true
	return false
