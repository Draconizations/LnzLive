# LnzLive guide

## Quickstart

### Load LNZ into the editor

You can either start from a preset LNZ file under `Examples` in the file tree (left-hand panel) by double-clicking to load, or paste LNZ copied from a pet file (`.pet`, `.baby`) or breed file (`.dog`, `.cat`) into the text editor (right-hand panel).

To load your own LNZ file, open in LNZPro, paste the contents into the editor, and hit `Apply Changes` or save (`CRTL+S`) to refresh the pet view. These will appear under `Local Storage` in the file tree, and can be right-clicked to rename or make backups, which is recommended.

Helpful tips will appear at the top of the screen about visual and text editing tools.

Don't forget to hit save or apply changes to see the results!

> Note: *Loading and saving LNZ data of game files directly is a **planned feature**.*

## Help! It crashes when I do X!

LnzLive is a work in progress! Please make regular backups of your LNZ files.

If you encounter a bug or have a suggestion, please raise an issue in the GitHub repository so it can be tracked and resolved.

## File Tree

The file tree on the left panel allows you to manage your LNZ files.

- **Examples:** Contains preset LNZ files you can double-click to load.

- **Local Storage:** Stores LNZ files that you have saved from the editor.

- **Local Textures:** Shows custom texture BMP files you have imported. A thumbnail preview of your texture will also show here.

- **Local Palettes:** Shows custom palette PNG files you have imported. Double-clicking on a palette will apply to the current LNZ file.

Once you have an LNZ file saved under Local Storage, you can right-click it to see more options:

- **Back Up:** Creates a copy of the file named `{filename}_backup_#.lnz`. LnzLive keeps the three most recent backups.

- **Rename:** Changes the name of the LNZ file.

- **Delete:** Removes the LNZ file permanently.

For any LNZ, BMP, or PNG file, you can right-click and choose "Copy Filename" to get the file prefix for easy pasting into LNZ.

## Menu Options

### File

- **Import LNZ / BMP / PNG:** Load LNZ files or custom texture/palette image files from your computer.

### Edit

- **Capture Head Shot:** Captures the current animation frame and camera angle and writes it to the `[Head Shot]` section of the LNZ with helpful comments.

### Tool

#### Auto Paintballer

The `Auto Paintballer` is tool for procedurally generating either simple spots, complex patterns, or intricate fractals using `[Paintballz]`, which get placed according to selected distribution modes.

**Common Properties:**

These settings are used by most distribution modes.

- **Affected Ballz:** A comma-separated list of ball numbers (or ranges, e.g., `1,5,10-15`) that paintballs can be attached to.
- **Number of Spots:** The total number of spots, which could comprise multiple paintballz, to generate.
- **Size Min/Max:** The random size range for each paintball.
- **Color/Outline Color List:** Comma-separated lists of color indices (or ranges, e.g., `150-159,180-189,214`) to be used for the fill and outline of the paintballs.
- **Outline Type Min/Max:** The random range for the outline type.
- **Fuzz Min/Max:** The random range for fuzziness.
- **Texture List:** A comma-separated list of texture IDs to apply. Use -1 for no texture.
- **Group:** The group number to assign to the generated paintballs.
- **Anchored:** If checked, the paintballs will be anchored.

**Distribution Modes:**

This dropdown determines the algorithm used to place paintballs.

- Uniform: Places paintballs randomly across the entire surface.
- Spiral: Arranges paintballs in a spiral pattern around the pet.
- Star: Creates starburst patterns with configurable points and ray length.
- Horizontal/Vertical Bands: Confines paintball placement to distinct bands.
- Grid/Checkerboard: Arranges paintballs in a grid or checkerboard pattern.
- Random Walk: Each new paintball is placed near the previous one, creating winding paths.
- Clustered: Groups paintballs into tight, randomly placed clusters.
- Pole/Equator-Focused: Concentrates paintballs at the top/bottom or the middle of the pet.
- Halfie: Restricts paintballs to one half of the pet along a selected axis (X, Y, or Z) and size (positive or negative).
- Bullseye: Creates concentric rings of different colors.
- Stripes: Generates organic, wavy stripes using noise. You can control the frequency, scale, distortion, and thickness.
- Leopard: Creates irregular, ringed spots. You can control the spot radius, irregularity, and how complete the rings are. Use "Paired Colors" to define ordered outer/inner colors from your color list (e.g., `155,45,185,45` will only sample 155 outer / 45 inner and 185 outer / 45 inner if "Paired Colors" is checked; otherwise, random pairs will be drawn).
- Rainbow: Generates multi-color arcs of paintballz. You can control the angle, curvature, width, and length of the arcs.
- Fractal: A powerful mode using Lindenmayer system aka turtle-walking procedure for generating complex, self-repeating patterns.

    - *Preset:* Choose a classic fractal like Dragon Curve, Sierpinski Triangle, or Barnsley Fern to see how it works. Select "Custom" to define your own rules.
	- *Generate Random:* When "Custom" preset is selected, this button creates a new, randomized (but valid) rules for you to experiment with making new fractals.
	- *Axiom:* The starting string for the fractal (e.g., `F`).
	- *Rules:* The replacement rules, one per line (e.g., `F=F+G`). The allowed characters are `F`, `G`, `A`, `B`, `X`, `+`, `-`, `[, ]`. The *Axiom* and *Rules* fields are only editable when the "Custom" preset is selected.
	- *Iterations:* How many times to apply the rules. Higher numbers create more complex patterns.
	- *Angle:* The angle in degrees for turning commands (`+` or `-`). Each preset comes with a recommended angle.

	The Lindenmayer system works by starting with a string of characters (the *Axiom*) and repeatedly replacing characters according to a set of *Rules*. This process, called iteration, creates a long and complex string of commands. This string is then used to guide a "turtle" that moves across the ballz surface, placing paintballz along the pattern.
	
	The basic commands are:

	`F`, `G`, `A`, `B`: Move forward and draw a paintball.

	`X`: A placeholder character used in rules that could replace it. It does not draw any paintballz itself.

	`+`: Turn right by the specified *Angle*.

	`-`: Turn left by the specified *Angle*.

	`[`: Save the current position and direction (creates a branch).

	`]`: Return to the last saved position and direction (ends a branch).

#### View Palette

Pops open a numbered preview of the paletted color index matching whichever game species and color palette is loaded currently.

#### Recolor Menu

The Recolor Menu can be used to quickly recolor ballz, paintballz, and linez. Enter the color mappings you want to apply (e.g., 35 -> 15). Use the checkboxes to select to which LNZ elements to apply the color swap.


### Mode

#### Select Mode

In `Select Mode`, hovering over ballz will report their index # and double clicking, or pressing the following keys, will jump you to relevant sections and entries in the LNZ text editor.

- **Z** or **B**: go directly to the LNZ line defining ballz in `[Ball Info]` or `[Add Ball]`.
- **X** or **M**: cycle through `[Move]` lines that affect this ball. If none are found, goes to the `[Move]` header.
- **C** or **P**: cycle through `[Project Ball]` lines that affect this ball. If none are found, goes to the `[Project Ball]` header.
- **V** or **L**: cycle through `[Linez]` that include this ball. If none are found, goes to the `[Linez]` header.

#### Paintball Mode

In `Paintball Mode`, you can place prepared paintballs by point-and-click. This mode can be entered via the top menu or by right-clicking a specific ball to lock editing to that ball. When applying paintballs to Babyz, LnzLive automatically repeats the LNZ entries five times with `;rep#` comments to improve their stability in-game.

#### Project Mode

In `Project Mode`, you can quickly prototype body shapes. This mode allows you to set ranges and randomize entries from `[Project Ball]` and extension and scale sections (e.g., `[Leg Extension]` or `[Default Scales]`). For projections, the defaults given per species represent a normal distribution of fixed-projected ball pairs from official breed files, but the min and max projection values can be modified or you can add new fixed-projected pairs. You can also flag a pair with `Mirror` to also write out the same values to any ballz with left/right equivalents. If you check `Lock` on any entry in the table, then those values will not change when you randomize. When you are happy with the values, then hit `Apply Projections to LNZ` to write to LNZ. Order of `[Project Ball]` entries does matter for how ballz get placed and influence eachother, so you can also alter the order of planned entries in the properties panel.

#### Preset Mode

In `Preset Mode`, you can copy properties of existing ballz, including any applied paintballz, and apply these properties onto other ballz. It is here that you can also enter paintballz LNZ and have those paintballz get added to other ballz. You can also rotate those paintballz designs before applying.

Holding the ALT key and clicking on a ballz will copy its properties and paintballz to the panel.

For applying size properties, you have three options: true, set, and sum. True size determines what size difference is needed for a base ballz to match the effective visual size, or just sets that value for add ballz. Set applies the same value to base ballz and add ballz regardless. Sum can be used to increase or decrease sizes of ballz. The default is true size. Note that resizing ballz can also be done visually by holding SHIFT + ALT + left-click and dragging a ball inward (decrease) or outward (increase), which can be faster than click through sums via `Preset Mode`.

#### Line Mode

In `Line Mode`, you can click a series of start and end ballz to connect linez with the properties specified.

### Render

Here, you will find toggles for what elements should be drawn in the pet view. Transparency on color index `253` (typically, magenta in default game palette) can be toggled on or off. Special ballz refers to transient ballz like tears in Babyz that do not usually render but aren't explicitly omitted in `[Omissions]`.

### Export

- **Export OBJ 3D Model:** Experimental feature to export a 3D model of the loaded LNZ and animation frame! Your mileage may vary.

### Help

This option offers links to several handy resources, including [Carolyn Horn's hexing information](https://github.com/melissamcewen/carolyns-bible) and this [User Guide](https://github.com/tabbzi/LnzLive/blob/master/GUIDE.md)!


### Background Color Selector

Clicking on the square after the menu options brings up a color selector, which you can use to pick the background color of the pet view.

### Eyelid Toggle

Clicking on the eyeball will cycle through eyelid rendering options: neutral, none, angry, and scared.

### Animation Controller

Use these controls to preview and navigate animations:

- Jump through animations with the arrows or by entering an animation index in the box.
- Click `Play` button or press `SPACE` to start or stop a playback.
- Slide through animation frames by dragging the handle.

## Basic Navigation

- Click and hold the left mouse button in the pet view (center panel) to rotate the pet.
- Use the mouse wheel to zoom in and out.
- Press down on mouse wheel or hold space and drag to move pet around viewport.

## Visual editing

Ballz can be moved and resized directly in the pet view.

### Move a ball
SHIFT + left-click and drag to move a ball in 3D space.

The move will be reflected as a Move entry in the LNZ. If a Move line does not exist, one will be created.

Hold X, Y, or Z while dragging to constrain movement to that axis.

### Scale a ball
SHIFT + ALT + left-click and drag to resize a ball interactively.

The size change will be reflected in the Ballz Info or Add Ball line in the LNZ.

## Tools menu

Press CTRL + SPACE in the pet view to open the tools menu, or right-click on a ball in the pet view.

### Color...

The "Color..." option opens a menu of additional options for recoloring.

For most of these, when you select what to recolor, two text entry boxes will appear at your cursor. The first is for the ball colour, the second is for outline color. Type a color number (e.g., 25) and hit Enter to apply. Leave a box blank if you don't want to affect the color/outline.

The "Color Swap" option opens the Recolor Menu, which can be used to quickly recolor ballz, paintballz, and linez. Enter the color mappings you want to apply (e.g., 35 -> 15). Use the checkboxes to select to which LNZ elements to apply the color swap.

### Create Add Ballz (+ Linez)

While a ball/addball is hovered or selected, use "Create Addballz" or "Create Addballz + Linez" to create a new addball and/or line. If an addball is selected, the new addball will be parented to the same ball as the selected addball. The line will connect the selected addball and the new addball.

### Delete Addballz / Omit Ballz

While a ball/addball is hovered or selected, use "Delete Addballz / Omit Ballz" to either remove an addballz and its associated linez and paintballz completely, or add base ballz to the `[Omissions]` list.

### Connect with Linez

While a ball is hovered or selected, use "Connect with Linez" line creation mode.

Click another ball to connect the two with a Linez entry in the LNZ.

### Copy L to R

The Copy L to R tool will apply all changes on the left side of the pet (i.e. the side with ball number 0 - in LnzLive this is currently the left side when looking at the pet head-on, NOT the pet's left side) to the right side. This includes balls, addballs, paintballs, lines, etc.

### Move Head

LNZ has no such thing as a 'neck extension', so this is a small util to move all head balls at once. The three text boxes are for x, y, z coordinates to move by. Hit Enter to apply. You can keep hitting Enter to continue moving.

### Copy Ballz Colors to Clipboard

Useful for making Color Info Override sections in breeds. Not supported in all browsers.

## Backups

Destructive tools like `Color Swap` and `Copy L to R` will trigger an automatic backup. The visual editing tools like move and scale ballz are especially hard to reverse without backups, as these take effect immediately. LnzLive takes a backup of your file before applying these tools, and saves it as `{filename}_backup.lnz`. The backup will overwrite any existing backup file.

> Note: *Improved save states or file versioning is a **planned feature**.*

## Textures and Palettes

Custom BMP files can be loaded from local storage by clicking "Import LNZ / BMP / PNG" button. These should now appear under `Local Textures` in the file tree. You can now apply textures as normal in the LNZ data. LnzLive doesn't care about the full filepath, only the filename.

Similar to textures, custom palettes can be loaded from local storage, but need to be in a color ramp PNG format. **You will need to convert your BMP palette image to a PNG in the format that LnzLive expects**. You can generate this using either of these web tools:

- [Petz Palette Converter](https://draconizations.github.io/petz-palette-converter/)
- [Petz Paletteiare](https://tabbzi.github.io/petz-paletteiare/)

To load your palette image, use the "Import LNZ / BMP / PNG" button. These should now appear under `Local Palettes` in the file tree. You can now apply the palettes as normal in the LNZ data, make sure to omit the `.png` at the end. Or, double-click the palette file name to apply automatically.

You can also add files directly for LnzLive to access from your file system:

Go to `%APPDATA%/Godot/app_userdata/PetzRendering/resources/textures` (you may have to create this folder).

After adding your files directly to this folder, relaunch LnzLive to load it. If your files have been loaded correctly, you will see them if you expand the `Local Textures` or `Local Palettes` part of the file tree.

> Note: *Loading palettes from palette BMP files directly is a **planned feature**.*

## Other features

While editing the LNZ:

- Place the editing cursor on any line in Ballz Info. You don't need to select the entire line, just place the cursor within it. Hit Ctrl+Q to make that ball flash in the pet view so you can locate it.

- Similarly, place the cursor on any line in the Add Ball section and hit Ctrl+Q to make the addball flash.
