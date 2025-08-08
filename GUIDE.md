# LnzLive guide

## Quickstart

Load a Petz or Babyz LNZ file by double-clicking one of the Examples.

Edit the LNZ in the right-hand window.

Hit Ctrl+S to save and refresh the pet view. Your file will be saved in local storage.

Once a Petz or Babyz LNZ is loaded, you can paste in external LNZ. If using in a browser, your browser must have permission to access the clipboard.

## Help! It crashes when I do this!

LnzLive is definitely a work in progress!  

If you're using the web version, it should be fairly resilient. If you make a mistake in your LNZ (e.g. missing a space between two numbers) and the pet view goes all weird, you should be able to correct it and continue.

If you're using the Windows exe, run the debug version rather than the release version.

Raise an issue if you have a bug to point out. There's also a LnzLive channel on the Discord server "Hexers HQ". Check in there if you want to ask, chat or complain :)

## Basic navigation

Click and hold the left mouse button in the pet view (centre) to rotate the pet.

Use the mouse wheel to zoom in and out.

Press down on mouse wheel or hold space and drag to move pet around viewport.

The pet view currently has a maximum size of 1000x1000px. If part of your pet is cut off when zoomed in, don't worry about it.

## File tools

Once you have a file saved in Local Storage (i.e. you have loaded an Example pet and hit Ctrl+S at least once), you can right click it to see some options.

While a file is loaded, you can hit Back Up to save a copy of the file named "yourfilename_backup.lnz". Note: this will overwrite any existing file of that name.

You can also rename or delete files in local storage.

## Advanced navigation

Turn on ball selection using the "Select Mode" checkbox from the Mode menu at the top of the screen.

Hover over balls to show their ball number.

Double-click a ball/addball to go directly to the LNZ line defining the ball/addball.

While hovering over a ball/addball, you can use the following keys:

- Z or B: go directly to the LNZ line defining the ball/addball
- X or M: cycle through Move lines that affect this ball. If none are found, goes to the Move header.
- C or P: cycle through Project Ball lines that affect this ball. If none are found, goes to the Project Ball header.
- V or L: cycle through Linez that include this ball. If none are found, goes to the Linez header.

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

Color Swap and Copy L to R can be destructive! LnzLive takes a backup of your file before applying them, and saves it as "yourfilename_backup.lnz". The backup will overwrite any existing backup file.

## Custom textures

Custom BMP files can be loaded from local storage by clicking "Add File". You can also add BMP files directly for LnzLive to access from your file system. Go to %APPDATA%/Godot/app_userdata/PetzRendering/resources/textures (you may have to create this folder). Copy your textures directly into this folder, without subfolders. Relaunch LnzLive. If your textures have been loaded correctly, you will see them if you expand the Local Textures part of the filetree in the left panel.

Apply textures as normal in the LNZ data. LnzLive doesn't care about the full filepath, only the filename.

## Palette swapping

Similar to textures, custom palettes can be loaded from local storage. There is no way to add these via the local interface, so you have to use the Windows exe.

**You will need to convert your .bmp palette image to a .png in the format lnzlive expects**, use the following tool:

**[Convert your palette files here](https://draconizations.github.io/petz-palette-converter/)**!

To load your palette image, use the "Add File" button in the lower left. Or, go to %APPDATA%/Godot/app_userdata/PetzRendering/resources/palettes (you may have to create this folder). Copy the converted .png files** directly into the folder. Relaunch LnzLive. If your palettes have been loaded correctly, you will see them if you expand the Local Palettes part of the filetree.

You can now apply the paletes as normal in the LNZ data, make sure to omit the .png at the end.

## Other features

While editing the LNZ:

- Place the editing cursor on any line in Ballz Info. You don't need to select the entire line, just place the cursor within it. Hit Ctrl+Q to make that ball flash in the pet view so you can locate it.
- Similarly, place the cursor on any line in the Add Ball section and hit Ctrl+Q to make the addball flash.