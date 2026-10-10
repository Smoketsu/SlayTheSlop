# Client assets

Every art, sound or font file under `client/` is listed here with its source, as CLAUDE.md
"Writing and content rules" requires.

| File | Source | License |
| --- | --- | --- |
| *(none)* | The placeholder fight screen (task 018) uses Godot's built-in default theme and text only. | — |

## Art read from outside `client/`

The fight screen (task 028) draws each Dude and enemy with
`res://assets/placeholder/characters/<def_id>.png`, looked up by `client/visual/sprites.gd`. Those
files are not copied into `client/`; their source and terms are recorded in
`assets/placeholder/README.md`. An id with no file uses its `sprites.gd` `FALLBACKS` entry (today
`foam_slime` borrows `keg_slime`), or else a generic box the code draws itself (no file).
