extends VBoxContainer

onready var tab_container = get_node("SidebarTabs")
onready var tree = get_node("SidebarTabs/FileTree/Tree")

var floating_layer: CanvasLayer = null
const UTILITY_TABS = ["FileTree", "Palette"]

func _ready():
	if tab_container:
		tab_container.visible = true

	if not floating_layer:
		var existing_layer = get_tree().root.find_node("FloatingPanelsLayer", true, false)
		if existing_layer:
			floating_layer = existing_layer
		else:
			floating_layer = CanvasLayer.new()
			floating_layer.name = "FloatingPanelsLayer"
			floating_layer.layer = 10
			get_tree().root.call_deferred("add_child", floating_layer)

	tab_container.connect("tab_changed", self, "_on_tab_changed")

func add_tool_tab(control: Control, title: String):
	if control == null or not is_instance_valid(control):
		return

	if control.get_parent() == tab_container:
		return

	if control.get_parent():
		control.get_parent().remove_child(control)

	tab_container.add_child(control)
	control.name = title

	if title == "FileTree":
		tab_container.move_child(control, 0)
	elif title == "Palette":
		var target_idx = 1 if tab_container.get_child(0).name == "FileTree" else 0
		tab_container.move_child(control, target_idx)

	if control.has_method("set_docked"):
		control.set_docked(true) 
	
	_update_tab_visibilities()

func dock_panel(panel: Control):
	if panel.get_parent() == tab_container:
		switch_to_tab(panel)
		return

	if panel.get_parent():
		panel.get_parent().remove_child(panel)

	tab_container.add_child(panel)
	
	if panel.has_method("set_docked"):
		panel.set_docked(true)
		
	_update_tab_visibilities()
	switch_to_tab(panel)

func undock_panel(panel: Control):
	if panel.get_parent() != tab_container:
		return

	var was_current = (tab_container.get_current_tab_control() == panel)
	tab_container.remove_child(panel)

	if not floating_layer:
		floating_layer = CanvasLayer.new()
		floating_layer.name = "FloatingPanelsLayer"
		floating_layer.layer = 10
		get_tree().root.add_child(floating_layer)

	floating_layer.add_child(panel)

	if panel.has_method("set_docked"):
		panel.set_docked(false)
	
	if was_current:
		tab_container.current_tab = 0
		
	_update_tab_visibilities()

func switch_to_tab(panel: Control):
	if panel.get_parent() == tab_container:
		var idx = panel.get_index()
		if not tab_container.get_tab_disabled(idx):
			tab_container.current_tab = idx

func _update_tab_visibilities():
	var is_any_mode_floating = false
	if floating_layer:
		for panel in floating_layer.get_children():
			if panel.visible and not panel.name in UTILITY_TABS:
				is_any_mode_floating = true
				break
			
	for i in range(tab_container.get_child_count()):
		var child = tab_container.get_child(i)
		if child.name in UTILITY_TABS:
			tab_container.set_tab_disabled(i, false)
		else:
			tab_container.set_tab_disabled(i, is_any_mode_floating)

func _on_tab_changed(tab_index: int):
	var control = tab_container.get_child(tab_index)
	var pet_view = get_tree().root.find_node("PetViewContainer", true, false)
	if not pet_view or not is_instance_valid(pet_view): return

	match control.name:
		"Paint": pet_view.paintball_check_box.pressed = true
		"AutoPaint": pet_view.auto_paintballer_check_box.pressed = true
		"Move": pet_view.move_mode_check_box.pressed = true
		"Line": pet_view.line_mode_check_box.pressed = true
		"Preset": pet_view.preset_mode_check_box.pressed = true
		"Project": pet_view.project_mode_check_box.pressed = true
		"Palette": pet_view.view_palette_check_box.pressed = true
		"FileTree":
			pass