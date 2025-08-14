extends CanvasLayer

signal apply_projections(projections, overwrite)
signal randomize_projections()
signal randomize_body_proportions(settings)

var held_projections = []
var body_part_groups = {}

onready var stationary_options = find_node("StationaryOptionButton")
onready var projected_options = find_node("ProjectedOptionButton")
onready var amount_spinbox = find_node("AmountSpinBox")
onready var projections_tree = find_node("ProjectionsTree")
onready var panel = $Panel

func _ready():
	# Connect signals
	find_node("AddButton").connect("pressed", self, "_on_AddButton_pressed")
	find_node("RandomizeProjectionsButton").connect("pressed", self, "_on_RandomizeProjectionsButton_pressed")
	find_node("RandomizeBodyButton").connect("pressed", self, "_on_RandomizeBodyButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")

	# Setup Tree
	projections_tree.set_column_titles_visible(true)
	projections_tree.set_column_title(0, "Stationary")
	projections_tree.set_column_title(1, "Projected")
	projections_tree.set_column_title(2, "Amount")

	# Initial population of dropdowns
	_populate_body_part_options()

	# Hide by default
	hide()

func _populate_body_part_options():
	stationary_options.clear()
	projected_options.clear()
	body_part_groups.clear()

	# This is a simplified representation. A more robust solution would handle species changes.
	# For now, we assume one species throughout the session.
	var species = KeyBallsData.species

	if species == KeyBallsData.Species.DOG:
		body_part_groups["Front Legs"] = KeyBallsData.legs_dog[0]
		body_part_groups["Back Legs"] = KeyBallsData.legs_dog[1]
		body_part_groups["Head"] = KeyBallsData.head_ext_dog
		body_part_groups["Body"] = KeyBallsData.body_ext_dog
		body_part_groups["Tail"] = KeyBallsData.tail_dog
		body_part_groups["Face"] = KeyBallsData.face_ext_dog
	elif species == KeyBallsData.Species.CAT:
		body_part_groups["Front Legs"] = KeyBallsData.legs_cat[0]
		body_part_groups["Back Legs"] = KeyBallsData.legs_cat[1]
		body_part_groups["Head"] = KeyBallsData.head_ext_cat
		body_part_groups["Body"] = KeyBallsData.body_ext_cat
		body_part_groups["Tail"] = KeyBallsData.tail_cat
		body_part_groups["Face"] = KeyBallsData.face_ext_cat
	# Add BABY species when data is available

	for part_name in body_part_groups:
		stationary_options.add_item(part_name)
		projected_options.add_item(part_name)

func _on_AddButton_pressed():
	var stationary_idx = stationary_options.selected
	var projected_idx = projected_options.selected

	if stationary_idx == -1 or projected_idx == -1:
		print("Please select both a stationary and a projected group.")
		return

	var stationary_group_name = stationary_options.get_item_text(stationary_idx)
	var projected_group_name = projected_options.get_item_text(projected_idx)

	var stationary_balls = body_part_groups[stationary_group_name]
	var projected_balls = body_part_groups[projected_group_name]

	if stationary_balls.empty() or projected_balls.empty():
		print("One of the selected groups is empty.")
		return

	randomize()
	var stationary_ball = stationary_balls[randi() % stationary_balls.size()]
	var projected_ball = projected_balls[randi() % projected_balls.size()]
	var amount = amount_spinbox.value

	var new_projection = {
		"stationary": stationary_ball,
		"projected": projected_ball,
		"amount": amount
	}

	held_projections.append(new_projection)
	_update_tree()

func _on_RandomizeProjectionsButton_pressed():
	emit_signal("randomize_projections")

func _on_RandomizeBodyButton_pressed():
	var settings = {
		"leg_ext_1": { "min": find_node("LegExt1MinSpinBox").value, "max": find_node("LegExt1MaxSpinBox").value },
		"leg_ext_2": { "min": find_node("LegExt2MinSpinBox").value, "max": find_node("LegExt2MaxSpinBox").value },
		"head_enl_1": { "min": find_node("HeadEnl1MinSpinBox").value, "max": find_node("HeadEnl1MaxSpinBox").value },
		"head_enl_2": { "min": find_node("HeadEnl2MinSpinBox").value, "max": find_node("HeadEnl2MaxSpinBox").value },
		"feet_enl_1": { "min": find_node("FeetEnl1MinSpinBox").value, "max": find_node("FeetEnl1MaxSpinBox").value },
		"feet_enl_2": { "min": find_node("FeetEnl2MinSpinBox").value, "max": find_node("FeetEnl2MaxSpinBox").value },
		"scales_1": { "min": find_node("Scales1MinSpinBox").value, "max": find_node("Scales1MaxSpinBox").value },
		"scales_2": { "min": find_node("Scales2MinSpinBox").value, "max": find_node("Scales2MaxSpinBox").value },
		"body_ext": { "min": find_node("BodyExtMinSpinBox").value, "max": find_node("BodyExtMaxSpinBox").value },
		"face_ext": { "min": find_node("FaceExtMinSpinBox").value, "max": find_node("FaceExtMaxSpinBox").value },
		"ear_ext": { "min": find_node("EarExtMinSpinBox").value, "max": find_node("EarExtMaxSpinBox").value }
	}
	emit_signal("randomize_body_proportions", settings)

func _on_ApplyButton_pressed():
	# Always overwrite the section, as per user feedback to simplify the UI.
	emit_signal("apply_projections", held_projections, true)
	held_projections.clear()
	_update_tree()

func _update_tree():
	projections_tree.clear()
	var root = projections_tree.create_item()
	for proj in held_projections:
		var item = projections_tree.create_item(root)
		item.set_text(0, str(proj.stationary))
		item.set_text(1, str(proj.projected))
		item.set_text(2, str(proj.amount))

func set_held_projections(projections_array):
	held_projections = projections_array
	_update_tree()

func show():
	# Re-populate options in case species has changed since _ready()
	_populate_body_part_options()
	panel.show()

func hide():
	panel.hide()
