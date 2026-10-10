---
id: 014
title: The slice's Gear and the eight Brews as data
lane: content
owner: B
status: in_review
branch: b/014-gear-and-brew-data
depends_on: [021]
blocked_on: []
files:
  - data/gear/
  - data/brews/
  - tests/data/          # only to extend task 004's validation to the two new folders
  - docs/tasks/          # only to write tasks asking Agent A for ops or triggers that do not exist
---

## Goal

The 10 Gear chosen in G16, the 3 Boss Gear (Goblin King Chad's reward) and the 8 GDD Brews as data
files in `data/gear/` and `data/brews/`, in the formats task 021 defines, with the GDD's numbers and
wording exactly.

## Read first

GDD "Items" (all tables), "Prices at Baileys", "Tom, the Enforcer" (starting Gear), "Glossary of
themed terms"; G16 and G21; `core/schema/gear_def.gd` and `brew_def.gd` and `core/ops/README.md`
once task 021 has merged; task 004's validator.

## Acceptance checks

- [x] `ls data/gear/*.json | wc -l` prints 13: the 10 Gear from G16's answer plus Beer Helmet, Dad's Platinum Card and Cursed Intramural Trophy.
- [x] `ls data/brews/*.json | wc -l` prints 8: Light Beer, Energy Drink, Protein Shake, Shot of Courage, Special Brownie, Hair of the Dog, Party Bowl, Smelling Salts.
- [x] Tom's starting Gear is `data/gear/tom_unused_gym_membership.json` (the id task 006's `tom.json` already names): heal 6 HP after every fight.
- [x] Ids are snake_case, Tom's Gear prefixed `tom_` (e.g. `tom_arm_wrestling_table`), the rest as task 021's format says. Medical Card is `medical_card`; no file or id uses `fake_id` (the GDD 0.5 rename).
- [x] Each file passes `gear_def.check()` or `brew_def.check()`, and its id equals its file name.
- [x] Each file has rarity, owner (Tom, general or boss) and player-facing text as the GDD table gives them. Boss Gear text states both the upside and the downside.
- [x] Effects and triggers use only what `core/ops/README.md` and task 021 provide. For anything missing, a task for Agent A names the exact op or trigger and its fields, and that item keeps the GDD text with empty effects until it exists.
- [x] Task 004's validation covers `data/gear/` and `data/brews/` (the unknown-folder rule passes), and `tom.json`'s `starting_gear` resolves. The test suite (task 002's command) passes.

## Notes

- **Baileys sells weed, not drinks.** At Baileys every Brew is shown as Shake; the Brew file keeps its
  own name and is a normal Brew in a slot. No text in these files may describe Baileys as selling
  drinks. "Protein Shake" (a Brew) and "Shake" (the shop's name for any Brew) are easy to confuse on
  screen; flag it to the people if it reads badly, do not rename.
- Gear and Brew numbers (+1 Swole, +8 Max HP, heal 8, 20% lower ...) are content values and live in
  these files, not in `data/constants.json` and not in code.
- Questions to ask, not answer: Unused Gym Membership and the Boss Gear have no rarity in the GDD
  (use what task 021's format allows for starting and boss Gear, or ask); whether Medical Card's 20%
  applies to card removal, and how a discounted price rounds; which statuses count as "debuffs" for
  Hair of the Dog (G10 only defines buffs).
- Party Bowl ("every player") and Smelling Salts (solo variant) must be written for any party size;
  the core picks the solo case from `party_size`, the data does not assume one Dude.
- Medical Card changes Baileys prices, which is run lane (task 025); check with Agent A that a trigger
  for it exists before writing its effects.

## Log
- 2026-10-10 B: Claimed. Every gap in `blocked_on` is answered (steamjgrube accepted all defaults; see `docs/proposals/decision-log.md`).
- 2026-10-10 B: Done. 13 Gear in `data/gear/` and 8 Brews in `data/brews/`, copied from Agent A's `tests/core/items/item_fixtures.gd` (what the core's item tests play). Medical Card is `medical_card`; no `fake_id`. Boss Gear text states upside and downside. Beer Helmet is as built: its Hangover lasts the run; I7's accepted default (one fight only) needs a `lasts` option on `add_card` first (asked of Agent A in #54 and on #29), then a one-line data change here. Verified: `tools/test.sh` all passing; `tests/data/test_item_data.gd` checks the set, every file against the fixture, and the current names.
