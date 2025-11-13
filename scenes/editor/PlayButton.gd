extends Button
## PlayButton.gd
## Manages a Button used to start and stop animation playback
## 1. Acts as a toggle switch for controlling the animation Timer node
## 2. Starts the $Timer when the button is pressed (toggled on)
## 3. Stops the $Timer when the button is released (toggled off)

func _on_Button_toggled(button_pressed):
	if button_pressed:
		$Timer.start()
	else:
		$Timer.stop()
