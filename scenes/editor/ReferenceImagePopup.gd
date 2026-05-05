extends WindowDialog

onready var texture_rect = $TextureRect

var programmatic_hide = false

func _ready():
	window_title = "Reference Image Viewer"
	rect_min_size = Vector2(200, 200)
	texture_rect.expand = true
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	connect("popup_hide", self, "_on_popup_hide")

func _on_popup_hide():
	if programmatic_hide:
		programmatic_hide = false
		return
		
	var config_path = "user://settings.cfg"
	var config = ConfigFile.new()
	config.load(config_path)
	config.set_value("ReferenceImage", "show_popup", false)
	config.save(config_path)

	var settings = get_tree().root.find_node("ReferenceImageSettings", true, false)
	if settings:
		settings.show_popup_checkbox.pressed = false

func _on_reference_image_updated(config_data):
	if not texture_rect:
		texture_rect = $TextureRect

	if config_data.path != "" and config_data.show_popup:
		var image = Image.new()
		var err = image.load(config_data.path, false, false)
		if err == OK:
			var tex = ImageTexture.new()
			tex.create_from_image(image)
			texture_rect.texture = tex

			var target_size = image.get_size()
			if target_size.x > 800 or target_size.y > 600:
				var aspect = target_size.x / target_size.y
				if aspect > 1.33:
					target_size = Vector2(800, 800 / aspect)
				else:
					target_size = Vector2(600 * aspect, 600)

			rect_size = target_size
			if not visible:
				show()
				var viewport_size = get_viewport().size
				rect_position = (viewport_size - rect_size) / 2.0
		else:
			texture_rect.texture = null
			hide()
	else:
		texture_rect.texture = null
		programmatic_hide = true
		hide()

func _on_ToggleRefImageBtn_pressed():
	var ref_settings = get_tree().root.find_node("ReferenceImageSettings", true, false)
	if ref_settings:
		ref_settings.toggle_reference_image()
