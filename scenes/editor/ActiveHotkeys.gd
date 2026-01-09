extends Label

export var display_time := 3.0 
export var fade_speed := 1.5 

var timer = 0.0
var current_alpha = 1.0
var active_keys = []

func _ready():
	text = ""
	mouse_filter = MOUSE_FILTER_IGNORE
	align = Label.ALIGN_RIGHT
	add_color_override("font_color", Color(1, 1, 1, 1.0)) 

func _process(delta):
	if timer > 0:
		timer -= delta 
		
		if timer <= 1.0:
			current_alpha = max(0, timer)
			add_color_override("font_color", Color(1, 1, 1, current_alpha))
		
		if timer <= 0:
			text = "" 
	else:
		if text != "":
			text = ""

func _input(event):
	if event is InputEventKey:
		var scancode = event.scancode
		
		if event.pressed and not event.echo:
			if not scancode in active_keys:
				active_keys.append(scancode)
			
			_update_hotkey_text(event)
				
		elif not event.pressed:
			if scancode in active_keys:
				active_keys.erase(scancode)
				
				if not active_keys.empty():
					_update_hotkey_text(event)

func _update_hotkey_text(event: InputEventKey):
	var key_str = _get_combo_string(event)
	
	if key_str != "":
		if _should_display(event, key_str):
			text = key_str
			timer = display_time
			current_alpha = 1.0
			add_color_override("font_color", Color(1, 1, 1, 1.0))

func _should_display(event: InputEventKey, key_str: String) -> bool:
	var focus_owner = get_focus_owner()
	var is_text_input = focus_owner is TextEdit or focus_owner is LineEdit 
	
	if is_text_input:
		if event.control or event.alt or event.shift:
			return true
			
		return _is_special_key(event.scancode) 
			
	return true

func _is_special_key(scancode: int) -> bool:
	if scancode >= KEY_F1 and scancode <= KEY_F16:
		return true
	
	var special_keys = [
		KEY_ESCAPE, KEY_TAB, KEY_ENTER, KEY_KP_ENTER, 
		KEY_INSERT, KEY_DELETE, KEY_PAUSE, KEY_PRINT, KEY_SYSREQ, KEY_CLEAR,
		KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, 
		KEY_PAGEUP, KEY_PAGEDOWN
	]
	
	return scancode in special_keys

func _get_combo_string(event: InputEventKey) -> String:
	var parts = []
	
	if event.control or KEY_CONTROL in active_keys: 
		if not "CTRL" in parts: parts.append("CTRL")
	if event.alt or KEY_ALT in active_keys: 
		if not "ALT" in parts: parts.append("ALT")
	if event.shift or KEY_SHIFT in active_keys: 
		if not "SHIFT" in parts: parts.append("SHIFT")
	
	for code in active_keys:
		if not _is_modifier(code):
			var key_name = _get_key_name(code)
			if not key_name in parts:
				parts.append(key_name)
	
	var result = ""
	for i in range(parts.size()):
		result += parts[i]
		if i < parts.size() - 1:
			result += " + "
			
	return result

func _get_key_name(scancode: int) -> String:
	match scancode:
		KEY_CONTROL: return "CTRL"
		KEY_ALT: return "ALT"
		KEY_SHIFT: return "SHIFT"
		KEY_TAB: return "TAB"
		KEY_SPACE: return "SPACE"
		_:
			return OS.get_scancode_string(scancode).to_upper() 

func _is_modifier(scancode: int) -> bool:
	return scancode == KEY_CONTROL or scancode == KEY_SHIFT or scancode == KEY_ALT
