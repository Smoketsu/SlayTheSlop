# 2026-10-11: task 030, Nothing to Lose and Bro Hug as data

Author: Agent B. Branch: `b/030-nothing-to-lose` (follows #95, which added 13 of Tom's 16 new
cards). Content and tests only: no code or contract changes.

## What changed

- **2 new card files in `data/cards/`**, each exactly as accepted in
  `docs/proposals/tom-slice-cards.md` (decision log row "Task 012: Tom's 16 new cards", #91), owner
  `tom`, `"crunch": null`, `"upgrade": {}` (the upgrade tables are not accepted):

  | Id | Name | Type | Cost | Rarity | Target | Keywords | Effects |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | `tom_nothing_to_lose` | Nothing to Lose | attack | 2 | rare | enemy | `tapped` | `damage_from_missing_hp` cap 30 (op from task 039, #93) |
  | `tom_bro_hug` | Bro Hug | skill | 1 | common | ally | `assist` | `guard` 7, on the target Dude (ally targets from task 035, #96) |

- **`tests/data/test_tom_new_cards.gd`**: both cards added to `ACCEPTED` and removed from
  `WAITING`; `POOL_SIZES` updated; two new single-card checks through `Core.apply` on the real data
  (`test_nothing_to_lose_hits_for_missing_hp_up_to_30`: Tom at 60/80 HP deals 20 to a Goblin
  Bouncer, at 30/80 the hit is capped at 30, and the card is Tapped; `test_bro_hug_in_solo_guards_tom`:
  Bro Hug aimed at Tom's own `player_id` gives him 7 Guard). The fight policy `_next_request` now
  also tries Tom's own `player_id` as a target, so it can play ally cards. The fixed-seed fight
  builds its deck from `ACCEPTED`, so its recorded outcome was re-recorded (below).
- **`docs/tasks/030-tom-new-cards-data.md`**: branch and log entry (15 of 16; Tough Skull waits for
  task 037).

## Why

Agent A's tasks 039 (`damage_from_missing_hp`) and 035 (`ally` targets) merged, so two of the three
waiting accepted cards can be data now.

## Fields, variables and constants

No data field, schema field or tuning constant was added, renamed or removed. New card ids
(permanent once merged): `tom_nothing_to_lose`, `tom_bro_hug`. Test constants changed in
`tests/data/test_tom_new_cards.gd`:

- `ACCEPTED`: now 15 cards (adds `tom_nothing_to_lose`, `tom_bro_hug`).
- `WAITING`: now only `tom_tough_skull` (task 037).
- `POOL_SIZES`: common 9 -> 10, uncommon 9, rare 5 -> 6.
- `RECORDED`: re-recorded `["won", 6, 21, 71]` -> `["won", 6, 20, 69]` (result, final turn,
  applied requests, Tom's final HP) on Godot 4.7.2-stable, because the deck gained two cards.
- `RECORDED_PLAYED`: re-recorded, now 10 of 15: `tom_bro_hug`, `tom_compound_fracture`,
  `tom_dislocate`, `tom_gym_selfie`, `tom_headbutt`, `tom_headlock`, `tom_noggin_knock`,
  `tom_noogie`, `tom_stare_down`, `tom_three_hour_podcast`.

No other test was re-recorded: `tools/test.sh` -> 488 passed, 0 failed.
