extends PopupMenu

signal color_entire_pet(color_index, outline_color_index)
signal color_part_pet(core_ball_nos, color_index, outline_color_index, part)
signal add_ball(selected_ball, connect_line)
signal delete_ball(selected_ball)
signal copy_l_to_r()
signal recolor(recolor_info)
signal move_head(x,y,z)
signal print_ball_colors()
signal paintball_mode_for_ball_toggled(ball)

var selected_visual_ball = null

var current_action

onready var option_recolor_menu_button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/RecolorMenuButton")

enum RecolorAction { ENTIRE, LEGS, TAIL, HEAD, SNOUT, EARS, PAWS, NOSE }

func _ready():
	add_submenu_item("Color...", "RecolorMenu")
	add_item("Create Addballz + Linez") # index 1
	#add_separator()
	add_item("Create Addballz") # index 2
	add_item("Delete Addballz / Omit Ballz") # index 3
	add_item("Connect by Linez") # index 4
	add_item("Copy L to R") # index 5
	add_item("Paintball Mode") # index 6
	add_item("Move Head Ballz") # index 7
	add_item("Copy Ballz Colors to Clipboard") # index 8

	option_recolor_menu_button.connect("pressed", self, "_on_RecolorMenuButton_pressed")

func _on_LineEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		var base_color = get_parent().get_node("ColorPopup/VBoxContainer/LineEdit").text
		var outline_color = get_parent().get_node("ColorPopup/VBoxContainer/LineEdit2").text
		if current_action == RecolorAction.ENTIRE:
			emit_signal("color_entire_pet", base_color, outline_color)
		else:
			var core_ball_nos = []
			if current_action == RecolorAction.LEGS:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.legs_dog[0])
					core_ball_nos.append_array(KeyBallsData.legs_dog[1])
					for ar in KeyBallsData.foot_ext_dog:
						for v in ar:
							core_ball_nos.erase(v)
				else:
					core_ball_nos.append_array(KeyBallsData.legs_cat[0])
					core_ball_nos.append_array(KeyBallsData.legs_cat[1])
					for ar in KeyBallsData.foot_ext_cat:
						for v in ar:
							core_ball_nos.erase(v)
			elif current_action == RecolorAction.TAIL:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.tail_dog)
				else:
					core_ball_nos.append_array(KeyBallsData.tail_cat)
			elif current_action == RecolorAction.HEAD:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.head_ext_dog)
				else:
					core_ball_nos.append_array(KeyBallsData.head_ext_cat)
			elif current_action == RecolorAction.SNOUT:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.face_ext_dog)
				else:
					core_ball_nos.append_array(KeyBallsData.face_ext_cat)
			elif current_action == RecolorAction.EARS:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					var v = KeyBallsData.ear_ext_dog.values()
					core_ball_nos.append_array(v[0])
					core_ball_nos.append_array(v[1])
					core_ball_nos.append_array(KeyBallsData.ear_ext_dog.keys())
				else:
					var v = KeyBallsData.ear_ext_cat.values()
					core_ball_nos.append_array(v[0])
					core_ball_nos.append_array(v[1])
					core_ball_nos.append_array(KeyBallsData.ear_ext_cat.keys())
			elif current_action == RecolorAction.PAWS:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					for ar in KeyBallsData.foot_ext_dog:
						core_ball_nos.append_array(ar)
				else:
					for ar in KeyBallsData.foot_ext_cat:
						core_ball_nos.append_array(ar)
			elif current_action == RecolorAction.NOSE:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.nose_dog)
				else:
					core_ball_nos.append_array(KeyBallsData.nose_cat)
			var part = RecolorAction.keys()[RecolorAction.values()[current_action]]
			emit_signal("color_part_pet", core_ball_nos, base_color, outline_color, part)

func _on_RecolorMenu_id_pressed(id):
	current_action = id
	if id == 8: # color swap
		get_parent().get_node("RecolorPopup").popup_centered()
	else:
		get_parent().get_node("ColorPopup").rect_position = get_global_mouse_position()
		get_parent().get_node("ColorPopup").popup()

func _on_RecolorMenuButton_pressed():
	get_parent().get_node("RecolorPopup").popup_centered()

func _on_ToolsMenu_index_pressed(index):
	if index == 5: # Copy L to R
		emit_signal("copy_l_to_r")
	elif index == 1: # Create Addballz + Linez
		if is_instance_valid(selected_visual_ball):
			emit_signal("add_ball", selected_visual_ball, true)
	elif index == 2: # Create Addballz
		if is_instance_valid(selected_visual_ball):
			emit_signal("add_ball", selected_visual_ball, false)
	elif index == 3: # Delete Addballz or Omit Base Ball
		if is_instance_valid(selected_visual_ball):
			emit_signal("delete_ball", selected_visual_ball.ball_no)
	elif index == 4: # Connect by Linez
		if is_instance_valid(selected_visual_ball):
			var pet_view = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
			pet_view.line_mode_close = true
			pet_view.line_mode_check_box.pressed = true
			pet_view.linez_start_ball = selected_visual_ball
			selected_visual_ball.apply_outline_state(selected_visual_ball.OutlineState.ACTIVE_SELECTED)
	elif index == 6: # Paintball Mode
		if is_instance_valid(selected_visual_ball):
			emit_signal("paintball_mode_for_ball_toggled", selected_visual_ball)
	elif index == 7: # Move Head
		var options = get_parent().get_node("HeadMovePopup")
		options.popup_centered()
	elif index == 8: # Print Ballz Colors
		emit_signal("print_ball_colors")

func _on_ToolsMenu_about_to_show():
	var view_container = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	#set_item_disabled(1, !view_container.last_selected_is_valid())

func _on_RecolorPopup_confirmed():
	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines = popup.get_node("RecolorLines").get_children()
	var recolor_info = {recolors = {}}
	for l in lines:
		var original_color = l.get_child(0).text as String
		var new_color = l.get_child(2).text as String
		if original_color.empty() or new_color.empty():
			continue
		recolor_info.recolors[original_color] = new_color
	var balls_on = popup.get_node("CheckContainer/Balls").pressed
	var ball_outlines_on = popup.get_node("CheckContainer/Ball outlines").pressed
	var paintballs_on = popup.get_node("CheckContainer/Paintballs").pressed
	var lines_on = popup.get_node("CheckContainer/Lines").pressed
	recolor_info.balls_on = balls_on
	recolor_info.ball_outlines_on = ball_outlines_on
	recolor_info.paintballs_on = paintballs_on
	recolor_info.lines_on = lines_on
	emit_signal("recolor", recolor_info)	

func _on_ClearButton_pressed():
	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines = popup.get_node("RecolorLines").get_children()
	for l in lines:
		l.get_child(0).text = ""
		l.get_child(2).text = ""
	for cb in popup.get_node("CheckContainer").get_children():
		cb.pressed = true

func _on_HeadMoveLineEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		var popup = get_parent().get_node("HeadMovePopup/VBoxContainer")
		var x = popup.get_node("HeadMoveLineEditX").text.to_int()
		var y = popup.get_node("HeadMoveLineEditY").text.to_int()
		var z = popup.get_node("HeadMoveLineEditZ").text.to_int()
		emit_signal("move_head", x, y, z)
