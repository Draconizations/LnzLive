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

const PET_SCALE = 0.01

#func _ready():
#	flip_camera_view()

func flip_camera_view():
	var camera_transform = camera.transform
	camera_transform.basis.x *= -1
	camera.transform = camera_transform

func _gui_input(event):
	if event is InputEventMouseMotion:
		label.rect_global_position = event.global_position
		var pet_node = null
		if get_tree().root.has_node("Root/PetRoot/Node"):
			pet_node = get_tree().root.get_node("Root/PetRoot/Node")


		var real_center = rect_position + rect_size / 2.0
		var offset = event.position - real_center
		offset /= tex.rect_scale
		var screen_pos = Vector2(500, 500) + offset

		if Input.is_key_pressed(KEY_SHIFT) and is_dragging and drag_ball:
			print("Camera origin: ", camera.transform.origin)
			print("Camera scale (zoom): ", tex.rect_scale)
			print("Camera FOV: ", camera.fov)
			print("Camera near/far: ", camera.near, camera.far)

			var ray_origin = camera.project_ray_origin(screen_pos)
			var ray_dir = camera.project_ray_normal(screen_pos)

			var plane_normal: Vector3
			var plane_point: Vector3

			plane_normal = camera.global_transform.basis.z.normalized()
			plane_point = drag_ball.global_transform.origin

			# Override if projection info is available
			if pet_node and pet_node.lnz.project_ball.size() > 0:
				for proj in pet_node.lnz.project_ball:
					if proj.ball == drag_ball.ball_no and pet_node.ball_map.has(proj.base):
						var base_node = pet_node.ball_map[proj.base]
						plane_normal = base_node.global_transform.basis.z.normalized()
						plane_point = base_node.global_transform.origin
						break


			var intersect = intersect_ray_with_plane(ray_origin, ray_dir, plane_normal, plane_point)
			if intersect:
				var new_pos = intersect + drag_offset
				print("New drag position (world): ", new_pos)
				drag_ball.global_transform.origin = new_pos

				# Axis snapping
				if Input.is_key_pressed(KEY_X):
					new_pos.y = drag_ball.global_transform.origin.y
					new_pos.z = drag_ball.global_transform.origin.z
				elif Input.is_key_pressed(KEY_Y):
					new_pos.x = drag_ball.global_transform.origin.x
					new_pos.z = drag_ball.global_transform.origin.z
				elif Input.is_key_pressed(KEY_Z):
					new_pos.x = drag_ball.global_transform.origin.x
					new_pos.y = drag_ball.global_transform.origin.y

				drag_ball.global_transform.origin = new_pos
				print("Set drag_ball position to: ", new_pos)
		else:
			# Regular camera motion
			if Input.is_mouse_button_pressed(BUTTON_LEFT):
				var motion = event.relative
				camera_holder.rotation.x += motion.y * 0.01
				camera_holder.rotation.y += motion.x * -0.01
			elif Input.is_mouse_button_pressed(BUTTON_RIGHT) or Input.is_mouse_button_pressed(BUTTON_MIDDLE):
				var motion = event.relative
				camera.transform.origin.x += motion.x * 0.001 / tex.rect_scale.x
				camera.transform.origin.y += motion.y * 0.001 / tex.rect_scale.x

		# Selection logic
		if selecting_on:
			var from = camera.project_ray_origin(screen_pos)
			var to = from + camera.project_ray_normal(screen_pos) * 950
			var space_state = camera.get_world().direct_space_state
			var result = space_state.intersect_ray(from, to, [], 0x7FFFFFFF, false, true)
			if !result.empty():
				label.show()
				deal_with_last_selected()
				result.collider.get_parent()._on_Area_mouse_entered()
				last_selected = result.collider.get_parent()
			else:
				deal_with_last_selected()
				last_selected = null
				label.hide()

	elif event is InputEventMouseButton:
		var real_center = rect_position + rect_size / 2.0
		var offset = event.position - real_center
		offset /= tex.rect_scale
		var screen_pos = Vector2(500, 500) + offset

		if event.button_index == BUTTON_WHEEL_DOWN:
			tex.rect_pivot_offset = tex.rect_size / 2.0
			tex.rect_scale /= 2.0
		elif event.button_index == BUTTON_WHEEL_UP:
			tex.rect_pivot_offset = tex.rect_size / 2.0
			tex.rect_scale *= 2.0
		elif event.doubleclick and event.button_index == BUTTON_LEFT and last_selected_is_valid():
			last_selected.selected()
		elif event.button_index == BUTTON_LEFT:
			if event.pressed and Input.is_key_pressed(KEY_SHIFT):
				var hovered = get_ball_under_mouse(screen_pos)
				if hovered:
					print("Started drag on ball:", hovered.name)
					drag_ball = hovered
					is_dragging = true

					var ray_origin = camera.project_ray_origin(screen_pos)
					var ray_dir = camera.project_ray_normal(screen_pos)
					var plane_normal = camera.global_transform.basis.z.normalized()
					var plane_point = drag_ball.global_transform.origin
					var intersect = intersect_ray_with_plane(ray_origin, ray_dir, plane_normal, plane_point)
					if intersect:
						print("Intersect successful: ", intersect)
						drag_offset = drag_ball.global_transform.origin - intersect
			elif is_dragging and drag_ball:
				var final_pos = drag_ball.global_transform.origin
				var pet_node = get_tree().root.get_node("Root/PetRoot/Node")

				# Reverse project ball effect, if applicable
				if pet_node and "lnz" in pet_node:
					for proj in pet_node.lnz.project_ball:
						if proj.ball == drag_ball.ball_no and proj.amount != 100 and pet_node.ball_map.has(proj.base):
							var base_pos = pet_node.ball_map[proj.base].global_transform.origin
							var vec = final_pos - base_pos
							final_pos = base_pos + (vec * (100.0 / proj.amount))
							print("Corrected reverse projection for ball %d with base %d" % [proj.ball, proj.base])
							break

				# Convert world pos to LNZ-space
				print("Ball final world position: ", final_pos)
				final_pos /= PET_SCALE
				final_pos.y *= -1

				print("Dragged ball %d to %.2f %.2f %.2f (LNZ-space)" % [
					drag_ball.ball_no, final_pos.x, final_pos.y, final_pos.z
				])

				# Emit signal (still via dog_generator.gd)
				if pet_node and pet_node.has_method("emit_ball_translation"):
					pet_node.emit_ball_translation(drag_ball.ball_no, final_pos)
					pet_node.emit_ball_translation_done()
				else:
					print("Could not find or access PetRoot/Node to emit signal")

				is_dragging = false
				drag_ball = null


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
