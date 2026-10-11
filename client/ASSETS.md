# Client assets

Every art, sound or font file under `client/` is listed here with its source, as CLAUDE.md
"Writing and content rules" requires.

| File | Source | License |
| --- | --- | --- |
| *(none)* | No art, sound or font file lives under `client/`. The fight screen's icons (task 057) are read from `res://assets/placeholder/icons/`; their source is in `assets/placeholder/README.md` "Icons". | — |

## Art read from outside `client/`

The fight screen (task 028) draws each Dude and enemy with
`res://assets/placeholder/characters/<def_id>.png`, looked up by `client/visual/sprites.gd`. Those
files are not copied into `client/`; their source and terms are recorded in
`assets/placeholder/README.md`. An id with no file uses its `sprites.gd` `FALLBACKS` entry (today
`foam_slime` borrows `keg_slime`), or else a generic box the code draws itself (no file).

The room behind a fight is `res://assets/placeholder/backgrounds/<room>.webp`, picked by
`client/visual/backgrounds.gd`: a boss's own room when an enemy on the field has one (named by its
def_id), otherwise the floor's room (floor 1: `basement`). Source and terms are in
`assets/placeholder/README.md` "Backgrounds". A room with no file is drawn as a plain colour.

## Sounds read from outside `client/`

Task 055: the sound effects are `res://assets/placeholder/sounds/<kind>.wav`, looked up by
`client/audio/sounds.gd` `FILES`. They were synthesized for this repository by
`assets/placeholder/source/make_sounds.py`; source and licence are in `assets/placeholder/README.md`
"Sounds". A kind with no file is silent.
