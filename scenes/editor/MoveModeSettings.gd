extends CanvasLayer

signal apply_moves
signal clear_moves
signal unselect_all
signal align_selection(axis, mode) # mode: 0=min, 1=center, 2=max
signal snap_selection(axis, direction) # direction: -1=min, 1=max
signal nudge_selection(vector)
signal mirror_toggled(is_on)

var current_constraint_mode = "free" # free, x, y, z, xy, xz, yz

func _ready():
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("UnselectButton").connect("pressed", self, "_on_UnselectButton_pressed")
	
	var constraints = ["Free", "LockX", "LockY", "LockZ", "LockXY", "LockXZ", "LockYZ"]
	for c in constraints:
		var node = find_node(c)
		if node:
			node.connect("pressed", self, "_on_constraint_selected", [c])
	
	find_node("MirrorX").connect("toggled", self, "_on_MirrorX_toggled")
	
	find_node("AlignX").connect("pressed", self, "_on_Align_pressed", ["x"])
	find_node("AlignY").connect("pressed", self, "_on_Align_pressed", ["y"])
	find_node("AlignZ").connect("pressed", self, "_on_Align_pressed", ["z"])
	
	var align_opt = find_node("AlignModeOption")
	align_opt.clear()
	align_opt.add_item("Negative (-)", 0)
	align_opt.add_item("Center (Average)", 1)
	align_opt.add_item("Positive (+)", 2)
	align_opt.selected = 1
	
	var btn_drop_floor = find_node("DropFloor")
	btn_drop_floor.text = "Drop to Floor (max Y)"
	btn_drop_floor.connect("pressed", self, "_on_Snap_pressed", ["y", -1])

	var btn_raise_roof = find_node("RaiseRoof")
	btn_raise_roof.text = "Raise to Ceiling (min Y)"
	btn_raise_roof.connect("pressed", self, "_on_Snap_pressed", ["y", 1])

	var btn_front = find_node("ShoveFront")
	btn_front.text = "Shove to Front (min Z)"
	btn_front.connect("pressed", self, "_on_Snap_pressed", ["z", -1])
	
	var btn_back = find_node("PushBack")
	btn_back.text = "Push to Back (max Z)"
	btn_back.connect("pressed", self, "_on_Snap_pressed", ["z", 1])
	
	find_node("ApplyNudge").connect("pressed", self, "_on_ApplyNudge_pressed")

func show():
	$Panel.show()

func hide():
	$Panel.hide()

func set_queued_count(count):
	find_node("QueuedLabel").text = "Queued Moves: " + str(count)

func get_constraints():
	var res = {"x": false, "y": false, "z": false}
	
	match current_constraint_mode:
		"LockX":
			res.y = true
			res.z = true
		"LockY":
			res.x = true
			res.z = true
		"LockZ":
			res.x = true
			res.y = true
		"LockXY":
			res.z = true
		"LockXZ":
			res.y = true
		"LockYZ":
			res.x = true
		"Free":
			pass
			
	return res

func is_mirror_x_active():
	return find_node("MirrorX").pressed

func _on_ApplyButton_pressed():
	emit_signal("apply_moves")

func _on_ClearButton_pressed():
	emit_signal("clear_moves")

func _on_UnselectButton_pressed():
	emit_signal("unselect_all")

func _on_constraint_selected(selected_name):
	current_constraint_mode = selected_name
	
	var constraints = ["Free", "LockX", "LockY", "LockZ", "LockXY", "LockXZ", "LockYZ"]
	for c in constraints:
		var node = find_node(c)
		if node:
			node.pressed = (c == selected_name)

func _on_MirrorX_toggled(pressed):
	emit_signal("mirror_toggled", pressed)

func _on_Align_pressed(axis):
	var mode = find_node("AlignModeOption").selected
	emit_signal("align_selection", axis, mode)

func _on_Snap_pressed(axis, direction):
	emit_signal("snap_selection", axis, direction)

func _on_ApplyNudge_pressed():
	var dx = find_node("NudgeX").value
	var dy = find_node("NudgeY").value
	var dz = find_node("NudgeZ").value
	emit_signal("nudge_selection", Vector3(dx, dy, dz))

func change_nudge_value(axis, delta):
	var node_name = ""
	if axis == "x": node_name = "NudgeX"
	elif axis == "y": node_name = "NudgeY"
	elif axis == "z": node_name = "NudgeZ"
	
	if node_name != "":
		var sb = find_node(node_name)
		if sb:
			sb.value += delta
