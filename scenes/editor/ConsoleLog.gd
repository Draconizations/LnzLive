extends RichTextLabel

export var max_messages := 5
export var display_time := 3.0
export var fade_speed := 1.5

var current_messages = []

func _ready():
	bbcode_enabled = true
	scroll_active = false
	log_message("Welcome to LnzLive...")

func log_message(msg: String):
	var entry = {
		"text": msg,
		"alpha": 1.0,
		"timer": display_time
	}
	current_messages.append(entry)
	
	if current_messages.size() > max_messages:
		current_messages.pop_front()
	
	_update_display()

func _process(delta):
	if current_messages.empty():
		return

	var needs_update = false
	var i = current_messages.size() - 1
	
	while i >= 0:
		var msg = current_messages[i]
		msg.timer -= delta
		
		if msg.timer <= 1.0:
			msg.alpha = max(0, msg.timer)
			needs_update = true
		
		if msg.timer <= 0:
			current_messages.remove(i)
			needs_update = true
		
		i -= 1

	if needs_update:
		_update_display()

func _update_display():
	clear()
	for msg in current_messages:
		var display_color = Color(1.0, 1.0, 1.0, msg.alpha)
		
		push_color(display_color)
		append_bbcode(msg.text + "\n")
		pop()