extends Control

onready var camera_holder = get_tree().root.get_node("Root/SceneRoot/ViewportContainer/Viewport/CameraHolder") as Spatial
onready var camera = camera_holder.get_node("Camera") as Camera
onready var ball_label = get_tree().root.get_node("Root/SceneRoot/BallLabel")
onready var helper_label = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/HelperContainer/VBoxContainer/HelperLabel")
onready var cube = get_tree().root.get_node("Root/PetRoot/MeshInstance") as Spatial
onready var tex = get_tree().root.get_node("Root/SceneRoot/ViewportContainer") as ViewportContainer
onready var help_popup = get_tree().root.get_node("Root/SceneRoot/HelpPopupDialog") as WindowDialog
onready var dog_generator = get_tree().root.get_node("Root/PetRoot/Node")

var _auto_paint_affected_cache: Array = []

var _nearby_balls_cache: Array = []
var _current_tab_index: int = -1
var _last_selected_by_tab: Spatial = null
var _tab_activation_mouse_pos := Vector2.ZERO
const MAX_NEARBY_BALLS := 3
const NEARBY_SCREEN_RADIUS := 60.0
const TAB_RESET_THRESHOLD_PIXELS := 15.0

var input_is_paused := false

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

var sidebar_controller = null

var linez_mode = false
var linez_start_ball = null
var line_mode_close = false

var paintball_mode = false
var project_mode = false
var auto_paintballer_mode = false
var move_mode = false

var paintball_target_ball = null
var ray_intersect_paintball = null
var close_paintball_on_apply = false

var freeline_active = false
var freeline_path = []
var last_freeline_point = Vector2()

var _ordered_color_index = 0
var _ordered_outline_color_index = 0
var _ordered_texture_index = 0

# onready var paintball_settings_instance = preload("res://scenes/editor/PaintballSettings.tscn").instance()
# onready var project_settings_instance = preload("res://scenes/editor/ProjectSettings.tscn").instance()
# onready var preset_settings_instance = preload("res://scenes/editor/PresetSettings.tscn").instance()
# onready var auto_paintballer_settings_instance = preload("res://scenes/editor/AutoPaintballerSettings.tscn").instance()
# onready var palette_viewer_instance = preload("res://scenes/editor/PaletteViewer.tscn").instance()
# onready var move_mode_settings_instance = preload("res://scenes/editor/MoveModeSettings.tscn").instance()
# onready var line_mode_settings_instance = preload("res://scenes/editor/LineModeSettings.tscn").instance()

var paintball_settings_instance: Control
var project_settings_instance: Control
var preset_settings_instance: Control
var auto_paintballer_settings_instance: Control
var palette_viewer_instance: Control
var move_mode_settings_instance: Control
var line_mode_settings_instance: Control

onready var paintball_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/PaintballModeCheckBox")
onready var project_mode_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/ProjectModeCheckBox")
onready var preset_mode_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/PresetModeCheckBox")
onready var auto_paintballer_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/AutoPaintballerModeCheckBox")
onready var view_palette_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton")

onready var line_mode_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/LineModeCheckBox")
onready var move_mode_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/MoveModeCheckBox")

onready var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
onready var _select_check_box = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel/VBoxContainer/SelectCheckBox")

onready var recolor_popup = get_tree().root.get_node("Root/SceneRoot/RecolorPopup")

var preset_mode = false

var hand_neutral = load("res://resources/icons/ico_hand_neutral_2x.png")
var hand_move = load("res://resources/icons/ico_hand_move_2x.png")
var hand_pinch = load("res://resources/icons/ico_hand_pinch_2x.png")
var hand_stretch = load("res://resources/icons/ico_hand_stretch_2x.png")
var eyedropper = load("res://resources/icons/ico_tool_eyedropper_2x.png")
var smallbrush = load("res://resources/icons/ico_tool_paintbrush_2x.png")
var bigbrush = load("res://resources/icons/ico_tool_brush_2x.png")
var paintbucket = load("res://resources/icons/ico_tool_bucket_2x.png")
var rope = load("res://resources/icons/icon_line_mode.png")
var eraser = load("res://resources/icons/ico_eraser_2x.png")

const ZOOM_STEP := 1.2

var selected_balls = []
var pending_moves = {} # ball_no -> {orig_pos: Vector3, new_pos: Vector3}

var box_selecting = false
var box_start_pos = Vector2()
var box_end_pos = Vector2()

func _ready():
	set_process_unhandled_key_input(true)
	set_process(true)

	paintball_settings_instance = load("res://scenes/editor/PaintballSettings.tscn").instance()
	project_settings_instance = load("res://scenes/editor/ProjectSettings.tscn").instance()
	preset_settings_instance = load("res://scenes/editor/PresetSettings.tscn").instance()
	auto_paintballer_settings_instance = load("res://scenes/editor/AutoPaintballerSettings.tscn").instance()
	palette_viewer_instance = load("res://scenes/editor/PaletteViewer.tscn").instance()
	move_mode_settings_instance = load("res://scenes/editor/MoveModeSettings.tscn").instance()
	line_mode_settings_instance = load("res://scenes/editor/LineModeSettings.tscn").instance()

	var sidebar_node = get_tree().root.find_node("VBoxContainer", true, false)
	var sidebars = get_tree().get_nodes_in_group("SidebarController")
	if sidebars.size() > 0:
		sidebar_controller = sidebars[0]
	elif sidebar_node and sidebar_node.has_method("add_tool_tab"):
		sidebar_controller = sidebar_node
	
	if sidebar_controller:
		sidebar_controller.call_deferred("add_tool_tab", auto_paintballer_settings_instance, "Auto Paintballer")
		sidebar_controller.call_deferred("add_tool_tab", palette_viewer_instance, "Palette Viewer")
		sidebar_controller.call_deferred("add_tool_tab", paintball_settings_instance, "Paintball Mode")
		sidebar_controller.call_deferred("add_tool_tab", line_mode_settings_instance, "Line Mode")
		sidebar_controller.call_deferred("add_tool_tab", move_mode_settings_instance, "Move Mode")
		sidebar_controller.call_deferred("add_tool_tab", preset_settings_instance, "Preset Mode")
		sidebar_controller.call_deferred("add_tool_tab", project_settings_instance, "Project Mode")
	else:
		print("PetViewContainer: SidebarController not found, adding settings to SceneRoot as fallback.")
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", paintball_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", preset_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", project_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", auto_paintballer_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", move_mode_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", palette_viewer_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", line_mode_settings_instance)
	
	paintball_check_box.connect("toggled", self, "_on_paintball_mode_toggled")
	preset_mode_check_box.connect("toggled", self, "_on_preset_mode_toggled")
	project_mode_check_box.connect("toggled", self, "_on_project_mode_toggled")

	auto_paintballer_check_box.connect("toggled", self, "_on_auto_paintballer_mode_toggled")

	view_palette_check_box.connect("toggled", self, "_on_view_palette_check_box_toggled")
	palette_viewer_instance.connect("visibility_changed", self, "_on_palette_visibility_changed")

	line_mode_check_box.connect("toggled", self, "_on_line_mode_toggled")
	move_mode_check_box.connect("toggled", self, "_on_move_mode_toggled")

	var tools_menu = get_tree().root.get_node("Root/SceneRoot/ToolsMenu")
	tools_menu.connect("paintball_mode_for_ball_toggled", self, "_on_paintball_mode_for_ball_toggled")

	paintball_settings_instance.connect("apply_paintballz", lnz_text_edit, "_on_apply_paintballz")
	paintball_settings_instance.connect("clear_paintballz", dog_generator, "_on_clear_paintballz")
	paintball_settings_instance.connect("delete_mode_toggled", self, "_on_delete_mode_toggled")

	preset_settings_instance.connect("eyedropper_toggled", self, "_on_eyedropper_toggled")
	preset_settings_instance.connect("apply_to_selection", self, "_on_preset_apply_selection")
	preset_settings_instance.connect("unselect_all", self, "_on_unselect_all")
	preset_settings_instance.connect("select_balls_by_ids", self, "_on_select_balls_by_ids")

	project_settings_instance.connect("apply_projections", lnz_text_edit, "write_project_ball_section")
	project_settings_instance.connect("randomize_body_proportions", self, "_on_randomize_body_proportions")

	auto_paintballer_settings_instance.connect("randomize_auto_paintballz", dog_generator, "_on_randomize_auto_paintballz")
	auto_paintballer_settings_instance.connect("clear_auto_paintballz", dog_generator, "_on_clear_auto_paintballz")
	auto_paintballer_settings_instance.connect("apply_auto_paintballz", dog_generator, "_on_apply_auto_paintballz")
	auto_paintballer_settings_instance.connect("affected_list_changed", self, "_on_affected_list_changed")
	auto_paintballer_settings_instance.connect("unselect_all", self, "_on_unselect_all")

	move_mode_settings_instance.connect("apply_moves", self, "_on_move_mode_apply")
	move_mode_settings_instance.connect("clear_moves", self, "_on_move_mode_clear")
	move_mode_settings_instance.connect("unselect_all", self, "_on_unselect_all")
	move_mode_settings_instance.connect("align_selection", self, "_on_align_selection")
	move_mode_settings_instance.connect("snap_selection", self, "_on_snap_selection")
	move_mode_settings_instance.connect("nudge_selection", self, "_on_nudge_selection")
	move_mode_settings_instance.connect("select_group", self, "_on_move_mode_select_group")
	move_mode_settings_instance.connect("rotate_selection", self, "_on_rotate_selection")
	move_mode_settings_instance.connect("select_balls_by_ids", self, "_on_select_balls_by_ids")
	move_mode_settings_instance.connect("flip_selection", self, "_on_flip_selection")
	move_mode_settings_instance.connect("pivot_changed", self, "_on_pivot_changed")

	Input.set_custom_mouse_cursor(hand_neutral)
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_IBEAM)
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_POINTING_HAND)

	# flip_camera_view()

	helper_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	_select_check_box.connect("pressed", self, "_on_SelectCheckBox_pressed")

	var mode_popup = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel")
	mode_popup.connect("about_to_show", self, "_on_ModePopup_about_to_show")

func _ensure_panel_visible(panel):
	if panel.is_docked:
		if sidebar_controller and sidebar_controller.tab_container.current_tab != panel.get_index():
			sidebar_controller.switch_to_tab(panel)
	else:
		panel.show()
		panel.raise()

func _reset_tab_state():
	if is_instance_valid(_last_selected_by_tab):
		if not move_mode:
			_last_selected_by_tab.apply_outline_state(get_visual_state_for_ball(_last_selected_by_tab))
	_last_selected_by_tab = null
	_current_tab_index = -1
	_nearby_balls_cache.clear()
	_tab_activation_mouse_pos = Vector2.ZERO

func _process(_delta):
	var text = "Welcome to LnzLive!\nHelpful hints will appear here..."

	if is_instance_valid(_last_selected_by_tab) and not move_mode:
		var target_ball = _last_selected_by_tab
		var total_count = _nearby_balls_cache.size()
		var current_idx = max(0, _current_tab_index) + 1
		
		# Helper text required by user
		text = "Hovered: ball #%d (tabbable %d/%d)" % [target_ball.ball_no, current_idx, total_count]
		text += "\nZ or B: [Ball Info] or [Add Ball] | X or M: [Move]\nC or P: [Project Ball] | V or L: [Line]"

	elif linez_mode:
		if is_instance_valid(linez_start_ball):
			text = "Line Mode: Left-click a 2nd ball to end a line.\n"
		else:
			text = "Line Mode: Left-click a 1st ball to start a line.\n"
	elif paintball_mode:
		var delete_mode = paintball_settings_instance.find_node("EraserCheckBox").pressed
		var temp_eraser_active = Input.is_key_pressed(KEY_CONTROL)
		
		if delete_mode:
			text = "Paintball Mode: Left-click to erase nearest paintball."
			# cursor is handled by _on_delete_mode_toggled
		elif temp_eraser_active:
			text = "Paintball Mode: Left-click to erase nearest paintball."
			Input.set_custom_mouse_cursor(eraser)
		else:
			var freeline_on = paintball_settings_instance.find_node("FreelineCheckBox").pressed or Input.is_key_pressed(KEY_SHIFT)
			if freeline_on:
				text = "Paintball Mode (Freeline): Left-click and drag to draw."
			else:
				text = "Paintball Mode: Left-click to add next paintball"
			Input.set_custom_mouse_cursor(smallbrush) # Default for paintball mode
		
		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			text += "\nPainting on ball " + str(paintball_target_ball.ball_no)
	elif auto_paintballer_mode:
		text = "Auto Paintballer: Use the panel to generate random paintballz patterns. Click ballz to affect. Hit 'Apply' to save changes."
	elif project_mode:
		text = "Project Mode: Use the panel to add or randomize projections.\nHit 'Apply to LNZ' to save changes."
	elif move_mode:
		text = "Move Mode: Click to select, CTRL+Click to toggle multiple.\nDrag selected balls to move group."
		var queued_count = pending_moves.size()
		if queued_count > 0:
			text += "\nQueued Moves: " + str(queued_count)
	elif preset_mode:
		preset_settings_instance.sync_camera(camera.global_transform)

		var is_eyedropper = Input.is_key_pressed(KEY_ALT) or preset_settings_instance.is_eyedropper_active()

		if is_eyedropper:
			text = "Eyedropper Mode: Left-click a ball to sample its properties."
			Input.set_custom_mouse_cursor(eyedropper, 0, Vector2(0,30))
		else:
			text = "Preset Mode: Left-click to apply preset.\nHold ALT for eyedropper."
			if not preset_settings_instance.find_node("EyedropperToggle").pressed:
				Input.set_custom_mouse_cursor(bigbrush)
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
	if active_selected_ball and is_instance_valid(active_selected_ball) and "ball_no" in active_selected_ball:
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = ball
	active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.ACTIVE_SELECTED)
	_update_selected_ballz_in_settings()

func clear_active_selected_ball():
	if active_selected_ball and is_instance_valid(active_selected_ball) and "ball_no" in active_selected_ball:
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = null
	_update_selected_ballz_in_settings()

func get_visual_state_for_ball(b):
	if not "ball_no" in b:
		return
	else:
		if move_mode:
			if move_mode_settings_instance.find_node("UsePivotCheckBox").pressed:
				var pivot_id = int(move_mode_settings_instance.find_node("PivotBall").value)
				if b.ball_no == pivot_id:
					return b.OutlineState.PIVOT

		if (move_mode or preset_mode or auto_paintballer_mode) and b in selected_balls:
			return b.OutlineState.ACTIVE_SELECTED
		elif move_mode and pending_moves.has(b.ball_no):
			return b.OutlineState.MODIFIED
		else:
			if b == active_selected_ball:
				return b.OutlineState.ACTIVE_SELECTED
			return b.OutlineState.NONE

func flip_camera_view():
	var camera_transform = camera.transform
	camera_transform.basis.x *= -1
	camera.transform = camera_transform

func _draw():
	if box_selecting:
		var rect = Rect2(box_start_pos, box_end_pos - box_start_pos)
		draw_rect(rect, Color(0.5, 1, 0.5, 0.2), true)
		draw_rect(rect, Color(0.5, 1, 0.5, 0.8), false)

func _gui_input(event):
	if input_is_paused:
		return

	if (move_mode or preset_mode or auto_paintballer_mode) and Input.is_key_pressed(KEY_CONTROL):
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			if event.pressed:
				box_selecting = true
				box_start_pos = event.position
				box_end_pos = event.position
				return
			elif box_selecting:
				box_selecting = false
				update()
				if box_start_pos.distance_to(event.position) < 5.0:
					var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
					if hover:
						if hover in selected_balls:
							selected_balls.erase(hover)
						else:
							selected_balls.append(hover)
						if is_instance_valid(hover) and hover.has_method("apply_outline_state"):
							hover.apply_outline_state(get_visual_state_for_ball(hover))
						_update_selected_ballz_in_settings()
				else:
					_commit_box_selection()
				return

		if event is InputEventMouseMotion and box_selecting:
			box_end_pos = event.position
			update()
			return

	if event is InputEventMouseButton and event.pressed and not Input.is_key_pressed(KEY_SHIFT) and not move_mode:
		_reset_tab_state()

	if move_mode:
		# Check for Nudge hotkey via Scroll
		if event is InputEventMouseButton and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN):
			var nudge_axis = ""
			if Input.is_key_pressed(KEY_X): nudge_axis = "x"
			elif Input.is_key_pressed(KEY_Y): nudge_axis = "y"
			elif Input.is_key_pressed(KEY_Z): nudge_axis = "z"
			
			if nudge_axis != "":
				var delta = 1.0 if event.button_index == BUTTON_WHEEL_UP else -1.0
				move_mode_settings_instance.change_nudge_value(nudge_axis, delta)
				get_tree().set_input_as_handled()
				return

		if event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				if event.pressed:
					if Input.is_key_pressed(KEY_ALT):
						var hover_pos = (event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500)
						var hover_ball = get_ball_under_mouse(hover_pos)
						if hover_ball:
							move_mode_settings_instance.set_pivot_ball(hover_ball.ball_no)
							var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
							for b in all_balls:
								if is_instance_valid(b) and b.has_method("apply_outline_state"):
									b.apply_outline_state(get_visual_state_for_ball(b))
							return

					var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
					
					if hover:
						if Input.is_key_pressed(KEY_CONTROL):
							# Toggle selection
							if hover in selected_balls:
								selected_balls.erase(hover)
								hover.apply_outline_state(get_visual_state_for_ball(hover))
							else:
								selected_balls.append(hover)
								hover.apply_outline_state(hover.OutlineState.ACTIVE_SELECTED)
						else:
							# If not holding CTRL, and ball is not already selected, select only this one
							# If ball IS selected, we might be starting a drag, so don't clear others yet
							if not (hover in selected_balls):
								_on_unselect_all()
								selected_balls.append(hover)
								hover.apply_outline_state(hover.OutlineState.ACTIVE_SELECTED)

						_update_selected_ballz_in_settings()
						
						# Prepare for dragging if we have a selection
						if selected_balls.size() > 0:
							is_dragging = true
							drag_ball = hover # Just as a reference for plane intersection
							drag_start_pos = event.position
							
							# Record original positions for this drag session
							var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
							for b in selected_balls:
								if not pet_node._orig_world_pos.has(b.ball_no):
									pet_node._orig_world_pos[b.ball_no] = b.global_transform.origin
									
							Input.set_custom_mouse_cursor(hand_move)
							return # Consume click on ball

					else:
						# Clicked empty space
						if not move_mode:
							_on_unselect_all()
						# Do NOT return here, allow pass-through to rotation logic
				else:
					# Mouse release
					if is_dragging: # Only commit if we were actually dragging
						is_dragging = false
						Input.set_custom_mouse_cursor(hand_neutral)
						drag_ball = null
						
						# Commit pending moves for visual feedback (gray outline)
						for b in selected_balls:
							if is_instance_valid(b):
								if not pending_moves.has(b.ball_no):
									var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
									if pet_node._orig_world_pos.has(b.ball_no):
										pending_moves[b.ball_no] = {
											"orig_pos": pet_node._orig_world_pos[b.ball_no], 
											"new_pos": b.global_transform.origin
										}
								else:
									pending_moves[b.ball_no]["new_pos"] = b.global_transform.origin
						
						move_mode_settings_instance.set_queued_count(pending_moves.size())
						return # Consume drag release

		elif event is InputEventMouseMotion and is_dragging and drag_ball:
			var real_center = rect_position + rect_size / 2.0
			var offset = event.position - real_center
			offset /= tex.rect_scale
			var screen_pos = Vector2(500, 500) + offset
			var ray_o = camera.project_ray_origin(screen_pos)
			var ray_d = camera.project_ray_normal(screen_pos)
			
			# Drag plane based on the reference ball's position
			var plane_n = camera.global_transform.basis.z.normalized()
			var plane_p = drag_ball.global_transform.origin
			var intersect = intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)
			
			if intersect:
				var drag_current_pos = intersect
				
				# Get the previous intersection point to calculate delta
				var prev_offset = (event.position - event.relative) - real_center
				prev_offset /= tex.rect_scale
				var prev_screen_pos = Vector2(500, 500) + prev_offset
				var prev_ray_o = camera.project_ray_origin(prev_screen_pos)
				var prev_ray_d = camera.project_ray_normal(prev_screen_pos)
				var prev_intersect = intersect_ray_with_plane(prev_ray_o, prev_ray_d, plane_n, plane_p)
				
				if prev_intersect:
					var delta = drag_current_pos - prev_intersect
					
					# Apply constraints
					var constraints = move_mode_settings_instance.get_constraints()
					
					var constrain_x = Input.is_key_pressed(KEY_X)
					var constrain_y = Input.is_key_pressed(KEY_Y)
					var constrain_z = Input.is_key_pressed(KEY_Z)
					
					var final_lock_x = constraints.x
					var final_lock_y = constraints.y
					var final_lock_z = constraints.z
					
					# Override UI with Hotkeys if pressed
					if constrain_x or constrain_y or constrain_z:
						# If using hotkeys, treat them as "Allow movement on Axis"
						# So if X is pressed, we Lock Y and Z.
						final_lock_x = not constrain_x
						final_lock_y = not constrain_y
						final_lock_z = not constrain_z
					
					if final_lock_x: delta.x = 0
					if final_lock_y: delta.y = 0
					if final_lock_z: delta.z = 0
					
					# Apply to all selected balls
					for b in selected_balls:
						if is_instance_valid(b):
							var addballz_base_selected = false
							var p = b.get_parent()
							while is_instance_valid(p) and p != get_tree().root:
								if p in selected_balls:
									addballz_base_selected = true
									break
								p = p.get_parent()
							
							if not addballz_base_selected:
								b.global_transform.origin += delta

							_track_pending_move(b)
					
					# Handle Mirroring
					if move_mode_settings_instance.is_mirror_x_active():
						_apply_mirror_move(selected_balls, delta)

			return

	if preset_mode and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var target_ball = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if target_ball:
			var is_eyedropper_active = preset_settings_instance.find_node("EyedropperToggle").pressed or Input.is_key_pressed(KEY_ALT)
			if is_eyedropper_active:
				var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
				var ball_no = target_ball.ball_no
				var ball_data = null
				if pet_node.lnz.balls.has(ball_no):
					ball_data = pet_node.lnz.balls[ball_no]
				elif pet_node.lnz.addballs.has(ball_no):
					ball_data = pet_node.lnz.addballs[ball_no]

				if ball_data:
					var properties = {
						"fuzz": ball_data.fuzz,
						"outline": ball_data.outline,
						"color_index": ball_data.color_index,
						"outline_color_index": ball_data.outline_color_index,
						"texture_id": ball_data.texture_id,
						"group": ball_data.group
					}

					if pet_node.lnz.balls.has(ball_no): # It's a base ball
						var bhd_size = pet_node.bhd.ball_sizes[ball_no]
						var lnz_size = ball_data.size
						var scale = pet_node.lnz.scales[1]
						var current_base_size = bhd_size + lnz_size
						var final_size = round((current_base_size - 2) * (scale / 255.0))
						final_size -= 1 - fmod(final_size, 2)
						properties["size"] = int(round(final_size))
					else: # It's an addball
						properties["size"] = int(round(ball_data.size))

					if pet_node.lnz.paintballs.has(ball_no):
						properties["paintballz"] = pet_node.lnz.paintballs[ball_no]
					preset_settings_instance.set_properties(properties)
			else: # Brush mode
				var properties = preset_settings_instance.get_properties()
				var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
				var ball_no = target_ball.ball_no
				var ref_size = int(round(preset_settings_instance.size_spinbox.value))
				var size_mode = preset_settings_instance.size_mode_option.selected

				match size_mode:
					preset_settings_instance.SizeMode.SET:
						pass
					
					preset_settings_instance.SizeMode.SUM:
						if properties.has("size"):
							var original_size = 0
							if pet_node.lnz.balls.has(ball_no):
								original_size = pet_node.lnz.balls[ball_no].size
							elif pet_node.lnz.addballs.has(ball_no):
								original_size = pet_node.lnz.addballs[ball_no].size
							properties["size"] = original_size + properties.size
					
					preset_settings_instance.SizeMode.TRUE:
						if properties.has("size"):
							if pet_node.lnz.balls.has(ball_no): # Only for base ballz
								var bhd_size = pet_node.bhd.ball_sizes[ball_no]
								var scale = pet_node.lnz.scales[1]
								var desired_final_size = properties.size

								var new_lnz_size = 0
								var calculated_size = 0
								var required_base_size = (desired_final_size / (scale / 255.0)) + 2
								new_lnz_size = required_base_size - bhd_size

								for i in range(3): 
									var current_base_size = bhd_size + new_lnz_size
									calculated_size = round((current_base_size - 2) * (scale / 255.0))
									calculated_size -= 1 - fmod(calculated_size, 2)
									if calculated_size == desired_final_size:
										break
									var diff = desired_final_size - calculated_size
									new_lnz_size += diff 

								properties["size"] = int(round(new_lnz_size))
					
				var scale_ratio = 1.0
				if properties["scale_paintballz"]:
					var target_lnz_size = 0
					if pet_node.lnz.balls.has(ball_no):
						var bhd_size = pet_node.bhd.ball_sizes[ball_no]
						var scale = pet_node.lnz.scales[1]
						var current_base_size = bhd_size + pet_node.lnz.balls[ball_no].size
						target_lnz_size = round((current_base_size - 2) * (scale / 255.0))
					elif pet_node.lnz.addballs.has(ball_no):
						target_lnz_size = pet_node.lnz.addballs[ball_no].size

					scale_ratio = float(target_lnz_size) / float(ref_size) if ref_size > 0 else 1.0

				var p_size_mod = properties.get("paintball_size_scale", 1.0)
				var p_pos_mod = properties.get("paintball_pos_scale", 1.0)

				if scale_ratio != 1.0 or p_size_mod != 1.0 or p_pos_mod != 1.0:
					if properties.has("paintballz"):
						var scaled_paintballz = []
						for pb in properties.paintballz:
							var new_pb = pb.duplicate()
							new_pb.position *= (scale_ratio * p_pos_mod)
							new_pb.size = int(round(new_pb.size * scale_ratio * p_size_mod))
							scaled_paintballz.append(new_pb)
						properties["paintballz"] = scaled_paintballz
				lnz_text_edit.write_preset_to_ball(target_ball.ball_no, properties, null, false)
		return

	if paintball_mode and event is InputEventMouseButton and event.shift and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN):
		var diameter_min_spinbox = paintball_settings_instance.find_node("DiameterMin")
		var diameter_max_spinbox = paintball_settings_instance.find_node("DiameterMax")
		if event.button_index == BUTTON_WHEEL_UP:
			diameter_min_spinbox.value += 1
			diameter_max_spinbox.value += 1
		else:
			diameter_min_spinbox.value -= 1
			diameter_max_spinbox.value -= 1
		return

	if paintball_mode and event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		var props = paintball_settings_instance.get_properties()
		var freeline_mode = props.freeline or (event.shift and not (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN))
		if freeline_mode:
			if event.pressed:
				if props.ordered and props.repeat:
					_ordered_color_index = 0
					_ordered_outline_color_index = 0
					_ordered_texture_index = 0
				freeline_active = true
				freeline_path.clear()
				last_freeline_point = event.position
			else:
				freeline_active = false
				_finalize_freeline()
			return

	if paintball_mode and event is InputEventMouseMotion and freeline_active:
		var props = paintball_settings_instance.get_properties()
		var current_pos = event.position
		if current_pos.distance_to(last_freeline_point) > props.spacing:
			freeline_path.append(current_pos)
			last_freeline_point = current_pos
		return

	if paintball_mode and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var delete_mode = paintball_settings_instance.find_node("EraserCheckBox").pressed or Input.is_key_pressed(KEY_CONTROL)
		if delete_mode:
			var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
			var pending_paintballs = pet_node.get_pending_paintball_nodes()
			if pending_paintballs.empty():
				return

			var closest_paintball = null
			var min_dist_sq = INF
			var click_pos = event.global_position # Use global mouse position

			var viewport_global_offset = tex.get_global_transform().origin

			for pb_node in pending_paintballs:
				if not is_instance_valid(pb_node) or not pb_node.is_inside_tree():
					continue
				
				# Project world pos to 2D screen pos (local to viewport)
				var projected_pos_local = camera.unproject_position(pb_node.global_transform.origin)
				
				# Apply ViewportContainer scale and global offset to get ball pos in raw global screen coords
				var paintball_global_pos = viewport_global_offset + (projected_pos_local * tex.rect_scale)

				var dist_sq = click_pos.distance_squared_to(paintball_global_pos)
				
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_paintball = pb_node
			
			if closest_paintball and min_dist_sq < 25*25: # 25px threshold
				pet_node.remove_specific_pending_paintball(closest_paintball)
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
			_create_paintball_at_position(screen_pos, target_ball)
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
		tools_menu.rect_size = Vector2(150, 350)
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

		#var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))

		var hover = null
		if is_instance_valid(_last_selected_by_tab):
			hover = _last_selected_by_tab
		else:
			hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))

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
	if event is InputEventMouseMotion and is_dragging and drag_ball and not move_mode:
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
				
				var press_x = Input.is_key_pressed(KEY_X)
				var press_y = Input.is_key_pressed(KEY_Y)
				var press_z = Input.is_key_pressed(KEY_Z)
				
				if press_x or press_y or press_z:
					if not press_x: 
						new_pos.x = original_pos.x
					if not press_y: 
						new_pos.y = original_pos.y
					if not press_z: 
						new_pos.z = original_pos.z

				drag_ball.global_transform.origin = new_pos
				#print("Set drag_ball position to: ", new_pos)
		return

	# Finalize drag or resize operation on mouse release:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed and is_dragging and drag_ball and not move_mode:
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
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.doubleclick and not move_mode:
		if selecting_on and last_selected_is_valid():
			last_selected.selected()
		return
	
	if linez_mode:
		if _handle_line_mode_input(event):
			return

	# Select ballz via single-click or clear selected ballz:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and selecting_on and not move_mode:
		var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if hover:
			set_active_selected_ball(hover)
		else:
			clear_active_selected_ball()

	# Rotate or pan camera during general mouse motion:
	if event is InputEventMouseMotion and not is_dragging:
		#label.rect_global_position = event.global_position

		if is_instance_valid(_last_selected_by_tab):
			var current_mouse_pos = get_viewport().get_mouse_position()
			if current_mouse_pos.distance_to(_tab_activation_mouse_pos) > TAB_RESET_THRESHOLD_PIXELS:
				_reset_tab_state()
			else:
				pass

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
			Input.set_custom_mouse_cursor(rope)
			var hover = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
			for b in get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs"):
				if b != linez_start_ball and b.has_method("apply_outline_state"):
					b.apply_outline_state(b.OutlineState.NONE)
			if hover and hover != linez_start_ball and hover.has_method("apply_outline_state"):
				hover.apply_outline_state(hover.OutlineState.HOVER)
		elif not preset_mode and not paintball_mode and not project_mode and not move_mode:
			Input.set_custom_mouse_cursor(hand_neutral)

	# Update hovered ball_label and trigger highlight for selectable ball:
	if selecting_on and not paintball_mode and not is_instance_valid(_last_selected_by_tab) and not move_mode:
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
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and is_dragging and drag_ball and not move_mode:
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
	
	if auto_paintballer_mode and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var target_ball = get_ball_under_mouse((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))
		if target_ball:
			auto_paintballer_settings_instance.add_affected_ball(target_ball.ball_no)
			if is_instance_valid(target_ball) and "ball_no" in target_ball:
				target_ball.apply_outline_state(target_ball.OutlineState.ACTIVE_SELECTED)
			yield(get_tree().create_timer(0.1), "timeout")
			if is_instance_valid(target_ball) and "ball_no" in target_ball:
				target_ball.apply_outline_state(get_visual_state_for_ball(target_ball))
		return

func _unhandled_key_input(event):
	if input_is_paused:
		return
		
	if move_mode and event.pressed:
		var nudge_axis = ""
		if Input.is_key_pressed(KEY_X): nudge_axis = "x"
		elif Input.is_key_pressed(KEY_Y): nudge_axis = "y"
		elif Input.is_key_pressed(KEY_Z): nudge_axis = "z"
		
		if nudge_axis != "":
			if event.scancode == KEY_EQUAL or event.scancode == KEY_KP_ADD: # + key
				move_mode_settings_instance.change_nudge_value(nudge_axis, 1.0)
				get_tree().set_input_as_handled()
				return
			elif event.scancode == KEY_MINUS or event.scancode == KEY_KP_SUBTRACT: # - key
				move_mode_settings_instance.change_nudge_value(nudge_axis, -1.0)
				get_tree().set_input_as_handled()
				return

	if event.is_pressed() and event.scancode == KEY_TAB and not move_mode:
		get_tree().set_input_as_handled()
		_cycle_nearby_ballz()
		return
		
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
	
	if event is InputEventKey and event.pressed and event.alt and event.scancode == KEY_B:
		paintball_check_box.pressed = !paintball_check_box.pressed
		get_tree().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.alt and event.scancode == KEY_L:
		line_mode_check_box.pressed = !line_mode_check_box.pressed
		get_tree().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.alt and event.scancode == KEY_G:
		preset_mode_check_box.pressed = !preset_mode_check_box.pressed
		get_tree().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.alt and event.scancode == KEY_M:
		move_mode_check_box.pressed = !move_mode_check_box.pressed
		get_tree().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.alt and event.scancode == KEY_P:
		project_mode_check_box.pressed = !project_mode_check_box.pressed
		get_tree().set_input_as_handled()
		return

	if event.pressed and not event.control and not event.alt and not event.shift:
		match event.scancode:
			KEY_S:
				_select_check_box.pressed = !_select_check_box.pressed
				_on_SelectCheckBox_pressed()
				get_tree().set_input_as_handled()
				return
			KEY_W:
				paintball_check_box.pressed = !paintball_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_E:
				line_mode_check_box.pressed = !line_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_R:
				preset_mode_check_box.pressed = !preset_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_U:
				move_mode_check_box.pressed = !move_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_D:
				project_mode_check_box.pressed = !project_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_A:
				auto_paintballer_check_box.pressed = !auto_paintballer_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_T:
				view_palette_check_box.pressed = !view_palette_check_box.pressed
				get_tree().set_input_as_handled()
				return
			KEY_G:
				if recolor_popup.visible:
					recolor_popup.hide()
				else:
					recolor_popup.popup_centered()
				get_tree().set_input_as_handled()
				return
			KEY_H:
				lnz_text_edit._on_HeadShotButton_pressed()
				get_tree().set_input_as_handled()
				return

	if event.pressed and event.scancode == KEY_L and Input.is_key_pressed(KEY_SHIFT) and last_selected_is_valid():
		linez_mode = true
		linez_start_ball = last_selected
		linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.ACTIVE_SELECTED)
	else:
		if event.pressed:
			match event.scancode:
				KEY_1:
					_set_camera_view("front")
				KEY_2:
					_set_camera_view("bottom")
				KEY_3:
					_set_camera_view("top")
				KEY_4:
					_set_camera_view("right")
				KEY_5:
					_set_camera_view("left")
				KEY_6:
					_set_camera_view("back")
				KEY_7:
					_set_camera_view("isorightbottom")
				KEY_8:
					_set_camera_view("isorighttop")
				KEY_9:
					_set_camera_view("isoleftbottom")
				KEY_0:
					_set_camera_view("isolefttop")
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
	if selecting_on:
		ball_label.text = str(ball_info.ball_no)
		ball_label.rect_global_position = get_viewport().get_mouse_position() + Vector2(25,15)
		ball_label.show()

func _on_SelectCheckBox_toggled(button_pressed):
	pass

func _on_ModePopup_about_to_show():
	_select_check_box.pressed = selecting_on

func _on_SelectCheckBox_pressed():
	selecting_on = _select_check_box.pressed
	if !selecting_on:
		if last_selected_is_valid():
			last_selected._on_Area_mouse_exited()
		last_selected = null
		clear_active_selected_ball()
		ball_label.hide()
		for b in get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs"):
			if b and b.has_method("apply_outline_state"):
				b.apply_outline_state(b.OutlineState.NONE)
		tex.update()

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
	var result = space_state.intersect_ray(from, to, [], 1, false, true)

	if result and result.collider:
		var parent = result.collider.get_parent()
		if parent.is_in_group("balls") or parent.is_in_group("addballs"):
			if parent.get("omitted") == true and not dog_generator.draw_omitted_balls:
				return null
			return parent
	return null

func _sort_by_distance(a, b):
	return a.distance < b.distance

func _get_sorted_nearby_balls(raw_mouse_pos: Vector2) -> Array:
	var balls_list = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	var nearby_balls = []
	
	var viewport_global_offset = tex.get_global_transform().origin
	
	for ball in balls_list:
		if !is_instance_valid(ball): continue
		
		# Project world pos to 2D screen pos
		var projected_pos_local = camera.unproject_position(ball.global_transform.origin)
		
		# Apply ViewportContainer scale and global offset to get ball pos in raw global screen coords
		var ball_global_pos = viewport_global_offset + (projected_pos_local * tex.rect_scale)

		# Calculate distance in global screen space
		var screen_distance = ball_global_pos.distance_to(raw_mouse_pos)
		
		# Only consider ballz within NEARBY_SCREEN_RADIUS
		if screen_distance < NEARBY_SCREEN_RADIUS:
			nearby_balls.append({
				"ball": ball,
				"distance": screen_distance
			})

	# Sort by distance (closest first)
	nearby_balls.sort_custom(self, "_sort_by_distance")
	
	# Return the ball objects, limited by MAX_NEARBY_BALLS
	var result_balls = []
	for i in range(min(nearby_balls.size(), MAX_NEARBY_BALLS)):
		result_balls.append(nearby_balls[i].ball)
		
	return result_balls

func _cycle_nearby_ballz():
	var raw_mouse_pos = get_viewport().get_mouse_position()
	
	# Clear visual state of the previously TAB-selected ball
	deal_with_last_selected()
	
	if _current_tab_index == -1 or _current_tab_index >= _nearby_balls_cache.size() - 1:
		_current_tab_index = 0
		
		_nearby_balls_cache = _get_sorted_nearby_balls(raw_mouse_pos)
		
		if _nearby_balls_cache.size() > 0:
			# Store the raw mouse position where TAB was pressed for persistence checking
			_tab_activation_mouse_pos = raw_mouse_pos
	else:
		# Move to the next ball in the existing cache
		_current_tab_index += 1

	if _nearby_balls_cache.size() > 0:
		var target_ball = _nearby_balls_cache[_current_tab_index]
		
		# Set new selection state (updates last_selected)
		last_selected = target_ball
		_last_selected_by_tab = target_ball
		
		# Apply highlight
		if selecting_on and target_ball.has_method("_on_Area_mouse_entered"):
			target_ball._on_Area_mouse_entered()
		
		# Update floating ball number label
		ball_label.text = str(target_ball.ball_no)
		ball_label.rect_global_position = raw_mouse_pos + Vector2(35, 15)
		ball_label.show()
		
	else:
		# No nearby balls
		_reset_tab_state()
		# Set a temporary message for the helper label if no balls are found
		helper_label.text = "No nearby ballz found for cycling (Radius: %s px)." % [NEARBY_SCREEN_RADIUS]

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

func _on_affected_list_changed(ids: Array):
	_auto_paint_affected_cache = ids
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))

func _update_paintball_mode_ui():
	if paintball_mode:
		_ensure_panel_visible(paintball_settings_instance)
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
		Input.set_custom_mouse_cursor(eraser)
	else:
		Input.set_custom_mouse_cursor(smallbrush)

func _on_paintball_mode_for_ball_toggled(ball):
	close_paintball_on_apply = true
	paintball_target_ball = ball
	set_active_selected_ball(ball)
	paintball_settings_instance.find_node("Target").selected = 1
	if not paintball_check_box.pressed:
		paintball_check_box.pressed = true
	else:
		_update_paintball_mode_ui()
	_isolate_target_ball(ball)

func _on_view_palette_check_box_toggled(is_on):
	palette_viewer_instance.visible = is_on
	
	if is_on:
		if palette_viewer_instance is WindowDialog or palette_viewer_instance is Popup:
			palette_viewer_instance.popup() 
		palette_viewer_instance.populate_colors()
	else:
		palette_viewer_instance.hide()

func _on_palette_popup_closed():
	if view_palette_check_box.pressed:
		view_palette_check_box.pressed = false

func _on_palette_visibility_changed():
	if view_palette_check_box.pressed != palette_viewer_instance.visible:
		view_palette_check_box.pressed = palette_viewer_instance.visible

func _flatten_symmetry_dict(dict: Dictionary) -> Array:
	var flat_list = []
	for main_part in dict:
		for sub_part in dict[main_part]:
			var part_info = dict[main_part][sub_part]
			if part_info.has("left") and part_info.has("right") and not part_info.left.empty() and not part_info.right.empty():
				flat_list.append(part_info)
	return flat_list

func _on_randomize_body_proportions(settings: Dictionary):
	randomize()
	lnz_text_edit.save_backup()

	# Two-value sections
	var leg_ext1_min = int(settings.leg_ext_1.min)
	var leg_ext1_max = int(settings.leg_ext_1.max)
	var leg_ext1 = randi() % (leg_ext1_max - leg_ext1_min + 1) + leg_ext1_min
	var leg_ext2_min = int(settings.leg_ext_2.min)
	var leg_ext2_max = int(settings.leg_ext_2.max)
	var leg_ext2 = randi() % (leg_ext2_max - leg_ext2_min + 1) + leg_ext2_min
	lnz_text_edit.update_lnz_section_two_values("[Leg Extension]", leg_ext1, leg_ext2)

	var head_enl1_min = int(settings.head_enl_1.min)
	var head_enl1_max = int(settings.head_enl_1.max)
	var head_enl1 = randi() % (head_enl1_max - head_enl1_min + 1) + head_enl1_min
	var head_enl2_min = int(settings.head_enl_2.min)
	var head_enl2_max = int(settings.head_enl_2.max)
	var head_enl2 = randi() % (head_enl2_max - head_enl2_min + 1) + head_enl2_min
	lnz_text_edit.update_lnz_section_two_values("[Head Enlargement]", head_enl1, head_enl2)

	var feet_enl1_min = int(settings.feet_enl_1.min)
	var feet_enl1_max = int(settings.feet_enl_1.max)
	var feet_enl1 = randi() % (feet_enl1_max - feet_enl1_min + 1) + feet_enl1_min
	var feet_enl2_min = int(settings.feet_enl_2.min)
	var feet_enl2_max = int(settings.feet_enl_2.max)
	var feet_enl2 = randi() % (feet_enl2_max - feet_enl2_min + 1) + feet_enl2_min
	lnz_text_edit.update_lnz_section_two_values("[Feet Enlargement]", feet_enl1, feet_enl2)

	var scales1_min = int(settings.scales_1.min)
	var scales1_max = int(settings.scales_1.max)
	var scales1 = randi() % (scales1_max - scales1_min + 1) + scales1_min
	var scales2_min = int(settings.scales_2.min)
	var scales2_max = int(settings.scales_2.max)
	var scales2 = randi() % (scales2_max - scales2_min + 1) + scales2_min
	lnz_text_edit.update_lnz_section_two_values("[Default Scales]", scales1, scales2)

	# One-value sections
	var body_ext_min = int(settings.body_ext.min)
	var body_ext_max = int(settings.body_ext.max)
	var body_ext = randi() % (body_ext_max - body_ext_min + 1) + body_ext_min
	lnz_text_edit.update_lnz_section_one_value("[Body Extension]", body_ext)

	var face_ext_min = int(settings.face_ext.min)
	var face_ext_max = int(settings.face_ext.max)
	var face_ext = randi() % (face_ext_max - face_ext_min + 1) + face_ext_min
	lnz_text_edit.update_lnz_section_one_value("[Face Extension]", face_ext)

	var ear_ext_min = int(settings.ear_ext.min)
	var ear_ext_max = int(settings.ear_ext.max)
	var ear_ext = randi() % (ear_ext_max - ear_ext_min + 1) + ear_ext_min
	lnz_text_edit.update_lnz_section_one_value("[Ear Extension]", ear_ext)

	# A short delay to allow the text edit to process, then save.
	yield(get_tree().create_timer(0.1), "timeout")
	lnz_text_edit.save_file()
	print("Randomized Body Proportions and applied to LNZ.")

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
					if line_mode_close:
						line_mode_check_box.pressed = false
			return true
	return false

func _on_eyedropper_toggled(is_on):
	if is_on:
		Input.set_custom_mouse_cursor(eyedropper)
	else:
		Input.set_custom_mouse_cursor(smallbrush)

func _set_camera_view(view_name: String):
	camera_holder.rotation = Vector3.ZERO
	
	match view_name:
		"front":
			camera_holder.rotation_degrees = Vector3(0, 0, 0)
		"back":
			camera_holder.rotation_degrees = Vector3(0, 180, 0)
		"right":
			camera_holder.rotation_degrees = Vector3(0, 90, 0)
		"left":
			camera_holder.rotation_degrees = Vector3(0, -90, 0)
		"bottom":
			camera_holder.rotation_degrees = Vector3(-90, 0, 0)
		"top":
			camera_holder.rotation_degrees = Vector3(90, 0, 0)
		"isorightbottom":
			camera_holder.rotation_degrees = Vector3(-35, 45, 0)
		"isorighttop":
			camera_holder.rotation_degrees = Vector3(35, 45, 0)
		"isoleftbottom":
			camera_holder.rotation_degrees = Vector3(-35, -45, 0)
		"isolefttop":
			camera_holder.rotation_degrees = Vector3(35, -45, 0)

func close_paintball_mode():
	paintball_check_box.pressed = false

func _finalize_freeline():
	var props = paintball_settings_instance.get_properties()
	var jitter = props.jitter

	# Determine if there is a single target for the entire stroke
	var stroke_target_ball = null
	if paintball_target_ball and is_instance_valid(paintball_target_ball):
		stroke_target_ball = paintball_target_ball
	elif props.target_mode == 1 and active_selected_ball and is_instance_valid(active_selected_ball):
		stroke_target_ball = active_selected_ball

	var path_len = freeline_path.size()
	for i in range(path_len):
		var point = freeline_path[i]
		var jittered_point = point + Vector2(rand_range(-jitter, jitter), rand_range(-jitter, jitter))
		var screen_pos = (jittered_point - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500)

		var point_target_ball = stroke_target_ball
		if not point_target_ball: # If no stroke-wide target, use hover mode
			point_target_ball = get_ball_under_mouse(screen_pos)
		
		var current_diameter = -1 # default = random
		if props.tapered:
			var min_diam = props.diameter_min
			var max_diam = props.diameter_max
			
			if path_len == 1:
				current_diameter = min_diam
			else:
				var t = float(i) / (path_len - 1)
				var pingpong_t = 1.0 - abs(t * 2.0 - 1.0) # 0 -> 1 -> 0
				var calculated_diameter = lerp(min_diam, max_diam, pingpong_t)
	
				current_diameter = int(round(calculated_diameter))

		if point_target_ball:
			_create_paintball_at_position(screen_pos, point_target_ball, current_diameter)

func _create_paintball_at_position(screen_pos, target_ball, diameter_override = -1):
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 10000
	var space_state = camera.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [self], 1, true, true)

	if result and result.collider and result.collider.get_parent() == target_ball:
		var intersection_point = result.position
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		var props = paintball_settings_instance.get_properties()

		var color_list = LnzLiveUtils.parse_number_list(props.color)
		if color_list.empty():
			push_warning("Invalid color list format.")
			return

		var outline_color_list = LnzLiveUtils.parse_number_list(props.outline_color)
		if outline_color_list.empty():
			push_warning("Invalid outline color list format.")
			return
		
		var texture_list = LnzLiveUtils.parse_number_list(props.texture, true)
		if texture_list.empty():
			texture_list.append(-1)

		var local_relative_pos = target_ball.to_local(intersection_point)
		var world_relative_pos = intersection_point - target_ball.global_transform.origin
		var px_scale = pet_node.pixel_world_size
		var lnz_scale = pet_node.lnz.scales.x / 255.0
		var relative_pos_lnz = world_relative_pos / (px_scale * lnz_scale)
		relative_pos_lnz.y *= -1

		var color
		var outline_color
		var texture
		if props.ordered:
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

		var diameter
		if diameter_override != -1:
			diameter = diameter_override
		else:
			diameter = int(round(rand_range(props.diameter_min, props.diameter_max)))

		var paintball_info = {
			"base_ball_no": target_ball.ball_no,
			"relative_pos_local": local_relative_pos,
			"relative_pos_lnz": relative_pos_lnz,
			"diameter": int(diameter),
			"color": color,
			"outline_color": outline_color,
			"outline_type": floor(rand_range(props.outline_type_min, props.outline_type_max)),
			"fuzz": floor(rand_range(props.fuzz_min, props.fuzz_max)),
			"texture": texture,
			"group": props.group,
			"anchored": props.anchored,
		}

		pet_node.add_pending_paintball(paintball_info)

func _isolate_target_ball(target_ball):
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for ball in all_balls:
		if not is_instance_valid(ball):
			continue
		var area = ball.get_node_or_null("Area")
		if not area:
			continue

		if ball != target_ball:
			area.set_collision_layer_bit(0, false)
			area.set_collision_layer_bit(1, true)
		else:
			area.set_collision_layer_bit(0, true)
			area.set_collision_layer_bit(1, false)

func _restore_all_balls():
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for ball in all_balls:
		if not is_instance_valid(ball):
			continue
		var area = ball.get_node_or_null("Area")
		if not area:
			continue

		area.set_collision_layer_bit(0, true)
		area.set_collision_layer_bit(1, false)

func _track_pending_move(ball):
	if not pending_moves.has(ball.ball_no):
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		if pet_node._orig_world_pos.has(ball.ball_no):
			pending_moves[ball.ball_no] = {
				"orig_pos": pet_node._orig_world_pos[ball.ball_no], 
				"new_pos": ball.global_transform.origin
			}
	else:
		pending_moves[ball.ball_no]["new_pos"] = ball.global_transform.origin
	
	ball.apply_outline_state(get_visual_state_for_ball(ball))
	move_mode_settings_instance.set_queued_count(pending_moves.size())

func _on_unselect_all():
	var to_update = selected_balls.duplicate()
	selected_balls.clear()
	
	if auto_paintballer_mode:
		_auto_paint_affected_cache.clear() 
	
	for b in to_update:
		if is_instance_valid(b) and "ball_no" in b:
			b.apply_outline_state(get_visual_state_for_ball(b)) 
			
	_update_selected_ballz_in_settings()

func _on_move_mode_clear():
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if not "ball_no" in b:
			continue
		if pending_moves.has(b.ball_no):
			b.global_transform.origin = pending_moves[b.ball_no].orig_pos
	
	pending_moves.clear()
	move_mode_settings_instance.set_queued_count(0)
	
	for b in all_balls:
		if not "ball_no" in b:
			continue
		b.apply_outline_state(get_visual_state_for_ball(b))

func _on_move_mode_apply():
	if pending_moves.empty():
		return
		
	dog_generator.set_skip_next_rebuild(true)
	lnz_text_edit.apply_batch_moves(pending_moves)
	
	pending_moves.clear()
	move_mode_settings_instance.set_queued_count(0)
	
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if not "ball_no" in b:
			continue
		pet_node._orig_world_pos[b.ball_no] = b.global_transform.origin
		b.apply_outline_state(get_visual_state_for_ball(b))

func _on_align_selection(axis, mode):
	if selected_balls.empty():
		return
		
	_align_ball_list(selected_balls, axis, mode)

	if move_mode_settings_instance.is_mirror_x_active():
		var mirrored_group = []
		
		for b in selected_balls:
			var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)
			
			if partner_id != -1 and partner_id != b.ball_no:
				var partner_visual = _find_visual_ball_by_no(partner_id)
				
				if partner_visual and not (partner_visual in selected_balls) and not (partner_visual in mirrored_group):
					mirrored_group.append(partner_visual)
		
		if not mirrored_group.empty():
			var target_mode = mode
			if axis == "x":
				if mode == 0: target_mode = 2
				elif mode == 2: target_mode = 0
				
			_align_ball_list(mirrored_group, axis, target_mode)

func _align_ball_list(ball_list, axis, mode):
	var reference_val = 0.0
	var first = true
	
	if mode == 1:
		var sum = 0.0
		for b in ball_list:
			if not "ball_no" in b:
				continue
			sum += _get_axis_val(b, axis)
		reference_val = sum / ball_list.size()
	else:
		for b in ball_list:
			if not "ball_no" in b:
				continue
			var val = _get_axis_val(b, axis)
			if first:
				reference_val = val
				first = false
			else:
				if mode == 0:
					if val < reference_val: reference_val = val
				elif mode == 2:
					if val > reference_val: reference_val = val
	
	for b in ball_list:
		if not "ball_no" in b:
			continue
		if axis == "x": b.global_transform.origin.x = reference_val
		elif axis == "y": b.global_transform.origin.y = reference_val
		elif axis == "z": b.global_transform.origin.z = reference_val
		_track_pending_move(b)

func _get_axis_val(ball, axis):
	if axis == "x": return ball.global_transform.origin.x
	if axis == "y": return ball.global_transform.origin.y
	if axis == "z": return ball.global_transform.origin.z
	return 0.0

func _on_snap_selection(axis, direction):
	
	if selected_balls.empty():
		return

	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	var target_val = 0.0
	var first = true
	
	for b in all_balls:
		if not is_instance_valid(b): continue
		
		var val = _get_axis_val(b, axis)
		
		if first:
			target_val = val
			first = false
		else:
			if direction == -1:
				if val < target_val: target_val = val
			else:
				if val > target_val: target_val = val

	_snap_ball_list_to_target(selected_balls, axis, direction, target_val)

	if move_mode_settings_instance.is_mirror_x_active():
		var mirrored_group = []
		for b in selected_balls:
			var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)
			if partner_id != -1 and partner_id != b.ball_no:
				var partner_visual = _find_visual_ball_by_no(partner_id)
				if partner_visual and not (partner_visual in selected_balls) and not (partner_visual in mirrored_group):
					mirrored_group.append(partner_visual)
		
		if not mirrored_group.empty():
			_snap_ball_list_to_target(mirrored_group, axis, direction, target_val)

func _snap_ball_list_to_target(ball_list, axis, direction, target_val):
	var selection_extreme = 0.0
	var first = true
	
	for b in ball_list:
		if not "ball_no" in b:
			continue
		var val = _get_axis_val(b, axis)
		
		if first:
			selection_extreme = val
			first = false
		else:
			if direction == -1:
				if val < selection_extreme: selection_extreme = val
			else:
				if val > selection_extreme: selection_extreme = val
	
	if first: return
	
	var offset = target_val - selection_extreme
	
	for b in ball_list:
		if not "ball_no" in b:
			continue
		if axis == "y": b.global_transform.origin.y += offset
		elif axis == "z": b.global_transform.origin.z += offset
		_track_pending_move(b)

func _on_nudge_selection(vector: Vector3):
	if selected_balls.empty():
		return
		
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var px_scale = pet_node.pixel_world_size
	var lnz_scale = pet_node.lnz.scales.x / 255.0
	
	var world_delta = vector
	world_delta.y *= -1
	world_delta = world_delta * (px_scale * lnz_scale)
	
	for b in selected_balls:
		var addballz_base_selected = false
		var p = b.get_parent()
		while is_instance_valid(p) and p != get_tree().root:
			if p in selected_balls:
				addballz_base_selected = true
				break
			p = p.get_parent()
			
		if not addballz_base_selected:
			b.global_transform.origin += world_delta

		_track_pending_move(b)

func _on_move_mode_select_group(group_name: String):
	if not Input.is_key_pressed(KEY_CONTROL):
		_on_unselect_all()

	var balls_to_select = KeyBallsData.get_group_balls(group_name)
	
	for b_no in balls_to_select:
		var b = _find_visual_ball_by_no(b_no)
		
		if b and is_instance_valid(b):
			if not (b in selected_balls):
				selected_balls.append(b)
				if not "ball_no" in b:
					continue
				b.apply_outline_state(b.OutlineState.ACTIVE_SELECTED)
	_update_selected_ballz_in_settings()

func _apply_mirror_move(balls_moved, delta):
	var mirror_mult = move_mode_settings_instance.get_mirror_vector()
	
	for b in balls_moved:
		if not "ball_no" in b:
			continue
		
		var addballz_base_selected = false
		var p = b.get_parent()
		while is_instance_valid(p) and p != get_tree().root:
			if p in balls_moved:
				addballz_base_selected = true
				break
			p = p.get_parent()
			
		if addballz_base_selected:
			var partner_id_check = lnz_text_edit.find_mirrored_ball(b.ball_no)
			if partner_id_check != -1 and partner_id_check != b.ball_no:
				var partner_visual = _find_visual_ball_by_no(partner_id_check)
				if partner_visual:
					_track_pending_move(partner_visual)
			continue

		var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)
		if partner_id != -1 and partner_id != b.ball_no:
			# Find visual ball for partner
			var partner_visual = _find_visual_ball_by_no(partner_id)
			if partner_visual and not (partner_visual in selected_balls):
				var mirrored_delta = delta * mirror_mult
				
				partner_visual.global_transform.origin += mirrored_delta
				_track_pending_move(partner_visual)

func _find_visual_ball_by_no(no: int) -> Spatial:
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if b.ball_no == no:
			return b
	return null

func _get_rotation_pivot_origin(pivot_id):
	var pivot_origin = Vector3.ZERO
	var pivot_visual = null
	
	if pivot_id != -1:
		pivot_visual = _find_visual_ball_by_no(pivot_id)
	
	if pivot_visual and is_instance_valid(pivot_visual):
		pivot_origin = pivot_visual.global_transform.origin
	else:
		var sum_pos = Vector3.ZERO
		var count = 0
		for b in selected_balls:
			if is_instance_valid(b):
				sum_pos += b.global_transform.origin
				count += 1
		if count > 0:
			pivot_origin = sum_pos / count
	return pivot_origin

func _on_rotate_selection(rotation_degrees, pivot_id):
	if selected_balls.empty():
		return

	var pivot_origin = _get_rotation_pivot_origin(pivot_id)
	
	var rot_rad = Vector3(deg2rad(rotation_degrees.x), deg2rad(rotation_degrees.y), deg2rad(rotation_degrees.z))
	
	var basis = Basis(Quat(rot_rad))
	
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	
	for b in selected_balls:
		if is_instance_valid(b):
			var addballz_base_selected = false
			var p = b.get_parent()
			while is_instance_valid(p) and p != get_tree().root:
				if p in selected_balls:
					addballz_base_selected = true
					break
				p = p.get_parent()
			
			if addballz_base_selected:
				continue

			var current_pos = b.global_transform.origin
			var rel_pos = current_pos - pivot_origin
			
			var rotated_rel = basis.xform(rel_pos)
			var new_pos = pivot_origin + rotated_rel
			
			if not pet_node._orig_world_pos.has(b.ball_no):
				pet_node._orig_world_pos[b.ball_no] = current_pos 
			
			b.global_transform.origin = new_pos
			b.global_transform.basis = basis * b.global_transform.basis

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

func _on_flip_selection(axis_vector, pivot_id):
	if selected_balls.empty():
		return

	var pivot_origin = _get_rotation_pivot_origin(pivot_id)
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	
	for b in selected_balls:
		if is_instance_valid(b):
			var addballz_base_selected = false
			var p = b.get_parent()
			while is_instance_valid(p) and p != get_tree().root:
				if p in selected_balls:
					addballz_base_selected = true
					break
				p = p.get_parent()
				
			if addballz_base_selected:
				continue

			var current_pos = b.global_transform.origin
			var rel_pos = current_pos - pivot_origin
			var flipped_rel = rel_pos * axis_vector
			var new_pos = pivot_origin + flipped_rel
			
			if not pet_node._orig_world_pos.has(b.ball_no):
				pet_node._orig_world_pos[b.ball_no] = current_pos 
			
			b.global_transform.origin = new_pos

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

func _update_selected_ballz_in_settings():
	var ids = []
	var properties = preset_settings_instance.get_properties()
	var exclude_eyes = properties.get("exclude_eyes", false)
	
	var filter = KeyBallsData.get_group_balls("irises")
	if exclude_eyes:
		filter += KeyBallsData.get_group_balls("eyes")
	
	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			if not b.ball_no in filter:
				ids.append(b.ball_no)
				
	move_mode_settings_instance.update_selected_balls_text(ids)
	preset_settings_instance.update_selected_balls_text(ids)

	if auto_paintballer_mode:
		auto_paintballer_settings_instance.update_selected_balls_text(ids)

func _on_select_balls_by_ids(ids: Array):
	_on_unselect_all()
	var iris_ids = KeyBallsData.get_group_balls("irises")
	
	for id in ids:
		if id in iris_ids:
			continue
			
		var ball = _find_visual_ball_by_no(id)
		if ball and is_instance_valid(ball):
			if "ball_no" in ball:
				selected_balls.append(ball)
				ball.apply_outline_state(ball.OutlineState.ACTIVE_SELECTED)
				
	_update_selected_ballz_in_settings()

func _commit_box_selection():
	var rect = Rect2(box_start_pos, box_end_pos - box_start_pos).abs()
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	
	var iris_ids = KeyBallsData.get_group_balls("irises")
	var properties = preset_settings_instance.get_properties()
	var exclude_eyes = properties.get("exclude_eyes", false) 
	var eye_ids = KeyBallsData.get_group_balls("eyes") if exclude_eyes else []

	for b in all_balls:
		if not is_instance_valid(b) or not b.is_inside_tree(): 
			continue

		if b.get("omitted") == true and not dog_generator.draw_omitted_balls:
			continue
		
		if not ("ball_no" in b) or not b.visible: 
			continue
			
		if b.ball_no in iris_ids or b.ball_no in eye_ids: 
			continue

		var projected_pos_local = camera.unproject_position(b.global_transform.origin)
		var relative_pos = projected_pos_local - Vector2(500, 500)
		var pos_in_container = (relative_pos * tex.rect_scale) + (rect_size / 2.0) 

		if rect.has_point(pos_in_container):
			if not (b in selected_balls):
				selected_balls.append(b)
				if b.has_method("apply_outline_state"):
					b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()

func _on_preset_apply_selection():
	if selected_balls.empty():
		return

	var properties = preset_settings_instance.get_properties()
	var ball_ids = []
	
	var should_exclude_eyes = properties.get("exclude_eyes", false)
	var exclusion_list = []
	if should_exclude_eyes:
		exclusion_list = KeyBallsData.get_group_balls("eyes") + KeyBallsData.get_group_balls("irises")

	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			if not b.ball_no in exclusion_list:
				ball_ids.append(b.ball_no)

	if not ball_ids.empty():
		lnz_text_edit.apply_batch_presets(ball_ids, properties)

func _on_pivot_changed():
	var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))

###

func _on_paintball_mode_toggled(is_on):
	if is_on: _deactivate_other_modes("Paintball Mode")
	paintball_mode = is_on
	_update_mode_panel_visibility(paintball_settings_instance, is_on)
	
	if not is_on:
		paintball_target_ball = null
		close_paintball_on_apply = false
		_restore_all_balls()
	else:
		_restore_all_balls()
		_ordered_color_index = 0
		_ordered_outline_color_index = 0
		_ordered_texture_index = 0
		paintball_settings_instance.find_node("Target").selected = 0
		
	_update_paintball_mode_ui()
	
# func _on_paintball_mode_toggled(is_on):
# 	paintball_mode = is_on
# 	if not is_on:
# 		paintball_target_ball = null
# 		close_paintball_on_apply = false
# 		_restore_all_balls()
# 	else:
# 		_restore_all_balls()
# 		_ordered_color_index = 0
# 		_ordered_outline_color_index = 0
# 		_ordered_texture_index = 0
# 		paintball_settings_instance.find_node("Target").selected = 0
# 		if linez_mode:
# 			linez_mode = false
# 			line_mode_check_box.pressed = false
# 			_on_line_mode_toggled(false)
# 		if preset_mode:
# 			preset_mode = false
# 			preset_mode_check_box.pressed = false
# 			_on_preset_mode_toggled(false)
# 		if project_mode:
# 			project_mode = false
# 			project_mode_check_box.pressed = false
# 			_on_project_mode_toggled(false)
# 		if move_mode:
# 			move_mode = false
# 			move_mode_check_box.pressed = false
# 			_on_move_mode_toggled(false)
# 	_update_paintball_mode_ui()


func _on_line_mode_toggled(is_on):
	if is_on: _deactivate_other_modes("Line Mode")
	linez_mode = is_on
	_update_mode_panel_visibility(line_mode_settings_instance, is_on)
	
	if is_on:
		Input.set_custom_mouse_cursor(rope)
	else:
		line_mode_close = false
		if is_instance_valid(linez_start_ball):
			linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
		linez_start_ball = null
		Input.set_custom_mouse_cursor(hand_neutral)

# func _on_line_mode_toggled(is_on):
# 	linez_mode = is_on
# 	if is_on:
# 		_ensure_panel_visible(line_mode_settings_instance)
# 		line_mode_settings_instance.show()
# 		Input.set_custom_mouse_cursor(rope)
# 		if paintball_mode:
# 			paintball_mode = false
# 			paintball_check_box.pressed = false
# 			_on_paintball_mode_toggled(false)
# 		if preset_mode:
# 			preset_mode = false
# 			preset_mode_check_box.pressed = false
# 			_on_preset_mode_toggled(false)
# 		if move_mode:
# 			move_mode = false
# 			move_mode_check_box.pressed = false
# 			_on_move_mode_toggled(false)
# 	else:
# 		line_mode_close = false
# 		line_mode_settings_instance.hide()
# 		if is_instance_valid(linez_start_ball):
# 			linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
# 		linez_start_ball = null
# 		Input.set_custom_mouse_cursor(hand_neutral)


func _on_move_mode_toggled(is_on):
	if is_on: _deactivate_other_modes("Move Mode")
	move_mode = is_on
	_update_mode_panel_visibility(move_mode_settings_instance, is_on)
	
	if is_on:
		move_mode_settings_instance.set_queued_count(pending_moves.size())
		Input.set_custom_mouse_cursor(hand_neutral)
		ball_label.hide()
		_reset_tab_state()
	else:
		_on_unselect_all()
		_on_move_mode_clear()

# func _on_move_mode_toggled(is_on):
# 	move_mode = is_on
# 	if is_on:
# 		_ensure_panel_visible(move_mode_settings_instance)
# 		move_mode_settings_instance.show()
# 		move_mode_settings_instance.set_queued_count(pending_moves.size())
# 		Input.set_custom_mouse_cursor(hand_neutral)
		
# 		# Disable other modes
# 		if paintball_mode:
# 			paintball_mode = false
# 			paintball_check_box.pressed = false
# 			_on_paintball_mode_toggled(false)
# 		if linez_mode:
# 			linez_mode = false
# 			line_mode_check_box.pressed = false
# 			_on_line_mode_toggled(false)
# 		if preset_mode:
# 			preset_mode = false
# 			preset_mode_check_box.pressed = false
# 			_on_preset_mode_toggled(false)
# 		if project_mode:
# 			project_mode = false
# 			project_mode_check_box.pressed = false
# 			_on_project_mode_toggled(false)
			
# 		# Hide ball label and clear tab selection
# 		ball_label.hide()
# 		_reset_tab_state()
		
# 	else:
# 		move_mode_settings_instance.hide()
# 		# Clear visual state of selected balls
# 		_on_unselect_all()
# 		_on_move_mode_clear() # Revert any pending moves visuals


func _on_preset_mode_toggled(is_on):
	if is_on: _deactivate_other_modes("Preset Mode")
	preset_mode = is_on
	_update_mode_panel_visibility(preset_settings_instance, is_on)
	
	if is_on:
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		if pet_node and pet_node.lnz:
			if pet_node.lnz.texture_list:
				preset_settings_instance.set_texture_list(pet_node.lnz.texture_list)
			if pet_node.lnz.palette:
				preset_settings_instance.set_palette(pet_node.lnz.palette)
		
		Input.set_custom_mouse_cursor(smallbrush)
		mouse_default_cursor_shape = CURSOR_ARROW
	else:
		Input.set_custom_mouse_cursor(hand_neutral)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND

# func _on_preset_mode_toggled(is_on):
# 	preset_mode = is_on
# 	if is_on:
# 		_ensure_panel_visible(preset_settings_instance)
# 		preset_settings_instance.show()

# 		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
# 		if pet_node and pet_node.lnz and pet_node.lnz.texture_list:
# 			preset_settings_instance.set_texture_list(pet_node.lnz.texture_list)
		
# 		if pet_node and pet_node.lnz and pet_node.lnz.palette:
# 			preset_settings_instance.set_palette(pet_node.lnz.palette)

# 		Input.set_custom_mouse_cursor(smallbrush)
# 		if paintball_mode:
# 			paintball_mode = false
# 			paintball_check_box.pressed = false
# 		if linez_mode:
# 			linez_mode = false
# 			line_mode_check_box.pressed = false
# 		if project_mode:
# 			project_mode = false
# 			project_mode_check_box.pressed = false
# 		if move_mode:
# 			move_mode = false
# 			move_mode_check_box.pressed = false
# 			_on_move_mode_toggled(false)
# 		mouse_default_cursor_shape = CURSOR_ARROW
# 	else:
# 		preset_settings_instance.hide()
# 		Input.set_custom_mouse_cursor(hand_neutral)
# 		mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _on_project_mode_toggled(is_on):
	if is_on: _deactivate_other_modes("Project Mode")
	project_mode = is_on
	_update_mode_panel_visibility(project_settings_instance, is_on)

# func _on_project_mode_toggled(is_on):
# 	project_mode = is_on
# 	if is_on:
# 		_ensure_panel_visible(project_settings_instance)
# 		project_settings_instance.show()
# 		if paintball_mode:
# 			paintball_mode = false
# 			paintball_check_box.pressed = false
# 			_on_paintball_mode_toggled(false)
# 		if linez_mode:
# 			linez_mode = false
# 			line_mode_check_box.pressed = false
# 			_on_line_mode_toggled(false)
# 		if preset_mode:
# 			preset_mode = false
# 			preset_mode_check_box.pressed = false
# 			_on_preset_mode_toggled(false)
# 		if move_mode:
# 			move_mode = false
# 			move_mode_check_box.pressed = false
# 			_on_move_mode_toggled(false)
# 	else:
# 		project_settings_instance.hide()


func _on_auto_paintballer_mode_toggled(is_on):
	if is_on: _deactivate_other_modes("Auto Paintballer")
	auto_paintballer_mode = is_on
	_update_mode_panel_visibility(auto_paintballer_settings_instance, is_on)
	
	if not is_on:
		dog_generator._on_clear_auto_paintballz()
		_on_unselect_all()
		_auto_paint_affected_cache.clear()
		var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
		for b in all_balls:
			if is_instance_valid(b) and b.has_method("apply_outline_state"):
				b.apply_outline_state(b.OutlineState.NONE)

# func _on_auto_paintballer_mode_toggled(is_on):
# 	auto_paintballer_mode = is_on
# 	if is_on:
# 		_ensure_panel_visible(auto_paintballer_settings_instance)
# 		auto_paintballer_settings_instance.show()
# 		if paintball_mode:
# 			paintball_mode = false
# 			paintball_check_box.pressed = false
# 			_on_paintball_mode_toggled(false)
# 		if linez_mode:
# 			linez_mode = false
# 			line_mode_check_box.pressed = false
# 			_on_line_mode_toggled(false)
# 		if preset_mode:
# 			preset_mode = false
# 			preset_mode_check_box.pressed = false
# 			_on_preset_mode_toggled(false)
# 		if project_mode:
# 			project_mode = false
# 			project_mode_check_box.pressed = false
# 			_on_project_mode_toggled(false)
# 		if move_mode:
# 			move_mode = false
# 			move_mode_check_box.pressed = false
# 			_on_move_mode_toggled(false)
# 	else:
# 		auto_paintballer_settings_instance.hide()
# 		dog_generator._on_clear_auto_paintballz()
# 		_on_unselect_all()
# 		_auto_paint_affected_cache.clear()
# 		var all_balls = get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")
# 		for b in all_balls:
# 			if is_instance_valid(b) and b.has_method("apply_outline_state"):
# 				b.apply_outline_state(b.OutlineState.NONE)

func _deactivate_other_modes(active_mode_name: String):
	if active_mode_name != "Paintball Mode": paintball_check_box.pressed = false
	if active_mode_name != "Line Mode": line_mode_check_box.pressed = false
	if active_mode_name != "Move Mode": move_mode_check_box.pressed = false
	if active_mode_name != "Preset Mode": preset_mode_check_box.pressed = false
	if active_mode_name != "Project Mode": project_mode_check_box.pressed = false
	if active_mode_name != "Auto Paintballer": auto_paintballer_check_box.pressed = false

func _update_mode_panel_visibility(panel: Control, is_active: bool):
	if is_active:
		if panel.is_docked:
			sidebar_controller.dock_panel(panel)
		else:
			panel.show()
			panel.raise()
	else:
		if not panel.is_docked:
			panel.hide()