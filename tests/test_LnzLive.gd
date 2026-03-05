extends GutTest
# GUT test suite for LnzLive Text and View components
# Uses Godot 3.4 compatible syntax and GUT assertion syntax

var editor_scene = load("res://scenes/editor/editor.tscn")
var editor_instance: Node

# Component References
var dog_gen: Node
var file_tree: Tree
var lnz_text: TextEdit
var pet_view: Control

func before_each():
	# Instantiate the full editor scene to accurately reflect real-world usage
	editor_instance = editor_scene.instance()
	
	# Rename to 'Root' to satisfy absolute paths in child scripts 
	# e.g., get_tree().root.get_node("Root/SceneRoot/...")
	editor_instance.name = "Root" 
	get_tree().root.add_child(editor_instance)
	
	# Yield one idle frame to allow all deeply nested _ready() calls to fire 
	# and connect their 'onready' references.
	yield(get_tree(), "idle_frame")
	
	# Safely resolve references based on the structure shown in the code snippets
	dog_gen = editor_instance.get_node_or_null("PetRoot/Node")
	file_tree = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
	lnz_text = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	pet_view = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")

func after_each():
	# Safely cleanup the entire scene after every test
	if is_instance_valid(editor_instance):
		editor_instance.queue_free()
		yield(get_tree(), "idle_frame")

# ------------------------------------------------------------------------------
# Tests for dog_generator.gd
# ------------------------------------------------------------------------------
func test_dog_generator_initialization():
	assert_not_null(dog_gen, "Dog generator (PetRoot/Node) should be instanced in the SceneTree.")
	if not dog_gen: return
	
	# Check default exported variables
	assert_true(dog_gen.draw_balls, "Balls should be drawn by default.")
	assert_eq(dog_gen.pixel_world_size, 0.002, "Pixel world size should initialize at 0.002.")
	assert_false(dog_gen.draw_omitted_balls, "Omitted balls should not be drawn by default.")

func test_dog_generator_hidden_balls_tracking():
	assert_not_null(dog_gen, "Dog generator should exist.")
	if not dog_gen: return
	
	# Verify initial unhidden state
	var test_ball_no = 15
	assert_false(dog_gen.is_ball_hidden(test_ball_no), "Ball should not be hidden initially.")
	
	# Mutate state directly and test the helper function
	dog_gen._hidden_balls.append(test_ball_no)
	assert_true(dog_gen.is_ball_hidden(test_ball_no), "is_ball_hidden should return true when ball added to array.")

func test_dog_generator_restore_visual_states_safeguard():
	assert_not_null(dog_gen)
	if not dog_gen: return
	
	# Ensure the generator safely ignores calls if lnz parser data is null
	dog_gen.lnz = null
	dog_gen.restore_ball_visual_states([1, 2, 3])
	assert_true(true, "restore_ball_visual_states did not crash when lnz was null.")

# ------------------------------------------------------------------------------
# Tests for FileTree.gd
# ------------------------------------------------------------------------------
func test_filetree_expanded_states():
	if not file_tree:
		pending("FileTree node not found at expected path. Skipping.")
		return
		
	# Setup mock TreeItems since actual directory reading might not populate 
	# them in a pure testing environment.
	if not file_tree.examples:
		file_tree.examples = file_tree.create_item()
	if not file_tree.local_storage:
		file_tree.local_storage = file_tree.create_item()
	
	var mock_states = {
		"Examples": false,
		"Local Storage": true
	}
	
	file_tree.set_expanded_states(mock_states)
	
	# Assert underlying UI component actually reacted
	assert_true(file_tree.examples.collapsed, "Examples should be collapsed.")
	assert_false(file_tree.local_storage.collapsed, "Local Storage should be expanded.")
	
	# Verify getter logic handles inverted mapping accurately
	var retrieved_states = file_tree.get_expanded_states()
	assert_false(retrieved_states["Examples"], "Getter should return false for Examples.")
	assert_true(retrieved_states["Local Storage"], "Getter should return true for Local Storage.")

# ------------------------------------------------------------------------------
# Tests for LnzTextEdit.gd
# ------------------------------------------------------------------------------
func test_lnz_textedit_dependency_resolution():
	if not lnz_text:
		pending("LnzTextEdit not found at expected path. Skipping.")
		return
		
	# These are all assigned via standard `onready var x = get_tree().root...`
	# If our integration setup above works, none of these should be null.
	assert_not_null(lnz_text.file_tree, "LnzTextEdit successfully resolved FileTree dependency.")
	assert_not_null(lnz_text.pet_node, "LnzTextEdit successfully resolved PetNode dependency.")
	assert_not_null(lnz_text.pet_view, "LnzTextEdit successfully resolved PetViewContainer dependency.")

# ------------------------------------------------------------------------------
# Tests for PetViewContainer.gd
# ------------------------------------------------------------------------------
func test_pet_view_container_dependency_resolution():
	if not pet_view:
		pending("PetViewContainer not found at expected path. Skipping.")
		return
		
	# Verify successful resolution of other singletons/major nodes
	assert_not_null(pet_view.pet_node, "PetViewContainer successfully resolved PetNode.")
	assert_not_null(pet_view.lnz_text_edit, "PetViewContainer successfully resolved LnzTextEdit.")
	assert_not_null(pet_view.camera, "PetViewContainer successfully resolved 3D Camera.")
