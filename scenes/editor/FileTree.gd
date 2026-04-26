extends Tree
## FileTree.gd
## Manages the Tree UI for organizing and interacting with Petz LNZ files textures and palettes
## This script builds the file structure from two sources: read-only Examples (res://) and user Local Storage (user://)
## 1. Loading: Scans directories to populate the tree with LNZ files textures and palettes
## 2. Selection: Handles item activation to load the selected file/palette by emitting example_file_selected user_file_selected or palette_selected
## 3. Import: Manages file uploading for both desktop and web builds copying LNZ BMP and PNG files to local storage
## 4. Management: Provides a right-click context menu for user-stored files allowing for renaming deleting and backing up the currently active LNZ file
## 5. Rescan: Provides dedicated methods to refresh the LNZ texture and palette sections of the tree

signal example_file_selected(filepath)
signal user_file_selected(filepath)
signal palette_selected(fileprefix)

enum ImportType { NONE, LNZ, TEXTURE, PALETTE }
var current_import_type = ImportType.NONE

enum SortMode { ALPHABETICAL, MODIFIED_DATE }
var current_sort_mode = SortMode.ALPHABETICAL

const MAX_RECURSION_DEPTH = 3

onready var pet_view_container = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
onready var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")

var examples: TreeItem
var local_storage: TreeItem
var root: TreeItem
var local_storage_textures: TreeItem
var res_textures: TreeItem
var local_storage_palettes: TreeItem

var new_folder_dialog: ConfirmationDialog
var new_folder_input: LineEdit

var move_dialog: ConfirmationDialog
var move_dropdown: OptionButton

export var example_file_location = "res://resources/"
export var user_file_location = "user://resources/"

onready var rename_dialog = get_tree().root.get_node("Root/SceneRoot/RenameDialog") as AcceptDialog
onready var upload_popup = get_tree().root.get_node("Root/SceneRoot/WebFileUploadPopup") as AcceptDialog
onready var preloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader

onready var import_lnz_button = get_node("../FileNavHBox2/ImportButtonLNZ")
onready var import_tex_button = get_node("../FileNavHBox1/ImportButtonTexBMP")
onready var import_pal_button = get_node("../FileNavHBox1/ImportButtonPalPNG")
onready var open_user_folder_button = get_node("../FileNavHBox2/OpenUserFolder")

onready var menu_import_lnz = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuImportLNZ")
onready var menu_import_tex = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuImportTexture")
onready var menu_import_pal = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuImportPalette")
onready var menu_open_user_folder = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/MenuOpenUserFolder")

onready var file_dialog = get_node("./ItemPopupMenu/FileDialog")

var saved_subfolder_states := {}

signal backup_file

func _ready():
	select_mode = SELECT_MULTI
	root = create_item()
	examples = create_item(root)
	examples.set_text(0, "Examples")
	
	import_lnz_button.connect("pressed", self, "_on_ImportLNZ_pressed")
	import_tex_button.connect("pressed", self, "_on_ImportTexture_pressed")
	import_pal_button.connect("pressed", self, "_on_ImportPalette_pressed")
	open_user_folder_button.connect("pressed", self, "_on_OpenUserFolder_pressed")

	menu_import_lnz.connect("pressed", self, "_on_ImportLNZ_pressed")
	menu_import_tex.connect("pressed", self, "_on_ImportTexture_pressed")
	menu_import_pal.connect("pressed", self, "_on_ImportPalette_pressed")
	menu_open_user_folder.connect("pressed", self, "_on_OpenUserFolder_pressed")

	file_dialog.connect("files_selected", self, "_on_FileDialog_files_selected")
	file_dialog.connect("popup_hide", self, "_on_FileDialog_popup_hide")
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.rect_min_size = Vector2(400, 400)
	
	file_dialog.popup_exclusive = true
	
	if rename_dialog:
		rename_dialog.popup_exclusive = true
		rename_dialog.connect("about_to_show", self, "_on_RenameDialog_about_to_show")
		rename_dialog.connect("popup_hide", self, "_on_RenameDialog_popup_hide")

	if upload_popup:
		upload_popup.connect("about_to_show", self, "_on_FileDialog_about_to_show")
		upload_popup.connect("popup_hide", self, "_on_FileDialog_popup_hide")

	var popup = $ItemPopupMenu
	if popup.get_item_count() < 7:
		popup.add_item("New Folder", 5)
		popup.add_item("Move To...", 6)

	var dir = Directory.new()
	var lnz_dir_path = example_file_location + "lnz/"
	if dir.open(lnz_dir_path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var subdir_path = lnz_dir_path + file_name
				var subdir = Directory.new()
				if subdir.open(subdir_path) == OK:
					var sub_item = create_item(examples)
					sub_item.set_text(0, file_name)
					sub_item.set_collapsed(true)
					subdir.list_dir_begin(true, true)
					var sub_file = subdir.get_next()
					while sub_file != "":
						if sub_file.ends_with(".lnz"):
							var new_item = create_item(sub_item)
							new_item.set_text(0, sub_file)
							new_item.set_metadata(0, subdir_path + "/" + sub_file)
						sub_file = subdir.get_next()
					subdir.list_dir_end()
			file_name = dir.get_next()
		dir.list_dir_end()

	_setup_dynamic_dialogs()

	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_sort_mode = config.get_value("Display", "file_tree_sort_mode", SortMode.ALPHABETICAL)

	_setup_sort_ui()

	rescan(null)
	rescan_textures(true)
	rescan_res_textures()
	rescan_palettes()

func _on_FileDialog_popup_hide():
	pet_view_container.input_is_paused = false
	release_focus()

func _on_RenameDialog_about_to_show():
	pet_view_container.input_is_paused = true

func _on_RenameDialog_popup_hide():
	pet_view_container.input_is_paused = false
	release_focus()

func _setup_dynamic_dialogs():
	new_folder_dialog = ConfirmationDialog.new()
	new_folder_dialog.window_title = "Create New Folder"
	
	var vbox1 = VBoxContainer.new()
	var label1 = Label.new()
	label1.text = "Enter folder name:"
	new_folder_input = LineEdit.new()
	
	vbox1.add_child(label1)
	vbox1.add_child(new_folder_input)
	new_folder_dialog.add_child(vbox1)
	
	new_folder_dialog.connect("confirmed", self, "_on_NewFolderDialog_confirmed")
	add_child(new_folder_dialog)
	
	move_dialog = ConfirmationDialog.new()
	move_dialog.window_title = "Move To..."
	
	var vbox2 = VBoxContainer.new()
	var label2 = Label.new()
	label2.text = "Select Destination Folder:"
	move_dropdown = OptionButton.new()
	
	vbox2.add_child(label2)
	vbox2.add_child(move_dropdown)
	move_dialog.add_child(vbox2)
	
	move_dialog.connect("confirmed", self, "_on_MoveFileDialog_confirmed")
	add_child(move_dialog)

func _setup_sort_ui():
	var sort_hbox = HBoxContainer.new()
	sort_hbox.alignment = BoxContainer.ALIGN_END
	
	var sort_label = Label.new()
	sort_label.text = "Sort LNZ: "
	
	var sort_dropdown = OptionButton.new()
	sort_dropdown.add_item("Alphabetical (A-Z)")
	sort_dropdown.add_item("Modified (Newest)")

	sort_dropdown.select(current_sort_mode as int)
	sort_dropdown.connect("item_selected", self, "_on_sort_mode_changed")
	
	var custom_font = import_lnz_button.get_font("font")
	if custom_font:
		sort_label.add_font_override("font", custom_font)
		sort_dropdown.add_font_override("font", custom_font)
	
	sort_hbox.add_child(sort_label)
	sort_hbox.add_child(sort_dropdown)
	
	call_deferred("_inject_sort_ui", sort_hbox)

func _inject_sort_ui(sort_hbox: HBoxContainer):
	var parent = get_parent()
	parent.add_child(sort_hbox)
	parent.move_child(sort_hbox, 0)

func _on_sort_mode_changed(index: int):
	current_sort_mode = index 

	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg") 
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading config to save sort mode: ", err)
		
	config.set_value("Display", "file_tree_sort_mode", current_sort_mode)
	config.save("user://settings.cfg")
	
	var selected_path = null
	var selected = get_selected()
	if selected:
		selected_path = str(selected.get_metadata(0))
		if selected_path == "Null": selected_path = null
		
	rescan(selected_path)

func _on_ImportLNZ_pressed():
	current_import_type = ImportType.LNZ
	if (!OS.has_feature("HTML5")):
		pet_view_container.input_is_paused = true
		file_dialog.clear_filters()
		file_dialog.add_filter("*.lnz ; LNZ Files")
		file_dialog.add_filter("*.txt ; Text Files")
		file_dialog.mode = FileDialog.MODE_OPEN_FILES
		file_dialog.popup_centered()
	else:
		web_file_dialog(".lnz,.txt")

func _on_ImportTexture_pressed():
	current_import_type = ImportType.TEXTURE
	if (!OS.has_feature("HTML5")):
		pet_view_container.input_is_paused = true
		file_dialog.clear_filters()
		file_dialog.add_filter("*.bmp ; BMP Textures")
		file_dialog.mode = FileDialog.MODE_OPEN_FILES
		file_dialog.popup_centered()
	else:
		web_file_dialog(".bmp")

func _on_ImportPalette_pressed():
	current_import_type = ImportType.PALETTE
	if (!OS.has_feature("HTML5")):
		pet_view_container.input_is_paused = true
		file_dialog.clear_filters()
		file_dialog.add_filter("*.png, *.bmp ; Palette Files")
		file_dialog.mode = FileDialog.MODE_OPEN_FILES
		file_dialog.popup_centered()
	else:
		web_file_dialog(".png")

func _on_OpenUserFolder_pressed():
	var path = ProjectSettings.globalize_path("user://")
	OS.shell_open(path)

func _on_FileDialog_files_selected(paths: Array):
	var imported_types := {"lnz": false, "bmp": false, "png": false}
	var last_lnz_path = ""
	
	for p in paths:
		var dest_path = _on_FileDialog_file_selected(p, true) 
		
		if dest_path != "":
			var ext = dest_path.get_extension().to_lower()
			if imported_types.has(ext):
				imported_types[ext] = true
			if ext == "lnz":
				last_lnz_path = dest_path
				
	if imported_types["lnz"]:
		rescan(last_lnz_path)
		emit_signal("user_file_selected", last_lnz_path)
		
	if imported_types["bmp"]:
		rescan_textures(true)
		
	if imported_types["png"]:
		rescan_palettes()

func _on_FileDialog_file_selected(selected_path, skip_rescan = false) -> String:
	var file_extension = selected_path.get_extension().to_lower()
	var dest_dir = ""
	
	if current_import_type == ImportType.LNZ:
		dest_dir = user_file_location
	elif current_import_type == ImportType.TEXTURE:
		dest_dir = user_file_location.plus_file("textures")
	elif current_import_type == ImportType.PALETTE:
		dest_dir = user_file_location.plus_file("palettes")
	else:
		print("Unknown import type")
		return ""

	var dest_filename = selected_path.get_file()
	if current_import_type == ImportType.LNZ and file_extension == "txt":
		dest_filename = dest_filename.get_basename() + ".lnz"
	
	var dest_path = dest_dir.plus_file(dest_filename)

	var dir = Directory.new()
	if not dir.dir_exists(dest_dir):
		var err = dir.make_dir_recursive(dest_dir)
		if err != OK:
			print("Error creating directory: ", err)
			return ""

	if current_import_type == ImportType.PALETTE and file_extension == "bmp":
		var success = convert_bmp_to_palette_png(selected_path, dest_dir)
		if success:
			if not skip_rescan:
				rescan_palettes()
			return dest_dir.plus_file(dest_filename.get_basename() + ".png")
		return ""

	if current_import_type == ImportType.PALETTE:
		var img = Image.new()
		var err = img.load(selected_path, false, false)
		if err == OK:
			if img.get_height() != 1:
				print("Palette " + selected_path.get_file() + " is not 1 pixel high.")
				return ""
		else:
			print("Error loading image.")
			return ""

	var copy_success = false
	if file_extension == "txt" and current_import_type == ImportType.LNZ:
		var f_in = File.new()
		if f_in.open(selected_path, File.READ) == OK:
			var content = f_in.get_as_text()
			f_in.close()

			var f_out = File.new()
			if f_out.open(dest_path, File.WRITE) == OK:
				f_out.store_string(content)
				f_out.close()
				copy_success = true
			else:
				print("Error writing to destination file: ", dest_path)
		else:
			print("Error reading source file: ", selected_path)
	else:
		var err = dir.copy(selected_path, dest_path)
		if err == OK:
			copy_success = true
		else:
			print("Error copying file: ", err)

	if copy_success:
		if not skip_rescan:
			rescan_with_extension(dest_path.get_extension().to_lower(), dest_path)
		return dest_path
		
	return ""
		
func web_file_dialog(accept_extensions):
	JavaScript.eval("""
	window.fileUploadData = {}

	let el = document.createElement("input");
	el.type = "file"
	el.accept = '""" + accept_extensions + """'
	el.addEventListener("change", (e) => {
	  if (e.target.files.length > 0) {
		let file = e.target.files[0]
		window.fileUploadData.name = file.name

		let reader = new FileReader()
		reader.readAsArrayBuffer(file)
		reader.onloadend = (ev) => {
		  window.fileUploadData.blob = ev.target.result
		}
	  }
	})
	el.click()
	""")
	upload_popup.visible = true
	
func _on_web_file_upload_popup_confirmed():
	var file_blob = JavaScript.eval("window.fileUploadData.blob")
	if (file_blob == null):
		print("File is empty.")
		return
		
	var file_name = JavaScript.eval("window.fileUploadData.name")
	var file_extension = file_name.get_extension().to_lower()
	

	var dest_dir = ""
	if current_import_type == ImportType.LNZ:
		dest_dir = user_file_location
	elif current_import_type == ImportType.TEXTURE:
		dest_dir = user_file_location + "/textures"
	elif current_import_type == ImportType.PALETTE:
		dest_dir = user_file_location + "/palettes"
	else:
		return
	
	var dest_filename = file_name
	if current_import_type == ImportType.LNZ and file_extension == "txt":
		dest_filename = file_name.get_basename() + ".lnz"

	var dest_path = dest_dir.plus_file(dest_filename)

	var dir = Directory.new()
	if not dir.dir_exists(dest_dir):
		var err = dir.make_dir_recursive(dest_dir)
		if err != OK:
			print("Error creating directory: ", err)
			return

	if current_import_type == ImportType.PALETTE:
		var img = Image.new()
		var png_err = img.load_png_from_buffer(file_blob)
		if png_err == OK:
			if img.get_height() != 1:
				print("Warning: Palette " + file_name + " is not 1 pixel high.")
		else:
			print("Error loading PNG from buffer")
			return

	var file = File.new()
	var err = file.open(dest_path, File.WRITE)
	if err != OK:
		print("Error creating file: ", err)
		return
	file.store_buffer(file_blob)
	file.close()

	rescan_with_extension(dest_path.get_extension(), dest_path)

func rescan_with_extension(file_extension: String, dest_path: String):
	if file_extension == "lnz":
		rescan(dest_path)
		emit_signal("user_file_selected", dest_path)
	elif file_extension == "bmp":
		rescan_textures(true)
	elif file_extension == "png":
		rescan_palettes()

func _on_Tree_item_activated():
	var selected = get_selected() as TreeItem
	if not selected: return
	var filepath = str(selected.get_metadata(0)) 
	
	if filepath == null or filepath == "Null" or filepath.ends_with("/"):
		return
		
	var parent = selected.get_parent() as TreeItem
	var is_user_file = false
	var current_parent = parent
	while current_parent:
		if current_parent == local_storage:
			is_user_file = true
			break
		current_parent = current_parent.get_parent()

	if parent == examples or parent.get_parent() == examples:
		emit_signal("example_file_selected", filepath)
	elif is_user_file:
		emit_signal("user_file_selected", filepath)
	elif parent == local_storage_palettes:
		var filename = selected.get_text(0)
		var filename_no_ext = filename.get_basename()
		emit_signal("palette_selected", filename_no_ext)
		
	release_focus()

func rescan(selected_filepath):
	var was_collapsed = true
	if local_storage != null:
		was_collapsed = local_storage.collapsed
		_save_subfolder_states(local_storage)
		root.remove_child(local_storage)
		local_storage.free()
	
	local_storage = create_item(root, 1)
	local_storage.set_text(0, "Local Storage")
	local_storage.collapsed = was_collapsed
	scan_local_storage(selected_filepath)

func _save_subfolder_states(item: TreeItem):
	if not item: return
	var child = item.get_children()
	while child:
		var meta = str(child.get_metadata(0))
		if meta.ends_with("/"):
			saved_subfolder_states[meta] = child.collapsed
			_save_subfolder_states(child)
		child = child.get_next()
	
func rescan_textures(reload_model: bool = false):
	var was_collapsed = true
	if local_storage_textures != null:
		was_collapsed = local_storage_textures.collapsed
		root.remove_child(local_storage_textures)
	local_storage_textures = create_item(root, 2)
	local_storage_textures.set_text(0, "Local Textures")
	local_storage_textures.collapsed = was_collapsed
	scan_local_textures()

	if reload_model:
		var pet_node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
		if pet_node and pet_node.has_method("clear_texture_cache"):
			pet_node.clear_texture_cache()
			if pet_node.lnz:
				pet_node.recompose_model()

func rescan_res_textures():
	var was_collapsed = true
	if res_textures != null:
		was_collapsed = res_textures.collapsed
		root.remove_child(res_textures)
	res_textures = create_item(root, 3)
	res_textures.set_text(0, "Base Textures")
	res_textures.collapsed = was_collapsed
	scan_res_textures()
	
func rescan_palettes():
	var was_collapsed = true
	if local_storage_palettes != null:
		was_collapsed = local_storage_palettes.collapsed
		root.remove_child(local_storage_palettes)
	local_storage_palettes = create_item(root, 4)
	local_storage_palettes.set_text(0, "Local Palettes")
	local_storage_palettes.collapsed = was_collapsed
	scan_local_palettes()
	
func scan_local_storage(selected_filepath):
	var safe_filepath = "" if selected_filepath == null else str(selected_filepath)
	_scan_dir_recursive(user_file_location, local_storage, safe_filepath, true)

func _scan_dir_recursive(path: String, parent_item: TreeItem, selected_filepath: String, is_root: bool = false, depth: int = 0):
	if depth > MAX_RECURSION_DEPTH:
		return

	var dir = Directory.new()
	if dir.open(path) != OK:
		return
		
	dir.list_dir_begin(true, true)
	var filename = dir.get_next()
	
	var folders = []
	var files = []
	
	var file_checker = File.new()
	
	while filename != "":
		if dir.current_is_dir():
			if is_root and (filename == "textures" or filename == "palettes"):
				filename = dir.get_next()
				continue
			folders.append({"name": filename, "time": 0})
		elif filename.ends_with(".lnz"):
			var full_path = path.plus_file(filename)
			var mod_time = file_checker.get_modified_time(full_path)
			files.append({"name": filename, "path": full_path, "time": mod_time})
			
		filename = dir.get_next()
	dir.list_dir_end()
	
	folders.sort_custom(self, "_sort_by_name")
	
	if current_sort_mode == SortMode.ALPHABETICAL:
		files.sort_custom(self, "_sort_by_name")
	elif current_sort_mode == SortMode.MODIFIED_DATE:
		files.sort_custom(self, "_sort_by_time")
		
	for folder_data in folders:
		var f_name = folder_data["name"]
		var sub_path = path.plus_file(f_name)
		var sub_item = create_item(parent_item)
		sub_item.set_text(0, f_name)
		
		var meta_path = sub_path + "/"
		sub_item.set_metadata(0, meta_path)
		
		if saved_subfolder_states.has(meta_path):
			sub_item.set_collapsed(saved_subfolder_states[meta_path])
		else:
			sub_item.set_collapsed(true)
		
		_scan_dir_recursive(sub_path, sub_item, selected_filepath, false, depth + 1)
		
	for file_data in files:
		var f_name = file_data["name"]
		var full_path = file_data["path"]
		
		var new_item = create_item(parent_item)
		new_item.set_text(0, f_name)
		new_item.set_metadata(0, full_path)
		
		if full_path == selected_filepath:
			new_item.select(0)

func scan_local_textures():
	var dir = Directory.new()
	var textures_dir = user_file_location + "/textures"
	if dir.open(textures_dir) != OK:
		return
	dir.list_dir_begin()
	var filename = dir.get_next()
	var file = File.new()

	while filename != "":
		if filename.to_lower().ends_with(".bmp"):
			var full_path = textures_dir.plus_file(filename)

			var new_item = create_item(local_storage_textures)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, full_path)

			# Check whether valid BMP file
			var is_valid_bmp = false
			if file.open(full_path, File.READ) == OK:
				if file.get_len() >= 2:
					var b1 = file.get_8()
					var b2 = file.get_8()
					if b1 == 66 and b2 == 77: # 'B' and 'M'
						is_valid_bmp = true
				file.close()

			if not is_valid_bmp:
				new_item.set_text(0, filename + " (FILE ISSUE)")
			else:
				# Load image for texture
				var img_indexed = Image.new()
				var err = img_indexed.load(full_path, true, true)
				
				if err != OK or img_indexed.get_width() == 0:
					new_item.set_text(0, filename + " (FILE ISSUE)")
				else:
					var full_tex = ImageTexture.new()
					full_tex.flags = 0
					full_tex.create_from_image(img_indexed, ImageTexture.FLAG_REPEAT)
					
					var res_name = filename.to_lower()
					if preloader.has_resource(res_name):
						preloader.remove_resource(res_name)
					preloader.add_resource(res_name, full_tex)

					# Load image for preview
					if file.open(full_path, File.READ) == OK:
						var buf = file.get_buffer(file.get_len())
						file.close()

						var icon_img = Image.new()
						var icon_err = icon_img.load_bmp_from_buffer(buf)
						
						if icon_err == OK and icon_img.get_width() > 0:
							var w = icon_img.get_width()
							var h = icon_img.get_height()

							icon_img.convert(Image.FORMAT_RGBA8)
							icon_img.resize(32, 32, Image.INTERPOLATE_NEAREST)

							var icon_tex = ImageTexture.new()
							icon_tex.create_from_image(icon_img, ImageTexture.FLAG_FILTER)
							new_item.set_icon(0, icon_tex)

							new_item.set_text(0, filename + " (" + str(w) + "x" + str(h) + ")")
						else:
							new_item.set_text(0, filename + " (FILE ISSUE)")
					else:
						new_item.set_text(0, filename + " (FILE ISSUE)")

		filename = dir.get_next()
	dir.list_dir_end()

func scan_res_textures():
	var processed = []
	var textures_dir = "res://resources/textures"
	
	var atlas_manifest_path = "res://resources/texture_atlas/atlas_manifest.json"
	var f = File.new()
	if f.open(atlas_manifest_path, File.READ) == OK:
		var result = JSON.parse(f.get_as_text())
		f.close()
		if result.error == OK:
			var manifest = result.result
			print("FileTree scanning atlas manifest...")

			var sorted_keys = manifest.keys()
			sorted_keys.sort()
			
			for key in sorted_keys:
				var entry = manifest[key]
				var texture_name = key
				if !texture_name.to_lower().ends_with(".bmp"):
					texture_name += ".bmp"
				
				processed.append(texture_name)
				
				var new_item = create_item(res_textures)
				new_item.set_text(0, texture_name)
				new_item.set_metadata(0, textures_dir.plus_file(texture_name))
				
				var thumb_path = textures_dir.plus_file(texture_name.get_basename() + "_thumb.png")
				
				if ResourceLoader.exists(thumb_path):
					var thumb = ResourceLoader.load(thumb_path)
					new_item.set_icon(0, thumb)
				else:
					var atlas_file = entry["atlas"]
					if atlas_file.to_lower().ends_with(".bmp"):
						atlas_file = atlas_file.get_basename() + ".png"
					var atlas_path = "res://resources/texture_atlas/" + atlas_file
					
					if ResourceLoader.exists(atlas_path):
						var atlas_tex = ResourceLoader.load(atlas_path)
						var region = Rect2(entry["x"], entry["y"], entry["w"], entry["h"])
						var icon_tex = AtlasTexture.new()
						icon_tex.atlas = atlas_tex
						icon_tex.region = region
						new_item.set_icon(0, icon_tex)

	var dir = Directory.new()
	if dir.open(textures_dir) == OK:
		dir.list_dir_begin()
		var filename = dir.get_next()

		while filename != "":
			var final_filename = ""
			
			if filename.to_lower().ends_with(".bmp"):
				final_filename = filename
			elif filename.to_lower().ends_with(".bmp.import"):
				final_filename = filename.get_basename()

			if final_filename != "" and not final_filename in processed:
				processed.append(final_filename)
				var full_path = textures_dir.plus_file(final_filename)

				var new_item = create_item(res_textures)
				new_item.set_text(0, final_filename)
				new_item.set_metadata(0, full_path)

				var thumb_path = full_path.get_basename() + "_thumb.png"
				
				if ResourceLoader.exists(thumb_path):
					var thumb_tex = load(thumb_path)
					if thumb_tex:
						new_item.set_icon(0, thumb_tex)

			filename = dir.get_next()
		dir.list_dir_end()

func scan_local_palettes():
	var dir2 = Directory.new()
	if not dir2.dir_exists(user_file_location + "/palettes"):
		return

	dir2.open(user_file_location + "/palettes")
	dir2.list_dir_begin()
	var filename = dir2.get_next()
	
	while(!filename.empty()):
		if filename.ends_with(".png"):
			var full_path = user_file_location + "/palettes/" + filename
			
			var new_item = create_item(local_storage_palettes)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, full_path)
			
			var img = Image.new()
			var err = img.load(full_path, true, true)
			
			if err == OK:
				var tex = ImageTexture.new()
				tex.create_from_image(img, 0)
				var clean_key = "palette_" + filename.strip_edges().to_lower()
				preloader.add_resource(clean_key, tex)
				
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				
				var w = img.get_width()
				var h = img.get_height()
				
				if w >= 200:
					img.lock()
					
					var preview_img = Image.new()
					preview_img.create(32, 20, false, Image.FORMAT_RGBA8)
					preview_img.lock()
					
					var color_index = 0
					
					for i in range(10, 200, 10):
						var pos_start = Vector2(0, i) if h > w else Vector2(i, 0)
						var pos_end = Vector2(0, i + 8) if h > w else Vector2(i + 8, 0)
						
						var c1 = img.get_pixel(pos_start.x, pos_start.y)
						var c2 = img.get_pixel(pos_end.x, pos_end.y)
						
						var row = color_index / 8
						var col = color_index % 8
						var x_base = col * 4
						var y_base = row * 4

						for y in range(4):
							for x in range(4):
								if x_base + x < 32 and y_base + y < 20:
									preview_img.set_pixel(x_base + x, y_base + y, c1)
						color_index += 1
						
						row = color_index / 8
						col = color_index % 8
						x_base = col * 4
						y_base = row * 4
						for y in range(4):
							for x in range(4):
								if x_base + x < 32 and y_base + y < 20:
									preview_img.set_pixel(x_base + x, y_base + y, c2)
						color_index += 1
					
					preview_img.unlock()
					img.unlock()
					
					var icon_tex = ImageTexture.new()
					icon_tex.create_from_image(preview_img, 0)
					new_item.set_icon(0, icon_tex)
					
				else:
					var fallback = img.duplicate()
					fallback.resize(32, 32, Image.INTERPOLATE_NEAREST)
					var icon_tex = ImageTexture.new()
					icon_tex.create_from_image(fallback, 0)
					new_item.set_icon(0, icon_tex)

		filename = dir2.get_next()
	dir2.list_dir_end()

func convert_bmp_to_palette_png(source_path: String, dest_dir: String) -> bool:
	var f = File.new()
	if f.open(source_path, File.READ) != OK:
		print("Error: Could not read BMP file.")
		return false
	
	f.seek(10)
	var pixel_offset = f.get_32()
	
	f.seek(14)
	var header_size = f.get_32()
	
	f.seek(28)
	var bpp = f.get_16()
	
	if bpp != 8:
		print("Error: This BMP is " + str(bpp) + "-bit. Only 8-bit BMPs have palettes.")
		f.close()
		return false
	
	var palette_offset = 14 + header_size
	
	f.seek(palette_offset)
	
	var img = Image.new()
	img.create(256, 1, false, Image.FORMAT_RGBA8)
	img.lock()
	
	var buffer = f.get_buffer(1024) # 256 colors * 4 bytes per color
	
	for i in range(256):
		# if f.get_position() >= pixel_offset or (i * 4 + 3) >= buffer.size():
		# 	break
			
		var current_byte_pos = palette_offset + (i * 4) 
		
		if current_byte_pos >= pixel_offset or (i * 4 + 3) >= buffer.size():
			break
			
		var b = buffer[i * 4] / 255.0
		var g = buffer[i * 4 + 1] / 255.0
		var r = buffer[i * 4 + 2] / 255.0
		
		img.set_pixel(i, 0, Color(r, g, b, 1.0))
		
	img.unlock()
	f.close()
	
	var dest_filename = source_path.get_file().get_basename() + ".png"
	var dest_path = dest_dir.plus_file(dest_filename)
	
	var err = img.save_png(dest_path)
	if err == OK:
		print("Converted BMP palette to: " + dest_path)
		return true
	else:
		print("Error saving PNG palette.")
		return false

func get_all_selected() -> Array:
	var selected_items = []
	var current = get_next_selected(null)
	while current:
		selected_items.append(current)
		current = get_next_selected(current)
	return selected_items

func _on_Tree_item_rmb_selected(position):
	var items = get_all_selected()
	if items.size() == 0: return
	
	$ItemPopupMenu.rect_global_position = position

	if items.size() > 1:
		for i in range($ItemPopupMenu.get_item_count()):
			var id = $ItemPopupMenu.get_item_id(i)
			var allowed_multi = (id == 0 or id == 5 or id == 6)
			$ItemPopupMenu.set_item_disabled(i, !allowed_multi)
	else:
		var item = get_selected()
		if not item: return
		
		var p = item.get_parent()
		var meta = str(item.get_metadata(0))
		var is_dir = meta != "Null" and meta.ends_with("/")
		
		var is_local_content = false
		var is_local_file = false
		
		var curr = p
		while curr:
			if curr == local_storage or curr == local_storage_textures or curr == local_storage_palettes:
				is_local_content = true
			if curr == local_storage:
				is_local_file = true
			curr = curr.get_parent()

		for i in range($ItemPopupMenu.get_item_count()):
			var id = $ItemPopupMenu.get_item_id(i)
			if id == 0: $ItemPopupMenu.set_item_disabled(i, !is_local_content) # Delete
			elif id == 1: $ItemPopupMenu.set_item_disabled(i, !is_local_content) # Rename
			elif id == 2: $ItemPopupMenu.set_item_disabled(i, !is_local_file or is_dir) # Backup
			elif id == 3: $ItemPopupMenu.set_item_disabled(i, false) # Copy Filename
			elif id == 4: $ItemPopupMenu.set_item_disabled(i, !is_local_file or is_dir) # Export File
			elif id == 5: $ItemPopupMenu.set_item_disabled(i, !is_local_file) # New Folder
			elif id == 6: $ItemPopupMenu.set_item_disabled(i, !is_local_file) # Move To...

	$ItemPopupMenu.popup()
	
func _on_ItemPopupMenu_id_pressed(id):
	if id == 0: # delete file/folder
		var items = get_all_selected()
		if items.size() == 0: return
		
		var dir = Directory.new()
		for item in items:
			var filepath = str(item.get_metadata(0))
			
			if filepath == null or filepath == "Null":
				continue
			
			if filepath.ends_with("/"):
				_delete_dir_recursive(filepath.trim_suffix("/"))
			elif dir.file_exists(filepath):
				dir.remove(filepath)

		rescan(null)
		rescan_textures()
		rescan_palettes()

	elif id == 1: # rename file
		var item = get_selected()
		if not item: return
		var filepath = str(item.get_metadata(0))
		if filepath == null or filepath == "Null":
			return
		
		rename_dialog.popup()
		rename_dialog.get_node("LineEdit").text = filepath.get_file()
		
	elif id == 2: # backup
		emit_signal("backup_file")
		
	elif id == 3: # copy file name
		var item = get_selected()
		if not item: return
		var filepath = str(item.get_metadata(0))
		if filepath != "Null":
			var filename = filepath.get_file()
			OS.set_clipboard(filename)
			
	elif id == 4: # export file
		var item = get_selected()
		if not item: return
		var item_filepath = str(item.get_metadata(0))
		if item_filepath == null or item_filepath == "Null" or item_filepath.ends_with("/"): return
		
		var filename = item.get_text(0)
		var file = File.new()
		if file.open(item_filepath, File.READ) != OK:
			print("Error: Could not open file for reading: " + item_filepath)
			return
		var content_bytes = file.get_buffer(file.get_len())
		file.close()
		
		_save_file_as(filename, content_bytes)
		
	elif id == 5: # New Folder
		var timestamp = str(OS.get_unix_time())
		new_folder_input.text = "new_folder_" + timestamp 
		new_folder_dialog.popup_centered(Vector2(250, 100))
		
	elif id == 6: # Move To
		_populate_move_dropdown()
		move_dialog.popup_centered(Vector2(300, 100))

func _delete_dir_recursive(path: String, depth: int = 0):
	if depth > MAX_RECURSION_DEPTH:
		print("Warning: Max deletion depth reached at: ", path)
		return
		
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.plus_file(file_name)
			if dir.current_is_dir():
				_delete_dir_recursive(full_path, depth + 1)
			else:
				dir.remove(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		dir.remove(path)

func _on_SaveDialog_file_selected(path, content_bytes):
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_buffer(content_bytes)
		file.close()
		print("File saved successfully to: " + path)
	else:
		print("Error saving file to: " + path)

	if is_instance_valid(self):
		for child in get_children():
			if child is FileDialog and child.window_title == "Save File As":
				child.queue_free()
				return

func _save_file_as(filename: String, content_bytes: PoolByteArray):	
	if OS.has_feature("HTML5"):		
		var escaped_filename = filename.replace("'", "\\'")
		var base64_content = Marshalls.raw_to_base64(content_bytes)
		
		var mime_type = "application/octet-stream"
		if filename.ends_with(".lnz"): mime_type = "text/plain"
		elif filename.ends_with(".bmp"): mime_type = "image/bmp"
		elif filename.ends_with(".png"): mime_type = "image/png"
		
		var js_code = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:""" + mime_type + """;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + escaped_filename + """');
		
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
		
	else:
		var save_dialog = FileDialog.new()
		
		save_dialog.connect("file_selected", self, "_on_SaveDialog_file_selected", [content_bytes])
		
		save_dialog.add_filter("*.lnz, *.bmp, *.png, *.* ; All Files")
		save_dialog.mode = FileDialog.MODE_SAVE_FILE
		save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_dialog.window_title = "Save File As"
		save_dialog.current_file = filename
		save_dialog.rect_min_size = Vector2(400, 400)
		save_dialog.popup_exclusive = true
		
		add_child(save_dialog)
		save_dialog.popup_centered()

func _on_RenameDialog_confirmed():
	var items = get_all_selected()
	if items.size() != 1: 
		return
		
	var item = items[0]
	var filepath = item.get_metadata(0)
	
	if filepath == null or str(filepath) == "Null": 
		return
	
	var filepath_str = str(filepath)
	var dir = Directory.new()
	var new_filename = rename_dialog.get_node("LineEdit").text.strip_edges()
	
	if new_filename == "" or new_filename == filepath_str.get_file():
		return

	var base_dir = filepath_str.get_base_dir()
	var new_filepath = base_dir.plus_file(new_filename)
	
	if filepath_str.ends_with("/"):
		new_filepath += "/"

	if dir.rename(filepath_str, new_filepath) == OK:
		rescan(null)
		rescan_textures()
		rescan_palettes()

		if new_filepath.ends_with(".lnz"):
			emit_signal("user_file_selected", new_filepath)

	release_focus()

func _on_ItemPopupMenu_about_to_show():
	var items = get_all_selected()
	if items.size() > 1: return

	var clicked_item = get_selected() as TreeItem
	if not clicked_item: return

	var clicked_filepath = clicked_item.get_metadata(0)
	
	if clicked_filepath != null:
		if lnz_text_edit:
			$ItemPopupMenu.set_item_disabled(2, !(lnz_text_edit.filepath == clicked_filepath))

func _on_LnzTextEdit_file_backed_up():
	var item = get_selected()
	var path = str(item.get_metadata(0)) if item else null
	if path == null or path == "Null": 
		path = null
	rescan(path)

func get_expanded_states() -> Dictionary:
	_save_subfolder_states(local_storage)
	return {
		"Examples": examples.collapsed == false if examples else true,
		"Local Storage": local_storage.collapsed == false if local_storage else true,
		"Local Textures": local_storage_textures.collapsed == false if local_storage_textures else false,
		"Base Textures": res_textures.collapsed == false if res_textures else false,
		"Local Palettes": local_storage_palettes.collapsed == false if local_storage_palettes else false,
		"Subfolders": saved_subfolder_states
	}

func set_expanded_states(states: Dictionary):
	if examples: examples.collapsed = !states.get("Examples", true)
	if local_storage: local_storage.collapsed = !states.get("Local Storage", true)
	if local_storage_textures: local_storage_textures.collapsed = !states.get("Local Textures", false)
	if res_textures: res_textures.collapsed = !states.get("Base Textures", false)
	if local_storage_palettes: local_storage_palettes.collapsed = !states.get("Local Palettes", false)
	if states.has("Subfolders"):
		saved_subfolder_states = states.get("Subfolders")

func _populate_move_dropdown():
	move_dropdown.clear()
	move_dropdown.add_item("Root (user://resources/)")
	move_dropdown.set_item_metadata(0, user_file_location) 
	
	var dirs = []
	_get_all_subdirs(user_file_location, dirs)
	
	var idx = 1
	for d in dirs:
		var display_name = d.replace(user_file_location, "")
		move_dropdown.add_item(display_name)
		move_dropdown.set_item_metadata(idx, d)
		idx += 1

func _get_all_subdirs(path: String, out_array: Array, depth: int = 0):
	if depth > MAX_RECURSION_DEPTH:
		return

	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if path == user_file_location and (file_name == "textures" or file_name == "palettes"):
					file_name = dir.get_next()
					continue
					
				var full_path = path.plus_file(file_name)
				out_array.append(full_path + "/")
				_get_all_subdirs(full_path, out_array, depth + 1)
			file_name = dir.get_next()
		dir.list_dir_end()

func _on_NewFolderDialog_confirmed():
	var items = get_all_selected()
	if items.size() == 0: return
	
	var folder_name = new_folder_input.text.strip_edges()
	if folder_name == "": return
	
	var first_item = items[0]
	var first_meta = str(first_item.get_metadata(0))
	var base_is_dir = first_meta.ends_with("/")
	var base_dir = first_meta if base_is_dir else first_meta.get_base_dir() + "/"
	
	var new_dir_path = base_dir.plus_file(folder_name)
	var dir = Directory.new()
	
	if not dir.dir_exists(new_dir_path):
		dir.make_dir(new_dir_path)
		
	for item in items:
		var item_meta = str(item.get_metadata(0))
		if item_meta == null or item_meta == "Null":
			continue
		
		if item_meta == base_dir:
			continue 
		
		var clean_meta = item_meta.trim_suffix("/")
		var item_name = clean_meta.get_file()
		
		dir.rename(clean_meta, new_dir_path.plus_file(item_name))
			
	rescan(null)

func _on_MoveFileDialog_confirmed():
	var items = get_all_selected()
	if items.size() == 0: return
	
	var target_dir = move_dropdown.get_selected_metadata()
	if not target_dir: return
	
	var dir = Directory.new()
	var any_moved = false
	var last_lnz_path = ""
	
	for item in items:
		var current_path = str(item.get_metadata(0))
		if current_path == null or current_path == "Null":
			continue
		
		var clean_path = current_path.trim_suffix("/")
		var file_name = clean_path.get_file()
		
		if current_path.ends_with("/") and target_dir.begins_with(current_path):
			print("Cannot move a folder into itself!")
			continue
		
		var new_path = target_dir.plus_file(file_name)
		
		if dir.rename(clean_path, new_path) == OK:
			any_moved = true
			if new_path.ends_with(".lnz"):
				last_lnz_path = new_path
			
	if any_moved:
		rescan(null)

func _sort_by_name(a: Dictionary, b: Dictionary) -> bool:
	return a["name"].to_lower() < b["name"].to_lower()

func _sort_by_time(a: Dictionary, b: Dictionary) -> bool:
	return a["time"] > b["time"]
