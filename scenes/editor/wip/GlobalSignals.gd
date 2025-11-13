extends Node

# GlobalSignals.gd - coordinates signals and events across nodes
# - Emits signals for UI components (Buttons, Sliders, Tree)
# - Listens to logic components (LnzDocument, LnzTextEdit)

# --- File Operations ---
signal apply_changes_pressed
signal save_file_pressed
signal backup_file_pressed
signal user_file_selected(filepath)
signal example_file_selected(filepath)

# --- Pet View ---
signal find_ball_in_3d(ball_no)
signal ball_selected_in_ui(section_enum, ball_no, is_addball)
signal headshot_button_pressed

# --- Visual Editing ---
signal visual_ball_resized(ball_no, new_size)
signal visual_ball_moved(ball_no, position_delta)
signal visual_line_created(start_ball, end_ball)
signal visual_addball_created(reference_ball_node, connect_line)
signal visual_apply_paintballz

# --- Tools Menu ---
signal tool_delete_ball(ball_no)
signal tool_add_ball(reference_ball_node, connect_line)
signal tool_color_pet(color_index, outline_color_index)
signal tool_color_part(ball_nos, color, outline_color, part_name)
signal tool_recolor(recolor_info)
signal tool_move_head(x, y, z)
signal tool_copy_l_to_r(selected_ball_no)
signal tool_palette_selected(palette_name)
signal tool_apply_preset(ball_no, properties, write_target, should_override)

# --- Mode Panels ---
signal project_ball_data_updated(projections_array)
signal line_mode_settings_updated(properties) # Example