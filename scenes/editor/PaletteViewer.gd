extends DraggablePanel
## PaletteViewer.gd
## Manages a popup that displays the currently loaded pet color palette
## This script generates a visual grid of colors from the active palette file
## 1. Initialization: Connects the close button to hide the popup
## 2. Population: Clears the existing view, loads the correct palette texture for the active pet, and creates a GridContainer
## 3. Display: Iterates through the palette's colors, generating a ColorRect and a numbered Label for each color index
## 4. Loading: Contains logic to find the appropriate palette file based on  LNZ document data

# var dragging = false
# var drag_start = Vector2()

var dog_generator = null

var color_grid: GridContainer

onready var vbox = $MarginContainer/MainVBox/PaletteViewerScrollContainer/PaletteViewerVBoxContainer
onready var title_label = $MarginContainer/MainVBox/TitleLabel
onready var main_container = $MarginContainer
onready var pixel_font = load("res://resources/fonts/font_pixel_code_14.tres")
# onready var close_button = $CloseButton

func _ready():
	# if close_button:
	# 	close_button.connect("pressed", self, "_on_close_button_pressed")
	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_pet_palette_changed")
		populate_colors()
	else:
		print("PaletteViewer Error: Could not find dog_generator node.")

	vbox.connect("resized", self, "_on_vbox_resized")
	
	var user_settings = get_tree().root.find_node("SceneRoot", true, false)
	if user_settings:
		user_settings.connect("global_font_updated", self, "populate_colors")

# func _gui_input(event):
# 	if event is InputEventMouseButton:
# 		if event.button_index == BUTTON_LEFT:
# 			if event.pressed:
# 				dragging = true
# 				drag_start = get_global_mouse_position() - rect_global_position
# 			else:
# 				dragging = false
# 	elif event is InputEventMouseMotion and dragging:
# 		rect_global_position = get_global_mouse_position() - drag_start

func populate_colors():
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

	if dog_generator == null or dog_generator.lnz == null:
		title_label.text = "No palette loaded"
		var label = Label.new()
		label.text = "No pet loaded"
		vbox.add_child(label)
		return

	var pal_texture = dog_generator.current_palette_texture
	var palette_path = dog_generator.lnz.palette
	
	if palette_path == null or palette_path == "":
		title_label.text = "default Babyz game palette" if dog_generator.is_babyz_mode else "default Petz game palette"
	else:
		title_label.text = "Palette: " + palette_path.get_basename()
		if dog_generator.is_babyz_mode and dog_generator.lnz.species != 3:
			title_label.text += " (game: Babyz)"

	if pal_texture == null:
		var label = Label.new()
		label.text = "palette not found"
		vbox.add_child(label)
		return

	color_grid = GridContainer.new()
	vbox.add_child(color_grid)

	var img = pal_texture.get_data()
	img.lock()

	var current_font_size = pixel_font.size
	var dynamic_size = max(24, current_font_size + 12)
	var cell_vector = Vector2(dynamic_size, dynamic_size)

	var color_index = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var color = img.get_pixel(x, y)

			var color_rect = ColorRect.new()
			color_rect.color = color
			color_rect.rect_min_size = cell_vector

			var label = Label.new()
			label.add_font_override("font", pixel_font)
			label.text = str(color_index)
			label.align = Label.ALIGN_CENTER
			label.valign = Label.VALIGN_CENTER

			var luminance = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			label.add_color_override("font_color", Color.black if luminance > 0.5 else Color.white)

			color_rect.add_child(label)
			label.set_anchors_and_margins_preset(Control.PRESET_WIDE)

			color_grid.add_child(color_rect)
			color_index += 1

	img.unlock()
	
	call_deferred("_on_vbox_resized")

func _on_vbox_resized():
	if color_grid and color_grid.get_child_count() > 0:
		var cell_width = color_grid.get_child(0).rect_min_size.x
		var spacing = color_grid.get_constant("hseparation")
		var available_width = vbox.rect_size.x
		
		var calculated_columns = max(1, floor(available_width / (cell_width + spacing)))
		color_grid.columns = calculated_columns
		
func load_palette_texture(palette_filename: String) -> Texture:
	var texture = null
	var clean_filename = palette_filename.strip_edges()
	
	var user_res_path = "user://resources/palettes".plus_file(clean_filename)
	var res_res_path = "res://resources/palettes".plus_file(clean_filename)

	if ResourceLoader.exists(user_res_path):
		texture = ResourceLoader.load(user_res_path)
	elif ResourceLoader.exists(res_res_path):
		texture = ResourceLoader.load(res_res_path)
	else:
		var resource_key = "palette_" + clean_filename.to_lower()
		var preloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader
		if preloader.has_resource(resource_key):
			texture = preloader.get_resource(resource_key)

	return texture

func _on_palette_selected(filename_no_ext: String):
	if dog_generator.lnz == null:
		return 
		
	dog_generator.lnz.palette = filename_no_ext + ".png"
	populate_colors()

func _on_pet_palette_changed(palette_name):
	populate_colors()

# func _on_close_button_pressed():
# 	self.hide()
