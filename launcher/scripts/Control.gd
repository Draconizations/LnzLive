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

var btn_change_path
var lbl_path_display
var file_dialog

var http_api
var http_download
var local_version = ""
var target_remote_version = ""
var target_download_url = ""
var install_dir = "" 
var game_install_path = "" 
var version_file_path = "" 
var all_releases_data = [] 

func _ready():
	setup_dynamic_ui()
	load_install_config()
	ensure_directory_exists()
	
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
	file_dialog = FileDialog.new()
	file_dialog.mode = FileDialog.MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.rect_min_size = Vector2(600, 400)
	file_dialog.connect("dir_selected", self, "_on_dir_selected")
	get_tree().current_scene.call_deferred("add_child", file_dialog)
	
	btn_change_path = Button.new()
	btn_change_path.text = "Change Install Location"
	btn_change_path.rect_min_size = Vector2(0, 25)
	
	btn_change_path.add_stylebox_override("normal", btn_install.get_stylebox("normal"))
	btn_change_path.add_stylebox_override("hover", btn_install.get_stylebox("hover"))
	btn_change_path.add_stylebox_override("pressed", btn_install.get_stylebox("pressed"))
	btn_change_path.add_stylebox_override("focus", btn_install.get_stylebox("focus"))
	btn_change_path.add_font_override("font", btn_install.get_font("font"))
	
	btn_change_path.connect("pressed", self, "_on_BtnChangePath_pressed")
	
	var open_folder_pos = btn_open_folder.get_position_in_parent()
	add_child_below_node(btn_open_folder, btn_change_path)
	move_child(btn_change_path, open_folder_pos)
	
	lbl_path_display = Label.new()
	lbl_path_display.align = Label.ALIGN_CENTER
	lbl_path_display.valign = Label.VALIGN_CENTER
	lbl_path_display.autowrap = true
	
	lbl_path_display.size_flags_horizontal = SIZE_FILL # Fill available space, don't expand it
	lbl_path_display.rect_min_size = Vector2(100, 0) # Allow it to shrink if needed
	
	lbl_path_display.add_color_override("font_color", Color(0.5, 0.8, 0.8))
	if status_label.has_font_override("font"):
		lbl_path_display.add_font_override("font", status_label.get_font("font"))
		
	add_child(lbl_path_display)

func load_install_config():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	var default_docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).plus_file("LnzLive")
	
	if err == OK:
		install_dir = config.get_value("General", "install_path", default_docs)
	else:
		var dir = Directory.new()
		if dir.dir_exists(default_docs):
			install_dir = default_docs
		else:
			install_dir = default_docs
	
	update_paths_and_label()

func save_install_config():
	var config = ConfigFile.new()
	config.set_value("General", "install_path", install_dir)
	config.save(SETTINGS_FILE)

func update_paths_and_label():
	game_install_path = install_dir.plus_file(GAME_EXE_NAME)
	version_file_path = install_dir.plus_file(VERSION_FILE_NAME)
	lbl_path_display.text = "Install Location:\n" + install_dir
	print("Install path set to: ", install_dir)

func ensure_directory_exists():
	var dir = Directory.new()
	if not dir.dir_exists(install_dir):
		var docs_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if install_dir.begins_with(docs_path):
			dir.make_dir_recursive(install_dir)

func _on_BtnChangePath_pressed():
	file_dialog.current_dir = install_dir
	file_dialog.popup_centered()

func _on_dir_selected(path):
	install_dir = path
	save_install_config()
	update_paths_and_label()
	
	check_local_version()
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
	
	if not version_selector.is_connected("item_selected", self, "_on_version_changed"):
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
		local_version = file.get_as_text().strip_edges()
		file.close()
	else:
		local_version = "None"

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
		if ver_a[i] > ver_b[i]:
			return true
		elif ver_a[i] < ver_b[i]:
			return false

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
	
	if current_num != "":
		numbers.append(int(current_num))
	
	while numbers.size() < 3:
		numbers.append(0)
		
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

func update_target_from_selection():
	var index = version_selector.selected
	if index < 0 or index >= all_releases_data.size():
		return
		
	var selected_release = all_releases_data[index]
	target_remote_version = selected_release["tag_name"]
	target_download_url = ""
	
	var assets = selected_release["assets"]
	var latest_asset = null

	for asset in assets:
		if not asset["name"].ends_with(".exe"):
			continue
		
		if latest_asset == null:
			latest_asset = asset
			continue
			
		if asset["updated_at"] > latest_asset["updated_at"]:
			latest_asset = asset
	
	if latest_asset:
		target_download_url = latest_asset["browser_download_url"]
		print("Selected Asset: ", latest_asset["name"], " | Updated: ", latest_asset["updated_at"])
	
	update_ui_state()


func update_ui_state():
	status_label.text = "Local: %s | Target: %s" % [local_version, target_remote_version]
	
	var file_check = File.new()
	var game_exists = file_check.file_exists(game_install_path)
	
	btn_launch.disabled = true
	btn_update.disabled = true
	btn_install.disabled = true
	btn_update.visible = false
	btn_install.visible = false
	
	if not game_exists:
		btn_install.disabled = false
		btn_install.visible = true
	elif local_version != target_remote_version:
		btn_update.text = "Install " + target_remote_version
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
	btn_change_path.disabled = true 
	
	version_selector.disabled = true
	status_label.text = "Starting download..."
	progress_bar.value = 0
	
	var temp_path = install_dir.plus_file(TEMP_FILE_NAME)
	http_download.set_download_file(temp_path)
	
	var error = http_download.request(target_download_url)
	if error != OK:
		status_label.text = "Download request failed."
		version_selector.disabled = false
		btn_change_path.disabled = false
		check_launch_readiness()

func _on_download_request_completed(result, response_code, _headers, _body):
	version_selector.disabled = false
	btn_change_path.disabled = false
	
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
	file.store_string(target_remote_version)
	file.close()
	
	local_version = target_remote_version
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