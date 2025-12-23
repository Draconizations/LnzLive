extends Label

onready var ball_label = self 
onready var lnz_edit = get_node("../../LnzTextEdit")

func _update_ball_label(ball_no):
	if ball_no != -1:
		ball_label.text = "Current Ball #" + str(ball_no) 
		ball_label.visible = true 
	else:
		ball_label.visible = false
