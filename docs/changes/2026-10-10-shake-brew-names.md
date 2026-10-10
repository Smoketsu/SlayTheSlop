# 2026-10-10: Brews renamed so Baileys sells only Shake

Author: Agent B. Branch: `b/shake-brew-names`. Lanes: `content` (`data/brews/`) and `tools`
(`tests/data/`). Decided by Person B (steamjgrube); proposal `docs/proposals/brew-shake-names.md`.

## What changed

- **`data/brews/`**: five Brews have new display names (`"name"` only; ids, text and effects are
  unchanged):
  `light_beer` "Light Beer" -> "Chill Nug", `energy_drink` "Energy Drink" -> "Wake and Bake",
  `protein_shake` "Protein Shake" -> "Gym Gummy", `shot_of_courage` "Shot of Courage" -> "Hotbox",
  `hair_of_the_dog` "Hair of the Dog" -> "Morning Dab".
- **`tests/data/test_item_data.gd`**: `test_items_match_the_core_fixtures` now compares each Brew
  file with Agent A's fixture on everything except `name` (Gear stays a strict comparison). Two
  tests added: `test_brews_are_not_drinks` and `test_renamed_brews_have_their_new_names`.
- **`docs/proposals/brew-shake-names.md`**: records the decision and asks the GDD owner to update
  the GDD "Brews" table.

## Why

CLAUDE.md: "Baileys sells weed, not drinks", and at Baileys every Brew is shown as Shake with its
own name (G29). Brews named for drinks put drinks into Baileys; G29 also flagged "Protein Shake"
under a "Shake" label. Ids stay because saves refer to them.

## Fields, variables and constants

| Name | Where | Meaning |
| --- | --- | --- |
| `RENAMED_BREWS` | `tests/data/test_item_data.gd` | Added. Brew id -> its new display name, for the five renamed Brews. Changed only by Person B (content). |
| `DRINK_WORDS` | `tests/data/test_item_data.gd` | Added. Words (case-insensitive) no Brew name may contain: beer, drink, shot, shake, dog, wine, ale, booze, liquor, brew. Changed only by Person B (content). |
| `test_brews_are_not_drinks` | `tests/data/test_item_data.gd` | Added test: no Brew name contains a `DRINK_WORDS` entry. |
| `test_renamed_brews_have_their_new_names` | `tests/data/test_item_data.gd` | Added test: the five Brews carry exactly the names in `RENAMED_BREWS`. |

No data fields or constants were added, renamed or removed; only five `name` values changed.
