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

onready var pet_view_container = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")

var examples: TreeItem
var local_storage: TreeItem
var root: TreeItem
var local_storage_textures: TreeItem
var res_textures: TreeItem
var local_storage_palettes: TreeItem

export var example_file_location = "res://resources/"
export var user_file_location = "user://resources/"

onready var rename_dialog = get_tree().root.get_node("Root/SceneRoot/RenameDialog") as WindowDialog
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
	
	var dir = Directory.new()
	var lnz_dir_path = "res://resources/lnz/"
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

	rescan(null)
	rescan_textures()
	rescan_res_textures()
	rescan_palettes()

func _on_FileDialog_popup_hide():
	pet_view_container.input_is_paused = false

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
	for p in paths:
		_on_FileDialog_file_selected(p)

func _on_FileDialog_file_selected(selected_path):
	var file_extension = selected_path.get_extension().to_lower()
	var dest_dir = ""
	
	if current_import_type == ImportType.LNZ:
		dest_dir = user_file_location
	elif current_import_type == ImportType.TEXTURE:
		dest_dir = user_file_location + "/textures"
	elif current_import_type == ImportType.PALETTE:
		dest_dir = user_file_location + "/palettes"
	else:
		print("Unknown import type")
		return

	if current_import_type == ImportType.PALETTE and file_extension == "bmp":
		var success = convert_bmp_to_palette_png(selected_path, dest_dir)
		if success:
			rescan_palettes()
			return

	if current_import_type == ImportType.PALETTE:
		var img = Image.new()
		var err = img.load(selected_path, false, false)
		if err == OK:
			if img.get_height() != 1:
				print("Palette " + selected_path.get_file() + " is not 1 pixel high.")
				return
		else:
			print("Error loading image.")
			return

	var dest_filename = selected_path.get_file()
	if current_import_type == ImportType.LNZ and file_extension == "txt":
		dest_filename = dest_filename.get_basename() + ".lnz"
	
	var dest_path = dest_dir.plus_file(dest_filename)

	var dir = Directory.new()
	if not dir.dir_exists(dest_dir):
		var err = dir.make_dir_recursive(dest_dir)
		if err != OK:
			print("Error creating directory: ", err)
			return

	var copy_success = false
	if file_extension == "txt" and current_import_type == ImportType.LNZ:
		# Copy content manually for txt to lnz
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
		rescan_with_extension(dest_path.get_extension(), dest_path)
		
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
		rescan_textures()
	elif file_extension == "png":
		rescan_palettes()

func _on_Tree_item_activated():
	var selected = get_selected() as TreeItem
	var filepath = selected.get_metadata(0)
	var parent = selected.get_parent() as TreeItem
	if filepath == null:
		return
	if parent == examples or parent.get_parent() == examples:
		emit_signal("example_file_selected", filepath)
	elif parent == local_storage:
		emit_signal("user_file_selected", filepath)
	elif parent == local_storage_palettes:
		var filename = selected.get_text(0)
		var filename_no_ext = filename.get_basename()
		emit_signal("palette_selected", filename_no_ext)
	release_focus()

func rescan(selected_filepath):
	if local_storage != null:
		root.remove_child(local_storage)
	local_storage = create_item(root, 1)
	local_storage.set_text(0, "Local Storage")
	scan_local_storage(selected_filepath)
	
func rescan_textures():
	var was_collapsed = true
	if local_storage_textures != null:
		was_collapsed = local_storage_textures.collapsed
		root.remove_child(local_storage_textures)
	local_storage_textures = create_item(root, 2)
	local_storage_textures.collapsed = was_collapsed
	local_storage_textures.set_text(0, "Local Textures")
	scan_local_textures()

func rescan_res_textures():
	var was_collapsed = true
	if res_textures != null:
		was_collapsed = res_textures.collapsed
		root.remove_child(res_textures)
	res_textures = create_item(root, 3)
	res_textures.collapsed = was_collapsed
	res_textures.set_text(0, "Base Textures")
	scan_res_textures()
	
func rescan_palettes():
	var was_collapsed = true
	if local_storage_palettes != null:
		was_collapsed = local_storage_palettes.collapsed
		root.remove_child(local_storage_palettes)
	local_storage_palettes = create_item(root, 4)
	local_storage_palettes.collapsed = was_collapsed
	local_storage_palettes.set_text(0, "Local Palettes")
	scan_local_palettes()
	
func scan_local_storage(selected_filepath):
	var dir2 = Directory.new()
	dir2.open(user_file_location)
	dir2.list_dir_begin()
	var filename = dir2.get_next()
	while(!filename.empty()):
		if filename.ends_with(".lnz"):
			var new_item = create_item(local_storage)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, user_file_location + filename)
			if(user_file_location + filename == selected_filepath):
				new_item.select(0)
		filename = dir2.get_next()
	dir2.list_dir_end()

func scan_local_textures():
	var dir = Directory.new()
	var textures_dir = user_file_location + "/textures"
	if dir.open(textures_dir) != OK:
		return
	dir.list_dir_begin()
	var filename = dir.get_next()
	while filename != "":
		if filename.to_lower().ends_with(".bmp"):
			var full_path = textures_dir.plus_file(filename)

			var new_item = create_item(local_storage_textures)
			new_item.set_text(0, filename)
			new_item.set_metadata(0, full_path)

			# Load image for texture
			var img_indexed = Image.new()
			img_indexed.load(full_path, true, true)
			var full_tex = ImageTexture.new()
			full_tex.flags = 0
			full_tex.create_from_image(
				img_indexed,
				ImageTexture.FLAG_REPEAT
			)
			preloader.add_resource(filename.to_lower(), full_tex)

			# Load image for preview
			var file = File.new()
			if file.open(full_path, File.READ) == OK:
				var buf = file.get_buffer(file.get_len())
				file.close()

				var icon_img = Image.new()
				icon_img.load_bmp_from_buffer(buf)

				var w = icon_img.get_width()
				var h = icon_img.get_height()

				icon_img.convert(Image.FORMAT_RGBA8)
				icon_img.resize(32, 32, Image.INTERPOLATE_NEAREST)

				var icon_tex = ImageTexture.new()
				icon_tex.create_from_image(icon_img, ImageTexture.FLAG_FILTER)
				new_item.set_icon(0, icon_tex)

				new_item.set_text(0, filename + " (" + str(w) + "x" + str(h) + ")")
		filename = dir.get_next()
	dir.list_dir_end()

func scan_res_textures():
	var dir = Directory.new()
	var textures_dir = "res://resources/textures"
	if dir.open(textures_dir) != OK:
		return
	dir.list_dir_begin()
	var filename = dir.get_next()

	var processed = []

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
				preloader.add_resource("palette_" + filename.to_lower(), tex)
				
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				
				var w = img.get_width()
				var h = img.get_height()
				
				if w >= 200:
					img.lock()
					
					# Create the thumbnail 32 x 20 thumbnail
					var preview_img = Image.new()
					preview_img.create(32, 20, false, Image.FORMAT_RGBA8)
					preview_img.lock()
					
					# 38 colors total (19 ranges * 2 samples)
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
	
	for i in range(256):
		if f.get_position() >= pixel_offset:
			break
			
		var b = f.get_8() / 255.0
		var g = f.get_8() / 255.0
		var r = f.get_8() / 255.0
		var _reserved = f.get_8()
		
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
	$ItemPopupMenu.rect_global_position = position
	var items = get_all_selected()

	if items.size() > 1:
		for i in range($ItemPopupMenu.get_item_count()):
			if i == 0: # Delete
				$ItemPopupMenu.set_item_disabled(i, false)
			else:
				$ItemPopupMenu.set_item_disabled(i, true)
	else:
		var item = get_selected()
		var p = item.get_parent()
		var is_local_file = (p == local_storage)
		var is_local_content = (p == local_storage or p == local_storage_textures or p == local_storage_palettes)

		$ItemPopupMenu.set_item_disabled(0, !is_local_content) # Delete
		$ItemPopupMenu.set_item_disabled(1, !is_local_content) # Rename
		$ItemPopupMenu.set_item_disabled(2, !is_local_file) # Backup
		$ItemPopupMenu.set_item_disabled(3, false) # Copy Filename
		$ItemPopupMenu.set_item_disabled(4, !is_local_file) # Export File

	$ItemPopupMenu.popup()
	
func _on_ItemPopupMenu_id_pressed(id):
	if id == 0: # delete file
		var items = get_all_selected()
		var dir = Directory.new()
		for item in items:
			var filepath = item.get_metadata(0)
			if filepath and dir.file_exists(filepath):
				dir.remove(filepath)

		rescan(null)
		rescan_textures()
		rescan_palettes()

	elif id == 1: # rename file
		var item = get_selected() as TreeItem
		var filepath = item.get_metadata(0) as String
		rename_dialog.popup()
		rename_dialog.get_node("LineEdit").text = filepath.get_file()
	elif id == 2: # backup
		emit_signal("backup_file")
	elif id == 3: # copy file name
		var item = get_selected() as TreeItem
		var filepath = item.get_metadata(0)
		var filename = filepath.get_file()
		OS.set_clipboard(filename)
	elif id == 4: # export file
		var item = get_selected() as TreeItem
		var item_filepath = item.get_metadata(0)
		var filename = item.get_text(0)
		var file = File.new()
		if file.open(item_filepath, File.READ) != OK:
			print("Error: Could not open file for reading: " + item_filepath)
			return
		var content_bytes = file.get_buffer(file.get_len())
		file.close()
		
		_save_file_as(filename, content_bytes)

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
		
		add_child(save_dialog)
		save_dialog.popup_centered()

func _on_RenameDialog_confirmed():
	var item = get_selected() as TreeItem
	var filepath = item.get_metadata(0) as String
	var dir = Directory.new()
	var new_filename = rename_dialog.get_node("LineEdit").text
	var new_filepath = filepath.replace(filepath.get_file(), new_filename)
	dir.rename(filepath, new_filepath)

	rescan(null)
	rescan_textures()
	rescan_palettes()

	if new_filepath.ends_with(".lnz"):
		emit_signal("user_file_selected", new_filepath)

func _on_ItemPopupMenu_about_to_show():
	var items = get_all_selected()
	if items.size() > 1:
		return

	var clicked_item = get_selected() as TreeItem
	var textlnz = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit") as TextEdit
	var clicked_filepath = clicked_item.get_metadata(0)
	if (clicked_filepath != null):
		$ItemPopupMenu.set_item_disabled(2, !textlnz.filepath == clicked_filepath)

func _on_LnzTextEdit_file_backed_up():
	rescan(get_selected().get_metadata(0) as String)
