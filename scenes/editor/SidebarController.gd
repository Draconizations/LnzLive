extends VBoxContainer

onready var tab_container = get_node("SidebarTabs")
onready var tree = get_node("SidebarTabs/FileTree/Tree")
onready var file_nav_hbox1 = get_node("SidebarTabs/FileTree/FileNavHBox1")
onready var file_nav_hbox2 = get_node("SidebarTabs/FileTree/FileNavHBox2")

var floating_layer: CanvasLayer = null

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
	if not tab_container:
		return

	if control.get_parent() == tab_container:
		return

	if control.get_parent():
		control.get_parent().remove_child(control)

	tab_container.add_child(control)
	control.name = title

	if control.has_method("set_docked"):
		control.set_docked(true)

func dock_panel(panel: Control):
	if panel.get_parent() == tab_container:
		switch_to_tab(panel)
		return

	if panel.get_parent():
		panel.get_parent().remove_child(panel)

	tab_container.add_child(panel)

	switch_to_tab(panel)

	if panel.has_method("set_docked"):
		panel.set_docked(true)

func undock_panel(panel: Control):
	if panel.get_parent() != tab_container:
		return

	tab_container.remove_child(panel)

	if not floating_layer:
		floating_layer = CanvasLayer.new()
		floating_layer.name = "FloatingPanelsLayer"
		floating_layer.layer = 10
		get_tree().root.add_child(floating_layer)

	floating_layer.add_child(panel)

	if panel.has_method("set_docked"):
		panel.set_docked(false)

func switch_to_tab(panel: Control):
	if panel.get_parent() == tab_container:
		var idx = panel.get_index()
		tab_container.current_tab = idx

func _on_tab_changed(tab_index: int):
	var control = tab_container.get_child(tab_index)

	var pet_view = get_tree().root.find_node("PetViewContainer", true, false)
	if pet_view:
		if control.name == "File Tree":
			pass
		elif control.name == "Paintball Mode":
			if not pet_view.paintball_mode:
				pet_view.paintball_check_box.pressed = true
		elif control.name == "Auto Paintballer":
			if not pet_view.auto_paintballer_mode:
				pet_view.auto_paintballer_check_box.pressed = true
		elif control.name == "Move Mode":
			if not pet_view.move_mode:
				pet_view.move_mode_check_box.pressed = true
		elif control.name == "Line Mode":
			if not pet_view.linez_mode:
				pet_view.line_mode_check_box.pressed = true
		elif control.name == "Preset Mode":
			if not pet_view.preset_mode:
				pet_view.preset_mode_check_box.pressed = true
		elif control.name == "Project Mode":
			if not pet_view.project_mode:
				pet_view.project_mode_check_box.pressed = true
		elif control.name == "Palette Viewer":
			if not pet_view.view_palette_check_box.pressed:
				pet_view.view_palette_check_box.pressed = true
