extends Label

onready var ball_label = self 
onready var lnz_edit = get_node("../../LnzTextEdit")

func _update_ball_label(ball_no):
	if ball_no != -1:
		var max_base = KeyBallsData.max_base_ball_num
		var type_label = "(base)" if ball_no < max_base else "(add)"
		
		var name_ext = ""
		if lnz_edit.has_method("get_ball_name"):
			var b_name = lnz_edit.get_ball_name(ball_no)
			if typeof(b_name) == TYPE_STRING and b_name != "":
				name_ext = ": " + b_name
		
		ball_label.text = "Curr Ball #" + str(ball_no) + " " + type_label + name_ext
		ball_label.visible = true 
	else:
		ball_label.visible = false
