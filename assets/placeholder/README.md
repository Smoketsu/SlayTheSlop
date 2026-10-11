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

## Backgrounds (`backgrounds/`)

Fight-room backgrounds, 1672 × 941 px (about 16:9). They are kept as the WebP files that were provided, unchanged; Godot imports WebP directly. Like the characters, Smoketsu provided them on 2026-10-10 as placeholders, from the same ChatGPT set and on the same terms.

| File | Used for |
| --- | --- |
| `basement.webp` | Floor 1, The Basement: the default room for its Brawls, Rivals and other fights |
| `goblin_king_chad.webp` | Goblin King Chad's throne room (the slice's floor 1 boss) |
| `rat_king.webp` | The Rat King of the Dumpster's lair. This boss is in the GDD but not in the slice's data |

Each boss background is named by the boss's content id, matching `characters/`. A screen can use `backgrounds/<boss id>.webp` when the fight has that boss and fall back to `backgrounds/basement.webp` otherwise.

## Icons (`icons/`)

Small stat, status, intent and pile icons for the fight screen (task 057). **Made for this repository** by Agent B on 2026-10-11: each is a 64 × 64 SVG drawn from plain circles, rectangles and paths by `source/make_icons.py`; nothing is copied from other art, and no brand or logo is used. The client looks them up by file name through `client/visual/icons.gd` (`ICONS`), so a replacement icon sheet only has to keep the same file names. Godot imports SVG directly; the `.import` files are committed like the other art's.

| File | Shows | Used for (icons.gd key) |
| --- | --- | --- |
| `heart.svg` | A red heart | `hp` (left end of the HP bar) |
| `shield.svg` | A blue shield | `guard`, and the `defend` intent |
| `flex.svg` | A flexed arm | `swole` |
| `snowflake.svg` | A snowflake | `chill` |
| `crown.svg` | A gold crown | `clout` |
| `hype_orb.svg` | An orange orb with a faint bolt | `hype` (the orb beside the hand) |
| `bullseye.svg` | A red and white target | `exposed` |
| `noodle.svg` | Two limp noodles | `noodle_arms` |
| `queasy.svg` | A queasy green face | `hungover` |
| `cloud.svg` | A grey cloud | `foggy` |
| `ghost.svg` | A pale ghost | `faded` |
| `broken_bone.svg` | A bone snapped in two | `broken_arms` (status `broken_arm`) |
| `stink.svg` | Green stink lines | `ick` |
| `sword.svg` | A sword | the `attack` intent |
| `arrow_up.svg` | A green up arrow | the `buff` intent |
| `arrow_down.svg` | A purple down arrow | the `debuff` intent |
| `summon.svg` | A plus in a circle | the `summon` intent |
| `hourglass.svg` | An hourglass | the `charge` intent |
| `flee.svg` | An arrow leaving a doorway | the `flee` intent |
| `question.svg` | A question mark | the `unknown` intent |
| `zzz.svg` | Zzz | `skipped` (an enemy that will skip its move) |
| `aim.svg` | A white chevron, tinted per Dude by the client | `target` (attack marker) and `seat` (marker over a Dude in co-op) |
| `fist_bump.svg` | Two fists bumping | `bro_meter` |
| `draw_pile.svg` | A stack of blue card backs | `draw_pile` |
| `discard_pile.svg` | Fanned red card faces | `discard_pile` |
| `tapped_pile.svg` | A grey card crossed out | `tapped_pile` |

To redraw them, edit `source/make_icons.py` and run, from the repository root:

```
python3 -I assets/placeholder/source/make_icons.py assets/placeholder/icons
```

It needs only the Python standard library.

## Re-cutting

```
python3 -I assets/placeholder/source/slice_sheet.py assets/placeholder/source/character_sheet.webp <out_dir>
```

This needs Pillow and NumPy. It writes the sheet's own labels, so rename `dorm_rats.png` to `dorm_rat.png` afterwards.

## Sounds (`sounds/`)

Placeholder sound effects (task 055), played by `client/audio/sounds.gd`, which looks each one up by its kind in `FILES` (`<kind>.wav`). A kind whose file is missing is silent.

- **Who and when:** made by Agent B (steamjgrube's agent) on 2026-10-11, for this repository.
- **How:** synthesized by `source/make_sounds.py` from sine, square and triangle waves and noise, using only the Python standard library. Nothing is sampled, recorded or downloaded, and no sound imitates a real game, film or brand. The script is deterministic: running it again writes byte-identical files.
- **Licence:** made for this repository; the project may use, change or replace them freely. Placeholder sound only.
- **Format:** 16-bit mono PCM WAV at 22050 Hz, each under 1 second; about 169 KB for all ten.

| File | Kind | Played when | Length | How it sounds |
| --- | --- | --- | --- | --- |
| `card_played.wav` | `card_played` | A card or Bro Move is played | 0.14 s | Noise swish over a soft low tick |
| `hit.wav` | `hit` | A hit takes HP | 0.20 s | Sine thump falling 150 to 55 Hz, with a short noise crack |
| `blocked.wav` | `blocked` | Guard takes a hit whole | 0.22 s | Dull clank of three inharmonic partials |
| `guard.wav` | `guard` | Someone gains Guard | 0.22 s | Two rising soft-square blips |
| `enemy_death.wav` | `enemy_death` | An enemy dies | 0.45 s | Wobbling triangle sliding 420 to 70 Hz |
| `passed_out.wav` | `passed_out` | A Dude Passes Out | 0.70 s | Three slow falling triangle notes (G, E, C) |
| `click.wav` | `click` | Any button is pressed | 0.03 s | Very short tick |
| `dolla_bills.wav` | `dolla_bills` | A Dude gains Dolla Bills | 0.27 s | Two-note high "ching" |
| `victory.wav` | `victory` | A fight is won | 0.78 s | Rising C-major arpeggio ending on a held C |
| `defeat.wav` | `defeat` | A fight is lost | 0.90 s | Three falling "wah wah" notes |

Regenerate them with

```
python3 -I assets/placeholder/source/make_sounds.py assets/placeholder/sounds
```

A new sound needs an entry in the script's `SOUNDS`, in `client/audio/sounds.gd` `FILES`, and in the table above.
