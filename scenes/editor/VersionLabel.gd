extends Label

func _ready():
    var version = get_version_from_presets()
    if version:
        text = str(version)
    else:
        text = "unknown version"

func get_version_from_presets():
    var config = ConfigFile.new()
    var err = config.load("res://export_presets.cfg")
    
    if err == OK:
        var val = config.get_value("preset.1.options", "application/file_version", null)
        return val
    else:
        print("Error: Could not open export_presets.cfg (Code: ", err, ")")
        return null