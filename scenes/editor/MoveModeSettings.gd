extends CanvasLayer

signal apply_moves
signal clear_moves
signal unselect_all
signal align_selection(axis)
signal drop_to_floor
signal nudge_selection(vector)
signal mirror_toggled(is_on)
signal axis_lock_toggled(axis, is_locked)

func _ready():
	var viewport_size = get_viewport().size
	var panel = $Panel
	var panel_size = panel.rect_size
	
	var default_x = (viewport_size.x - panel_size.x) / 2
	var default_y = viewport_size.y - panel_size.y - 10
	var default_pos = Vector2(default_x, default_y)
	
	panel.restore_position(default_pos)
	# var viewport_size = get_viewport().size
	# var panel = $Panel
	# var panel_size = panel.rect_size
	# panel.margin_left = (viewport_size.x - panel_size.x) / 2
	# panel.margin_top = (viewport_size.y - panel_size.y) / 2
	
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("ClearButton").connect("pressed", self, "_on_ClearButton_pressed")
	find_node("UnselectButton").connect("pressed", self, "_on_UnselectButton_pressed")
	
	find_node("LockX").connect("toggled", self, "_on_LockX_toggled")
	find_node("LockY").connect("toggled", self, "_on_LockY_toggled")
	find_node("LockZ").connect("toggled", self, "_on_LockZ_toggled")
	
	find_node("MirrorX").connect("toggled", self, "_on_MirrorX_toggled")
	
	find_node("AlignX").connect("pressed", self, "_on_AlignX_pressed")
	find_node("AlignY").connect("pressed", self, "_on_AlignY_pressed")
	find_node("AlignZ").connect("pressed", self, "_on_AlignZ_pressed")
	
	find_node("DropFloor").connect("pressed", self, "_on_DropFloor_pressed")
	
	find_node("ApplyNudge").connect("pressed", self, "_on_ApplyNudge_pressed")

func show():
	$Panel.show()

func hide():
	$Panel.hide()

func set_queued_count(count):
	find_node("QueuedLabel").text = "Queued Moves: " + str(count)

func get_constraints():
	return {
		"x": find_node("LockX").pressed,
		"y": find_node("LockY").pressed,
		"z": find_node("LockZ").pressed
	}

func is_mirror_x_active():
	return find_node("MirrorX").pressed

func _on_ApplyButton_pressed():
	emit_signal("apply_moves")

func _on_ClearButton_pressed():
	emit_signal("clear_moves")

func _on_UnselectButton_pressed():
	emit_signal("unselect_all")

func _on_LockX_toggled(pressed):
	emit_signal("axis_lock_toggled", "x", pressed)

func _on_LockY_toggled(pressed):
	emit_signal("axis_lock_toggled", "y", pressed)

func _on_LockZ_toggled(pressed):
	emit_signal("axis_lock_toggled", "z", pressed)

func _on_MirrorX_toggled(pressed):
	emit_signal("mirror_toggled", pressed)

func _on_AlignX_pressed():
	emit_signal("align_selection", "x")

func _on_AlignY_pressed():
	emit_signal("align_selection", "y")

func _on_AlignZ_pressed():
	emit_signal("align_selection", "z")

func _on_DropFloor_pressed():
	emit_signal("drop_to_floor")

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
