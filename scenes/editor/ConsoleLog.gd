extends RichTextLabel
## ConsoleLog.gd
## Displays a rolling log of messages with fade-out effects

export var max_messages: int = 5
export var display_time: float = 3.0
export var fade_speed: float = 1.5

var current_messages: Array = []

func _ready() -> void:
	bbcode_enabled = true
	scroll_active = false
	log_message("Welcome to LnzLive...")

func log_message(msg: String) -> void:
	var entry: Dictionary = {
		"text": msg,
		"alpha": 1.0,
		"timer": display_time
	}
	current_messages.append(entry)
	
	if current_messages.size() > max_messages:
		current_messages.pop_front()
	
	_update_display()

func _process(delta: float) -> void:
	if current_messages.empty():
		return

	var needs_update: bool = false
	var i: int = current_messages.size() - 1
	
	while i >= 0:
		var msg: Dictionary = current_messages[i]
		msg["timer"] -= delta
		
		if msg["timer"] <= 1.0:
			msg["alpha"] = max(0.0, msg["timer"])
			needs_update = true
		
		if msg["timer"] <= 0:
			current_messages.remove(i)
			needs_update = true
		
		i -= 1

	if needs_update:
		_update_display()

func _update_display() -> void:
	clear()
	for msg in current_messages:
		var display_color: Color = Color(1.0, 1.0, 1.0, msg["alpha"])
		
		push_color(display_color)
		append_bbcode(msg["text"] + "\n")
		pop()
