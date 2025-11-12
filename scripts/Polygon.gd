extends Spatial
## Polygon.gd
## Represents polygonz connecting four ballz
## This script manages the visual properties of a polygon from parsed LNZ document data
## The polygon is rendered as a simple quad mesh dynamically positioned and oriented
## in the shader based on the world positions of the four connected ballz

export var fuzz_amount            = 0                  setget set_fuzz_amount
export var color_index            = 0                  setget set_color_index
export var l_edge_color           = 0                  setget set_l_edge_color
export var r_edge_color           = 0                  setget set_r_edge_color
export var ball_world_pos1        = Vector3.ZERO       setget set_ball_world_pos1
export var ball_world_pos2        = Vector3.ZERO       setget set_ball_world_pos2
export var ball_world_pos3        = Vector3.ZERO       setget set_ball_world_pos3
export var ball_world_pos4        = Vector3.ZERO       setget set_ball_world_pos4

export var texture: Texture                            setget set_texture
export var texture_size           = Vector2(256, 256)  setget set_texture_size
export var texture_size_raw       = Vector2.ZERO
export var transparent_color      = 0                  setget set_transparent_color

export var species                = 0                  setget set_species

export var palette                = preload("res://resources/textures/petzpalette.png") setget set_palette
const DEFAULT_PALETTE             = preload("res://resources/textures/petzpalette.png")
const BABYZ_PALETTE               = preload("res://resources/palettes/babyz_palette.png")

export var petz_palette           = DEFAULT_PALETTE

func _ready():
	# Pass the original texture to the shader
	set_texture(texture)

	# Pass the default Petz palette to the shader
	$MeshInstance.material_override.set_shader_param("petz_palette", DEFAULT_PALETTE)

func update_palette_after_added(new_palette):
	call_deferred("set_palette", new_palette)
	#set_deferred("material_override", $MeshInstance.material_override.duplicate())
	#set_palette(new_palette)

func set_fuzz_amount(new_value):
	fuzz_amount = new_value
	$MeshInstance.material_override.set_shader_param("fuzz_amount", new_value)

func set_r_edge_color(new_value):
	r_edge_color = new_value
	$MeshInstance.material_override.set_shader_param("r_edge_color", new_value)

func set_l_edge_color(new_value): # Corrected function name
	l_edge_color = new_value
	$MeshInstance.material_override.set_shader_param("l_edge_color", new_value)

func set_ball_world_pos1(new_value):
	ball_world_pos1 = new_value
	$MeshInstance.material_override.set_shader_param("ball_world_pos1", new_value)

func set_ball_world_pos2(new_value):
	ball_world_pos2 = new_value
	$MeshInstance.material_override.set_shader_param("ball_world_pos2", new_value)

func set_ball_world_pos3(new_value):
	ball_world_pos3 = new_value
	$MeshInstance.material_override.set_shader_param("ball_world_pos3", new_value)

func set_ball_world_pos4(new_value):
	ball_world_pos4 = new_value
	$MeshInstance.material_override.set_shader_param("ball_world_pos4", new_value)

func set_color_index(new_value):
	color_index = new_value
	$MeshInstance.material_override.set_shader_param("color_index", new_value)

func set_texture_size(new_value):
	texture_size = new_value

func set_texture(new_value):
	texture = new_value
	
	if $MeshInstance.material_override != null:
		$MeshInstance.material_override.set_shader_param("polygon_texture", new_value)
		if new_value != null:
			var raw_texture_size = new_value.get_size()
			var eff_texture_size = texture_size if texture_size != Vector2.ZERO else raw_texture_size

			# print("Declared size from [Texture List]:", texture_size)
			# print("Actual image size:", raw_texture_size)
			# print("Effective texture_size passed to shader:", eff_texture_size)
			# print("Texture resized? ", eff_texture_size != raw_texture_size)
			
			$MeshInstance.material_override.set_shader_param("texture_size", eff_texture_size)
			$MeshInstance.material_override.set_shader_param("texture_size_raw", raw_texture_size)
			$MeshInstance.material_override.set_shader_param("has_texture", true)
		else:
			$MeshInstance.material_override.set_shader_param("has_texture", false)

func set_palette(new_value):
	if new_value != null:
		palette = new_value
		$MeshInstance.material_override.set_shader_param("palette", new_value)
	else:
		palette = DEFAULT_PALETTE
		$MeshInstance.material_override.set_shader_param("palette", DEFAULT_PALETTE)

func set_species(new_value: int) -> void:
	species = new_value
	if $MeshInstance.material_override != null:
		if species == 3:
			# For Babyz species, use the Babyz palette and enable quantization
			$MeshInstance.material_override.set_shader_param("palette", BABYZ_PALETTE)
			$MeshInstance.material_override.set_shader_param("should_quantize", true)
			$MeshInstance.material_override.set_shader_param("palette_size", 256)
		else:
			# For other species, use the default palette and disable quantization
			$MeshInstance.material_override.set_shader_param("palette", DEFAULT_PALETTE)
			$MeshInstance.material_override.set_shader_param("should_quantize", false)
			$MeshInstance.material_override.set_shader_param("palette_size", 256)

func set_transparent_color(new_value):
	transparent_color = new_value
	$MeshInstance.material_override.set_shader_param("transparent_index", new_value)
