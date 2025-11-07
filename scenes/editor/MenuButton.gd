extends LinkButton

export var url: String = ""

func _ready():
	connect("pressed", self, "_on_pressed")

func _on_pressed():
	if not url.empty():
		OS.shell_open(url)