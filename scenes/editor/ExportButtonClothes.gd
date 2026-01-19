extends Button

func _ready():
	connect("pressed", self, "_on_pressed")

func _on_pressed():
	var export_dialog = get_tree().root.get_node("Root/SceneRoot/ExportClothes")
	export_dialog.open()
