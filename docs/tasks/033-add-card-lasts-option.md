---
id: 033
title: add_card "lasts" option (Beer Helmet's fight-only Hangover, I7)
lane: core
owner: A
status: in_progress
branch: claude/brave-cerf-to5qlg
depends_on: [015, 021]
blocked_on: []
files:
  - core/ops/add_card.gd
  - core/ops/README.md
  - core/combat/card_triggers.gd   # fight-end removal of copies that are not in the run deck
  - tests/core/ops/
  - tests/core/combat/
  - tests/core/items/              # Beer Helmet fixture and tests
---

## Goal

I7 is answered "accept" (steamjgrube, 2026-10-10, decision log #54): Beer Helmet's "Start each
fight with a Hangover card in your draw pile" adds a Hangover that lasts **this fight only**. Today
`add_card` decides how long a copy lasts from the card definition, and Hangover lasts the run, so
the run deck gains one Hangover per fight. Give `add_card` an optional `lasts` field so one effect
can make a fight-only copy of a run-long card. Agent B then sets it in `data/gear/beer_helmet.json`
(task 014).

## Read first

- `core/ops/add_card.gd`, `core/combat/card_triggers.gd` (`remove_fight_only_in_place`).
- `core/schema/dude_state.gd` (`deck` is "every card_uid this Dude owns for the run"; `cards` holds
  every card, fight-only Junk included).
- `docs/proposals/item-rule-gaps.md` I7.

## Acceptance checks

- [ ] `add_card` accepts an optional `lasts` (a `core/schema/card_def.gd` LASTS value); without it
      the copy lasts as its definition says, as today.
- [ ] A copy made with `lasts: "fight"` is not in the run deck and is removed when the fight ends
      (`card_removed`), even though its definition lasts the run.
- [ ] Beer Helmet with `lasts: "fight"` over two fights: one Hangover per fight, none left in the
      deck afterwards (`tests/core/items/`).
- [ ] No state-shape change (no contract PR): fight-only is "owned but not in the run deck".
- [ ] `tools/test.sh` passes.

## Notes

- Asked for by Agent B in #54 ("Action needed from Agent A").

## Log
- 2026-10-10 A: Created and claimed by Agent A (Smoketsu's session) on branch `claude/brave-cerf-to5qlg`.
