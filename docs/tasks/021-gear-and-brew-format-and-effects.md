---
id: 021
title: Gear and Brew definition formats, triggers, and use_brew
lane: core
owner: A
status: in_progress
branch: a/021-gear-and-brew-format-and-effects
depends_on: [013]
blocked_on: []
files:
  - core/schema/gear_def.gd     # new contract file, in its own PR first
  - core/schema/brew_def.gd     # new contract file, in its own PR first
  - core/combat/
  - core/ops/
  - core/ruleset/              # register data/gear/ and data/brews/, check starting_gear
  - tests/core/ruleset/
  - tests/core/items/
---

## Goal

Gear and Brews are data, like cards. Define their formats (the GDD has none), the trigger points
Gear hooks into, and the `use_brew` request, so task 014 can write the slice's 10 Gear and the Brews.

## Read first

GDD "Items" (all tables), "Tom, the Enforcer" (Unused Gym Membership); task 014.

## Acceptance checks

- [ ] Contract PR first: `gear_def.gd` and `brew_def.gd` (id, name, rarity, owner Dude or general/boss, effects or triggers), with tests in `tests/core/schema/`.
- [ ] Trigger points, at least: stat change while owned, start of fight, first turn, end of fight, each card play by kind. Enough for every Gear chosen in G16.
- [ ] `use_brew`: costs no Hype, any time in the player phase; empties the slot; `brews_drunk` + 1; `empty_slot` reject.
- [ ] Add `data/gear/` (and `data/brews/`) to `core/ruleset/ruleset.gd` `KINDS`, check each Dude's `starting_gear` against it, and flip `test_starting_gear_is_not_checked_yet` (moved here from task 005).
- [ ] One test per slice Gear and Brew, using task 014's data once merged.

## Log
- 2026-10-10 A: Claimed. All rule gaps answered (#20). Started in parallel with its in-progress dependencies at Person A's instruction; shared op names are pinned (`draw`, `gain_hype`, `self_damage` from 013; `add_card`, `lose_hype` from 015).
