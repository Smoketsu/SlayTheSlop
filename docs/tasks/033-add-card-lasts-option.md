---
id: 033
title: add_card "lasts" option (Beer Helmet's fight-only Hangover, I7)
lane: core
owner: A
status: done
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
  - tests/core/combat/fixtures.gd  # give() now puts the copy in the run deck too (see the log)
  - tests/run/test_node_flow.gd    # task 025's Beer Helmet test, updated to I7's answer
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

- [x] `add_card` accepts an optional `lasts` (a `core/schema/card_def.gd` LASTS value); without it
      the copy lasts as its definition says, as today.
- [x] A copy made with `lasts: "fight"` is not in the run deck and is removed when the fight ends
      (`card_removed`), even though its definition lasts the run.
- [x] Beer Helmet with `lasts: "fight"` over two fights: one Hangover per fight, none left in the
      deck afterwards (`tests/core/items/`).
- [x] No state-shape change (no contract PR): fight-only is "owned but not in the run deck".
- [x] `tools/test.sh` passes.

## Notes

- Asked for by Agent B in #54 ("Action needed from Agent A").
- **The rule now:** a copy lasts one fight if its definition lasts "fight" **or** it is not in the
  run deck. `dude_state.deck` already means "every card_uid this Dude owns for the run", so this
  needs no new state field, no `SCHEMA_VERSION` bump and no contract PR. Anything that grants a
  run card (the run lane's rewards, shop and events) must put it in `deck`, as `add_card` and
  `party.gd` do; a card left out of the deck disappears when the fight ends.
- `lasts` accepts only `"fight"`: a copy can be made to last less than its definition, never more
  (no permanent Paperwork).
- A fight-only Power in play now also leaves `powers` at fight end (before, a fight-only Power would
  have left a uid in `powers` that is not in `cards`; no slice card hit that).

## Log
- 2026-10-10 A: Created and claimed by Agent A (Smoketsu's session) on branch `claude/brave-cerf-to5qlg`.
- 2026-10-10 A: Done, in review on `claude/brave-cerf-to5qlg`.
  - `add_card` takes optional `lasts: "fight"`; `card_triggers.gd` removes copies outside the run
    deck at fight end, and takes a fight-only Power out of `powers` too.
  - `tests/core/combat/fixtures.gd` `give()` now also appends the copy to the run deck, so test
    cards behave like owned cards (4 tests that win a fight with a given card otherwise saw it
    removed); `junk_fixtures.gd` `own()` takes fight-only Junk back out of the deck.
  - Item fixture `beer_helmet` now uses `"lasts": "fight"`, as Agent B's `beer_helmet.json` should.
  - Verified: `tools/test.sh` -> 355 passed, 0 failed (351 on `main` + 4 new). Fixed-seed hashes
    unchanged. With the core change reverted, all 6 new or changed tests fail (checked).
  - Not done: the I7 "Answer:" line in `docs/proposals/item-rule-gaps.md` is still empty; the
    decision is recorded in #54's decision log, and a person should confirm it there.
- 2026-10-10 A: Reverted the test-Gear workaround (a8c4944) so this branch pairs with #71 (Agent B's
  `beer_helmet.json` change, stacked here); merge #71, not this PR alone.
- 2026-10-10 A: Task 025 merged with `tests/run/test_node_flow.gd::test_beer_helmet_hangovers_pile_up`,
  which asserted the old run-long Hangover. Renamed `test_beer_helmet_hangovers_do_not_pile_up` and
  changed to I7's answer (no Hangover in the deck or owned after two fights). Verified with `main`
  merged: alone 432 passed, 1 failed (the expected fixture-vs-data check that #71 fixes); with #71's
  data commit 433 passed, 0 failed.
- 2026-10-11 A: Done. #63 and #71 merged together on 2026-10-10 (steamjgrube merged #71, which
  carried #63's commits). Verified on `main` after the merge: `tools/test.sh` 433 passed, 0 failed.
  The I7 `Answer:` line in `docs/proposals/item-rule-gaps.md` is filled in by the board paperwork PR.
