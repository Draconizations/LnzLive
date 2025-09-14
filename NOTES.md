# Notes

## Bugs

Recording observations about bugs here... making issues when the problem and solution are more clear...

### 2025-09-01

- [x]  Comments in sections disrupt the hotkey jumps
- [x]  Hotkey jumps don't loop
- [x]  Fix mirror project to propogate Fixed <> Projected pair swaps
- [x]  Clicking headers for Mirror and Lock should set/unset all in Project Mode
- [ ]  If applyling paintballz, then unselect from Text Editor first, otherwise it replaces all
- [ ]  Render option draw paintballz hides the irises but not on reload of LNZ
- [x]  Frame number doesn't copy right when entering into animation frame? or just frame isnt captured right? -1?
- [x]  Quick flash with CTRL+Q does not affect addballz
- [ ]  Add texture color to recolor menu
- [ ]  Links in Options Menu -> Help open both URLs at once
- [ ]  Scale up overshoots size
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