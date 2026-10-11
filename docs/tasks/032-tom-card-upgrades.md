---
id: 032
title: Tom's card upgrades as data (all 30 cards)
lane: content
owner: B
status: done
branch: b/032-tom-upgrades
depends_on: [012, 025, 030]
blocked_on: []
files:
  - data/cards/
  - tests/data/
  - docs/proposals/tom-slice-cards.md   # only the `Answer:` lines (Agent B's file)
---

## Goal

Both people accepted the upgrade tables in `docs/proposals/tom-slice-cards.md` for all 30 of Tom's
cards (14 GDD + 16 new) and its Q1 and Q2 (decision log rows "Task 012: Tom's 16 new cards", #91,
and "Task 012: upgrades, Q1 and Q2", #103). This task writes each accepted upgrade into the card's
`upgrade` field in `data/cards/`, so Lift at The Tailgate works on Tom's whole deck (G15). Each
upgrade also sets `"text"` to the upgraded wording, because an upgraded copy otherwise keeps the
definition's `text` and screens would show the old numbers.

## Read first

- `docs/proposals/tom-slice-cards.md` ("Upgrades", "Questions") and the two decision log rows above.
- GDD "Example card definition", "Card definition fields" (`upgrade`), "The Tailgate" (Lift).
- `core/combat/upgrades.gd` (path grammar, how `upgraded()` applies an `upgrade` dict),
  `core/schema/card_def.gd` (`upgrade` rules), the existing `data/cards/tom_*.json`,
  `tests/data/test_tom_data.gd`, `tests/data/test_tom_new_cards.gd`.

## Acceptance checks

- [x] Each of Tom's 30 cards has `upgrade` exactly as the accepted table, plus a `"text"` entry with
      the upgraded wording (the base wording with only the upgraded numbers or words changed).
      Exception: the 5 cost-only upgrades set no `"text"` (see the log).
- [x] `tom_chest_bump` keeps `"upgrade": {}` (Q1).
- [x] A test in `tests/data/` checks every upgrade against a commented table copied from the
      proposal, applies it with `core/combat/upgrades.gd` `upgraded()`, and checks the result passes
      `core/schema/card_def.gd` `check()` and that the upgraded text differs from the base text and
      holds the upgraded number(s).
- [x] The existing Tom tests that assert `"upgrade": {}` are updated to the accepted upgrades.
- [x] A fixed-seed check on the real data shows an upgraded card's new value in play (Lift at a
      Tailgate, or an upgraded copy played through `Core.apply`).
- [x] Seeded tests in Agent B's lanes that change are re-recorded with a comment; nothing in
      `tests/core/` or `tests/run/` is edited (if one breaks, stop and tell Agent A).
- [x] The `Answer:` lines in `tom-slice-cards.md` record both people's answers.
- [x] `tools/test.sh` passes with 0 failed.

## Notes

- Chest Bump (the Bro Move) has no upgrade (Q1): it is never in the deck, so it is never Lifted.
- Arm Bar's GDD upgrade (`effects[0].amount` 8 → 11) is already in `tom_arm_bar.json`. Keep it and
  add the upgraded `"text"`.
- Agent A checked on 2026-10-11 that every proposed path applies with `upgraded()` and passes the
  card schema (decision log row, #103), and that a string → string `text` path is allowed.
- Two-path upgrades: Double Arm Day and Noogie. Power trigger paths: Reply Guy and Tough Skull.

## Log

- 2026-10-11 B: Written and claimed. Next free even id (032).
- 2026-10-11 B: Done, in review on `b/032-tom-upgrades`. All 30 of Tom's cards (14 GDD + 16 new)
  now have the accepted `upgrade` in `data/cards/`, path for path as the proposal's two tables
  (Double Arm Day and Noogie have two paths; Reply Guy and Tough Skull change a `power_triggers`
  path; Arm Bar's GDD path was kept). Every upgrade that changes a number in the card's text also
  sets `"text"`: the base wording with only that number changed (for example Punch "Deal 9 damage",
  Compound Fracture "Deal 9 damage. If the target has a Broken Arm, deal 6 more. ..."). The 5
  cost-only upgrades (Friend Zone, Dislocate, Three-Hour Podcast, Nothing to Lose, Main Character
  Energy) set no `"text"`: no card text states its cost, the screens show the cost apart from the
  text, and a copy of the base text would go stale if the base wording changes. If a person wants
  `"text"` on those too, it is one line per file. `tom_chest_bump` keeps `"upgrade": {}` (Q1).
  Every upgrade applied as written; none needed a change.
  New `tests/data/test_tom_upgrades.gd`: each file's `upgrade` equals the commented
  `ACCEPTED_UPGRADES` table, and that table (without `"text"`) equals each row of the proposal's
  two upgrade tables (parsed from the file); every upgrade applies with `upgrades.gd` `upgraded()`,
  passes `card_def.gd` `check()`, `can_upgrade()` is true, each path goes from the proposal's old
  value to the new one and nothing else changes; the upgraded text differs, holds each upgraded
  number as a whole word and is exactly the base text with the numbers swapped; Chest Bump cannot be
  upgraded. Fixed seed 20261011 on the real data: a one-Tailgate map offers Lift on all 10 starter
  cards (only Arm Bar before), Lifting `c1` (Punch) emits `card_upgraded` and its definition reads
  "Deal 9 damage"; the boss vote starts Goblin King Chad's fight through `Core.apply`, `c1` is in the
  opening hand and deals 9 to the first enemy (`RECORDED`); a replay is byte-identical.
  Updated: `tests/data/test_tom_data.gd` (`test_only_arm_bar_upgrades` became
  `test_every_tom_card_but_chest_bump_upgrades`; Arm Bar's GDD check and the core-fixture check set
  the upgrade fields aside, since Agent A's `tests/core/ops/tom_fixtures.gd` keeps the old upgrades);
  `tests/data/test_tom_new_cards.gd` (`ACCEPTED` holds the accepted upgrades instead of `{}`).
  Re-recorded: `tests/data/test_side_quest_data.gd` The Unlabeled Brownie (upgrade 2 random cards)
  upgraded only Arm Bar and now picks 2 of the 10 starter cards: `["tom_arm_bar"]` ->
  `["tom_punch", "tom_flex"]` at seed 20261016 and `["tom_arm_bar", "tom_flex"]` at seed 1. No other
  test changed; nothing in `tests/core/` or `tests/run/` broke (their Lift tests use fixtures).
  `tom-slice-cards.md`: all 20 `Answer:` lines filled with both people's answers (#91, #103); its
  `Status:` line is left as it was.
  Verified: `tools/test.sh` -> 508 passed, 0 failed.
  Not done / found: the fight screen's hand (`client/fight/fight_model.gd` `_card`) reads the base
  definition, so an upgraded copy in hand still shows its base cost and text (the run screens only
  mark a Lifted copy's name). Showing `core/combat/upgrades.gd` `definition_of()` there instead is
  client work for a separate task.
- 2026-10-11 B: Done: merged (#105, claim #104). Upgraded copies display with their upgraded definition in the client (#106).
