extends Tree

var dog_generator
var lnz_parser

func setup(p_dog_generator, p_lnz_parser):
	dog_generator = p_dog_generator
	lnz_parser = p_lnz_parser
	populate_tree()

func populate_tree():
	clear()
	var root = create_item()
	set_hide_root(true)

	set_columns(1)
	set_column_title(0, "Variation Viewer")
	set_column_titles_visible(true)

	if lnz_parser == null or lnz_parser.sections_map == null:
		return

	var sections = lnz_parser.sections_map.keys()
	sections.sort()

	var id_counts = {}
	for section in sections:
		for id in lnz_parser.sections_map[section]:
			if id == 0: continue
			if !id_counts.has(id): id_counts[id] = 0
			id_counts[id] += 1

	var global_ids = []
	for id in id_counts:
		if id_counts[id] > 1:
			global_ids.append(id)
	global_ids.sort()

	if global_ids.size() > 0:
		var global_item = create_item(root)
		global_item.set_text(0, "Global Variations")
		global_item.set_selectable(0, false)

		for id in global_ids:
			var item = create_item(global_item)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_text(0, "Global Variation #" + str(id))
			item.set_metadata(0, {"type": "global", "id": id})

			var all_active = true
			for s in sections:
				if lnz_parser.sections_map[s].has(id):
					var config = dog_generator.current_variation_config
					if !config.has(s) or !config[s].has(id):
						all_active = false
						break
			item.set_checked(0, all_active)

	for section in sections:
		var variations = lnz_parser.sections_map[section]
		var var_ids = variations.keys()

		var has_variations = false
		for id in var_ids:
			if id > 0:
				has_variations = true
				break

		if !has_variations:
			continue

		var section_item = create_item(root)
		section_item.set_text(0, section)
		section_item.set_selectable(0, false)

		var_ids.sort()

		for id in var_ids:
			if id == 0: continue

			var var_block = variations[id]
			var item = create_item(section_item)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)

			var display_name = var_block.name
			if display_name == "Variation " + str(id):
				display_name = ""

			item.set_text(0, "#" + str(id) + " " + display_name)
			item.set_metadata(0, {"type": "section", "section": section, "id": id, "start_line": var_block.start_line})

			var config = dog_generator.current_variation_config
			if config.has(section) and config[section].has(id):
				item.set_checked(0, true)
			else:
				item.set_checked(0, false)

func _ready():
	connect("item_edited", self, "_on_item_edited")
	connect("item_selected", self, "_on_item_selected")

func _on_item_edited():
	var item = get_edited()
	var col = get_edited_column()
	if col == 0:
		var meta = item.get_metadata(0)
		if meta:
			var checked = item.is_checked(0)

			if meta.type == "global":
				var id = meta.id
				var sections = lnz_parser.sections_map.keys()
				var config = dog_generator.current_variation_config

				var root = get_root()
				if root:
					var global_folder = root.get_children()
					if global_folder and global_folder.get_text(0) == "Global Variations":
						var g_item = global_folder.get_children()
						while g_item:
							var g_meta = g_item.get_metadata(0)
							if g_meta and g_meta.id != id:
								g_item.set_checked(0, false)
							g_item = g_item.get_next()

				var all_global_ids = []
				if root:
					var global_folder = root.get_children()
					if global_folder and global_folder.get_text(0) == "Global Variations":
						var g_item = global_folder.get_children()
						while g_item:
							var g_meta = g_item.get_metadata(0)
							if g_meta: all_global_ids.append(g_meta.id)
							g_item = g_item.get_next()

				for s in sections:
					if !config.has(s): config[s] = [0]

					for g_id in all_global_ids:
						if config[s].has(g_id):
							config[s].erase(g_id)

					if checked:
						if lnz_parser.sections_map[s].has(id):
							config[s] = [0, id]
						elif lnz_parser.sections_map[s].has(1):
							# Fallback to #1
							config[s] = [0, 1]
						else:
							config[s] = [0]
					elif !checked:
						# If unchecked, default to #1 if available, otherwise base LNZ
						if config[s].empty(): config[s] = [0]
						if config[s] == [0] and lnz_parser.sections_map[s].has(1):
							config[s] = [0, 1]

				_update_tree_checks()

			elif meta.type == "section":
				var section = meta.section
				var id = meta.id
				var config = dog_generator.current_variation_config
				if !config.has(section): config[section] = [0]

				if checked:
					config[section] = [0, id]
				else:
					if config[section].has(id):
						config[section].erase(id)

					# If unchecked, default to #1 if available
					if config[section] == [0] and lnz_parser.sections_map[section].has(1):
						config[section] = [0, 1]

				_update_tree_checks()

			dog_generator.recompose_model()

func _update_tree_checks():
	var root = get_root()
	if !root: return

	var item = root.get_children()
	while item:
		var child = item.get_children()
		while child:
			var meta = child.get_metadata(0)
			if meta and meta.type == "section":
				var config = dog_generator.current_variation_config
				var is_active = config.has(meta.section) and config[meta.section].has(meta.id)
				child.set_checked(0, is_active)
			child = child.get_next()
		item = item.get_next()

func _on_item_selected():
	var item = get_selected()
	if item:
		var meta = item.get_metadata(0)
		if meta and meta.has("start_line"):
			var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
			if lnz_text_edit:
				lnz_text_edit.cursor_set_line(meta.start_line)
				lnz_text_edit.center_viewport_to_cursor()
