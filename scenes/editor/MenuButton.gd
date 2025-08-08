extends LinkButton

func _ready():
	connect("pressed", self, "_on_GuideLinkButton_pressed")
	connect("pressed", self, "_on_CarolynHornLinkButton_pressed")

func _on_GuideLinkButton_pressed():
	OS.shell_open("https://github.com/tabbzi/LnzLive/blob/master/GUIDE.md")
	
func _on_CarolynHornLinkButton_pressed():
	OS.shell_open("https://github.com/melissamcewen/carolyns-bible")

func _on_HelpPopupButton_pressed():
	print("blash")
