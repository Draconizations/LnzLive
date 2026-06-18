extends Node2D

# AxisOverlay.gd - screen‐space XYZ axis widget for LnzLive

#export(NodePath) var panel_path  := "Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer"
export(NodePath) var panel_path  := "Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/HelperContainer/AxisContainer"
export(NodePath) var camera_path := "Root/SceneRoot/ViewportContainer/Viewport/CameraHolder/Camera"

export(int)	 var axis_length	 := 40
export(int)	 var line_thickness  := 2
export(int)	 var axis_dir_offset := 8
export(Vector2) var margin		  := Vector2(30, 30)
export(Font)	var font

const AXIS_COLORS = {
	"X": Color(1, 0, 0),
	"Y": Color(0, 1, 0),
	"Z": Color(0, 0, 1)
}
const AXIS_LABELS = {
	"X": "+X",
	"Y": "-Y",
	"Z": "+Z"
}

onready var panel  = get_tree().root.get_node(panel_path)  as Control
onready var camera = get_tree().root.get_node(camera_path) as Camera

func _ready():
	set_process(true)

func _process(delta):
	if camera and camera.is_inside_tree() and panel:
		update()

func _draw():
	if not camera or not panel:
		return

	var pg = panel.rect_global_position
	var ps = panel.rect_size
	var container_anchor_point = Vector2(margin.x, ps.y - margin.y)
	var container_center_point = Vector2(ps.x * 0.5, ps.y * 0.5)
	#var origin = container_anchor_point - self.position
	var origin = container_center_point - self.position
	#var origin = pg + Vector2(ps.x * 0.5 + margin.x, ps.y - margin.y)

	var inv_basis = camera.global_transform.basis.inverse()
	var dirs = {
		"X": inv_basis.xform(Vector3(1, 0, 0)),
		"Y": inv_basis.xform(Vector3(0, 1, 0)),
		"Z": inv_basis.xform(Vector3(0, 0, 1))
	}

	for axis in ["X","Y","Z"]:
		var d3 = dirs[axis]
		#var d2 = Vector2(d3.x, -d3.y).normalized() * axis_length
		var d2 = Vector2(-d3.x, -d3.y).normalized() * axis_length
		var tip = origin + d2

		var tip_clamped = Vector2(
			clamp(tip.x, 0, ps.x - self.position.x),
			clamp(tip.y, 0, ps.y - self.position.y)
		)
		draw_line(origin, tip_clamped, AXIS_COLORS[axis], line_thickness)

		if font:
			var lbl_pos = tip + d2.normalized() * axis_dir_offset
			draw_string(font, lbl_pos, AXIS_LABELS[axis], AXIS_COLORS[axis])

		if font:
			# +X = "L"
			var d3p = dirs["X"]
			#var d2p = Vector2(d3p.x, -d3p.y).normalized() * axis_length
			var d2p = Vector2(-d3p.x, -d3p.y).normalized() * axis_length
			var tip_p = origin + d2p
			var tip_p_clamped = Vector2(
				clamp(tip_p.x, 0, ps.x - self.position.x),
				clamp(tip_p.y, 0, ps.y - self.position.y)
			)
			# offset perpendicular so it floats beside the arrow
			#var perp = Vector2(d2p.y, -d2p.x).normalized()
			var perp = Vector2(-d2p.y, d2p.x).normalized()
			draw_string(font, tip_p_clamped + perp * 22, "L", Color(1,1,1))

			# -X = "R"
			var d3n = -d3p
			#var d2n = Vector2(d3n.x, -d3n.y).normalized() * axis_length
			var d2n = Vector2(-d3n.x, -d3n.y).normalized() * axis_length
			var tip_n = origin + d2n
			var tip_n_clamped = Vector2(
				clamp(tip_n.x, 0, ps.x - self.position.x),
				clamp(tip_n.y, 0, ps.y - self.position.y)
			)
			draw_string(font, tip_n_clamped + perp * 22, "R", Color(1,1,1))

			# -Y connector under the green +Y
			var d3y = dirs["Y"]
			var d2y = Vector2(d3y.x, -d3y.y).normalized() * axis_length
			var tip_y = origin - d2y
			var tip_y_clamped = Vector2(
				clamp(tip_y.x, 0, ps.x - self.position.x),
				clamp(tip_y.y, 0, ps.y - self.position.y)
			)
			var conn_end = tip_y_clamped - d2y.normalized() * axis_dir_offset
			#draw_line(tip_y_clamped, conn_end, Color(1,1,1), line_thickness)
