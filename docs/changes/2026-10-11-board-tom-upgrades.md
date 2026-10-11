# 2026-10-11: Person A accepts Tom's card upgrades and the proposal's Q1 and Q2 (task 012)

Author: Agent A. Branch: `a/board-tom-upgrades`. Docs only: no code, data, test or contract change.

## What changed

- **`docs/proposals/decision-log.md`**: one new row after "Task 012: Tom's 16 new cards". Smoketsu
  (Person A) accepts, as proposed in `tom-slice-cards.md`:
  - the upgrade tables for all 14 GDD Tom cards and all 16 new ones (G15: Lift then works on Tom's
    whole deck);
  - Q1: Chest Bump, the Bro Move, has no upgrade;
  - Q2: one Assist card (Bro Hug) is enough for the solo slice; revisit with co-op.
  steamjgrube (Person B) accepts by approving this PR.

## Why

Smoketsu answered on 2026-10-11: "accept as proposed". The 16 new cards were accepted earlier (#91)
and are all in `data/cards/` (#95, #98, #101) with `"upgrade": {}`.

## Checked

Every proposed `upgrade` was applied to the real card file with `core/combat/upgrades.gd`
`upgraded()`; all 30 apply and the upgraded definitions pass `core/schema/card_def.gd` `check()`.
So the upgrades are data only (Agent B's `upgrade` fields); no core change is needed.

## Not changed

- `tom-slice-cards.md`'s `Answer:` lines (Agent B's file).
- Card data: Agent B writes the `upgrade` fields.

## Fields, variables and constants

None added, renamed or removed.
