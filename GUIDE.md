# LnzLive guide

## Quickstart

### Load LNZ into the editor

You can either start from a preset LNZ file under `Examples` in the file tree (left-hand panel) by double-clicking to load, or paste LNZ copied from a pet file (`.pet`, `.baby`) or breed file (`.dog`, `.cat`) into the text editor (right-hand panel).

To load your own LNZ file, open in LNZPro, paste the contents into the editor, and hit `Apply Changes` or save (`CRTL+S`) to refresh the pet view. These will appear under `Local Storage` in the file tree, and can be right-clicked to rename or make backups, which is recommended.

Helpful tips will appear at the top of the screen about visual and text editing tools.

Don't forget to hit save or apply changes to see the results!

> *Loading and saving LNZ data of game files directly is a **planned feature**.*

## Help! It crashes when I do X!

LnzLive is definitely a work in progress! Please make regular backups of your LNZ files.

Raise an issue in the GitHub repository if you have a bug or suggestion to report, so that can be tracked and resolved.

## File Tree
You can either start from a preset LNZ file under `Examples` in the file tree (left-hand panel) by double-clicking to load, or paste LNZ copied from a pet file (`.pet`, `.baby`) or breed file (`.dog`, `.cat`) into the text editor (right-hand panel).

To load your own LNZ file, open in LNZPro, paste the contents into the editor, and hit `Apply Changes` or save (`CRTL+S`) to refresh the pet view. These will appear under `Local Storage` in the file tree, and can be right-clicked to rename or make backups, which is recommended.

Once you have a LNZ file saved under `Local Storage`, you can right-click the file to see some options. While a file is loaded, you can hit `Back Up` to save a copy of the file named `{filename}_backup.lnz`. Note, this will overwrite any existing file of that name. You can also rename or delete files.

## Menu Options

### File

- Import LNZ / BMP / PNG

### Edit

- Capture Head Shot

### Tool

- View Palette
- Recolor Menu

### Mode

In `Select Mode`, hovering over ballz will report their index # and double clicking, or pressing the following keys, will jump you to relevant sections in the LNZ text editor.

- **Z** or **B**: go directly to the LNZ line defining ballz in `[Ball Info]` or `[Add Ball]`.
- **X** or **M**: cycle through `[Move]` lines that affect this ball. If none are found, goes to the `[Move]` header.
- **C** or **P**: cycle through `[Project Ball]` lines that affect this ball. If none are found, goes to the `[Project Ball]` header.
- **V** or **L**: cycle through `[Linez]` that include this ball. If none are found, goes to the `[Linez]` header.

In `Paintball Mode`, TBD

In `Project Mode`, TBD

In `Preset Mode`, TBD

In `Line Mode`, TBD

### Render

Here, you will find toggles for what elements should be drawn in the pet view. Transparency on color index `253` (typically, magenta in default game palette) can be toggled on or off. Special ballz refers to transient ballz like tears in Babyz that do not usually render but aren't explicitly omitted in `[Omissions]`.

### Export

- Export OBJ 3D Model

### Help

This option offers links to several handy resources, including [Carolyn Horn's hexing information](https://github.com/melissamcewen/carolyns-bible) and this [User Guide](https://github.com/tabbzi/LnzLive/blob/master/GUIDE.md)!


### Background Color Selector

Clicking on the square after the menu options brings up a color selector, which you can use to pick the background color of the pet view.

GIF HERE

### Eyelid Toggle

Clicking on the eyeball will cycle through eyelid rendering options: neutral, none, angry, and scared.

GIF HERE

### Animation Controller

Use these controls to preview and navigate animations:

- Jump through animations with the arrows or by entering an animation index in the box.
- Click `Play` button or press `SPACE` to start or stop a playback.
- Slide through animation frames by dragging the handle.

## Basic Navigation

- Click and hold the left mouse button in the pet view (center panel) to rotate the pet.
- Use the mouse wheel to zoom in and out.
- Press down on mouse wheel or hold space and drag to move pet around viewport.

## Edit functions

Options under the "Edit" menu button...

### Capture Head Shot

Click this button to capture current animation frame and view angle in `[Head Shot]` section.

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

Warning: make sure you do not have empty lines or comments in your LNZ before using any Tools.

Press Ctrl+Space in the pet view to open the tools menu, or right-click on a ball in the pet view.

### Color

The Color menu can be used to recolor the pet. When you select a part to recolor, two text entry boxes will appear at your cursor. The first is for the ball colour, the second is for outline color. Type a color number (e.g. 25) and hit Enter to apply. Leave a box blank if you don't want to affect the color/outline.

### Color Swap

The Color Swap tool under the Color menu can be used to quickly create a recolor. Enter the color mappings you want to apply (e.g. 35 -> 15). Use the checkboxes to select what to apply the color swap to.

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

Some tools like `Color Swap` and `Copy L to R` can be destructive! The visual editing tools like move and scale ballz are especially hard to reverse without backups, as these take effect immediately. LnzLive takes a backup of your file before applying these tools, and saves it as `{filename}_backup.lnz`. The backup will overwrite any existing backup file.

> *Improved save states or file versioning is a **planned feature**.*

## Textures and Palettes

Custom BMP files can be loaded from local storage by clicking "Import LNZ / BMP / PNG" button. These should now appear under `Local Textures` in the file tree. You can now apply textures as normal in the LNZ data. LnzLive doesn't care about the full filepath, only the filename.

Similar to textures, custom palettes can be loaded from local storage, but need to be in a color ramp PNG format. **You will need to convert your BMP palette image to a PNG in the format that LnzLive expects**. You can generate this using either of these web tools:

- [Petz Palette Converter](https://draconizations.github.io/petz-palette-converter/)
- [Petz Paletteiare](https://tabbzi.github.io/petz-paletteiare/)

To load your palette image, use the "Import LNZ / BMP / PNG" button. These should now appear under `Local Palettes` in the file tree. You can now apply the paletes as normal in the LNZ data, make sure to omit the `.png` at the end.

You can also add files directly for LnzLive to access from your file system:

Go to `%APPDATA%/Godot/app_userdata/PetzRendering/resources/textures` (you may have to create this folder).

After adding your files directly to this folder, relaunch LnzLive to load it. If your files have been loaded correctly, you will see them if you expand the `Local Textures` or `Local Palettes` part of the file tree.

> *Loading palettes from palette BMP files directly is a **planned feature**.*

## Other features

While editing the LNZ:

- Place the editing cursor on any line in Ballz Info. You don't need to select the entire line, just place the cursor within it. Hit Ctrl+Q to make that ball flash in the pet view so you can locate it.
- Similarly, place the cursor on any line in the Add Ball section and hit Ctrl+Q to make the addball flash.