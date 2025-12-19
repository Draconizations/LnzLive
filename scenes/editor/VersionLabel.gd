extends Label

func _ready():
	var version = ProjectSettings.get_setting("application/config/file_version")
	if version:
		text = "v" + str(version)
	else:
		text = "v?.?.?"
