---
id: 011
title: Enemy intents, move choice and targeting
lane: core
owner: A
status: open
branch:
depends_on: [007]
blocked_on: [G11]
files:
  - core/combat/
  - core/ai/
  - tests/core/ai/
---

## Goal

Enemies pick moves by weight from the `combat_ai` stream, never repeat a move three times in a row,
show their intent and target in advance, and follow scripted patterns where the data says so.

## Read first

GDD "Turn flow" step 1 and 5, "Enemies" intro, "Difficulty scaling" (targets per attack);
`core/schema/enemy_def.gd`, `enemy_state.gd`.

## Acceptance checks

- [ ] Weighted choice using only `combat_ai`; weight-0 moves are never chosen at random.
- [ ] No move three times in a row (G11 decides whether scripted moves are exempt). Needs a per-enemy move history: add the field to `enemy_state.gd` in a contract PR first.
- [ ] A data-driven way to script a pattern (Goblin Bouncer alternates Guard and hit). Propose the field in a contract PR to `enemy_def.gd`.
- [ ] Targets: one Dude, or `MULTI_TARGET_PARTY_SIZE` Dudes at that party size; never a Passed Out Dude.
- [ ] Fixed-seed test: a recorded intent sequence for a two-move enemy over 20 turns.

## Log
