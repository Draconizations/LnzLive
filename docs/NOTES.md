# LnzLive - Notes

LnzLive is an interactive editor for P.F. Magic LNZ data. All minor notes about development will be dropped in this document. Major tasks will be added as Issues to the [LnzLive Task Tracker](https://github.com/users/tabbzi/projects/3/views/6) associated with the GitHub repository.

## Code Review

🔴 DRY Violations | 🟡 Needs Optimization | 🔵 Dead Code | 🟣 Structural Issues

### Data Classes (Parsers & Utils)

#### `data_classes/lnz_parser.gd`

- 🔴 Redundant Property Parsing: Methods like get_default_scales, get_leg_extensions, and property overrides (get_ball_size_override, etc.) repeat the same logic of section searching and index mapping.
   - Problem: Extreme maintenance burden; changing the parsing logic requires updating dozens of methods.
   - Solution: Abstract into a generalized _parse_section_to_property(section, property_map) function.

- 🟡 Inefficient RegEx Usage: r.search_all is called in tight loops with redundant compilation.
   - Problem: Excessive CPU cycles spent recompiling patterns for every line.
   - Solution: Move RegEx patterns to class-level const or static variables. Use String.split() for simple delimited lines.

- 🟡 Suboptimal ID Tracking: get_addballs() calculates max_ball_num by extracting all keys into a new array via .keys().max().
   - Problem: $O(N)$ array allocation and sorting on every call is slow for complex models.
   - Solution: Track the current highest ID in a simple integer variable during the initial parse.

#### `data_classes/bhd_parser.gd` & `bdt_parser.gd`

- 🔴 Duplicated Loop Logic: Binary reading loops for ball_sizes are repeated across species-check branches (if "baby", elif "dog").
   - Problem: Logic errors in one branch may not be fixed in others.
   - Solution: Resolve the file.seek() offset first based on species, then execute a single unified extraction loop.

- 🟡 Synchronous Binary I/O: Brute-force while loops with constant file.seek() peeking (2 bytes at a time) for pattern matching.
   - Problem: Extremely slow on mechanical drives or high-latency filesystems; blocks the main thread.
   - Solution: Read the file into a PoolByteArray and use find() in memory to locate headers.

- 🟣 Blocking Constructors: Heavy file I/O is performed inside _init().
   - Problem: Freezes the UI/Engine during object instantiation.
   - Solution: Move I/O to a load_file(path) method that can be yielded or run in a background thread.

#### `data_classes/lnzlive_utils.gd`

- 🔴 Static RegEx Recompilation: parse_number_list and parse_flexible_integers recompile RegEx patterns on every single call.
   - Problem: These are core utility functions called thousands of times during an LNZ load; this is a primary performance bottleneck.
   - Solution: Define these RegEx patterns as static constants.

- 🔴 Math Logic Duplication: visual_size_to_lnz_size and snap_visual_size repeat the same engine-to-LNZ scaling math.
   - Problem: Inconsistent scaling if the formula is updated in one place but not the other.
   - Solution: Create a single get_engine_scale_factor() helper.

### Model Generation & Logic

#### `scenes/dog_generator.gd`

- 🔴 Species Logic Branching: Massive if/elif blocks checking for DOG, CAT, and BABY are repeated in 6+ functions.
   - Problem: Adding a new species requires manually hunting down and updating every single branch.
   - Solution: Abstract species-specific data (symmetry, bone names, scales) into a SpeciesProfile Resource.

- 🔴 Hardcoded Node Lookups: get_tree().root.get_node(...) is scattered throughout the file for UI interaction.
   - Problem: Moving a single node in the scene tree breaks the entire generator.
   - Solution: Use export (NodePath) variables or a centralized "Registry" of UI components.

- 🟡 Expensive Group Polling: get_tree().get_nodes_in_group() is called inside loops and toggle signals.
   - Problem: High overhead for simply toggling visibility or transparency.
   - Solution: Store references to created Ball and Line nodes in local dictionaries (_spawned_nodes) at creation time.

- 🔵 Commented Scaffolding: Large blocks of legacy leg/body positioning and remove_child logic clutter the script.

Recommended Refactor:

- ModelBuilder: Responsible only for instantiating Spatial nodes and applying LNZ properties.
- AnimationController: Handles BDT/BHD frame updates and T-Pose logic.
- SpeciesResource: A data-only resource that maps species enums and symmetry rules.

### Viewports & Inputs

#### `scenes/editor/PetViewContainer.gd`

- 🔴 Input Mode Duplication: Raycast intersection and click logic are duplicated across move_mode, paint_mode, and recolor_mode.
   - Problem: Inconsistent "feel" between tools; bugs in raycasting must be fixed in four places.
   - Solution: Unify raycasting into a single _get_object_under_mouse() helper.

- 🔴 Symmetry Mapping Redundancy: Logic for finding mirrored iris/eye/ball bindings is repeated in input handlers and sizing lookups.
   - Problem: Code bloat and potential for "desynced" symmetry.
   - Solution: Centralize symmetry lookups in KeyBallsData.

- 🟡 Frame-Rate Dependent String Building: _process constructs the helper_label string every frame using complex if checks.
   - Problem: Unnecessary string allocations 60+ times per second.
   - Solution: Use an event-driven approach; only update the label text when the tool mode or selection changes.

Recommended Refactor:

- ViewportInputHandler: Converts mouse events into world-space raycasts.
- EditorMode: Create classes for PaintMode, MoveMode, etc., that override handle_input.
- GizmoRenderer: Dedicated class for _draw calls and 3D axis handles.

### Text Editor

#### `scenes/editor/LnzTextEdit.gd`

- 🔴 Linear Search Overuse: _find_line_in_section functions repeat identical while loops searching for IDs.
   - Problem: Editing a large LNZ file becomes sluggish as every change triggers multiple full-text scans.
   - Solution: Use a generalized _find_entry_in_section(section, id, column) method.

- 🟡 UI-as-Database Antipattern: The script treats the TextEdit UI component as the "Source of Truth" for data.
   - Problem: Constantly splitting/joining strings to perform math is highly inefficient.
   - Solution: Maintain a structured LnzData object in memory. Sync the TextEdit UI to the data, not the other way around.

Recommended Refactor:

- LnzDataModel: A non-UI class that handles the parsing, mirroring, and recoloring of LNZ data arrays.
- UndoRedoHistory: Manages the history stack independent of the text buffer.
- LnzTextEditUI: Handles highlighting, scrolling, and user input, delegating logic to the DataModel.

### Visual Nodes (`Ball.gd`, `Line.gd`, etc.)

- 🔴 Base Class Omission: Hover, selection, and shader update logic are duplicated across all three visual scripts.
   - Problem: Adding a "Selection Outline" feature requires editing three different files.
   - Solution: Create a SelectableVisual base class inheriting from Spatial.

- 🔴 Shader Setter Boilerplate: Every setter (set_eyelid_color, set_outline) repeats the material_override.set_shader_param check.
   - Solution: Create a _set_param(name, value) helper that handles the validity checks.

- 🟡 Material Cloning: set_tile_texture calls .duplicate() on materials repeatedly.
   - Problem: Rapidly exhausts memory and breaks GLES batching.
   - Solution: Use set_instance_shader_param where possible, or cache unique materials in a dictionary.

- 🟣 Dependency Inversion Violation: Ball.gd reaches deep into the scene tree to check PetViewContainer state.
   - Problem: The Ball cannot exist without the specific Editor UI hierarchy.
   - Solution: Use signals or a global EditorState singleton to communicate selection/highlighting.

### Modes & Settings

#### `AutoPaintballerSettings.gd` & `PaintballSettings.gd`

- 🔴 Manual Dictionary Mapping: 20+ keys are manually mapped between ConfigFiles and UI nodes.
   - Problem: Adding a new setting requires updating load, save, and reset functions individually.
   - Solution: Use a loop over a SETTINGS_MAP constant that links "config_key" to "node_name".

- 🟡 Algorithm Coupling: Procedural generation logic (Voronoi, Noise, Stripes) is inside the UI script.
   - Problem: Cannot use the AutoPaintballer logic in a headless script or another scene.
   - Solution: Move math-heavy patterns to a ProceduralGenerator utility.

- 🟡 Blocking Raycast Loops: max_attempts for paintball placement can cause frame stutters.
   - Problem: High-density models freeze the editor during pattern generation.
   - Solution: Spread the generation over multiple frames using a yield or _process step.

## Bugs

Recording observations about bugs here... making issues when the problem and solution are more clear...

### Paintballz not appearing from certain Toyz LNZ

needing two copies of paintballz on addballz in DOLL.bhd babyz?

### Ball numbers of alternative BHD models not consistent with LNZ

issue with [Move] in Babyz toyz: when 18 is addball not baseball cant do moves on addball, it crashes; review how ball # computed from BHD

### New entries entered after blank lines

Figure out why new entries coming in after the last comment line within a section, e.g.:

```
(last part of LNZ section)
(blank line)
126,	127,	1,	-1,	244,	244,	100,	100
127,	128,	1,	-1,	244,	244,	100,	100

;Base ball,diameter(% of baseball),direction (x,y,z),colour,outline colour,fuzz,outline,group,texture
132	131	0	-1	150	150	100	100	0	0
```

## Archived

### 2026-04-04

These have been fixed with recent camera inversion and shader updates:

#### Headshot angles do not appear correct

Could be related to the inverted camera view in LnzLive

#### Texture scale on rotating ballz

Scaling on rotating textures still seems off

### 2025-09-01

- [x]  Comments in sections disrupt the hotkey jumps
- [x]  Hotkey jumps don't loop
- [x]  Fix mirror project to propogate Fixed <> Projected pair swaps
- [x]  Clicking headers for Mirror and Lock should set/unset all in Project Mode
- [x]  If applyling paintballz, then unselect from Text Editor first, otherwise it replaces all
- [x]  Render option draw paintballz hides the irises but not on reload of LNZ
- [x]  Frame number doesn't copy right when entering into animation frame? or just frame isnt captured right? -1?
- [x]  Quick flash with CTRL+Q does not affect addballz
- [x]  Add texture color to recolor menu
- [x]  Links in Options Menu -> Help open both URLs at once
- [x]  Scale up overshoots size
- [x]  Parse species from `[Default Linez File]` for breed file LNZ, if not `[Species]` as in pet file LNZ

### 2025-09-14

Disappearing ballz problem! Two instances (thanks Beefy for finding and sharing LNZ):

1. When referencing addball before it exists:

SCRIPT ERROR: generate_balls: Invalid get index '100' (on base: 'Dictionary').
          At: res://scenes/dog_generator.gd:646

Petz and PWS actually do not mind early ball references, but we parse each entry row by row. We may need to index all at once!

2. Beefy's Pterosaur example of all ballz after a certain index disappearing:

Checked:

- Error indicates that it is related to omissions
- Omissions x Linez? no
- Omissions x Move? no
- Omissions x Project Ball? no
- Error indicates paintball getting omitted... irises? YES!
- When eyes irised omitted, rest of ballz cannot be shown

Also, it would be useful to make it unneccessary to open an Example LNZ before pasting... if you do right now:

ERROR: File must be opened before use.
   At: core\bind\core_bind.cpp:2224
File not found:
SCRIPT ERROR: init_ball_data: Invalid get index 'num_balls' (on base: 'Nil').
          At: res://scenes/dog_generator.gd:154
SCRIPT ERROR: apply_extensions: Invalid get index '30' (on base: 'Dictionary').
          At: res://scenes/dog_generator.gd:243
SCRIPT ERROR: init_visual_balls: Invalid type in function 'apply_sizes' in base 'Node (dog_generator.gd)'. Cannot convert argument 1 from Nil to Dictionary.
          At: res://scenes/dog_generator.gd:187
Saved LNZ and Applied Changes!