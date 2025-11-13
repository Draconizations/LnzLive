extends Panel
## DraggablePanel.gd
## Attach script to a `Panel` or `PanelContainer` node to allow the user
## to click and drag it around the screen

var dragging = false
var drag_start = Vector2()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = get_global_mouse_position() - rect_global_position
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		rect_global_position = get_global_mouse_position() - drag_start
