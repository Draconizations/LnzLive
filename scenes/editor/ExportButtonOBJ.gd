extends Button

# ExportButtonOBJ.gd – exports currently loaded petz and animation frame as a 3D model Wavefront OBJ file
# - Collects all visible, non-omitted Ball.gd nodes
# - Writes each ball as a UV-sphere mesh (vertices + faces)
# - Writes each Line as a tapered cylinder mesh
# - Writes each Polygon as a quad

func _ready():
	connect("pressed", self, "_on_pressed")

func _on_pressed():
	var fd = FileDialog.new()
	fd.mode = FileDialog.MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.add_filter("*.obj ; Wavefront OBJ")
	add_child(fd)
	fd.popup_centered()
	fd.connect("file_selected", self, "_export_current_model")

func _export_current_model(path: String) -> void:
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		push_error("Cannot open '%s' for writing" % path)
		return

	# Set OBJ header
	f.store_line("# Exported Petz Model")
	f.store_line("o Petz\n")

	# Grab scene data from PetRoot
	var dog = get_tree().root.get_node("Root/PetRoot/Node")
	print("Total balls in dog.ball_map:", dog.ball_map.size())
	var pixel_world_size = dog.pixel_world_size
	var lines = dog.lnz.lines
	var polys = dog.lnz.polygons

	# Define visible ballz to export
	var all_ball_nodes = []
	var by_no = {}
	for b in dog.ball_map.values():
		if "ball_no" in b and "ball_size" in b and b.has_method("is_visible_in_tree"):
			if not b.omitted and b.visible_override:
				all_ball_nodes.append(b)
				by_no[b.ball_no] = b

	print("? Found", all_ball_nodes.size(), "Ball.gd nodes")

	print("lines:", lines.size(), "polygons:", polys.size())

	var vertex_offset = 1

	# Define spheres for ballz
	var S_SEG = 12 # longitude segments
	var S_RNG = 8  # latitude segments

	for bd in all_ball_nodes:

		# Get center in world coordinates
		var center = bd.global_transform.origin
		center.y = -center.y

		# Get radius from ballz size in world units
		var radius = bd.ball_size * pixel_world_size * 0.5

		print("ball", bd.ball_no, "size", bd.ball_size)
		print("radius", radius)

		# Write vertices
		for i in range(S_RNG + 1):
			var phi = PI * i / S_RNG
			for j in range(S_SEG):
				var theta = TAU * j / S_SEG
				var x = radius * sin(phi) * cos(theta)
				var y = radius * cos(phi)
				var z = radius * sin(phi) * sin(theta)
				f.store_line("v %f %f %f" % [center.x + x, center.y + y, center.z + z])
		
		# Write faces
		for i in range(S_RNG):
			for j in range(S_SEG):
				var a = vertex_offset + i * S_SEG + j
				var b = vertex_offset + (i + 1) * S_SEG + j
				var c = vertex_offset + (i + 1) * S_SEG + (j + 1) % S_SEG
				var d = vertex_offset + i * S_SEG + (j + 1) % S_SEG
				f.store_line("f %d %d %d" % [a, b, c])
				f.store_line("f %d %d %d" % [a, c, d])
		
		# Track vertex index
		vertex_offset += (S_RNG + 1) * S_SEG
	
	# Define cylinders for linez
	var cyl = CylinderMesh.new()
	cyl.radial_segments = 6
	cyl.rings = 1

	for ld in lines:

		# Get start ballz and end ballz
		var b1 = by_no.get(ld.start)
		var b2 = by_no.get(ld.end)
		if b1 == null or b2 == null:
			continue

		# Get start point and end point in world coordinates
		var p1 = b1.global_transform.origin; p1.y = -p1.y
		var p2 = b2.global_transform.origin; p2.y = -p2.y

		# Define geometry between start ballz and end ballz
		var dir = (p2 - p1).normalized()
		var length = p1.distance_to(p2)
		var mid = p1 + dir * (length * 0.5)

		if typeof(b1.get("ball_size")) != TYPE_REAL or typeof(b2.get("ball_size")) != TYPE_REAL:
			print("Skipping line due to invalid ball_size:", ld.start, ld.end)
			continue
		
		# Define radius and scale tapers by line thickness
		var min_radius = 0.0
		var d1 = b1.ball_size * (ld.s_thick / 100.0)
		var d2 = b2.ball_size * (ld.e_thick / 100.0)
		var r1 = max(d1 * pixel_world_size * 0.5, min_radius)
		var r2 = max(d2 * pixel_world_size * 0.5, min_radius)

		print("length=", length, "   expected ball spacing=", p1.distance_to(p2))

		cyl.height = length * 2
		cyl.bottom_radius = r1
		cyl.top_radius = r2

		# Bake cylinder mesh
		var arr2 = cyl.surface_get_arrays(0)
		var verts2 = arr2[Mesh.ARRAY_VERTEX]
		var idxs2 = arr2[Mesh.ARRAY_INDEX]

		# Orient cylinder in direction of start ballz and end ballz
		var up = Vector3(0, 1, 0)
		var axis = up.cross(dir)
		if axis.length() < 1e-4:
			axis = Vector3(1, 0, 0)
		var angle = acos(clamp(up.dot(dir), -1, 1))
		var basis = Basis(Quat(axis.normalized(), angle))

		# Write vertices
		var offset = basis.xform(Vector3(0, -cyl.height * 0.5, 0))
		for v in verts2:
			var gv = basis.xform(v) + p1
			f.store_line("v %f %f %f" % [gv.x, gv.y, gv.z])

		# Write faces
		var segs = cyl.radial_segments
		var side_idx_limit = segs * 2 * 3

		for i in range(0, side_idx_limit, 3):
			var a = int(idxs2[i    ]) + vertex_offset
			var b = int(idxs2[i+1]) + vertex_offset
			var c = int(idxs2[i+2]) + vertex_offset
			f.store_line("f %d %d %d" % [a, b, c])
		
		# Track vertex index
		vertex_offset += verts2.size()

	# Define quads from polygonz
	for pd in polys:

		# Get centers four defining ballz in world coordinates
		var pts = []
		for key in ["ball1", "ball2", "ball3", "ball4"]:
			var bd = by_no.get(pd[key])
			if bd:
				var pp = bd.global_transform.origin
				pp.y = -pp.y
				pts.append(pp * pixel_world_size)
		if pts.size() == 4:
			for p in pts:
				# Write vertices
				f.store_line("v %f %f %f" % [p.x, p.y, p.z])

			# Write faces
			f.store_line("f %d %d %d" % [vertex_offset + 0, vertex_offset + 1, vertex_offset + 2])
			f.store_line("f %d %d %d" % [vertex_offset + 0, vertex_offset + 2, vertex_offset + 3])

			# Track vertex index
			vertex_offset += 4

	print("Current file position is:", f.get_position())
	f.close()
	print("Saved OBJ to", path)

# pose quick ref
#catz
#214 is helens
#306 is showpose
#309 is hanging
#177 is cute paw

# after loading exported OBJ into Blender, a good order of operations for a nice mesh is...
# separate body parts especially eyes
# select all verts in edit mode (a) > mesh > merge (m) > merge by distance
# subdivision modifier x2
# apply with crtl + a > visual geo to mesh
# join objects to one
# remesh with very low voxel 0.0015 m
# remesh better