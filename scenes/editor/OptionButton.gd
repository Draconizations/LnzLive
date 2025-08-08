extends Button

onready var popup = $PopupPanel
var close_timer := Timer.new()

func _ready():
	popup.hide()

	add_child(close_timer)
	close_timer.set_wait_time(2.0)
	close_timer.set_one_shot(true)
	close_timer.connect("timeout", self, "_on_close_timer_timeout")

	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")
	popup.connect("mouse_entered", self, "_on_mouse_entered")
	popup.connect("mouse_exited", self, "_on_mouse_exited")

func _on_mouse_entered():
	close_timer.stop()
	if not popup.visible:
		var button_pos = rect_global_position
		var button_size = rect_size
		popup.set_position(Vector2(button_pos.x, button_pos.y + button_size.y + 5))
		popup.popup()

func _on_mouse_exited():
	close_timer.start()

func _on_close_timer_timeout():
	var mouse_pos = get_viewport().get_mouse_position()
	var btn_rect   = Rect2(rect_global_position, rect_size)
	var popup_rect = Rect2(popup.rect_global_position, popup.rect_size)
	if not (btn_rect.has_point(mouse_pos) or popup_rect.has_point(mouse_pos)):
		popup.hide()
	else:
		close_timer.start()

