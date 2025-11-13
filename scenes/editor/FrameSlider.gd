extends HSlider
## FrameSlider.gd
## Manages an HSlider that controls the current frame of the loaded animation
## 1. Updates the slider's maximum value when a new animation is loaded via _on_animation_loaded(num_of_frames)
## 2. Handles advancing the frame during playback by incrementing the slider value when the Timer times out
## 3. Automatically loops the animation back to frame 0 when the maximum frame is reached

func _on_animation_loaded(num_of_frames):
	max_value = num_of_frames - 1

func _on_Timer_timeout():
	if value == max_value:
		value = 0
	else:
		value += 1
		
