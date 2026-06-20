extends Button
## ExportButtonClothes.gd
## Button to trigger the export clothes dialog

func _ready() -> void:
	connect("pressed", self, "_on_pressed")

func _on_pressed() -> void:
	var export_dialog: Control = get_tree().root.get_node("Root/SceneRoot/ExportClothes")
	if export_dialog:
		export_dialog.open()
