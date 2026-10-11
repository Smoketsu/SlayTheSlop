---
id: 030
title: Tom's new cards as data (the 13 whose ops exist)
lane: content
owner: B
status: in_review
branch: b/030-tom-new-cards
depends_on: [012, 013]
blocked_on: []
files:
  - data/cards/
  - tests/data/
---

## Goal

Both people accepted all 16 new Tom cards in `docs/proposals/tom-slice-cards.md` (decision log row
"Task 012: Tom's 16 new cards", PR #91). This task writes the 13 of them whose ops already exist in
the core as files in `data/cards/`, so they join Tom's card pool (cards owned by `tom` with rarity
common, uncommon or rare, `core/run/pools.gd`) and can be offered as rewards and at Baileys.

## Read first

- `docs/proposals/tom-slice-cards.md` ("New cards") and the decision log row above.
- GDD "Card definition fields", "Card types and keywords", "Tom".
- `core/schema/card_def.gd`, `core/ops/README.md` (every op's fields), the existing
  `data/cards/tom_*.json`, `tests/data/test_tom_data.gd`, `tests/data/content_check.gd`.

## Acceptance checks

- [x] 13 files in `data/cards/`, one per card, file name equal to `id`: `tom_noogie`,
      `tom_headlock`, `tom_hot_take`, `tom_stare_down`, `tom_noggin_knock`, `tom_dislocate`,
      `tom_compound_fracture`, `tom_story_time`, `tom_gym_selfie`, `tom_headbutt`,
      `tom_full_nelson`, `tom_three_hour_podcast`, `tom_main_character_energy`.
- [x] Each file passes `core/schema/card_def.gd`'s `check()`, `Ops.check_all()` and the ruleset
      build (`tests/data/test_data_files.gd`).
- [x] Name, type, cost, rarity, target, keywords, effects and text exactly as accepted in
      `tom-slice-cards.md`; rarity as proposed.
- [x] No upgrade values: the upgrade tables in `tom-slice-cards.md` are not accepted, so each file
      has `"upgrade": {}` like the existing Tom cards without a GDD upgrade.
- [x] A test in `tests/data/` checks every new card against a commented table of the accepted
      numbers and that each is in Tom's card pool.
- [x] A fixed-seed fight test in `tests/data/` plays at least one new card through `Core.apply` and
      records the outcome.
- [x] `tools/test.sh` passes (475 passed, 0 failed).

## Notes

- Three accepted cards wait for Agent A and are **not** part of this task: `tom_bro_hug` (needs
  `ally` targets, task 035), `tom_tough_skull` (needs the `self_damaged` Power trigger, task 037) and
  `tom_nothing_to_lose` (needs the op `damage_from_missing_hp`, task 039). Each gets its own content
  task once its core task merges.
- Bro Hug's ally pick on the fight screen is later client work, after task 035.
- Card reward offers and Baileys draw from Tom's pool, so adding cards can change seeded outcomes in
  Agent B's tests that reach a reward (`tests/client/`, `tests/data/`). Re-record those with a
  comment; if a test in `tests/core/` or `tests/run/` breaks, stop and tell Agent A.

## Log

- 2026-10-11 B: Written and claimed. Next free even id (030).
- 2026-10-11 B: Done, in review on `b/030-tom-new-cards`. 13 files in `data/cards/` (`tom_noogie`,
  `tom_headlock`, `tom_hot_take`, `tom_stare_down`, `tom_noggin_knock`, `tom_dislocate`,
  `tom_compound_fracture`, `tom_story_time`, `tom_gym_selfie`, `tom_headbutt`, `tom_full_nelson`,
  `tom_three_hour_podcast`, `tom_main_character_energy`), each written exactly as the proposal's
  card (effects, text, rarity, target, keywords) with `"upgrade": {}`. Every field each card needs
  exists in `core/ops/README.md`; no card needed a rule the core lacks. Tom's pool is found by owner
  and rarity (`core/run/pools.gd` `card_pool`), so `data/dudes/tom.json` needed no change.
  New test file `tests/data/test_tom_new_cards.gd`: each file equals the commented `ACCEPTED` table
  and passes `card_def.gd` `check()`, `Ops.check_all()` (trigger effects too) and the real ruleset
  build; the three waiting cards have no file (`WAITING`); Tom's pool has 9 common, 9 uncommon and
  5 rare cards (`POOL_SIZES`); three single-card checks through `Core.apply` on the real data (Full
  Nelson then Compound Fracture deal 10, 6, 6, 6 and break both arms; Headlock adds Noodle Arms only
  after Dislocate; Main Character Energy breaks an arm when Three-Hour Podcast Grosses Out a Goblin
  Bouncer, and the Podcast is Tapped); and a fixed-seed fight (seed 20261011, starter deck plus one
  of each new card, Goblin Pledge and Goblin Bouncer) recorded as `RECORDED` = won, turn 6, 21
  requests, Tom at 71 HP, playing 11 of the 13 (`RECORDED_PLAYED`; not Full Nelson or Headbutt).
  No existing test changed: the seeded run drives in `tests/client/` and `tests/data/` still pass
  with the bigger pool, so nothing was re-recorded, and nothing in `tests/core/` or `tests/run/`
  broke. `tests/data/test_tom_data.gd` `test_only_arm_bar_upgrades` covers the new files too.
  Verified: `tools/test.sh` -> 475 passed, 0 failed. Not done: Bro Hug, Tough Skull and Nothing to
  Lose (tasks 035, 037, 039); upgrade values (the upgrade tables are not accepted).
