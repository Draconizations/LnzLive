extends RichTextLabel

var message_queue = []
var fade_duration = 3.0
var display_time = 3.0
var current_messages = []

func _ready():
	bbcode_enabled = true
	scroll_active = false
	set_process(true)

func log_message(msg: String):
	var entry = {
		"text": msg,
		"time_left": display_time,
		"alpha": 1.0
	}
	current_messages.append(entry)
	if current_messages.size() > 5:
		current_messages.pop_front()
	_update_display()

func _process(delta):
	if current_messages.empty():
		return

	var dirty = false
	var to_remove = []

	for i in range(current_messages.size()):
		var msg = current_messages[i]
		msg.time_left -= delta

		if msg.time_left <= 0:
			to_remove.append(i)
			dirty = true
		elif msg.time_left < 1.0:
			msg.alpha = msg.time_left
			dirty = true

	if not to_remove.empty():
		for i in range(to_remove.size() - 1, -1, -1):
			current_messages.remove(to_remove[i])
		dirty = true

	if dirty:
		_update_display()

func _update_display():
	clear()
	push_table(1)

	for msg in current_messages:
		push_cell()
		var col = Color(1, 1, 1, msg.alpha)
		push_color(col)
		append_bbcode(msg.text)
		pop()
		pop()
		
	pop()
