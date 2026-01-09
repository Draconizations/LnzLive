extends Control
class_name DesignCanvas

signal design_changed

var design_paintballs = []
var brush_size = 30
var current_color_slot = 1
var is_drawing = false
var coordinate_multiplier = 1.0
var brush_spacing = 5.0
var last_draw_pos = Vector2.ZERO

var mirror_x = false
var mirror_y = false
var eraser_mode = false

var slot_data_ref = []

func _ready():
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				last_draw_pos = event.position
				if eraser_mode:
					_erase_at(event.position)
				else:
					_add_paintball_symmetric(event.position)
			else:
				is_drawing = false

	elif event is InputEventMouseMotion:
		if is_drawing:
			if event.position.distance_to(last_draw_pos) >= brush_spacing:
				if eraser_mode:
					_erase_at(event.position)
				else:
					_add_paintball_symmetric(event.position)
				last_draw_pos = event.position

func _erase_at(pos):
	var rect_size = get_rect().size
	var center = rect_size / 2.0

	var erase_radius = brush_size / 2.0

	var to_remove = []
	for i in range(design_paintballs.size()):
		var pb = design_paintballs[i]
		var pb_pos = _norm_to_local(pb.x, pb.y)
		if pb_pos.distance_to(pos) <= erase_radius:
			to_remove.append(i)

	if not to_remove.empty():
		to_remove.invert()
		for i in to_remove:
			design_paintballs.remove(i)
		update()
		emit_signal("design_changed")

func _add_paintball_symmetric(pos):
	var center = rect_size / 2.0
	var relative = pos - center

	_add_paintball(pos)

	if mirror_x:
		var mx_pos = center + Vector2(-relative.x, relative.y)
		if mx_pos.distance_to(pos) > 1.0:
			_add_paintball(mx_pos)

	if mirror_y:
		var my_pos = center + Vector2(relative.x, -relative.y)
		if my_pos.distance_to(pos) > 1.0:
			_add_paintball(my_pos)

	if mirror_x and mirror_y:
		var mxy_pos = center + Vector2(-relative.x, -relative.y)
		var dist_pos = mxy_pos.distance_to(pos)
		var mx_pos = center + Vector2(-relative.x, relative.y)
		var my_pos = center + Vector2(relative.x, -relative.y)
		var dist_mx = mxy_pos.distance_to(mx_pos)
		var dist_my = mxy_pos.distance_to(my_pos)

		if dist_pos > 1.0 and dist_mx > 1.0 and dist_my > 1.0:
			_add_paintball(mxy_pos)

func _add_paintball(pos):
	var rect_size = get_rect().size
	var center = rect_size / 2.0

	var norm_x = (pos.x - center.x) / (rect_size.x / 2.0)
	var norm_y = (pos.y - center.y) / (rect_size.y / 2.0)

	# Clamp to canvas
	if abs(norm_x) > 1.0 or abs(norm_y) > 1.0:
		return

	var pb = {
		"x": norm_x,
		"y": norm_y,
		"diameter": brush_size,
		"color_slot": current_color_slot
	}

	design_paintballs.append(pb)
	update()
	emit_signal("design_changed")

func _draw():
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.2, 0.2, 0.2))

	# Draw grid lines
	var center = rect_size / 2.0
	draw_line(Vector2(center.x, 0), Vector2(center.x, rect_size.y), Color(0.3, 0.3, 0.3), 2.0)
	draw_line(Vector2(0, center.y), Vector2(rect_size.x, center.y), Color(0.3, 0.3, 0.3), 2.0)

	# Draw symmetry lines
	if mirror_x:
		draw_line(Vector2(center.x, 0), Vector2(center.x, rect_size.y), Color(1, 0.5, 0.5, 0.5), 2.0)
	if mirror_y:
		draw_line(Vector2(0, center.y), Vector2(rect_size.x, center.y), Color(0.5, 0.5, 1, 0.5), 2.0)

	# Draw paintballs
	for pb in design_paintballs:
		var pos = _norm_to_local(pb.x, pb.y)
		var color = _get_slot_color(pb.color_slot)
		draw_circle(pos, pb.diameter / 2.0, color)

func _norm_to_local(nx, ny):
	var center = rect_size / 2.0
	var x = center.x + nx * (rect_size.x / 2.0)
	var y = center.y + ny * (rect_size.y / 2.0)
	return Vector2(x, y)

func _get_slot_color(slot_idx):
	var idx = slot_idx - 1
	if idx >= 0 and idx < slot_data_ref.size():
		return slot_data_ref[idx].get("display_color", Color.white)
	return Color.white

func clear():
	design_paintballs.clear()
	update()
	emit_signal("design_changed")

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	pass
