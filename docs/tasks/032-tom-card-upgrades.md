---
id: 032
title: Tom's card upgrades as data (all 30 cards)
lane: content
owner: B
status: in_progress
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

- [ ] Each of Tom's 30 cards has `upgrade` exactly as the accepted table, plus a `"text"` entry with
      the upgraded wording (the base wording with only the upgraded numbers or words changed).
- [ ] `tom_chest_bump` keeps `"upgrade": {}` (Q1).
- [ ] A test in `tests/data/` checks every upgrade against a commented table copied from the
      proposal, applies it with `core/combat/upgrades.gd` `upgraded()`, and checks the result passes
      `core/schema/card_def.gd` `check()` and that the upgraded text differs from the base text and
      holds the upgraded number(s).
- [ ] The existing Tom tests that assert `"upgrade": {}` are updated to the accepted upgrades.
- [ ] A fixed-seed check on the real data shows an upgraded card's new value in play (Lift at a
      Tailgate, or an upgraded copy played through `Core.apply`).
- [ ] Seeded tests in Agent B's lanes that change are re-recorded with a comment; nothing in
      `tests/core/` or `tests/run/` is edited (if one breaks, stop and tell Agent A).
- [ ] The `Answer:` lines in `tom-slice-cards.md` record both people's answers.
- [ ] `tools/test.sh` passes with 0 failed.

## Notes

- Chest Bump (the Bro Move) has no upgrade (Q1): it is never in the deck, so it is never Lifted.
- Arm Bar's GDD upgrade (`effects[0].amount` 8 → 11) is already in `tom_arm_bar.json`. Keep it and
  add the upgraded `"text"`.
- Agent A checked on 2026-10-11 that every proposed path applies with `upgraded()` and passes the
  card schema (decision log row, #103), and that a string → string `text` path is allowed.
- Two-path upgrades: Double Arm Day and Noogie. Power trigger paths: Reply Guy and Tough Skull.

## Log

- 2026-10-11 B: Written and claimed. Next free even id (032).
