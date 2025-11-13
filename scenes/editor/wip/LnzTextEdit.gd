extends TextEdit

# LnzTextEdit.gd - controls Text Editor (refactored)
# - Displays text from LnzDocument
# - Signals to LnzDocument when user applies LNZ text changes
# - Handles syntax highlighting and scroll memory
# - Forwards text-to-view events like flash ball (CTRL+Q) to the global event bus.
#
# It contains NO business logic, NO parsing, and NO file I/O.
# -----------------------------------------------------------------------------

var old_v_scroll: int = 0
var old_h_scroll: int = 0
var old_cursor_line: int = 0
var old_cursor_col: int = 0

func _ready() -> void:
	wrap_enabled = false
	
	# --- Syntax Highlighting ---
	add_color_region("[","]",Color(0.247119, 0.691406, 0.691406),false)
	add_color_region(";","",Color(0.168627, 0.45098, 0.45098),false)

	# --- Connect to LnzDocument Model ---
	# We listen for when the model changes so we can refresh our text.
	LnzDocument.connect("pre_document_update", self, "_on_pre_document_update")
	LnzDocument.connect("document_updated", self, "_on_document_changed")
	LnzDocument.connect("document_parsed", self, "_on_document_changed")

	# --- Connect to Global Signals ---
	# We listen for when the user clicks UI buttons.
	GlobalSignals.connect("apply_changes_pressed", self, "_on_apply_changes_pressed")
	GlobalSignals.connect("ball_selected_in_ui", self, "_on_ball_selected_in_ui")

	# Load initial file
	_on_document_changed()

# --- LNZ Synchronization ---

"""
Fires *before* LnzDocument changes its data.
We save our view state here.
"""
func _on_pre_document_update() -> void:
	old_v_scroll = get_v_scroll()
	old_h_scroll = get_h_scroll()
	old_cursor_line = cursor_get_line()
	old_cursor_col = cursor_get_column()

"""
Fires *after* LnzDocument has changed.
We get the new text, set it, and restore our view state.
"""
func _on_document_changed() -> void:
	var new_text = LnzDocument.serialize_to_text()
	_set_text_preserve(new_text)

"""
Sets the text content while preserving the user's view.
"""
func _set_text_preserve(new_text: String) -> void:
	# Check if text is actually different to avoid flicker
	if new_text == self.text:
		return

	self.text = new_text
	
	# Restore view state
	set_v_scroll(old_v_scroll)
	set_h_scroll(old_h_scroll)
	
	# Ensure cursor position is valid
	if old_cursor_line < get_line_count():
		cursor_set_line(old_cursor_line)
		var max_col = get_line(old_cursor_line).length()
		cursor_set_column(min(old_cursor_col, max_col))
	else:
		cursor_set_line(0)
		cursor_set_column(0)


# --- UI Event Handling ---

"""
Triggered by GlobalSignals when the "Apply Changes" button is pressed.
This is the *only* time this View writes back to the Model.
"""
func _on_apply_changes_pressed() -> void:
	LnzDocument.parse_from_text(self.text)
	# LnzDocument will emit "document_parsed", which will
	# trigger _on_document_changed and reload the 3D view.

"""
Handles local GUI inputs, like CTRL+Q for finding a ball.
"""
func _gui_input(event: InputEvent) -> void:
	# Find ball under cursor
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_Q:
		var line = cursor_get_line()
		var ball_no = LnzDocument.get_ball_no_from_line(line)
		
		if ball_no == -1:
			# Fallback: try to get word under cursor
			var word = get_word_under_cursor()
			if word.is_valid_integer():
				ball_no = int(word)

		if ball_no != -1:
			# Emit a global signal for the 3D view to catch
			GlobalSignals.emit_signal("find_ball_in_3d", ball_no)
			get_tree().set_input_as_handled()

"""
Handles CTRL+S (Save) and other unhandled key inputs.
"""
func _unhandled_key_input(event: InputEventKey) -> void:
	if Input.is_key_pressed(KEY_CONTROL) and event.pressed:
		if event.scancode == KEY_S:
			# Tell the document to save
			GlobalSignals.emit_signal("save_file_pressed")
			get_tree().set_input_as_handled()

"""
Handles a global signal to focus on a specific ball.
"""
func _on_ball_selected_in_ui(section_enum, ball_no: int, is_addball: bool) -> void:
	# This function needs to be rewritten.
	# LnzDocument should provide a "get_line_for_ball_no" function.
	
	# var line_to_go = LnzDocument.get_line_for_ball(ball_no, section_enum)
	# if line_to_go != -1:
	# 	cursor_set_line(line_to_go)
	# 	cursor_set_column(0)
	# 	center_viewport_to_cursor()
	
	print("LnzTextEdit: _on_ball_selected_in_ui needs to be re-implemented.")
	pass