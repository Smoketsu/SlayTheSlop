# Placeholder art

Visual placeholders for the solo slice, until real art exists. **Nothing here is final art.** Any of it can be replaced, as long as the replacement keeps the same file name.

## Source

- **Who and when:** provided by Smoketsu (Person A) on 2026-10-10, to be used as placeholders.
- **Origin:** Smoketsu generated the sheet with ChatGPT image generation. The original image is kept unchanged at `source/character_sheet.webp`.
- **Terms:** Smoketsu confirmed on 2026-10-10 that the project may use it freely. It is placeholder art only.

## Characters (`characters/`)

The files were cut from the sheet by `source/slice_sheet.py`. Each is a transparent-background PNG, trimmed to the character with a 4-pixel margin, at the sheet's resolution (about 180–275 px per side).

The background was removed by flood-filling the sheet's grey (RGB 89, 90, 99) from each cell's border. Small background gaps fully enclosed by a character's outline may still be grey.

Each file is named by the content id it shows (`data/dudes/<id>.json` or `data/enemies/<id>.json`), so a screen can look one up as `res://assets/placeholder/characters/<id>.png`:

| File | Content id | Notes |
| --- | --- | --- |
| `tom.png` | `tom` (Dude) | |
| `goblin_pledge.png` | `goblin_pledge` | |
| `goblin_bouncer.png` | `goblin_bouncer` | |
| `keg_slime.png` | `keg_slime` | No separate art for `foam_slime` (its split halves) yet |
| `dorm_rat.png` | `dorm_rat` | The sheet labels this `dorm_rats`, and it shows the group of three |
| `skeleton_intern.png` | `skeleton_intern` | |
| `boo_zer.png` | `boo_zer` | |
| `mimic_cooler.png` | `mimic_cooler` | |
| `kobold_ra.png` | `kobold_ra` | |
| `goblin_shot_caller.png` | `goblin_shot_caller` | |
| `hall_monitor_golem.png` | `hall_monitor_golem` | |
| `sewer_gator.png` | `sewer_gator` | |
| `goblin_king_chad.png` | `goblin_king_chad` | The slice's boss |
| `rat_king.png` | none yet | The GDD's floor 1 boss "The Rat King of the Dumpster", which is not in the slice's data |

## Re-cutting

```
python3 -I assets/placeholder/source/slice_sheet.py assets/placeholder/source/character_sheet.webp <out_dir>
```

This needs Pillow and NumPy. It writes the sheet's own labels, so rename `dorm_rats.png` to `dorm_rat.png` afterwards.
