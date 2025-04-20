extends Control

onready var camera_holder = get_tree().root.get_node("Root/SceneRoot/ViewportContainer/Viewport/CameraHolder") as Spatial
onready var camera = camera_holder.get_node("Camera") as Camera
onready var label = get_tree().root.get_node("Root/SceneRoot/Label")
onready var cube = get_tree().root.get_node("Root/PetRoot/MeshInstance") as Spatial
onready var tex = get_tree().root.get_node("Root/SceneRoot/ViewportContainer") as ViewportContainer
onready var popup = get_tree().root.get_node("Root/SceneRoot/PopupDialog") as WindowDialog

var last_selected
var selecting_on = false

var is_dragging = false
var drag_ball = null
var drag_offset = Vector3()
var pixel_world_size = 0.002

#func _ready():
#	flip_camera_view()

func flip_camera_view():
	var camera_transform = camera.transform
	camera_transform.basis.x *= -1
	camera.transform = camera_transform

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_DOWN:
			tex.rect_pivot_offset = tex.rect_size / 2.0
			tex.rect_scale /= 2.0
			return
	elif event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_UP:
			tex.rect_pivot_offset = tex.rect_size / 2.0
			tex.rect_scale *= 2.0
			return

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.doubleclick:
			if selecting_on and last_selected_is_valid():
					last_selected.selected()
			return

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and Input.is_key_pressed(KEY_SHIFT):
			var hover = get_ball_under_mouse((event.position - (rect_position + rect_size/2.0)) / tex.rect_scale + Vector2(500, 500))
			if hover:
					drag_ball = hover
					is_dragging = true
					print("[LNZ EDIT] Started drag on ball:", drag_ball.name)
					var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
					pet_node._orig_world_pos[drag_ball.ball_no] = drag_ball.global_transform.origin
			return

	if event is InputEventMouseMotion and is_dragging and drag_ball:
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
					print("Set drag_ball position to: ", new_pos)
			return

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed and is_dragging and drag_ball:
			print("[LNZ EDIT] Final world pos:", drag_ball.global_transform.origin)
			var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
			var lnz_pos = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[LNZ EDIT] Dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_translation(drag_ball.ball_no, lnz_pos)
			pet_node.emit_ball_translation_done()
			is_dragging = false
			drag_ball = null
			return

	if event is InputEventMouseMotion and not is_dragging:
		label.rect_global_position = event.global_position
		if Input.is_mouse_button_pressed(BUTTON_LEFT):
				var motion = event.relative
				camera_holder.rotation.x += motion.y * 0.01
				camera_holder.rotation.y += motion.x * -0.01
		elif Input.is_mouse_button_pressed(BUTTON_RIGHT) or Input.is_mouse_button_pressed(BUTTON_MIDDLE):
				var motion = event.relative
				camera.transform.origin.x += motion.x * 0.001 / tex.rect_scale.x
				camera.transform.origin.y += motion.y * 0.001 / tex.rect_scale.x

	if selecting_on:
		var real_center = rect_position + rect_size / 2.0
		var offset = (event.position - real_center) / tex.rect_scale
		var screen_pos = Vector2(500, 500) + offset

		var from = camera.project_ray_origin(screen_pos)
		var to   = from + camera.project_ray_normal(screen_pos) * 950
		var result = camera.get_world().direct_space_state.intersect_ray(from, to, [], 0x7FFFFFFF, false, true)

		if result:
				label.show()
				deal_with_last_selected()
				result.collider.get_parent()._on_Area_mouse_entered()
				last_selected = result.collider.get_parent()
		else:
				deal_with_last_selected()
				last_selected = null
				label.hide()
	elif event is InputEventMouseButton:
		if selecting_on and event.button_index == BUTTON_LEFT and event.doubleclick and last_selected_is_valid():
				last_selected.selected()
				return

func intersect_ray_with_plane(ray_origin: Vector3, ray_dir: Vector3, plane_normal: Vector3, plane_point: Vector3) -> Object:
	var denom = plane_normal.dot(ray_dir)
	if abs(denom) < 0.0001:
		return null
	var d = plane_normal.dot(plane_point - ray_origin) / denom
	return ray_origin + ray_dir * d

func _unhandled_key_input(event):
	if event.pressed and last_selected_is_valid():
		last_selected._input(event)
		
func last_selected_is_valid():
	return last_selected != null and is_instance_valid(last_selected)

func deal_with_last_selected():
	if last_selected != null and is_instance_valid(last_selected):
		last_selected._on_Area_mouse_exited()
				
func _on_Node_ball_mouse_enter(ball_info):
	label.text = str(ball_info.ball_no)

func _on_SelectCheckBox_toggled(button_pressed):
	selecting_on = button_pressed
	if !selecting_on:
		if last_selected_is_valid():
			last_selected._on_Area_mouse_exited()
		last_selected = null
		label.hide()

func _on_HelpButton_pressed():
	popup.popup_centered()

func _on_LnzTextEdit_mouse_entered():
	if last_selected_is_valid():
		last_selected._on_Area_mouse_exited()
	last_selected = null
	label.hide()

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