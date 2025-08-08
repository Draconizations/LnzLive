# AxisOverlay.gd
# A screen‐space XYZ axis widget for LnzLive (Godot 3.x)

extends Node2D

# Path to the 3D camera whose orientation drives the widget
export(NodePath) var camera_path := "Root/SceneRoot/ViewportContainer/Viewport/CameraHolder/Camera"

# Length of each axis arrow in pixels
export(int) var axis_length := 40

# Thickness of the axis lines
export(int) var line_thickness := 2

# Distance in pixels to offset the axis label from the arrow tip
export(int) var axis_dir_offset := 8

# Margin from the bottom‐left corner of the viewport
export(Vector2) var margin := Vector2(10, 10)

# Font for drawing the “X”, “Y”, “Z” labels
export(Font) var font

const AXIS_COLORS = {
	"X": Color(1, 0, 0),
	"Y": Color(0, 1, 0),
	"Z": Color(0, 0, 1)
}

const AXIS_LABELS = {
	"X": "+X",
	"Y": "+Y",
	"Z": "+Z"
}

onready var camera = get_tree().root.get_node(camera_path) as Camera

func _ready():
	set_process(true)

func _process(delta):
	if camera and camera.is_inside_tree():
		update()

func _draw():
	if not camera:
		return

	# Invert camera basis to get world‐axis directions in view space
	var inv_basis = camera.global_transform.basis.inverse()
	var dirs = {
		"X": inv_basis.xform(Vector3(1, 0, 0)),
		"Y": inv_basis.xform(Vector3(0, 1, 0)),
		"Z": inv_basis.xform(Vector3(0, 0, 1))
	}

	# Compute the origin in screen‐space (bottom‐left corner + margin)
	var vp_size = get_viewport_rect().size
	var origin = Vector2(margin.x, vp_size.y - margin.y)

	# Draw each axis line and label
	for axis_dir in dirs.keys():
		var dir3 = dirs[axis_dir]

		# Project to 2D: X = right, Y = up (invert Y for screen coordinates)
		var dir2 = Vector2(dir3.x, -dir3.y).normalized() * axis_length
		var tip_pos = origin + dir2

		# Draw the line
		draw_line(origin, tip_pos, AXIS_COLORS[axis_dir], line_thickness)

		# Draw the axis label at the tip
		if font:
			draw_string(
				font,
				tip_pos + dir2.normalized() * axis_dir_offset,
				AXIS_LABELS[axis_dir],
				AXIS_COLORS[axis_dir]
			)
