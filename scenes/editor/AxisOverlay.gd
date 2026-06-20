extends Node2D
## AxisOverlay.gd
## Shows screen‐space XYZ and L/R axis widget

## Exported NodePaths for configuration
var panel_path: NodePath = "Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/HelperContainer/AxisContainer"
var camera_path: NodePath = "Root/SceneRoot/ViewportContainer/Viewport/CameraHolder/Camera"

## Exported configuration properties
var axis_length: int = 40
var line_thickness: int = 2
var axis_dir_offset: int = 8
var margin: Vector2 = Vector2(30, 30)
var font: Font = null

## Constants for axis styling
const AXIS_COLORS: Dictionary = {
	"X": Color(1, 0, 0),
	"Y": Color(0, 1, 0),
	"Z": Color(0, 0, 1)
}
const AXIS_LABELS: Dictionary = {
	"X": "+X",
	"Y": "-Y",
	"Z": "+Z"
}

## Instance variables for cached nodes
var panel: Control = null
var camera: Camera = null

func _ready() -> void:
	# Cache node references to avoid repeated tree traversal
	panel = get_tree().root.get_node(panel_path) as Control
	camera = get_tree().root.get_node(camera_path) as Camera
	set_process(true)

func _process(delta: float) -> void:
	# Check validity of cached nodes before updating
	if camera and camera.is_inside_tree() and panel:
		update()

func _draw() -> void:
	# Early exit if required nodes are not available
	if not camera or not panel:
		return

	var pg: Vector2 = panel.rect_global_position
	var ps: Vector2 = panel.rect_size
	
	# Calculate container positioning
	var container_anchor_point: Vector2 = Vector2(margin.x, ps.y - margin.y)
	var container_center_point: Vector2 = Vector2(ps.x * 0.5, ps.y * 0.5)
	
	# Determine origin point for axis drawing
	# Using center point logic as per original implementation
	var origin: Vector2 = container_center_point - self.position
	
	# Calculate inverse basis to transform world directions to screen space
	var inv_basis: Basis = camera.global_transform.basis.inverse()
	
	# Temporary dictionary to store direction vectors
	var dirs: Dictionary = {
		"X": inv_basis.xform(Vector3(1, 0, 0)),
		"Y": inv_basis.xform(Vector3(0, 1, 0)),
		"Z": inv_basis.xform(Vector3(0, 0, 1))
	}

	# Draw main axes
	for axis in ["X","Y","Z"]:
		var d3: Vector3 = dirs[axis]
		# Transform 3D direction to 2D screen space
		var d2: Vector2 = Vector2(-d3.x, -d3.y).normalized() * axis_length
		var tip: Vector2 = origin + d2

		# Clamp tip position to panel bounds
		var tip_clamped: Vector2 = Vector2(
			clamp(tip.x, 0, ps.x - self.position.x),
			clamp(tip.y, 0, ps.y - self.position.y)
		)
		
		# Draw the axis line
		draw_line(origin, tip_clamped, AXIS_COLORS[axis], line_thickness)

		# Draw axis label if font is available
		if font:
			var lbl_pos: Vector2 = tip + d2.normalized() * axis_dir_offset
			draw_string(font, lbl_pos, AXIS_LABELS[axis], AXIS_COLORS[axis])

	# Draw additional indicators for X and Y axes
	if font:
		# +X Indicator ("L")
		var d3p: Vector3 = dirs["X"]
		var d2p: Vector2 = Vector2(-d3p.x, -d3p.y).normalized() * axis_length
		var tip_p: Vector2 = origin + d2p
		var tip_p_clamped: Vector2 = Vector2(
			clamp(tip_p.x, 0, ps.x - self.position.x),
			clamp(tip_p.y, 0, ps.y - self.position.y)
		)
		
		# Calculate perpendicular vector for offset
		var perp: Vector2 = Vector2(-d2p.y, d2p.x).normalized()
		draw_string(font, tip_p_clamped + perp * 22, "L", Color(1, 1, 1))

		# -X Indicator ("R")
		var d3n: Vector3 = -d3p
		var d2n: Vector2 = Vector2(-d3n.x, -d3n.y).normalized() * axis_length
		var tip_n: Vector2 = origin + d2n
		var tip_n_clamped: Vector2 = Vector2(
			clamp(tip_n.x, 0, ps.x - self.position.x),
			clamp(tip_n.y, 0, ps.y - self.position.y)
		)
		draw_string(font, tip_n_clamped + perp * 22, "R", Color(1, 1, 1))

		# -Y Connector logic (commented out in original, but kept for structure if needed)
		# var d3y: Vector3 = dirs["Y"]
		# var d2y: Vector2 = Vector2(d3y.x, -d3y.y).normalized() * axis_length
		# var tip_y: Vector2 = origin - d2y
		# var tip_y_clamped: Vector2 = Vector2(
		# 	clamp(tip_y.x, 0, ps.x - self.position.x),
		# 	clamp(tip_y.y, 0, ps.y - self.position.y)
		# )
		# var conn_end: Vector2 = tip_y_clamped - d2y.normalized() * axis_dir_offset
		# draw_line(tip_y_clamped, conn_end, Color(1, 1, 1), line_thickness)

	# Clean up temporary dictionary reference if it were stored in a pool, 
	# though local vars are GC'd. Explicitly clearing if it were an array/dict pool:
	dirs.clear()
