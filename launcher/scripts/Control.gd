extends VBoxContainer

const REPO_OWNER = "tabbzi"
const REPO_NAME = "LnzLive"
const GAME_EXE_NAME = "LnzLive.exe"
const VERSION_FILE_NAME = "version.txt"
const TEMP_FILE_NAME = "download_cache.tmp"
const SETTINGS_FILE = "user://launcher_settings.cfg"

const GITHUB_API_URL = "https://api.github.com/repos/%s/%s/releases" % [REPO_OWNER, REPO_NAME]

onready var status_label = $StatusLabel
onready var progress_bar = $ProgressBar
onready var version_selector = $ChannelSelector 
onready var btn_launch = $BtnLaunch
onready var btn_update = $BtnUpdate
onready var btn_install = $BtnInstall
onready var btn_open_folder = $BtnOpenFolder 

var texture_rect
var notes_scroll
var notes_text
var executable_selector
var btn_notes
var btn_appdata
var btn_change_path
var lbl_path_display
var file_dialog

var http_api
var http_download
var local_version = ""
var local_asset_name = ""
var target_remote_version = ""
var target_download_url = ""
var target_asset_name = ""
var install_dir = "" 
var game_install_path = "" 
var version_file_path = "" 

var all_releases_data = [] 
var current_release_assets = []

func _ready():
	texture_rect = get_node("../../TextureRect")
	
	call_deferred("setup_dynamic_ui")
	
	load_install_config()
	ensure_directory_exists()
	update_paths_and_label()
	setup_http_requests()
	setup_version_selector()
	
	btn_launch.connect("pressed", self, "_on_BtnLaunch_pressed")
	btn_update.connect("pressed", self, "_on_BtnUpdate_pressed")
	btn_install.connect("pressed", self, "_on_BtnInstall_pressed")
	
	if has_node("BtnOpenFolder"):
		btn_open_folder.connect("pressed", self, "_on_BtnOpenFolder_pressed")
	
	progress_bar.value = 0
	disable_all_buttons()
	status_label.text = "Checking local files..."
	
	check_local_version()
	status_label.text = "Checking for updates..."
	
	check_launch_readiness()
	check_github_updates()

func setup_dynamic_ui():
	var hbox = texture_rect.get_parent()
	
	notes_scroll = ScrollContainer.new()
	notes_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	notes_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	notes_scroll.visible = false
	hbox.add_child(notes_scroll)
	hbox.move_child(notes_scroll, texture_rect.get_index() + 1)
	
	notes_text = RichTextLabel.new()
	notes_text.size_flags_horizontal = SIZE_EXPAND_FILL
	notes_text.size_flags_vertical = SIZE_EXPAND_FILL
	notes_text.bbcode_enabled = true
	
	if status_label.has_font_override("font"):
		var base_font = status_label.get_font("font")
		notes_text.add_font_override("normal_font", base_font)
		notes_text.add_font_override("bold_font", base_font)
		notes_text.add_font_override("italics_font", base_font)
		notes_text.add_font_override("bold_italics_font", base_font)
		notes_text.add_font_override("mono_font", base_font)
		
	notes_scroll.add_child(notes_text)

	executable_selector = OptionButton.new()
	executable_selector.rect_min_size = Vector2(0, 25)
	_copy_button_style(version_selector, executable_selector)
	executable_selector.align = Button.ALIGN_CENTER
	executable_selector.connect("item_selected", self, "_on_executable_changed")
	add_child(executable_selector)
	move_child(executable_selector, version_selector.get_index() + 1)

	btn_notes = Button.new()
	btn_notes.text = "See Release Notes"
	btn_notes.rect_min_size = Vector2(0, 25)
	_copy_button_style(btn_install, btn_notes)
	btn_notes.connect("pressed", self, "_on_BtnNotes_pressed")
	add_child(btn_notes)
	move_child(btn_notes, executable_selector.get_index() + 1)

	var folder_hbox = HBoxContainer.new()
	folder_hbox.add_constant_override("separation", 10)
	
	var folder_index = btn_open_folder.get_index()
	add_child(folder_hbox)
	move_child(folder_hbox, folder_index)
	
	remove_child(btn_open_folder)
	folder_hbox.add_child(btn_open_folder)
	btn_open_folder.size_flags_horizontal = SIZE_EXPAND_FILL
	
	btn_appdata = Button.new()
	btn_appdata.text = "Open User Folder"
	btn_appdata.rect_min_size = Vector2(0, 25)
	btn_appdata.size_flags_horizontal = SIZE_EXPAND_FILL
	_copy_button_style(btn_install, btn_appdata)
	btn_appdata.connect("pressed", self, "_on_BtnAppData_pressed")
	folder_hbox.add_child(btn_appdata)

	file_dialog = FileDialog.new()
	file_dialog.mode = FileDialog.MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.rect_min_size = Vector2(600, 400)
	file_dialog.connect("dir_selected", self, "_on_dir_selected")
	get_tree().current_scene.call_deferred("add_child", file_dialog)
	
	btn_change_path = Button.new()
	btn_change_path.text = "Change Install Location"
	btn_change_path.rect_min_size = Vector2(0, 25)
	_copy_button_style(btn_install, btn_change_path)
	btn_change_path.connect("pressed", self, "_on_BtnChangePath_pressed")
	add_child(btn_change_path)
	move_child(btn_change_path, folder_hbox.get_index() + 1)
	
	lbl_path_display = Label.new()
	lbl_path_display.align = Label.ALIGN_CENTER
	lbl_path_display.valign = Label.VALIGN_CENTER
	lbl_path_display.autowrap = true
	lbl_path_display.size_flags_horizontal = SIZE_FILL 
	lbl_path_display.rect_min_size = Vector2(100, 0)
	lbl_path_display.add_color_override("font_color", Color(0.5, 0.8, 0.8))
	if status_label.has_font_override("font"):
		lbl_path_display.add_font_override("font", status_label.get_font("font"))
	add_child(lbl_path_display)
	update_paths_and_label()

func _copy_button_style(source: Control, target: Control):
	var states = ["normal", "hover", "pressed", "disabled", "focus"]
	for state in states:
		if source.has_stylebox_override(state):
			target.add_stylebox_override(state, source.get_stylebox(state))
	if source.has_font_override("font"):
		target.add_font_override("font", source.get_font("font"))

func load_install_config():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	var default_docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).plus_file("LnzLive")
	
	if err == OK:
		install_dir = config.get_value("General", "install_path", default_docs)
	else:
		install_dir = default_docs

func save_install_config():
	var config = ConfigFile.new()
	config.set_value("General", "install_path", install_dir)
	config.save(SETTINGS_FILE)

func update_paths_and_label():
	version_file_path = install_dir.plus_file(VERSION_FILE_NAME)
	game_install_path = install_dir.plus_file(GAME_EXE_NAME) 
		
	if lbl_path_display:
		lbl_path_display.text = "Install Location:\n" + install_dir

func ensure_directory_exists():
	var dir = Directory.new()
	if not dir.dir_exists(install_dir):
		dir.make_dir_recursive(install_dir)

func _on_BtnChangePath_pressed():
	file_dialog.current_dir = install_dir
	file_dialog.popup_centered()

func _on_dir_selected(path):
	install_dir = path
	save_install_config()
	check_local_version()
	update_paths_and_label()
	check_launch_readiness()
	update_ui_state()

func check_launch_readiness():
	var file = File.new()
	if file.file_exists(game_install_path):
		btn_launch.disabled = false
		if status_label.text == "Checking local files...":
			status_label.text = "Ready!"
	else:
		btn_launch.disabled = true

func setup_http_requests():
	http_api = HTTPRequest.new()
	add_child(http_api)
	http_api.connect("request_completed", self, "_on_api_request_completed")
	
	http_download = HTTPRequest.new()
	add_child(http_download)
	http_download.connect("request_completed", self, "_on_download_request_completed")
	http_download.use_threads = true

func setup_version_selector():
	version_selector.clear()
	version_selector.add_item("Fetching releases...")
	version_selector.disabled = true
	version_selector.connect("item_selected", self, "_on_version_changed")

func _process(_delta):
	if http_download.get_http_client_status() == HTTPClient.STATUS_BODY:
		var downloaded = http_download.get_downloaded_bytes()
		var total = http_download.get_body_size()
		if total > 0:
			progress_bar.value = (float(downloaded) / float(total)) * 100
			status_label.text = "Downloading: %d%%" % int(progress_bar.value)

func check_local_version():
	var file = File.new()
	if file.file_exists(version_file_path):
		file.open(version_file_path, File.READ)
		var content = file.get_as_text().strip_edges()
		file.close()
		
		var json_res = JSON.parse(content)
		if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
			local_version = json_res.result.get("tag", "Unknown")
			local_asset_name = json_res.result.get("asset", "")
		else:
			local_version = content
			local_asset_name = ""
	else:
		local_version = "None"
		local_asset_name = ""
		
	update_paths_and_label()

func check_github_updates():
	var error = http_api.request(GITHUB_API_URL)
	if error != OK:
		status_label.text = "Error connecting to GitHub API."

func _on_api_request_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Failed to fetch updates."
		check_launch_readiness()
		return

	var json_result = JSON.parse(body.get_string_from_utf8())
	if json_result.error != OK:
		status_label.text = "Error parsing GitHub JSON."
		return
		
	if typeof(json_result.result) == TYPE_ARRAY:
		all_releases_data = []
		for release in json_result.result:
			if release.has("tag_name") and not release["tag_name"].begins_with("launcher"):
				all_releases_data.append(release)
		all_releases_data.sort_custom(self, "_sort_releases_desc")
		populate_version_list()
	else:
		status_label.text = "Unexpected API format."

func _sort_releases_desc(a, b):
	var ver_a = _parse_version_string(a["tag_name"])
	var ver_b = _parse_version_string(b["tag_name"])
	for i in range(3):
		if ver_a[i] > ver_b[i]: return true
		elif ver_a[i] < ver_b[i]: return false
	return a["published_at"] > b["published_at"]

func _parse_version_string(tag_string):
	var clean_tag = tag_string.to_lower()
	var numbers = []
	var current_num = ""
	var found_digit = false
	
	for i in range(clean_tag.length()):
		var char_code = clean_tag.ord_at(i)
		if char_code >= 48 and char_code <= 57:
			current_num += clean_tag[i]
			found_digit = true
		elif clean_tag[i] == "." and found_digit:
			if current_num != "":
				numbers.append(int(current_num))
				current_num = ""
		elif found_digit:
			break
			
	if current_num != "": numbers.append(int(current_num))
	while numbers.size() < 3: numbers.append(0)
	return numbers

func populate_version_list():
	version_selector.clear()
	version_selector.disabled = false
	
	if all_releases_data.size() == 0:
		version_selector.add_item("No releases found")
		version_selector.disabled = true
		return

	for release in all_releases_data:
		var item_text = release["tag_name"]
		if release.has("prerelease") and release["prerelease"]:
			item_text += " [Preview]"
		version_selector.add_item(item_text)
	
	update_target_from_selection()

func _on_version_changed(_index):
	update_target_from_selection()

func _markdown_to_bbcode(md_text: String) -> String:
	var bbcode = md_text.replace("\r", "")
	
	var patterns = [
		{"pattern": "(?m)^### (.*)$", "replace": "[b][u]$1[/u][/b]"},
		{"pattern": "(?m)^## (.*)$", "replace": "[b][u]$1[/u][/b]"},
		{"pattern": "(?m)^# (.*)$", "replace": "[b][u]$1[/u][/b]"},
		{"pattern": "\\[(.*?)\\]\\((.*?)\\)", "replace": "[url=$2]$1[/url]"},
		{"pattern": "\\*\\*(.*?)\\*\\*", "replace": "[b]$1[/b]"},
		{"pattern": "__(.*?)__", "replace": "[b]$1[/b]"},
		{"pattern": "\\b_(.*?)_\\b", "replace": "[i]$1[/i]"},
		{"pattern": "(?m)^[\\*\\-]\\s(.*)$", "replace": "  • $1"},
		{"pattern": "`([^`]+)`", "replace": "[code]$1[/code]"}
	]
	
	var regex = RegEx.new()
	for p in patterns:
		var err = regex.compile(p.pattern)
		if err == OK:
			bbcode = regex.sub(bbcode, p.replace, true)
			
	bbcode = bbcode.replace("```", "")
			
	return bbcode

func update_target_from_selection():
	var index = version_selector.selected
	if index < 0 or index >= all_releases_data.size(): return
		
	var selected_release = all_releases_data[index]
	target_remote_version = selected_release["tag_name"]
	
	if notes_text:
		var raw_notes = selected_release.get("body", "No release notes provided.")
		notes_text.bbcode_text = _markdown_to_bbcode(raw_notes)
	
	current_release_assets = []
	for asset in selected_release["assets"]:
		if asset["name"].ends_with(".exe"):
			current_release_assets.append(asset)
			
	executable_selector.clear()
	if current_release_assets.size() == 0:
		executable_selector.add_item("No executables found")
		executable_selector.disabled = true
		target_download_url = ""
		target_asset_name = ""
		update_ui_state()
		return

	executable_selector.disabled = false
	var best_index = 0
	var best_date = ""
	var found_stable = false

	for i in range(current_release_assets.size()):
		var asset = current_release_assets[i]
		executable_selector.add_item(asset["name"])
		var is_stable = "stable" in asset["name"].to_lower()
		
		if is_stable and not found_stable:
			best_index = i
			best_date = asset["updated_at"]
			found_stable = true
		elif is_stable and found_stable:
			if asset["updated_at"] > best_date:
				best_index = i
				best_date = asset["updated_at"]
		elif not found_stable:
			if best_date == "" or asset["updated_at"] > best_date:
				best_index = i
				best_date = asset["updated_at"]
				
	executable_selector.select(best_index)
	_on_executable_changed(best_index)

func _on_executable_changed(index):
	if index < 0 or index >= current_release_assets.size(): return
	var selected_asset = current_release_assets[index]
	target_download_url = selected_asset["browser_download_url"]
	target_asset_name = selected_asset["name"].get_file()
	update_ui_state()

func _on_BtnNotes_pressed():
	if notes_scroll and texture_rect:
		notes_scroll.visible = !notes_scroll.visible
		texture_rect.visible = !notes_scroll.visible
		btn_notes.text = "Hide Release Notes" if notes_scroll.visible else "See Release Notes"

func _on_BtnAppData_pressed():
	var base_user_dir = OS.get_user_data_dir().get_base_dir()
	var appdata_path = base_user_dir.plus_file("LnzLive")
	var dir = Directory.new()
	if not dir.dir_exists(appdata_path):
		dir.make_dir_recursive(appdata_path)
	OS.shell_open(appdata_path)

func update_ui_state():
	status_label.text = "Local: %s | Target: %s" % [local_version, target_remote_version]
	
	btn_launch.disabled = true
	btn_update.disabled = true
	btn_install.disabled = true
	btn_update.visible = false
	btn_install.visible = false
	
	var file_check = File.new()
	var game_exists = file_check.file_exists(game_install_path)
	
	if not game_exists or local_asset_name != target_asset_name:
		btn_install.disabled = false
		btn_install.visible = true
		btn_install.text = "Install " + target_asset_name
	elif local_version != target_remote_version:
		btn_update.text = "Update to " + target_remote_version 
		btn_update.disabled = false
		btn_update.visible = true
		btn_launch.disabled = false
	else:
		btn_launch.disabled = false
		status_label.text += " (Ready)"

func start_download():
	if target_download_url == "":
		status_label.text = "Error: No download URL for this version."
		return
		
	var dir = Directory.new()
	if not dir.dir_exists(install_dir):
		var err = dir.make_dir_recursive(install_dir)
		if err != OK:
			status_label.text = "Error: Cannot create install folder."
			return
			
	btn_launch.disabled = true 
	btn_update.disabled = true
	btn_install.disabled = true
	if btn_change_path: btn_change_path.disabled = true 
	version_selector.disabled = true
	executable_selector.disabled = true
	
	status_label.text = "Starting download..."
	progress_bar.value = 0
	
	var temp_path = install_dir.plus_file(TEMP_FILE_NAME)
	http_download.set_download_file(temp_path)
	
	var error = http_download.request(target_download_url)
	if error != OK:
		status_label.text = "Download request failed."
		version_selector.disabled = false
		executable_selector.disabled = false
		if btn_change_path: btn_change_path.disabled = false
		check_launch_readiness()

func _on_download_request_completed(result, response_code, _headers, _body):
	version_selector.disabled = false
	executable_selector.disabled = false
	if btn_change_path: btn_change_path.disabled = false
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Download failed! Code: %s" % str(response_code)
		update_ui_state()
		return
		
	status_label.text = "Finalizing..."
	progress_bar.value = 100
	
	var dir = Directory.new()
	var temp_path = install_dir.plus_file(TEMP_FILE_NAME)
	var backup_path = game_install_path + ".bak"
	
	var file_check = File.new()
	if not file_check.file_exists(temp_path):
		status_label.text = "Error: Downloaded file missing."
		return

	if dir.file_exists(game_install_path):
		var backup_err = dir.rename(game_install_path, backup_path)
		if backup_err != OK:
			status_label.text = "Error: Close game before updating!"
			dir.remove(temp_path)
			return
			
		var install_err = dir.rename(temp_path, game_install_path)
		if install_err != OK:
			status_label.text = "Update failed. Restoring..."
			dir.rename(backup_path, game_install_path) 
			return
		
		dir.remove(backup_path)
	else:
		var ren_err = dir.rename(temp_path, game_install_path)
		if ren_err != OK:
			status_label.text = "Error creating file."
			return
	
	var file = File.new()
	file.open(version_file_path, File.WRITE)
	
	var save_data = {
		"tag": target_remote_version,
		"asset": target_asset_name
	}
	file.store_string(to_json(save_data))
	file.close()
	
	local_version = target_remote_version
	local_asset_name = target_asset_name
	update_paths_and_label()
	update_ui_state()
	status_label.text = "Ready!"

func _on_BtnInstall_pressed():
	start_download()

func _on_BtnUpdate_pressed():
	start_download()

func _on_BtnLaunch_pressed():
	status_label.text = "Launching..."
	OS.execute(game_install_path, [], false)

func _on_BtnOpenFolder_pressed():
	var dir = Directory.new()
	if dir.dir_exists(install_dir):
		OS.shell_open(install_dir)
	else:
		status_label.text = "Error: Install directory not found!"

func disable_all_buttons():
	btn_launch.disabled = true
	btn_update.disabled = true
	btn_install.disabled = true
