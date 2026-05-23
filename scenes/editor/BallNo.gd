extends Label

onready var ball_label = self 
onready var lnz_edit = get_node("../../LnzTextEdit")

func _update_ball_label(ball_no):
	if ball_no == -1:
		ball_label.visible = false
		return

	var current_section = lnz_edit.get_current_section_name()
	
	if current_section == "[Linez]" or current_section == "[Project Ball]":
		var line_idx = lnz_edit.cursor_get_line()
		var line_text = lnz_edit.get_line(line_idx).strip_edges()
		var parts = lnz_edit.split_line(line_text)
		
		if parts.size() >= 2:
			var b1 = int(parts[0])
			var b2 = int(parts[1])
			var name1 = lnz_edit.get_ball_name(b1) 
			var name2 = lnz_edit.get_ball_name(b2)
			
			var display_text = "#(" + str(b1) + "): " + name1 + " to #(" + str(b2) + "): " + name2
			
			if current_section == "[Linez]" and lnz_edit.has_method("check_linez_limits"):
				if lnz_edit.check_linez_limits(b1, b2):
					display_text += " (LINEZ LIMIT)"
					ball_label.add_color_override("font_color", Color.red)
				else:
					ball_label.add_color_override("font_color", Color.white)
			else:
				ball_label.add_color_override("font_color", Color.white)
				
			ball_label.text = display_text
			ball_label.visible = true
			return

	ball_label.add_color_override("font_color", Color.white)
	var max_base = KeyBallsData.max_base_ball_num
	var type_label = "(base)" if ball_no < max_base else "(add)"
	
	var name_ext = ""
	if lnz_edit.has_method("get_ball_name"):
		var b_name = lnz_edit.get_ball_name(ball_no)
		if typeof(b_name) == TYPE_STRING and b_name != "":
			name_ext = ": " + b_name
	
	ball_label.text = "Curr Ball #" + str(ball_no) + " " + type_label + name_ext
	ball_label.visible = true
