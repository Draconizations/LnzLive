extends Control

# PetViewContainer.gd – manages 3D viewport interaction, modes, tools, and states
# - Translates 2D mouse input into 3D world interactions (raycasting/selection)
# - Manages Modes (Move, Paint, Line, etc.)
# - Handles coordinate conversion between spatial world and LNZ units
# - Coordinates viewport visuals (gizmos, labels, and cursors)

# SECTIONS:
#	SETUP & INITIALIZATION
#	INPUT HANDLING
#	MODE MANAGEMENT
#	PALETTE VIEWER
#	VARIATION VIEWER
#	RECOLOR MODE
#	PAINT MODE
#	SHAPE MODE
#	LINE MODE
#	PRESET MODE
#	MOVE MODE

var ui_is_dirty := true

onready var default_font = get_font("font")

onready var file_tree = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree"
)
onready var lnz_text_edit = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit"
)
onready var pet_view = self
onready var pet_node = get_tree().root.get_node("Root/PetRoot/Node")

var px_scale: float setget , get_px_scale
var lnz_scale: float setget , get_lnz_scale

onready var camera_holder = get_tree().root.get_node("Root/SceneRoot/ViewportContainer/Viewport/CameraHolder") as Spatial
onready var camera = camera_holder.get_node("Camera") as Camera

onready var ball_label = get_tree().root.find_node("BallLabel", true, false)
onready var help_popup = get_tree().root.find_node("HelpPopupDialog", true, false)
onready var recolor_popup = get_tree().root.find_node("RecolorPopup", true, false)
onready var helper_label = find_node("HelperLabel")
onready var cube = get_tree().root.get_node("Root/PetRoot/MeshInstance") as Spatial
onready var tex = get_tree().root.get_node("Root/SceneRoot/ViewportContainer") as ViewportContainer

onready var auto_paintballer_check_box = find_node("AutoPaintballerModeCheckBox")

onready var view_palette_check_box = find_node("ViewPaletteButton")

onready var view_variations_check_box = find_node("ViewVariationsCheckBox")
onready var variation_tree = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/Variations"
)

onready var select_check_box = find_node("SelectCheckBox")

onready var recolor_mode_check_box = find_node("RecolorModeCheckBox")
onready var texture_editor_mode_check_box = find_node("TextureEditorModeCheckBox")
var texture_editor_mode = false

onready var paintball_check_box = find_node("PaintballModeCheckBox")
onready var move_mode_check_box = find_node("MoveModeCheckBox")
onready var line_mode_check_box = find_node("LineModeCheckBox")
onready var project_mode_check_box = find_node("ProjectModeCheckBox")
onready var preset_mode_check_box = find_node("PresetModeCheckBox")

onready var tools_menu = get_tree().root.get_node("Root/SceneRoot/ToolsMenu")

var _auto_paint_affected_cache: Array = []

var _spatial_grid_2d = {}
const GRID_CELL_SIZE = 80.0

var _nearby_balls_cache: Array = []
var _current_tab_index: int = -1
var _last_selected_by_tab: Spatial = null
var _tab_activation_mouse_pos := Vector2.ZERO
const MAX_NEARBY_BALLS := 6
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

var _scale_group_pivot = Vector3.ZERO
var _scale_group_initial_data = {}

var sidebar_controller = null

var linez_mode = false
var linez_start_ball = null
var line_mode_close = false

var paintball_mode = false
var project_mode = false
var auto_paintballer_mode = false
var move_mode = false
var recolor_mode = false
var preset_mode = false

var paintball_target_ball = null
var ray_intersect_paintball = null
var close_paintball_on_apply = false

var freeline_active = false
var freeline_path = []
var last_freeline_point = Vector2()

var _ordered_color_index = 0
var _ordered_outline_color_index = 0
var _ordered_texture_index = 0

var gizmo_3d_root: Spatial
var gizmo_x: MeshInstance
var gizmo_y: MeshInstance
var gizmo_z: MeshInstance
var labels_3d = {}
const GIZMO_OPACITY = 0.5

# onready var paintball_settings_instance = preload("res://scenes/editor/PaintballSettings.tscn").instance()
# onready var project_settings_instance = preload("res://scenes/editor/ProjectSettings.tscn").instance()
# onready var preset_settings_instance = preload("res://scenes/editor/PresetSettings.tscn").instance()
# onready var auto_paintballer_settings_instance = preload("res://scenes/editor/AutoPaintballerSettings.tscn").instance()
# onready var palette_viewer_instance = preload("res://scenes/editor/PaletteViewer.tscn").instance()
# onready var move_mode_settings_instance = preload("res://scenes/editor/MoveModeSettings.tscn").instance()
# onready var line_mode_settings_instance = preload("res://scenes/editor/LineModeSettings.tscn").instance()

var palette_viewer_instance: Control
var recolor_settings_instance: Control
var paintball_settings_instance: Control
var move_mode_settings_instance: Control
var line_mode_settings_instance: Control
var project_settings_instance: Control
var preset_settings_instance: Control
var auto_paintballer_settings_instance: Control
var texture_editor_settings_instance: Control

var shader_settings_instance: Control

var diameter_min_spinbox: SpinBox
var diameter_max_spinbox: SpinBox
var eraser_check_box: CheckBox
var pivot_ball_spinbox: SpinBox
var use_pivot_check_box: CheckBox

#var hand_neutral = load("res://resources/icons/ico_hand_neutral_2x.png")
var hand_neutral = load("res://resources/icons/ico_hand_neutral_2x_64px.png")
#var hand_move = load("res://resources/icons/ico_hand_move_2x.png")
var hand_move = load("res://resources/icons/ico_hand_move_2x_64px.png")
#var hand_pinch = load("res://resources/icons/ico_hand_pinch_2x.png")
var hand_pinch = load("res://resources/icons/ico_hand_pinch_2x_64px.png")
#var hand_stretch = load("res://resources/icons/ico_hand_stretch_2x.png")
var hand_stretch = load("res://resources/icons/ico_hand_stretch_2x_64px.png")
#var eyedropper = load("res://resources/icons/ico_tool_eyedropper_2x.png")
var eyedropper = load("res://resources/icons/ico_tool_eyedropper_2x_64px.png")
#var smallbrush = load("res://resources/icons/ico_tool_paintbrush_2x.png")
var smallbrush = load("res://resources/icons/ico_tool_paintbrush_2x_64px.png")
#var bigbrush = load("res://resources/icons/ico_tool_brush_2x.png")
var bigbrush = load("res://resources/icons/ico_tool_brush_2x_64px.png")
#var paintbucket = load("res://resources/icons/ico_tool_bucket_2x.png")
var paintbucket = load("res://resources/icons/ico_tool_bucket_2x_64px.png")
#var rope = load("res://resources/icons/icon_line_mode.png")
var rope = load("res://resources/icons/icon_line_mode_2x_64px.png")
#var eraser = load("res://resources/icons/ico_eraser_2x.png")
var eraser = load("res://resources/icons/ico_eraser_2x_64px.png")

const ZOOM_STEP := 1.2

var selected_balls = []
var pending_moves = {}  # ball_no -> {orig_pos: Vector3, new_pos: Vector3}

var _pre_move_state = {}

var box_selecting = false
var box_start_pos = Vector2()
var box_end_pos = Vector2()

const MAX_INTERACTION_HISTORY = 25

var paint_history = []
var paint_redo_stack = []

var move_history = []
var move_redo_stack = []

var hotkey_overlay_scene = preload("res://scenes/editor/HotkeyOverlay.tscn")
var hotkey_overlay_instance = null

var _overlay_viewport_container: ViewportContainer = null
var _overlay_viewport: Viewport = null
var _overlay_camera: Camera = null
var _dimmer_rect: ColorRect = null

var design_rotation_angle: float = 0.0
var design_scale_multiplier: float = 1.0

### SETUP & INITIALIZATION ###


func _safe_connect(target, sig, method):
	if target and target.has_signal(sig) and not target.is_connected(sig, self, method):
		target.connect(sig, self, method)


func _ready():
	hotkey_overlay_instance = hotkey_overlay_scene.instance()
	add_child(hotkey_overlay_instance)

	set_process_unhandled_key_input(true)
	set_process(true)

	paintball_settings_instance = load("res://scenes/editor/PaintballSettings.tscn").instance()
	project_settings_instance = load("res://scenes/editor/ProjectSettings.tscn").instance()
	preset_settings_instance = load("res://scenes/editor/PresetSettings.tscn").instance()
	auto_paintballer_settings_instance = load("res://scenes/editor/AutoPaintballerSettings.tscn").instance()
	palette_viewer_instance = load("res://scenes/editor/PaletteViewer.tscn").instance()
	move_mode_settings_instance = load("res://scenes/editor/MoveModeSettings.tscn").instance()
	line_mode_settings_instance = load("res://scenes/editor/LineModeSettings.tscn").instance()
	recolor_settings_instance = load("res://scenes/editor/RecolorSettings.tscn").instance()
	texture_editor_settings_instance = load("res://scenes/editor/TextureEditor.tscn").instance()
	shader_settings_instance = load("res://scenes/editor/ShaderSettings.tscn").instance()

	var sidebar_node = get_tree().root.find_node("VBoxContainer", true, false)
	var sidebars = get_tree().get_nodes_in_group("SidebarController")
	if sidebars.size() > 0:
		sidebar_controller = sidebars[0]
	elif sidebar_node and sidebar_node.has_method("add_tool_tab"):
		sidebar_controller = sidebar_node

	if sidebar_controller:
		sidebar_controller.call_deferred("add_tool_tab", palette_viewer_instance, "Palette")
		sidebar_controller.call_deferred("add_tool_tab", recolor_settings_instance, "Recolor")
		sidebar_controller.call_deferred("add_tool_tab", texture_editor_settings_instance, "Texture")
		sidebar_controller.call_deferred("add_tool_tab", paintball_settings_instance, "Paint")
		sidebar_controller.call_deferred("add_tool_tab", move_mode_settings_instance, "Move")
		sidebar_controller.call_deferred("add_tool_tab", line_mode_settings_instance, "Line")
		sidebar_controller.call_deferred("add_tool_tab", preset_settings_instance, "Preset")
		sidebar_controller.call_deferred("add_tool_tab", auto_paintballer_settings_instance, "AutoPaint")
		sidebar_controller.call_deferred("add_tool_tab", project_settings_instance, "Shape")

	else:
		print("[WARNING] PetViewContainer: SidebarController not found, adding settings to SceneRoot as fallback")
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", palette_viewer_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", recolor_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", texture_editor_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", paintball_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", move_mode_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", line_mode_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", preset_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", auto_paintballer_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", project_settings_instance)

	get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", shader_settings_instance)
	
	paintball_check_box.connect("toggled", self, "_on_paintball_mode_toggled")
	preset_mode_check_box.connect("toggled", self, "_on_preset_mode_toggled")
	project_mode_check_box.connect("toggled", self, "_on_project_mode_toggled")

	auto_paintballer_check_box.connect("toggled", self, "_on_auto_paintballer_mode_toggled")

	view_palette_check_box.connect("toggled", self, "_on_view_palette_check_box_toggled")
	palette_viewer_instance.connect("visibility_changed", self, "_on_palette_visibility_changed")

	view_variations_check_box.connect("toggled", self, "_on_view_variations_toggled")
	variation_tree.connect("visibility_changed", self, "_on_variation_visibility_changed")

	line_mode_check_box.connect("toggled", self, "_on_line_mode_toggled")
	move_mode_check_box.connect("toggled", self, "_on_move_mode_toggled")
	recolor_mode_check_box.connect("toggled", self, "_on_recolor_mode_toggled")
	texture_editor_mode_check_box.connect("toggled", self, "_on_texture_editor_mode_toggled")

	tools_menu.connect(
		"paintball_mode_for_ball_toggled", self, "_on_paintball_mode_for_ball_toggled"
	)

	if is_instance_valid(lnz_text_edit):
		paintball_settings_instance.connect(
			"apply_paintballz", lnz_text_edit, "_on_apply_paintballz"
		)
	if is_instance_valid(pet_node):
		paintball_settings_instance.connect("clear_paintballz", pet_node, "_on_clear_paintballz")
	paintball_settings_instance.connect("delete_mode_toggled", self, "_on_delete_mode_toggled")

	if is_instance_valid(pet_node):
		pet_node.connect("palette_changed", preset_settings_instance, "set_palette")
	preset_settings_instance.connect("eyedropper_toggled", self, "_on_eyedropper_toggled")
	preset_settings_instance.connect("apply_to_selection", self, "_on_preset_apply_selection")
	preset_settings_instance.connect("unselect_all", self, "_on_unselect_all")
	preset_settings_instance.connect("select_balls_by_ids", self, "_on_select_balls_by_ids")

	if is_instance_valid(lnz_text_edit):
		project_settings_instance.connect("apply_projections", lnz_text_edit, "write_project_ball_section")
	project_settings_instance.connect("randomize_body_proportions", self, "_on_randomize_body_proportions")
	project_settings_instance.connect("randomize_moves", self, "_on_randomize_moves")

	if is_instance_valid(pet_node):
		auto_paintballer_settings_instance.connect("randomize_auto_paintballz", pet_node, "_on_randomize_auto_paintballz")
		auto_paintballer_settings_instance.connect("clear_auto_paintballz", pet_node, "_on_clear_auto_paintballz")
		auto_paintballer_settings_instance.connect("apply_auto_paintballz", pet_node, "_on_apply_auto_paintballz")
	auto_paintballer_settings_instance.connect("affected_list_changed", self, "_on_affected_list_changed")
	auto_paintballer_settings_instance.connect("unselect_all", self, "_on_unselect_all")

	move_mode_settings_instance.connect("apply_moves", self, "_on_move_mode_apply")
	move_mode_settings_instance.connect("clear_moves", self, "_on_move_mode_clear")
	move_mode_settings_instance.connect("unselect_all", self, "_on_unselect_all")
	move_mode_settings_instance.connect("unselect_side", self, "_on_unselect_side")
	move_mode_settings_instance.connect("align_selection", self, "_on_align_selection")
	move_mode_settings_instance.connect("snap_selection", self, "_on_snap_selection")
	move_mode_settings_instance.connect("nudge_selection", self, "_on_nudge_selection")
	move_mode_settings_instance.connect("select_group", self, "_on_move_mode_select_group")
	move_mode_settings_instance.connect("rotate_selection", self, "_on_rotate_selection")
	move_mode_settings_instance.connect("select_balls_by_ids", self, "_on_select_balls_by_ids")
	move_mode_settings_instance.connect("flip_selection", self, "_on_flip_selection")
	move_mode_settings_instance.connect("pivot_changed", self, "_on_pivot_changed")
	move_mode_settings_instance.connect("apply_scale", self, "_on_apply_scale")

	if is_instance_valid(lnz_text_edit):
		recolor_settings_instance.connect("recolor", lnz_text_edit, "_on_ToolsMenu_recolor")
		recolor_settings_instance.connect("apply_batch_bucket", lnz_text_edit, "apply_batch_presets")

	var shader_settings_btn = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/ShaderSettingsButton")
	if is_instance_valid(shader_settings_btn):
		shader_settings_btn.connect("pressed", self, "_on_ShaderSettingsButton_pressed")

	if is_instance_valid(shader_settings_instance):
		shader_settings_instance.connect("texture_rotation_mode_changed", self, "_on_texture_rotation_mode_changed")
		shader_settings_instance.connect("texture_rotation_input_changed", self, "_on_texture_rotation_input_changed")
		shader_settings_instance.connect("texture_affected_by_size_changed", self, "_on_texture_affected_by_size_changed")
		shader_settings_instance.connect("texture_affected_by_rotation_changed", self, "_on_texture_affected_by_rotation_changed")
		shader_settings_instance.connect("texture_flat_colors_changed", self, "_on_texture_flat_colors_changed")
		# shader_settings_instance.connect("texture_use_quadrants_changed", self, "_on_texture_use_quadrants_changed")
		shader_settings_instance.connect("texture_rotation_mode_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
		shader_settings_instance.connect("texture_rotation_input_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
		shader_settings_instance.connect("texture_affected_by_size_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
		shader_settings_instance.connect("texture_affected_by_rotation_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")

	diameter_min_spinbox = paintball_settings_instance.find_node("DiameterMin")
	diameter_max_spinbox = paintball_settings_instance.find_node("DiameterMax")
	eraser_check_box = paintball_settings_instance.find_node("EraserCheckBox")
	pivot_ball_spinbox = move_mode_settings_instance.find_node("PivotBall")
	use_pivot_check_box = move_mode_settings_instance.find_node("UsePivotCheckBox")

	Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_IBEAM, Vector2(30, 31))
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_CROSS, Vector2(30, 31))
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_POINTING_HAND, Vector2(30, 31))

	helper_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	select_check_box.connect("pressed", self, "_on_SelectCheckBox_pressed")

	var mode_popup = get_tree().root.get_node(
		"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel"
	)
	mode_popup.connect("about_to_show", self, "_on_ModePopup_about_to_show")

	_setup_3d_gizmos()

	# check flipped view...
	tex.rect_scale.x = -1.0
	tex.rect_pivot_offset = tex.rect_size / 2.0


func _ensure_panel_visible(panel):
	if panel.is_docked:
		if sidebar_controller and sidebar_controller.tab_container.current_tab != panel.get_index():
			sidebar_controller.switch_to_tab(panel)
	else:
		panel.show()
		panel.raise()


func _rebuild_spatial_hash():
	_spatial_grid_2d.clear()
	var all_balls = _get_all_visual_balls()
	var viewport_offset = tex.get_global_transform().origin
	
	for ball in all_balls:
		if not is_instance_valid(ball) or not ball.visible: 
			continue
			
		var projected_pos = camera.unproject_position(ball.global_transform.origin) 
		var screen_pos = viewport_offset + (projected_pos * tex.rect_scale) 
		
		var cell = (screen_pos / GRID_CELL_SIZE).floor()
		if not _spatial_grid_2d.has(cell):
			_spatial_grid_2d[cell] = []
		_spatial_grid_2d[cell].append(ball)


func _reset_tab_state():
	if is_instance_valid(_last_selected_by_tab):
		if not move_mode:
			_last_selected_by_tab.apply_outline_state(
				get_visual_state_for_ball(_last_selected_by_tab)
			)
	_last_selected_by_tab = null
	_current_tab_index = -1
	_nearby_balls_cache.clear()
	_tab_activation_mouse_pos = Vector2.ZERO
	mark_ui_dirty()


func mark_ui_dirty():
	# Use to trigger _process so it's not triggering every time the mouse moves...
	ui_is_dirty = true


func get_px_scale() -> float:
	if not is_instance_valid(pet_node):
		return 0.002
	return pet_node.pixel_world_size


func get_lnz_scale() -> float:
	if not is_instance_valid(pet_node) or not pet_node.get("lnz") or not pet_node.lnz.has("scales"):
		return 1.0
	return pet_node.lnz.scales.x / 255.0


func _process(_delta):
	if is_instance_valid(_overlay_camera):
		_sync_overlay()

	# AXIS GIZMO
	_update_3d_gizmo_visibility()

	# Always sync Preset Mode preview ball
	if preset_mode and is_instance_valid(preset_settings_instance):
		preset_settings_instance.sync_camera(camera.global_transform)

	# Skip helper text update, if UI is not dirty
	if not ui_is_dirty:
		return

	# HELPER TEXT
	var header = ""
	var body = ""
	var footer = ""

	# HIGHLIGHTS
	var highlighted_ball = null
	if is_instance_valid(_last_selected_by_tab):
		highlighted_ball = _last_selected_by_tab
		var b_name = lnz_text_edit.get_ball_name(highlighted_ball.ball_no)
		var total_count = _nearby_balls_cache.size()
		var current_idx = max(0, _current_tab_index) + 1
		header = "Hovered: %s #%d (tabbable %d/%d)" % [b_name, highlighted_ball.ball_no, current_idx, total_count]
	elif selecting_on and last_selected_is_valid():
		highlighted_ball = last_selected
		var b_name = lnz_text_edit.get_ball_name(highlighted_ball.ball_no)
		header = "Hovered: %s #%d" % [b_name, highlighted_ball.ball_no]

	# MODES
	if linez_mode:
		var intended = get_intended_ball(_get_viewport_pos_from_screen_pos(get_local_mouse_position())) 
		
		if is_instance_valid(linez_start_ball): 
			body = "Line Mode: Left-click target to END line (TAB to cycle ballz)"
		else:
			body = "Line Mode: Left-click target to START line (TAB to cycle ballz)"
		
		Input.set_custom_mouse_cursor(rope, 0, Vector2(30, 31))

	elif paintball_mode:
		#paintball_settings_instance.sync_camera(camera.global_transform)
		var delete_mode = paintball_settings_instance.find_node("EraserCheckBox").pressed
		var temp_eraser_active = Input.is_key_pressed(KEY_CONTROL)
		var is_design_mode = paintball_settings_instance.is_design_mode_active()

		if delete_mode:
			body = "Paintball Mode: Left-click to erase nearest paintball."
		elif temp_eraser_active:
			if is_design_mode:
				body = "Design Mode: Ctrl+Scroll to Scale | Left-Click to Stamp."
			else:
				body = "Paintball Mode: Left-click to erase nearest paintball."
				Input.set_custom_mouse_cursor(eraser, 0, Vector2(30, 31))
		elif is_design_mode:
			body = "Design Mode: Stamp pattern onto ball.\nScroll to Rotate | Ctrl+Scroll to Scale."
			Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
		else:
			var freeline_on = (
				paintball_settings_instance.find_node("FreelineCheckBox").pressed
				or Input.is_key_pressed(KEY_SHIFT)
			)
			if freeline_on:
				body = "Paintball Mode (Freeline): Left-click and drag to draw."
			else:
				body = "Paintball Mode: Left-click to add next paintball"
			Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			body += "\nPainting on ball " + str(paintball_target_ball.ball_no)

	elif auto_paintballer_mode:
		body = "Auto Paintballer: Use the panel to generate random paintballz patterns. Click ballz to affect. Hit 'Apply' to save changes."

	elif project_mode:
		body = "Project Mode: Use the panel to add or randomize projections.\nHit 'Apply to LNZ' to save changes."

	elif move_mode:
		body = "Move Mode: Click to select, CTRL+Click to toggle multiple.\nDrag selected balls to move group."
		var queued_count = pending_moves.size()
		if queued_count > 0:
			body += "\nQueued Moves: " + str(queued_count)

	elif preset_mode:
		preset_settings_instance.sync_camera(camera.global_transform)
		var is_eyedropper = (
			Input.is_key_pressed(KEY_ALT)
			or preset_settings_instance.is_eyedropper_active()
		)
		if is_eyedropper:
			body = "Eyedropper Mode: Left-click a ball to sample its properties."
			Input.set_custom_mouse_cursor(eyedropper, 0, Vector2(30, 31))
		else:
			body = "Preset Mode: Left-click to apply preset.\nHold ALT for eyedropper."
			if not preset_settings_instance.find_node("EyedropperToggle").pressed:
				Input.set_custom_mouse_cursor(bigbrush, 0, Vector2(30, 31))

	elif recolor_mode:
		body = "Recolor Mode: Use Color Swap to replace colors or Paint Bucket to queue changes."
		Input.set_custom_mouse_cursor(paintbucket, 0, Vector2(30, 31))

	elif selecting_on:
		body = "Select Mode: when hovering, cycle ballz using TAB..."

	elif is_dragging:
		pass
		#update() # AXIS GIZMO

	else:
		if Input.is_key_pressed(KEY_CONTROL):
			body = "Open Tools Menu (CTRL + SPACE)\nApply and Save Changes (CTRL + S)\nFlash Ballz (CTRL + Q)"
		elif Input.is_key_pressed(KEY_SHIFT):
			body = "Move Ball (SHIFT + left-click drag)\nScale Ball (SHIFT + ALT + left-click drag)"
		elif Input.is_key_pressed(KEY_SPACE):
			body = "Pan View (SPACE + left-click drag)"
		else:
			body = "Welcome to LnzLive!\nHelpful hints will appear here..."

	# HOTKEYS
	if highlighted_ball:
		footer = "\nZ or B: [Ball Info] or [Add Ball] | X or M: [Move]\nC or P: [Project Ball] | V or L: [Line]"

	var locks = []
	if Input.is_key_pressed(KEY_X):
		locks.append("X")
	if Input.is_key_pressed(KEY_Y):
		locks.append("Y")
	if Input.is_key_pressed(KEY_Z):
		locks.append("Z")
	if locks.size() > 0:
		var lock_str = "Axis Lock: " + str(locks)
		if footer != "":
			footer += " | " + lock_str
		elif body != "Welcome to LnzLive!\nHelpful hints will appear here...":
			body += " | " + lock_str
		else:
			body = lock_str

	# HELPER
	var final_text = body
	if header != "":
		final_text = header + "\n" + final_text
	if footer != "":
		final_text += footer

	if helper_label.text != final_text:
		helper_label.text = final_text

	ui_is_dirty = false


func _draw():
	# BOX SELECTION
	if box_selecting:
		var rect = Rect2(box_start_pos, box_end_pos - box_start_pos)
		draw_rect(rect, Color(0.5, 1, 0.5, 0.2), true)
		draw_rect(rect, Color(0.5, 1, 0.5, 0.8), false)

	# TAB RADIUS
	# if selecting_on:
	# 	var mouse_pos = get_local_mouse_position()
	# 	draw_arc(mouse_pos, NEARBY_SCREEN_RADIUS, 0, TAU, 32, Color(1, 1, 0, 0.5), 2.0)

	# AXIS GIZMOS
	# var reference_ball = null

	# if is_dragging and is_instance_valid(drag_ball):
	# 	reference_ball = drag_ball
	# elif move_mode and not selected_balls.empty():
	# 	if is_instance_valid(selected_balls[0]):
	# 		reference_ball = selected_balls[0]

	# if reference_ball:
	# 	_draw_axis_gizmos(reference_ball)


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


func _setup_3d_gizmos():
	gizmo_3d_root = Spatial.new()
	pet_node.add_child(gizmo_3d_root)
	gizmo_3d_root.visible = false

	gizmo_x = _create_gizmo_line(Color.red, Vector3(1, 0, 0))
	gizmo_y = _create_gizmo_line(Color.green, Vector3(0, 1, 0))
	gizmo_z = _create_gizmo_line(Color.blue, Vector3(0, 0, 1))

	gizmo_3d_root.add_child(gizmo_x)
	gizmo_3d_root.add_child(gizmo_y)
	gizmo_3d_root.add_child(gizmo_z)


func _create_gizmo_line(color: Color, direction: Vector3) -> MeshInstance:
	var mi = MeshInstance.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.001
	cylinder.bottom_radius = 0.001
	cylinder.height = 0.5

	var mat = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.albedo_color = Color(color.r, color.g, color.b, GIZMO_OPACITY)
	mat.flags_no_depth_test = true

	mi.mesh = cylinder
	mi.material_override = mat

	if direction.x != 0:
		mi.rotation_degrees = Vector3(0, 0, 90)
	elif direction.z != 0:
		mi.rotation_degrees = Vector3(90, 0, 0)

	return mi


func _update_3d_gizmo_visibility():
	var reference_ball = null

	if is_dragging and is_instance_valid(drag_ball):
		reference_ball = drag_ball
	elif move_mode and not selected_balls.empty():
		reference_ball = selected_balls[0]
	elif selecting_on and is_instance_valid(last_selected):
		reference_ball = last_selected

	if not reference_ball or not is_instance_valid(reference_ball):
		gizmo_3d_root.visible = false
		return

	gizmo_3d_root.global_transform.origin = reference_ball.global_transform.origin

	var hotkey_x = Input.is_key_pressed(KEY_X)
	var hotkey_y = Input.is_key_pressed(KEY_Y)
	var hotkey_z = Input.is_key_pressed(KEY_Z)
	var any_hotkey = hotkey_x or hotkey_y or hotkey_z

	var ui_active_x = false
	var ui_active_y = false
	var ui_active_z = false

	if move_mode and is_instance_valid(move_mode_settings_instance):
		match move_mode_settings_instance.current_constraint_mode:
			"LockX":
				ui_active_x = true
			"LockY":
				ui_active_y = true
			"LockZ":
				ui_active_z = true
			"LockXY":
				ui_active_x = true
				ui_active_y = true
			"LockXZ":
				ui_active_x = true
				ui_active_z = true
			"LockYZ":
				ui_active_y = true
				ui_active_z = true
			"Free":
				ui_active_x = false
				ui_active_y = false
				ui_active_z = false

	var show_x = hotkey_x if any_hotkey else ui_active_x
	var show_y = hotkey_y if any_hotkey else ui_active_y
	var show_z = hotkey_z if any_hotkey else ui_active_z

	if not is_dragging:
		gizmo_3d_root.visible = false
		return

	gizmo_x.visible = show_x
	gizmo_y.visible = show_y
	gizmo_z.visible = show_z

	if not is_dragging and not any_hotkey:
		gizmo_3d_root.visible = false
		return

	gizmo_x.visible = show_x
	gizmo_y.visible = show_y
	gizmo_z.visible = show_z

	gizmo_3d_root.visible = show_x or show_y or show_z


### INPUT HANDLING ###

func _get_ball_sizing_info(pet_node: Node, ball_no: int) -> Dictionary:
	var is_addball = ball_no >= KeyBallsData.max_base_ball_num
	var bhd_size = 0
	var enl_x = 100.0
	var enl_y = 0.0

	if not is_addball:
		bhd_size = pet_node.bhd.ball_sizes[ball_no]
		
		# Determine if the ball is part of an enlarged group
		var head_ext = []
		var foot_ext = []
		if pet_node.lnz.species == KeyBallsData.Species.DOG:
			head_ext = KeyBallsData.head_ext_dog
			foot_ext = KeyBallsData.foot_ext_dog
		elif pet_node.lnz.species == KeyBallsData.Species.CAT:
			head_ext = KeyBallsData.head_ext_cat
			foot_ext = KeyBallsData.foot_ext_cat
		elif pet_node.lnz.species == KeyBallsData.Species.BABY:
			head_ext = KeyBallsData.head_ext_bab
			foot_ext = KeyBallsData.foot_ext_bab

		if ball_no in head_ext:
			enl_x = pet_node.lnz.head_enlargement.x
			enl_y = pet_node.lnz.head_enlargement.y
		else:
			for foot_group in foot_ext:
				if ball_no in foot_group:
					enl_x = pet_node.lnz.foot_enlargement.x
					enl_y = pet_node.lnz.foot_enlargement.y
					break
	else:
		if pet_node.lnz.addballs.has(ball_no):
			var ab = pet_node.lnz.addballs[ball_no]
			if ab.anchor_ball != -1:
				if ab.anchor_ball < pet_node.bhd.ball_sizes.size():
					bhd_size = pet_node.bhd.ball_sizes[ab.anchor_ball]

	return {
		"is_addball": is_addball, 
		"bhd_size": bhd_size,
		"enl_x": enl_x,
		"enl_y": enl_y
	}

func _get_viewport_pos_from_screen_pos(screen_pos: Vector2) -> Vector2:
	var global_pos = self.rect_global_position + screen_pos
	return tex.get_global_transform().affine_inverse().xform(global_pos)

func _get_screen_pos_from_viewport_pos(viewport_pos: Vector2) -> Vector2:
	var global_pos = tex.get_global_transform().xform(viewport_pos)
	return global_pos - self.rect_global_position

# TBD: refactor _gui_input with separate functions:
func _handle_box_selection(event: InputEvent) -> bool:
	if (
		not (move_mode or preset_mode or auto_paintballer_mode)
		or not Input.is_key_pressed(KEY_CONTROL)
	):
		return false

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			box_selecting = true
			box_start_pos = event.position
			box_end_pos = event.position
			return true
		elif box_selecting:
			box_selecting = false
			update()
			if box_start_pos.distance_to(event.position) < 5.0:
				var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
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
			return true

	if event is InputEventMouseMotion and box_selecting:
		box_end_pos = event.position
		update()
		return true

	return false


func _initialize_move_drag(drag_target_ball: Spatial, start_pos: Vector2, resizing: bool = false):
	is_dragging = true
	drag_ball = drag_target_ball
	drag_start_pos = start_pos
	is_resizing = resizing

	if resizing:
		#_scale_group_pivot = _get_rotation_pivot_origin(int(move_mode_settings_instance.find_node("PivotBall").value) if move_mode_settings_instance.find_node("UsePivotCheckBox").pressed else -1)
		_scale_group_pivot = _get_rotation_pivot_origin(
			int(pivot_ball_spinbox.value) if use_pivot_check_box.pressed else -1
		)

		_scale_group_initial_data.clear()
		for b in selected_balls:
			if is_instance_valid(b):
				_scale_group_initial_data[b.ball_no] = {
					"pos": b.global_transform.origin, "size": b.ball_size
				}
				var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)
				if partner_id != -1 and partner_id != b.ball_no:
					var mb = _find_visual_ball_by_no(partner_id)
					if mb:
						_scale_group_initial_data[partner_id] = {
							"pos": mb.global_transform.origin, "size": mb.ball_size
						}
		Input.set_custom_mouse_cursor(hand_pinch, 0, Vector2(30, 31))
	else:
		_record_move_start_state()
		for b in selected_balls:
			if is_instance_valid(b) and "ball_no" in b:
				if not pet_node._orig_world_pos.has(b.ball_no):
					pet_node._orig_world_pos[b.ball_no] = b.global_transform.origin
		Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))

	mark_ui_dirty()


func _handle_move_mode_gui_input(event: InputEvent) -> bool:
	if not move_mode:
		return false

	# Check for Nudge hotkey via Scroll
	if (
		event is InputEventMouseButton
		and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN)
	):
		var nudge_axis = ""
		if Input.is_key_pressed(KEY_X):
			nudge_axis = "x"
		elif Input.is_key_pressed(KEY_Y):
			nudge_axis = "y"
		elif Input.is_key_pressed(KEY_Z):
			nudge_axis = "z"

		if nudge_axis != "":
			var delta = 1.0 if event.button_index == BUTTON_WHEEL_UP else -1.0
			move_mode_settings_instance.change_nudge_value(nudge_axis, delta)
			get_tree().set_input_as_handled()
			return true

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				if Input.is_key_pressed(KEY_ALT):
					if Input.is_key_pressed(KEY_SHIFT) and selected_balls.size() > 0:
						_initialize_move_drag(selected_balls[0], event.position, true)
						return true
					else:
						var hover_pos = _get_viewport_pos_from_screen_pos(event.position)
						var hover_ball = get_intended_ball(hover_pos)
						if hover_ball:
							move_mode_settings_instance.set_pivot_ball(hover_ball.ball_no)
							var all_balls = (
								get_tree().get_nodes_in_group("balls")
								+ get_tree().get_nodes_in_group("addballs")
							)
							for b in all_balls:
								if is_instance_valid(b) and b.has_method("apply_outline_state"):
									b.apply_outline_state(get_visual_state_for_ball(b))
							return true

				var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))

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
						if not (hover in selected_balls):
							_on_unselect_all()
							selected_balls.append(hover)
							hover.apply_outline_state(hover.OutlineState.ACTIVE_SELECTED)

					_update_selected_ballz_in_settings()

					if selected_balls.size() > 0:
						_initialize_move_drag(hover, event.position, false)
						return true

				else:
					if not move_mode:
						_on_unselect_all()
			else:
				# Mouse release
				if is_dragging:
					var was_resizing = is_resizing
					is_dragging = false
					is_resizing = false
					Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
					drag_ball = null

					for b in selected_balls:
						if is_instance_valid(b):
							if not pending_moves.has(b.ball_no):
								var orig_p = b.global_transform.origin
								if pet_node._orig_world_pos.has(b.ball_no):
									orig_p = pet_node._orig_world_pos[b.ball_no]

								var orig_s = b.ball_size
								if was_resizing and _scale_group_initial_data.has(b.ball_no):
									orig_s = _scale_group_initial_data[b.ball_no].size

								pending_moves[b.ball_no] = {
									"orig_pos": orig_p,
									"new_pos": b.global_transform.origin,
									"orig_size": orig_s,
									"new_size": b.ball_size,
									"orig_basis": b.global_transform.basis,
									"new_basis": b.global_transform.basis
								}
							else:
								pending_moves[b.ball_no]["new_pos"] = b.global_transform.origin
								pending_moves[b.ball_no]["new_size"] = b.ball_size
								if was_resizing and _scale_group_initial_data.has(b.ball_no):
									if (
										not pending_moves[b.ball_no].has("orig_size")
										or (
											pending_moves[b.ball_no]["orig_size"]
											== pending_moves[b.ball_no]["new_size"]
										)
									):
										pending_moves[b.ball_no]["orig_size"] = _scale_group_initial_data[b.ball_no].size

					move_mode_settings_instance.set_queued_count(pending_moves.size())
					_record_move_end_state("Drag Move")
					return true

				mark_ui_dirty()

	elif event is InputEventMouseMotion and is_dragging and drag_ball:
		if is_resizing:
			var mouse_delta = event.position - drag_start_pos
			var change_amount = mouse_delta.dot(Vector2(1, -1).normalized()) * 0.05
			var scale_factor = max(0.1, 1.0 + change_amount)

			Input.set_custom_mouse_cursor(
				hand_stretch if change_amount > 0 else hand_pinch, 0, Vector2(30, 31)
			)

			var engine_scale = pet_node.lnz.scales[1]
			for b_no in _scale_group_initial_data:
				var b = _find_visual_ball_by_no(b_no)
				if not is_instance_valid(b):
					continue

				var initial = _scale_group_initial_data[b_no]

				var offset_from_pivot = initial.pos - _scale_group_pivot
				b.global_transform.origin = _scale_group_pivot + (offset_from_pivot * scale_factor)

				var target_visual = clamp(initial.size * scale_factor, 1.0, 500.0)
				var sizing_info = _get_ball_sizing_info(pet_node, b_no)
				var is_addball = sizing_info.is_addball
				var bhd_s = sizing_info.bhd_size

				var snapped_visual = LnzLiveUtils.snap_visual_size(
					target_visual, is_addball, engine_scale, bhd_s, sizing_info.enl_x, sizing_info.enl_y
				)
				b.set_ball_size(snapped_visual)

			if move_mode_settings_instance.is_mirror_x_active():
				_apply_mirror_scale(
					selected_balls, scale_factor, true, true, _scale_group_pivot, true
				)
			return true

		var screen_pos = _get_viewport_pos_from_screen_pos(event.position)
		var ray_o = camera.project_ray_origin(screen_pos)
		var ray_d = camera.project_ray_normal(screen_pos)

		var plane_n = camera.global_transform.basis.z.normalized()
		var plane_p = drag_ball.global_transform.origin
		var intersect = LnzLiveUtils.intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)

		if intersect:
			var drag_current_pos = intersect

			var prev_screen_pos = _get_viewport_pos_from_screen_pos(event.position - event.relative)
			var prev_ray_o = camera.project_ray_origin(prev_screen_pos)
			var prev_ray_d = camera.project_ray_normal(prev_screen_pos)
			var prev_intersect = LnzLiveUtils.intersect_ray_with_plane(
				prev_ray_o, prev_ray_d, plane_n, plane_p
			)

			if prev_intersect:
				var delta = drag_current_pos - prev_intersect

				var constraints = move_mode_settings_instance.get_constraints()

				var constrain_x = Input.is_key_pressed(KEY_X)
				var constrain_y = Input.is_key_pressed(KEY_Y)
				var constrain_z = Input.is_key_pressed(KEY_Z)

				var final_lock_x = constraints.x
				var final_lock_y = constraints.y
				var final_lock_z = constraints.z

				if constrain_x or constrain_y or constrain_z:
					final_lock_x = not constrain_x
					final_lock_y = not constrain_y
					final_lock_z = not constrain_z

				if final_lock_x:
					delta.x = 0
				if final_lock_y:
					delta.y = 0
				if final_lock_z:
					delta.z = 0

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

				if move_mode_settings_instance.is_mirror_x_active():
					_apply_mirror_move(selected_balls, delta)

		return true

	return false


func _handle_preset_mode_gui_input(event: InputEvent) -> bool:
	if not preset_mode:
		return false

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var target_ball = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if target_ball:
			var ball_no = target_ball.ball_no
			var sizing_info = _get_ball_sizing_info(pet_node, ball_no)
			
			var is_eyedropper_active = (
				preset_settings_instance.find_node("EyedropperToggle").pressed
				or Input.is_key_pressed(KEY_ALT)
			)
			if is_eyedropper_active:
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
						"group": ball_data.group,
						"size": int(round(target_ball.ball_size))
					}

					if pet_node.lnz.paintballs.has(ball_no):
						properties["paintballz"] = pet_node.lnz.paintballs[ball_no]
					preset_settings_instance.set_properties(properties)
			else:  # Brush mode
				var properties = preset_settings_instance.get_properties()
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
							var scale = pet_node.lnz.scales[1]
							properties["size"] = LnzLiveUtils.visual_size_to_lnz_size(
								properties.size, sizing_info.is_addball, scale, sizing_info.bhd_size, sizing_info.enl_x, sizing_info.enl_y
							)

				var scale_ratio = 1.0
				if properties.get("scale_paintballz", false) and properties.has("paintballz"):
					var source_ref = preset_settings_instance.source_ball_reference_size
					
					var final_lnz = properties.size
					var current_base_size = sizing_info.bhd_size + final_lnz
					if not sizing_info.is_addball:
						current_base_size = floor(current_base_size * (sizing_info.enl_x / 100.0)) + sizing_info.enl_y
					
					var scale = pet_node.lnz.scales[1]
					var target_visual_size = round((current_base_size - 2.0) * (scale / 255.0))
					target_visual_size -= 1.0 - fmod(target_visual_size, 2.0)
					
					scale_ratio = float(target_visual_size) / float(source_ref) if source_ref > 0 else 1.0

					var p_size_mod = properties.get("paintball_size_scale", 1.0)
					var p_pos_mod = properties.get("paintball_pos_scale", 1.0)

					if scale_ratio != 1.0 or p_size_mod != 1.0 or p_pos_mod != 1.0:
						var scaled_paintballz = []
						for pb in properties.paintballz:
							var new_pb = pb.duplicate()
							new_pb.position *= (scale_ratio * p_pos_mod)
							new_pb.size = int(round(new_pb.size * scale_ratio * p_size_mod))
							scaled_paintballz.append(new_pb)
						properties["paintballz"] = scaled_paintballz
						
				lnz_text_edit.write_preset_to_ball(target_ball.ball_no, properties, null, false)
		return true

	return false

func _handle_paint_mode_gui_input(event: InputEvent) -> bool:
	if not paintball_mode:
		return false
		
	if not is_instance_valid(paintball_settings_instance):
		print("[ERROR] PetViewContainer: paintball_settings_instance is invalid in _handle_paint_mode_gui_input")
		return false

	if (
		event is InputEventMouseButton
		and event.shift
		and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN)
	):
		#var diameter_min_spinbox = paintball_settings_instance.find_node("DiameterMin")
		#var diameter_max_spinbox = paintball_settings_instance.find_node("DiameterMax")
		print("[STATUS] PetViewContainer: adjusting brush size constraints via scroll")
		if event.button_index == BUTTON_WHEEL_UP:
			diameter_min_spinbox.value += 1
			diameter_max_spinbox.value += 1
		else:
			diameter_min_spinbox.value -= 1
			diameter_max_spinbox.value -= 1
		return true

	if paintball_settings_instance.is_design_mode_active():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == BUTTON_WHEEL_UP:
				print("[STATUS] PetViewContainer: adjusted design stamp scale/rotation (UP)")
				if event.control:
					design_scale_multiplier += 0.1
				else:
					design_rotation_angle += 0.1
				get_tree().set_input_as_handled()
				return true
			elif event.button_index == BUTTON_WHEEL_DOWN:
				print("[STATUS] PetViewContainer: adjusted design stamp scale/rotation (DOWN)")
				if event.control:
					design_scale_multiplier = max(0.1, design_scale_multiplier - 0.1)
				else:
					design_rotation_angle -= 0.1
				get_tree().set_input_as_handled()
				return true

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		var props = paintball_settings_instance.get_properties()
		var freeline_mode = (
			props.freeline
			or (
				event.shift
				and not (
					event.button_index == BUTTON_WHEEL_UP
					or event.button_index == BUTTON_WHEEL_DOWN
				)
			)
		)
		if freeline_mode:
			if event.pressed:
				print("[STATUS] PetViewContainer: started freeline path")
				if props.ordered and props.repeat:
					_ordered_color_index = 0
					_ordered_outline_color_index = 0
					_ordered_texture_index = 0
				freeline_active = true
				freeline_path.clear()
				last_freeline_point = event.position
			else:
				print("[STATUS] PetViewContainer: finished freeline path")
				freeline_active = false
				_finalize_freeline()
			return true

	if event is InputEventMouseMotion and freeline_active:
		var props = paintball_settings_instance.get_properties()
		var current_pos = event.position
		if current_pos.distance_to(last_freeline_point) > props.spacing:
			freeline_path.append(current_pos)
			last_freeline_point = current_pos
		return true

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		#var delete_mode = paintball_settings_instance.find_node("EraserCheckBox").pressed or Input.is_key_pressed(KEY_CONTROL)
		var delete_mode = eraser_check_box.pressed or Input.is_key_pressed(KEY_CONTROL)

		if delete_mode:
			print("[STATUS] PetViewContainer: attempted eraser click")
			var pending_paintballs = pet_node.get_pending_paintball_nodes()
			if pending_paintballs.empty():
				print("[WARNING] PetViewContainer: no pending paintballs to erase")
				return true

			var closest_paintball = null
			var min_dist_sq = INF
			var click_pos_local = event.position  # Use local mouse position

			for pb_node in pending_paintballs:
				if not is_instance_valid(pb_node) or not pb_node.is_inside_tree():
					continue

				var projected_pos_local = camera.unproject_position(pb_node.global_transform.origin)
				var paintball_screen_pos = _get_screen_pos_from_viewport_pos(projected_pos_local)
				
				var dist_sq = click_pos_local.distance_squared_to(paintball_screen_pos)

				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_paintball = pb_node

			if closest_paintball and min_dist_sq < 25 * 25:  # 25px threshold
				pet_node.remove_specific_pending_paintball(closest_paintball)
				print("[STATUS] PetViewContainer: erased closest paintball node: %s" % closest_paintball.name)
			else:
				print("[WARNING] PetViewContainer: no paintball close enough to erase (threshold distance: 25px)")
			return true

		var target_ball

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			target_ball = paintball_target_ball
		else:
			var target_mode = paintball_settings_instance.find_node("Target").selected
			if target_mode == 0:  # Hovered Ball
				target_ball = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
			else:  # Selected Ball
				if active_selected_ball and is_instance_valid(active_selected_ball):
					target_ball = active_selected_ball

		if target_ball:
			var screen_pos = _get_viewport_pos_from_screen_pos(event.position)
			var result = _create_paintball_at_position(screen_pos, target_ball)
			if result:
				_record_paint_action([result])
		return true

	return false


func _gui_input(event):
	if input_is_paused:
		return

	if _handle_box_selection(event):
		return

	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index != BUTTON_RIGHT
		and not Input.is_key_pressed(KEY_SHIFT)
		and not move_mode
		and not auto_paintballer_mode
		and not preset_mode
		and not linez_mode
	):
		_reset_tab_state()

	if _handle_move_mode_gui_input(event):
		return

	if _handle_preset_mode_gui_input(event):
		return

	if _handle_paint_mode_gui_input(event):
		return

	# Guard against entering hotkeys into text area when interacting with view container:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var focus_owner := get_focus_owner()
		if focus_owner and focus_owner is TextEdit:
			focus_owner.release_focus()

	# Open Tools Menu via right-click on hovered ball:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		get_tree().set_input_as_handled()
		var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
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
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
		and Input.is_key_pressed(KEY_SHIFT)
	):
		var alt_key = Input.is_key_pressed(KEY_ALT)

		#var hover = get_intended_ball((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))

		var hover = null
		if is_instance_valid(_last_selected_by_tab):
			hover = _last_selected_by_tab
		else:
			hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
			
		if hover:
			drag_ball = hover
			is_dragging = true

			if alt_key:
				is_resizing = true
				Input.set_custom_mouse_cursor(hand_pinch, 0, Vector2(30, 31))
				original_scale = drag_ball.ball_size
				drag_start_pos = event.position
				print("[STATUS] PetViewContainer: started scale drag on ball:", drag_ball.name)
			else:
				print("[STATUS] PetViewContainer: started drag on ball:", drag_ball.name)
				# is_dragging = true
				Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
				pet_node._orig_world_pos[drag_ball.ball_no] = drag_ball.global_transform.origin
		return

	# Update ball position or scale during moving or resizing:
	if event is InputEventMouseMotion and is_dragging and drag_ball:
		if is_resizing:
			var delta = event.position - drag_start_pos
			var change = delta.dot(Vector2(1, -1).normalized()) * 0.5

			if change < 0:
				Input.set_custom_mouse_cursor(hand_pinch, 0, Vector2(30, 31))
			else:
				Input.set_custom_mouse_cursor(hand_stretch, 0, Vector2(30, 31))

			var target_visual = clamp(original_scale + change, 1.0, 500.0)

			var sizing_info = _get_ball_sizing_info(pet_node, drag_ball.ball_no)
			var is_ab = sizing_info.is_addball
			var bhd_s = sizing_info.bhd_size
			var engine_scale = pet_node.lnz.scales[1]

			var snapped_visual = LnzLiveUtils.snap_visual_size(
				target_visual, is_ab, engine_scale, bhd_s, sizing_info.enl_x, sizing_info.enl_y
			)
			drag_ball.set_ball_size(snapped_visual)
		else:
			Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
			var screen_pos = _get_viewport_pos_from_screen_pos(event.position)
			var ray_o = camera.project_ray_origin(screen_pos)
			var ray_d = camera.project_ray_normal(screen_pos)
			var plane_n = camera.global_transform.basis.z.normalized()
			var plane_p = drag_ball.global_transform.origin
			var intersect = LnzLiveUtils.intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)
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
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and not event.pressed
		and is_dragging
		and drag_ball
		and not move_mode
	):
		if is_resizing:
			var delta = event.position - drag_start_pos
			var change = delta.dot(Vector2(1, -1).normalized()) * 0.5
			var raw_target_visual = clamp(original_scale + change, 1.0, 500.0)

			var final_size = get_absolute_lnz_size(raw_target_visual, drag_ball, pet_node)
			pet_node.emit_ball_resize(drag_ball.ball_no, final_size)
		else:
			print("[STATUS] PetViewContainer: final world position:", drag_ball.global_transform.origin)
			var lnz_pos = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[STATUS] PetViewContainer: dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_move(drag_ball.ball_no, lnz_pos)

		is_dragging = false
		is_resizing = false
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		#update() # AXIS GIZMO
		drag_ball = null
		return

	# Select ballz via double-click in Select Mode:
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.doubleclick
		and not move_mode
	):
		if selecting_on and last_selected_is_valid():
			last_selected.selected()
		return

	if linez_mode:
		if _handle_line_mode_input(event):
			return

	# Select ballz via single-click or clear selected ballz:
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
		and selecting_on
		and not move_mode
	):
		var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if hover:
			set_active_selected_ball(hover)
		else:
			clear_active_selected_ball()

	# Rotate or pan camera during general mouse motion:
	if event is InputEventMouseMotion and not is_dragging:
		#label.rect_global_position = event.global_position

		# if is_instance_valid(_last_selected_by_tab):
		# 	var current_mouse_pos = get_viewport().get_mouse_position()
		# 	if current_mouse_pos.distance_to(_tab_activation_mouse_pos) > TAB_RESET_THRESHOLD_PIXELS:
		# 		_reset_tab_state()
		# 	else:
		# 		pass

		var space_and_left = (
			Input.is_key_pressed(KEY_SPACE)
			and Input.is_mouse_button_pressed(BUTTON_LEFT)
		)
		var middle_drag = Input.is_mouse_button_pressed(BUTTON_MIDDLE)

		if space_and_left or middle_drag:
			var motion = event.relative
			#camera.transform.origin.y += motion.y * 0.001 / tex.rect_scale.x
			camera.transform.origin.y -= motion.y * 0.001 / tex.rect_scale.x
			camera.transform.origin.x += motion.x * 0.001 / tex.rect_scale.x
		elif Input.is_mouse_button_pressed(BUTTON_LEFT):
			var motion = event.relative
			camera_holder.rotation.x += motion.y * 0.01
			#camera_holder.rotation.y += motion.x * -0.01
			camera_holder.rotation.y -= motion.x * -0.01

		# Highlight hovered ball in line creation mode:
		if linez_mode and not selecting_on:
			Input.set_custom_mouse_cursor(rope, 0, Vector2(30, 31))
			var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
			for b in _get_all_visual_balls():
				if b != linez_start_ball and b.has_method("apply_outline_state"):
					b.apply_outline_state(b.OutlineState.NONE)
			if hover and hover != linez_start_ball and hover.has_method("apply_outline_state"):
				hover.apply_outline_state(hover.OutlineState.HOVER)
		elif not preset_mode and not paintball_mode and not project_mode and not move_mode:
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))

	# Update hovered ball_label and trigger highlight for selectable ball:
	if (
		event is InputEventMouseMotion
		and selecting_on
		and not paintball_mode
		and not is_instance_valid(_last_selected_by_tab)
	):
		var screen_pos = _get_viewport_pos_from_screen_pos(event.position)

		var from = camera.project_ray_origin(screen_pos)
		var to = from + camera.project_ray_normal(screen_pos) * 950
		var result = camera.get_world().direct_space_state.intersect_ray(
			from, to, [], 0x7FFFFFFF, false, true
		)

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
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and is_dragging
		and drag_ball
		and not move_mode
	):
		var commit_now: bool = (
			(drag_started_via_code and event.pressed)
			or (not drag_started_via_code and not event.pressed)
		)
		if commit_now:
			print("[STATUS] PetViewContainer: final world position:", drag_ball.global_transform.origin)
			var lnz_pos = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[STATUS] PetViewContainer: dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_move(drag_ball.ball_no, lnz_pos)

			is_dragging = false
			is_resizing = false
			drag_started_via_code = false
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
			#update() # AXIS GIZMO
			drag_ball = null
			return

	if (
		auto_paintballer_mode
		and event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
	):
		var target_ball = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))

		if target_ball:
			auto_paintballer_settings_instance.add_affected_ball(target_ball.ball_no)

			if not (target_ball in selected_balls):
				selected_balls.append(target_ball)

			target_ball.apply_outline_state(target_ball.OutlineState.ACTIVE_SELECTED)

			get_tree().set_input_as_handled()
			return

	if (
		recolor_mode
		and event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
	):
		var target_ball = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if target_ball:
			recolor_settings_instance.queue_bucket_change(target_ball)
			get_tree().set_input_as_handled()
			return


func _handle_camera_view_key_input(event: InputEventKey) -> bool:
	if not event.pressed:
		return false

	match event.scancode:
		KEY_1:
			_set_camera_view("front")
			return true
		KEY_2:
			_set_camera_view("bottom")
			return true
		KEY_3:
			_set_camera_view("top")
			return true
		KEY_4:
			_set_camera_view("right")
			return true
		KEY_5:
			_set_camera_view("left")
			return true
		KEY_6:
			_set_camera_view("back")
			return true
		KEY_7:
			_set_camera_view("isorightbottom")
			return true
		KEY_8:
			_set_camera_view("isorighttop")
			return true
		KEY_9:
			_set_camera_view("isoleftbottom")
			return true
		KEY_0:
			_set_camera_view("isolefttop")
			return true
	return false


func _handle_mode_shortcut_key_input(event: InputEventKey) -> bool:
	if not event.pressed:
		return false

	if event.alt:
		match event.scancode:
			KEY_F:
				recolor_mode_check_box.pressed = !recolor_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_B:
				paintball_check_box.pressed = !paintball_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_L:
				line_mode_check_box.pressed = !line_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_G:
				preset_mode_check_box.pressed = !preset_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_M:
				move_mode_check_box.pressed = !move_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_P:
				project_mode_check_box.pressed = !project_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true

	if not event.control and not event.alt and not event.shift:
		match event.scancode:
			KEY_S:
				select_check_box.pressed = !select_check_box.pressed
				_on_SelectCheckBox_pressed()
				get_tree().set_input_as_handled()
				return true
			KEY_W:
				paintball_check_box.pressed = !paintball_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_E:
				line_mode_check_box.pressed = !line_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_R:
				preset_mode_check_box.pressed = !preset_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_U:
				move_mode_check_box.pressed = !move_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_D:
				project_mode_check_box.pressed = !project_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_A:
				auto_paintballer_check_box.pressed = !auto_paintballer_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_T:
				view_palette_check_box.pressed = !view_palette_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_G:
				recolor_mode_check_box.pressed = !recolor_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_H:
				lnz_text_edit._on_HeadShotButton_pressed()
				get_tree().set_input_as_handled()
				return true
			KEY_V:
				view_variations_check_box.pressed = !view_variations_check_box.pressed
				get_tree().set_input_as_handled()
				return true
	return false


func _handle_move_nudge_key_input(event: InputEventKey) -> bool:
	if move_mode and event.pressed:
		var nudge_axis = ""
		if Input.is_key_pressed(KEY_X):
			nudge_axis = "x"
		elif Input.is_key_pressed(KEY_Y):
			nudge_axis = "y"
		elif Input.is_key_pressed(KEY_Z):
			nudge_axis = "z"

		if nudge_axis != "":
			if event.scancode == KEY_EQUAL or event.scancode == KEY_KP_ADD:  # + key
				_record_move_start_state()  # Before change
				move_mode_settings_instance.change_nudge_value(nudge_axis, 1.0)
				_record_move_end_state("Nudge +")
				get_tree().set_input_as_handled()
				return true
			elif event.scancode == KEY_MINUS or event.scancode == KEY_KP_SUBTRACT:  # - key
				_record_move_start_state()  # Before change
				move_mode_settings_instance.change_nudge_value(nudge_axis, -1.0)
				_record_move_end_state("Nudge -")
				get_tree().set_input_as_handled()
				mark_ui_dirty()
				return true
	return false


func _unhandled_key_input(event):
	if input_is_paused:
		return

	if event is InputEventKey:
		if event.scancode in [KEY_X, KEY_Y, KEY_Z, KEY_SHIFT, KEY_CONTROL, KEY_ALT]:
			mark_ui_dirty()

	if event is InputEventKey and event.pressed and event.scancode == KEY_TAB:
		if selecting_on:
			get_tree().set_input_as_handled()
			_cycle_nearby_ballz()
			return

	if event.is_pressed() and event.scancode == KEY_ESCAPE:
		paintball_check_box.pressed = false
		line_mode_check_box.pressed = false
		move_mode_check_box.pressed = false
		preset_mode_check_box.pressed = false
		recolor_mode_check_box.pressed = false
		texture_editor_mode_check_box.pressed = false
		project_mode_check_box.pressed = false
		auto_paintballer_check_box.pressed = false
		view_palette_check_box.pressed = false
		view_variations_check_box.pressed = false

		get_tree().set_input_as_handled()
		return

	# Mini-history for Paintball and Move modes
	if event is InputEventKey and event.pressed and event.control and event.shift:
		if event.scancode == KEY_Z:  # Undo
			if paintball_mode:
				_undo_queued_paintball()
				get_tree().set_input_as_handled()
				return
			elif move_mode:
				_undo_queued_move()
				get_tree().set_input_as_handled()
				return
		elif event.scancode == KEY_X:  # Redo
			if paintball_mode:
				_redo_queued_paintball()
				get_tree().set_input_as_handled()
				return
			elif move_mode:
				_redo_queued_move()
				get_tree().set_input_as_handled()
				return

	if _handle_move_nudge_key_input(event):
		return

	# Open Tools Menu via CTRL+SPACE for last selected ball:
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_SPACE:
		get_tree().set_input_as_handled()
		if last_selected_is_valid():
			tools_menu.selected_visual_ball = last_selected
		else:
			tools_menu.selected_visual_ball = null
		tools_menu.rect_global_position = get_viewport().get_mouse_position()
		tools_menu.popup()
		return

	if _handle_mode_shortcut_key_input(event):
		return

	if _handle_camera_view_key_input(event):
		return

	if event.pressed and last_selected_is_valid():
		last_selected._input(event)


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

func _on_ShaderSettingsButton_pressed():
	if is_instance_valid(shader_settings_instance):
		shader_settings_instance.popup_centered()

func _on_texture_rotation_mode_changed(mode):
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_mode", mode)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_mode", mode)

func _on_texture_rotation_input_changed(input_vec):
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_input", input_vec)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_input", input_vec)

func _on_texture_affected_by_size_changed(is_affected):
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_size", is_affected)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_size", is_affected)

func _on_texture_affected_by_rotation_changed(is_affected):
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_rotation", is_affected)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_rotation", is_affected)

# func _on_texture_use_quadrants_changed(is_using: bool):
# 	var all_balls = _get_all_visual_balls()
# 	for b in all_balls:
# 		# Update the main ball
# 		if b.has_method("set_use_quadrants"):
# 			b.set_use_quadrants(is_using)
			
# 		# Update any attached paintballs
# 		for child in b.get_children():
# 			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
# 				var mat = child.get_node("MeshInstance").material_override
# 				if mat:
# 					mat.set_shader_param("use_quadrants", is_using)

func _on_texture_flat_colors_changed(is_flat: bool):
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("set_render_flat_colors"):
			b.set_render_flat_colors(is_flat)
			
			for child in b.get_children():
				if child.is_in_group("paintballs") and child.has_method("set_render_flat_colors"):
					child.set_render_flat_colors(is_flat)

	for l in get_tree().get_nodes_in_group("lines"):
		if is_instance_valid(l) and l.has_method("set_render_flat_colors"):
			l.set_render_flat_colors(is_flat)

	for p in get_tree().get_nodes_in_group("polygons"):
		if is_instance_valid(p) and p.has_method("set_render_flat_colors"):
			p.set_render_flat_colors(is_flat)

	if is_instance_valid(pet_node):
		pet_node.render_flat_colors_global = is_flat

# MODES

func _on_ModePopup_about_to_show():
	select_check_box.pressed = selecting_on

func _on_SelectCheckBox_pressed():
	selecting_on = select_check_box.pressed
	if !selecting_on:
		if last_selected_is_valid():
			last_selected._on_Area_mouse_exited()
		last_selected = null
		clear_active_selected_ball()
		ball_label.hide()
		for b in _get_all_visual_balls():
			if b and b.has_method("apply_outline_state"):
				b.apply_outline_state(b.OutlineState.NONE)
		tex.update()
	mark_ui_dirty()


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


# VISUALS
func set_active_selected_ball(ball):
	if (
		active_selected_ball
		and is_instance_valid(active_selected_ball)
		and "ball_no" in active_selected_ball
	):
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = ball
	active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.ACTIVE_SELECTED)
	_update_selected_ballz_in_settings()
	mark_ui_dirty()


func clear_active_selected_ball():
	if (
		active_selected_ball
		and is_instance_valid(active_selected_ball)
		and "ball_no" in active_selected_ball
	):
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = null
	_update_selected_ballz_in_settings()
	mark_ui_dirty()


func get_visual_state_for_ball(b):
	if not "ball_no" in b:
		return
	else:
		if move_mode:
			if use_pivot_check_box.pressed:
				#if move_mode_settings_instance.find_node("UsePivotCheckBox").pressed:
				#var pivot_id = int(move_mode_settings_instance.find_node("PivotBall").value)
				var pivot_id = int(pivot_ball_spinbox.value)
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


func last_selected_is_valid():
	return last_selected != null and is_instance_valid(last_selected)


func deal_with_last_selected():
	if last_selected != null and is_instance_valid(last_selected):
		last_selected._on_Area_mouse_exited()
		mark_ui_dirty()


func _on_Node_ball_mouse_enter(ball_info):
	if selecting_on:
		ball_label.text = str(ball_info.ball_no)
		ball_label.rect_global_position = get_viewport().get_mouse_position() + Vector2(25, 15)
		ball_label.show()
		mark_ui_dirty()


func _find_visual_ball_by_no(no: int) -> Spatial:
	if is_instance_valid(pet_node) and pet_node.ball_map:
		if pet_node.ball_map.has(no):
			var b = pet_node.ball_map[no]
			if is_instance_valid(b):
				return b
		return null

	var all_balls = (
		get_tree().get_nodes_in_group("balls")
		+ get_tree().get_nodes_in_group("addballs")
	)
	for b in all_balls:
		if is_instance_valid(b) and "ball_no" in b:
			if b.ball_no == no:
				return b
	return null


# func _find_visual_addball_by_no(no: int) -> Spatial:
# 	for b in get_tree().get_nodes_in_group("addballs"):
# 		if b.has_method("get"): # safety if some nodes aren't the ball script
# 			if b.ball_no == no:
# 				return b
# 	return null


func _get_all_visual_balls() -> Array:
	if is_instance_valid(pet_node) and pet_node.ball_map:
		return pet_node.ball_map.values()
	return get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")


func _on_affected_list_changed(ids: Array):
	_auto_paint_affected_cache = ids

	selected_balls.clear()
	for id in ids:
		var ball = _find_visual_ball_by_no(id)
		if ball and is_instance_valid(ball):
			selected_balls.append(ball)

	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))


func get_ball_under_mouse(screen_pos: Vector2):
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 10000

	var space_state = camera.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [], 1, false, true)

	if result and result.collider:
		var parent = result.collider.get_parent()
		if parent.is_in_group("balls") or parent.is_in_group("addballs"):
			if parent.get("omitted") == true and not pet_node.draw_omitted_balls:
				return null
			return parent
	return null


func get_intended_ball(mouse_pos: Vector2) -> Spatial:
	if is_instance_valid(_last_selected_by_tab):
		return _last_selected_by_tab

	return get_ball_under_mouse(mouse_pos)


func _sort_by_distance(a, b):
	return a.distance < b.distance


func _get_sorted_nearby_balls(raw_mouse_pos: Vector2) -> Array:
	_rebuild_spatial_hash()
	var nearby_balls = []
	var center_cell = (raw_mouse_pos / GRID_CELL_SIZE).floor()
	var viewport_offset = tex.get_global_transform().origin

	for x in range(-1, 2):
		for y in range(-1, 2):
			var cell_coord = center_cell + Vector2(x, y)
			if _spatial_grid_2d.has(cell_coord):
				for ball in _spatial_grid_2d[cell_coord]:
					var proj = camera.unproject_position(ball.global_transform.origin) 
					var ball_global_pos = viewport_offset + (proj * tex.rect_scale) 
					var dist = ball_global_pos.distance_to(raw_mouse_pos) 
					
					if dist < NEARBY_SCREEN_RADIUS: 
						nearby_balls.append({"ball": ball, "distance": dist})

	nearby_balls.sort_custom(self, "_sort_by_distance") 
	
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
		helper_label.text = (
			"No nearby ballz found for cycling (Radius: %s px)."
			% [NEARBY_SCREEN_RADIUS]
		)

	mark_ui_dirty()


func get_lnz_position_from_visual(drag_ball: Spatial, pet_node: Node) -> Vector3:
	var current_world = drag_ball.global_transform.origin
	var original_world = pet_node._orig_world_pos.get(drag_ball.ball_no, Vector3.ZERO)

	print(
		(
			"[STATUS] PetViewContainer: get_lnz_position_from_visual: ball %d world positions: current=%s, original=%s"
			% [drag_ball.ball_no, current_world, original_world]
		)
	)

	var delta_meters = current_world - original_world
	var lnz_offset = LnzLiveUtils.world_to_lnz_delta(
		delta_meters, pixel_world_size, pet_node.lnz.scales.x
	)
	print("[STATUS] PetViewContainer: get_lnz_position_from_visual: rounded LNZ‐space offset (int): %s" % lnz_offset)

	return lnz_offset


func get_absolute_lnz_size(raw_target_visual: float, drag_ball: Spatial, pet_node: Node) -> int:
	var sizing_info = _get_ball_sizing_info(pet_node, drag_ball.ball_no)
	var engine_scale = pet_node.lnz.scales[1]

	return LnzLiveUtils.visual_size_to_lnz_size(
		drag_ball.ball_size, sizing_info.is_addball, engine_scale, sizing_info.bhd_size, sizing_info.enl_x, sizing_info.enl_y
	)

func _isolate_target_ball(target_ball):
	_create_overlay()
	camera.cull_mask = 1

	var all_balls = _get_all_visual_balls()
	for ball in all_balls:
		if not is_instance_valid(ball):
			continue
		var area = ball.get_node_or_null("Area")
		if not area:
			continue

		var is_dependent = "base_ball_no" in ball and ball.base_ball_no == target_ball.ball_no

		if ball != target_ball:
			area.set_collision_layer_bit(0, false)
			area.set_collision_layer_bit(1, true)
			_set_visual_layer_recursive(ball, 1)
		else:
			area.set_collision_layer_bit(0, true)
			area.set_collision_layer_bit(1, false)
			_set_visual_layer_recursive(ball, 2)


func _restore_all_balls():
	var all_balls = _get_all_visual_balls()
	for ball in all_balls:
		if not is_instance_valid(ball):
			continue

		_set_visual_layer_recursive(ball, 1)

		var area = ball.get_node_or_null("Area")
		if not area:
			continue

		area.set_collision_layer_bit(0, true)
		area.set_collision_layer_bit(1, false)

	camera.cull_mask = 1048575

	if is_instance_valid(_overlay_viewport_container):
		_overlay_viewport_container.queue_free()
	if is_instance_valid(_dimmer_rect):
		_dimmer_rect.queue_free()


func _create_overlay():
	var scene_root = tex.get_parent()
	var bg_rect = scene_root.get_node("BackgroundColorRect")

	_dimmer_rect = ColorRect.new()
	_dimmer_rect.color = bg_rect.color
	_dimmer_rect.color.a = 0.5
	_dimmer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_overlay_viewport_container = ViewportContainer.new()
	_overlay_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_viewport_container.stretch = true

	_overlay_viewport = Viewport.new()
	_overlay_viewport.transparent_bg = true
	_overlay_viewport.handle_input_locally = false
	_overlay_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	_overlay_viewport.world = tex.get_child(0).world

	_overlay_camera = Camera.new()
	_overlay_camera.cull_mask = 2

	_overlay_viewport.add_child(_overlay_camera)
	_overlay_viewport_container.add_child(_overlay_viewport)

	scene_root.add_child(_dimmer_rect)
	scene_root.add_child(_overlay_viewport_container)

	var tex_idx = tex.get_index()
	scene_root.move_child(_dimmer_rect, tex_idx + 1)
	scene_root.move_child(_overlay_viewport_container, tex_idx + 2)

	_sync_overlay()


func _sync_overlay():
	if not is_instance_valid(_overlay_viewport_container):
		return

	_overlay_viewport_container.rect_position = tex.rect_position
	_overlay_viewport_container.rect_size = tex.rect_size
	_overlay_viewport_container.rect_scale = tex.rect_scale
	_overlay_viewport_container.rect_pivot_offset = tex.rect_pivot_offset

	_dimmer_rect.rect_position = tex.rect_position
	_dimmer_rect.rect_size = tex.rect_size
	_dimmer_rect.rect_scale = tex.rect_scale
	_dimmer_rect.rect_pivot_offset = tex.rect_pivot_offset

	if is_instance_valid(_overlay_camera) and is_instance_valid(camera):
		_overlay_camera.global_transform = camera.global_transform
		_overlay_camera.projection = camera.projection
		_overlay_camera.fov = camera.fov
		_overlay_camera.size = camera.size
		_overlay_camera.near = camera.near
		_overlay_camera.far = camera.far
		_overlay_camera.keep_aspect = camera.keep_aspect


func _set_visual_layer_recursive(node: Node, layer_value: int):
	if node is VisualInstance:
		node.layers = layer_value
	for child in node.get_children():
		_set_visual_layer_recursive(child, layer_value)


func _on_unselect_all():
	var to_update = selected_balls.duplicate()
	selected_balls.clear()

	if auto_paintballer_mode:
		_auto_paint_affected_cache.clear()

	for b in to_update:
		if is_instance_valid(b) and "ball_no" in b:
			b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	mark_ui_dirty()


func _on_unselect_side(side: String):
	if selected_balls.empty():
		return

	var symmetry_dict = {}
	match KeyBallsData.species:
		KeyBallsData.Species.CAT:
			symmetry_dict = KeyBallsData.cat_body_part_symmetry
		KeyBallsData.Species.DOG:
			symmetry_dict = KeyBallsData.dog_body_part_symmetry
		KeyBallsData.Species.BABY:
			symmetry_dict = KeyBallsData.baby_body_part_symmetry

	var left_lookup = {}
	var right_lookup = {}
	for main_part in symmetry_dict:
		for sub_part in symmetry_dict[main_part]:
			var part_info = symmetry_dict[main_part][sub_part]
			if part_info.has("left"):
				for id in part_info.left:
					left_lookup[id] = true
			if part_info.has("right"):
				for id in part_info.right:
					right_lookup[id] = true

	var to_remove = []
	for b in selected_balls:
		if not is_instance_valid(b) or not "ball_no" in b:
			continue

		var ball_no = b.ball_no
		var is_left = left_lookup.has(ball_no)
		var is_right = right_lookup.has(ball_no)
		var is_center = not is_left and not is_right

		var should_unselect = false
		match side:
			"left":
				should_unselect = is_left
			"right":
				should_unselect = is_right
			"center":
				should_unselect = is_center

		if should_unselect:
			to_remove.append(b)

	for b in to_remove:
		selected_balls.erase(b)
		if b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	mark_ui_dirty()


func _update_selected_ballz_in_settings():
	var ids = []
	var properties = preset_settings_instance.get_properties()
	var exclude_eyes = properties.get("exclude_eyes", false) if not move_mode else false

	var filter = []
	if exclude_eyes:
		filter += KeyBallsData.get_group_balls("Eyes")

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

	for id in ids:
		var ball = _find_visual_ball_by_no(id)
		if ball and is_instance_valid(ball):
			if "ball_no" in ball:
				selected_balls.append(ball)
				ball.apply_outline_state(ball.OutlineState.ACTIVE_SELECTED)

	_update_selected_ballz_in_settings()
	mark_ui_dirty()


func _commit_box_selection():
	var rect = Rect2(box_start_pos, box_end_pos - box_start_pos).abs()
	var all_balls = _get_all_visual_balls()

	var properties = preset_settings_instance.get_properties()
	var exclude_eyes = properties.get("exclude_eyes", false) if not move_mode else false
	var eye_ids = KeyBallsData.get_group_balls("Eyes") if exclude_eyes else []

	for b in all_balls:
		#if not is_instance_valid(b) or not b.is_inside_tree():
		if not is_instance_valid(b) or not b.visible:
			continue

		if b.get("omitted") == true and not pet_node.draw_omitted_balls:
			continue

		if not ("ball_no" in b):
			continue

		if b.ball_no in eye_ids:
			continue

		var projected_pos_local = camera.unproject_position(b.global_transform.origin)
		var pos_in_container = _get_screen_pos_from_viewport_pos(projected_pos_local)

		if rect.has_point(pos_in_container):
			if not (b in selected_balls):
				selected_balls.append(b)
				if b.has_method("apply_outline_state"):
					b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()


# HISTORY
func _capture_pending_state_snapshot():
	var snapshot = {}

	for b_no in pending_moves.keys():
		snapshot[b_no] = pending_moves[b_no].duplicate()

	for b in selected_balls:
		if is_instance_valid(b) and not snapshot.has(b.ball_no):
			snapshot[b.ball_no] = {
				"new_pos": b.global_transform.origin,
				"new_size": b.ball_size,
				"new_basis": b.global_transform.basis
			}

	return snapshot


func _record_move_history_entry(old_snapshot, new_snapshot):
	if old_snapshot.hash() == new_snapshot.hash():
		return

	move_history.append({"old": old_snapshot, "new": new_snapshot})
	move_redo_stack.clear()


func _restore_move_snapshot(snapshot):
	pending_moves = snapshot.duplicate(true)

	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if not "ball_no" in b:
			continue

		if pending_moves.has(b.ball_no):
			var data = pending_moves[b.ball_no]
			b.global_transform.origin = data.new_pos
			if data.has("new_size"):
				b.set_ball_size(data.new_size)
			b.apply_outline_state(get_visual_state_for_ball(b))
		else:
			if pet_node._orig_world_pos.has(b.ball_no):
				b.global_transform.origin = pet_node._orig_world_pos[b.ball_no]

			b.apply_outline_state(get_visual_state_for_ball(b))

	move_mode_settings_instance.set_queued_count(pending_moves.size())


func _cap_history_arrays():
	if paint_history.size() > MAX_INTERACTION_HISTORY:
		paint_history.pop_front()
	if move_history.size() > MAX_INTERACTION_HISTORY:
		move_history.pop_front()


func _undo_queued_move():
	if move_history.empty():
		return
	var entry = move_history.pop_back()
	move_redo_stack.append(entry)
	_restore_move_snapshot(entry.old)


func _redo_queued_move():
	if move_redo_stack.empty():
		return
	var entry = move_redo_stack.pop_back()
	move_history.append(entry)
	_restore_move_snapshot(entry.new)


func _record_paint_action(paintballs_added):
	if paintballs_added.empty():
		return
	print("[STATUS] PetViewContainer: Recording paint action with %d paintballs" % paintballs_added.size())
	paint_history.append(paintballs_added)
	paint_redo_stack.clear()
	_cap_history_arrays()


func _undo_queued_paintball():
	print("[STATUS] PetViewContainer: Undoing queued paintball action")
	if paint_history.empty():
		var data = pet_node.remove_last_pending_paintball()
		if data:
			paint_redo_stack.append([data])
		return

	var last_action = paint_history.pop_back()
	paint_redo_stack.append(last_action)

	for i in range(last_action.size()):
		pet_node.remove_last_pending_paintball()


func _redo_queued_paintball():
	print("[STATUS] PetViewContainer: Redoing queued paintball action")
	if paint_redo_stack.empty():
		return

	var action_to_redo = paint_redo_stack.pop_back()
	paint_history.append(action_to_redo)

	for pb_data in action_to_redo:
		pet_node.add_pending_paintball(pb_data)


func _record_move_start_state():
	_pre_move_state = _capture_pending_state_snapshot()


func _record_move_end_state(action_name):
	var current_state = _capture_pending_state_snapshot()
	_record_move_history_entry(_pre_move_state, current_state)
	_cap_history_arrays()


# HELPERS
func _flatten_symmetry_dict(dict: Dictionary) -> Array:
	var flat_list = []
	for main_part in dict:
		for sub_part in dict[main_part]:
			var part_info = dict[main_part][sub_part]
			if (
				part_info.has("left")
				and part_info.has("right")
				and not part_info.left.empty()
				and not part_info.right.empty()
			):
				flat_list.append(part_info)
	return flat_list


func begin_auto_move_for_ball(ball: Spatial) -> void:
	if not ball:
		return
	drag_ball = ball
	is_dragging = true
	is_resizing = false
	drag_started_via_code = true
	Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
	pet_node._orig_world_pos[ball.ball_no] = ball.global_transform.origin


func schedule_autodrag_for_addball(ball_no: int) -> void:
	pending_autodrag_addball_no = ball_no
	_wait_for_addball_then_autodrag()


func _wait_for_addball_then_autodrag() -> void:
	var tries := 10
	while tries > 0 and pending_autodrag_addball_no != -1:
		yield(get_tree(), "idle_frame")
		var visual := _find_visual_ball_by_no(pending_autodrag_addball_no)
		if visual:
			begin_auto_move_for_ball(visual)
			pending_autodrag_addball_no = -1
			return
		tries -= 1


### MODE MANAGEMENT ###


func _deactivate_other_modes(active_mode_name: String):
	if active_mode_name != "Paintball Mode":
		paintball_check_box.pressed = false
	if active_mode_name != "Line Mode":
		line_mode_check_box.pressed = false
	if active_mode_name != "Move Mode":
		move_mode_check_box.pressed = false
	if active_mode_name != "Preset Mode":
		preset_mode_check_box.pressed = false
	if active_mode_name != "Project Mode":
		project_mode_check_box.pressed = false
	if active_mode_name != "Auto Paintballer":
		auto_paintballer_check_box.pressed = false
	if active_mode_name != "Recolor Mode":
		recolor_mode_check_box.pressed = false
	if active_mode_name != "Texture Editor":
		texture_editor_mode_check_box.pressed = false
		texture_editor_mode_check_box.pressed = false


func _update_mode_panel_visibility(panel: Control, is_active: bool):
	if is_active:
		if "is_docked" in panel and panel.is_docked:
			sidebar_controller.dock_panel(panel)
			sidebar_controller.switch_to_tab(panel)
		elif sidebar_controller and (panel == variation_tree or panel == palette_viewer_instance):
			sidebar_controller.switch_to_tab(panel)
		else:
			panel.show()
			panel.raise()
	else:
		if "is_docked" in panel and not panel.is_docked:
			panel.hide()
		elif panel != variation_tree and panel != palette_viewer_instance:
			panel.hide()

		if sidebar_controller:
			var tree_tab = sidebar_controller.tab_container.get_node_or_null("FileTree")
			if tree_tab:
				var current_tab = sidebar_controller.tab_container.get_current_tab_control()
				if current_tab == null or current_tab == panel:
					sidebar_controller.switch_to_tab(tree_tab)


func _on_recolor_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Recolor Mode")
	recolor_mode = is_on
	_update_mode_panel_visibility(recolor_settings_instance, is_on)

	if is_on:
		mouse_default_cursor_shape = CURSOR_ARROW
		Input.set_custom_mouse_cursor(paintbucket, 0, Vector2(30, 31))
	else:
		recolor_settings_instance._on_ClearBucket_pressed()
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		recolor_settings_instance._on_ClearBucket_pressed()
	mark_ui_dirty()


func _on_paintball_mode_toggled(is_on):
	print("[STATUS] PetViewContainer: Paintball Mode toggled %s" % is_on)
	if is_on:
		_deactivate_other_modes("Paintball Mode")
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
	mark_ui_dirty()


func _on_move_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Move Mode")
	move_mode = is_on
	_update_mode_panel_visibility(move_mode_settings_instance, is_on)

	if is_on:
		move_mode_settings_instance.set_queued_count(pending_moves.size())
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		ball_label.hide()
		_reset_tab_state()
	else:
		_on_unselect_all()
		_on_move_mode_clear()
	mark_ui_dirty()


func _on_line_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Line Mode")
	linez_mode = is_on
	_update_mode_panel_visibility(line_mode_settings_instance, is_on)

	if is_on:
		Input.set_custom_mouse_cursor(rope, 0, Vector2(30, 31))
	else:
		line_mode_close = false
		if is_instance_valid(linez_start_ball):
			linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
		linez_start_ball = null
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
	mark_ui_dirty()


func _on_preset_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Preset Mode")
	preset_mode = is_on
	_update_mode_panel_visibility(preset_settings_instance, is_on)

	if is_on:
		if pet_node and pet_node.lnz:
			if pet_node.lnz.texture_list:
				preset_settings_instance.set_texture_list(pet_node.lnz.texture_list)
			if pet_node.lnz.palette:
				preset_settings_instance.set_palette(pet_node.lnz.palette)

		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_ARROW
	else:
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
	mark_ui_dirty()


func _on_auto_paintballer_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Auto Paintballer")
	auto_paintballer_mode = is_on
	_update_mode_panel_visibility(auto_paintballer_settings_instance, is_on)

	if not is_on:
		pet_node._on_clear_auto_paintballz()
		_on_unselect_all()
		_auto_paint_affected_cache.clear()
		var all_balls = _get_all_visual_balls()
		for b in all_balls:
			if is_instance_valid(b) and b.has_method("apply_outline_state"):
				b.apply_outline_state(b.OutlineState.NONE)
	mark_ui_dirty()


func _on_project_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Project Mode")
	project_mode = is_on
	_update_mode_panel_visibility(project_settings_instance, is_on)
	mark_ui_dirty()


### PALETTE VIEWER ###


func _on_view_palette_check_box_toggled(is_on):
	if is_instance_valid(palette_viewer_instance):
		_update_mode_panel_visibility(palette_viewer_instance, is_on)

	if is_on:
		if palette_viewer_instance is WindowDialog or palette_viewer_instance is Popup:
			palette_viewer_instance.popup()
		palette_viewer_instance.populate_colors()


func _on_palette_popup_closed():
	if view_palette_check_box.pressed:
		view_palette_check_box.pressed = false


func _on_palette_visibility_changed():
	if view_palette_check_box.pressed != palette_viewer_instance.visible:
		view_palette_check_box.pressed = palette_viewer_instance.visible


### VARIATION VIEWER ###


func _on_view_variations_toggled(is_on):
	if is_instance_valid(variation_tree):
		_update_mode_panel_visibility(variation_tree, is_on)

	if is_on and sidebar_controller:
		sidebar_controller.switch_to_tab(variation_tree)


func _on_variation_visibility_changed():
	if view_variations_check_box.pressed != variation_tree.visible:
		view_variations_check_box.pressed = variation_tree.visible


### RECOLOR MODE ###

### PAINT MODE ###


func _update_paintball_mode_ui():
	print("[STATUS] PetViewContainer: updating paintball mode UI (visible: %s)" % paintball_mode)
	if paintball_mode:
		_ensure_panel_visible(paintball_settings_instance)

		_set_pending_paintballs_visible(true)

		paintball_settings_instance.show()
		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_ARROW

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			paintball_settings_instance.find_node("Target").disabled = true
		else:
			paintball_settings_instance.find_node("Target").disabled = false
	else:
		# used to clear on exit
		#if pet_node:
		#	pet_node.clear_pending_paintballs()
		_set_pending_paintballs_visible(false)

		paintball_settings_instance.hide()
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _on_delete_mode_toggled(is_on):
	if is_on:
		Input.set_custom_mouse_cursor(eraser, 0, Vector2(30, 31))
	else:
		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))


func _set_pending_paintballs_visible(is_visible: bool):
	if is_instance_valid(pet_node):
		var pending = pet_node.get_pending_paintball_nodes()
		for pb in pending:
			if is_instance_valid(pb):
				pb.visible = is_visible


func _on_paintball_mode_for_ball_toggled(ball):
	print("[STATUS] PetViewContainer: paintball mode specifically focused on ball #%d" % ball.ball_no)
	close_paintball_on_apply = true
	paintball_target_ball = ball
	set_active_selected_ball(ball)
	paintball_settings_instance.find_node("Target").selected = 1
	if not paintball_check_box.pressed:
		paintball_check_box.pressed = true
	else:
		_update_paintball_mode_ui()
	_isolate_target_ball(ball)
	mark_ui_dirty()


func close_paintball_mode():
	print("[STATUS] PetViewContainer: closing paintball mode")
	paintball_check_box.pressed = false


func _finalize_freeline():
	if freeline_path.empty():
		print("[WARNING] PetViewContainer: freeline path is empty upon finalize")
		return
		
	print("[STATUS] PetViewContainer: finalizing freeline with %d points" % freeline_path.size())
	var props = paintball_settings_instance.get_properties()
	var jitter = props.jitter
	var stroke = []

	# Determine if there is a single target for the entire stroke
	var stroke_target_ball = null
	if paintball_target_ball and is_instance_valid(paintball_target_ball):
		stroke_target_ball = paintball_target_ball
	elif (
		props.target_mode == 1
		and active_selected_ball
		and is_instance_valid(active_selected_ball)
	):
		stroke_target_ball = active_selected_ball

	var path_len = freeline_path.size()
	for i in range(path_len):
		var point = freeline_path[i]
		var jittered_point = (
			point
			+ Vector2(rand_range(-jitter, jitter), rand_range(-jitter, jitter))
		)
		var screen_pos = _get_viewport_pos_from_screen_pos(jittered_point)

		var point_target_ball = stroke_target_ball
		if not point_target_ball:  # If no stroke-wide target, use hover mode
			point_target_ball = get_intended_ball(screen_pos)

		var current_diameter = -1  # default = random
		if props.tapered:
			var min_diam = props.diameter_min
			var max_diam = props.diameter_max

			if path_len == 1:
				current_diameter = min_diam
			else:
				var t = float(i) / (path_len - 1)
				var pingpong_t = 1.0 - abs(t * 2.0 - 1.0)  # 0 -> 1 -> 0
				var calculated_diameter = lerp(min_diam, max_diam, pingpong_t)

				current_diameter = int(round(calculated_diameter))

		if point_target_ball:
			stroke.append({"pos": screen_pos, "ball": point_target_ball, "diam": current_diameter})

	if props.get("shuffle", false):
		stroke.shuffle()

	var added_paintballs = []
	for data in stroke:
		var result = _create_paintball_at_position(data.pos, data.ball, data.diam)
		if result:
			added_paintballs.append(result)

	print("[STATUS] PetViewContainer: freeline generated %d valid paintballs" % added_paintballs.size())
	_record_paint_action(added_paintballs)


func _create_paintball_at_position(screen_pos, target_ball, diameter_override = -1):
	if not is_instance_valid(target_ball):
		print("[ERROR] PetViewContainer: target_ball is invalid in _create_paintball_at_position")
		return null
		
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 10000
	var space_state = camera.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [self], 1, true, true)

	if result and result.collider and result.collider.get_parent() == target_ball:
		print("[STATUS] PetViewContainer: paintball raycast hit target ball #%d" % target_ball.ball_no)
		var intersection_point = result.position

		if paintball_settings_instance.is_design_mode_active():
			var visual_radius = (intersection_point - target_ball.global_transform.origin).length()
			var engine_scale = pet_node.lnz.scales[1]
			var lnz_diam = (visual_radius * 2.0 / pixel_world_size) / (engine_scale / 255.0)

			var normal = (intersection_point - target_ball.global_transform.origin).normalized()
			var cam_up = camera.global_transform.basis.y
			var tangent_up = (cam_up - normal * cam_up.dot(normal)).normalized()
			if tangent_up.length_squared() < 0.001:
				tangent_up = camera.global_transform.basis.x.cross(normal).normalized()
			var tangent_right = tangent_up.cross(normal).normalized()
			var basis = Basis(tangent_right, normal, tangent_up)

			var pattern_pbs = paintball_settings_instance.paste_paintball_design(
				normal,
				basis,
				target_ball.ball_no,
				lnz_diam,
				design_scale_multiplier,
				design_rotation_angle
			)

			var px_scale = pet_node.pixel_world_size
			var lnz_scale = pet_node.lnz.scales.x / 255.0

			if px_scale == 0 or lnz_scale == 0:
				print("[ERROR] PetViewContainer: px_scale or lnz_scale is 0, cannot project design paintballz")
				return

			var pos_arr = pattern_pbs.positions
			var diam_arr = pattern_pbs.diameters
			var col_arr = pattern_pbs.colors
			var out_col_arr = pattern_pbs.outlines
			var out_type_arr = pattern_pbs.outline_types
			var fuzz_arr = pattern_pbs.fuzzes
			var group_arr = pattern_pbs.groups
			var tex_arr = pattern_pbs.textures
			var anc_arr = pattern_pbs.anchored

			for i in range(pos_arr.size()):
				var pos_normalized = pos_arr[i]
				var spot_world_rel = pos_normalized * (lnz_diam * 0.5 * px_scale * lnz_scale)
				var spot_local_rel = target_ball.global_transform.basis.xform_inv(spot_world_rel)
				var relative_pos_lnz = LnzLiveUtils.world_to_lnz_delta(
					spot_local_rel, px_scale, pet_node.lnz.scales.x
				)

				var pb_data = {
					"base_ball_no": target_ball.ball_no,
					"diameter": diam_arr[i],
					"color": col_arr[i],
					"outline_color": out_col_arr[i],
					"outline_type": out_type_arr[i],
					"fuzz": fuzz_arr[i],
					"group": group_arr[i],
					"texture": tex_arr[i],
					"anchored": anc_arr[i],
					"relative_pos_local": spot_local_rel,
					"relative_pos_lnz": relative_pos_lnz
				}

				pet_node.add_pending_paintball(pb_data)
			print("[STATUS] PetViewContainer: successfully created %d paintballs from design onto ball #%d" % [pos_arr.size(), target_ball.ball_no])
			return

		var props = paintball_settings_instance.get_properties()

		var color_list = LnzLiveUtils.parse_number_list(props.color)
		if color_list.empty():
			print("[ERROR] PetViewContainer: invalid color list format for paintball")
			push_warning("Invalid color list format.")
			return

		var outline_color_list = LnzLiveUtils.parse_number_list(props.outline_color, true)
		if outline_color_list.empty():
			print("[ERROR] PetViewContainer: invalid outline color list format for paintball")
			push_warning("Invalid outline color list format.")
			return

		var texture_list = LnzLiveUtils.parse_number_list(props.texture, true)
		if texture_list.empty():
			texture_list.append(-1)

		var local_relative_pos = target_ball.to_local(intersection_point)
		var world_relative_pos = intersection_point - target_ball.global_transform.origin
		var relative_pos_lnz = LnzLiveUtils.world_to_lnz_delta(
			world_relative_pos, pet_node.pixel_world_size, pet_node.lnz.scales.x
		)

		var color
		var outline_color
		var texture
		if props.ordered:
			color = color_list[_ordered_color_index % color_list.size()]
			_ordered_color_index += 1
			outline_color = outline_color_list[(
				_ordered_outline_color_index
				% outline_color_list.size()
			)]
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
			if props.get("pixel_mode", false):
				var base_size = float(target_ball.ball_size)
				if base_size == 0:
					base_size = 1.0
				diameter = int(ceil((diameter / base_size) * 100.0))
		else:
			if props.get("pixel_mode", false):
				var base_size = float(target_ball.ball_size)
				if base_size == 0:
					base_size = 1.0
				var rand_px = rand_range(props["diameter_min"], props["diameter_max"])
				diameter = int(ceil((rand_px / base_size) * 100.0))
			else:
				diameter = int(round(rand_range(props["diameter_min"], props["diameter_max"])))

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
		print("[STATUS] PetViewContainer: successfully created paintball on ball #%d" % target_ball.ball_no)
		return paintball_info
	return null


### SHAPE MODE ###


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
	print("[STATUS] PetViewContainer: _on_randomize_body_proportions: randomized body proportions and applied to LNZ")


func _on_randomize_moves(settings: Dictionary):
	var target_groups = settings.groups
	var mirror_x = settings.mirror_x
	var type = settings.type
	var range_min = settings.range_min
	var range_max = settings.range_max
	var jitter_radius_percent = settings.jitter_radius

	var moves_to_apply = {}

	var target_balls = []
	for group_name in target_groups:
		target_balls.append_array(KeyBallsData.get_group_balls(group_name))

	var unique_targets = {}
	for b in target_balls:
		unique_targets[b] = true
	target_balls = unique_targets.keys()

	var symmetry_dict = {}
	if KeyBallsData.species == KeyBallsData.Species.DOG:
		symmetry_dict = KeyBallsData.dog_body_part_symmetry
	elif KeyBallsData.species == KeyBallsData.Species.CAT:
		symmetry_dict = KeyBallsData.cat_body_part_symmetry
	elif KeyBallsData.species == KeyBallsData.Species.BABY:
		symmetry_dict = KeyBallsData.baby_body_part_symmetry

	var eye_iris_pairs = {}  # iris_id -> eye_id
	var eye_pairs_source = {}
	if KeyBallsData.species == KeyBallsData.Species.DOG:
		eye_pairs_source = KeyBallsData.eyes_dog
	elif KeyBallsData.species == KeyBallsData.Species.CAT:
		eye_pairs_source = KeyBallsData.eyes_cat
	elif KeyBallsData.species == KeyBallsData.Species.BABY:
		eye_pairs_source = KeyBallsData.eyes_bab

	for iris in eye_pairs_source:
		eye_iris_pairs[iris] = eye_pairs_source[iris]

	var assigned_offsets = {}

	randomize()

	for ball_no in target_balls:
		if assigned_offsets.has(ball_no):
			continue

		var offset = Vector3.ZERO

		# iris, check if eye already has offset
		if eye_iris_pairs.has(ball_no):
			var parent_eye = eye_iris_pairs[ball_no]
			if assigned_offsets.has(parent_eye):
				offset = assigned_offsets[parent_eye]
				assigned_offsets[ball_no] = offset
				moves_to_apply[ball_no] = offset
				continue

		# random offset
		if type == "range":
			var rx = rand_range(range_min.x, range_max.x)
			var ry = rand_range(range_min.y, range_max.y)
			var rz = rand_range(range_min.z, range_max.z)
			offset = Vector3(rx, ry, rz)
		elif type == "jitter":
			# % radius offset from ball size
			var ball_size = 10.0
			if pet_node.bhd and ball_no < pet_node.bhd.ball_sizes.size():
				ball_size = pet_node.bhd.ball_sizes[ball_no]
			elif pet_node.lnz.addballs.has(ball_no):
				var ab = pet_node.lnz.addballs[ball_no]
				if typeof(ab) == TYPE_OBJECT:
					ball_size = ab.size
				elif typeof(ab) == TYPE_DICTIONARY:
					ball_size = ab.get("size", 10)

			var radius = ball_size / 2.0
			var jitter_amount = radius * (jitter_radius_percent / 100.0)

			var v = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			offset = v * jitter_amount

		assigned_offsets[ball_no] = offset
		moves_to_apply[ball_no] = offset

		# Symmetry
		if mirror_x:
			var mirrored_ball = KeyBallsData.get_mirrored_ball(ball_no, symmetry_dict)

			if mirrored_ball != -1:
				var mirror_offset = Vector3(-offset.x, offset.y, offset.z)
				assigned_offsets[mirrored_ball] = mirror_offset
				moves_to_apply[mirrored_ball] = mirror_offset
			else:
				# zero out if center ball
				offset.x = 0
				assigned_offsets[ball_no] = offset
				moves_to_apply[ball_no] = offset

		# Find iris for eye
		for iris in eye_iris_pairs:
			if eye_iris_pairs[iris] == ball_no:
				assigned_offsets[iris] = offset
				moves_to_apply[iris] = offset

				if mirror_x:
					var mirrored_iris = KeyBallsData.get_mirrored_ball(iris, symmetry_dict)
					if mirrored_iris != -1:
						var mirror_offset = Vector3(-offset.x, offset.y, offset.z)
						assigned_offsets[mirrored_iris] = mirror_offset
						moves_to_apply[mirrored_iris] = mirror_offset

	if not moves_to_apply.empty():
		lnz_text_edit.set_batch_moves(moves_to_apply)
		print("[STATUS] PetViewContainer: _on_randomize_moves: randomized moves applied to %d ballz" % moves_to_apply.size())


### LINE MODE ###


func _handle_line_mode_input(event) -> bool:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		
		if hover:
			if !is_instance_valid(linez_start_ball):
				linez_start_ball = hover
				linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.ACTIVE_SELECTED)
				_reset_tab_state() 
			else:
				if hover != linez_start_ball:
					pet_node.emit_signal("line_created", linez_start_ball.ball_no, hover.ball_no)
					linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
					linez_start_ball = null
					_reset_tab_state()
					if line_mode_close:
						line_mode_check_box.pressed = false
			return true
	return false


### PRESET MODE ###


func _on_eyedropper_toggled(is_on):
	if is_on:
		Input.set_custom_mouse_cursor(eyedropper, 0, Vector2(30, 31))
	else:
		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))


func _on_preset_apply_selection():
	if selected_balls.empty():
		return

	var ids_to_restore = []
	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			ids_to_restore.append(b.ball_no)

	var base_properties = preset_settings_instance.get_properties()

	var exclusion_list = []
	if base_properties.get("exclude_eyes", false):
		exclusion_list = KeyBallsData.get_group_balls("Eyes")

	var batch_changes = {}

	for b in selected_balls:
		if not is_instance_valid(b) or not "ball_no" in b:
			continue
		if b.ball_no in exclusion_list:
			continue

		var ball_no = b.ball_no
		var per_ball_props = base_properties.duplicate()
		var sizing_info = _get_ball_sizing_info(pet_node, ball_no)

		var size_mode = base_properties.get("size_mode", 0)
		var ref_val = base_properties.get("size", 10)

		if size_mode == preset_settings_instance.SizeMode.SUM:
			var original = 0
			if pet_node.lnz.balls.has(ball_no):
				original = pet_node.lnz.balls[ball_no].size
			elif pet_node.lnz.addballs.has(ball_no):
				original = pet_node.lnz.addballs[ball_no].size
			per_ball_props["size"] = original + ref_val

		elif size_mode == preset_settings_instance.SizeMode.TRUE:
			var scale = pet_node.lnz.scales[1]
			per_ball_props["size"] = LnzLiveUtils.visual_size_to_lnz_size(
				ref_val, sizing_info.is_addball, scale, sizing_info.bhd_size, sizing_info.enl_x, sizing_info.enl_y
			)

		if per_ball_props.get("scale_paintballz", false) and per_ball_props.has("paintballz"):
			var source_ref = preset_settings_instance.source_ball_reference_size
			
			var final_lnz = per_ball_props["size"]
			var current_base_size = sizing_info.bhd_size + final_lnz
			if not sizing_info.is_addball:
				current_base_size = floor(current_base_size * (sizing_info.enl_x / 100.0)) + sizing_info.enl_y
			
			var scale = pet_node.lnz.scales[1]
			var target_visual_size = round((current_base_size - 2.0) * (scale / 255.0))
			target_visual_size -= 1.0 - fmod(target_visual_size, 2.0)
			
			var scale_ratio = float(target_visual_size) / float(source_ref) if source_ref > 0 else 1.0

			var p_size_mod = per_ball_props.get("paintball_size_scale", 1.0)
			var p_pos_mod = per_ball_props.get("paintball_pos_scale", 1.0)

			if scale_ratio != 1.0 or p_size_mod != 1.0 or p_pos_mod != 1.0:
				var scaled_paintballz = []
				for pb in per_ball_props["paintballz"]:
					var new_pb = pb.duplicate()
					new_pb.position *= (scale_ratio * p_pos_mod)
					new_pb.size = int(round(new_pb.size * scale_ratio * p_size_mod))
					scaled_paintballz.append(new_pb)
				per_ball_props["paintballz"] = scaled_paintballz

		batch_changes[ball_no] = per_ball_props

	if not batch_changes.empty():
		lnz_text_edit.apply_batch_presets(batch_changes)
		_restore_preset_selection(ids_to_restore)


func _restore_preset_selection(ids: Array):
	selected_balls.clear()

	for id in ids:
		var ball = _find_visual_ball_by_no(id)
		if is_instance_valid(ball):
			selected_balls.append(ball)
			if ball.has_method("apply_outline_state"):
				ball.apply_outline_state(ball.OutlineState.ACTIVE_SELECTED)

	_update_selected_ballz_in_settings()


### MOVE MODE ###


func _on_move_mode_clear():
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if not "ball_no" in b:
			continue

		if pending_moves.has(b.ball_no):
			var move_data = pending_moves[b.ball_no]

			b.global_transform.origin = move_data.orig_pos

			if move_data.has("orig_size"):
				b.set_ball_size(move_data.orig_size)

	pending_moves.clear()
	move_mode_settings_instance.set_queued_count(0)

	for b in all_balls:
		if not "ball_no" in b:
			continue
		b.apply_outline_state(get_visual_state_for_ball(b))

	mark_ui_dirty()


func _update_pivot_limit():
	if is_instance_valid(pet_node) and is_instance_valid(move_mode_settings_instance):
		var total_balls = 0
		if pet_node.ball_map:
			total_balls = pet_node.ball_map.size()
		else:
			total_balls = (
				get_tree().get_nodes_in_group("balls").size()
				+ get_tree().get_nodes_in_group("addballs").size()
			)

		move_mode_settings_instance.update_pivot_max(total_balls)


func _track_pending_move(ball):
	var current_size = ball.ball_size
	if not pending_moves.has(ball.ball_no):
		var orig_pos = ball.global_transform.origin
		if pet_node._orig_world_pos.has(ball.ball_no):
			orig_pos = pet_node._orig_world_pos[ball.ball_no]

		pending_moves[ball.ball_no] = {
			"orig_pos": orig_pos,
			"orig_size": current_size,
			"orig_basis": ball.global_transform.basis,
			"new_pos": ball.global_transform.origin,
			"new_size": current_size,
			"new_basis": ball.global_transform.basis
		}
	else:
		pending_moves[ball.ball_no]["new_pos"] = ball.global_transform.origin
		pending_moves[ball.ball_no]["new_size"] = current_size
		pending_moves[ball.ball_no]["new_basis"] = ball.global_transform.basis

	ball.apply_outline_state(get_visual_state_for_ball(ball))
	move_mode_settings_instance.set_queued_count(pending_moves.size())

	mark_ui_dirty()


func _on_move_mode_apply():
	if pending_moves.empty():
		return

	var needs_rebuild = false
	for b_no in pending_moves:
		var data = pending_moves[b_no]
		
		if data.has("orig_basis") and data.has("new_basis"):
			if data.orig_basis != data.new_basis:
				needs_rebuild = true
			else:
				data.erase("orig_basis")
				data.erase("new_basis")
				
		if data.has("orig_size") and data.has("new_size"):
			# if data.orig_size != data.new_size:
			if not is_equal_approx(data.orig_size, data.new_size):
				needs_rebuild = true
			else:
				data.erase("orig_size")
				data.erase("new_size")

	var selected_ids = []
	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			selected_ids.append(b.ball_no)

	pet_node.set_skip_next_rebuild(!needs_rebuild)
	lnz_text_edit.apply_batch_moves(pending_moves)

	pending_moves.clear()
	move_mode_settings_instance.set_queued_count(0)

	selected_balls.clear()
	for id in selected_ids:
		var new_b = _find_visual_ball_by_no(id)
		if new_b and is_instance_valid(new_b):
			selected_balls.append(new_b)

	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if not "ball_no" in b:
			continue
		pet_node._orig_world_pos[b.ball_no] = b.global_transform.origin
		b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	mark_ui_dirty()


func _on_align_selection(axis, mode):
	if selected_balls.empty():
		return

	_record_move_start_state()

	_align_ball_list(selected_balls, axis, mode)

	if move_mode_settings_instance.is_mirror_x_active():
		var mirrored_group = []

		for b in selected_balls:
			var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)

			if partner_id != -1 and partner_id != b.ball_no:
				var partner_visual = _find_visual_ball_by_no(partner_id)

				if (
					partner_visual
					and not (partner_visual in selected_balls)
					and not (partner_visual in mirrored_group)
				):
					mirrored_group.append(partner_visual)

		if not mirrored_group.empty():
			var target_mode = mode
			if axis == "x":
				if mode == 0:
					target_mode = 2
				elif mode == 2:
					target_mode = 0

			_align_ball_list(mirrored_group, axis, target_mode)

	_record_move_end_state("Align " + axis)


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
					if val < reference_val:
						reference_val = val
				elif mode == 2:
					if val > reference_val:
						reference_val = val

	for b in ball_list:
		if not "ball_no" in b:
			continue
		if axis == "x":
			b.global_transform.origin.x = reference_val
		elif axis == "y":
			b.global_transform.origin.y = reference_val
		elif axis == "z":
			b.global_transform.origin.z = reference_val
		_track_pending_move(b)


func _get_axis_val(ball, axis):
	if axis == "x":
		return ball.global_transform.origin.x
	if axis == "y":
		return ball.global_transform.origin.y
	if axis == "z":
		return ball.global_transform.origin.z
	return 0.0


func _on_snap_selection(axis, direction):
	if selected_balls.empty():
		return

	var all_balls = _get_all_visual_balls()
	var target_val = 0.0
	var first = true

	for b in all_balls:
		if not is_instance_valid(b):
			continue

		if b.get("omitted") == true:
			continue

		var val = _get_axis_val(b, axis)

		if first:
			target_val = val
			first = false
		else:
			if direction == -1:
				if val < target_val:
					target_val = val
			else:
				if val > target_val:
					target_val = val

	_snap_ball_list_to_target(selected_balls, axis, direction, target_val)

	if move_mode_settings_instance.is_mirror_x_active():
		var mirrored_group = []
		for b in selected_balls:
			var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)
			if partner_id != -1 and partner_id != b.ball_no:
				var partner_visual = _find_visual_ball_by_no(partner_id)
				if (
					partner_visual
					and not (partner_visual in selected_balls)
					and not (partner_visual in mirrored_group)
				):
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
				if val < selection_extreme:
					selection_extreme = val
			else:
				if val > selection_extreme:
					selection_extreme = val

	if first:
		return

	var offset = target_val - selection_extreme

	for b in ball_list:
		if not "ball_no" in b:
			continue
		if axis == "y":
			b.global_transform.origin.y += offset
		elif axis == "z":
			b.global_transform.origin.z += offset
		_track_pending_move(b)


func _on_nudge_selection(vector: Vector3):
	if selected_balls.empty():
		return

	_record_move_start_state()

	# var px_scale = pet_node.pixel_world_size
	# var lnz_scale = pet_node.lnz.scales.x / 255.0

	# var world_delta = vector
	# world_delta.y *= -1
	# world_delta = world_delta * (px_scale * lnz_scale)
	var world_delta = LnzLiveUtils.lnz_to_world_delta(
		vector, pet_node.pixel_world_size, pet_node.lnz.scales.x
	)

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

	_record_move_end_state("Nudge")


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


func _apply_eye_iris_binding(ball, delta):
	# Check for eye -> iris binding
	var eye_pairs_source = {}
	if KeyBallsData.species == KeyBallsData.Species.DOG:
		eye_pairs_source = KeyBallsData.eyes_dog
	elif KeyBallsData.species == KeyBallsData.Species.CAT:
		eye_pairs_source = KeyBallsData.eyes_cat
	elif KeyBallsData.species == KeyBallsData.Species.BABY:
		eye_pairs_source = KeyBallsData.eyes_bab

	for iris_id in eye_pairs_source:
		var eye_id = eye_pairs_source[iris_id]
		if eye_id == ball.ball_no:
			# ball is an Eye, so move its Iris if not already selected
			var iris_visual = _find_visual_ball_by_no(iris_id)
			if iris_visual and is_instance_valid(iris_visual):
				if not (iris_visual in selected_balls):
					# Iris not manually selected, so move it along with the eye
					iris_visual.global_transform.origin += delta
					_track_pending_move(iris_visual)


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


func _apply_mirror_scale(
	targets: Array,
	factor: float,
	scale_dist: bool,
	scale_size: bool,
	pivot_origin: Vector3,
	is_interactive: bool = false
):
	var selected_nos = {}
	for b in targets:
		selected_nos[b.ball_no] = true

	for b in targets:
		if not is_instance_valid(b):
			continue

		var partner_id = lnz_text_edit.find_mirrored_ball(b.ball_no)
		if partner_id == -1 or partner_id == b.ball_no or selected_nos.has(partner_id):
			continue

		var mb = _find_visual_ball_by_no(partner_id)
		if not is_instance_valid(mb):
			continue

		if scale_dist:
			var start_pos = mb.global_transform.origin

			if is_interactive and _scale_group_initial_data.has(partner_id):
				start_pos = _scale_group_initial_data[partner_id].pos
			elif not is_interactive:
				if not pet_node._orig_world_pos.has(partner_id):
					pet_node._orig_world_pos[partner_id] = start_pos

			var rel_pos = start_pos - pivot_origin
			mb.global_transform.origin = pivot_origin + (rel_pos * factor)

		if scale_size:
			mb.set_ball_size(b.ball_size)

		_track_pending_move(mb)


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

	_record_move_start_state()

	var pivot_origin = _get_rotation_pivot_origin(pivot_id)

	var rot_rad = Vector3(
		deg2rad(rotation_degrees.x), deg2rad(rotation_degrees.y), deg2rad(rotation_degrees.z)
	)

	var basis = Basis(Quat(rot_rad))

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
			var current_basis = b.global_transform.basis
			_track_pending_move(b)

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

	_record_move_end_state("Rotate")


func _on_flip_selection(axis_vector, pivot_id):
	if selected_balls.empty():
		return

	_record_move_start_state()

	var pivot_origin = _get_rotation_pivot_origin(pivot_id)

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
			var current_basis = b.global_transform.basis

			if not pending_moves.has(b.ball_no):
				_track_pending_move(b)

			var rel_pos = current_pos - pivot_origin
			var flipped_rel = rel_pos * axis_vector
			var new_pos = pivot_origin + flipped_rel

			if not pet_node._orig_world_pos.has(b.ball_no):
				pet_node._orig_world_pos[b.ball_no] = current_pos

			b.global_transform.origin = new_pos

			var scale_basis = Basis().scaled(axis_vector)
			b.global_transform.basis = scale_basis * b.global_transform.basis

			if scale_basis.determinant() < 0:
				var mesh_instance = b.get_node_or_null("MeshInstance")
				if mesh_instance:
					mesh_instance.scale.x *= -1.0

				for child in b.get_children():
					if child.is_in_group("paintballs"):
						var pb_mesh = child.get_node_or_null("MeshInstance")
						if pb_mesh:
							pb_mesh.scale.x *= -1.0

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

	_record_move_end_state("Flip")


func _on_apply_scale(factor: float, scale_dist: bool, scale_size: bool, pivot_id: int):
	if selected_balls.empty():
		return

	_record_move_start_state()

	var pivot_origin = _get_rotation_pivot_origin(pivot_id)

	for b in selected_balls:
		if not is_instance_valid(b):
			continue

		var addballz_base_selected = false
		var p = b.get_parent()
		while is_instance_valid(p) and p != get_tree().root:
			if p in selected_balls:
				addballz_base_selected = true
				break
			p = p.get_parent()

		if scale_dist:
			if not addballz_base_selected:
				var current_pos = b.global_transform.origin
				var rel_pos = current_pos - pivot_origin
				var new_rel_pos = rel_pos * factor
				var new_pos = pivot_origin + new_rel_pos

				if not pet_node._orig_world_pos.has(b.ball_no):
					pet_node._orig_world_pos[b.ball_no] = current_pos

				var delta = new_pos - current_pos
				b.global_transform.origin = new_pos

				_apply_eye_iris_binding(b, delta)

		if scale_size:
			var original_s = b.ball_size
			var target_visual = original_s * factor
			target_visual = clamp(target_visual, 1.0, 500.0)
			var sizing_info = _get_ball_sizing_info(pet_node, b.ball_no)
			var is_ab = sizing_info.is_addball
			var bhd_s = sizing_info.bhd_size
			var engine_scale = pet_node.lnz.scales[1]
			var snapped_visual = LnzLiveUtils.snap_visual_size(
				target_visual, is_ab, engine_scale, bhd_s, sizing_info.enl_x, sizing_info.enl_y
			)
			b.set_ball_size(snapped_visual)

			pass

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

	if move_mode_settings_instance.is_mirror_x_active():
		_apply_mirror_scale(selected_balls, factor, scale_dist, scale_size, pivot_origin)

	_record_move_end_state("Scale")


func _on_pivot_changed():
	var all_balls = _get_all_visual_balls()
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))


func _on_texture_editor_mode_toggled(is_on):
	if is_on:
		_deactivate_other_modes("Texture Editor")
	texture_editor_mode = is_on
	_update_mode_panel_visibility(texture_editor_settings_instance, is_on)
	mark_ui_dirty()
